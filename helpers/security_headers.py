#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""security_headers.py HEADER_SYMLINKS DEST

Copies the public headers of Security.framework: the files that Security.h
and a few other entry points reach through #include <Security/...>, taken
from the header_symlinks directory of the Security project (symlinks are
followed).
"""
import os, re, shutil, sys
root, dest = sys.argv[1:3]
dirs = [root + "/macOS/Security", root + "/Security"]
def find(n):
    for d in dirs:
        p = os.path.join(d, n)
        if os.path.exists(p):
            return p
seen, q = [], ["Security.h", "AuthorizationPlugin.h", "CodeSigning.h", "SecAsn1Coder.h", "SecAsn1Templates.h", "SecureDownload.h", "eisl.h"]
while q:
    n = q.pop()
    p = find(n)
    if n in seen or not p:
        continue
    seen.append(n)
    shutil.copyfile(p, os.path.join(dest, n))     # follows the symlink
    for m in re.findall(r'#\s*include\s*<Security/([A-Za-z0-9_./]+)>', open(p, errors="replace").read()):
        q.append(m)
