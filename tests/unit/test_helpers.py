# SPDX-License-Identifier: GPL-2.0-only
"""Tests of the Python helpers and of the data files.  Standard library only,
no network, no compiler: python3 -m unittest discover -s tests/unit"""
import contextlib
import importlib.util
import io
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HELPERS = os.path.join(ROOT, "helpers")
TOOLS = os.path.join(ROOT, "tools")
DATA = os.path.join(ROOT, "data")
sys.path.insert(0, HELPERS)
import data_files  # noqa: E402


def run(script, *args):
    """Run a helper the way the generator does (python3 -I); (rc, stdout, stderr).
    SCRIPT is below helpers/, or tools/NAME."""
    r = subprocess.run([sys.executable, "-I", os.path.join(ROOT if script.startswith("tools/") else HELPERS, script)] + list(args),
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    return r.returncode, r.stdout, r.stderr


def read(path):
    with open(path) as f:
        return f.read()


def load(name, where=None):
    spec = importlib.util.spec_from_file_location(name, os.path.join(where or HELPERS, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class Tmp(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.tmp = self._td.name

    def tearDown(self):
        self._td.cleanup()

    def path(self, name):
        return os.path.join(self.tmp, name)

    def write(self, name, text):
        p = self.path(name)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write(text)
        return p


class MkTbd(Tmp):
    def test_reexport_library(self):
        syms = self.write("s", "x86_64 _a\narm64 _a\n")
        out = self.path("o.tbd")
        rc, _, err = run("write_tbd.py", out, "/x/A", "1", syms, "--compat", "1",
                         "--reexport-library", "/x/B.framework/B", "--reexport-library", "/x/C")
        self.assertEqual(rc, 0, err)
        t = read(out)
        self.assertIn("reexported-libraries:\n  - targets:         [ x86_64-macos, arm64-macos, arm64e-macos ]\n"
                      "    libraries:       [ '/x/B.framework/B', '/x/C' ]\nexports:", t)
        rc, _, err = run("write_tbd.py", out, "/x/A", "1", syms)
        self.assertEqual(rc, 0, err)
        self.assertNotIn("reexported-libraries", read(out))

    def test_two_architectures(self):
        syms = self.write("s", "x86_64 _a\nx86_64 _b\narm64 _a\narm64 _c\n")
        out = self.path("o.tbd")
        rc, _, err = run("write_tbd.py", out, "/usr/lib/libx.1.dylib", "1.2", syms, "--compat", "1")
        self.assertEqual(rc, 0, err)
        t = read(out)
        self.assertIn("install-name:    '/usr/lib/libx.1.dylib'", t)
        self.assertIn("current-version: 1.2", t)
        self.assertIn("compatibility-version: 1", t)
        self.assertIn("x86_64-macos", t)
        self.assertIn("arm64-macos", t)
        # a symbol of one architecture is not listed for the other
        self.assertRegex(t, r"_b")
        self.assertRegex(t, r"_c")

    def test_replaces_a_symlink(self):
        syms = self.write("s", "x86_64 _a\narm64 _a\n")
        target = self.write("target.tbd", "keep me\n")
        link = self.path("link.tbd")
        os.symlink(target, link)
        rc, _, err = run("write_tbd.py", link, "/usr/lib/libx.dylib", "1", syms, "--compat", "1")
        self.assertEqual(rc, 0, err)
        self.assertEqual(read(target), "keep me\n")
        self.assertFalse(os.path.islink(link))

    def test_deterministic(self):
        syms = self.write("s", "arm64 _z\narm64 _a\nx86_64 _m\n")
        a, b = self.path("a.tbd"), self.path("b.tbd")
        run("write_tbd.py", a, "/usr/lib/libx.dylib", "1", syms, "--compat", "1")
        run("write_tbd.py", b, "/usr/lib/libx.dylib", "1", syms, "--compat", "1")
        self.assertEqual(read(a), read(b))


class Scrub(Tmp):
    def test_scrub_forms(self):
        m = load("scrub_platforms")
        cases = [
            ("void f(void) __API_UNAVAILABLE(bridgeos);", "void f(void) ;"),
            ("__API_AVAILABLE(macos(10.0), bridgeos(2.0))", "__API_AVAILABLE(macos(10.0))"),
            ("__API_AVAILABLE(bridgeos(2.0), macos(10.0))", "__API_AVAILABLE(macos(10.0))"),
            ("__API_UNAVAILABLE(macos, bridgeos)", "__API_UNAVAILABLE(macos)"),
            # the macros of the framework headers have no underscores
            ("OSStatus f(void) API_UNAVAILABLE(bridgeos);", "OSStatus f(void) ;"),
            ("API_AVAILABLE(macos(10.0), bridgeos(2.0))", "API_AVAILABLE(macos(10.0))"),
            ("API_UNAVAILABLE(macos, bridgeos)", "API_UNAVAILABLE(macos)"),
            ("API_UNAVAILABLE(bridgeos, macos)", "API_UNAVAILABLE(macos)"),
            ("MY_API_UNAVAILABLE(bridgeos)", "MY_API_UNAVAILABLE(bridgeos)"),
            # the platform argument of __OS_AVAILABILITY(_MSG) stays (objc/objc-api.h)
            ("__OS_AVAILABILITY(bridgeos,introduced=_vers)", "__OS_AVAILABILITY(bridgeos,introduced=_vers)"),
            ("__OS_AVAILABILITY_MSG(bridgeos,deprecated=_dep,_msg)", "__OS_AVAILABILITY_MSG(bridgeos,deprecated=_dep,_msg)"),
            ("nothing here", "nothing here"),
        ]
        for src, want in cases:
            got, _ = m.scrub(src, "bridgeos")
            self.assertEqual(got.strip(), want.strip(), src)

    def test_every_directory_and_the_notice(self):
        self.write("inc/a.h", "/* l */\nint a API_UNAVAILABLE(bridgeos);\n")
        self.write("fw/Security.framework/Headers/b.h", "/* l */\nint b API_UNAVAILABLE(bridgeos);\nint c __API_AVAILABLE(macos(10.0), bridgeos(2.0));\n")
        self.write("fw/Other.framework/Headers/c.h", "int d;\n")
        rc, out, err = run("scrub_platforms.py", "2026-11-26", self.path("inc"), self.path("fw/Security.framework/Headers"),
                           self.path("fw/Other.framework/Headers"))
        self.assertEqual(rc, 0, err)
        self.assertIn("3 substitutions in 2 files", out)
        b = read(self.path("fw/Security.framework/Headers/b.h"))
        self.assertNotRegex(read(self.path("inc/a.h")) + b, r"(?m)^[^/].*bridgeos")   # not in the lines of code
        self.assertIn("/* Modified by osxcross-open-sdk (2026-11-26): the platform bridgeos removed", b)
        self.assertEqual(read(self.path("fw/Other.framework/Headers/c.h")), "int d;\n")


class Notice(Tmp):
    def test_after_license_comment(self):
        p = self.write("a.h", "/* license */\n#ifndef A\n#define A\n#endif\n")
        run("notice.py", "2026-11-24", p, "something changed")
        t = read(p)
        self.assertTrue(t.startswith("/* license */\n/* Modified by osxcross-open-sdk (2026-11-24): something changed. */\n#ifndef A"))

    def test_without_comment_and_idempotent(self):
        p = self.write("b.h", "int x;\n")
        run("notice.py", "2026-11-24", p, "x")
        run("notice.py", "2026-11-24", p, "x")
        t = read(p)
        self.assertEqual(t.count("Modified by osxcross-open-sdk"), 1)
        self.assertTrue(t.endswith("int x;\n"))

    def test_second_text_is_added_behind_the_first(self):
        p = self.write("c.h", "/* license */\n#define A 1\n")
        run("notice.py", "2026-11-24", p, "first")
        run("notice.py", "2026-11-24", p, "second")
        run("notice.py", "2026-11-24", p, "second")
        t = read(p)
        self.assertEqual(t.count("Modified by osxcross-open-sdk"), 2)
        self.assertLess(t.index("first"), t.index("second"))
        self.assertTrue(t.endswith("#define A 1\n"))


class TreeHash(Tmp):
    def make(self, root):
        self.write(os.path.join(root, "a/f.h"), "one\n")
        os.symlink("f.h", os.path.join(self.path(root), "a/l.h"))

    def test_same_tree_same_hash_any_time(self):
        self.make("t1")
        self.make("t2")
        os.utime(self.path("t2/a/f.h"), (1, 1))
        h1 = run("tree_hash.py", self.path("t1"))[1]
        h2 = run("tree_hash.py", self.path("t2"))[1]
        self.assertEqual(h1, h2)
        self.assertRegex(h1.strip(), r"^[0-9a-f]{64}$")

    def test_content_mode_and_link_change_the_hash(self):
        self.make("t1")
        base = run("tree_hash.py", self.path("t1"))[1]
        self.write("t1/a/f.h", "two\n")
        self.assertNotEqual(run("tree_hash.py", self.path("t1"))[1], base)
        self.write("t1/a/f.h", "one\n")
        self.assertEqual(run("tree_hash.py", self.path("t1"))[1], base)
        os.chmod(self.path("t1/a/f.h"), 0o755)
        self.assertNotEqual(run("tree_hash.py", self.path("t1"))[1], base)
        os.chmod(self.path("t1/a/f.h"), 0o644)
        os.unlink(self.path("t1/a/l.h"))
        os.symlink("other.h", self.path("t1/a/l.h"))
        self.assertNotEqual(run("tree_hash.py", self.path("t1"))[1], base)


class AvailDsl(Tmp):
    DSL = "version macos 13.3\nversion ios 16.4\nversion macos 14.0\nversion ios 17.0\nversion macos 15.0\nversion ios 18.0\n"

    def test_ios_version(self):
        p = self.write("a.dsl", self.DSL)
        self.assertEqual(run("avail_dsl.py", "--ios-version", p, "14.0")[1].strip(), "17.0")

    def test_cut_after_the_release(self):
        base = self.write("base.dsl", "# base\nversion macos 13.3\nversion ios 16.4\n")
        extra = self.write("extra.dsl", "version macos 14.0\nversion ios 17.0\nversion macos 15.0\nversion ios 18.0\n")
        out = self.path("out.dsl")
        rc, _, err = run("avail_dsl.py", base, extra, "14.0", out)
        self.assertEqual(rc, 0, err)
        t = read(out)
        self.assertIn("version macos 14.0", t)
        self.assertNotIn("version macos 15.0", t)

    def test_maccatalyst_variant_name(self):
        # the DSL of AvailabilityVersions-138.7 names the variant iosmac (GCC does not know that name),
        # the later tags macCatalyst; both end up as macCatalyst with the alias iosmac
        old = "variant\t\tios\t\t\t\t\tiosmac\t\tMACCATALYST\tavailability_aliases=macCatalyst\nversion macos 14.0\n"
        new = "variant     ios                 macCatalyst   MACCATALYST\nversion macos 14.0\n"
        for name, text in (("old", old), ("new", new)):
            base = self.write(name + ".dsl", text)
            extra = self.write(name + "-extra.dsl", "")
            out = self.path(name + "-out.dsl")
            rc, _, err = run("avail_dsl.py", base, extra, "14.0", out)
            self.assertEqual(rc, 0, err)
            lines = [l.split() for l in read(out).splitlines() if l.startswith("variant")]
            self.assertEqual(lines, [["variant", "ios", "macCatalyst", "MACCATALYST", "availability_aliases=iosmac"]])


class CxxSite(Tmp):
    def test_template(self):
        src = self.write("in", "#cmakedefine01 _LIBCPP_HAS_THREADS\n#cmakedefine _LIBCPP_ABI_VERSION @LIBCXX_ABI_VERSION@\n"
                               "#cmakedefine01 _LIBCPP_UNKNOWN_OPTION\n#cmakedefine _LIBCPP_PSTL_BACKEND_LIBDISPATCH\n")
        out = self.path("out")
        rc, _, err = run("write_cxx_config_site.py", src, out)
        self.assertEqual(rc, 0, err)
        t = read(out)
        self.assertIn("#define _LIBCPP_HAS_THREADS 1", t)
        self.assertIn("#define _LIBCPP_UNKNOWN_OPTION 0", t)
        self.assertIn("#define _LIBCPP_ABI_VERSION 1", t)
        self.assertIn("#define _LIBCPP_PSTL_BACKEND_LIBDISPATCH", t)


class OpenSdkJson(Tmp):
    OWN = ["--own-files", os.path.join(DATA, "own-files.txt"), "--own-headers", os.path.join(DATA, "headers")]

    def test_content_has_no_date_or_host(self):
        projects = self.write("p.tsv", "xnu\txnu-1\t" + "a" * 40 + "\nLibc\tLibc-1\t" + "b" * 40 + "\n")
        out = self.path("OpenSDK.json")
        args = ["generator_commit=unknown", "macos_version=26.5", "macos_release=macos-265",
                "variant=full", "libcxx=21.1.8", "sqlite_url=https://example.org/s.zip", "sqlite_sha256=" + "c" * 64]
        rc, _, err = run("write_open_sdk_json.py", out, projects, *(self.OWN + args))
        self.assertEqual(rc, 0, err)
        d = json.loads(read(out))
        self.assertEqual(d["name"], "osxcross-open-sdk")
        self.assertEqual([p["name"] for p in d["projects"]], ["Libc", "sqlite", "xnu"])
        self.assertEqual(d["variant"], "full")
        self.assertIn("usr/lib/*.tbd", d["own_files"])
        text = read(out)
        self.assertNotRegex(text, r"20\d\d-\d\d-\d\d")
        out2 = self.path("2.json")
        run("write_open_sdk_json.py", out2, projects, *(self.OWN + args))
        self.assertEqual(text, read(out2))

    def test_core_has_no_sqlite_and_fewer_own_files(self):
        projects = self.write("p.tsv", "xnu\txnu-1\t" + "a" * 40 + "\n")
        out = self.path("c.json")
        run("write_open_sdk_json.py", out, projects, *self.OWN, "generator_commit=0123456789abcdef0123456789abcdef01234567-modified", "macos_version=26.5",
            "macos_release=macos-265", "variant=core", "libcxx=21.1.8")
        d = json.loads(read(out))
        self.assertEqual([p["name"] for p in d["projects"]], ["xnu"])
        self.assertNotIn("usr/include/xpc/xpc.h", d["own_files"])

    def test_fallback_only_if_the_sdk_has_the_own_file(self):
        projects = self.write("p.tsv", "xnu\txnu-1\t" + "a" * 40 + "\n")
        args = ["generator_commit=unknown", "macos_version=14.3", "macos_release=macos-143", "variant=full", "libcxx=16.0.6"]
        der = "usr/include/libDER/DERItem.h"
        self.write("sdk/" + der, read(os.path.join(DATA, "headers", der)))
        run("write_open_sdk_json.py", self.path("sdk/OpenSDK.json"), projects, *(self.OWN + args))
        self.assertIn(der, json.loads(read(self.path("sdk/OpenSDK.json")))["own_files"])
        self.write("sdk/" + der, "/* the file of xnu */\n")
        run("write_open_sdk_json.py", self.path("sdk/OpenSDK.json"), projects, *(self.OWN + args))
        self.assertNotIn(der, json.loads(read(self.path("sdk/OpenSDK.json")))["own_files"])


class Manifest(Tmp):
    def test_read_and_new_offline(self):
        m = load("manifest", TOOLS)
        base = self.write("base.txt", "# c\nxnu xnu-1 " + "a" * 40 + "\nLibm Libm-1 " + "b" * 40 + "\nAvailabilityVersions AvailabilityVersions-100 " + "c" * 40 + "\nsqlite u " + "d" * 64 + "\nxz g v1 " + "f" * 40 + "\n")
        self.assertEqual([r[0] for r in m.read_projects(base)], ["xnu", "Libm", "AvailabilityVersions"])
        rel = self.write("rel.json", json.dumps({"projects": [{"project": "xnu", "tag": "xnu-2"},
                                                         {"project": "AvailabilityVersions", "tag": "AvailabilityVersions-134"}]}))
        m.ls_remote = lambda url, ref: "e" * 40
        out = self.path("out.txt")
        with contextlib.redirect_stdout(io.StringIO()):
            m.cmd_new("26.6", base, rel, out)
        lines = [l.split() for l in read(out).splitlines() if l.strip() and not l.startswith("#")]
        d = {l[0]: l for l in lines}
        self.assertEqual(d["xnu"][1:], ["xnu-2", "e" * 40, "release"])
        self.assertEqual(d["Libm"][1:], ["Libm-1", "e" * 40, "fixed"])
        # AvailabilityVersions before tag 135 keeps the old tag
        self.assertEqual(d["AvailabilityVersions"][1], "AvailabilityVersions-100")
        self.assertIn("sqlite", d)
        self.assertEqual(d["xz"][1:], list(m.read_manifest_xz(base)))

    def test_new_from_a_list_of_tags(self):
        # a base of "<project> <tag>" lines has no sqlite line: the newest manifest gives it
        m = load("manifest", TOOLS)
        base = self.write("base.txt", "xnu xnu-1\nLibm Libm-1\n")
        rel = self.write("rel.json", json.dumps({"projects": [{"project": "xnu", "tag": "xnu-2"}]}))
        m.ls_remote = lambda url, ref: "e" * 40
        out = self.path("out.txt")
        with contextlib.redirect_stdout(io.StringIO()):
            m.cmd_new("26.6", base, rel, out)
        d = {l.split()[0]: l.split() for l in read(out).splitlines() if l.strip() and not l.startswith("#")}
        self.assertEqual(d["xnu"][1], "xnu-2")
        self.assertEqual(d["sqlite"][1:], list(m.read_manifest(m.newest_manifest())[1]))
        self.assertEqual(d["xz"][1:], list(m.read_manifest_xz(m.newest_manifest())))


class MakeLicenses(Tmp):
    def src_tree(self, with_sqlite):
        """A source directory with a license file for every project of the list"""
        m = load("write_licenses")
        src = self.path("src")
        for ent in m.P:
            if ent[1] is None:
                continue
            d = os.path.join(src, ent[1])
            os.makedirs(d, exist_ok=True)
            if ent[0] != "libdispatch":   # libdispatch: no license file, the Apache text is added
                self.write(os.path.join("src", ent[1], "LICENSE"), ent[0] + " license\n")
            top = ent[1].split("/")[0]
            self.write(os.path.join("src", top, ".open-sdk-tag"), "%s-1.0\n" % top)
        self.write("src/xnu/APPLE_LICENSE", "APSL\n")
        self.write("src/CF/.open-sdk-tag", "CF-1153.18\n")
        if with_sqlite:
            self.write("src/sqlite-amalgamation-3430200/sqlite3.h", '/* blessing */\n#define SQLITE_VERSION        "3.43.2"\n')
        return src

    def run_it(self, variant, with_sqlite):
        src = self.src_tree(with_sqlite)
        out = self.path("out")
        args = [src, out, variant, os.path.join(DATA, "licenses", "0BSD.txt"),
                "--apache-license", os.path.join(DATA, "licenses", "Apache-2.0.txt"),
                "--scl-license", os.path.join(DATA, "licenses", "swift-corelibs-foundation-LICENSE.txt"),
                "--own-files", os.path.join(DATA, "own-files.txt"), "--own-headers", os.path.join(DATA, "headers"),
                "--sdk", self.path("sdk"), "--projects-out", self.path("projects.tsv")]
        if with_sqlite:
            args += ["--sqlite", os.path.join(src, "sqlite-amalgamation-3430200")]
        rc, _, err = run("write_licenses.py", *args)
        self.assertEqual(rc, 0, err)
        return out, read(os.path.join(out, "LICENSES.md"))

    def test_core(self):
        out, md = self.run_it("core", False)
        self.assertTrue(md.startswith("# Licenses of the open SDK (core SDK)\n"))
        self.assertIn("| xnu | xnu-1.0 |", md)
        self.assertNotIn("| zlib |", md)
        self.assertNotIn("sqlite", md)
        self.assertEqual(read(os.path.join(out, "README.txt")), md)
        self.assertEqual(read(os.path.join(out, "own-files-0BSD", "LICENSE.txt")), read(os.path.join(DATA, "licenses", "0BSD.txt")))
        self.assertTrue(os.path.isfile(os.path.join(out, "libdispatch", "LICENSE-Apache-2.0.txt")))
        rows = [l.split("\t") for l in read(self.path("projects.tsv")).splitlines()]
        self.assertIn(["llvm-project", "llvm-project-1.0", "?"], rows)
        self.assertEqual(len(rows), len({r[0] for r in rows}))

    def own_section(self, md):
        """The paths in the list of the files written for this SDK, and the list items"""
        sec = md.split("## Files written for this SDK\n", 1)[1]
        items = [l for l in sec.splitlines() if l.startswith("- ")]
        return [re.match(r"- `([^`]+)`", l).group(1) for l in items], items

    def expected_own(self, variant):
        return sorted(p for p, var, how, _ in data_files.read_own_files(os.path.join(DATA, "own-files.txt"))
                      if (var == "all" or var == variant) and how != "fallback")

    def test_own_files_are_those_of_the_variant(self):
        for variant in ("core", "full"):
            _, md = self.run_it(variant, variant != "core")
            paths, _ = self.own_section(md)
            self.assertEqual(sorted(paths), self.expected_own(variant), variant)
        _, core = self.run_it("core", False)
        for p in ("xpc/xpc.h", "libDER/DERItem.h", "CoreFoundation.framework/Versions/A/Modules/module.modulemap"):
            self.assertNotIn(p, core)

    def test_own_files_have_their_notes_and_the_fallback_its_condition(self):
        der = "usr/include/libDER/DERItem.h"
        _, md = self.run_it("full", True)
        self.assertNotIn(der, md)       # the SDK has no copy of ours: the file is xnu's
        self.write("sdk/" + der, read(os.path.join(DATA, "headers", der)))
        _, md = self.run_it("full", True)
        paths, items = self.own_section(md)
        self.assertIn(der, paths)
        self.assertIn("`%s`: only where xnu has no EXTERNAL_HEADERS/libDER" % der, md)
        self.assertIn("- `usr/include/os/log.h`: stand-ins that trace nothing", items)
        self.assertIn("- `OpenSDK.json`", items)

    def test_full_names_the_versions_of_sqlite_and_cf(self):
        _, md = self.run_it("full", True)
        self.assertIn("| sqlite | 3.43.2 (sqlite-amalgamation-3430200) |", md)
        self.assertIn("(upstream amalgamation 3.43.2)", md)
        self.assertIn("CoreFoundation.framework/Headers (CF-1153.18)", md)
        self.assertIn("| swift-corelibs-foundation | swift-6.4.3-RELEASE | Apache 2.0 with Runtime Library Exception |", md)
        self.assertIn("Runtime Library Exception", read(self.path("out/swift-corelibs-foundation/LICENSE.txt")))
        _, md = self.run_it("core", False)
        self.assertNotIn("swift-corelibs-foundation", md)


class SecurityHeaders(Tmp):
    def test_follows_the_includes(self):
        self.write("hs/Security/Security.h", "#include <Security/A.h>\n")
        self.write("hs/Security/A.h", "#include <Security/B.h>\n#include <Security/Missing.h>\n")
        self.write("hs/Security/B.h", "generic\n")
        self.write("hs/macOS/Security/B.h", "macOS\n")
        self.write("hs/Security/Unused.h", "\n")
        os.makedirs(self.path("dest"))
        rc, _, err = run("security_headers.py", self.path("hs"), self.path("dest"))
        self.assertEqual(rc, 0, err)
        self.assertEqual(sorted(os.listdir(self.path("dest"))), ["A.h", "B.h", "Security.h"])
        self.assertEqual(read(self.path("dest/B.h")), "macOS\n")


class GenSymbols(Tmp):
    def test_evidence_and_aliases(self):
        m = load("libsystem_syms")
        self.assertTrue(m.has_evidence("_stat$INODE64", {"stat"}))
        self.assertTrue(m.has_evidence("__exit", {"_exit"}))
        self.assertFalse(m.has_evidence("_nothere", {"stat"}))
        for fn in m.ALIAS_FILES:
            self.write(os.path.join("src", fn), "# comment\n_a _b\n_c _d # x\nbad line here\n")
        self.assertEqual(m.alias_pairs(self.path("src")), [("_a", "_b"), ("_c", "_d")] * len(m.ALIAS_FILES))

    def test_header_list(self):
        m = load("libsystem_syms")
        for h in ("stdio.h", "kern/x.h", "sys/ubc.h", "foo_private.h", "later.h"):
            self.write("sdk/usr/include/" + h, "\n")
        self.write("sdk/work/headers.list", "stdio.h\nkern/x.h\nsys/ubc.h\nfoo_private.h\n")
        self.assertEqual(m.header_list(self.path("sdk")), ["stdio.h"])


class CxxSymbols(Tmp):
    def test_not_reexported_by_libcxx(self):
        for arch in ("x86_64", "arm64"):
            self.write("llvm/libcxx/lib/abi/%s-apple-darwin.libcxxabi.v1.stable.exceptions.nonew.abilist" % arch,
                       "{'is_defined': True, 'name': '__Zcxx'}\n{'is_defined': True, 'name': '__Zabi'}\n"
                       "{'is_defined': False, 'name': '__Zundef'}\n")
        for n in ("cxxabiv1", "fundamental-types", "itanium-base", "std-misc", "new-delete",
                  "std-exceptions", "itanium-exceptions", "personality-v0"):
            self.write("llvm/libcxxabi/lib/%s.exp" % n, "__Zabi\n" if n == "cxxabiv1" else "")
        self.write("llvm/libcxxabi/lib/symbols-not-reexported.exp", "# comment\n__Znre\n")
        os.makedirs(self.path("out"))
        rc, _, err = run("cxx_syms.py", self.path("llvm"), self.path("out"))
        self.assertEqual(rc, 0, err)
        self.assertEqual(read(self.path("out/libcxx.syms")), "x86_64 __Zcxx\narm64 __Zcxx\n")
        self.assertEqual(read(self.path("out/libcxxabi.syms")), "x86_64 __Zabi\nx86_64 __Znre\narm64 __Zabi\narm64 __Znre\n")
        self.assertEqual(read(self.path("out/libcxxabi-reexported.syms")), "x86_64 __Zabi\narm64 __Zabi\n")


class SpiSymbols(Tmp):
    def test_declared_defined_missing(self):
        m = load("spi_syms")
        self.write("src/p/private/a.h", "extern int a_one;\nvoid a_two(void);\n")
        self.write("src/p/src/a.c", "int a_one;\nvoid a_two(void) {}\n")
        self.write("src/p/tests/t.c", "int a_test(void);\n")
        self.write("src/p/private/b.h", "int a_test(void);\n")
        e = [("_a_one", "p", "private/a.h"), ("_a_two", "p", "private/a.h"), ("_a_new", "p", "private/a.h")]
        self.assertEqual(m.spi_symbols(self.path("src"), e), (["_a_one", "_a_two"], ["_a_new"], []))
        # declared, but only a test names it; a header that does not exist
        _, _, err = m.spi_symbols(self.path("src"), [("_a_test", "p", "private/b.h"), ("_x", "p", "no.h")])
        self.assertEqual(len(err), 2)
        lst = self.write("l.txt", "# c\n_a_one p private/a.h # x\n_a_new p private/a.h\n")
        rc, out, _ = run("spi_syms.py", self.path("src"), lst, self.path("out"))
        self.assertEqual(rc, 0)
        self.assertIn("_a_new", out)
        self.assertEqual(read(self.path("out")), "x86_64 _a_one\narm64 _a_one\n")
        self.write("bad.txt", "_a_one p\n")
        self.assertNotEqual(run("spi_syms.py", self.path("src"), self.path("bad.txt"), self.path("out"))[0], 0)

    def test_list_of_the_repository(self):
        for sym, proj, hdr in data_files.lines(os.path.join(DATA, "symbols", "libsystem-spi.txt")):
            self.assertTrue(sym.startswith("_"))
            self.assertTrue(hdr.endswith(".h"))


class CheckLibraries(Tmp):
    def test_differences(self):
        m = load("check_libraries", TOOLS)
        os.makedirs(self.path("src"))
        rc, out, _ = run("tools/check_libraries.py", self.path("src"))
        self.assertEqual(rc, 1)
        self.assertIn("libz.1: missing file zlib/zlib.xcconfig", out)
        self.write("src/zlib/zlib.xcconfig", "DYLIB_CURRENT_VERSION = 1.2.12\nDYLIB_COMPATIBILITY_VERSION = 1\n")
        rc, out, _ = run("tools/check_libraries.py", self.path("src"))
        self.assertNotIn("libz.1:", out)
        # every library of the table has a check
        names = set(data_files.read_libraries(os.path.join(DATA, "libraries.txt")))
        self.assertTrue(set(m.CHECKS) <= names)


class DocSymbols(Tmp):
    def page(self, path, eid, mods, mac="10.0", kind="func", ext=None, objc=False, decl=None, refs=(), other=None):
        """decl: the platforms of the declaration, and no metadata.platforms (or other: these); refs: pages that
        it names"""
        m = {"externalID": eid, "modules": [{"name": x} for x in mods], "symbolKind": kind,
             "platforms": [{"name": "iOS", "introducedAt": "2.0"}] + ([{"name": "macOS", "introducedAt": mac}] if mac else [])}
        if ext:
            m["extendedModule"] = ext
        page = {"metadata": m, "abstract": [{"text": "not copied"}],
                "identifier": {"interfaceLanguage": "occ" if objc else "swift"}}
        if decl is not None:
            m["platforms"] = other
            if other is None:
                del m["platforms"]
            page["primaryContentSections"] = [{"kind": "content", "content": []},
                                              {"kind": "declarations", "declarations": [{"platforms": decl}]}]
        page["references"] = {"doc://x/" + r: {"kind": "symbol", "url": "/documentation/" + r,
                                               "title": "not copied"} for r in refs}
        self.write("docs/data/" + path + ".json", json.dumps(page))
        with open(self.path("docs/index.tsv"), "a") as f:
            f.write("https://developer.apple.com/tutorials/data/documentation/%s.json\t200\t2026-11-2%dT01:00:00Z\n"
                    % (path, len(path) % 2 + 6))

    def test_lists(self):
        self.page("coregraphics/cgfoo(_:)", "c:@F@CGFoo", ["Core Graphics"])
        self.page("coregraphics/kcgbar", "c:@kCGBar", ["Core Graphics"], "26.0", "var")
        self.page("coregraphics/cgonlyios", "c:@F@CGOnlyIOS", ["Core Graphics"], None)
        self.page("coregraphics/cgcontext/init(data:)", "c:@F@_CGInit", ["Core Graphics"])
        self.page("coregraphics/cgmacro", "c:@macro@CG_MACRO", ["Core Graphics"])
        self.page("coregraphics/cgenum", "c:@E@CGE@kCGE1", ["Core Graphics"], kind="case")
        self.page("coregraphics/cgalias", "c:@CGAlias", ["Core Graphics"], kind="typealias")
        self.page("foundation/nskey/new", "c:@NSKeyNew", ["Foundation"], kind="property", ext="Foundation")
        self.page("foundation/nskey/font", "c:@NSFontName", ["Foundation"], kind="property", ext="Foundation")
        self.page("foundation/nsnotification/name/pdfx", "c:@PDFXNotification", ["Foundation"], kind="property",
                  ext="Foundation")
        self.page("foundation/nslog", "c:@F@NSLog", ["Foundation"])
        self.page("appkit/nsappkitversionnumber", "c:@NSAppKitVersionNumber", ["AppKit"], kind="var")
        self.page("appkit/nsbase", "c:@NSBaseKey", ["AppKit"], kind="var")
        # under Foundation in Swift, the Objective-C pages name the frameworks
        self.page("foundation/nskey/lang", "c:@NSLangAttribute", ["Foundation"], kind="property", ext="Foundation")
        self.page("appkit/nslangattribute", "c:@NSLangAttribute", ["AppKit"], "10.13", "var", objc=True)
        self.page("foundation/nsnotification/name/pdfy", "c:@PDFYNotification", ["Foundation"], kind="property",
                  ext="Foundation")
        self.page("pdfkit/pdfynotification", "c:@PDFYNotification", ["PDFKit"], kind="var", objc=True)
        self.write("base/Headers/Foundation/NSKey.h", "GS_EXPORT NSString *const NSKeyNew;\n"
                   "GS_EXPORT NSString *const PDFYNotification;\n"
                   "GS_EXPORT NSString *const NSBaseKey;\nGS_EXPORT_CLASS @interface X\n")
        self.write("gui/Headers/AppKit/NSAttr.h", "/* APPKIT_EXPORT int NSNot; */\nAPPKIT_EXPORT NSString *NSFontName;\n"
                   "APPKIT_EXPORT void NSBeep(void);\n")
        rc, out, err = run("tools/doc_symbols.py", "--docs", self.path("docs/data"), "--out", self.path("out"),
                           "CoreGraphics", "Foundation", "AppKit")
        self.assertEqual(rc, 2, out + err)  # Foundation and AppKit need GNUstep
        rc, out, err = run("tools/doc_symbols.py", "--docs", self.path("docs/data"), "--out", self.path("out"),
                           "--gnustep-base", self.path("base"), "--gnustep-gui", self.path("gui"),
                           "CoreGraphics", "Foundation", "AppKit")
        self.assertEqual(rc, 0, out + err)
        rows = {}
        for fw in ("CoreGraphics", "Foundation", "AppKit"):
            t = read(self.path("out/%s.txt" % fw))
            self.assertNotIn("not copied", t)
            rows[fw] = [l.split() for l in t.splitlines() if l and not l.startswith("#")]
        self.assertEqual(rows["CoreGraphics"], [["_CGFoo", "func", "10.0", "coregraphics/cgfoo(_:)"],
                                                ["_kCGBar", "data", "26.0", "coregraphics/kcgbar"]])
        self.assertIn("fetched 2026-11-26 to 2026-11-27", read(self.path("out/CoreGraphics.txt")))
        # NSFontName: under Foundation, but gnustep-gui declares it; PDFXNotification: a member of an
        # extension that neither declares; NSBaseKey: under AppKit, stays there
        self.assertEqual([r[0] for r in rows["Foundation"]], ["_NSKeyNew", "_NSLog"])
        self.assertEqual(rows["AppKit"], [["_NSAppKitVersionNumber", "data", "10.0", "appkit/nsappkitversionnumber"],
                                          ["_NSBaseKey", "data", "10.0", "appkit/nsbase"],
                                          ["_NSFontName", "data", "10.0", "foundation/nskey/font", "gnustep-gui"],
                                          ["_NSLangAttribute", "data", "10.13", "appkit/nslangattribute"]])

    def test_a_page_without_platforms_has_those_of_its_declarations(self):
        self.page("coregraphics/cgstream", "c:@F@CGStream", ["Core Graphics"], decl=["Mac Catalyst", "macOS"])
        self.page("coregraphics/kcgstream", "c:@kCGStream", ["Core Graphics"], kind="var", decl=["macOS"])
        self.page("coregraphics/cgcatalyst", "c:@F@CGCatalyst", ["Core Graphics"], decl=["iOS", "Mac Catalyst"])
        # metadata.platforms of other platforms: their releases count from 26.0 on
        self.page("audiotoolbox/atnew", "c:@F@ATNew", ["Audio Toolbox"], decl=["iOS", "macOS"],
                  other=[{"name": "visionOS", "introducedAt": "26.1"}, {"name": "iOS", "introducedAt": "26.0"}])
        self.page("audiotoolbox/atold", "c:@F@ATOld", ["Audio Toolbox"], decl=["iOS", "macOS"],
                  other=[{"name": "iOS", "introducedAt": "17.0"}])
        self.page("audiotoolbox/atios", "c:@F@ATiOS", ["Audio Toolbox"], decl=["iOS"],
                  other=[{"name": "iOS", "introducedAt": "26.0"}])
        self.page("coregraphics/cgnodecl", "c:@F@CGNoDecl", ["Core Graphics"], decl=[])
        rc, out, err = run("tools/doc_symbols.py", "--docs", self.path("docs/data"), "--out", self.path("out"),
                           "CoreGraphics", "AudioToolbox")
        self.assertEqual(rc, 0, out + err)
        rows = [l.split() for l in read(self.path("out/CoreGraphics.txt")).splitlines() if l and not l.startswith("#")]
        self.assertEqual(rows, [["_CGStream", "func", "-", "coregraphics/cgstream"],
                                ["_kCGStream", "data", "-", "coregraphics/kcgstream"]])
        rows = [l.split() for l in read(self.path("out/AudioToolbox.txt")).splitlines() if l and not l.startswith("#")]
        self.assertEqual(rows, [["_ATNew", "func", "26.0", "audiotoolbox/atnew"],
                                ["_ATOld", "func", "-", "audiotoolbox/atold"]])

    def test_warns_of_pages_that_are_referred_to_and_missing(self):
        self.page("coregraphics/cgfoo(_:)", "c:@F@CGFoo", ["Core Graphics"],
                  refs=["CoreGraphics/CGGone", "CoreGraphics/CGKnown404", "CoreGraphics/CGFoo(_:)",
                        "CoreGraphics/CGType/member", "Metal/MTLGone"])
        self.write("docs/data/coregraphics/cgknown404.json.404", "")
        args = ["tools/doc_symbols.py", "--docs", self.path("docs/data"), "--out", self.path("out"), "CoreGraphics"]
        rc, out, err = run(*args)
        self.assertEqual(rc, 0, out + err)
        # a page of another directory and a page below a page are not named; one that answered 404 is known
        self.assertIn("1 pages that the documentation refers to are not in the cache (fetch them): coregraphics/cggone",
                      err)
        self.write("docs/data/coregraphics/cggone.json", "{}")
        rc, out, err = run(*args)
        self.assertEqual((rc, err), (0, ""))
        # the other directory of --docs has the page
        os.remove(self.path("docs/data/coregraphics/cggone.json"))
        self.write("more/coregraphics/cggone.json", "{}")
        rc, out, err = run("tools/doc_symbols.py", "--docs", self.path("docs/data"), "--docs", self.path("more"),
                           "--out", self.path("out"), "CoreGraphics")
        self.assertEqual((rc, err), (0, ""))

    def test_core_foundation_leaves_out_names_that_headers_mention(self):
        self.page("corefoundation/cffoo(_:)", "c:@F@CFFoo", ["Core Foundation"], "10.5")
        self.page("corefoundation/cfinline(_:)", "c:@F@CFInline", ["Core Foundation"])
        self.page("corefoundation/kcfdeclared", "c:@kCFDeclared", ["Core Foundation"], kind="var")
        self.page("corefoundation/kcfincomment", "c:@kCFInComment", ["Core Foundation"], kind="var")
        self.write("hdr/CFX.h", "/* a name in a comment counts as mentioned: kCFInComment */\nCF_INLINE int CFInline(void) { return 0; }\nextern int kCFDeclared;\n")
        rc, out, err = run("tools/doc_symbols.py", "--docs", self.path("docs/data"), "--out", self.path("out"),
                           "CoreFoundation")
        self.assertEqual(rc, 2, out + err)  # --headers is needed
        rc, out, err = run("tools/doc_symbols.py", "--docs", self.path("docs/data"), "--out", self.path("out"),
                           "--headers", self.path("hdr"), "CoreFoundation")
        self.assertEqual(rc, 0, out + err)
        rows = [l.split() for l in read(self.path("out/CoreFoundation.txt")).splitlines() if l and not l.startswith("#")]
        self.assertEqual(rows, [["_CFFoo", "func", "10.5", "corefoundation/cffoo(_:)"]])


class ApplyDiff(Tmp):
    PATCH = "--- a/x.h\n+++ b/x.h\n@@ -3,3 +3,4 @@\n c\n d\n+new\n e\n"

    def test_applies_at_another_line_and_refuses_a_mismatch(self):
        p = self.write("p.diff", self.PATCH)
        self.write("d/x.h", "a\nb\nz\nc\nd\ne\nf\n")   # the context is two lines further down
        rc, out, err = run("apply_diff.py", self.path("d"), p)
        self.assertEqual(rc, 0, err)
        self.assertEqual(read(self.path("d/x.h")), "a\nb\nz\nc\nd\nnew\ne\nf\n")
        self.write("d/x.h", "a\nb\nz\nq\nd\ne\nf\n")
        rc, out, err = run("apply_diff.py", self.path("d"), p)
        self.assertEqual(rc, 1)
        self.assertIn("does not match", err)
        self.assertEqual(read(self.path("d/x.h")), "a\nb\nz\nq\nd\ne\nf\n")

    def test_the_patch_of_data_CF_applies_to_headers_that_it_changes(self):
        files = re.findall(r"^\+\+\+ b/(\S+)", read(os.path.join(DATA, "CF", "additions.patch")), re.M)
        self.assertEqual(files, sorted(files))
        self.assertGreaterEqual(len(files), 7)


class DataFileReaders(Tmp):
    def test_readers(self):
        p = self.write("s.txt", "# head\n_a   # source\n\n  _b\n# _c\n")
        self.assertEqual(data_files.read_symbols(p), ["_a", "_b"])
        p = self.write("m.txt", "# c\nxnu xnu-1 " + "a" * 40 + " release\nsqlite https://x/s.zip " + "b" * 64 +
                       "\nxz https://x/xz v1 " + "c" * 40 + "\n")
        rows, sq = data_files.read_manifest(p)
        self.assertEqual(rows, [["xnu", "xnu-1", "a" * 40, "release"]])
        self.assertEqual(sq, ("https://x/s.zip", "b" * 64))
        self.assertEqual(data_files.read_manifest_xz(p), ("https://x/xz", "v1", "c" * 40))
        p = self.write("r.txt", "11.3 16.0.6 core -\n14.3 16.0.6 full,core 23D56 default\n")
        self.assertEqual(data_files.read_releases(p), [("11.3", "16.0.6", ["core"], "", False),
                                                       ("14.3", "16.0.6", ["full", "core"], "23D56", True)])


class DataFiles(unittest.TestCase):
    def manifests(self):
        d = os.path.join(DATA, "manifests")
        return {n: read(os.path.join(d, n)).splitlines() for n in sorted(os.listdir(d)) if n.endswith(".txt")}

    def test_manifests(self):
        ms = self.manifests()
        self.assertGreaterEqual(len(ms), 7)
        # the manifests of the releases with a full SDK list the same projects; those of the
        # core-only releases list the same projects but those that only the full SDK uses
        full = {"macos-%s.txt" % r[0].replace(".", "") for r in
                data_files.read_releases(os.path.join(DATA, "releases.txt")) if "full" in r[2]}
        names0 = {True: None, False: None}
        for n, lines in ms.items():
            self.assertRegex(n, r"^macos-\d+\.txt$")
            self.assertTrue(lines[0].startswith("# osxcross-open-sdk: pinned sources for macOS "), n)
            names = []
            for l in lines:
                if not l.strip() or l.startswith("#"):
                    continue
                f = l.split()
                if f[0] == "sqlite":
                    self.assertEqual(len(f), 3)
                    self.assertRegex(f[2], r"^[0-9a-f]{64}$")
                    continue
                if f[0] == "xz":
                    self.assertEqual(len(f), 4)
                    self.assertTrue(f[1].startswith("https://"), l)
                    self.assertRegex(f[3], r"^[0-9a-f]{40}$")
                    continue
                self.assertEqual(len(f), 4, l)
                self.assertRegex(f[2], r"^[0-9a-f]{40}$", l)
                self.assertIn(f[3], ("release", "fixed"))
                self.assertTrue(f[1].startswith(f[0] + "-"), l)
                names.append(f[0])
            self.assertEqual(len(names), len(set(names)), n)
            if names0[n in full] is None:
                names0[n in full] = names
            self.assertEqual(names, names0[n in full], n)
            self.assertIn("xnu", names)
        self.assertTrue(names0[True] and names0[False])
        self.assertEqual([x for x in names0[True] if x in names0[False]], names0[False])

    def test_doc_symbol_lists(self):
        # data/symbols/doc/: "<symbol> <kind> <macOS> <page> [gnustep-gui]", sorted, every symbol once,
        # every list a framework of data/libraries.txt
        d = os.path.join(DATA, "symbols", "doc")
        libs = set(data_files.read_libraries(os.path.join(DATA, "libraries.txt")))
        seen = {}
        for n in sorted(os.listdir(d)):
            self.assertTrue(n.endswith(".txt"), n)
            self.assertIn(n[:-4], libs)
            names = []
            for l in read(os.path.join(d, n)).splitlines():
                if not l or l.startswith("#"):
                    continue
                f = l.split()
                self.assertIn(len(f), (4, 5), l)
                self.assertRegex(f[0], r"^_[A-Za-z_][A-Za-z0-9_]*$", l)
                self.assertIn(f[1], ("func", "data"), l)
                self.assertRegex(f[2], r"^(-|\d+(\.\d+)*)$", l)
                if len(f) == 5:
                    self.assertEqual(f[4], "gnustep-gui", l)
                self.assertNotIn(f[0], seen, "%s: also in %s" % (l, seen.get(f[0])))
                seen[f[0]] = n
                names.append(f[0])
            self.assertEqual(names, sorted(names), n)

    def test_framework_install_names_are_paths_of_versions(self):
        # a framework's install name is /System/Library/Frameworks/N.framework/Versions/V/N (the layout of fw_layout)
        libs = data_files.read_libraries(os.path.join(DATA, "libraries.txt"))
        fws = {k: v for k, v in libs.items() if v[0].startswith("/System/Library/Frameworks/")}
        self.assertIn("Cocoa", fws)
        for k, v in fws.items():
            self.assertRegex(v[0], r"^/System/Library/Frameworks/%s\.framework/Versions/[A-Z]/%s$" % (k, k), k)

    def test_releases_and_libcxx_versions(self):
        llvm = data_files.read_libcxx_versions(os.path.join(DATA, "libcxx-versions.txt"))
        rel = data_files.read_releases(os.path.join(DATA, "releases.txt"))
        versions = [r[0] for r in rel]
        self.assertEqual(len(versions), len(set(versions)))
        self.assertEqual(versions, sorted(versions, key=lambda v: [int(x) for x in v.split(".")]))
        self.assertEqual(sum(1 for r in rel if r[4]), 1, "one default release")
        manifest_versions = {lines[0].split("macOS ")[1] for lines in self.manifests().values()}
        self.assertEqual(set(versions), manifest_versions, "every release has a manifest and every manifest a line")
        for v, libcxx, variants, build, _ in rel:
            self.assertIn(libcxx, llvm, v)
            self.assertIn("core", variants, v)
            self.assertTrue(set(variants) <= {"full", "core"}, v)
            self.assertRegex(build, r"^([0-9]{2}[A-Z][0-9]+[a-z]?)?$", v)
        for v, c in llvm.items():
            self.assertRegex(c, r"^[0-9a-f]{40}$")

    def test_libraries_table(self):
        names = set()
        manifest_projects = {l.split()[0] for l in self.manifests()["macos-265.txt"] if l and not l.startswith("#")}
        for l in read(os.path.join(DATA, "libraries.txt")).splitlines():
            if not l.strip() or l.startswith("#"):
                continue
            f = l.split()
            self.assertGreaterEqual(len(f), 5, l)
            self.assertNotIn(f[0], names)
            names.add(f[0])
            self.assertTrue(f[1].startswith("/"), l)
            cur = f[2]
            if cur.startswith("tag:"):
                self.assertIn(cur[4:], manifest_projects)
            else:
                self.assertRegex(cur, r"^\d+(\.\d+){0,2}$", l)
            self.assertRegex(f[3], r"^\d+(\.\d+){0,2}$", l)
        for n in ("libSystem.B", "libc++.1", "libc++abi", "libresolv.9", "CoreFoundation", "Foundation"):
            self.assertIn(n, names)

    # a source: a path (Libc/gen/x.c, clang's lib/CodeGen/...) or a file name (objc-abi.h)
    SOURCE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]*[A-Za-z0-9_]|\b[A-Za-z0-9_-]+\.(h|c|cpp|mm|s|td|exp)\b")

    def test_symbol_lists_name_a_source(self):
        """Every symbol of every list of data/symbols/ has a source: the comment on its
        line or the last comment before it (a comment that continues on the next
        lines counts as one) names a file.  The lists of data/symbols/doc/ name a page in a
        column (test_doc_symbol_lists)."""
        files = sorted(f for f in os.listdir(os.path.join(DATA, "symbols")) if f.endswith(".txt"))
        self.assertGreaterEqual(len(files), 6)
        for fn in files:
            named = cont = False
            for l in read(os.path.join(DATA, "symbols", fn)).splitlines():
                if not l.strip():
                    cont = False
                    continue
                sym, _, comment = l.partition("#")
                if comment:
                    named = bool(self.SOURCE.search(comment)) or (cont and named)
                cont = bool(comment)
                if sym.strip():
                    self.assertTrue(named, "%s: %s has no source" % (fn, l.strip()))

    def test_xpc_list_fits_the_header(self):
        """data/symbols/libsystem-xpc.txt: the names that xpc/xpc.h declares, each with the
        release of its API_AVAILABLE (doc) or none (webkit, the variables behind the macros)"""
        hdr = read(os.path.join(DATA, "headers", "usr", "include", "xpc", "xpc.h"))
        hdr = re.sub(r"^#.*$", "", re.sub(r"/\*.*?\*/", "", hdr, flags=re.S), flags=re.M)
        avail = {}
        for decl in hdr.split(";"):
            m = re.search(r"\b(_?xpc_[a-z0-9_]+|XPC_[A-Z0-9_]+)\s*(\([^()]*(\([^()]*\)[^()]*)*\))?\s*(__dead2)?\s*$", decl)
            if m and not re.search(r"\btypedef\b|\benum\b", decl):
                v = re.search(r"API_AVAILABLE\(macos\(([0-9.]+)\)\)", decl)
                avail["_" + m.group(1)] = v.group(1) if v else "-"
        rows = data_files.lines(os.path.join(DATA, "symbols", "libsystem-xpc.txt"))
        self.assertEqual({r[0]: r[1] for r in rows}, avail)
        for r in rows:
            self.assertEqual(len(r), 3, r)
            self.assertEqual(r[2], "webkit" if r[1] == "-" else "doc", r)

    def test_fsevents_list_fits_the_header(self):
        """data/symbols/CoreServices-fsevents.txt: the functions that CoreServices/FSEvents.h
        declares, each with the first release of its API_AVAILABLE or API_DEPRECATED"""
        hdr = read(os.path.join(DATA, "headers", "System", "Library", "Frameworks", "CoreServices.framework",
                                "Versions", "A", "Headers", "FSEvents.h"))
        hdr = re.sub(r"^#.*$", "", re.sub(r"/\*.*?\*/", "", hdr, flags=re.S), flags=re.M)
        avail = {}
        for decl in hdr.split(";"):
            m = re.search(r"\b(FSEvents?[A-Za-z]+)\s*\(", decl)
            if m and not re.search(r"\btypedef\b|\benum\b|\bstruct\b", decl):
                v = re.search(r"API_(?:AVAILABLE|DEPRECATED)\((?:\"[^\"]*\", )?macos\(([0-9.]+)", decl)
                avail["_" + m.group(1)] = v.group(1) if v else "-"
        rows = data_files.lines(os.path.join(DATA, "symbols", "CoreServices-fsevents.txt"))
        self.assertEqual({r[0]: r[1] for r in rows}, avail)
        for r in rows:
            self.assertEqual(r[2:], ["doc"], r)

    def test_own_headers_have_a_license(self):
        for root, _, files in os.walk(os.path.join(DATA, "headers")):
            for fn in files:
                self.assertIn("SPDX-License-Identifier: 0BSD", read(os.path.join(root, fn)), fn)

    def test_own_files(self):
        """data/headers/ has exactly the files that data/own-files.txt copies"""
        own = data_files.read_own_files(os.path.join(DATA, "own-files.txt"))
        copied = set()
        for p, var, how, _ in own:
            self.assertIn(var, ("all", "full"), p)
            self.assertIn(how, ("written", "copied", "fallback"), p)
            if how != "written":
                copied.add(p)
        have = set()
        for root, _, files in os.walk(os.path.join(DATA, "headers")):
            for fn in files:
                have.add(os.path.relpath(os.path.join(root, fn), os.path.join(DATA, "headers")))
        self.assertEqual(copied, have)


if __name__ == "__main__":
    unittest.main()


class SdkCheckVersionTest(unittest.TestCase):
    """tests/sdk-check.py: the version in the directory name must match the files"""

    def make_sdk(self, tmp, dirver, ver):
        sdk = os.path.join(tmp, "MacOSX%s.sdk" % dirver)
        os.makedirs(os.path.join(sdk, "System/Library/CoreServices"))
        with open(os.path.join(sdk, "SDKSettings.json"), "w") as f:
            json.dump({"Version": ver, "CanonicalName": "macosx" + ver}, f)
        with open(os.path.join(sdk, "OpenSDK.json"), "w") as f:
            json.dump({"macos": {"version": ver}}, f)
        with open(os.path.join(sdk, "SDKSettings.plist"), "w") as f:
            f.write("<dict><key>Version</key>\n<string>%s</string></dict>" % ver)
        with open(os.path.join(sdk, "System/Library/CoreServices/SystemVersion.plist"), "w") as f:
            f.write("<dict><key>ProductVersion</key><string>%s</string></dict>" % ver)
        return sdk

    def errors(self, dirver, ver):
        spec = importlib.util.spec_from_file_location("sdk_check", os.path.join(ROOT, "tests", "sdk-check.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        with tempfile.TemporaryDirectory() as tmp:
            rep = mod.Report()
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                mod.check_versions(self.make_sdk(tmp, dirver, ver), rep)
            return rep.errors, out.getvalue()

    def test_matching(self):
        self.assertEqual(self.errors("26.5", "26.5")[0], 0)

    def test_other_version_in_the_files(self):
        n, out = self.errors("14.3", "26.5")
        self.assertEqual(n, 5)
        self.assertIn("MacOSX14.3.sdk", out)
        self.assertIn("SystemVersion.plist ProductVersion is 26.5", out)


GL_XML = """<registry><comment>
Copyright 2013-2026 The Khronos Group Inc.
SPDX-License-Identifier: Apache-2.0
</comment>
<types>@TYPES@</types>
<enums namespace="GL"><enum value="0x0001" name="GL_A"/><enum value="0x0002" name="GL_OLD"/>
<enum value="0xFFFFFFFF" name="GL_ALL" type="u"/></enums>
<commands>
<command><proto>void <name>glOld</name></proto></command>
<command><proto>const <ptype>GLubyte</ptype> *<name>glStr</name></proto><param><ptype>GLenum</ptype> <name>n</name></param></command>
<command><proto>void <name>glExt</name></proto><param>const <ptype>GLfloat</ptype> *<name>v</name></param></command>
</commands>
<feature api="gl" name="GL_VERSION_1_0" number="1.0"><require><enum name="GL_A"/><enum name="GL_OLD"/>
<command name="glOld"/><command name="glStr"/></require></feature>
<feature api="gl" name="GL_VERSION_3_2" number="3.2"><require><enum name="GL_ALL"/></require>
<remove profile="core"><enum name="GL_OLD"/><command name="glOld"/></remove></feature>
<extensions><extension name="GL_X_ext" supported="gl"><require><enum name="GL_A"/><command name="glExt"/></require></extension></extensions>
</registry>
"""


class OpenGL(Tmp):
    def setUp(self):
        super().setUp()
        self.xml = os.path.join(self.tmp, "gl.xml")
        with open(self.xml, "w") as f:
            names = "GLenum GLboolean GLbitfield GLvoid GLbyte GLubyte GLshort GLushort GLint GLuint GLsizei GLfloat GLclampf GLdouble GLclampd GLchar GLintptr GLsizeiptr GLint64 GLuint64 GLsync".split()
            f.write(GL_XML.replace("@TYPES@", "".join("<type>typedef int <name>%s</name>;</type>" % n for n in names)))
        self.data = os.path.join(self.tmp, "data")
        os.mkdir(self.data)
        with open(os.path.join(self.data, "extensions.txt"), "w") as f:
            f.write("GL_X_ext|glExt|page\n")
        with open(os.path.join(self.data, "cgl-functions.txt"), "w") as f:
            f.write("OpenGL.h|CGLError|CGLFoo|GLint x|a,b\n")
        with open(os.path.join(self.data, "cgl-enums.txt"), "w") as f:
            f.write("error kCGLNoError 0 a b\npfa kCGLPFAColorSize 8 a b\n")

    def test_profiles(self):
        R = load("gl_registry")
        reg = R.Registry(self.xml)
        legacy = reg.select((1, 0), (2, 1), "compatibility")
        self.assertEqual(legacy, [("GL_VERSION_1_0", ["GL_A", "GL_OLD"], ["glOld", "glStr"])])
        core = reg.select((1, 0), (4, 1), "core")
        self.assertEqual(core[0], ("GL_VERSION_1_0", ["GL_A"], ["glStr"]))
        self.assertEqual(core[1], ("GL_VERSION_3_2", ["GL_ALL"], []))
        self.assertEqual(reg.all_commands((4, 1)), ["glOld", "glStr"])
        self.assertEqual(reg.commands["glStr"].declaration(), "extern const GLubyte *glStr(GLenum n);")

    def test_headers_and_symbols(self):
        out = os.path.join(self.tmp, "h")
        rc, _o, err = run("write_opengl_headers.py", self.xml, self.data, out, "2026-01-01")
        self.assertEqual(rc, 0, err)
        gl = read(os.path.join(out, "gl.h"))
        self.assertIn("extern void glOld(void);", gl)
        self.assertIn("SPDX-License-Identifier: Apache-2.0", gl)
        gl3 = read(os.path.join(out, "gl3.h"))
        self.assertNotIn("glOld", gl3)
        self.assertIn("#define GL_ALL", gl3)
        self.assertIn("0xFFFFFFFFu", gl3)
        self.assertIn("extern void glExt(const GLfloat *v);", read(os.path.join(out, "glext.h")))
        self.assertIn("extern CGLError CGLFoo(GLint x);", read(os.path.join(out, "OpenGL.h")))
        self.assertIn("kCGLPFAColorSize = 8", read(os.path.join(out, "CGLTypes.h")))
        syms = os.path.join(self.tmp, "syms")
        rc, _o, err = run("opengl_syms.py", self.xml, self.data, syms)
        self.assertEqual(rc, 0, err)
        self.assertEqual(read(syms).split(), ["_CGLFoo", "_glExt", "_glOld", "_glStr"])

    def test_data_files(self):
        R = load("gl_registry")
        d = os.path.join(DATA, "opengl")
        enums = R.read_cgl_enums(os.path.join(d, "cgl-enums.txt"))
        names = [n for _g, n, _v in enums]
        self.assertEqual(len(names), len(set(names)))
        for _g, _n, v in enums:
            int(v, 0)
        for row in R.read_pipe_file(os.path.join(d, "cgl-functions.txt")):
            self.assertEqual(len(row), 5, row)
            self.assertGreaterEqual(len(row[4].split(",")), 2, row)
        for row in R.read_pipe_file(os.path.join(d, "extensions.txt")):
            self.assertEqual(len(row), 3, row)
        pin = data_files.lines(os.path.join(d, "registry.txt"))
        self.assertEqual(len(pin), 1)
        self.assertRegex(pin[0][4], r"^[0-9a-f]{64}$")
        self.assertIn("OpenGL", data_files.read_libraries(os.path.join(DATA, "libraries.txt")))
