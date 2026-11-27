#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""The exports of OpenGL.framework: one symbol per line.

usage: opengl_syms.py GL_XML DATA_DIR OUT
Every command of OpenGL 1.0 to 4.1 in gl.xml, the functions of data/opengl/extensions.txt,
and the functions of data/opengl/cgl-functions.txt, each with the leading underscore.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
import gl_registry as R  # noqa: E402


def main(argv):
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    glxml, droot, out = argv[1:]
    reg = R.Registry(glxml)
    names = list(reg.all_commands(R.CORE_MAX))
    for _name, funcs, _pages in R.read_pipe_file(os.path.join(droot, "extensions.txt")):
        names += funcs.split()
    for n in names:
        if n not in reg.commands:
            raise SystemExit("gl.xml has no command %s" % n)
    names += [r[2] for r in R.read_pipe_file(os.path.join(droot, "cgl-functions.txt"))]
    with open(out, "w") as f:
        for n in sorted(set(names)):
            f.write("_%s\n" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
