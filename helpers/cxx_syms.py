#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Symbol lists for libc++.1 and libc++abi from LLVM's ABI lists.

usage: cxx_syms.py LLVM_PROJECT OUTDIR
writes OUTDIR/libcxx.syms and OUTDIR/libcxxabi.syms ("<arch> <symbol>")
"""
import ast, os, sys

root, out = sys.argv[1:3]
abi = os.path.join(root, "libcxx/lib/abi")
cxx = {}
for arch, tgt in (("x86_64", "x86_64-apple-darwin"), ("arm64", "arm64-apple-darwin")):
    syms = set()
    path = os.path.join(abi, tgt + ".libcxxabi.v1.stable.exceptions.nonew.abilist")
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        d = ast.literal_eval(line)
        if d.get("is_defined"):
            syms.add(d["name"])
    cxx[arch] = syms

def exp(fn):
    s = set()
    for line in open(os.path.join(root, fn)):
        line = line.split("#")[0].strip()
        if line and "*" not in line:
            s.add(line)
    return s

# libc++abi's export lists: LLVM 16 to 18 and 19 and later (the lists were
# split up and renamed)
abiexp = set()
if os.path.exists(os.path.join(root, "libcxxabi/lib/cxxabiv1.exp")):
    names = ("cxxabiv1", "fundamental-types", "itanium-base", "std-misc", "new-delete",
             "std-exceptions", "itanium-exceptions", "personality-v0")
    files = ["libcxxabi/lib/%s.exp" % n for n in names]
else:
    files = ["libcxxabi/lib/itanium-base.exp", "libcxxabi/lib/new-delete.exp",
             "libcxxabi/lib/exceptions.exp", "libcxxabi/lib/personality-v0.exp",
             "libcxx/lib/libc++abi.exp"]
for fn in files:
    abiexp |= exp(fn)
# exported by libc++abi, but not re-exported by libc++
nre = os.path.join(root, "libcxxabi/lib/symbols-not-reexported.exp")
extra_abi = exp("libcxxabi/lib/symbols-not-reexported.exp") if os.path.exists(nre) else set()

with open(os.path.join(out, "libcxx.syms"), "w") as f:
    for arch in ("x86_64", "arm64"):
        for s in sorted(cxx[arch] - abiexp):
            f.write("%s %s\n" % (arch, s))
with open(os.path.join(out, "libcxxabi.syms"), "w") as f:
    for arch in ("x86_64", "arm64"):
        for s in sorted(abiexp | extra_abi):
            f.write("%s %s\n" % (arch, s))
print("libc++ %d/%d symbols, libc++abi %d" % (len(cxx["x86_64"] - abiexp), len(cxx["arm64"] - abiexp), len(abiexp)))
