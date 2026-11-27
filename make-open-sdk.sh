#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# make-open-sdk.sh -- build a macOS SDK from Apple's open source releases
# (APSL 2.0) and LLVM's libc++, instead of extracting it from Xcode.
#
# Usage: make-open-sdk.sh [options]
#
# Every input is a pinned tag of a project on
# https://github.com/apple-oss-distributions (a macOS release, see
# distribution-macOS/macos-265/release.json) or of LLVM.  The result is
# out/MacOSX<VERSION>-open-sdk-<COMMIT>.tar.xz (--core: MacOSX<VERSION>-open-core-sdk-<COMMIT>.tar.xz),
# COMMIT being the first 7 characters of the commit of this repository, with
# "-modified" if tracked files have changes, or "unknown" (not a git checkout);
# then a warning is printed.  SDKSettings.plist, SDKSettings.json and
# OpenSDK.json name the whole commit (with "-modified", or "unknown").
# The notices in the headers that the script changes carry the date of that
# commit; without a readable commit they carry the day of the build (a warning).
#
# Options:
#   --macos VERSION      the SDK of another macOS release (default 26.5; the
#                        numbers of Xcode's SDKs: 11.3 12.3 13.3 14.3 15.5 26.0 ...;
#                        the full SDK is made for 14.3 and later, --core for 11.3
#                        and later; data/releases.txt, --list-releases).
#                        A list (14.3,26.5) or "all" makes several SDKs one after
#                        the other, each in <work-dir>/<VERSION>[-core] (the sources
#                        are not shared); one that fails does not stop the others,
#                        the exit status is 1 then.  "all" makes the core SDK of the
#                        releases that have no full SDK; --libcxx: one release only
#   --libcxx VERSION     libc++ of another LLVM release (default: 21.1.8 for
#                        26.5, 16.0.6 for 14.3, see data/releases.txt and
#                        docs/LIBCXX.md)
#   --min-deployment-target VERSION
#                        the lowest deployment target that SDKSettings.json
#                        names (default 11.0, the major version of the oldest
#                        release of data/releases.txt; VERSION like 10.13 or
#                        11.0, not above the SDK's release)
#   --release            every release, the full and the core SDK of each (the full SDK
#                        where there is one), into <output-dir>/release/<COMMIT>/ with
#                        SHA256SUMS; only from a clean commit; with --tree-hash their tree hashes
#   --core               only C, C++ and POSIX (the steps libs and frameworks
#                        are left out; macOS 11.3 and later); without it (macOS
#                        14.3 and later) the SDK also has the
#                        libraries of /usr/lib and the frameworks
#                        CoreFoundation, DiskArbitration, SystemConfiguration,
#                        Security and IOKit, and link stubs without headers
#                        of Foundation, CoreGraphics, AppKit, CoreText,
#                        CoreVideo, QuartzCore, Metal, CoreAudio and
#                        AudioToolbox
#   -w, --work-dir DIR   sources and build files (default: build/ of this
#                        repository); relative paths are taken from the
#                        current directory
#   -o, --output-dir DIR where the tarball goes (default: out/)
#   -s, --steps "STEPS"  run only these steps (see below); the staging of an earlier run must match
#   --clang PATH         the clang that builds the host tools and parses the
#                        headers (default: clang in the PATH)
#   --force              replace an existing tarball of the same name even if
#                        it does not look like a tarball of this script
#   --clean              delete the build files of the work directory, keep
#                        the downloaded sources (src/), and exit
#   --clean-all          delete the work directory, sources included, and exit
#   --list-releases      print the macOS releases that can be built, and their libc++
#   --show-config        print what the script would build and where, and exit
#   --tree-hash          print the SHA-256 of the file tree of the SDK
#                        (independent of tar and xz versions) after the tarball
#   -v, --verbose        also show the output that otherwise goes only to the
#                        logs of the steps or nowhere (Apple's scripts, the
#                        helpers) and every command the steps run (set -x,
#                        lines that start with "+"); it is in build.log too
#   -h, --help           this text
#   --version            the commit of this script (7 characters, "-modified" or "unknown", as in the name of the tarball)
#
# Environment (options take precedence): OPEN_SDK_WORK_DIR, OPEN_SDK_OUTPUT_DIR,
# OPEN_SDK_CLANG, OPEN_SDK_YACC (yacc or bison -y; by default the first one
# that works), OPEN_SDK_BUILD_VERSION (ProductBuildVersion of SystemVersion.plist;
# default: the one of data/releases.txt),
# OPEN_SDK_SWIFT_PKG, OPEN_SDK_AV_TAG (AvailabilityVersions tag),
# OPEN_SDK_MIN_DEPLOYMENT_TARGET (--min-deployment-target),
# OPEN_SDK_BSDTAR (use bsdtar even if GNU tar exists).  No other variable is read:
# SDK_VERSION, TARBALL_DIR, WORK, CLANG ... of OSXCross do not matter.
#
# Steps (all by default, or pick with -s):
#   fetch     clone the pinned source tags
#   host      build host tools: unifdef, decomment, migcom, small shims
#   headers   install the C headers (xnu, Libc, libpthread, ...)
#   stubs     create the .tbd stub libraries: libSystem (with dns_sd in the
#             full SDK), libresolv, libiconv
#   cxx       libc++/libc++abi headers and stubs (the LLVM release that
#             matches the macOS release, or --libcxx)
#   libs      more libraries: zlib, bzip2, expat, libffi, libedit, libxml2,
#             libobjc, libutil, libpcap, libarchive, OpenPAM, libxslt,
#             libcurl, ncurses with panel, form and menu, sqlite3,
#             liblzma
#             (not with --core)
#   frameworks  CoreFoundation, DiskArbitration, SystemConfiguration, IOKit,
#             Security, CoreServices; link stubs of Foundation, CoreGraphics,
#             AppKit, CoreText, CoreVideo, QuartzCore, Metal, CoreAudio and
#             AudioToolbox (not with --core)
#   meta      SDKSettings.plist/.json, SystemVersion.plist, license files
#   tarball   the tarball
#   swift     (not a default step) stubs for the Swift runtime, needs
#             OPEN_SDK_SWIFT_PKG
#
# The variables below are used by the files of lib/.
# shellcheck disable=SC2034
set -euo pipefail
# Make the tools behave the same on every host: the sort order, and BSD sed
# rejects bytes that are not valid in a UTF-8 locale.
export LC_ALL=C

