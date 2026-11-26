# SPDX-License-Identifier: GPL-2.0-only
"""What the symbol scans (gen_symbols.py, hdr_syms.py) share: the architectures,
the clang command line prefix and the test of a declaration.

Clang 17 and later define __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__ for the
target, which AvailabilityInternal.h (from Apple's open source release of
the headers) uses for __MAC_OS_X_VERSION_MIN_REQUIRED. Older clang only
defines __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__; the missing macro reads
as 0 and headers such as dirent.h then take their "before macOS 10.8" branch
(dirfd as a macro, no declaration), so the symbol would be lost. The macro is
defined here with the value of the target when the clang in use lacks it."""
import subprocess

VERSION = "14.0"
VALUE = "140000"  # the same, as the number clang gives the target

def target_args(clang, arch):
    target = arch + "-apple-macosx" + VERSION
    r = subprocess.run([clang, "-target", target, "-dM", "-E", "-x", "c", "/dev/null"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("clang_scan.py: %s -dM -E failed:\n%s" % (clang, r.stderr[:2000]))
    args = ["-target", target]
    if "__ENVIRONMENT_OS_VERSION_MIN_REQUIRED__" not in r.stdout:
        args.append("-D__ENVIRONMENT_OS_VERSION_MIN_REQUIRED__=" + VALUE)
    return args


# the architectures of the symbol lists ("ARCH SYMBOL" lines)
ARCHS = ("x86_64", "arm64")


def exported_name(n):
    """The Mach-O name of a node of clang's JSON AST if it declares an exported
    function or variable (not implicit, static, inline or defined in the header;
    a variable only if extern), else None."""
    k = n.get("kind")
    if k not in ("FunctionDecl", "VarDecl") or n.get("isImplicit"):
        return None
    if n.get("storageClass") == "static" or n.get("inline"):
        return None
    if k == "VarDecl" and n.get("storageClass") != "extern":
        return None
    if any(i.get("kind") == "CompoundStmt" for i in n.get("inner", [])):
        return None
    m = n.get("mangledName")
    if not m:
        return None
    return m[1:] if m.startswith("\x01") else m
