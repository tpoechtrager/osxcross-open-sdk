#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Install the public xnu headers the way xnu's installhdrs does.

xnu's Makefiles list the user-visible headers (INSTALL_MI_LIST,
INSTALL_MD_LIST, ...) and install them with unifdef.  The real build needs
Xcode tools, so this script evaluates the Makefiles with a stub MakeInc.*
and applies the same unifdef flags (SINCFRAME_UNIFDEF) itself.

usage: xnu_headers.py XNU_SRC DESTDIR UNIFDEF DECOMMENT
       xnu_headers.py XNU_SRC --print-flags
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

ARCHES = ["X86_64", "ARM64"]
VARS = ["INSTALL_MI_LIST", "INSTALL_MI_DIR", "INSTALL_MD_LIST", "INSTALL_MD_DIR",
        "INSTALL_MI_GEN_LIST", "INSTALL_MD_GEN_LIST",
        "INSTALL_MODULEMAP_MI_LIST", "INSTALL_MODULEMAP_MI_DIR",
        "INSTALL_MODULEMAP_MD_LIST", "INSTALL_MODULEMAP_MD_DIR",
        "INSTINC_SUBDIRS", "INSTINC_SUBDIRS_X86_64", "INSTINC_SUBDIRS_ARM64"]

PLATFORMS = ("MacOSX DriverKit ExclaveKit ExclaveCore iPhoneSimulator "
             "iPhoneNanoSimulator tvSimulator AppleTVSimulator WatchSimulator "
             "iPhoneOS iPhoneOSNano tvOS AppleTVOS WatchOS BridgeOS").split()

XNU_PRIVATE = ["-UMACH_KERNEL_PRIVATE", "-UBSD_KERNEL_PRIVATE", "-UIOKIT_KERNEL_PRIVATE",
               "-ULIBKERN_KERNEL_PRIVATE", "-ULIBSA_KERNEL_PRIVATE",
               "-UPEXPERT_KERNEL_PRIVATE", "-UXNU_KERNEL_PRIVATE"]


def platform_prefix(src):
    """xnu before about 10002 names the unifdef guards PLATFORM_<name>, later
    releases XNU_PLATFORM_<name>; MakeInc.def says which one is in use."""
    try:
        t = open(os.path.join(src, "makedefs", "MakeInc.def")).read()
    except OSError:
        return "XNU_PLATFORM_"
    return "XNU_PLATFORM_" if "-DXNU_PLATFORM_" in t else "PLATFORM_"


def unifdef_flags(prefix="XNU_PLATFORM_"):
    f = []
    for p in PLATFORMS:
        f.append(("-D%s%s" if p == "MacOSX" else "-U%s%s") % (prefix, p))
    f += XNU_PRIVATE
    f += ["-UKERNEL_PRIVATE", "-UKERNEL", "-UDRIVERKIT", "-UEXCLAVEKIT", "-UEXCLAVECORE",
          "-USCHED_TEST_HARNESS"]
    f += ["-UPRIVATE", "-D_OPEN_SOURCE_", "-D__OPEN_SOURCE__"]
    return f


def vpaths(src, d):
    out = []
    try:
        text = open(os.path.join(src, d, "Makefile")).read()
    except OSError:
        return out
    for m in re.finditer(r"^VPATH\s*:?=\s*\$\(VPATH\):\$\(SOURCE\)/(\S+)", text, re.M):
        out.append(os.path.normpath(os.path.join(src, d, m.group(1))))
    return out


class Evaluator:
    def __init__(self, src, tmpdir):
        self.src = src
        # next to the output, not in /tmp: removed again by close()
        self.stub = tempfile.mkdtemp(prefix="xnu-stub-", dir=tmpdir)
        for n in ("cmd", "def", "rule", "dir"):
            open(os.path.join(self.stub, "MakeInc." + n), "w").close()

    def close(self):
        shutil.rmtree(self.stub, ignore_errors=True)

    def eval(self, d, arch):
        mk = os.path.join(self.src, d, "Makefile")
        wrapper = os.path.join(self.stub, "dump.mk")
        with open(wrapper, "w") as f:
            f.write("SRCROOT := %s\nPLATFORM := MacOSX\nCURRENT_ARCH_CONFIG := %s\n"
                    "CURRENT_MACHINE_CONFIG := NONE\n" % (self.src, arch))
            f.write("SUPPORTED_EMBEDDED_PLATFORMS := iPhoneOS iPhoneOSNano tvOS AppleTVOS WatchOS BridgeOS\n"
                    "SUPPORTED_SIMULATOR_PLATFORMS := iPhoneSimulator iPhoneNanoSimulator tvSimulator AppleTVSimulator WatchSimulator\n")
            f.write("include %s\n" % mk)
            f.write("export MakeInc_cmd := %s/MakeInc.cmd\n" % self.stub)
            f.write("dump:\n")
            for v in VARS:
                f.write("\t@echo '@@%s=$(strip $(%s))'\n" % (v, v))
        env = dict(os.environ)
        # The Makefiles ask xcrun for tools.  On a Mac that runs the real xcrun
        # (seconds per call, hundreds of calls).  `false` finds nothing, which is
        # what a Linux host without xcrun answers.
        extra = []
        if os.path.exists("/usr/bin/xcrun") and os.path.exists("/usr/bin/false"):
            extra = ["XCRUN=/usr/bin/false"]
        for n in ("cmd", "def", "rule", "dir"):
            env["MakeInc_" + n] = os.path.join(self.stub, "MakeInc." + n)
        r = subprocess.run([os.environ.get("MAKE", "make"), "-s", "-r"] + extra + ["-f", wrapper, "dump"], cwd=os.path.join(self.src, d),
                           env=env, capture_output=True, text=True)
        if r.returncode:
            sys.stderr.write("xnu_headers.py: make failed in %s: %s\n" % (d, r.stderr[-500:]))
            return None
        out = {}
        for line in r.stdout.splitlines():
            if line.startswith("@@"):
                k, _, v = line[2:].partition("=")
                out[k] = v.split()
        return out


