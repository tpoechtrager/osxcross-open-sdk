#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Swift runtime stubs (add-on, not a default step).
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# Swift without Foundation: stubs for the runtime libraries.  The dylibs come
# from the macOS toolchain package of swift.org (Apache 2.0), given as
# OPEN_SDK_SWIFT_PKG=/path/to/swift-X-RELEASE-osx.pkg (a xar archive with a gzip payload).
# Together with the swiftc of osxcross (build_swift.sh) this builds programs that
# only import Swift.  Not part of the default steps.
# ---------------------------------------------------------------------------
step_swift() {
  [ -f "${OPEN_SDK_SWIFT_PKG:-}" ] || { echo "set OPEN_SDK_SWIFT_PKG to a swift-*-osx.pkg" >&2; return 1; }
  local D=$WORK/swiftpkg L=$STAGE/usr/lib/swift
  rm -rf "$D"; mkdir -p "$D/x" "$D/payload" "$L"
  (cd "$D/x" && bsdtar -xf "$OPEN_SDK_SWIFT_PKG")
  # (|| true: ls fails for the one of the two layouts that the package does not have)
  local P; P=$(ls "$D"/x/*/Payload "$D"/x/Payload 2>/dev/null | head -1) || true
  (cd "$D/payload" && bsdtar -xf "$P" './usr/lib/swift/macosx/libswift*.dylib' './usr/share/swift/LICENSE.txt')
  python3 -I "$HELPERS/swift_stubs.py" "$D/payload/usr/lib/swift/macosx" "$L" \
    "$(dirname "$(command -v "$CLANG")")" "$HELPERS/mk_tbd.py"
}
