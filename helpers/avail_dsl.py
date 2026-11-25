#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Prepare the DSL of AvailabilityVersions for one SDK version.

usage: avail_dsl.py BASE.dsl EXTRA.dsl MACOS_VERSION OUT.dsl
       avail_dsl.py --ios-version OUT.dsl MACOS_VERSION

BASE.dsl is the availability.dsl of an AvailabilityVersions tag (Apple, APSL
2.0).  Its parser reads "#ifndef __OPENSOURCE__" as a comment, so the blocks
that the guard excludes would count as data; they are left out here.
EXTRA.dsl continues the DSL with the macOS releases that the public tags no
longer list (data/availability-extra.dsl).  The result is cut after the
release MACOS_VERSION, so that the newest version of every platform (and with
it __MAC_OS_X_VERSION_MAX_ALLOWED) is that of the SDK.

The cut does what the RC_DARWIN_KERNEL_VERSION variable of Apple's
"availability" script does (stop after the "set" line that names the Darwin
version), but it works without it: all sets before macOS 13.3 have the Darwin
version 0.0, and the lines of EXTRA.dsl have no set.
"""
import re
import sys


def words(line):
    return line.split("#", 1)[0].split()


def info(dsl, target):
    """The iOS version of a macOS release (for SDKSettings.json) from an already cut DSL."""
    if re.fullmatch(r"\d+", target):
        target += ".0"
    ios = None
    seen = False
    for line in open(dsl).read().splitlines():
        w = words(line)
        if w[:2] == ["version", "macos"]:
            if seen:
                break
            seen = w[2] == target
        elif w[:2] == ["version", "ios"]:
            # the newest iOS release up to the end of the macOS release's
            # group (it can come before the macOS line: macOS 11.3, iOS 14.5)
            ios = w[2]
    print(ios)


def main():
    if sys.argv[1] == "--ios-version":
        info(sys.argv[2], sys.argv[3])
        return
    base, extra, target, out = sys.argv[1:5]
    if re.fullmatch(r"\d+", target):
        target += ".0"
    lines = []
    skip = 0
    for line in open(base).read().splitlines():
        s = line.strip()
        if s.startswith("#ifndef __OPENSOURCE__"):
            skip += 1
            continue
        if skip and s.startswith("#if"):
            skip += 1
        elif skip and s.startswith("#endif"):
            skip -= 1
            continue
        if not skip:
            lines.append(line)
    lines += open(extra).read().splitlines()
    # AvailabilityVersions-138.7 lets API_AVAILABLE() say xros(...) for
    # visionOS; the DSL of the later tags lacks the alias, but the headers of
    # libdispatch from macOS 14.4 on use it (dispatch/queue.h).
    # The same for iosmac(...): the headers of libffi (and others) say iosmac,
    # the DSL of the later tags only knows the variant name macCatalyst.
    for i, line in enumerate(lines):
        w = words(line)
        if w[:2] == ["platform", "visionos"] and "availability_aliases=xros" not in line:
            lines[i] = line.split("#", 1)[0].rstrip() + " availability_aliases=xros"
        if w[:3] == ["variant", "ios", "macCatalyst"] and "iosmac" not in line:
            lines[i] = line.split("#", 1)[0].rstrip() + " availability_aliases=iosmac"
    start = None
    for i, line in enumerate(lines):
        w = words(line)
        if w[:2] == ["version", "macos"] and w[2] == target:
            start = i
            break
    if start is None:
        sys.exit("macOS %s is not in the DSL" % target)
    end = len(lines)
    for i in range(start + 1, len(lines)):
        w = words(lines[i])
        if w[:1] == ["set"]:
            end = i + 1
            break
        if w[:2] == ["version", "macos"]:
            end = i
            break
    with open(out, "w") as f:
        f.write("\n".join(lines[:end]) + "\n")


main()
