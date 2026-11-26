# SPDX-License-Identifier: GPL-2.0-only
"""What the symbol scans (libsystem_syms.py, header_syms.py) share: the architectures,
the clang command line prefix and the test of a declaration.

Clang 17 and later define __ENVIRONMENT_OS_VERSION_MIN_REQUIRED__ for the
target, which AvailabilityInternal.h (from Apple's open source release of
the headers) uses for __MAC_OS_X_VERSION_MIN_REQUIRED. Older clang only
defines __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__; the missing macro reads
as 0 and headers such as dirent.h then take their "before macOS 10.8" branch
(dirfd as a macro, no declaration), so the symbol would be lost. The macro is
defined here with the value of the target when the clang in use lacks it.

The clang of FreeBSD and OpenBSD lacks some of the headers that a clang provides
itself (stdbool.h, stdarg.h, float.h; the system's own are in /usr/include, which -isysroot
hides), but the headers of the SDK include them (mach/vm_statistics.h, mach/mach_init.h, CoreFoundation.h).
Then the definitions of ISO C99 (7.16, 7.15, 5.2.4.2.2) are supplied in a directory of their own."""
import atexit
import os
import shutil
import subprocess
import tempfile

VERSION = "14.0"
VALUE = "140000"  # the same, as the number clang gives the target

def float_h():
    """float.h of ISO C99/C11 5.2.4.2.2: every macro is clang's predefined __NAME__ of the type
    (HAS_SUBNORM is HAS_DENORM and TRUE_MIN is DENORM_MIN there)."""
    names = ("MANT_DIG", "DIG", "MIN_EXP", "MIN_10_EXP", "MAX_EXP", "MAX_10_EXP", "MAX", "EPSILON", "MIN",
             "HAS_SUBNORM", "TRUE_MIN")
    predefined = {"HAS_SUBNORM": "HAS_DENORM", "TRUE_MIN": "DENORM_MIN"}
    out = ["#define FLT_RADIX __FLT_RADIX__\n#define FLT_EVAL_METHOD __FLT_EVAL_METHOD__\n#define FLT_ROUNDS 1\n"
           "#define DECIMAL_DIG __DECIMAL_DIG__\n"]
    for pre, typ in (("FLT", "FLT"), ("DBL", "DBL"), ("LDBL", "LDBL")):
        out += ["#define %s_%s __%s_%s__\n" % (pre, n, typ, predefined.get(n, n)) for n in names]
        out.append("#define %s_DECIMAL_DIG __%s_DECIMAL_DIG__\n" % (pre, typ))
    return "".join(out)


# the headers of the C standard that a freestanding compiler provides, by name
FALLBACK_HEADERS = {
    "float.h": float_h(),
    "stdbool.h": "#ifndef __cplusplus\n#define bool _Bool\n#define true 1\n#define false 0\n#endif\n"
                 "#define __bool_true_false_are_defined 1\n",
    "stdarg.h": "typedef __builtin_va_list va_list;\n"
                "#define va_start(ap, param) __builtin_va_start(ap, param)\n"
                "#define va_end(ap) __builtin_va_end(ap)\n"
                "#define va_arg(ap, type) __builtin_va_arg(ap, type)\n"
                "#define va_copy(dest, src) __builtin_va_copy(dest, src)\n",
}
_FALLBACK_DIR = None


def lacks_header(clang, target, name):
    """True if clang does not find <NAME> with a sysroot that has no headers."""
    empty = tempfile.mkdtemp(prefix="open-sdk-")
    try:
        r = subprocess.run([clang, "-target", target, "-isysroot", empty, "-fsyntax-only", "-x", "c", "-"],
                           input="#include <%s>\n" % name, capture_output=True, text=True)
    finally:
        shutil.rmtree(empty)
    return r.returncode != 0


def fallback_dir(clang, target):
    """A directory with the headers of FALLBACK_HEADERS that clang lacks (removed at exit),
    or None if it has them all."""
    global _FALLBACK_DIR
    if _FALLBACK_DIR is None:
        missing = [n for n in sorted(FALLBACK_HEADERS) if lacks_header(clang, target, n)]
        _FALLBACK_DIR = tempfile.mkdtemp(prefix="open-sdk-cstd-") if missing else ""
        if missing:
            atexit.register(shutil.rmtree, _FALLBACK_DIR, True)
        for n in missing:
            with open(os.path.join(_FALLBACK_DIR, n), "w") as f:
                f.write(FALLBACK_HEADERS[n])
    return _FALLBACK_DIR or None


def target_args(clang, arch):
    target = arch + "-apple-macosx" + VERSION
    r = subprocess.run([clang, "-target", target, "-dM", "-E", "-x", "c", "/dev/null"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("clang_scan.py: %s -dM -E failed:\n%s" % (clang, r.stderr[:2000]))
    args = ["-target", target]
    d = fallback_dir(clang, target)
    if d:
        args += ["-isystem", d]
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
