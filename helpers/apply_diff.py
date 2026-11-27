#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""apply_diff.py DIR PATCH

Applies a unified diff (diff -u, file names a/NAME and b/NAME) to the files
in DIR.  Every hunk must match exactly (the lines it keeps and removes); it
may be at another line than its header says.  Any mismatch is an error and
leaves the file as it was.  Portable on purpose: the patch of BSD and GNU
systems differ in their options.
"""
import os
import sys


def parse(text):
    """[(file, [(start, [lines of the hunk with their prefix])])]"""
    files = []
    cur = None
    hunk = None
    for line in text.split("\n"):
        if line.startswith("--- "):
            continue
        if line.startswith("+++ "):
            name = line[4:].split("\t")[0]
            if not name.startswith("b/"):
                raise ValueError("file name without b/: " + name)
            cur = (name[2:], [])
            files.append(cur)
            hunk = None
        elif line.startswith("@@ "):
            start = int(line.split()[1].split(",")[0][1:])
            hunk = (start, [])
            cur[1].append(hunk)
        elif hunk is not None and line[:1] in (" ", "+", "-"):
            hunk[1].append(line)
    return files


def apply_file(lines, hunks, name):
    out = []
    pos = 0   # lines[:pos] are done
    for start, body in hunks:
        old = [l[1:] for l in body if l[0] in " -"]
        new = [l[1:] for l in body if l[0] in " +"]
        n = len(old)
        found = [i for i in range(pos, len(lines) - n + 1) if lines[i:i + n] == old]
        if not found:
            raise ValueError("%s: the hunk at line %d does not match" % (name, start))
        at = min(found, key=lambda i: abs(i - (start - 1)))
        out.extend(lines[pos:at])
        out.extend(new)
        pos = at + n
    out.extend(lines[pos:])
    return out


def main(argv):
    if len(argv) != 3:
        print(__doc__.split("\n\n")[0], file=sys.stderr)
        return 2
    d, patch = argv[1], argv[2]
    with open(patch, encoding="utf-8", errors="surrogateescape") as f:
        files = parse(f.read())
    for name, hunks in files:
        path = os.path.join(d, name)
        with open(path, encoding="utf-8", errors="surrogateescape", newline="") as f:
            text = f.read()
        nl = text.endswith("\n")
        lines = text.split("\n")
        if nl:
            lines.pop()
        try:
            lines = apply_file(lines, hunks, name)
        except ValueError as e:
            print("apply_diff.py: %s" % e, file=sys.stderr)
            return 1
        with open(path, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
            f.write("\n".join(lines) + ("\n" if nl else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