# The variables of OSXCross' tools.sh and of osxcross-conf (SDK_VERSION,
# TARBALL_DIR, ...) must not change what this script builds or where it
# writes: it reads only the options and the OPEN_SDK_* variables.
# (|| true: unset fails only for a variable that is read-only)
unset WORK TARBALL_DIR SDK_VERSION LIBCXX_VERSION CLANG BUILD_VERSION SWIFT_PKG AV_TAG || true

SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HELPERS=$SELF/helpers
DATA=$SELF/data
ALL_STEPS="fetch host headers stubs cxx libs frameworks meta tarball swift"

# the common functions and the steps (only functions and constants)
for f in common multi $ALL_STEPS; do
  # shellcheck source=/dev/null
  . "$SELF/lib/$f.sh"
done

# abs_path PATH: PATH relative to the current directory, made absolute
abs_path() { case $1 in /*) printf '%s\n' "$1";; *) printf '%s/%s\n' "$PWD" "$1";; esac; }

# the value of an option: opt_value OPTION ARGUMENT-COUNT VALUE
opt_value() { [ "$2" -ge 2 ] || { echo "make-open-sdk.sh: option $1 needs a value" >&2; exit 2; }; }

WORK=${OPEN_SDK_WORK_DIR:-$SELF/build}
OUT_DIR=${OPEN_SDK_OUTPUT_DIR:-$SELF/out}
CLANG=${OPEN_SDK_CLANG:-clang}
# the defaults of --macos and --min-deployment-target (data/releases.txt)
DEFAULT_MACOS=$(default_release)
SDK_VERSION=$DEFAULT_MACOS
LIBCXX_VERSION=
DEFAULT_MIN_DEPLOYMENT_TARGET=$(releases | head -n 1 | cut -d. -f1).0
MIN_DEPLOYMENT_TARGET=${OPEN_SDK_MIN_DEPLOYMENT_TARGET:-$DEFAULT_MIN_DEPLOYMENT_TARGET}
BUILD_VERSION=${OPEN_SDK_BUILD_VERSION:-}
VARIANT=full
RELEASE=0
FORCE=0
CLEAN=
TREE_HASH=0
LIST=0
SHOW=0
VERBOSE=0
SHOW_VERSION=0
STEPS=""

while [ $# -gt 0 ]; do
  case $1 in
    --*=*) a=$1; shift; set -- "${a%%=*}" "${a#*=}" "$@";;
  esac
  case $1 in
    -w|--work-dir) opt_value "$1" $#; WORK=$2; shift 2;;
    -o|--output-dir) opt_value "$1" $#; OUT_DIR=$2; shift 2;;
    -s|--steps) opt_value "$1" $#; STEPS=$2; shift 2;;
    --min-deployment-target) opt_value "$1" $#; MIN_DEPLOYMENT_TARGET=$2; shift 2;;
    --core) VARIANT=core; shift;;
    --release) RELEASE=1; shift;;
    --macos) opt_value "$1" $#; SDK_VERSION=$2; shift 2;;
    --libcxx) opt_value "$1" $#; LIBCXX_VERSION=$2; shift 2;;
    --clang) opt_value "$1" $#; CLANG=$2; shift 2;;
    --force) FORCE=1; shift;;
    --clean) CLEAN=build; shift;;
    --clean-all) CLEAN=all; shift;;
    --tree-hash) TREE_HASH=1; shift;;
    --list-releases) LIST=1; shift;;
    --show-config) SHOW=1; shift;;
    -v|--verbose) VERBOSE=1; shift;;
    --version) SHOW_VERSION=1; shift;;
    -h|--help) sed -n '3,/^set -/{/^set -/!p;}' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "make-open-sdk.sh: unknown option $1 (see --help)" >&2; exit 2;;
  esac
done

# Everything below works with absolute paths: the scripts of Apple run in
# other directories.
WORK=$(abs_path "$WORK")
OUT_DIR=$(abs_path "$OUT_DIR")
case $CLANG in */*) CLANG=$(abs_path "$CLANG");; esac
# Several SDKs (--macos with a list or "all", --release): this script runs
# itself for each one (lib/multi.sh); a list with one SDK is a single run.
MULTI_LIST=
if [ "$SHOW_VERSION" = 0 ] && [ "$LIST" = 0 ]; then
  if [ "$RELEASE" = 1 ]; then
    if [ "$SDK_VERSION" != "$DEFAULT_MACOS" ] || [ "$VARIANT" = core ]; then
      echo "make-open-sdk.sh: --release makes every SDK of every release: not with --macos or --core" >&2; exit 2
    fi
    MULTI_LIST=$(expand_release_list)
  else
    case $SDK_VERSION in
      all|*,*)
        MULTI_LIST=$(expand_macos_list "$SDK_VERSION" "$VARIANT") || exit $?
        if [ "$(printf '%s\n' "$MULTI_LIST" | wc -l)" -eq 1 ]; then
          SDK_VERSION=${MULTI_LIST% *}; VARIANT=${MULTI_LIST#* }; MULTI_LIST=
        fi;;
    esac
  fi
fi
if [ -n "$MULTI_LIST" ]; then
  [ -z "$LIBCXX_VERSION" ] || { echo "make-open-sdk.sh: --libcxx is only allowed with one release" >&2; exit 2; }
  [ -z "$BUILD_VERSION" ] || { echo "make-open-sdk.sh: OPEN_SDK_BUILD_VERSION is only allowed with one release" >&2; exit 2; }
  MULTI_OUT=$OUT_DIR
  if [ "$RELEASE" = 1 ]; then
    c=$(generator_commit)
    if [ -z "$CLEAN" ] && [ "$SHOW" = 0 ]; then
      case $c in
        unknown|*-modified) die "--release needs a clean commit of this repository, this one is \"$(generator_label "$c")\"";;
      esac
    fi
    MULTI_OUT=$OUT_DIR/release/$(generator_label "$c")
  fi
  run_multi "$RELEASE" "$MULTI_OUT" "$MULTI_LIST"
  exit $?
