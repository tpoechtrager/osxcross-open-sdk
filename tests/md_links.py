#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""md_links.py ROOT: check the relative links of the Markdown files of ROOT and ROOT/docs.

Every link to a file must name a file that exists, and every #anchor a heading of that file
(the anchor that GitHub makes: lower case, punctuation removed, spaces as hyphens, "-1", "-2", ...
for a repeated heading). Links to other hosts and ../../ (the GitHub pages of the repository)
are not checked. Prints every broken link; the exit status is 1 if there is one.
"""
import glob
import os
import re
import sys

LINK = re.compile(r"\]\(([^)#\s]*)(#[^)\s]*)?\)")


def anchors(path):
    seen, out, fence = {}, set(), False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("```"):
                fence = not fence
            if fence:
                continue
            m = re.match(r"#{1,6} (.*)", line)
            if not m:
                continue
            a = re.sub(r"[^\w\- ]", "", m.group(1).strip().lower()).replace(" ", "-")
            n = seen.get(a, 0)
            seen[a] = n + 1
            out.add(a if n == 0 else "%s-%d" % (a, n))
    return out


def main(argv):
    root = os.path.abspath(argv[1] if len(argv) > 1 else ".")
    files = sorted(glob.glob(os.path.join(root, "*.md")) + glob.glob(os.path.join(root, "docs", "*.md")))
    cache, bad = {}, 0
    for p in files:
        with open(p, encoding="utf-8") as f:
            text = f.read()
        for m in LINK.finditer(text):
            target, anchor = m.group(1), m.group(2)
            if re.match(r"[a-z]+:", target) or target.startswith("../../"):
                continue
            tp = os.path.normpath(os.path.join(os.path.dirname(p), target)) if target else p
            rel = os.path.relpath(p, root)
            if not os.path.exists(tp):
                print("%s: no file %s" % (rel, target))
                bad += 1
            elif anchor and tp.endswith(".md"):
                if tp not in cache:
                    cache[tp] = anchors(tp)
                if anchor[1:] not in cache[tp]:
                    print("%s: no heading for %s%s" % (rel, target, anchor))
                    bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
