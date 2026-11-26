#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build the test programs of tests/programs with an SDK of make-open-sdk.sh, for
# x86_64 and arm64, and (if asked) run them on a Mac.
#
#   tests/run.sh --osxcross TARGET_DIR [--llvm LLVM_BIN_DIR] [options]
#       with the compilers of an OSXCross that was built with the SDK (the triple
#       and the SDK come from TARGET_DIR/bin/osxcross-conf, not from the PATH); the
#       wrapper needs a clang: the one in LLVM_BIN_DIR, or the one in the PATH
#   tests/run.sh --sdk SDK_DIR --llvm LLVM_BIN_DIR [options]
#       with clang and ld64.lld of LLVM directly, without OSXCross
# Options:
#   --out DIR       where the programs go (default: a new directory in $TMPDIR; deleted at the end
#                   unless --keep)
#   --keep          keep the programs
#   --core          the SDK is a --core SDK: only the programs that it supports
#   --arch "A B"    architectures (default: x86_64 arm64)
#   --ssh HOST      copy the programs of the architecture of HOST to ~/open-sdk-tests/tests.PID there,
#                   run them, and delete the directory (the host is a Mac; it needs nothing installed)
#   --gcc           also build with the GCC of the OSXCross (--osxcross only; C and C++ programs)
#
# The exit status is 0 if every program built (and ran, with --ssh).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PROG=$HERE/programs
MODE=; TARGET_DIR=; SDK=; LLVM=; OUT=; KEEP=0; CORE=0; ARCHS="x86_64 arm64"; SSH=; GCC=0

while [ $# -gt 0 ]; do
  case $1 in
    --osxcross) MODE=osxcross; TARGET_DIR=$2; shift 2;;
    --sdk) MODE=llvm; SDK=$2; shift 2;;
    --llvm) LLVM=$2; shift 2;;
    --out) OUT=$2; shift 2;;
    --keep) KEEP=1; shift;;
    --core) CORE=1; shift;;
    --arch) ARCHS=$2; shift 2;;
    --ssh) SSH=$2; shift 2;;
    --gcc) GCC=1; shift;;
    -h|--help) sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "run.sh: unknown option $1" >&2; exit 2;;
  esac
done
[ -n "$MODE" ] || { echo "run.sh: give --osxcross TARGET_DIR or --sdk SDK_DIR --llvm DIR (see --help)" >&2; exit 2; }

if [ -z "$OUT" ]; then
  OUT=$(mktemp -d "${TMPDIR:-/tmp}/open-sdk-programs.XXXXXX") || exit 2
  [ "$KEEP" = 1 ] || trap 'rm -rf "$OUT"' EXIT
else
  mkdir -p "$OUT"
fi

SDKVER=
if [ "$MODE" = osxcross ]; then
  TARGET_DIR=$(cd "$TARGET_DIR" && pwd) || exit 2
  if [ -z "$LLVM" ]; then
    c=$(command -v clang) && LLVM=$(dirname "$c")
  fi
  [ -n "$LLVM" ] || { echo "run.sh: no clang in the PATH; give --llvm" >&2; exit 2; }
  # the configuration of this OSXCross; a clean environment, so that an OSXCross of the PATH does not matter
  eval "$(env -i PATH="$TARGET_DIR/bin:/usr/bin:/bin" "$TARGET_DIR/bin/osxcross-conf")" || exit 2
  DARWIN=$OSXCROSS_TARGET
  SDKDIR=$OSXCROSS_SDK
  SDKVER=$OSXCROSS_SDK_VERSION
  [ -f "$SDKDIR/OpenSDK.json" ] || echo "run.sh: note: $SDKDIR has no OpenSDK.json: this is not an SDK of make-open-sdk.sh"
else
  [ -d "$SDK" ] && [ -d "$LLVM" ] || { echo "run.sh: --sdk and --llvm must be directories" >&2; exit 2; }
  SDKDIR=$(cd "$SDK" && pwd)
  LLVM=$(cd "$LLVM" && pwd)
  SDKVER=$(sed -n 's/.*"Version": "\([^"]*\)".*/\1/p' "$SDKDIR/SDKSettings.json" | head -n 1)
fi
[ -f "$SDKDIR/OpenSDK.json" ] && grep -q '"variant": "core"' "$SDKDIR/OpenSDK.json" && CORE=1

# cc ARCH LANG(c|c++|objc) FLAGS... -- SOURCE OUTPUT LIBS...  (compile and link one program)
build() {
  local arch=$1 lang=$2 flags=$3 src=$4 out=$5 libs=$6 cc
  if [ "$MODE" = osxcross ]; then
    case $lang in
      c|objc) cc=$arch-apple-$DARWIN-clang;;
      c++) cc=$arch-apple-$DARWIN-clang++;;
    esac
    # shellcheck disable=SC2086
    env -i HOME="$HOME" PATH="$TARGET_DIR/bin:$LLVM:/usr/bin:/bin" "$cc" $flags -O1 -w -o "$out" "$src" $libs
  else
    case $lang in c++) cc=$LLVM/clang++;; *) cc=$LLVM/clang;; esac
    # shellcheck disable=SC2086
    env -i HOME="$HOME" PATH="$LLVM:/usr/bin:/bin" "$cc" -target "$arch-apple-macos${MINOS:-11.0}" -isysroot "$SDKDIR" \
      -fuse-ld=lld $flags -O1 -w -o "$out" "$src" $libs
  fi
}

