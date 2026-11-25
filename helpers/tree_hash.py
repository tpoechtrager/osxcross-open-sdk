#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""tree_hash.py DIR

Prints the SHA-256 of a directory tree: the sorted list of all entries with
type, executable bit, name and content hash (or link target). It does not
depend on the tar and xz versions, owners or times, so two SDKs of the same
sources have the same value on every host.
"""
import hashlib
import os
import stat
import sys


def file_hash(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def tree_hash(root):
    lines = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(dirnames + filenames):
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root)
            st = os.lstat(path)
            if stat.S_ISLNK(st.st_mode):
                lines.append("l %s -> %s" % (rel, os.readlink(path)))
            elif stat.S_ISDIR(st.st_mode):
                lines.append("d %s" % rel)
            else:
                x = "x" if st.st_mode & 0o111 else "-"
                lines.append("f%s %s %s" % (x, rel, file_hash(path)))
    lines.sort()
    return hashlib.sha256(("\n".join(lines) + "\n").encode("utf-8", "surrogateescape")).hexdigest()


def main(argv):
    if len(argv) != 2:
        sys.stderr.write(__doc__)
        return 2
    print(tree_hash(argv[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
