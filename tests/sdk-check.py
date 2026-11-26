#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""sdk-check.py SDK_DIR [options]  (use tests/sdk-check.sh)

Checks an SDK that make-open-sdk.sh made, without running anything of it:
  files     the files that every SDK has, valid JSON, no broken or absolute links
  tbd       every .tbd is well formed (install name, versions, both architectures)
            and, if data/libraries.txt names the library, has its install name
            (usr/lib/NAME.tbd, System/Library/Frameworks/NAME.framework/NAME.tbd)
  headers   every header of usr/include on its own with clang, for C and C++
            and both architectures; a header that fails and is not in
            tests/data/header-allow.txt is an error (the headers in the list
            do not compile alone: they need another header first)
Options: --clang PATH (default clang), --gcc "COMMAND" (also check with this GCC for
x86_64, C and C++; the command may have options, for example -B...), --update-allow
(write the failing headers to the allow list), --jobs N, --no-headers.
"""
import json
import os
import re
import shlex
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ALLOW = os.path.join(ROOT, "tests", "data", "header-allow.txt")
SKIP = re.compile(r"(^c\+\+/|_private\.h$|/private/|^sys/_pthread/|^i386/|^machine/)")
VERSION = re.compile(r"^\d+(\.\d+){0,4}$")


class Report:
    def __init__(self):
        self.errors = 0

    def error(self, msg):
        self.errors += 1
        print("FAIL: " + msg)

    def info(self, msg):
        print(msg)


def check_files(sdk, rep, core):
    for rel in ("OpenSDK.json", "SDKSettings.json", "SDKSettings.plist", "README.LICENSE.txt",
                "System/Library/CoreServices/SystemVersion.plist", "usr/include/stdio.h", "usr/include/mach/mach.h",
                "usr/include/TargetConditionals.h", "usr/include/c++/v1/vector", "usr/lib/libSystem.B.tbd",
                "usr/lib/libc++.1.tbd", "usr/lib/libresolv.9.tbd", "usr/share/licenses/open-sdk/LICENSES.md",
                "usr/share/licenses/open-sdk/own-files-0BSD/LICENSE.txt"):
        if not os.path.isfile(os.path.join(sdk, rel)):
            rep.error("missing file " + rel)
    try:
        with open(os.path.join(sdk, "OpenSDK.json")) as f:
            d = json.load(f)
        if d.get("name") != "osxcross-open-sdk" or d.get("format") != 1:
            rep.error("OpenSDK.json: name or format")
        if d.get("variant") not in ("full", "core"):
            rep.error("OpenSDK.json: variant")
        elif core is not None and (d["variant"] == "core") != core:
            rep.error("OpenSDK.json: variant %s does not match the files" % d["variant"])
        for p in d.get("projects", []):
            if "commit" in p and not re.fullmatch(r"[0-9a-f]{40}", p["commit"]):
                rep.error("OpenSDK.json: commit of " + p["name"])
        if not d.get("projects"):
            rep.error("OpenSDK.json: no projects")
    except (OSError, ValueError) as e:
        rep.error("OpenSDK.json: %s" % e)
    try:
        with open(os.path.join(sdk, "SDKSettings.json")) as f:
            s = json.load(f)
        for k in ("CanonicalName", "Version", "MaximumDeploymentTarget", "SupportedTargets"):
            if k not in s:
                rep.error("SDKSettings.json: no " + k)
        if "MinimumDeploymentTarget" not in s.get("SupportedTargets", {}).get("macosx", {}):
            rep.error("SDKSettings.json: no MinimumDeploymentTarget for macosx")
    except (OSError, ValueError) as e:
        rep.error("SDKSettings.json: %s" % e)
    # the commit of the generator: the same value in the three files
    try:
        with open(os.path.join(sdk, "OpenSDK.json")) as f:
            c_open = json.load(f)["generator"]["commit"]
        with open(os.path.join(sdk, "SDKSettings.json")) as f:
            c_json = json.load(f).get("OpenSDKGeneratorCommit")
        with open(os.path.join(sdk, "SDKSettings.plist")) as f:
            m = re.search(r"<key>OpenSDKGeneratorCommit</key>\s*<string>([^<]*)</string>", f.read())
        c_plist = m.group(1) if m else None
        if not re.fullmatch(r"[0-9a-f]{40}(-modified)?|unknown", str(c_open)):
            rep.error("OpenSDK.json: generator commit '%s'" % c_open)
        if not (c_open == c_json == c_plist):
            rep.error("generator commit differs: OpenSDK.json %s, SDKSettings.json %s, SDKSettings.plist %s"
                      % (c_open, c_json, c_plist))
    except (OSError, ValueError, KeyError) as e:
        rep.error("generator commit: %s" % e)
    real = os.path.realpath(sdk)
    n = 0
    for d, dirs, files in os.walk(sdk):
        for name in dirs + files:
            p = os.path.join(d, name)
            if os.path.islink(p):
                n += 1
                t = os.readlink(p)
                if os.path.isabs(t):
                    rep.error("absolute link %s -> %s" % (os.path.relpath(p, sdk), t))
                elif not os.path.exists(p):
                    rep.error("broken link %s -> %s" % (os.path.relpath(p, sdk), t))
                elif not os.path.realpath(p).startswith(real + os.sep):
                    rep.error("link out of the SDK " + os.path.relpath(p, sdk))
    rep.info("files: %d links checked" % n)


def libraries():
    """{name: install name} of data/libraries.txt"""
    sys.path.insert(0, os.path.join(ROOT, "helpers"))
    from data_files import read_libraries
    return {k: v[0] for k, v in read_libraries(os.path.join(ROOT, "data", "libraries.txt")).items()}


def library_name(rel):
    """The name of data/libraries.txt of a .tbd of the SDK: usr/lib/NAME.tbd or
    System/Library/Frameworks/NAME.framework/NAME.tbd (None for the others)"""
    m = re.match(r"^usr/lib/([^/]+)\.tbd$", rel) or \
        re.match(r"^System/Library/Frameworks/([^/]+)\.framework/\1\.tbd$", rel)
    return m.group(1) if m else None


def check_tbd(sdk, rep):
    table = libraries()
    n = 0
    for d, _, files in os.walk(sdk):
        for name in files:
            if not name.endswith(".tbd"):
                continue
            p = os.path.join(d, name)
            if os.path.islink(p):
                continue
            n += 1
            rel = os.path.relpath(p, sdk)
            with open(p) as f:
                t = f.read()
            if not t.startswith("--- !tapi-tbd\n"):
                rep.error(rel + ": not a tbd")
                continue
            m = re.search(r"^install-name:\s+'?([^'\n]+)'?$", t, re.M)
            c = re.search(r"^current-version:\s+(\S+)$", t, re.M)
            k = re.search(r"^compatibility-version:\s+(\S+)$", t, re.M)
            if not (m and c and k):
                rep.error(rel + ": install name or versions missing")
                continue
            if not (VERSION.match(c.group(1)) and VERSION.match(k.group(1))):
                rep.error("%s: bad version %s %s" % (rel, c.group(1), k.group(1)))
            if "x86_64-macos" not in t or "arm64-macos" not in t:
                rep.error(rel + ": architectures")
            if not m.group(1).startswith("/"):
                rep.error(rel + ": install name is not absolute")
            lib = library_name(rel)
            if lib in table and m.group(1) != table[lib]:
                rep.error("%s: install name %s, data/libraries.txt has %s" % (rel, m.group(1), table[lib]))
            if not re.search(r"symbols:\s*\[", t) and "re-exports" not in t and "Foundation" not in rel and "CoreServices" not in rel:
                rep.error(rel + ": no symbols")
    rep.info("tbd: %d files checked" % n)


def headers(sdk):
    inc = os.path.join(sdk, "usr", "include")
    res = []
    for d, _, files in os.walk(inc):
        for name in files:
            if name.endswith(".h"):
                rel = os.path.relpath(os.path.join(d, name), inc)
                if not SKIP.search(rel):
                    res.append(rel)
    return sorted(res)


def compile_one(args):
    cmd, sdk, hdr = args
    r = subprocess.run(cmd + [hdr_src(hdr)], input="", stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    return hdr, r.returncode


def hdr_src(h):
    return "-"


def run_headers(sdk, clang, gcc, jobs, rep, update):
    hs = headers(sdk)
    sdkv = "14.0"
    jobs_list = []
    fails = {}

    def one(arg):
        h, lang, arch, cmd = arg
        r = subprocess.run(cmd + ["-fsyntax-only", "-x", lang, "-"], input="#include <%s>\n" % h,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        return h, r.returncode

    work = []
    for h in hs:
        for arch in ("x86_64", "arm64"):
            for lang, std in (("c", "-std=gnu11"), ("c++", "-std=gnu++17")):
                work.append((h, lang, arch, [clang, "-target", "%s-apple-macosx%s" % (arch, sdkv), "-isysroot", sdk, std,
                                             "-Wno-everything"]))
        if gcc:
            for lang, std in (("c", "-std=gnu11"), ("c++", "-std=gnu++17")):
                work.append((h, lang, "x86_64", gcc + ["-isysroot", sdk, std, "-w"]))
    with ThreadPoolExecutor(max_workers=jobs) as ex:
        for h, rc in ex.map(one, work):
            if rc != 0:
                fails[h] = True
    failed = sorted(fails)
    allow = set()
    if os.path.exists(ALLOW):
        with open(ALLOW) as f:
            allow = {l.strip() for l in f if l.strip() and not l.startswith("#")}
    if update:
        with open(ALLOW, "w") as f:
            f.write("# Headers of usr/include that do not compile on their own with clang or GCC (C and C++):\n"
                    "# they need another header first, are for the kernel, or depend on a macro.  Paths only.\n"
                    "# Written by tests/sdk-check.sh --update-allow; the SDK is checked for new failures against it.\n")
            for h in sorted(set(failed) | allow):
                f.write(h + "\n")
        rep.info("headers: allow list written (%d entries)" % len(set(failed) | allow))
        return
    new = [h for h in failed if h not in allow]
    stale = sorted(h for h in allow if h not in fails and h in set(hs))
    for h in new:
        rep.error("header %s does not compile on its own" % h)
    rep.info("headers: %d checked (clang C and C++, x86_64 and arm64%s), %d fail, %d of them are in the allow list; %d allow entries now pass"
             % (len(hs), ", GCC x86_64" if gcc else "", len(failed), len(failed) - len(new), len(stale)))


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        sys.stdout.write(__doc__)
        return 2
    sdk = os.path.abspath(argv[1])
    clang = "clang"
    gcc = None
    jobs = os.cpu_count() or 4
    update = no_headers = False
    a = argv[2:]
    while a:
        if a[0] == "--clang":
            clang = a[1]; a = a[2:]
        elif a[0] == "--gcc":
            gcc = shlex.split(a[1]); a = a[2:]
        elif a[0] == "--jobs":
            jobs = int(a[1]); a = a[2:]
        elif a[0] == "--update-allow":
            update = True; a = a[1:]
        elif a[0] == "--no-headers":
            no_headers = True; a = a[1:]
        else:
            sys.stderr.write("sdk-check.py: unknown option %s\n" % a[0])
            return 2
    rep = Report()
    core = None
    if os.path.isdir(os.path.join(sdk, "System", "Library", "Frameworks", "CoreFoundation.framework")):
        core = False
    elif os.path.isfile(os.path.join(sdk, "OpenSDK.json")):
        core = True
    check_files(sdk, rep, core)
    check_tbd(sdk, rep)
    if not no_headers:
        run_headers(sdk, clang, gcc, jobs, rep, update)
    print("%d errors" % rep.errors)
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
