#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Symbols declared in a set of headers of one library.
usage: hdr_syms.py SDKROOT CLANG OUT "<clang flags>" [--allow-errors] -- HEADER... ; only
declarations whose file name (basename) matches one of the HEADERs are kept.
An error of clang in a header stops the script, because declarations after it
may be missing; --allow-errors accepts the errors (they are printed) for a
header that includes a file which the open sources do not have."""
import json, os, subprocess, sys, tempfile, shlex
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from clang_target import target_args
sdk, clang, out, flags = sys.argv[1:5]
allow = "--allow-errors" in sys.argv[5:sys.argv.index("--")]
hdrs = sys.argv[sys.argv.index("--") + 1:]
base = {os.path.basename(h) for h in hdrs}
with tempfile.TemporaryDirectory() as td:
    ext = ".m" if "objective-c" in flags else ".c"
    src = os.path.join(td, "a" + ext)
    open(src, "w").write("".join("#include <%s>\n" % h for h in hdrs))
    with open(out, "w") as f:
        for arch in ("x86_64", "arm64"):
            r = subprocess.run([clang] + target_args(clang, arch) + ["-isysroot", sdk, "-fsyntax-only",
                                "-D_DARWIN_C_SOURCE"] + shlex.split(flags) + ["-Xclang", "-ast-dump=json", src],
                               capture_output=True, text=True)
            if r.returncode != 0:
                # an error in a header can drop declarations silently: stop
                sys.stderr.write("hdr_syms.py: clang %s for %s (%s):\n%s\n" % (
                    "reports errors" if allow else "failed", arch, ", ".join(hdrs), r.stderr[:3000]))
                if not allow:
                    sys.exit(1)
            d = json.loads(r.stdout)
            # clang's JSON dump writes "file" only when it differs from the
            # previous location it wrote (includedFrom does not count), so
            # follow every location in document order. A declaration belongs
            # to the file of its expansion location.
            cur = ""
            def walk(x):
                global cur
                if isinstance(x, dict):
                    if "file" in x and ("offset" in x or "line" in x or "col" in x):
                        cur = x["file"]
                    for k, v in x.items():
                        if k != "includedFrom":
                            walk(v)
                elif isinstance(x, list):
                    for v in x:
                        walk(v)
            names = set()
            for n in d["inner"]:
                walk(n.get("loc", {}))
                nfile = cur
                walk(n)
                if os.path.basename(nfile) not in base:
                    continue
                if n.get("kind") in ("FunctionDecl", "VarDecl") and not n.get("isImplicit") \
                        and n.get("storageClass") != "static" and not n.get("inline") and n.get("mangledName") \
                        and not any(i.get("kind") == "CompoundStmt" for i in n.get("inner", [])) \
                        and (n.get("kind") == "FunctionDecl" or n.get("storageClass") == "extern"):
                    names.add(n["mangledName"].lstrip("\x01"))
                elif n.get("kind") == "ObjCInterfaceDecl" and not n.get("isImplicit") and n.get("name"):
                    names.add("_OBJC_CLASS_$_" + n["name"])
            for m in sorted(names):
                f.write("%s %s\n" % (arch, m))
