#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Make .tbd stubs for the Swift runtime libraries of a swift.org macOS
toolchain package (Apache 2.0 licensed, redistributable).

usage: swift_stubs.py DYLIB_DIR OUT_DIR LLVM_BIN MK_TBD
LLVM_BIN has llvm-otool and llvm-nm; MK_TBD is helpers/mk_tbd.py.
"""
import argparse
import glob
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from clang_scan import ARCHS  # noqa: E402


def main(argv):
    p = argparse.ArgumentParser(prog="swift_stubs.py", description="Stubs of the Swift runtime libraries.")
    p.add_argument("dylib_dir")
    p.add_argument("out_dir")
    p.add_argument("llvm_bin")
    p.add_argument("mk_tbd")
    a = p.parse_args(argv[1:])
    src, out, llvm, mk = a.dylib_dir, a.out_dir, a.llvm_bin, a.mk_tbd
    os.makedirs(out, exist_ok=True)
    for dy in sorted(glob.glob(os.path.join(src, "*.dylib"))):
        base = os.path.basename(dy)[:-6]
        inst = subprocess.run([llvm + "/llvm-otool", "-arch", "x86_64", "-D", dy],
                              capture_output=True, text=True).stdout.split("\n")[1].strip()
        if not inst.startswith("/usr/lib/swift/"):
            continue
        with tempfile.NamedTemporaryFile("w", delete=False) as f:
            for arch in ARCHS:
                r = subprocess.run([llvm + "/llvm-nm", "-g", "--defined-only", "--arch=" + arch, dy],
                                   capture_output=True, text=True)
                for l in r.stdout.splitlines():
                    w = l.split()
                    if len(w) == 3 and w[1] != "U":
                        f.write("%s %s\n" % (arch, w[2]))
            name = f.name
        subprocess.run([sys.executable, "-I", mk, os.path.join(out, base + ".tbd"), inst, "1.0", name, "--compat", "1"], check=True)
        os.unlink(name)
        print(base, inst)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
