#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""manifest.py: maintenance of data/manifests/ and data/libcxx-versions.txt.

The generator clones only what a manifest lists, and checks that every clone
is at the commit of the manifest.  This tool makes and checks manifests; the
generator itself never runs it.

  manifest.py --new VERSION [--base FILE] [--release-json FILE] [--out FILE]
      Write the manifest of macOS VERSION (for example 26.6).  The sqlite
      and xz lines are those of the base manifest (of the newest manifest if
      the base is a list of "<project> <tag>" lines).  The tags come
      from release.json of the tag macos-<VERSION without the dot> in
      github.com/apple-oss-distributions/distribution-macOS (or from
      --release-json); projects that release.json does not list (Libm,
      libunwind, cctools, CF, CarbonHeaders, developer_cmds) keep the tag of
      the base manifest (default: the newest file of data/manifests/, or a
      file of "<project> <tag>" lines).  AvailabilityVersions keeps the tag of
      the base before tag 135, which has no DSL.  The commit of every tag
      is asked with git ls-remote.
  manifest.py --check VERSION
      Ask git ls-remote again and report every tag (xz too) that no longer
      points to the commit of the manifest.
  manifest.py --llvm VERSION
      Print the line "llvm VERSION COMMIT" for data/libcxx-versions.txt.

Line format of a manifest (the generator reads the first three fields):
    <project> <tag> <commit> <release|fixed>
    sqlite <url> <sha256>
    xz <git url> <tag> <commit>
"""
import argparse
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from urllib.request import urlopen

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "helpers"))
from data_files import read_manifest, read_manifest_xz  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFESTS = os.path.join(ROOT, "data", "manifests")
OSS = "https://github.com/apple-oss-distributions/"
RELEASE_URL = ("https://raw.githubusercontent.com/apple-oss-distributions/"
               "distribution-macOS/macos-%s/release.json")


def die(msg):
    sys.stderr.write("manifest.py: %s\n" % msg)
    sys.exit(1)


def ls_remote(url, ref):
    """The commit of the tag ref (annotated tags: the commit they point to)."""
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    out = subprocess.run(
        ["git", "ls-remote", url, "refs/tags/%s" % ref, "refs/tags/%s^{}" % ref,
         "refs/heads/%s" % ref],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, env=env)
    if out.returncode != 0:
        die("git ls-remote %s failed: %s" % (url, out.stderr.strip()))
    tag = peeled = None
    for line in out.stdout.splitlines():
        sha, name = line.split()
        if name == "refs/heads/%s" % ref:
            die("%s has a branch and a tag named %s (git clone --branch is ambiguous)" % (url, ref))
        if name.endswith("^{}"):
            peeled = sha
        else:
            tag = sha
    if tag is None:
        die("%s has no tag %s" % (url, ref))
    return peeled or tag


def read_projects(path):
    """[(project, tag, rest...)] of a manifest or of a list of "name tag" lines."""
    return read_manifest(path)[0]


def newest_manifest():
    names = sorted(
        (n for n in os.listdir(MANIFESTS) if re.match(r"macos-\d+\.txt$", n)),
        key=lambda n: int(n[6:-4]))
    if not names:
        die("no manifest in %s; give --base" % MANIFESTS)
    return os.path.join(MANIFESTS, names[-1])


def macos_dir(version):
    return "macos-%s" % version.replace(".", "")


def cmd_new(version, base, release_json, out):
    base = base or newest_manifest()
    sqlite, xz = read_manifest(base)[1], read_manifest_xz(base)
    if sqlite is None or xz is None:
        # a base of "<project> <tag>" lines: the sqlite and xz lines of the newest manifest
        newest = newest_manifest()
        sqlite, xz = read_manifest(newest)[1], read_manifest_xz(newest)
        if sqlite is None or xz is None:
            die("neither %s nor %s has a sqlite and an xz line" % (base, newest))
    if release_json:
        with open(release_json) as f:
            data = json.load(f)
    else:
        url = RELEASE_URL % version.replace(".", "")
        try:
            data = json.loads(urlopen(url, timeout=60).read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            die("cannot read %s: %s" % (url, e))
    rel = {p["project"]: p["tag"] for p in data["projects"]}
    rows = []
    for row in read_projects(base):
        name, tag = row[0], row[1]
        new, origin = rel.get(name, tag), "release" if name in rel else "fixed"
        if name == "AvailabilityVersions":
            # before tag 135 there is no DSL, only a Perl script and a fixed header
            m = re.match(r"AvailabilityVersions-(\d+)", new)
            if not m or int(m.group(1)) < 135:
                new, origin = tag, "fixed"
        rows.append((name, new, origin))
    with ThreadPoolExecutor(max_workers=8) as ex:
        commits = list(ex.map(lambda r: ls_remote(OSS + r[0], r[1]), rows))
    text = ["# osxcross-open-sdk: pinned sources for macOS %s" % version,
            "# release: tag from release.json of distribution-macOS %s; fixed: not in"
            % macos_dir(version),
            "# release.json, the tag of the previous manifest is kept.",
            "# <project> <tag> <commit> <origin>"]
    for (name, tag, origin), commit in zip(rows, commits):
        text.append("%s %s %s %s" % (name, tag, commit, origin))
    text.append("# sqlite: <url> <sha256 of the archive>")
    text.append("sqlite %s %s" % sqlite)
    text.append("# xz (liblzma): <git url> <tag> <commit>")
    text.append("xz %s %s %s" % xz)
    out = out or os.path.join(MANIFESTS, macos_dir(version) + ".txt")
    with open(out, "w") as f:
        f.write("\n".join(text) + "\n")
    print("wrote %s (%d projects)" % (out, len(rows)))


def cmd_check(version):
    path = os.path.join(MANIFESTS, macos_dir(version) + ".txt")
    rows = [(OSS + r[0], r[0], r[1], r[2]) for r in read_projects(path) if len(r) >= 3]
    xz = read_manifest_xz(path)
    if xz:
        rows.append((xz[0], "xz", xz[1], xz[2]))
    with ThreadPoolExecutor(max_workers=8) as ex:
        commits = list(ex.map(lambda r: ls_remote(r[0], r[2]), rows))
    bad = 0
    for r, c in zip(rows, commits):
        if c != r[3]:
            print("CHANGED %s %s: manifest %s, now %s" % (r[1], r[2], r[3], c))
            bad += 1
    print("%d of %d tags changed" % (bad, len(rows)))
    return 1 if bad else 0


def cmd_llvm(version):
    print("llvm %s %s" % (version, ls_remote("https://github.com/llvm/llvm-project", "llvmorg-" + version)))


def main(argv):
    p = argparse.ArgumentParser(prog="manifest.py", description="Maintenance of data/manifests/.",
                                epilog="See the comment at the top of the file.")
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument("--new", action="store_const", const="new", dest="mode")
    mode.add_argument("--check", action="store_const", const="check", dest="mode")
    mode.add_argument("--llvm", action="store_const", const="llvm", dest="mode")
    p.add_argument("version")
    p.add_argument("--base")
    p.add_argument("--release-json")
    p.add_argument("--out")
    a = p.parse_args(argv[1:])
    if a.mode == "new":
        cmd_new(a.version, a.base, a.release_json, a.out)
    elif a.mode == "check":
        return cmd_check(a.version)
    else:
        cmd_llvm(a.version)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
