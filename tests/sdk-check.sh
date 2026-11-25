#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Check an SDK of make-open-sdk.sh (a directory, or a tarball that is unpacked
# into a new temporary directory) without running anything of it:
#   tests/sdk-check.sh SDK [--clang PATH] [--gcc "COMMAND"] [--update-allow] [--no-headers]
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
[ $# -ge 1 ] || { sed -n '3,6p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
sdk=$1; shift
tmp=
if [ -f "$sdk" ]; then
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/open-sdk-check.XXXXXX") || exit 2
  trap 'rm -rf "$tmp"' EXIT
  tar -C "$tmp" -xf "$sdk" || exit 2
  sdk=$(find "$tmp" -maxdepth 1 -name 'MacOSX*.sdk' | head -n 1)
fi
exec python3 -I "$HERE/sdk-check.py" "$sdk" "$@"
