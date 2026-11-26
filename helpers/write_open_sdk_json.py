#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""write_open_sdk_json.py OUT PROJECTS_FILE --own-files FILE --own-headers DIR KEY=VALUE...

Writes OpenSDK.json, the marker and the record of an open SDK: what it is,
which generator made it, and the tag and commit of every project that went
into it.  There is no date and no host information, so two builds of the same
sources by the same generator give the same file.  Keys:
  generator_commit macos_version macos_release variant
  libcxx sqlite_url sqlite_sha256 (the last two only if sqlite is in the SDK)
PROJECTS_FILE has lines "name<TAB>tag<TAB>commit" (write_licenses.py).
--own-files is data/own-files.txt, the files that the generator wrote itself;
a "fallback" entry is listed if the file of the SDK is the one of
--own-headers (data/headers).
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I leaves it out
from data_files import own_files_of  # noqa: E402


def main(argv):
    p = argparse.ArgumentParser(prog="write_open_sdk_json.py", description="Write OpenSDK.json.")
    p.add_argument("out")
    p.add_argument("projects_file")
    p.add_argument("--own-files", required=True, help="data/own-files.txt")
    p.add_argument("--own-headers", required=True, help="data/headers")
    p.add_argument("values", nargs="*", metavar="KEY=VALUE")
    a = p.parse_intermixed_args(argv[1:])  # KEY=VALUE after the options
    out, projects_file = a.out, a.projects_file
    if any("=" not in v for v in a.values):
        p.error("the values are KEY=VALUE")
    kv = dict(v.split("=", 1) for v in a.values)
    projects = []
    with open(projects_file) as f:
        for line in f:
            name, tag, commit = line.rstrip("\n").split("\t")
            projects.append({"name": name, "tag": tag, "commit": commit})
    if kv.get("sqlite_url"):
        projects.append({"name": "sqlite", "url": kv["sqlite_url"], "sha256": kv["sqlite_sha256"]})
    projects.sort(key=lambda p: p["name"].lower())
    own = [p for p, _ in own_files_of(a.own_files, a.own_headers, os.path.dirname(out), kv["variant"])]
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
