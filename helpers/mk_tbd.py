#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Write a TAPI text stub (tbd v4).

usage: mk_tbd.py OUT INSTALL_NAME CURRENT_VERSION SYMFILE [--compat V] [--reexport-symbols SYMFILE]
SYMFILE lines: "<arch> <symbol>" with arch x86_64 or arm64 (arm64e/x86_64h
share the symbols of arm64/x86_64).
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from clang_scan import ARCHS  # noqa: E402


def q(s):
    return s if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.]*", s) else "'" + s.replace("'", "''") + "'"

def wrap(items, indent, width=96, first_prefix=""):
    lines, cur = [], ""
    for i, it in enumerate(items):
        piece = it + ("," if i != len(items) - 1 else "")
        if cur and len(cur) + 1 + len(piece) > width:
            lines.append(cur); cur = piece
        else:
            cur = (cur + " " + piece) if cur else piece
    lines.append(cur)
    return ("\n" + " " * indent).join(lines)

def read_arch_symbols(path):
    """{arch: set of symbols} of a file of "<arch> <symbol>" lines"""
    syms = {a: set() for a in ARCHS}
    with open(path) as f:
        for l in f:
            p = l.split()
            if len(p) == 2:
                syms[p[0]].add(p[1])
    return syms


def main(argv):
    ap = argparse.ArgumentParser(prog="mk_tbd.py", description="Write a TAPI text stub (tbd v4).")
    ap.add_argument("out")
    ap.add_argument("install")
    ap.add_argument("current")
    ap.add_argument("symfile")
    ap.add_argument("--compat", help="the compatibility version")
    ap.add_argument("--reexport-symbols", dest="resyms", metavar="SYMFILE",
                    help="symbols re-exported from another library")
    args = ap.parse_args(argv[1:])
    out, install, cur, compat, resyms = args.out, args.install, args.current, args.compat, args.resyms
    syms = read_arch_symbols(args.symfile)
    objc = {a: set() for a in ARCHS}
    eh = {a: set() for a in ARCHS}
    for a_ in ARCHS:
        for n in list(syms[a_]):
            if n.startswith("_OBJC_CLASS_$_"):
                objc[a_].add(n[len("_OBJC_CLASS_$_"):]); syms[a_].discard(n)
            elif n.startswith("_OBJC_EHTYPE_$_"):
                eh[a_].add(n[len("_OBJC_EHTYPE_$_"):]); syms[a_].discard(n)
            elif n.startswith("_OBJC_METACLASS_$_"):
                syms[a_].discard(n)
    tmap = {"x86_64": ["x86_64-macos"], "arm64": ["arm64-macos", "arm64e-macos"]}
    # group: symbols common to both arches, then per arch
    both = syms["x86_64"] & syms["arm64"]
    only = {"x86_64": syms["x86_64"] - both, "arm64": syms["arm64"] - both}
    allt = ["x86_64-macos", "arm64-macos", "arm64e-macos"]
    o = ["--- !tapi-tbd", "tbd-version:     4",
         "targets:         [ %s ]" % ", ".join(allt),
         "install-name:    '%s'" % install, "current-version: %s" % cur]
    if compat: o.append("compatibility-version: %s" % compat)
    o.append("exports:")
    def block(targets, names, key="symbols"):
        if not names: return
        o.append("  - targets:         [ %s ]" % ", ".join(targets))
        o.append("    %s:%s[ %s ]" % (key, " " * (17 - len(key)), wrap([q(n) for n in sorted(names)], 21)))
    block(allt, both)
    block(tmap["x86_64"], only["x86_64"])
    block(tmap["arm64"], only["arm64"])
    ob = objc["x86_64"] & objc["arm64"]
    block(allt, ob, "objc-classes")
    block(tmap["x86_64"], objc["x86_64"] - ob, "objc-classes")
    block(tmap["arm64"], objc["arm64"] - ob, "objc-classes")
    eb = eh["x86_64"] & eh["arm64"]
    block(allt, eb, "objc-eh-types")
    block(tmap["x86_64"], eh["x86_64"] - eb, "objc-eh-types")
    block(tmap["arm64"], eh["arm64"] - eb, "objc-eh-types")
    if resyms:
        # symbols re-exported from another library (as tapi writes them)
        rs = read_arch_symbols(resyms)
        rb = rs["x86_64"] & rs["arm64"]
        o.append("reexports:")
        for tg, names in ((allt, rb), (tmap["x86_64"], rs["x86_64"] - rb), (tmap["arm64"], rs["arm64"] - rb)):
            if names:
                o.append("  - targets:         [ %s ]" % ", ".join(tg))
                o.append("    symbols:          [ %s ]" % wrap([q(n) for n in sorted(names)], 22))
    o.append("...")
    if os.path.lexists(out):
        os.unlink(out)   # never write through a symlink
    with open(out, "w") as f:
        f.write("\n".join(o) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
