#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Pinned sources and their download.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# The sources of a macOS release are listed in data/manifests/macos-NNN.txt:
# project, tag and commit of github.com/apple-oss-distributions, and the
# archive of sqlite with its SHA-256.  A clone is accepted only if its tag
# points to the commit of the manifest.  (helpers/manifest.py
# --new) writes a manifest for a new release.
# ---------------------------------------------------------------------------

# list_releases: the releases that have a manifest
list_releases() {
  local f v l
  for f in "$DATA"/manifests/macos-*.txt; do
    [ -f "$f" ] || continue
    v=$(sed -n 's/^# osxcross-open-sdk: pinned sources for macOS //p' "$f" | head -n 1)
    l=$(awk -v v="$v" '$1=="macos" && $2==v {print $3}' "$DATA/libcxx-versions.txt")
    printf '%s\tlibc++ %s\n' "$v" "$l"
  done | sort -t. -k1,1n -k2,2n | while IFS= read -r l; do
    v=${l%%"$(printf '\t')"*}
    printf '%s' "$l"
    [ "$v" != "$DEFAULT_MACOS" ] || printf '\t(default)'
    ! version_lt "$v" "$FULL_SDK_MIN_MACOS" || printf '\t(core SDK only)'
    echo
  done
}

# load_manifest: set PROJECTS ("name tag commit" lines), SQLITE_URL and
# SQLITE_SHA256 from the manifest of --macos, and the LLVM release (LIBCXX_VERSION
# and LLVM_COMMIT).
load_manifest() {
  local m=$DATA/manifests/$MACOS_REL.txt
  [ -f "$m" ] || die "no manifest for macOS $SDK_VERSION; releases with a manifest: $(list_releases | cut -f1 | tr '\n' ' ')"
  PROJECTS=$(awk '$1 !~ /^#/ && $1 != "sqlite" && NF >= 3 { print $1, $2, $3 }' "$m")
  SQLITE_URL=$(awk '$1 == "sqlite" { print $2 }' "$m")
  SQLITE_SHA256=$(awk '$1 == "sqlite" { print $3 }' "$m")
  if [ -n "${OPEN_SDK_AV_TAG:-}" ]; then
    # a tag by hand cannot be in the manifest: it is not checked
    PROJECTS=$(echo "$PROJECTS" | awk -v t="$OPEN_SDK_AV_TAG" '$1 == "AvailabilityVersions" { $2 = t; $3 = "-" } { print }')
  fi
  local t=$DATA/libcxx-versions.txt
  if [ -z "$LIBCXX_VERSION" ]; then
    LIBCXX_VERSION=$(awk -v v="$SDK_VERSION" '$1 == "macos" && $2 == v { print $3 }' "$t")
    [ -n "$LIBCXX_VERSION" ] || die "$t has no libc++ for macOS $SDK_VERSION"
  fi
  LLVM_TAG=llvmorg-$LIBCXX_VERSION
  LLVM_COMMIT=$(awk -v v="$LIBCXX_VERSION" '$1 == "llvm" && $2 == v { print $3 }' "$t")
  [ -n "$LLVM_COMMIT" ] || die "LLVM $LIBCXX_VERSION is not in $t; releases: $(awk '$1 == "llvm" { printf "%s ", $2 }' "$t") (helpers/manifest.py --llvm adds one)"
}

# clone_is_current DIR TAG COMMIT: is DIR a complete clone of TAG (its mark
# .oc-tag) at COMMIT ("-": any commit)?
clone_is_current() {
  [ -f "$1/.oc-tag" ] && [ "$(cat "$1/.oc-tag")" = "$2" ] || return 1
  [ "$3" = - ] && return 0
  # (rev-parse fails if the clone has no commit: then it is not current)
  [ "$(git --git-dir="$1/.git" rev-parse HEAD 2>/dev/null || true)" = "$3" ]
}