total=0; failed=0; ran=0; runfailed=0
# name file lang flags libs variant(core|full)
PROGRAMS="
hello       hello.c       c    -                          -                                     core
posix       posix.c       c    -                          -                                     core
cxx17       cxx.cpp       c++  -std=c++17                 -                                     core
cxx23       cxx.cpp       c++  -std=c++23                 -                                     core
avail       avail.c       c    -                          -                                     core
avail2      avail2.c      c    -                          -                                     core
resolv      resolv.c      c    -                          -lresolv                              core
ext         ext.c         c    -                          -lz,-lbz2,-lexpat,-lffi,-ledit,-lxml2 full
ext2        ext2.c        c    -                          -lutil,-lpcap,-larchive,-lpam,-lxslt,-lexslt,-lcurl,-lxml2 full
ext3        ext3.c        c    -                          -lncurses,-lpanel,-lform,-lmenu,-lsqlite3 full
objc        objc.m        objc -                          -lobjc                                full
arc         arc.m         objc -fobjc-arc                 -lobjc                                full
foundation  foundation.c  c    -                          -framework,Foundation                 full
fw_cf       fw_cf.c       c    -                          -framework,CoreFoundation             full
fw_misc     fw_misc.c     c    -                          -framework,CoreFoundation,-framework,DiskArbitration,-framework,SystemConfiguration,-framework,IOKit full
fw_sec      fw_sec.c      c    -                          -framework,CoreFoundation,-framework,Security full
fw_objc     fw_objc.m     objc -                          -framework,CoreFoundation,-lobjc      full
libcalls    libcalls.c    c    -                          -                                     core
oslog       oslog.c       c    -                          -                                     core
oslogcxx    oslog.c       c++  -xc++                      -                                     core
commoncrypto commoncrypto.c c  -                          -                                     full
launchd     launchd.c     c    -                          -                                     full
readline    readline.c    c    -                          -lreadline                            full
iopm        iopm.c        c    -                          -framework,CoreFoundation,-framework,IOKit full
"

built=
for arch in $ARCHS; do
  while read -r name file lang flags libs variant; do
    [ -n "$name" ] || continue
    [ "$variant" = full ] && [ "$CORE" = 1 ] && continue
    # __MAC_16_0 and __IPHONE_19_0 are in the headers of macOS 26 and later
    if [ "$name" = avail2 ] && [ "${SDKVER%%.*}" -lt 26 ] 2>/dev/null; then continue; fi
    [ "$flags" = - ] && flags=
    [ "$libs" = - ] && libs=
    libs=${libs//,/ }
    total=$((total + 1))
    ext=
    if build "$arch" "$lang" "$flags" "$PROG/$file" "$OUT/$name-$arch" "$libs" > "$OUT/$name-$arch.log" 2>&1; then
      echo "build ok    $name $arch"; built="$built $name-$arch"
    else
      echo "build FAIL  $name $arch"; head -n 3 "$OUT/$name-$arch.log" | sed 's/^/    /'; failed=$((failed + 1))
    fi
    if [ "$GCC" = 1 ] && [ "$MODE" = osxcross ] && [ "$lang" != objc ] && [ -x "$TARGET_DIR/bin/$arch-apple-$DARWIN-gcc" ]; then
      g=$arch-apple-$DARWIN-gcc; [ "$lang" = "c++" ] && g=$arch-apple-$DARWIN-g++
      total=$((total + 1))
      # shellcheck disable=SC2086
      if env -i HOME="$HOME" PATH="$TARGET_DIR/bin:$LLVM:/usr/bin:/bin" "$g" $flags -O1 -w -o "$OUT/$name-$arch-gcc" "$PROG/$file" $libs > "$OUT/$name-$arch-gcc.log" 2>&1; then
        echo "build ok    $name $arch (GCC)"
      else
        echo "build FAIL  $name $arch (GCC)"; head -n 3 "$OUT/$name-$arch-gcc.log" | sed 's/^/    /'; failed=$((failed + 1))
      fi
    fi
    : "$ext"
  done <<EOF2
$PROGRAMS
EOF2
done

if [ -n "$SSH" ]; then
  # the programs of the architecture of the Mac; ssh with the options of the user
  rarch=$(ssh "$SSH" uname -m 2>/dev/null)
  case $rarch in arm64) rarch=arm64;; x86_64) rarch=x86_64;; *) echo "run.sh: cannot ask $SSH for its architecture" >&2; rarch=;; esac
  if [ -n "$rarch" ]; then
    rdir=open-sdk-tests/tests.$$
    ssh "$SSH" "mkdir -p $rdir" && for p in $built; do
      case $p in *-"$rarch") scp -q "$OUT/$p" "$SSH:$rdir/" ;; esac
    done
    for p in $built; do
      case $p in
        *-"$rarch")
          ran=$((ran + 1))
          if ssh "$SSH" "cd $rdir && echo test | ./$p" > "$OUT/$p.run" 2>&1; then echo "run ok      $p"
          else echo "run FAIL    $p"; head -n 3 "$OUT/$p.run" | sed 's/^/    /'; runfailed=$((runfailed + 1)); fi;;
      esac
    done
    ssh "$SSH" "rm -rf $rdir; rmdir open-sdk-tests 2>/dev/null; true"
  fi
fi

echo "$((total - failed)) of $total programs built; $((ran - runfailed)) of $ran ran"
[ "$failed" = 0 ] && [ "$runfailed" = 0 ]