fi
case $SDK_VERSION in
  [0-9]*.[0-9]*) ;;
  *) echo "make-open-sdk.sh: --macos expects a version like 26.5, not '$SDK_VERSION'" >&2; exit 2;;
esac
case $LIBCXX_VERSION in
  ""|[0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "make-open-sdk.sh: --libcxx expects a version like 21.1.8, not '$LIBCXX_VERSION'" >&2; exit 2;;
esac

# MinimumDeploymentTarget: MAJOR.MINOR, not above the release of the SDK
if printf '%s\n' "$MIN_DEPLOYMENT_TARGET" | grep -Eqv '^[0-9]+\.[0-9]+$'; then
  echo "make-open-sdk.sh: --min-deployment-target expects a version like 11.0, not '$MIN_DEPLOYMENT_TARGET'" >&2; exit 2
fi
MACOS_REL=macos-$(echo "$SDK_VERSION" | tr -d .)
# ProductBuildVersion of SystemVersion.plist: OPEN_SDK_BUILD_VERSION or data/releases.txt ("-": none)
[ -n "$BUILD_VERSION" ] || BUILD_VERSION=$(release_value "$SDK_VERSION" 4)
[ "$BUILD_VERSION" != - ] || BUILD_VERSION=
if [ -z "$STEPS" ]; then
  STEPS="fetch host headers stubs cxx"
  [ "$VARIANT" = core ] || STEPS="$STEPS libs frameworks"
  STEPS="$STEPS meta tarball"
fi
for s in $STEPS; do
  case " $ALL_STEPS " in *" $s "*) ;; *) echo "make-open-sdk.sh: unknown step '$s' (steps: $ALL_STEPS)" >&2; exit 2;; esac
