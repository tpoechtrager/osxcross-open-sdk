#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Write libc++'s __config_site for macOS from the upstream template.

usage: cxx_site.py __config_site.in OUT

Upstream creates the file with CMake (#cmakedefine).  The names and the
meaning of the options change from release to release, so the template of
the release in use is filled in here, with the values of a libc++ for macOS:
ABI version 1, pthreads, vendor availability annotations on, libdispatch as
the parallel STL backend, no hardening.  Options that the template does not
list are not written; options that the table does not know are off.
"""
import re
import sys

VALUES = {
    "_LIBCPP_ABI_VERSION": "1",
    "_LIBCPP_ABI_NAMESPACE": "__1",
    "_LIBCPP_HAS_THREADS": 1,
    "_LIBCPP_HAS_MONOTONIC_CLOCK": 1,
    "_LIBCPP_HAS_TERMINAL": 1,
    "_LIBCPP_HAS_THREAD_API_PTHREAD": 1,
    "_LIBCPP_HAS_VENDOR_AVAILABILITY_ANNOTATIONS": 1,
    "_LIBCPP_HAS_FILESYSTEM": 1,
    "_LIBCPP_HAS_RANDOM_DEVICE": 1,
    "_LIBCPP_HAS_LOCALIZATION": 1,
    "_LIBCPP_HAS_UNICODE": 1,
    "_LIBCPP_HAS_WIDE_CHARACTERS": 1,
    "_LIBCPP_HAS_TIME_ZONE_DATABASE": 0,  # macOS has no tzdata.zi to read
    "_LIBCPP_PSTL_BACKEND_LIBDISPATCH": "",
    "_LIBCPP_PSTL_CPU_BACKEND_LIBDISPATCH": "",
    "_LIBCPP_HARDENING_MODE_DEFAULT": "_LIBCPP_HARDENING_MODE_NONE",
    "_LIBCPP_ASSERTION_SEMANTIC_DEFAULT": "_LIBCPP_ASSERTION_SEMANTIC_ENFORCE",
}
# older templates (LLVM 16 to 18) use negative names for the same options
OFF_BY_DEFAULT = {"_LIBCPP_ENABLE_ASSERTIONS_DEFAULT": 0}


def main():
    src, out = sys.argv[1:3]
    res = []
    for line in open(src).read().splitlines():
        m = re.match(r"#cmakedefine01\s+(\w+)", line)
        if m:
            res.append("#define %s %d" % (m.group(1), int(VALUES.get(m.group(1), 0) or 0)))
            continue
        m = re.match(r"#cmakedefine\s+(\w+)(?:\s+(.*))?$", line)
        if m:
            k = m.group(1)
            if k in VALUES:
                v = VALUES[k]
                res.append("#define %s%s" % (k, (" " + str(v)) if str(v) else ""))
            else:
                res.append("/* #undef %s */" % k)
            continue
        line = re.sub(r"@\w+@", "", line)
        res.append(line)
    open(out, "w").write("\n".join(res) + "\n")


main()
