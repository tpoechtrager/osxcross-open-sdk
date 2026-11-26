#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""scrub_platforms.py -- remove platform names that GCC does not know from the
availability annotations of the installed headers.

Apple's open source projects (Libc, libpthread, dyld, ...) name `bridgeos` in
__API_AVAILABLE/__API_UNAVAILABLE lists.  Clang accepts the platform, but GCC
(the Darwin port of Iain Sandoe: `availability` attribute) rejects it with
"platform 'bridgeos' is not recognised".  The scrub is purely textual and only
touches the argument lists of the __API_* macros.

usage: scrub_platforms.py <include-dir> <notice-date>

Every changed header gets the notice of notice.py.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notice  # noqa: E402

PLATFORMS = ("bridgeos",)

def scrub(text, plat):
    n = 0
    def sub(rx, rep):
        nonlocal text, n
        text, k = rx.subn(rep, text)
        n += k
    p = re.escape(plat)
    # __API_UNAVAILABLE(bridgeos) / __API_UNAVAILABLE(bridgeos, driverkit)
    sub(re.compile(r"__API_UNAVAILABLE\(\s*%s\s*\)[ \t]*" % p), "")
    # list element with a version: ", bridgeos(7.0)"
    sub(re.compile(r",\s*%s\([^()]*\)" % p), "")
    # first element with a version: "(bridgeos(7.0), ..."
    sub(re.compile(r"\(\s*%s\([^()]*\)\s*,\s*" % p), "(")
    # plain list element: ", bridgeos"
    sub(re.compile(r",\s*%s\b(?!\s*\()" % p), "")
    sub(re.compile(r"\(\s*%s\s*,\s*" % p), "(")
    return text, n

def main(argv):
    p = argparse.ArgumentParser(prog="scrub_platforms.py", description="Remove bridgeos from availability annotations.")
    p.add_argument("include_dir")
    p.add_argument("notice_date")
    a = p.parse_args(argv[1:])
    root, date = a.include_dir, a.notice_date
    total = files = 0
    for d, _, names in os.walk(root):
        for name in names:
            if not name.endswith((".h", ".hpp", ".defs", ".modulemap")):
                continue
            path = os.path.join(d, name)
            if os.path.islink(path) or name.startswith("AvailabilityInternal"):
                continue
            with open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
                t = f.read()
            if not any(p in t for p in PLATFORMS):
                continue
            o = t
            for p in PLATFORMS:
                t, n = scrub(t, p)
                total += n
            if t != o:
                files += 1
                with open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
                    f.write(t)
                notice.add_notice(path, date, "the platform bridgeos removed from the availability macros")
    print("scrub_platforms.py: %d substitutions in %d files" % (total, files))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
