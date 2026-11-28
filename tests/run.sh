#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build the test programs of tests/programs with an SDK of make-open-sdk.sh, for
# x86_64 and arm64, and (if asked) run them on a Mac.
#
#   tests/run.sh --sdk SDK [--osxcross DIR] [--llvm LLVM_BIN_DIR] [options]
#       with the compilers of OSXCross. SDK (a tarball of make-open-sdk.sh or an SDK directory) is always
#       the SDK that is tested; it is selected with SDKROOT.
#       Without --osxcross, OSXCross is cloned (OSXCROSS_GIT, OSXCROSS_REF: github.com/tpoechtrager/osxcross,
#       master) and built; the target is kept in build/osxcross of this repository for the next run.
#       With --osxcross, DIR is an OSXCross target, or a checkout of OSXCross (e.g. ~/dev/osxcross) whose
#       target/ is used if it is built; else a target is built from `git archive` of the checkout.
#       The triple comes from the osxcross-conf of the target, not from the PATH. The wrapper needs a clang:
#       the one in LLVM_BIN_DIR or in the PATH.
#   tests/run.sh --without-osxcross --sdk SDK --llvm LLVM_BIN_DIR [options]
#       with clang and ld64.lld of LLVM directly
# Options:
#   --out DIR       where the programs go (default: a new directory in $TMPDIR; deleted at the end
#                   unless --keep)
#   --keep          keep the programs
#   --core          the SDK is a --core SDK: only the programs that it supports
#   --arch "A B"    architectures (default: x86_64 arm64)
#   --ssh HOST      copy the programs of the architecture of HOST to ~/open-sdk-tests/tests.PID there,
#                   run them, and delete the directory (the host is a Mac; it needs nothing installed)
#   --flavor NAME   build OSXCross with this flavor, llvm or stable, also if the checkout has a target
#   --gcc           also build with the GCC of the OSXCross (not --without-osxcross; C and C++ programs)
#
# The deployment target is 11.0 (as for the projects of docs/TESTED.md).
# The exit status is 0 if every program built (and ran, with --ssh; then at least one must run and
# the connection must work).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
PROG=$HERE/programs
# shellcheck source=tests/lib/osxcross.sh
. "$HERE/lib/osxcross.sh"
MODE=osxcross; TARGET_DIR=; SDKARG=; LLVM=; OUT=; KEEP=0; CORE=0; ARCHS="x86_64 arm64"; SSH=; GCC=0; FLAVOR=

while [ $# -gt 0 ]; do
  case $1 in
    --osxcross) TARGET_DIR=$2; shift 2;;
    --without-osxcross) MODE=llvm; shift;;
    --sdk) SDKARG=$2; shift 2;;
    --flavor) FLAVOR=$2; shift 2;;
    --llvm) LLVM=$2; shift 2;;
    --out) OUT=$2; shift 2;;
    --keep) KEEP=1; shift;;
    --core) CORE=1; shift;;
    --arch) ARCHS=$2; shift 2;;
    --ssh) SSH=$2; shift 2;;
    --gcc) GCC=1; shift;;
    -h|--help) awk 'NR >= 3 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 0;;
    *) echo "run.sh: unknown option $1" >&2; exit 2;;
  esac
done
if [ "$MODE" = llvm ]; then
  [ -z "$TARGET_DIR" ] || { echo "run.sh: --osxcross and --without-osxcross exclude each other" >&2; exit 2; }
  [ -n "$SDKARG" ] && [ -n "$LLVM" ] || { echo "run.sh: --without-osxcross needs --sdk and --llvm" >&2; exit 2; }
else
  [ -n "$SDKARG" ] || { echo "run.sh: --sdk SDK is needed: the SDK to test (see --help)" >&2; exit 2; }
fi
case $FLAVOR in ''|llvm|stable) ;; *) echo "run.sh: --flavor is llvm or stable" >&2; exit 2;; esac

if [ -z "$OUT" ]; then
  OUT=$(mktemp -d "${TMPDIR:-/tmp}/open-sdk-programs.XXXXXX") || exit 2
  [ "$KEEP" = 1 ] || trap 'rm -rf "$OUT"' EXIT
