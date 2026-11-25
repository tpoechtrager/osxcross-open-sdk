# SPDX-License-Identifier: GPL-2.0-only
"""The clang command line prefix of the symbol scans (gen_symbols.py, hdr_syms.py).

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
        raise SystemExit("clang_target.py: %s -dM -E failed:\n%s" % (clang, r.stderr[:2000]))
    args = ["-target", target]
    if "__ENVIRONMENT_OS_VERSION_MIN_REQUIRED__" not in r.stdout:
        args.append("-D__ENVIRONMENT_OS_VERSION_MIN_REQUIRED__=" + VALUE)
    return args
