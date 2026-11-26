#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Pinned sources and their download.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# The sources of a macOS release are listed in data/manifests/macos-NNN.txt:
# project, tag and commit of github.com/apple-oss-distributions, and the
# archive of sqlite with its SHA-256, and URL, tag and commit of xz (liblzma).
# A clone is accepted only if its tag points to the commit of the manifest.  (tools/manifest.py
# --new) writes a manifest for a new release.
# ---------------------------------------------------------------------------

# Readers of the manifests and of data/libcxx-versions.txt (data_lines: without
# comments; helpers/data_files.py reads them the same way; data/releases.txt:
# lib/common.sh)
# manifest_projects FILE: "project tag commit" lines; manifest_sqlite FILE COLUMN:
# 2 the URL, 3 the SHA-256 of the sqlite archive; manifest_xz FILE COLUMN: 2 the
# URL, 3 the tag, 4 the commit of xz
manifest_projects() { data_lines "$1" | awk '$1 != "sqlite" && $1 != "xz" && NF >= 3 { print $1, $2, $3 }'; }
manifest_sqlite() { data_lines "$1" | awk -v c="$2" '$1 == "sqlite" { print $c }'; }
manifest_xz() { data_lines "$1" | awk -v c="$2" '$1 == "xz" { print $c }'; }
# llvm_commit RELEASE: the commit of the tag of an LLVM release; llvm_releases:
# the LLVM releases that --libcxx accepts
llvm_commit() { data_lines "$DATA/libcxx-versions.txt" | awk -v v="$1" '$1 == "llvm" && $2 == v { print $3 }'; }
llvm_releases() { data_lines "$DATA/libcxx-versions.txt" | awk '$1 == "llvm" { print $2 }'; }

# list_releases: the releases of data/releases.txt (each has a manifest), their
# libc++, the default and the releases of the core SDK only
list_releases() {
  local v
  for v in $(releases); do
    printf '%s\tlibc++ %s' "$v" "$(release_value "$v" 2)"
    [ "$v" != "$DEFAULT_MACOS" ] || printf '\t(default)'
    case ,$(release_value "$v" 3), in *,full,*) ;; *) printf '\t(core SDK only)';; esac
    echo
  done
}

# load_manifest: set PROJECTS ("name tag commit" lines), SQLITE_URL,
# SQLITE_SHA256, XZ_URL, XZ_TAG and XZ_COMMIT from the manifest of --macos, and
# the LLVM release (LIBCXX_VERSION and LLVM_COMMIT).
load_manifest() {
  local m=$DATA/manifests/$MACOS_REL.txt
  [ -f "$m" ] || die "no manifest for macOS $SDK_VERSION; releases with a manifest: $(list_releases | cut -f1 | tr '\n' ' ')"
  PROJECTS=$(manifest_projects "$m")
  SQLITE_URL=$(manifest_sqlite "$m" 2)
  SQLITE_SHA256=$(manifest_sqlite "$m" 3)
  XZ_URL=$(manifest_xz "$m" 2); XZ_TAG=$(manifest_xz "$m" 3); XZ_COMMIT=$(manifest_xz "$m" 4)
  if [ -n "${OPEN_SDK_AV_TAG:-}" ]; then
    # a tag by hand cannot be in the manifest: it is not checked
    PROJECTS=$(echo "$PROJECTS" | awk -v t="$OPEN_SDK_AV_TAG" '$1 == "AvailabilityVersions" { $2 = t; $3 = "-" } { print }')
  fi
  local t=$DATA/libcxx-versions.txt
  if [ -z "$LIBCXX_VERSION" ]; then
    LIBCXX_VERSION=$(release_value "$SDK_VERSION" 2)
    [ -n "$LIBCXX_VERSION" ] || die "data/releases.txt has no libc++ for macOS $SDK_VERSION"
  fi
  LLVM_TAG=llvmorg-$LIBCXX_VERSION
  LLVM_COMMIT=$(llvm_commit "$LIBCXX_VERSION")
  [ -n "$LLVM_COMMIT" ] || die "LLVM $LIBCXX_VERSION is not in $t; releases: $(llvm_releases | tr '\n' ' ')(tools/manifest.py --llvm adds one)"
}

# migrate_tag_marks: the clones of a work directory of an earlier version of
# this script have the mark .oc-tag: it is renamed once to .open-sdk-tag, so
# that they need not be cloned again
migrate_tag_marks() {
  local f
  for f in "$SRC"/*/.oc-tag; do
    [ -f "$f" ] || continue
    [ -e "${f%/.oc-tag}/.open-sdk-tag" ] || mv "$f" "${f%/.oc-tag}/.open-sdk-tag"
  done
}

# clone_is_current DIR TAG COMMIT: is DIR a complete clone of TAG (its mark
# .open-sdk-tag) at COMMIT ("-": any commit)?
clone_is_current() {
  [ -f "$1/.open-sdk-tag" ] && [ "$(cat "$1/.open-sdk-tag")" = "$2" ] || return 1
  [ "$3" = - ] && return 0
  # (rev-parse fails if the clone has no commit: then it is not current)
  [ "$(git --git-dir="$1/.git" rev-parse HEAD 2>/dev/null || true)" = "$3" ]
}

# git_pinned DIR URL TAG COMMIT [FETCH-OPTION...]: fetch TAG of URL into DIR
# and check that it is COMMIT ("-": do not check).  HEAD is set to the commit,
# the work tree is left empty (the caller checks out).  A clone that is there
# already stays if it is the same tag and commit.  The mark .open-sdk-tag is written
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
    echo "$tag" > "$SRC/$name/.open-sdk-tag"
  done <<EOF2
$PROJECTS
EOF2
  fetch_llvm
  [ "$VARIANT" = core ] || { fetch_sqlite; fetch_xz; }
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
  echo "$LLVM_TAG" > "$SRC/llvm-project/.open-sdk-tag"
}

# fetch_xz: the clone of xz (liblzma) at the tag and commit of the manifest
fetch_xz() {
  [ -n "$XZ_URL" ] && [ -n "$XZ_COMMIT" ] || die "the manifest of macOS $SDK_VERSION has no xz line"
  if clone_is_current "$SRC/xz" "$XZ_TAG" "$XZ_COMMIT"; then
    [ -n "${FETCH_QUIET:-}" ] || fetch_line xz "$XZ_TAG" present   # (the step libs calls this too)
    return 0
  fi
  fetch_line xz "$XZ_TAG" cloning
  git_pinned "$SRC/xz" "$XZ_URL" "$XZ_TAG" "$XZ_COMMIT"
  git --git-dir="$SRC/xz/.git" --work-tree="$SRC/xz" checkout -q -f HEAD
  echo "$XZ_TAG" > "$SRC/xz/.open-sdk-tag"
}

# sqlite_dir: the directory of the sqlite amalgamation in SRC (the name of the archive)
sqlite_dir() { echo "$SRC/$(basename "$SQLITE_URL" .zip)"; }

# fetch_sqlite: the amalgamation of the manifest; the directory name is the
# name of the archive.  The archive is checked before it is unpacked, and the
# directory appears only when it is complete.
fetch_sqlite() {
  local d; d=$(basename "$(sqlite_dir)")
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
