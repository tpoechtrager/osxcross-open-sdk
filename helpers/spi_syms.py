#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""spi_syms.py SRCDIR LIST OUT

The private symbols of libSystem of LIST (data/symbols/libsystem-spi.txt:
"<symbol> <project> <header>" lines) that the sources of this release have.
A symbol is taken if the header (a path inside the project) declares its
name and a source file of the project that is not a test names it too; a
symbol whose header lacks the name is left out and printed.  A missing
project or header, or a declared name that no source file names, is an
error: the list does not fit the sources.

Writes "ARCH symbol" lines for every architecture (the symbols are the same
for x86_64 and arm64).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from clang_scan import ARCHS  # noqa: E402
from data_files import lines  # noqa: E402

SOURCES = (".c", ".cpp", ".m", ".mm", ".s", ".S")
SKIP_DIRS = {".git", "test", "tests", "testing", "unit-tests"}


def names_in(path):
    with open(path, errors="replace") as f:
        return set(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", f.read()))


def source_names(project):
    """every name in the source files of PROJECT (without the tests)"""
    res = set()
    for root, dirs, files in os.walk(project):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for fn in sorted(files):
            if fn.endswith(SOURCES):
                res |= names_in(os.path.join(root, fn))
    return res


def spi_symbols(srcdir, entries):
    """(symbols, left out, errors) for ENTRIES [(symbol, project, header)]"""
    syms, missing, errors = [], [], []
    cache = {}
    for sym, proj, hdr in entries:
        name = sym[1:]
        pdir = os.path.join(srcdir, proj)
        hpath = os.path.join(pdir, hdr)
        if not os.path.isfile(hpath):
            errors.append("%s: no %s/%s" % (sym, proj, hdr))
            continue
        if name not in names_in(hpath):
            missing.append(sym)
            continue
        if proj not in cache:
            cache[proj] = source_names(pdir)
        if name not in cache[proj]:
            errors.append("%s: %s/%s declares it, but no source file of %s names it" % (sym, proj, hdr, proj))
            continue
        syms.append(sym)
    return syms, missing, errors


def main(argv):
    if len(argv) != 3:
        sys.exit("usage: spi_syms.py SRCDIR LIST OUT")
    srcdir, listfile, out = argv
    entries = []
    for w in lines(listfile):
        if len(w) != 3 or not w[0].startswith("_"):
            sys.exit("spi_syms.py: %s: bad line: %s" % (listfile, " ".join(w)))
        entries.append(tuple(w))
    syms, missing, errors = spi_symbols(srcdir, entries)
    if errors:
        sys.exit("spi_syms.py: " + "\nspi_syms.py: ".join(errors))
    if missing:
        print("not in the sources of this release: " + " ".join(missing))
    with open(out, "w") as f:
        for a in ARCHS:
            for s in syms:
                f.write("%s %s\n" % (a, s))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