# git_pinned DIR URL TAG COMMIT [FETCH-OPTION...]: fetch TAG of URL into DIR
# and check that it is COMMIT ("-": do not check).  HEAD is set to the commit,
# the work tree is left empty (the caller checks out).  A clone that is there
# already stays if it is the same tag and commit.  The mark .oc-tag is written
# last, so a clone that was interrupted is cloned again.
#
# init + fetch instead of "git clone --depth 1 --branch TAG": that clone warns
# "refs/tags/TAG ... is not a commit!" for every annotated tag (git 2.56).
git_pinned() {
  local dir=$1 url=$2 tag=$3 commit=$4 actual; shift 4
  if clone_is_current "$dir" "$tag" "$commit"; then return 0; fi
  rm -rf "${dir:?}"
  # a named remote: with --filter, git fetches the missing blobs from it later
  { git init -q "$dir" &&
    git --git-dir="$dir/.git" remote add origin "$url" &&
    git --git-dir="$dir/.git" fetch -q --depth 1 --no-tags ${1+"$@"} origin "refs/tags/$tag" &&
    git --git-dir="$dir/.git" update-ref --no-deref HEAD "FETCH_HEAD^{commit}"; } ||
    { rm -rf "${dir:?}"; die "cannot fetch $tag of $url"; }
  # --git-dir: never fall back to an enclosing repository
  actual=$(git --git-dir="$dir/.git" rev-parse HEAD)
  if [ "$commit" != - ] && [ "$actual" != "$commit" ]; then
    rm -rf "${dir:?}"
    die "the tag $tag of $url is at $actual, the manifest has $commit (the tag was moved?)"
  fi
}

# fetch_line NAME TAG STATE: one line of the step fetch.
fetch_line() { printf '%-22s %-30s %s\n' "$1" "$2" "$3"; }

step_fetch() {
  mkdir -p "$SRC"
  log "Fetch"
  local name tag commit
  while read -r name tag commit; do
    [ -n "$name" ] || continue
    if clone_is_current "$SRC/$name" "$tag" "$commit"; then
      fetch_line "$name" "$tag" present
      continue
    fi
    fetch_line "$name" "$tag" cloning
    git_pinned "$SRC/$name" "https://github.com/apple-oss-distributions/$name" "$tag" "$commit"
    git --git-dir="$SRC/$name/.git" --work-tree="$SRC/$name" checkout -q -f HEAD
    echo "$tag" > "$SRC/$name/.oc-tag"
  done <<EOF2
$PROJECTS
EOF2
  fetch_llvm
  [ "$VARIANT" = core ] || fetch_sqlite
}

fetch_llvm() {
  if clone_is_current "$SRC/llvm-project" "$LLVM_TAG" "$LLVM_COMMIT"; then
    [ -n "${FETCH_QUIET:-}" ] || fetch_line llvm-project "$LLVM_TAG" present   # (the step cxx calls this too)
    return 0
  fi
  fetch_line llvm-project "$LLVM_TAG" cloning
  git_pinned "$SRC/llvm-project" https://github.com/llvm/llvm-project "$LLVM_TAG" "$LLVM_COMMIT" --filter=blob:none
  git --git-dir="$SRC/llvm-project/.git" --work-tree="$SRC/llvm-project" sparse-checkout set libcxx libcxxabi
  git --git-dir="$SRC/llvm-project/.git" --work-tree="$SRC/llvm-project" checkout -q -f HEAD
  echo "$LLVM_TAG" > "$SRC/llvm-project/.oc-tag"
}

# fetch_sqlite: the amalgamation of the manifest; the directory name is the
# name of the archive.  The archive is checked before it is unpacked, and the
# directory appears only when it is complete.
fetch_sqlite() {
  local d; d=$(basename "$SQLITE_URL" .zip)
  if [ -f "$SRC/$d/sqlite3.h" ]; then
    [ -n "${FETCH_QUIET:-}" ] || fetch_line sqlite "$d" present   # (the step libs calls this too)
    return 0
  fi
  mkdir -p "$SRC"
  fetch_line sqlite "$d" downloading
  rm -rf "${SRC:?}/$d" "$SRC/sqlite.zip.part" "${SRC:?}/sqlite.unpack"
  curl -fsSL -o "$SRC/sqlite.zip.part" "$SQLITE_URL" || die "cannot download $SQLITE_URL"
  sha256_check "$SQLITE_SHA256" "$SRC/sqlite.zip.part" || { rm -f "$SRC/sqlite.zip.part"; die "the checksum of $SQLITE_URL does not match the manifest"; }
  mkdir "$SRC/sqlite.unpack"
  python3 -I "$HELPERS/unzip.py" "$SRC/sqlite.zip.part" "$SRC/sqlite.unpack"
  [ -f "$SRC/sqlite.unpack/$d/sqlite3.h" ] || { rm -rf "$SRC/sqlite.unpack"; die "$SQLITE_URL has no $d/sqlite3.h"; }
  mv "$SRC/sqlite.unpack/$d" "$SRC/$d"
  rm -rf "$SRC/sqlite.unpack"
  mv "$SRC/sqlite.zip.part" "$SRC/sqlite.zip"
}
