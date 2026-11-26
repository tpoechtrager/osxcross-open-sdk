# SPDX-License-Identifier: GPL-2.0-only
"""Readers of the files of data/ (the shell has the same readers in
lib/common.sh and lib/fetch.sh).  "#" starts a comment in every file; empty
lines are skipped."""


def lines(path):
    """The fields of every line of a data file, without comments and empty lines."""
    res = []
    with open(path) as f:
        for line in f:
            w = line.split("#", 1)[0].split()
            if w:
                res.append(w)
    return res


def read_symbols(path):
    """A symbol list (data/symbols/*.txt, export lists): one name per line."""
    return [w[0] for w in lines(path)]


def read_manifest(path):
    """A manifest of data/manifests/: ([(project, tag, commit, origin...)], (url, sha256) of
    sqlite or None).  A file of "<project> <tag>" lines gives rows of two fields."""
    rows, sqlite = [], None
    for w in lines(path):
        if w[0] == "sqlite":
            sqlite = (w[1], w[2])
        elif len(w) >= 2:
            rows.append(w)
    return rows, sqlite


def read_libcxx_versions(path):
    """data/libcxx-versions.txt: {LLVM release: commit of the tag}."""
    return {w[1]: w[2] for w in lines(path) if w[0] == "llvm" and len(w) == 3}


def read_releases(path):
    """data/releases.txt: [(release, libc++, [variants], ProductBuildVersion or "", default?)]."""
    res = []
    for w in lines(path):
        res.append((w[0], w[1], w[2].split(","), "" if w[3] == "-" else w[3], w[4:] == ["default"]))
    return res


def read_own_files(path):
    """data/own-files.txt: [(path in the SDK, all or full, written, copied or fallback)]."""
    return [tuple(w[:3]) for w in lines(path)]


def read_libraries(path):
    """data/libraries.txt: {name: (install name, current, compatibility, source)}."""
    res = {}
    for w in lines(path):
        if len(w) >= 4:
            res[w[0]] = (w[1], w[2], w[3], " ".join(w[4:]))
    return res
