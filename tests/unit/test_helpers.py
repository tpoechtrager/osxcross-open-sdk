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
DATA = os.path.join(ROOT, "data")


def run(script, *args):
    """Run a helper the way the generator does (python3 -I); (rc, stdout, stderr)."""
    r = subprocess.run([sys.executable, "-I", os.path.join(HELPERS, script)] + list(args),
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    return r.returncode, r.stdout, r.stderr


def read(path):
    with open(path) as f:
        return f.read()


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HELPERS, name + ".py"))
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
    def test_two_architectures(self):
        syms = self.write("s", "x86_64 _a\nx86_64 _b\narm64 _a\narm64 _c\n")
        out = self.path("o.tbd")
        rc, _, err = run("mk_tbd.py", out, "/usr/lib/libx.1.dylib", "1.2", syms, "--compat", "1")
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
        rc, _, err = run("mk_tbd.py", link, "/usr/lib/libx.dylib", "1", syms, "--compat", "1")
        self.assertEqual(rc, 0, err)
        self.assertEqual(read(target), "keep me\n")
        self.assertFalse(os.path.islink(link))

    def test_deterministic(self):
        syms = self.write("s", "arm64 _z\narm64 _a\nx86_64 _m\n")
        a, b = self.path("a.tbd"), self.path("b.tbd")
        run("mk_tbd.py", a, "/usr/lib/libx.dylib", "1", syms, "--compat", "1")
        run("mk_tbd.py", b, "/usr/lib/libx.dylib", "1", syms, "--compat", "1")
        self.assertEqual(read(a), read(b))


class Scrub(unittest.TestCase):
    def test_scrub_forms(self):
        m = load("scrub_platforms")
        cases = [
            ("void f(void) __API_UNAVAILABLE(bridgeos);", "void f(void) ;"),
            ("__API_AVAILABLE(macos(10.0), bridgeos(2.0))", "__API_AVAILABLE(macos(10.0))"),
            ("__API_AVAILABLE(bridgeos(2.0), macos(10.0))", "__API_AVAILABLE(macos(10.0))"),
            ("__API_UNAVAILABLE(macos, bridgeos)", "__API_UNAVAILABLE(macos)"),
            ("nothing here", "nothing here"),
        ]
        for src, want in cases:
            got, _ = m.scrub(src, "bridgeos")
            self.assertEqual(got.strip(), want.strip(), src)


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


class CxxSite(Tmp):
    def test_template(self):
        src = self.write("in", "#cmakedefine01 _LIBCPP_HAS_THREADS\n#cmakedefine _LIBCPP_ABI_VERSION @LIBCXX_ABI_VERSION@\n"
                               "#cmakedefine01 _LIBCPP_UNKNOWN_OPTION\n#cmakedefine _LIBCPP_PSTL_BACKEND_LIBDISPATCH\n")
        out = self.path("out")
        rc, _, err = run("cxx_site.py", src, out)
        self.assertEqual(rc, 0, err)
        t = read(out)
        self.assertIn("#define _LIBCPP_HAS_THREADS 1", t)
        self.assertIn("#define _LIBCPP_UNKNOWN_OPTION 0", t)
        self.assertIn("#define _LIBCPP_ABI_VERSION 1", t)
        self.assertIn("#define _LIBCPP_PSTL_BACKEND_LIBDISPATCH", t)


class OpenSdkJson(Tmp):
    def test_content_has_no_date_or_host(self):
        projects = self.write("p.tsv", "xnu\txnu-1\t" + "a" * 40 + "\nLibc\tLibc-1\t" + "b" * 40 + "\n")
        out = self.path("OpenSDK.json")
        args = ["generator_commit=unknown", "macos_version=26.5", "macos_release=macos-265",
                "variant=full", "libcxx=21.1.8", "sqlite_url=https://example.org/s.zip", "sqlite_sha256=" + "c" * 64]
        rc, _, err = run("open_sdk_json.py", out, projects, *args)
        self.assertEqual(rc, 0, err)
        d = json.loads(read(out))
        self.assertEqual(d["name"], "osxcross-open-sdk")
        self.assertEqual([p["name"] for p in d["projects"]], ["Libc", "sqlite", "xnu"])
        self.assertEqual(d["variant"], "full")
        self.assertIn("usr/lib/*.tbd", d["own_files"])
        text = read(out)
        self.assertNotRegex(text, r"20\d\d-\d\d-\d\d")
        out2 = self.path("2.json")
        run("open_sdk_json.py", out2, projects, *args)
        self.assertEqual(text, read(out2))

    def test_core_has_no_sqlite_and_fewer_own_files(self):
        projects = self.write("p.tsv", "xnu\txnu-1\t" + "a" * 40 + "\n")
        out = self.path("c.json")
        run("open_sdk_json.py", out, projects, "generator_commit=0123456789abcdef0123456789abcdef01234567-modified", "macos_version=26.5",
            "macos_release=macos-265", "variant=core", "libcxx=21.1.8")
        d = json.loads(read(out))
        self.assertEqual([p["name"] for p in d["projects"]], ["xnu"])
        self.assertNotIn("usr/include/xpc/xpc.h", d["own_files"])