done
SRC=$WORK/src
HOST=$WORK/host
STAGE=$WORK/stage
[ "$VARIANT" = full ] || STAGE=$WORK/stage-core
# the directories of the stage that the steps fill (the SDK is copied from it)
STAGE_INC=$STAGE/usr/include
STAGE_LIB=$STAGE/usr/lib
STAGE_FW=$STAGE/System/Library/Frameworks
STAGE_WORK=$STAGE/work   # intermediate files, not copied
PKG=$WORK/pkg
[ "$VARIANT" = full ] || PKG=$WORK/pkg-core
SDK=$PKG/MacOSX$SDK_VERSION.sdk

# check_min_target: the minimum must not be above the SDK's release (called
# after load_manifest, so that an unknown release is reported first)
check_min_target() {
  if version_lt "$SDK_VERSION" "$MIN_DEPLOYMENT_TARGET"; then
    echo "make-open-sdk.sh: --min-deployment-target $MIN_DEPLOYMENT_TARGET is above the SDK's release $SDK_VERSION" >&2
    exit 2
  fi
}

# check_full_release: the variants of a release are in data/releases.txt (the
# full SDK from macOS 14.3 on, the core SDK for every release).  Called after
# load_manifest, like check_min_target.
check_full_release() {
  [ "$VARIANT" = core ] && return 0
  if ! releases full | grep -qxF "$SDK_VERSION"; then
    echo "make-open-sdk.sh: the full SDK is made for macOS $(releases full | head -n 1) and later; use --core for macOS $SDK_VERSION" >&2
    exit 2
  fi
}

if [ "$SHOW_VERSION" = 1 ]; then
  echo "make-open-sdk.sh $(generator_label "$(generator_commit)")"
  exit 0
fi
if [ "$LIST" = 1 ]; then
  list_releases
  exit 0