else
  mkdir -p "$OUT"
fi

SDKVER=; SDKROOT_ENV=
if [ "$MODE" = osxcross ]; then
  if [ -z "$LLVM" ]; then
    c=$(command -v clang) && LLVM=$(dirname "$c")
  fi
  [ -n "$LLVM" ] || { echo "run.sh: no clang in the PATH; give --llvm" >&2; exit 2; }
  LLVM=$(cd "$LLVM" && pwd) || exit 2
  # the target: the one of --osxcross, or one built from the checkout of --osxcross or from a clone
  if [ -n "$TARGET_DIR" ] && [ -z "$FLAVOR" ] && t=$(osxcross_target "$TARGET_DIR"); then
    TARGET_DIR=$t
  else
    src=
    if [ -n "$TARGET_DIR" ]; then
      [ -f "$TARGET_DIR/build.sh" ] || { echo "run.sh: $TARGET_DIR is neither an OSXCross target nor a checkout" >&2; exit 2; }
      src=$(cd "$TARGET_DIR" && pwd)
    fi
    echo "building OSXCross (log $OUT/osxcross.log)"
    TARGET_DIR=$(osxcross_build "$src" "$REPO/build/osxcross" "$SDKARG" "${FLAVOR:-llvm}" "$LLVM" "$OUT/osxcross.log") || exit 2
  fi
  # the configuration of this OSXCross; a clean environment, so that an OSXCross of the PATH does not matter
  osxcross_conf "$TARGET_DIR" || exit 2
  DARWIN=$OSXCROSS_TARGET
  # the SDK of --sdk, selected with SDKROOT (OSXCross takes it before the SDK of the target)
  sdk_select "$SDKARG" "$OUT/sdk" || exit 2
  SDKDIR=$SDK; SDKROOT_ENV="SDKROOT=$SDK"
  echo "OSXCross: $TARGET_DIR; SDK: $SDKDIR"
else
  [ -d "$LLVM" ] || { echo "run.sh: --llvm must be a directory" >&2; exit 2; }
  LLVM=$(cd "$LLVM" && pwd)
  if [ -d "$SDKARG" ]; then
    SDKDIR=$(cd "$SDKARG" && pwd)
  else
    sdk_select "$SDKARG" "$OUT/sdk" || exit 2
    SDKDIR=$SDK
  fi
fi
SDKVER=$(sed -n 's/.*"Version": "\([^"]*\)".*/\1/p' "$SDKDIR/SDKSettings.json" | head -n 1)
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
    env -i HOME="$HOME" PATH="$TARGET_DIR/bin:$LLVM:/usr/bin:/bin" MACOSX_DEPLOYMENT_TARGET=11.0 $SDKROOT_ENV "$cc" $flags -O1 -w -o "$out" "$src" $libs
  else
    case $lang in c++) cc=$LLVM/clang++;; *) cc=$LLVM/clang;; esac
    # shellcheck disable=SC2086
    env -i HOME="$HOME" PATH="$LLVM:/usr/bin:/bin" "$cc" -target "$arch-apple-macos11.0" -isysroot "$SDKDIR" \
      -fuse-ld=lld $flags -O1 -w -o "$out" "$src" $libs
  fi
}