class Manifest(Tmp):
    def test_read_and_new_offline(self):
        m = load("manifest")
        base = self.write("base.txt", "# c\nxnu xnu-1 " + "a" * 40 + "\nLibm Libm-1 " + "b" * 40 + "\nAvailabilityVersions AvailabilityVersions-100 " + "c" * 40 + "\nsqlite u " + "d" * 64 + "\n")
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

    def test_new_from_a_list_of_tags(self):
        # a base of "<project> <tag>" lines has no sqlite line: the newest manifest gives it
        m = load("manifest")
        base = self.write("base.txt", "xnu xnu-1\nLibm Libm-1\n")
        rel = self.write("rel.json", json.dumps({"projects": [{"project": "xnu", "tag": "xnu-2"}]}))
        m.ls_remote = lambda url, ref: "e" * 40
        out = self.path("out.txt")
        with contextlib.redirect_stdout(io.StringIO()):
            m.cmd_new("26.6", base, rel, out)
        d = {l.split()[0]: l.split() for l in read(out).splitlines() if l.strip() and not l.startswith("#")}
        self.assertEqual(d["xnu"][1], "xnu-2")
        self.assertEqual(d["sqlite"][1:], list(m.read_manifest(m.newest_manifest())[1]))


class DataFiles(unittest.TestCase):
    def manifests(self):
        d = os.path.join(DATA, "manifests")
        return {n: read(os.path.join(d, n)).splitlines() for n in sorted(os.listdir(d)) if n.endswith(".txt")}

    def test_manifests(self):
        ms = self.manifests()
        self.assertGreaterEqual(len(ms), 7)
        names0 = None
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
                self.assertEqual(len(f), 4, l)
                self.assertRegex(f[2], r"^[0-9a-f]{40}$", l)
                self.assertIn(f[3], ("release", "fixed"))
                self.assertTrue(f[1].startswith(f[0] + "-"), l)
                names.append(f[0])
            self.assertEqual(len(names), len(set(names)), n)
            if names0 is None:
                names0 = names
            self.assertEqual(names, names0, n)
            self.assertIn("xnu", names)

    def test_libcxx_versions(self):
        t = read(os.path.join(DATA, "libcxx-versions.txt")).splitlines()
        macos = {l.split()[1]: l.split()[2] for l in t if l.startswith("macos ")}
        llvm = {l.split()[1]: l.split()[2] for l in t if l.startswith("llvm ")}
        for n, lines in self.manifests().items():
            v = lines[0].split("macOS ")[1]
            self.assertIn(v, macos, n)
            self.assertIn(macos[v], llvm)
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

    def test_symbol_lists_name_a_source(self):
        for fn in ("libsystem-extra.txt", "libobjc-extra.txt"):
            named = False   # a group of symbols has the source on its first line
            for l in read(os.path.join(DATA, "symbols", fn)).splitlines():
                if not l.strip() or l.startswith("#"):
                    continue
                if "#" in l:
                    named = True
                self.assertTrue(named, "%s: %s has no source" % (fn, l.strip()))

    def test_own_headers_have_a_license(self):
        for fn in os.listdir(os.path.join(DATA, "headers")):
            if fn == "CFCompat.h.in":
                continue   # appended to an APSL file
            self.assertIn("SPDX-License-Identifier: 0BSD", read(os.path.join(DATA, "headers", fn)), fn)


if __name__ == "__main__":
    unittest.main()
