#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Make .tbd stubs for the Swift runtime libraries of a swift.org macOS
toolchain package (Apache 2.0 licensed, redistributable).
usage: swift_stubs.py DYLIB_DIR OUT_DIR LLVM_BIN MK_TBD"""
import os, subprocess, sys, glob, tempfile
src, out, llvm, mk = sys.argv[1:5]
os.makedirs(out, exist_ok=True)
for dy in sorted(glob.glob(os.path.join(src, "*.dylib"))):
    base = os.path.basename(dy)[:-6]
    inst = subprocess.run([llvm + "/llvm-otool", "-arch", "x86_64", "-D", dy], capture_output=True, text=True).stdout.split("\n")[1].strip()
    if not inst.startswith("/usr/lib/swift/"):
        continue
    with tempfile.NamedTemporaryFile("w", delete=False) as f:
        for arch, a in (("x86_64", "x86_64"), ("arm64", "arm64")):
            r = subprocess.run([llvm + "/llvm-nm", "-g", "--defined-only", "--arch=" + a, dy], capture_output=True, text=True)
            for l in r.stdout.splitlines():
                p = l.split()
                if len(p) == 3 and p[1] not in ("U",):
                    f.write("%s %s\n" % (arch, p[2]))
        name = f.name
    subprocess.run([sys.executable, "-I", mk, os.path.join(out, base + ".tbd"), inst, "1.0", name, "--compat", "1"], check=True)
    os.unlink(name)
    print(base, inst)