fi
if [ "$SHOW" = 1 ]; then
  load_manifest
  check_min_target
  check_full_release
  printf 'macos %s\nlibcxx %s\nmin-deployment-target %s\nvariant %s\nsteps %s\nwork %s\noutput %s\nclang %s\nmanifest %s\n' \
    "$SDK_VERSION" "$LIBCXX_VERSION" "$MIN_DEPLOYMENT_TARGET" "$VARIANT" "$STEPS" "$WORK" "$OUT_DIR" "$CLANG" "$DATA/manifests/$MACOS_REL.txt"
  exit 0
fi
if [ -n "$CLEAN" ]; then
  clean_work "$CLEAN"
  exit 0
fi

load_manifest
check_min_target
check_full_release
check_tools
# the clang as a path, for the helpers and the scripts of Apple (check_tools
# found it if a step needs it; for the other steps the name stays)
CLANG_PATH=$(command -v "$CLANG") || CLANG_PATH=$CLANG
mkdir -p "$WORK"
: > "$WORK/.open-sdk-work"
migrate_tag_marks

# Everything the start and the steps print also goes to $WORK/build.log (a new
# file for every run).
BUILD_LOG=$WORK/build.log
# the commit of this repository: in the tarball's name and in three files of the SDK
GENERATOR_COMMIT=$(generator_commit)
GENERATOR_LABEL=$(generator_label "$GENERATOR_COMMIT")
set_notice_date "$GENERATOR_COMMIT"   # NOTICE_DATE of the notices in the changed headers
# the tarball (made by the step tarball, lib/tarball.sh)
SDK_TARBALL=$OUT_DIR/$(tarball_name "$SDK_VERSION" "$VARIANT" "$GENERATOR_LABEL")
# the start: what is built, with what, and where the results are (paths relative to
# the current directory where possible); it is not a step, so it has no "==" heading
rel_path() { case $1 in "$PWD"/*) echo "${1#"$PWD"/}";; *) echo "$1";; esac; }
{
  echo "Build configuration"
  echo
  printf '  %-18s %s\n' "macOS" "$SDK_VERSION ($VARIANT)"
  printf '  %-18s %s\n' "Deployment target" "$MIN_DEPLOYMENT_TARGET and later"
  printf '  %-18s %s\n' "Compiler" "$("$CLANG" --version 2>&1 | head -n 1)"
  printf '  %-18s %s\n' "libc++" "$LIBCXX_VERSION"
  printf '  %-18s %s\n' "Generator" "$GENERATOR_LABEL"
  printf '  %-18s %s\n' "Output" "$(rel_path "$SDK_TARBALL")"
  printf '  %-18s %s\n' "Log" "$(rel_path "$BUILD_LOG")"
  echo
  case $GENERATOR_COMMIT in
    unknown) echo "make-open-sdk.sh: warning: the commit of this repository cannot be read (no git checkout, or no git): the SDK names it \"unknown\""; echo;;
    *-modified) echo "make-open-sdk.sh: warning: tracked files of this repository are changed: the SDK names the commit with the suffix \"-modified\""; echo;;
  esac
  if [ -n "$NOTICE_DATE_WARNING" ]; then echo "make-open-sdk.sh: warning: $NOTICE_DATE_WARNING"; echo; fi
} | tee "$BUILD_LOG" >&2
# awk indents the lines below a heading ("== ..."); the messages of this script
# ("make-open-sdk.sh: ...") and empty lines stay as they are.
# set +e around the pipeline: its status is the one of the steps, not of tee.
set +e
{
  set -e
  if [ "$VERBOSE" = 1 ]; then set -x; fi   # every command of the steps, as "+ command"
  for s in $STEPS; do
    case $s in fetch|host|headers) ;; *) stage_mark_check release="$SDK_VERSION" variant="$VARIANT" libcxx="$LIBCXX_VERSION";; esac
    LOG_GAP=1   # log() puts an empty line before the first line of a step that prints something
    "step_$s"
  done
} 2>&1 | awk '/^== / || /^make-open-sdk\.sh:/ || $0 == "" { print; fflush(); next } { print "   " $0; fflush() }' | tee -a "$BUILD_LOG"
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" -ne 0 ]; then
  echo "make-open-sdk.sh: failed (exit status $rc), the log is $BUILD_LOG" >&2
  exit "$rc"
fi
