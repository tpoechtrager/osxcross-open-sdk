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
import argparse
import re
import sys


def words(line):
    return line.split("#", 1)[0].split()


def ios_version(dsl, target):
    """The iOS version of a macOS release (for SDKSettings.json) from an already cut DSL."""
    if re.fullmatch(r"\d+", target):
        target += ".0"
    ios = None
    seen = False
    with open(dsl) as f:
        dsl_lines = f.read().splitlines()
    for line in dsl_lines:
        w = words(line)
        if w[:2] == ["version", "macos"]:
            if seen:
                break
            seen = w[2] == target
        elif w[:2] == ["version", "ios"]:
            # the newest iOS release up to the end of the macOS release's
            # group (it can come before the macOS line: macOS 11.3, iOS 14.5)
            ios = w[2]
    return ios


def cut(base, extra, target, out):
    """Write OUT: BASE without the __OPENSOURCE__ blocks, EXTRA, cut after TARGET."""
    if re.fullmatch(r"\d+", target):
        target += ".0"
    lines = []
    skip = 0
    with open(base) as f:
        base_lines = f.read().splitlines()
    for line in base_lines:
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
    with open(extra) as f:
        lines += f.read().splitlines()
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
        sys.exit("avail_dsl.py: macOS %s is not in the DSL" % target)
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


def main(argv):
    if argv[1:2] == ["--ios-version"]:
        p = argparse.ArgumentParser(prog="avail_dsl.py --ios-version", description="The iOS version of a macOS release.")
        p.add_argument("dsl")
        p.add_argument("macos")
        a = p.parse_args(argv[2:])
        print(ios_version(a.dsl, a.macos))
        return 0
    p = argparse.ArgumentParser(prog="avail_dsl.py", description="Prepare the DSL of AvailabilityVersions.",
                                epilog="avail_dsl.py --ios-version DSL MACOS_VERSION prints the iOS version.")
    p.add_argument("base")
    p.add_argument("extra")
    p.add_argument("macos")
    p.add_argument("out")
    a = p.parse_args(argv[1:])
    cut(a.base, a.extra, a.macos, a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
