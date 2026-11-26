#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# The tarball.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# The mtime of every file in the tarball (UTC, "YYYY-MM-DD HH:MM"); the formats
# that the tar variants need are made from it in step_tarball.
TARBALL_MTIME="2024-01-01 00:00"

# is_open_sdk_tarball FILE: made by this script (it has OpenSDK.json)?
is_open_sdk_tarball() {
  local list
  list=$(tar -tf "$1" 2>/dev/null || true)   # (|| true: FILE is no tarball)
  case "$list" in *"MacOSX$SDK_VERSION.sdk/OpenSDK.json"*) return 0;; esac
  return 1
}

step_tarball() {
  local V=$SDK_VERSION
  stage_mark_check min-deployment-target="$MIN_DEPLOYMENT_TARGET"
  rm -rf "$SDK"; mkdir -p "$SDK"
  cp -RPp "$STAGE/usr" "$STAGE/System" "$STAGE/SDKSettings.plist" "$STAGE/SDKSettings.json" \
    "$STAGE/README.LICENSE.txt" "$STAGE/OpenSDK.json" "$SDK/"
  local T=$SDK_TARBALL
  mkdir -p "$OUT_DIR"
  log "Tarball: $T"
  if [ -e "$T" ] && [ "$FORCE" = 0 ] && ! is_open_sdk_tarball "$T"; then
    die "$T exists and is not a tarball of this script; --force replaces it"
  fi
  # reproducible: fixed order, owner and mtime
  local mtime_iso="$TARBALL_MTIME:00 UTC"                          # tar --mtime
  local mtime_touch; mtime_touch=$(echo "$TARBALL_MTIME" | tr -d ' :-').00   # touch -t
  local gtar=
  if tar --version 2>/dev/null | grep -q GNU; then gtar=tar
  elif command -v gtar >/dev/null 2>&1; then gtar=gtar; fi
  if [ -n "$gtar" ] && [ -z "${OPEN_SDK_BSDTAR:-}" ]; then
    # GNU tar
    "$gtar" -C "$PKG" --sort=name --owner=0 --group=0 --numeric-owner --mtime="$mtime_iso" \
      -cf - "MacOSX$V.sdk" | xz -T0 -6 > "$T.tmp"
  else
    # bsdtar (macOS, BSD): no --sort and --mtime; take a sorted file list and
    # set the mtime of the files before.  The bytes differ from GNU tar's
    # (another archive format), the files in the archive are the same.
    command -v bsdtar >/dev/null 2>&1 || die "need GNU tar (gtar) or bsdtar for the tarball"
    local mt=()
    if bsdtar --help 2>&1 | grep -q -e --clamp-mtime; then
      mt=(--mtime "$mtime_iso" --clamp-mtime)
    else
      # old bsdtar: the mtime comes from the files (touch -h is missing on OpenBSD)
      (cd "$PKG" &&
        find "MacOSX$V.sdk" ! -type l -exec env TZ=UTC touch -t "$mtime_touch" {} + &&
        { find "MacOSX$V.sdk" -type l -exec env TZ=UTC touch -h -t "$mtime_touch" {} + 2>/dev/null || true; })
    fi
    (cd "$PKG" && find "MacOSX$V.sdk" | sort > "$WORK/tarlist-$VARIANT" &&
      if command -v xz >/dev/null 2>&1; then
        bsdtar -n -T "$WORK/tarlist-$VARIANT" ${mt[@]+"${mt[@]}"} --uid 0 --gid 0 --uname root --gname wheel --numeric-owner -cf - | xz -T0 -6 > "$T.tmp"
      else
        bsdtar -n -T "$WORK/tarlist-$VARIANT" ${mt[@]+"${mt[@]}"} --uid 0 --gid 0 --uname root --gname wheel --numeric-owner --xz -cf "$T.tmp"
      fi)
  fi
  mv "$T.tmp" "$T"
  echo "size: $(du -h "$T" | cut -f1)"
  if [ "$TREE_HASH" = 1 ]; then
    echo "tree hash ($VARIANT): $(python3 -I "$HELPERS/tree_hash.py" "$SDK")  MacOSX$V.sdk"
  fi
}
