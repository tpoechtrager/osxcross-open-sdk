#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Symbol lists for libc++.1 and libc++abi from LLVM's ABI lists.

usage: cxx_syms.py LLVM_PROJECT OUTDIR
writes OUTDIR/libcxx.syms, OUTDIR/libcxxabi.syms and OUTDIR/libcxxabi-reexported.syms
(the symbols of libc++abi that libc++ re-exports), lines "<arch> <symbol>"
"""
import argparse
import ast
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from clang_scan import ARCHS  # noqa: E402

# the ABI list of each architecture (libcxx/lib/abi/<target>.libcxxabi.v1.stable.exceptions.nonew.abilist)
ABI_TARGET = {"x86_64": "x86_64-apple-darwin", "arm64": "arm64-apple-darwin"}


def abilist(root, arch):
    """The defined symbols of the ABI list of ARCH"""
    syms = set()
    path = os.path.join(root, "libcxx/lib/abi", ABI_TARGET[arch] + ".libcxxabi.v1.stable.exceptions.nonew.abilist")
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = ast.literal_eval(line)
            if d.get("is_defined"):
                syms.add(d["name"])
    return syms


def exp(root, fn):
    """The names of an export list (no patterns)"""
    s = set()
    with open(os.path.join(root, fn)) as f:
        for line in f:
            line = line.split("#")[0].strip()
            if line and "*" not in line:
                s.add(line)
    return s


def abi_exports(root):
    """(the exports of libc++abi, those that libc++ does not re-export)"""
    # libc++abi's export lists: LLVM 16 to 18 and 19 and later (the lists were
    # split up and renamed)
    if os.path.exists(os.path.join(root, "libcxxabi/lib/cxxabiv1.exp")):
        names = ("cxxabiv1", "fundamental-types", "itanium-base", "std-misc", "new-delete",
                 "std-exceptions", "itanium-exceptions", "personality-v0")
        files = ["libcxxabi/lib/%s.exp" % n for n in names]
    else:
        files = ["libcxxabi/lib/itanium-base.exp", "libcxxabi/lib/new-delete.exp",
                 "libcxxabi/lib/exceptions.exp", "libcxxabi/lib/personality-v0.exp",
                 "libcxx/lib/libc++abi.exp"]
    abiexp = set()
    for fn in files:
        abiexp |= exp(root, fn)
    # exported by libc++abi, but not re-exported by libc++
    nre = "libcxxabi/lib/symbols-not-reexported.exp"
    extra_abi = exp(root, nre) if os.path.exists(os.path.join(root, nre)) else set()
    return abiexp, extra_abi


def main(argv):
    p = argparse.ArgumentParser(prog="cxx_syms.py", description="The symbols of libc++ and libc++abi.")
    p.add_argument("llvm_project")
    p.add_argument("outdir")
    a = p.parse_args(argv[1:])
    root, out = a.llvm_project, a.outdir
    cxx = {arch: abilist(root, arch) for arch in ARCHS}
    abiexp, extra_abi = abi_exports(root)
    with open(os.path.join(out, "libcxx.syms"), "w") as f:
        for arch in ARCHS:
            for s in sorted(cxx[arch] - abiexp):
                f.write("%s %s\n" % (arch, s))
    with open(os.path.join(out, "libcxxabi.syms"), "w") as f:
        for arch in ARCHS:
            for s in sorted(abiexp | extra_abi):
                f.write("%s %s\n" % (arch, s))
    # libc++ re-exports the export lists of libc++abi, not the names of
    # symbols-not-reexported.exp (libcxxabi/src/CMakeLists.txt: reexport_symbols, export_symbols)
    with open(os.path.join(out, "libcxxabi-reexported.syms"), "w") as f:
        for arch in ARCHS:
            for s in sorted(abiexp):
                f.write("%s %s\n" % (arch, s))
    print("libc++ %d/%d symbols, libc++abi %d" % (len(cxx["x86_64"] - abiexp), len(cxx["arm64"] - abiexp), len(abiexp)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