def walk(ev, d, arch, seen, result):
    key = (d, arch)
    if key in seen or not os.path.exists(os.path.join(ev.src, d, "Makefile")):
        return
    seen.add(key)
    vals = ev.eval(d, arch)
    if vals is None:
        return
    result.append((d, vals))
    for sd in vals.get("INSTINC_SUBDIRS", []) + vals.get("INSTINC_SUBDIRS_" + arch, []):
        walk(ev, os.path.normpath(os.path.join(d, sd)), arch, seen, result)


MIN_FILES = 300


def main(argv):
    p = argparse.ArgumentParser(prog="xnu_headers.py", description="Install the public xnu headers.")
    p.add_argument("xnu_src")
    p.add_argument("--print-flags", action="store_true",
                   help="only print the unifdef flags for the headers of that xnu")
    p.add_argument("rest", nargs="*", metavar="DESTDIR UNIFDEF DECOMMENT")
    a = p.parse_args(argv[1:])
    if a.print_flags:
        print(" ".join(unifdef_flags(platform_prefix(a.xnu_src))))
        return 0
    if len(a.rest) != 3:
        p.error("DESTDIR, UNIFDEF and DECOMMENT are needed")
    src = a.xnu_src
    dest, unifdef, decomment = a.rest
    flags = unifdef_flags(platform_prefix(src))
    os.makedirs(dest, exist_ok=True)
    ev = Evaluator(src, os.path.dirname(os.path.abspath(dest)))
    try:
        run(ev, src, dest, unifdef, decomment, flags)
    finally:
        ev.close()
    return 0


def run(ev, src, dest, unifdef, decomment, flags):
    installed = {}
    missing = []
    failed = 0
    for arch in ARCHES:
        result = []
        seen = set()
        tops = ("security", "bsd", "osfmk", "pexpert", "libkern", "libsa", "san", "EXTERNAL_HEADERS")
        for top in tops:
            walk(ev, top, arch, seen, result)
        for d, vals in result:
            mi_dir = (vals.get("INSTALL_MI_DIR") or ["."])[0]
            md_dir = (vals.get("INSTALL_MD_DIR") or ["."])[0]
            for lst, dd in (("INSTALL_MI_LIST", mi_dir), ("INSTALL_MD_LIST", md_dir),
                            ("INSTALL_MI_GEN_LIST", mi_dir), ("INSTALL_MD_GEN_LIST", md_dir)):
                for fn in vals.get(lst, []):
                    srcf = os.path.join(src, d, fn)
                    if lst.endswith("GEN_LIST"):
                        # generated headers: copy from a VPATH directory when
                        # one has the file (mach/i386/asm.h <- osfmk/i386/asm.h)
                        srcf = None
                        for vp in vpaths(src, d):
                            if os.path.exists(os.path.join(vp, fn)):
                                srcf = os.path.join(vp, fn)
                                break
                        if srcf is None:
                            missing.append((arch, os.path.join(dd, fn)))
                            continue
                    if not os.path.exists(srcf):
                        missing.append((arch, srcf))
                        continue
                    dst = os.path.normpath(os.path.join(dest, "usr/include", dd, fn))
                    r = subprocess.run([unifdef] + flags + [srcf], capture_output=True)
                    if r.returncode == 2:
                        sys.stderr.write("xnu_headers.py: unifdef failed: %s\n" % srcf)
                        failed += 1
                        continue
                    content = r.stdout
                    # xnu drops files that are empty after comment removal
                    p = subprocess.run([decomment, "/dev/stdin", "r"], input=content, capture_output=True)
                    if not p.stdout.strip():
                        continue
                    if dst in installed and installed[dst] != content:
                        sys.stderr.write("xnu_headers.py: note: %s differs between archs\n" % dst)
                    installed[dst] = content
    for dst, content in installed.items():
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.lexists(dst):
            os.unlink(dst)
        with open(dst, "wb") as f:
            f.write(content)
    gen = sorted(set(m[1] for m in missing))
    with open(os.path.join(dest, ".xnu-generated-list"), "w") as f:
        f.write("\n".join(gen) + "\n")
    print("installed %d files; %d generated/missing entries" % (len(installed), len(gen)))
    # a Makefile that lists nothing (wrong path, a release that is built
    # differently) must not look like a success; a full tree has about 500
    if failed or len(installed) < MIN_FILES:
        sys.stderr.write("xnu_headers.py: %d files failed, %d installed (at least %d expected)\n"
                         % (failed, len(installed), MIN_FILES))
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
