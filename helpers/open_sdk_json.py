#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""open_sdk_json.py OUT PROJECTS_FILE KEY=VALUE...

Writes OpenSDK.json, the marker and the record of an open SDK: what it is,
which generator made it, and the tag and commit of every project that went
into it.  There is no date and no host information, so two builds of the same
sources by the same generator give the same file.  Keys:
  generator_commit macos_version macos_release variant
  libcxx sqlite_url sqlite_sha256 (the last two only if sqlite is in the SDK)
PROJECTS_FILE has lines "name<TAB>tag<TAB>commit" (make_licenses.py).
"""
import argparse
import json
import os
import sys

# The files that the generator wrote itself (0BSD, own-files-0BSD in the
# license directory); all other files come from the projects of the list.
OWN_FILES = [
    "OpenSDK.json",
    "README.LICENSE.txt",
    "SDKSettings.json",
    "SDKSettings.plist",
    "System/Library/CoreServices/SystemVersion.plist",
    "usr/include/TargetConditionals.h",
    "usr/include/architecture/arm64/fenv.h",
    "usr/include/os/activity.h",
    "usr/include/os/log.h",
    "usr/include/os/signpost.h",
    "usr/include/os/trace.h",
    "usr/lib/*.tbd",
]
OWN_FILES_FULL = [
    "System/Library/Frameworks/*.framework/*.tbd",
    "System/Library/Frameworks/CoreFoundation.framework/Modules/module.modulemap",
    "usr/include/xpc/xpc.h",
]


def main(argv):
    p = argparse.ArgumentParser(prog="open_sdk_json.py", description="Write OpenSDK.json.")
    p.add_argument("out")
    p.add_argument("projects_file")
    p.add_argument("values", nargs="*", metavar="KEY=VALUE")
    a = p.parse_args(argv[1:])
    out, projects_file = a.out, a.projects_file
    if any("=" not in v for v in a.values):
        p.error("the values are KEY=VALUE")
    kv = dict(v.split("=", 1) for v in a.values)
    projects = []
    for line in open(projects_file):
        name, tag, commit = line.rstrip("\n").split("\t")
        projects.append({"name": name, "tag": tag, "commit": commit})
    if kv.get("sqlite_url"):
        projects.append({"name": "sqlite", "url": kv["sqlite_url"], "sha256": kv["sqlite_sha256"]})
    projects.sort(key=lambda p: p["name"].lower())
    own = OWN_FILES + (OWN_FILES_FULL if kv["variant"] == "full" else [])
    if kv["variant"] == "full" and not os.path.exists(os.path.join(os.path.dirname(out), "usr/include/libDER/libDER_config.h")):
        own.append("usr/include/libDER/DERItem.h")   # the own file, not xnu's (lib/frameworks.sh)
    doc = {
        "format": 1,
        "name": "osxcross-open-sdk",
        "notice": ("This SDK was built from Apple's open source releases "
                   "(github.com/apple-oss-distributions), LLVM and other open source "
                   "projects. It is not Apple's SDK and contains nothing of it."),
        "generator": {"commit": kv["generator_commit"]},
        "macos": {"version": kv["macos_version"], "release": kv["macos_release"]},
        "variant": kv["variant"],
        "libcxx": kv["libcxx"],
        "projects": projects,
        "own_files": sorted(own),
        "licenses": "usr/share/licenses/open-sdk/LICENSES.md",
    }
    with open(out, "w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
