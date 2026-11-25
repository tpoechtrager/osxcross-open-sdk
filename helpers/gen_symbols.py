#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Derive the exported symbol list of libSystem from the installed headers.

usage: gen_symbols.py SDKROOT CLANG OUTFILE SRCDIR [ERRORFILE [SYSCALLS_FILE]]
Runs clang's AST dump (JSON) over one translation unit per architecture that
includes the userland headers, and records every external function/variable
declaration (honouring asm labels such as _stat$INODE64).
Output: lines "ARCH symbol" (ARCH = x86_64 | arm64).
"""
import json, os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from clang_target import target_args

sdk, clang, out, srcdir = sys.argv[1:5]
errfile = open(sys.argv[5], "w") if len(sys.argv) > 5 else sys.stderr
errfile.write("# The headers are read in several modes, strict POSIX and XOPEN among them, and clang\n"
              "# reports errors for headers that are not meant for such a mode. That is expected\n"
              "# and does not affect the SDK.\n")
syscalls_file = sys.argv[6] if len(sys.argv) > 6 else None
inc = os.path.join(sdk, "usr/include")
SKIP_DIRS = {"c++", "kern", "vfs", "miscfs", "nfs", "pexpert", "default_pager", "device", "corpses",
             "atm", "bank", "security", "netkey", "i386", "arm", "arm64", "machine", "objc",
             "architecture", "mach_debug", "sys/_types", "_types", "secure",
             "mach/i386", "mach/arm", "mach/machine", "libkern/i386", "libkern/arm", "libkern/machine",
             "mach-o/x86_64", "mach-o/arm", "mach-o/arm64", "mach-o/i386"}
SKIP_FILES = {"sys/ubc.h", "servers/key_defs.h", "rpcsvc/yp_prot.h", "nlist.h", "sys/_posix_availability.h", "sys/_symbol_aliasing.h", "string_x86.h", "pexpert/pexpert.h",
              "sys/dtrace_impl.h", "mach/mach_eventlink.h", "libkern/OSTypes.h",
              "dispatch/dispatch_swift_shims.h", "netinet6/in6.h", "netinet6/nd6.h", "mpool.h",
              # libresolv.9.dylib, not libSystem: its own stub (step stubs, libresolv/xcodescripts/links.sh)
              "resolv.h", "nameser.h", "arpa/nameser.h", "dns.h", "dns_util.h",
              # the introspection variant of libdispatch (INSTALL_PATH /usr/lib/system/introspection in
              # libdispatch/xcodeconfig/libdispatch-introspection.xcconfig), not libdispatch itself
              "dispatch/introspection.h"}
SKIP_TOP = {"libkern/OSByteOrder.h"}

# Only the headers of the step "headers" (the list is made there): headers of
# libraries that later steps install must not change the symbols of libSystem
# when the step runs again.
listfile = os.path.join(sdk, "work", "headers.list")
only = set(open(listfile).read().split("\n")) if os.path.exists(listfile) else None

hdrs = []
for root, dirs, files in os.walk(inc):
    rel = os.path.relpath(root, inc)
    if rel == ".":
        rel = ""
    if any(rel == d or rel.startswith(d + "/") for d in SKIP_DIRS):
        continue
    for f in files:
        if not f.endswith(".h"):
            continue
        p = os.path.join(rel, f)
        if only is not None and p not in only:
            continue
        if p in SKIP_FILES or "private" in f:
            continue
        hdrs.append(p)
hdrs.sort()

MODES = [[], ["-D_DARWIN_C_SOURCE", "-D_USE_EXTENDED_LOCALES_"], ["-D_DARWIN_C_SOURCE"], ["-D_POSIX_C_SOURCE=200809L"], ["-D_XOPEN_SOURCE=700"]]

# The legacy symbols of x86_64 (_select, _opendir, _glob, ...): Libc and
# Libsyscall build a "legacy" variant of the functions with the macros
# below (Libc/xcodescripts/variants.xcconfig, VARIANT_LEGACY_MACROS).  Their
# names are the plain ones that headers give without UNIX03 and 64-bit
# inodes; configure scripts probe for them.  arm64 has no such variant (its
# headers give the plain names already).
LEGACY_MODE = ["-U__DARWIN_UNIX03", "-D__DARWIN_UNIX03=0", "-U__DARWIN_64_BIT_INO_T", "-D__DARWIN_64_BIT_INO_T=0"]

def symbols(arch):
    syms = set()
    inl = set()
    for mode in MODES + ([LEGACY_MODE] if arch == "x86_64" else []):
        a, b = symbols_mode(arch, mode)
        syms |= a; inl |= b
    return syms, inl

def symbols_mode(arch, mode):
    syms = set()
    inl = set()
    with tempfile.TemporaryDirectory() as td:
        src = os.path.join(td, "all.c")
        with open(src, "w") as f:
            f.write("#include <sys/cdefs.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <stddef.h>\n#include <stdint.h>\n"
                    "#include <sys/types.h>\n#include <sys/socket.h>\n#include <netinet/in.h>\n#include <pthread.h>\n"
                    "#include <mach/mach.h>\n#include <unistd.h>\n#include <dispatch/dispatch.h>\n")
            for h in hdrs:
                f.write('#if __has_include(<%s>)\n#include <%s>\n#endif\n' % (h, h))
        r = subprocess.run([clang] + target_args(clang, arch) + ["-isysroot", sdk, "-fsyntax-only"] + mode + [
                            "-fno-color-diagnostics", "-ferror-limit=0", "-Xclang", "-ast-dump=json", src],
                           capture_output=True, text=True)
        for l in r.stderr.splitlines():
            if "error:" in l:
                errfile.write(l[:300] + "\n")
        try:
            d = json.loads(r.stdout)
        except ValueError:
            sys.stderr.write("gen_symbols.py: clang gave no AST for %s\n" % arch)
            sys.exit(1)
    for n in d["inner"]:
        k = n.get("kind")
        if k not in ("FunctionDecl", "VarDecl"):
            continue
        if n.get("isImplicit"):
            continue
        if n.get("storageClass") == "static" or n.get("inline"):
            if k == "FunctionDecl" and n.get("name"):
                inl.add(n["name"])
            continue
        if k == "VarDecl" and n.get("storageClass") != "extern":
            continue
        if any(i.get("kind") == "CompoundStmt" for i in n.get("inner", [])):
            continue
        m = n.get("mangledName")
        if not m:
            continue
        if m.startswith("\x01"):
            m = m[1:]
        syms.add(m)
    return syms, inl

import re
# --- evidence: a declared symbol must be mentioned in userland sources --------
USERLAND = ["Libc", "libpthread", "libplatform", "libmalloc", "Libinfo", "libdispatch", "libresolv", "Libnotify",
            "copyfile", "removefile", "Libm", "dyld", "libunwind", "syslog", "Libsystem", "libclosure",
            "architecture", "cctools/libmacho", "xnu/libsyscall", "xnu/osfmk/mach",
            "xnu/libkern/os", "xnu/libkern/libkern/OSAtomic.h"]
EXT = (".c", ".m", ".mm", ".s", ".S", ".defs", ".map", ".list", ".aliases", ".master", ".exp", ".cpp", ".y", ".l", ".h")
tok = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
corpus = set()
defs0 = set()
col0 = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\(", re.M)
for u in USERLAND:
    base = os.path.join(srcdir, u)
    paths = []
    if os.path.isfile(base):
        paths = [base]
    else:
        for root, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in (".git", "tests", "test", "man")]
            for fn in files:
                if fn.endswith(EXT):
                    if u == "xnu/osfmk/mach" and not fn.endswith((".defs", ".h")):
                        continue
                    paths.append(os.path.join(root, fn))
    for pth in paths:
        try:
            txt = open(pth, errors="replace").read()
            corpus.update(tok.findall(txt))
            if not pth.endswith(".h"):
                defs0.update(col0.findall(txt))
        except OSError:
            pass

def has_evidence(sym):
    n = sym[1:] if sym.startswith("_") else sym
    return n.split("$")[0] in corpus or sym.split("$")[0] in corpus

def alias_pairs():
    """alias files: '<symbol> <alias>' per line"""
    files = ["Libc/xcodescripts/alias.list", "libpthread/xcodescripts/pthread.aliases",
             "libplatform/xcodeconfig/libplatform.aliases", "libdispatch/xcodeconfig/libdispatch.aliases"]
    res = []
    for fn in files:
        for l in open(os.path.join(srcdir, fn)):
            l = l.split("#")[0].split()
            if len(l) == 2:
                res.append((l[0], l[1]))
    return res

excluded = set()
for l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data/symbols/libsystem-exclude.txt")):
    l = l.split("#")[0].split()
    if len(l) == 1:
        excluded.add(l[0])

with open(out, "w") as f:
    for arch in ("x86_64", "arm64"):
        syms, inl = symbols(arch)
        kept = {s for s in syms if has_evidence(s)}
        # functions that are inline in the headers but also have an out-of-line
        # definition in the libraries (ctype, htonl, ...)
        kept |= {"_" + n for n in inl if n in defs0}
        # ctype/wctype/byte-order helpers are inline in the headers, but the
        # library also exports out-of-line copies (generated by macros that a
        # text search does not find)
        helper = re.compile(r"(isw?|tow?)[a-z]+|digittoint|ishexnumber|isnumber|isspecial|isideogram|isphonogram|isrune|(hton|ntoh)[sl]")
        kept |= {"_" + n for n in inl if helper.fullmatch(n)}
        for a, b in alias_pairs():
            kept.add(b)
        sysmap = [os.path.join(srcdir, "xnu/libsyscall/Platforms/syscall.map")]
        sysmap.append(os.path.join(srcdir, "xnu/libsyscall/Platforms/MacOSX/%s/syscall.map" % ("x86_64" if arch == "x86_64" else "arm64")))
        for m in sysmap:
            for l in open(m):
                p = l.split("#")[0].split()
                if len(p) == 2:
                    kept.add(p[0]); kept.add(p[1])
        # raw system call stubs of libsystem_kernel (___open, ___ulock_wait, ...):
        # the stubs that xnu's create-syscalls.pl makes (helpers/syscall_syms.py)
        if syscalls_file:
            kept |= {l.strip() for l in open(syscalls_file) if l.strip()}
        if arch == "x86_64":
            # Libm's own export list for Intel (libsystem_m)
            for l in open(os.path.join(srcdir, "Libm/Exports/libm_Intel.a.exp")):
                l = l.split("#")[0].strip()
                if l and "*" not in l:
                    kept.add(l)
        for l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data/symbols/libsystem-extra.txt")):
            l = l.split("#")[0].split()
            if len(l) == 1:
                kept.add(l[0])
        kept -= excluded
        for s in sorted(kept):
            f.write("%s %s\n" % (arch, s))
