#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""notice.py DATE FILE TEXT

Marks a header that the generator changed: puts the comment
    /* Modified by osxcross-open-sdk (DATE): TEXT. */
behind the license comment at the top of FILE (APSL 2.0 section 2.2 and
Apache 2.0 section 4 ask for a notice in a changed file).  A file that
has a notice already gets the new text as a further notice line behind the
last one, unless that line is there; the same call twice changes nothing.  DATE is fixed by the generator, not
the date of the build, so that the SDK is reproducible.
"""
import argparse
import sys

MARK = "Modified by osxcross-open-sdk"


def add_notice(path, date, text):
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
        t = f.read()
    note = "/* %s (%s): %s. */\n" % (MARK, date, text)
    if note in t:
        return False
    if MARK in t:
        # insert behind the last existing notice line
        pos = t.rfind("/* " + MARK)
        nl = t.find("\n", pos)
        nl = nl + 1 if nl >= 0 else len(t)
        t = t[:nl] + note + t[nl:]
        with open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
            f.write(t)
        return True
    s = t.lstrip()
    lead = len(t) - len(s)
    if s.startswith("/*"):
        end = s.find("*/")
        if end >= 0:
            cut = lead + end + 2
            # behind the end of the line of the closing comment
            nl = t.find("\n", cut)
            cut = nl + 1 if nl >= 0 else len(t)
            t = t[:cut] + note + t[cut:]
        else:
            t = note + t
    else:
        t = note + t
    with open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write(t)
    return True


def main(argv):
    p = argparse.ArgumentParser(prog="notice.py", description="Mark a header that the generator changed.")
    p.add_argument("date")
    p.add_argument("file")
    p.add_argument("text")
    a = p.parse_args(argv[1:])
    add_notice(a.file, a.date, a.text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
