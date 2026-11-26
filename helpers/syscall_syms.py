#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""syscall_syms.py XNU_DIR WORK_DIR OUT

The system call stubs that libsystem_kernel exports (___open, ___accept, ...).
They are made by xnu's own script, libsyscall/xcodescripts/create-syscalls.pl,
which the build of libsyscall runs on bsd/kern/syscalls.master: it decides
which calls get a stub (the NO_SYSCALL_STUB mark, the #if lines of the master
file, the stubs for the double-underscore names that Libc wraps).  The
script writes one assembler file per stub; the name of the file is the
symbol.  The files that custom.s defines on x86_64 are added (the only
architecture-specific global of custom.s that is not a stub file).

Writes one symbol per line (Mach-O names, the same for x86_64 and arm64).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from clang_scan import ARCHS  # noqa: E402


def main(argv):
    p = argparse.ArgumentParser(prog="syscall_syms.py", description="The system call stubs of libsystem_kernel.")
    p.add_argument("xnu")
    p.add_argument("work")
    p.add_argument("out")
    a = p.parse_args(argv[1:])
    xnu, work, out = a.xnu, a.work, a.out
    ls = os.path.join(xnu, "libsyscall")
    outdir = os.path.join(work, "syscall-stubs")
    shutil.rmtree(outdir, ignore_errors=True)
    os.makedirs(outdir)
    env = dict(os.environ, ARCHS=" ".join(ARCHS))
    r = subprocess.run(
        ["perl", os.path.join(ls, "xcodescripts", "create-syscalls.pl"),
         os.path.join(xnu, "bsd", "kern", "syscalls.master"),
         os.path.join(ls, "custom"), os.path.join(ls, "Platforms"), "MacOSX", outdir],
        env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    if r.returncode != 0:
        sys.stderr.write("syscall_syms.py: create-syscalls.pl failed:\n%s%s" % (r.stdout[-2000:], r.stderr[-2000:]))
        return 1
    names = set()
    for fn in os.listdir(outdir):
        if fn.endswith(".s") and fn != "custom.s":
            names.add(fn[:-2])
    # globals of custom.s (the i386 ones are not for macOS on x86_64 or arm64)
    with open(os.path.join(ls, "custom", "custom.s"), errors="replace") as f:
        for line in f:
            m = re.match(r"\s*\.globl\s+(\S+)", line)
            if m and not m.group(1).startswith("_i386_"):
                names.add(m.group(1))
    if len(names) < 300:
        sys.stderr.write("syscall_syms.py: only %d stubs, something went wrong\n" % len(names))
        return 1
    with open(out, "w") as f:
        for n in sorted(names):
            f.write(n + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
