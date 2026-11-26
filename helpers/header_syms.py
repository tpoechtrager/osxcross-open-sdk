#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Symbols declared in a set of headers of one library.

usage: header_syms.py SDKROOT CLANG OUT [--flags "CLANG-FLAGS"] HEADER...
Declarations with hidden visibility are left out.  Only declarations whose
file name (basename) matches one of the HEADERs are kept.  An error of clang in a header stops the script, because declarations
after it may be missing.
Output: lines "ARCH symbol" (ARCH = x86_64 | arm64).
"""
import argparse
import json
import os
import shlex
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from clang_scan import ARCHS, exported_name, target_args  # noqa: E402


def file_of_nodes(nodes):
    """The file of each top-level node of clang's JSON dump.  The dump writes
    "file" only when it differs from the previous location it wrote
    (includedFrom does not count), so every location is followed in document
    order.  A declaration belongs to the file of its expansion location."""
    cur = [""]

    def walk(x):
        if isinstance(x, dict):
            if "file" in x and ("offset" in x or "line" in x or "col" in x):
                cur[0] = x["file"]
            for k, v in x.items():
                if k != "includedFrom":
                    walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)

    res = []
    for n in nodes:
        walk(n.get("loc", {}))
        res.append((n, cur[0]))
        walk(n)
    return res


def is_hidden(n):
    """visibility("hidden"), or declared inside #pragma GCC visibility push(hidden):
    the library does not export it (installapi leaves it out)."""
    return any(i.get("kind") == "VisibilityAttr" and i.get("visibility") == "hidden" for i in n.get("inner", []))


def scan(sdk, clang, flags, hdrs, arch, src):
    base = {os.path.basename(h) for h in hdrs}
    r = subprocess.run([clang] + target_args(clang, arch) + ["-isysroot", sdk, "-fsyntax-only",
                        "-D_DARWIN_C_SOURCE"] + shlex.split(flags) + ["-Xclang", "-ast-dump=json", src],
                       capture_output=True, text=True)
    if r.returncode != 0:
        # an error in a header can drop declarations silently: stop
        sys.exit("header_syms.py: clang failed for %s (%s):\n%s" % (arch, ", ".join(hdrs), r.stderr[:3000]))
    names = set()
    for n, nfile in file_of_nodes(json.loads(r.stdout)["inner"]):
        if os.path.basename(nfile) not in base:
            continue
        if is_hidden(n):
            continue
        name = exported_name(n)
        if name:
            names.add(name)
        elif n.get("kind") == "ObjCInterfaceDecl" and not n.get("isImplicit") and n.get("name"):
            names.add("_OBJC_CLASS_$_" + n["name"])
    return names


def main(argv):
    p = argparse.ArgumentParser(prog="header_syms.py", description="The symbols that headers declare.")
    p.add_argument("sdk")
    p.add_argument("clang")
    p.add_argument("out")
    p.add_argument("--flags", default="", help="clang flags (one argument, split like a shell)")
    p.add_argument("headers", nargs="+")
    a = p.parse_args(argv[1:])
    with tempfile.TemporaryDirectory() as td:
        ext = ".m" if "objective-c" in a.flags else ".c"
        src = os.path.join(td, "a" + ext)
        with open(src, "w") as f:
            f.write("".join("#include <%s>\n" % h for h in a.headers))
        with open(a.out, "w") as f:
            for arch in ARCHS:
                for m in sorted(scan(a.sdk, a.clang, a.flags, a.headers, arch, src)):
                    f.write("%s %s\n" % (arch, m))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
