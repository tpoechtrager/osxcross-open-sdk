# shellcheck shell=bash
# SPDX-License-Identifier: GPL-2.0-only
#
# The OSXCross and the SDK of the test scripts (tests/run.sh, tests/projects.sh); sourced, not run.
#
#   osxcross_target DIR          prints the target of DIR: DIR itself if it is a target (bin/osxcross-conf),
#                                or DIR/target if DIR is a checkout with a built target
#   osxcross_build SRC CACHE SDKTAR FLAVOR LLVMBIN LOG
#                                builds OSXCross from the checkout SRC (`git archive` of its HEAD; SRC is
#                                never written) or, if SRC is empty, from a clone of OSXCROSS_GIT
#                                (OSXCROSS_REF), in CACHE/osxcross-COMMIT-FLAVOR, with the SDK tarball
#                                SDKTAR; a target built before for the same commit is used again.
#                                Prints the target.
#   osxcross_conf TARGET         sets OSXCROSS_* from TARGET/bin/osxcross-conf (in a clean environment)
#   sdk_select SDK DEST          SDK is a tarball of make-open-sdk.sh (unpacked into DEST) or an SDK
#                                directory; sets SDK (the directory), SDKVER and VARIANT (full, core)
#                                from its OpenSDK.json
#
# The functions print their errors to stderr and return 1; they need curl or git, tar and sed.

OSXCROSS_GIT=${OSXCROSS_GIT:-https://github.com/tpoechtrager/osxcross.git}
OSXCROSS_REF=${OSXCROSS_REF:-master}

osxcross_target() {
  if [ -x "$1/bin/osxcross-conf" ]; then (cd "$1" && pwd)
  elif [ -x "$1/target/bin/osxcross-conf" ]; then (cd "$1/target" && pwd)
  else return 1
  fi
}

osxcross_build() {
  local src=$1 cache=$2 sdktar=$3 flavor=$4 llvmbin=$5 log=$6 commit dir tmp=
  [ -f "$sdktar" ] || { echo "building OSXCross needs an SDK tarball, not $sdktar" >&2; return 1; }
  mkdir -p "$cache" || return 1
  if [ -z "$src" ]; then
    tmp=$cache/clone.$$
    rm -rf "$tmp"
    echo "cloning $OSXCROSS_GIT ($OSXCROSS_REF)" >&2
    git clone -q --depth 1 -b "$OSXCROSS_REF" "$OSXCROSS_GIT" "$tmp" >&2 || { rm -rf "$tmp"; return 1; }
    src=$tmp
  fi
  [ -f "$src/build.sh" ] || { echo "$src is no OSXCross checkout" >&2; return 1; }
  commit=$(git -C "$src" rev-parse HEAD | cut -c1-12) || { rm -rf "$tmp"; return 1; }
  dir=$cache/osxcross-$commit-$flavor
  if [ ! -f "$dir/.built" ]; then
    rm -rf "$dir"; mkdir -p "$dir/tarballs" || return 1
    git -C "$src" archive HEAD | tar -xf - -C "$dir" || { rm -rf "$tmp"; return 1; }
    cp "$sdktar" "$dir/tarballs/" || return 1
    echo "building OSXCross $commit ($flavor) in $dir, log $log" >&2
    (cd "$dir" && env -i PATH="${llvmbin:+$llvmbin:}/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME" UNATTENDED=1 \
        BUILD_FLAVOR="$flavor" ./build.sh) > "$log" 2>&1 || { tail -n 20 "$log" >&2; rm -rf "$tmp"; return 1; }
    : > "$dir/.built"
  fi
  [ -z "$tmp" ] || rm -rf "$tmp"
  echo "$dir/target"
}

osxcross_conf() {
  local conf
  conf=$(env -i PATH="$1/bin:/usr/bin:/bin" "$1/bin/osxcross-conf") || return 1
  eval "$conf"
}

sdk_select() {
  local member
  if [ -d "$1" ]; then
    SDK=$(cd "$1" && pwd -P) || return 1
  else
    member=$(tar -tf "$1" | grep 'OpenSDK\.json$' | head -n 1)
    [ -n "$member" ] || { echo "$1 has no OpenSDK.json: not an SDK of make-open-sdk.sh" >&2; return 1; }
    member=${member%%/*}
    mkdir -p "$2" && tar -xf "$1" -C "$2" || return 1
    SDK=$(cd "$2/$member" && pwd -P) || return 1
  fi
  [ -f "$SDK/OpenSDK.json" ] || { echo "$SDK has no OpenSDK.json: not an SDK of make-open-sdk.sh" >&2; return 1; }
  SDKVER=$(sed -n 's/.*"version": "\([0-9.]*\)".*/\1/p' "$SDK/OpenSDK.json" | head -n 1)
  VARIANT=$(sed -n 's/.*"variant": "\([a-z]*\)".*/\1/p' "$SDK/OpenSDK.json" | head -n 1)
  [ -n "$SDKVER" ] || { echo "$SDK/OpenSDK.json names no version" >&2; return 1; }
  case $VARIANT in full|core) ;; *) echo "$SDK/OpenSDK.json names no variant (full or core)" >&2; return 1;; esac
}