total=0; failed=0; ran=0; runfailed=0; sshfailed=0
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
pcap        pcap.c        c    -                          -lpcap                                full
lzma        lzma.c        c    -                          -llzma                                full
objc        objc.m        objc -                          -lobjc                                full
arc         arc.m         objc -fobjc-arc                 -lobjc                                full
foundation  foundation.c  c    -                          -framework,Foundation                 full
fw_cf       fw_cf.c       c    -                          -framework,CoreFoundation             full
fw_cf_new   fw_cf_new.c   c    -                          -framework,CoreFoundation             full
fw_cf_typed fw_cf_typed.c c    -                          -framework,CoreFoundation             full
fw_cf_typedxx fw_cf_typed.c c++ -xc++                      -framework,CoreFoundation             full
fw_doc_new  fw_doc_new.c  c    -                          -framework,CoreFoundation,-framework,CoreGraphics,-framework,CoreServices,-framework,AudioToolbox full
fw_media    fw_media.c    c    -                          -framework,CoreFoundation,-framework,AVFoundation,-framework,CoreMedia,-framework,ImageIO,-framework,Vision,-framework,MetalKit full
fw_misc     fw_misc.c     c    -                          -framework,CoreFoundation,-framework,DiskArbitration,-framework,SystemConfiguration,-framework,IOKit full
fw_sec      fw_sec.c      c    -                          -framework,CoreFoundation,-framework,Security full
fw_objc     fw_objc.m     objc -                          -framework,CoreFoundation,-lobjc      full
fw_carbon   fw_carbon.c   c    -                          -framework,CoreFoundation,-framework,Carbon full
fw_doc_more fw_doc_more.c c    -                          -framework,CoreFoundation,-framework,WebKit,-framework,UniformTypeIdentifiers,-framework,OpenDirectory full
libcalls    libcalls.c    c    -                          -                                     core
compiler_rt compiler_rt.c c    -nodefaultlibs             -lSystem                              core
libunwind_ext libunwind_ext.c c -                         -                                     core
oslog       oslog.c       c    -                          -                                     core
oslogcxx    oslog.c       c++  -xc++                      -                                     core
commoncrypto commoncrypto.c c  -                          -                                     full
launchd     launchd.c     c    -                          -                                     full
xpc_session  xpc_session.c c   -                          -                                     full
readline    readline.c    c    -                          -lreadline                            full
iopm        iopm.c        c    -                          -framework,CoreFoundation,-framework,IOKit full
iokit_families iokit_families.c c -                       -framework,CoreFoundation,-framework,IOKit full
iokit_usb    iokit_usb.c   c    -                          -framework,CoreFoundation,-framework,IOKit full
darwin      darwin.c      c    -                          -                                     core
dispatch    dispatch.c    c    -                          -                                     core
iconv       iconv.c       c    -                          -liconv                               core
fsevents    fsevents.c    c    -                          -framework,CoreServices,-framework,CoreFoundation full
xpc_conn    xpc_conn.c    c    -                          -                                     full
opengl      opengl.c      c    -                          -framework,OpenGL                     full
"

built=
for arch in $ARCHS; do
  while read -r name file lang flags libs variant; do
    [ -n "$name" ] || continue
    [ "$variant" = full ] && [ "$CORE" = 1 ] && continue
    # __MAC_16_0 and __IPHONE_19_0 are in the headers of macOS 26 and later
    # fw_doc_new links names of the documentation that macOS 26.0 added
    case $name in avail2|fw_doc_new) [ "${SDKVER%%.*}" -lt 26 ] 2>/dev/null && continue;; esac
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
      if env -i HOME="$HOME" PATH="$TARGET_DIR/bin:$LLVM:/usr/bin:/bin" MACOSX_DEPLOYMENT_TARGET=11.0 $SDKROOT_ENV "$g" $flags -O1 -w -o "$OUT/$name-$arch-gcc" "$PROG/$file" $libs > "$OUT/$name-$arch-gcc.log" 2>&1; then
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
  case $rarch in arm64) rarch=arm64;; x86_64) rarch=x86_64;; *) echo "run.sh: cannot ask $SSH for its architecture" >&2; rarch=; sshfailed=1;; esac
  if [ -n "$rarch" ]; then
    rdir=open-sdk-tests/tests.$$
    if ssh "$SSH" "mkdir -p $rdir"; then
      for p in $built; do
        case $p in *-"$rarch") scp -q "$OUT/$p" "$SSH:$rdir/" || { echo "run.sh: scp of $p to $SSH failed" >&2; sshfailed=1; } ;; esac
      done
    else
      echo "run.sh: cannot create $rdir on $SSH" >&2; sshfailed=1
    fi
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
if [ -n "$SSH" ] && [ "$ran" = 0 ] && [ "$sshfailed" = 0 ]; then
  echo "run.sh: --ssh $SSH: no program ran" >&2; sshfailed=1
fi
[ "$failed" = 0 ] && [ "$runfailed" = 0 ] && [ "$sshfailed" = 0 ]
