#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build the open source projects of docs/TESTED.md with OSXCross against an SDK of make-open-sdk.sh,
# for x86_64 and arm64, and run the x86_64 programs on a Mac. One file: the sources (URL, SHA-256),
# the recipes (with the reason of every workaround) and the tests are all in this script.
#
#   tests/projects.sh --sdk SDK_TARBALL [--osxcross DIR] [options]
#       DIR is an OSXCross target, or a checkout of OSXCross (e.g. ~/dev/osxcross) whose target/ is used if it
#       is built; else a target is built from `git archive` of the checkout. Without --osxcross, OSXCross is
#       cloned (OSXCROSS_GIT, OSXCROSS_REF: github.com/tpoechtrager/osxcross, master) and built. A built target
#       is kept in build/osxcross of this repository for the next run; a checkout is never written.
# Options:
#   --sdk TARBALL     the SDK tarball (MacOSX<VER>-open-sdk-<hash>.tar.xz, or -open-core-sdk-: then the projects
#                     that need frameworks are skipped); it is unpacked into the work directory and selected
#                     with SDKROOT, so one target builds with every SDK
#   --flavor NAME     build OSXCross with this flavor, llvm or stable, also if the checkout has a target
#   --llvm DIR        bin directory of the clang that the wrappers of OSXCross run, also to build OSXCross
#                     (default: the one of the PATH)
#   --target VERSION  deployment target (default 11.0)
#   --arch "A B"      architectures: x86_64 arm64 (default both; arm64 is built, never run)
#   --only "A B"      only these projects (and what they need); --list shows the names
#   --group NAME      main (default), compilers (llvm, compiler-rt, cctools-port: very large), games
#                     (Cube 2: Sauerbraten; needs 7z) or all
#   --jobs N          parallel jobs per architecture (default: CPUs / number of architectures)
#   --work DIR        the downloads (kept as a cache) and one directory per run (default: build/projects
#                     of this repository)
#   --ssh HOST        copy the x86_64 programs and tests to the Mac HOST (a directory of its own below
#                     ~/oc-projects.noindex), run them and delete it; nothing is installed there
#   --keep            keep the directory of the run (WORK/run.PID.XXXXXX); without it, it is deleted
#                     at the end unless something failed
#   -v, --verbose     also show the output of the downloads, builds and tests (it is in the logs anyway),
#                     each line with [ARCH PROJECT] in front
#   --list            list the projects and exit
#
# The script runs with a clean environment (PATH, HOME, TERM, SSH_AUTH_SOCK and USER only). Logs:
# WORK/logs/PROJECT.ARCH.log. At the end a table shows build and test of every project and
# architecture; the exit status is 0 only if all of them are ok.
# Before anything is built the script checks that the compiler uses the SDK of the tarball (-isysroot,
# -syslibroot), and for one program of every project that LC_BUILD_VERSION holds the deployment target
# and the version of that SDK.
set -u
if [ -z "${OC_PROJECTS_CLEAN:-}" ]; then
  exec env -i OC_PROJECTS_CLEAN=1 PATH="$PATH" HOME="$HOME" TERM="${TERM:-dumb}" LC_ALL=C \
    USER="${USER:-}" SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}" "${BASH:-bash}" "$0" "$@"
fi
[ -n "${SSH_AUTH_SOCK:-}" ] || unset SSH_AUTH_SOCK
REPO=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/lib/osxcross.sh
. "$REPO/tests/lib/osxcross.sh"


OSX=; SDKTAR=; FLAVOR=; LLVMBIN=; TARGET=11.0; ARCHS="x86_64 arm64"; ONLY=; SEL=main
JOBS=; WORK=; SSH=; KEEP=0; VERBOSE=0

die() { echo "projects.sh: $*" >&2; exit 2; }
# say TEXT: a line of progress with the time
say() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
# capture LOG LABEL: append stdin to LOG; with --verbose also show it, each line with [LABEL] in front
capture() {
  local l
  if [ "$VERBOSE" = 1 ]; then
    while IFS= read -r l; do printf '%s\n' "$l" >> "$1"; printf '[%s] %s\n' "$2" "$l"; done
  else
    cat >> "$1"
  fi
}
# ---------------------------------------------------------------------------------------------
# Projects, in the order they are built: name; group (main: the default, compilers: very large, games: needs
# 7z for the disk images of SDL); source (- for the name, else the source of another project); what it needs
# (comma-separated; built before it and installed in one prefix per architecture); what only the full SDK has
# (with a core SDK the project is skipped; - for nothing)
projects() {
  cat <<'TABLE'
zlib           main       -        -                       -
bzip2          main       -        -                       -
xz             main       -        -                       -
zstd           main       -        -                       -
lz4            main       -        -                       -
brotli         main       -        -                       -
libarchive     main       -        -                       CommonCrypto
expat          main       -        -                       -
libxml2        main       -        -                       -
libyaml        main       -        -                       -
jansson        main       -        -                       -
cjson          main       -        -                       -
json-c         main       -        -                       -
jq             main       -        -                       -
sqlite         main       -        -                       -
pcre2          main       -        -                       -
oniguruma      main       -        -                       -
nlohmann-json  main       -        -                       -
libevent       main       -        -                       -
gmp            main       -        -                       -
mpfr           main       -        gmp                     -
mbedtls        main       -        -                       -
nghttp2        main       -        -                       -
c-ares         main       -        -                       SystemConfiguration
libssh2        main       -        mbedtls                 -
curl           main       -        mbedtls,nghttp2,c-ares  SystemConfiguration
curl-st        main       curl     nghttp2,c-ares          Security
libressl       main       -        -                       -
libffi         main       -        -                       -
lua            main       -        -                       libedit
libedit        main       -        -                       ncurses
readline       main       -        -                       -
ncurses        main       -        -                       -
tmux           main       -        libevent,ncurses        -
fmt            main       -        -                       -
spdlog         main       -        -                       -
googletest     main       -        -                       -
ninja          main       -        -                       -
cmake          main       -        -                       zlib
libpng         main       -        -                       zlib
libjpeg-turbo  main       -        -                       -
libtiff        main       -        -                       -
pkgconf        main       -        -                       -
libiconv       main       -        -                       -
gettext        main       -        -                       -
libsodium      main       -        -                       -
file           main       -        -                       -
gnumake        main       -        -                       -
bash           main       -        -                       ncurses
nano           main       -        ncurses                 -
less           main       -        -                       -
htop           main       -        ncurses                 IOKit
coreutils      main       -        gmp                     -
grep           main       -        -                       -
sed            main       -        -                       -
gawk           main       -        -                       -
findutils      main       -        -                       -
rsync          main       -        -                       -
openssh        main       -        -                       zlib
git            main       -        -                       CoreServices
libgit2        main       -        -                       -
libgit2-st     main       libgit2  -                       Security
redis          main       -        -                       -
freetype       main       -        -                       -
xxhash         main       -        -                       -
lmdb           main       -        -                       -
fswatch        main       -        -                       CoreServices
hidapi         main       -        -                       IOKit
libusb         main       -        -                       IOKit
libuv          main       -        -                       -
libzip         main       -        -                       zlib,CommonCrypto
openvpn        main       -        mbedtls,lz4             -
sudo           main       -        -                       OpenPAM
glew           main       -        -                       OpenGL
dfu-util       main       -        libusb                  IOKit
osx-cpu-temp   main       -        -                       IOKit
efsw           main       -        -                       CoreServices
aria2          main       -        -                       zlib,Security
libcbor        main       -        -                       -
libfido2       main       -        libcbor,libressl        zlib,IOKit
vim            main       -        ncurses                 -
tcpdump        main       -        -                       libpcap
llvm           compilers  -        -                       -
compiler-rt    compilers  llvm     -                       -
cctools-port   compilers  -        -                       -
sauerbraten    games      -        -                       OpenGL
TABLE
}
proj_field() { projects | awk -v n="$1" -v f="$2" '$1 == n { print $f }'; }
# group_projects GROUP: the projects of GROUP (all: every project), in build order
group_projects() { projects | awk -v g="$1" 'g == "all" || $2 == g { printf "%s ", $1 }'; }
deps_of() { local d; d=$(proj_field "$1" 4); [ "$d" = - ] || echo "$d" | tr , ' '; }
# is_dep NAME: another project needs it (it is installed in the prefix of the architecture)
is_dep() { projects | awk -v n="$1" 'index("," $4 ",", "," n ",") { f = 1 } END { exit !f }'; }
# full_only NAME: prints what of the full SDK the project needs; fails if the core SDK is enough
full_only() { local f; f=$(proj_field "$1" 5); [ -n "$f" ] && [ "$f" != - ] && echo "$f"; }
# missing_tool NAME: prints a tool of the build host that the project needs and that is missing
missing_tool() {
  case $1 in
    sauerbraten) command -v 7zz >/dev/null 2>&1 || command -v 7z >/dev/null 2>&1 || echo 7z;;
  esac
}
# extra_sources NAME: the sources that the recipe of NAME fetches besides its own
extra_sources() { case $1 in sauerbraten) echo "sdl2 sdl2-image sdl2-mixer";; esac; }
src_name() { local s; s=$(proj_field "$1" 3); if [ "$s" = - ]; then echo "$1"; else echo "$s"; fi; }

usage() { awk 'NR >= 3 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"; }

while [ $# -gt 0 ]; do
  case $1 in
    --osxcross) [ $# -ge 2 ] || die "$1 needs a value"; OSX=$2; shift 2;;
    --sdk) [ $# -ge 2 ] || die "$1 needs a value"; SDKTAR=$2; shift 2;;
    --flavor) [ $# -ge 2 ] || die "$1 needs a value"; FLAVOR=$2; shift 2;;
    --llvm) [ $# -ge 2 ] || die "$1 needs a value"; LLVMBIN=$2; shift 2;;
    --target) [ $# -ge 2 ] || die "$1 needs a value"; TARGET=$2; shift 2;;
    --arch) [ $# -ge 2 ] || die "$1 needs a value"; ARCHS=$2; shift 2;;
    --only) [ $# -ge 2 ] || die "$1 needs a value"; ONLY=$2; shift 2;;
    --group) [ $# -ge 2 ] || die "$1 needs a value"; SEL=$2; shift 2;;
    --jobs) [ $# -ge 2 ] || die "$1 needs a value"; JOBS=$2; shift 2;;
    --work) [ $# -ge 2 ] || die "$1 needs a value"; WORK=$2; shift 2;;
    --ssh) [ $# -ge 2 ] || die "$1 needs a value"; SSH=$2; shift 2;;
    --keep) KEEP=1; shift;;
    -v|--verbose) VERBOSE=1; shift;;
    --list) for g in main compilers games; do echo "$g: $(group_projects $g)"; done; exit 0;;
    -h|--help) usage; exit 0;;
    *) die "unknown option $1 (see --help)";;
  esac
done
[ -f "$SDKTAR" ] || die "give --sdk TARBALL (see --help)"
SDKTAR=$(cd "$(dirname "$SDKTAR")" && pwd)/$(basename "$SDKTAR")
case $FLAVOR in ''|llvm|stable) ;; *) die "--flavor is llvm or stable";; esac
for a in $ARCHS; do case $a in x86_64|arm64) ;; *) die "unknown architecture $a";; esac; done
NARCH=$(echo "$ARCHS" | wc -w | tr -d ' ')
if [ -z "$JOBS" ]; then
  JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
  JOBS=$((JOBS / NARCH))
  [ "$JOBS" -ge 1 ] || JOBS=1
fi
if [ -z "$LLVMBIN" ]; then
  c=$(command -v clang) && LLVMBIN=$(dirname "$c")
fi
if [ -z "$WORK" ]; then
  # build/ of this repository (as for make-open-sdk.sh): the downloads stay there for the next run
  WORK=$REPO/build/projects
fi
mkdir -p "$WORK" || exit 2
WORK=$(cd "$WORK" && pwd)
DL=$WORK/dl
mkdir -p "$DL" || exit 2
# every run builds in a directory of its own below WORK (run.PID.XXXXXX): the SDK, builds, installations,
# logs and results. It is deleted at the end and after Ctrl-C; --keep keeps it, and so does a run with
# failures (for the logs). Runs at the same time share only the downloads.
for d in "$WORK"/run.*; do
  [ -d "$d" ] || continue
  [ -f "$d/.kept" ] && continue   # kept on purpose (--keep or a failure): the user deletes it
  pid=${d#"$WORK"/run.}; pid=${pid%%.*}
  case $pid in *[!0-9]*|'') continue;; esac
  kill -0 "$pid" 2>/dev/null && continue
  say "deleting $d (left by run $pid, which is gone)"; rm -rf "$d"
done
RUN=$(mktemp -d "$WORK/run.$$.XXXXXX") || exit 2
say "created $RUN"
LOGS=$RUN/logs; RES=$RUN/results
mkdir -p "$LOGS" "$RES" || exit 2
RUN_OK=0; INTERRUPTED=0
finish() {
  if [ "$INTERRUPTED" = 1 ] && [ "$KEEP" != 1 ]; then
    say "interrupted: deleting $RUN"; rm -rf "$RUN"; say "deleted $RUN"
  elif [ "$KEEP" = 1 ] || [ "$RUN_OK" != 1 ]; then
    : > "$RUN/.kept"
    say "kept $RUN (logs in $LOGS)"
  else
    say "deleting $RUN"; rm -rf "$RUN"; say "deleted $RUN"
  fi
}
trap 'finish' EXIT
# kill_tree PID: the process and everything it started (make, the compilers; they ignore SIGINT,
# because the builders run in the background)
kill_tree() {
  local c
  for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; done
  kill "$1" 2>/dev/null
}
BUILDERS=
# Ctrl-C: stop the builds of both architectures, then finish deletes the directory (unless --keep)
interrupted() {
  INTERRUPTED=1
  trap '' INT TERM
  local p
  for p in $BUILDERS; do kill_tree "$p"; done
  wait 2>/dev/null
  exit 130
}
trap 'interrupted' INT TERM

# ---------------------------------------------------------------------------------------------
# Sources: name, version, URL, SHA-256 of the release tarball (checked after the download)
sources() {
  cat <<'TABLE'
zlib 1.3.1 https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz 9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
bzip2 1.0.8 https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269
xz 5.8.1 https://github.com/tukaani-project/xz/releases/download/v5.8.1/xz-5.8.1.tar.xz 0b54f79df85912504de0b14aec7971e3f964491af1812d83447005807513cd9e
zstd 1.5.7 https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3
lz4 1.10.0 https://github.com/lz4/lz4/releases/download/v1.10.0/lz4-1.10.0.tar.gz 537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b
brotli 1.1.0 https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff
libarchive 3.8.1 https://github.com/libarchive/libarchive/releases/download/v3.8.1/libarchive-3.8.1.tar.xz 19f917d42d530f98815ac824d90c7eaf648e9d9a50e4f309c812457ffa5496b5
expat 2.7.1 https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.xz 354552544b8f99012e5062f7d570ec77f14b412a3ff5c7d8d0dae62c0d217c30
libxml2 2.14.4 https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.4.tar.xz 24175ec30a97cfa86bdf9befb7ccf4613f8f4b2713c5103e0dd0bc9c711a2773
libyaml 0.2.5 https://github.com/yaml/libyaml/releases/download/0.2.5/yaml-0.2.5.tar.gz c642ae9b75fee120b2d96c712538bd2cf283228d2337df2cf2988e3c02678ef4
jansson 2.14.1 https://github.com/akheron/jansson/releases/download/v2.14.1/jansson-2.14.1.tar.gz 2521cd51a9641d7a4e457f7215a4cd5bb176f690bc11715ddeec483e85d9e2b3
cjson 1.7.18 https://github.com/DaveGamble/cJSON/archive/refs/tags/v1.7.18.tar.gz 3aa806844a03442c00769b83e99970be70fbef03735ff898f4811dd03b9f5ee5
json-c 0.18 https://github.com/json-c/json-c/archive/refs/tags/json-c-0.18-20240915.tar.gz 3112c1f25d39eca661fe3fc663431e130cc6e2f900c081738317fba49d29e298
sqlite 3.50.2 https://www.sqlite.org/2025/sqlite-autoconf-3500200.tar.gz 84a616ffd31738e4590b65babb3a9e1ef9370f3638e36db220ee0e73f8ad2156
pcre2 10.45 https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.bz2 21547f3516120c75597e5b30a992e27a592a31950b5140e7b8bfde3f192033c4
oniguruma 6.9.10 https://github.com/kkos/oniguruma/releases/download/v6.9.10/onig-6.9.10.tar.gz 2a5cfc5ae259e4e97f86b68dfffc152cdaffe94e2060b770cb827238d769fc05
jq 1.8.0 https://github.com/jqlang/jq/releases/download/jq-1.8.0/jq-1.8.0.tar.gz 91811577f91d9a6195ff50c2bffec9b72c8429dc05ec3ea022fd95c06d2b319c
libevent 2.1.12 https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz 92e6de1be9ec176428fd2367677e61ceffc2ee1cb119035037a27d346b0403bb
libuv 1.51.0 https://dist.libuv.org/dist/v1.51.0/libuv-v1.51.0.tar.gz 5f0557b90b1106de71951a3c3931de5e0430d78da1d9a10287ebc7a3f78ef8eb
c-ares 1.34.5 https://github.com/c-ares/c-ares/releases/download/v1.34.5/c-ares-1.34.5.tar.gz 7d935790e9af081c25c495fd13c2cfcda4792983418e96358ef6e7320ee06346
nghttp2 1.65.0 https://github.com/nghttp2/nghttp2/releases/download/v1.65.0/nghttp2-1.65.0.tar.xz f1b9df5f02e9942b31247e3d415483553bc4ac501c87aa39340b6d19c92a9331
mbedtls 3.6.4 https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.4/mbedtls-3.6.4.tar.bz2 ec35b18a6c593cf98c3e30db8b98ff93e8940a8c4e690e66b41dfc011d678110
libssh2 1.11.1 https://libssh2.org/download/libssh2-1.11.1.tar.xz 9954cb54c4f548198a7cbebad248bdc87dd64bd26185708a294b2b50771e3769
curl 8.14.1 https://curl.se/download/curl-8.14.1.tar.xz f4619a1e2474c4bbfedc88a7c2191209c8334b48fa1f4e53fd584cc12e9120dd
libressl 4.1.0 https://cdn.openbsd.org/pub/OpenBSD/LibreSSL/libressl-4.1.0.tar.gz 0f71c16bd34bdaaccdcb96a5d94a4921bfb612ec6e0eba7a80d8854eefd8bb61
libffi 3.4.8 https://github.com/libffi/libffi/releases/download/v3.4.8/libffi-3.4.8.tar.gz bc9842a18898bfacb0ed1252c4febcc7e78fa139fd27fdc7a3e30d9d9356119b
gmp 6.3.0 https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
mpfr 4.2.2 https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.2.tar.xz b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01
lua 5.4.7 https://www.lua.org/ftp/lua-5.4.7.tar.gz 9fbf5e28ef86c69858f6d3d34eccc32e911c1a28b4120ff3e84aaa70cfbf1e30
ncurses 6.5 https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz 136d91bc269a9a5785e5f9e980bc76ab57428f604ce3e5a5a90cebc767971cc6
readline 8.2 https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz 3feb7171f16a84ee82ca18a36d7b9be109a52c04f492a053331d7d1095007c35
libedit 20250104-3.1 https://thrysoee.dk/editline/libedit-20250104-3.1.tar.gz 23792701694550a53720630cd1cd6167101b5773adddcb4104f7345b73a568ac
tmux 3.5a https://github.com/tmux/tmux/releases/download/3.5a/tmux-3.5a.tar.gz 16216bd0877170dfcc64157085ba9013610b12b082548c7c9542cc0103198951
fmt 11.2.0 https://github.com/fmtlib/fmt/archive/refs/tags/11.2.0.tar.gz bc23066d87ab3168f27cef3e97d545fa63314f5c79df5ea444d41d56f962c6af
spdlog 1.15.3 https://github.com/gabime/spdlog/archive/refs/tags/v1.15.3.tar.gz 15a04e69c222eb6c01094b5c7ff8a249b36bb22788d72519646fb85feb267e67
nlohmann-json 3.12.0 https://github.com/nlohmann/json/archive/refs/tags/v3.12.0.tar.gz 4b92eb0c06d10683f7447ce9406cb97cd4b453be18d7279320f7b2f025c10187
googletest 1.17.0 https://github.com/google/googletest/releases/download/v1.17.0/googletest-1.17.0.tar.gz 65fab701d9829d38cb77c14acdc431d2108bfdbf8979e40eb8ae567edf10b27c
ninja 1.13.0 https://github.com/ninja-build/ninja/archive/refs/tags/v1.13.0.tar.gz f08641d00099a9e40d44ec0146f841c472ae58b7e6dd517bee3945cfd923cedf
cmake 4.0.3 https://github.com/Kitware/CMake/releases/download/v4.0.3/cmake-4.0.3.tar.gz 8d3537b7b7732660ea247398f166be892fe6131d63cc291944b45b91279f3ffb
libpng 1.6.50 https://download.sourceforge.net/libpng/libpng-1.6.50.tar.xz 4df396518620a7aa3651443e87d1b2862e4e88cad135a8b93423e01706232307
libjpeg-turbo 3.1.1 https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.1/libjpeg-turbo-3.1.1.tar.gz aadc97ea91f6ef078b0ae3a62bba69e008d9a7db19b34e4ac973b19b71b4217c
libtiff 4.7.0 https://download.osgeo.org/libtiff/tiff-4.7.0.tar.gz 67160e3457365ab96c5b3286a0903aa6e78bdc44c4bc737d2e486bcecb6ba976
pkgconf 2.5.1 https://distfiles.ariadne.space/pkgconf/pkgconf-2.5.1.tar.xz cd05c9589b9f86ecf044c10a2269822bc9eb001eced2582cfffd658b0a50c243
libiconv 1.18 https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz 3b08f5f4f9b4eb82f151a7040bfd6fe6c6fb922efe4b1659c66ea933276965e8
gettext 0.25 https://ftp.gnu.org/gnu/gettext/gettext-0.25.tar.xz 05240b29f5b0f422e5a4ef8e9b5f76d8fa059cc057693d2723cdb76f36a88ab0
libsodium 1.0.20 https://download.libsodium.org/libsodium/releases/libsodium-1.0.20.tar.gz ebb65ef6ca439333c2bb41a0c1990587288da07f6c7fd07cb3a18cc18d30ce19
file 5.46 https://astron.com/pub/file/file-5.46.tar.gz c9cc77c7c560c543135edc555af609d5619dbef011997e988ce40a3d75d86088
gnumake 4.4.1 https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3
bash 5.2.37 https://ftp.gnu.org/gnu/bash/bash-5.2.37.tar.gz 9599b22ecd1d5787ad7d3b7bf0c59f312b3396d1e281175dd1f8a4014da621ff
nano 8.5 https://www.nano-editor.org/dist/v8/nano-8.5.tar.xz 000b011d339c141af9646d43288f54325ff5c6e8d39d6e482b787bbc6654c26a
less 679 https://www.greenwoodsoftware.com/less/less-679.tar.gz 9b68820c34fa8a0af6b0e01b74f0298bcdd40a0489c61649b47058908a153d78
htop 3.4.1 https://github.com/htop-dev/htop/releases/download/3.4.1/htop-3.4.1.tar.xz 904f7d4580fc11cffc7e0f06895a4789e0c1c054435752c151e812fead9f6220
coreutils 9.7 https://ftp.gnu.org/gnu/coreutils/coreutils-9.7.tar.xz e8bb26ad0293f9b5a1fc43fb42ba970e312c66ce92c1b0b16713d7500db251bf
grep 3.12 https://ftp.gnu.org/gnu/grep/grep-3.12.tar.xz 2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9
sed 4.9 https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz 6e226b732e1cd739464ad6862bd1a1aba42d7982922da7a53519631d24975181
gawk 5.3.2 https://ftp.gnu.org/gnu/gawk/gawk-5.3.2.tar.xz f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc
findutils 4.10.0 https://ftp.gnu.org/gnu/findutils/findutils-4.10.0.tar.xz 1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5
rsync 3.4.1 https://download.samba.org/pub/rsync/src/rsync-3.4.1.tar.gz 2924bcb3a1ed8b551fc101f740b9f0fe0a202b115027647cf69850d65fd88c52
openssh 10.0p1 https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.0p1.tar.gz 021a2e709a0edf4250b1256bd5a9e500411a90dddabea830ed59cef90eb9d85c
git 2.50.1 https://www.kernel.org/pub/software/scm/git/git-2.50.1.tar.xz 7e3e6c36decbd8f1eedd14d42db6674be03671c2204864befa2a41756c5c8fc4
libgit2 1.9.1 https://github.com/libgit2/libgit2/archive/refs/tags/v1.9.1.tar.gz 14cab3014b2b7ad75970ff4548e83615f74d719afe00aa479b4a889c1e13fc00
redis 8.0.3 https://github.com/redis/redis/archive/refs/tags/8.0.3.tar.gz 2467b9608ecbcc2c0d27397c0c2406b499b6f68bc08ac9f6380b1faf2113ae6f
freetype 2.13.3 https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz 0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289
xxhash 0.8.3 https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.3.tar.gz aae608dfe8213dfd05d909a57718ef82f30722c392344583d3f39050c7f29a80
lmdb 0.9.33 https://github.com/LMDB/lmdb/archive/refs/tags/LMDB_0.9.33.tar.gz 9c352fa9bdad53d920128ac6a62296f2850c7e29862a610d3a72f5f49a1cd7ea
fswatch 1.17.1 https://github.com/emcrisostomo/fswatch/releases/download/1.17.1/fswatch-1.17.1.tar.gz c38e341c567f5f16bfa64b72fc48bba5e93873d8572522e670e6f320bbc2122f
hidapi 0.16.0 https://github.com/libusb/hidapi/archive/refs/tags/hidapi-0.16.0.tar.gz bc599d295792fe515778f19ce86a49760b0ea5fc114e5258245d470609632bbf
libusb 1.0.30 https://github.com/libusb/libusb/releases/download/v1.0.30/libusb-1.0.30.tar.bz2 fea36f34f9156400209595e300840767ab1a385ede1dc7ee893015aea9c6dbaf
libzip 1.11.4 https://github.com/nih-at/libzip/releases/download/v1.11.4/libzip-1.11.4.tar.xz 8a247f57d1e3e6f6d11413b12a6f28a9d388de110adc0ec608d893180ed7097b
openvpn 2.6.14 https://swupdate.openvpn.net/community/releases/openvpn-2.6.14.tar.gz 9eb6a6618352f9e7b771a9d38ae1631b5edfeed6d40233e243e602ddf2195e7a
sudo 1.9.17p1 https://www.sudo.ws/dist/sudo-1.9.17p1.tar.gz ff607ea717072197738a78f778692cd6df9a7e3e404565f51de063ca27455d32
glew 2.2.0 https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz d4fc82893cfb00109578d0a1a2337fb8ca335b3ceccf97b97e5cc7f08e4353e1
dfu-util 0.11 https://dfu-util.sourceforge.net/releases/dfu-util-0.11.tar.gz b4b53ba21a82ef7e3d4c47df2952adf5fa494f499b6b0b57c58c5d04ae8ff19e
osx-cpu-temp 1.1.0 https://github.com/lavoiesl/osx-cpu-temp/archive/refs/tags/1.1.0.tar.gz 94b90ce9a1c7a428855453408708a5557bfdb76fa45eef2b8ded4686a1558363
efsw 1.4.1 https://github.com/SpartanJ/efsw/archive/refs/tags/1.4.1.tar.gz f0ddee587928737c6a3dc92eb88266a804c77279cbdf29d47e5e6f6ad6c7fd9a
aria2 1.37.0 https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0.tar.xz 60a420ad7085eb616cb6e2bdf0a7206d68ff3d37fb5a956dc44242eb2f79b66b
libcbor 0.12.0 https://github.com/PJK/libcbor/archive/refs/tags/v0.12.0.tar.gz 5368add109db559f546d7ed10f440f39a273b073daa8da4abffc83815069fa7f
libfido2 1.15.0 https://developers.yubico.com/libfido2/Releases/libfido2-1.15.0.tar.gz abaab1318d21d262ece416fb8a7132fa9374bda89f6fa52b86a98a2f5712b61e
vim 9.1.1500 https://github.com/vim/vim/archive/refs/tags/v9.1.1500.tar.gz 70f0e75bf77af00b870a967fcb325031f0a32d787bc3cacc1ca1729727d0bbc7
tcpdump 4.99.5 https://www.tcpdump.org/release/tcpdump-4.99.5.tar.gz 8c75856e00addeeadf70dad67c9ff3dd368536b2b8563abf6854d7c764cd3adb
llvm 23.1.6 https://github.com/llvm/llvm-project/releases/download/llvmorg-23.1.6/llvm-project-23.1.6.src.tar.xz d3b86ab29cfb4445a6652e5c2642ccc75e04e38084dde3701d323320f35a31da
cctools-port 986-ld64-711 https://github.com/tpoechtrager/cctools-port/archive/c78fd67397591cd47aecde7dd162c89a4a7faae5.tar.gz 4e7b8904e9419737a2d5c578454e0ce86c184d6721b6f214d63409f2c63dfe5b
sauerbraten 2020_12_29 https://downloads.sourceforge.net/project/sauerbraten/sauerbraten/2020_11_29/sauerbraten_2020_12_29_linux.tar.bz2 cdba7c4a47cefd30d0afdd6a912199a1384319cf1619923cb7189e72e468be70
sdl2 2.32.10 https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.dmg 4a7ac31640d70214e848f994be8a12849c0f97918a7e6c2e27a40036166d1a7f
sdl2-image 2.8.12 https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.12/SDL2_image-2.8.12.dmg 3f2599c44b2fc536a1248b58c3e7766ad157c9e14fafcbb6f9d85678c8fb3bed
sdl2-mixer 2.8.2 https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.8.2/SDL2_mixer-2.8.2.dmg 3ad8af90531596403d5a914aae4bcc3feff209cfa4ea493211ea21a10e0b9adf
TABLE
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}
src_field() { sources | awk -v n="$1" -v f="$2" '$1 == n { print $f }'; }
src_file() { echo "$DL/$1-$(basename "$(src_field "$1" 3)")"; }

# mirrors URL: the URLs to try; for a file of ftp.gnu.org the mirrors first (ftp.gnu.org itself is
# often unreachable), the same path on each
mirrors() {
  case $1 in
    https://ftp.gnu.org/gnu/*)
      echo "https://mirrors.kernel.org/gnu/${1#https://ftp.gnu.org/gnu/} https://ftpmirror.gnu.org/gnu/${1#https://ftp.gnu.org/gnu/} $1";;
    *) echo "$1";;
  esac
}
# download URL FILE: curl with short timeouts (no connection in 5 s, or less than 1 KB/s for 15 s:
# a new try). Up to 3 tries (none more after another 4xx); HTTP 429 and 503 (the server asks to wait) up to 6 tries, waiting as long
# as its Retry-After says (at most 300 s) or 15, 30, 60, 120, 240 s.
download() {
  local try=0 code wait=15 ra hdr=$2.hdr
  while :; do
    try=$((try + 1))
    if [ "$VERBOSE" = 1 ]; then
      code=$(curl -L --connect-timeout 5 --speed-limit 1024 --speed-time 15 -# -D "$hdr" -o "$2" -w '%{http_code}' "$1")
    else
      code=$(curl -sSL --connect-timeout 5 --speed-limit 1024 --speed-time 15 -D "$hdr" -o "$2" -w '%{http_code}' "$1")
    fi
    case $code in
      2??) rm -f "$hdr"; return 0;;
      429|503)
        [ "$try" -lt 6 ] || break
        ra=$(tr -d '\r' < "$hdr" 2>/dev/null | awk 'tolower($1) == "retry-after:" { v = $2 } END { print v }')
        case $ra in ''|*[!0-9]*) ra=$wait;; esac
        [ "$ra" -le 300 ] || ra=300
        say "$1: HTTP $code (the server asks to wait), try $((try + 1)) in $ra s"
        sleep "$ra"; wait=$((wait * 2));;
      4??) say "$1: HTTP $code"; break;;   # missing or forbidden: no use to try again
      *)
        [ "$try" -lt 3 ] || break
        case $code in 000|'') code="no connection or too slow";; *) code="HTTP $code";; esac
        say "$1: $code, try $((try + 1)) in 2 s"
        sleep 2;;
    esac
  done
  rm -f "$hdr"
  return 1
}

# fetch NAME: download once into the cache and check the SHA-256
fetch() {
  local f url want u got part
  f=$(src_file "$1"); url=$(src_field "$1" 3); want=$(src_field "$1" 4)
  [ -n "$url" ] || { echo "no source for $1" >&2; return 1; }
  if [ -f "$f" ]; then
    if [ "$(sha256 "$f")" = "$want" ]; then
      [ "$VERBOSE" = 1 ] && say "cached $1: $f"
      return 0
    fi
    say "cached $1 has a wrong SHA-256: removed, downloading it again"
    rm -f "$f"
  fi
  # GNU: ftp.gnu.org is often unreachable; the same files are on the mirrors. A download goes into the
  # cache only with the right SHA-256; otherwise the next mirror is tried.
  for u in $(mirrors "$url"); do
    say "download $1: $u"
    # a name of its own: the builders of both architectures may fetch the same file
    part=$(mktemp "$f.part.XXXXXX") || return 1
    download "$u" "$part" || { rm -f "$part"; say "download of $u failed"; continue; }
    got=$(sha256 "$part")
    if [ "$got" = "$want" ]; then
      mv "$part" "$f"
      return 0
    fi
    rm -f "$part"; say "$u: wrong SHA-256 $got (want $want), discarded"
  done
  echo "no download of $1 with the SHA-256 $want" >&2
  return 1
}

# ---------------------------------------------------------------------------------------------
# The OSXCross target and the SDK of the tarball
# setup_osxcross: OSX is the target to use (see --osxcross)
setup_osxcross() {
  local src="" t
  if [ -n "$OSX" ] && [ -z "$FLAVOR" ] && t=$(osxcross_target "$OSX"); then OSX=$t; return 0; fi
  if [ -n "$OSX" ]; then
    [ -f "$OSX/build.sh" ] || die "$OSX is neither an OSXCross target nor a checkout"
    src=$(cd "$OSX" && pwd)
  fi
  [ -n "$LLVMBIN" ] || [ "${FLAVOR:-llvm}" != llvm ] || die "no clang in the PATH; give --llvm"
  say "OSXCross: the target of ${OSX:-a clone} (built once and kept in $REPO/build/osxcross; log $LOGS/osxcross.log)"
  OSX=$(osxcross_build "$src" "$REPO/build/osxcross" "$SDKTAR" "${FLAVOR:-llvm}" "$LLVMBIN" "$LOGS/osxcross.log") || return 1
  say "OSXCross: $OSX"
}

# norm_version V: 11.0 -> 11, 26.5 -> 26.5 (otool prints the shortest form)
norm_version() { echo "$1" | sed -e 's/\(\.0\)*$//'; }

# verify_sdk: the configuration of the target, and the SDK of the tarball selected with SDKROOT
verify_sdk() {
  osxcross_conf "$OSX" || return 1
  DARWIN=$OSXCROSS_TARGET
  # the SDK of the tarball is unpacked into the work directory and selected with SDKROOT (OSXCross takes
  # SDKROOT before the SDK of the target): one target can build with any SDK
  sdk_select "$SDKTAR" "$RUN/sdk" || return 1
  SDKROOT=$SDK; export SDKROOT
  echo "SDK: $(basename "$SDKTAR") in $SDK (macOS $SDKVER, $VARIANT, commit $(sed -n 's/.*"commit": "\([0-9a-f]*\)".*/\1/p' "$SDK/OpenSDK.json" | head -n 1 | cut -c1-12)), selected with SDKROOT"
}

# arch variables: ARCH (x86_64|arm64), HOST (autotools triple: aarch64 for arm64), CMW (wrapper prefix)
arch_vars() {
  ARCH=$1
  case $1 in
    arm64) HOST=aarch64-apple-$DARWIN;;
    *) HOST=$1-apple-$DARWIN;;
  esac
  CMW=$1-apple-$DARWIN
}

# macho_versions ARCH FILE: sets MINOS and SDKV from the LC_BUILD_VERSION of FILE
macho_versions() {
  local out
  arch_vars "$1"
  out=$("$OSX/bin/$CMW-otool" -l "$2" 2>/dev/null | awk '
    /cmd LC_BUILD_VERSION/ { f = 1; next }
    f && $1 == "minos" { m = $2 }
    f && $1 == "sdk" { s = $2 }
    f && /^Load command/ { exit }
    END { if (m != "" && s != "") print m, s }') || return 1
  [ -n "$out" ] || return 1
  MINOS=${out% *}; SDKV=${out#* }
}

# verify_compiler ARCH: -v of a compile and a link names the SDK as -isysroot and -syslibroot
verify_compiler() {
  local t=$RUN/cctest.$1 p opt
  arch_vars "$1"
  rm -rf "$t"; mkdir -p "$t"
  echo 'int main(void) { return 0; }' > "$t/t.c"
  ( cd "$t" && env -i PATH="$TOOLPATH" SDKROOT="$SDK" MACOSX_DEPLOYMENT_TARGET="$TARGET" \
      "$HOST-clang" -v -o t t.c ) > "$t/log" 2>&1 || { cat "$t/log" >&2; return 1; }
  for opt in -isysroot -syslibroot; do
    p=$(tr ' ' '\n' < "$t/log" | tr -d '"' | grep -A1 -x -- "$opt" | sed -n '2p' | head -n 1)
    [ -n "$p" ] || { echo "$1: the compiler does not pass $opt (see $t/log)" >&2; return 1; }
    p=$(cd "$p" 2>/dev/null && pwd -P)
    [ "$p" = "$SDK" ] || { echo "$1: $opt is $p, not $SDK" >&2; return 1; }
  done
  macho_versions "$1" "$t/t" || { echo "$1: no LC_BUILD_VERSION in the test program" >&2; return 1; }
  [ "$(norm_version "$MINOS")" = "$(norm_version "$TARGET")" ] && [ "$(norm_version "$SDKV")" = "$(norm_version "$SDKVER")" ] \
    || { echo "$1: test program has minos $MINOS sdk $SDKV, wanted $TARGET and $SDKVER" >&2; return 1; }
  echo "compiler $1: -isysroot and -syslibroot are the SDK; minos $MINOS, sdk $SDKV"
}

# ---------------------------------------------------------------------------------------------
fnname() { echo "$1" | sed 's/-/_/g'; }

# the projects to run, in build order, with what they need
select_projects() {
  local list want n d all
  all=$(group_projects all)
  if [ -n "$ONLY" ]; then
    list=$ONLY
    for n in $ONLY; do case " $all " in *" $n "*) ;; *) die "unknown project $n (see --list)";; esac; done
  else
    case $SEL in main|compilers|games|all) list=$(group_projects "$SEL");; *) die "--group is main, compilers, games or all";; esac
  fi
  want=" $list "
  for _ in 1 2 3; do
    for n in $want; do
      for d in $(deps_of "$n"); do case "$want" in *" $d "*) ;; *) want="$want$d ";; esac; done
    done
  done
  for n in $all; do case "$want" in *" $n "*) echo "$n";; esac; done
}

# ---------------------------------------------------------------------------------------------
# Environment of one project and architecture
proj_env() {
  NAME=$1; arch_vars "$2"
  FN=$(fnname "$NAME")
  B=$RUN/build/$ARCH/$NAME
  SRC=$B/src
  INST=$RUN/inst/$ARCH/$NAME
  PFX=$RUN/pfx/$ARCH
  if is_dep "$NAME"; then PREFIX=$PFX; else PREFIX=$INST; fi
  RDIR=$RROOT/$NAME
  export PATH=$TOOLPATH
  export MACOSX_DEPLOYMENT_TARGET=$TARGET
  CC=$HOST-clang; CXX=$HOST-clang++; AR=$HOST-ar; RANLIB=$HOST-ranlib; NM=$HOST-nm; STRIP=$HOST-strip
  export CC CXX AR RANLIB NM STRIP
  export OTOOL=$HOST-otool LIPO=$HOST-lipo INSTALL_NAME_TOOL=$HOST-install_name_tool
  export CFLAGS="-O2" CXXFLAGS="-O2" CPPFLAGS="-I$PFX/include" LDFLAGS="-L$PFX/lib"
  # only the libraries of the prefix of this run, never those of the build host
  export PKG_CONFIG_LIBDIR=$PFX/lib/pkgconfig PKG_CONFIG_PATH=
  export CC_FOR_BUILD="gcc -std=gnu17" CXX_FOR_BUILD=g++
  mkdir -p "$PFX/include" "$PFX/lib"
}


unpack() {
  local s
  s=$(src_name "$NAME")
  fetch "$s" || return 1
  mkdir -p "$B/x" || return 1
  tar -xf "$(src_file "$s")" -C "$B/x" || return 1
  SRC=$(find "$B/x" -mindepth 1 -maxdepth 1 | head -n 1)
}

# helpers of the recipes
make_j() { make -j"$JOBS" "$@"; }
# configure_host ARGS: configure for this architecture (the recipe is in the source directory)
configure_host() { ./configure --host="$HOST" --prefix="$PREFIX" "$@"; }
configure_install() { configure_host "$@"; make_j; make_j install; }
# cmake_install SRCDIR ARGS: configure, build and install with CMake and the OSXCross wrapper of the architecture
cmake_install() {
  local s=$1; shift
  "$CMW-cmake" -S "$s" -B "$B/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" -DCMAKE_OSX_DEPLOYMENT_TARGET="$TARGET" \
    -DCMAKE_FIND_ROOT_PATH="$PFX" -DCMAKE_PREFIX_PATH="$PFX" -DCMAKE_IGNORE_PREFIX_PATH=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_POLICY_VERSION_MINIMUM=3.5 "$@"
  cmake --build "$B/build" -j "$JOBS"
  cmake --install "$B/build"
}
# sedi EXPRESSION FILE: change a file in place (GNU and BSD sed differ in -i)
sedi() { sed -e "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }
# stage DIR: what the test copies to the Mac (default: the installation)
stage() { echo "$1" > "$B/.stage"; }
# stage_files BASE FILES...: copy files (relative to BASE) into a directory of their own
stage_files() {
  local base=$1; shift
  rm -rf "$B/stage"; mkdir -p "$B/stage"
  (cd "$base" && tar -cf - "$@") | tar -xf - -C "$B/stage"
  stage "$B/stage"
}

# stage_glob BASE PATTERN: the executable files of BASE that match PATTERN
stage_glob() {
  local f list=
  for f in "$1"/$2; do
    [ -f "$f" ] && [ -x "$f" ] && list="$list $(basename "$f")"
  done
  # shellcheck disable=SC2086 # the names have no blanks
  stage_files "$1" $list
}

# ---------------------------------------------------------------------------------------------
# The Mac: x86_64 programs only
remote_init() {
  [ -n "$SSH" ] || return 0
  RHOME=$(ssh -n -o BatchMode=yes -o ConnectTimeout=20 "$SSH" 'echo $HOME') || return 1
  [ -n "$RHOME" ] || return 1
  RROOT=$RHOME/oc-projects.noindex/run.$$
  ssh -n -o BatchMode=yes "$SSH" "mkdir -p '$RHOME/oc-projects.noindex' && touch '$RHOME/oc-projects.noindex/.metadata_never_index' && mkdir -p '$RROOT'" || return 1
  # a test of x86_64 programs needs an x86_64 Mac
  [ "$(ssh -n -o BatchMode=yes "$SSH" 'uname -m')" = x86_64 ] || { echo "$SSH is no x86_64 Mac" >&2; return 1; }
}
remote_done() {
  [ -n "$SSH" ] && [ -n "${RROOT:-}" ] || return 0
  ssh -n -o BatchMode=yes "$SSH" "rm -rf '$RROOT'; rmdir '$RHOME/oc-projects.noindex' 2>/dev/null; true" # rmdir fails if another run uses it
}
# run_mac COMMAND: run it on the Mac in the directory of the project; the libraries of the stage are found
run_mac() {
  # the command goes to /bin/sh as the script on stdin (the login shell of the Mac is zsh); the libraries of
  # the stage are set in the script, because /bin/sh drops DYLD_* of its environment
  printf 'DYLD_LIBRARY_PATH=%s:%s; export DYLD_LIBRARY_PATH; %s\n' "$RDIR/lib" "$RDIR" "$*" | perl -e 'alarm 600; exec @ARGV' \
    ssh -o BatchMode=yes "$SSH" "cd '$RDIR' && /bin/sh -c \"\$(cat)\""
}
mac_cleanup() { ssh -n -o BatchMode=yes "$SSH" "rm -rf '$RDIR'"; }
mac_push() {
  ssh -n -o BatchMode=yes "$SSH" "rm -rf '$RDIR' && mkdir -p '$RDIR'" || return 1
  tar -C "$1" -cf - . | ssh -o BatchMode=yes "$SSH" "tar -C '$RDIR' -xf -"
}

# ---------------------------------------------------------------------------------------------
# find_macho: a linked program or library of the project (else an object file)
find_macho() {
  local f
  for f in $(find "$INST" "$B/stage" -type f \( -perm -u+x -o -name '*.dylib' \) 2>/dev/null | head -n 300); do
    macho_versions "$ARCH" "$f" && { MACHO=$f; return 0; }
  done
  for f in $(find "$B" -type f \( -name '*.dylib' -o -name '*.o' \) 2>/dev/null | head -n 60); do
    macho_versions "$ARCH" "$f" && { MACHO=$f; return 0; }
  done
  return 1
}

# result NAME ARCH BUILD TEST: BUILD is ok, build, link, check, skip (a dependency failed), core (needs the full
# SDK) or tool (needs a tool that the build host lacks; neither of the last two is a failure); TEST is ok, FAIL or -
result() { echo "$3 $4" > "$RES/$1.$2"; }

# psay TEXT: a line of progress of the project being built, with DONE/TOTAL (the projects of this architecture
# that are done, also those that failed or were skipped, and all of them) and the architecture
psay() { say "[$DONE/$TOTAL] [$arch] $*"; }
run_project() {
  local name=$1 arch=$2 log rc d tst=- fnn t0 what
  proj_env "$name" "$arch"
  fnn=$FN
  log=$LOGS/$name.$arch.log
  if [ "$VARIANT" = core ] && what=$(full_only "$name"); then
    echo "skipped: needs $what of the full SDK" > "$log"; result "$name" "$arch" core -; DONE=$((DONE + 1)); psay "$name: skipped (needs $what of the full SDK)"
    return
  fi
  if what=$(missing_tool "$name") && [ -n "$what" ]; then
    echo "skipped: needs $what on the build host" > "$log"; result "$name" "$arch" tool -; DONE=$((DONE + 1)); psay "$name: skipped (needs $what)"
    return
  fi
  for d in $(deps_of "$name"); do
    case $(cat "$RES/$d.$arch" 2>/dev/null) in
      "ok "*) ;;
      *) echo "skipped: $d did not build" > "$log"; result "$name" "$arch" skip -; DONE=$((DONE + 1)); psay "$name: skipped ($d did not build)"; return;;
    esac
  done
  rm -rf "$B" "$INST"; mkdir -p "$B" "$INST"
  t0=$(date +%s)
  psay "$name: build (log $log)"
  : > "$log"
  (
    set +u -ex
    unpack
    cd "$SRC"
    "build_$fnn"
    : > "$B/.built"
  ) 2>&1 | capture "$log" "$arch $name"
  rc=${PIPESTATUS[0]}
  if [ ! -f "$B/.built" ]; then
    if tail -n 60 "$log" | grep -q 'ld64\.lld\|undefined symbol\|linker command failed\|ld: \|Undefined symbols'; then
      result "$name" "$arch" link -
    else
      result "$name" "$arch" build -
    fi
    DONE=$((DONE + 1)); psay "$name: FAIL (rc $rc), see $log"
    return
  fi
  # LC_BUILD_VERSION of one program of the project: the deployment target and the SDK
  if find_macho >> "$log" 2>&1 && macho_versions "$arch" "$MACHO" \
     && [ "$(norm_version "$MINOS")" = "$(norm_version "$TARGET")" ] && [ "$(norm_version "$SDKV")" = "$(norm_version "$SDKVER")" ]; then
    echo "== LC_BUILD_VERSION ok: $MACHO minos $MINOS sdk $SDKV" >> "$log"
  else
    echo "== LC_BUILD_VERSION wrong or missing: ${MACHO:-none} minos ${MINOS:-?} sdk ${SDKV:-?} (wanted $TARGET and $SDKVER)" >> "$log"
    result "$name" "$arch" check -
    DONE=$((DONE + 1)); psay "$name: FAIL check (LC_BUILD_VERSION), see $log"
    return
  fi
  psay "$name: built in $(( $(date +%s) - t0 )) s"
  if [ "$arch" = x86_64 ] && [ -n "$SSH" ] && [ "$(type -t "test_$fnn")" = function ]; then
    psay "$name: test on $SSH"
    (
      set +u -ex
      trap mac_cleanup EXIT
      cd "$SRC" 2>/dev/null || true
      st=$PREFIX; [ -f "$B/.stage" ] && st=$(cat "$B/.stage")
      mac_push "$st"
      "test_$fnn"
    ) 2>&1 | capture "$log" "$arch $name test"
    if [ "${PIPESTATUS[0]}" = 0 ]; then tst=ok; else tst=FAIL; fi
  fi
  result "$name" "$arch" ok "$tst"
  DONE=$((DONE + 1)); psay "$name: ok, test $tst"
  if [ "$KEEP" != 1 ]; then rm -rf "$B"; is_dep "$name" || rm -rf "$INST"; fi
}

# ---------------------------------------------------------------------------------------------
# Recipes: build_NAME builds and installs in the source directory (the shell stops at the first
# error); test_NAME runs on the Mac in the directory with the copy of what stage names (default: the
# installation; programs are called relative to it)

# --- compression
build_zlib() {
  # the Darwin branch of configure takes /usr/bin/libtool as ar: name ar, CHOST and uname
  CHOST=$HOST uname=Darwin AR="$AR" ARFLAGS=rc ./configure --prefix="$PREFIX"
  make_j AR="$AR" ARFLAGS=rc; make_j install AR="$AR" ARFLAGS=rc
  make_j AR="$AR" ARFLAGS=rc example minigzip
  stage_files . example minigzip
}
test_zlib() { run_mac ./example; run_mac 'echo hello | ./minigzip | ./minigzip -d | grep -qx hello'; }

build_bzip2() {
  # the default target runs the tests, and they are programs of the target
  make_j CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="-O2 -D_FILE_OFFSET_BITS=64" libbz2.a bzip2 bzip2recover
  make_j install PREFIX="$PREFIX" CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="-O2 -D_FILE_OFFSET_BITS=64"
}
test_bzip2() { run_mac 'echo hello | bin/bzip2 | bin/bzip2 -d | grep -qx hello'; }

build_xz() { configure_install --disable-nls; }
test_xz() { run_mac 'echo hello | bin/xz | bin/xz -d | grep -qx hello'; }

build_zstd() {
  # the Makefiles ask uname: Linux would name the library .so
  make_j UNAME=Darwin TARGET_SYSTEM=Darwin CC="$CC" AR="$AR" PREFIX="$PREFIX" install
}
test_zstd() { run_mac 'echo hello | bin/zstd | bin/zstd -d | grep -qx hello'; }

build_lz4() {
  # the Makefile decides by uname (Linux: -soname)
  make_j TARGET_OS=Darwin CC="$CC" AR="$AR" PREFIX="$PREFIX" install
}
test_lz4() { run_mac 'echo hello | bin/lz4 | bin/lz4 -d | grep -qx hello'; }

build_brotli() { cmake_install . -DBROTLI_DISABLE_TESTS=ON; }
test_brotli() { run_mac 'echo hello | bin/brotli | bin/brotli -d | grep -qx hello'; }

build_libarchive() {
  cmake_install . -DENABLE_TEST=OFF -DENABLE_OPENSSL=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DENABLE_LZ4=OFF \
    -DENABLE_LIBXML2=OFF -DENABLE_EXPAT=OFF
}
test_libarchive() {
  run_mac 'mkdir d && echo hi > d/f && bin/bsdtar -cf t.tar d && bin/bsdtar -tf t.tar | grep -q d/f &&
    bin/bsdtar -czf t.tgz d && bin/bsdcat t.tgz | head -c 1 >/dev/null && bin/bsdtar -xzf t.tgz -C /tmp'
}

# --- data formats
build_expat() { configure_install --without-docbook --without-examples --without-tests; }
test_expat() { run_mac "echo '<a><b/></a>' > t.xml && bin/xmlwf t.xml"; }

build_libxml2() { configure_install --without-python --without-lzma; }
test_libxml2() { run_mac "echo '<a><b>x</b></a>' | bin/xmllint --format - | grep -q '  <b>x</b>'"; }

build_libyaml() {
  configure_install --disable-shared
  make_j check TESTS=
  stage_files tests test-version test-reader run-parser run-emitter
}
test_libyaml() { run_mac ./test-version; }

build_jansson() { configure_install; }

build_cjson() {
  cmake_install . -DENABLE_CJSON_TEST=ON -DENABLE_CJSON_UNINSTALL=OFF -DBUILD_SHARED_LIBS=OFF -DBUILD_SHARED_AND_STATIC_LIBS=OFF
  stage_files "$B/build" cJSON_test
}
test_cjson() { run_mac ./cJSON_test; }

build_json_c() {
  # the project builds with -Werror and a new Clang finds warnings (-Wunused-but-set-global): the flags of
  # the build type come after its own
  cmake_install . -DCMAKE_C_FLAGS_RELEASE="-O2 -Wno-error" -DBUILD_TESTING=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON
  stage_glob "$B/build/tests" 'test[A-Za-z0-9_]*'
}
# test_json_patch and test_util_file need data files and arguments (ctest passes them)
test_json_c() { run_mac 'n=0; for t in ./test*; do case $t in ./test_json_patch|./test_util_file) continue;; esac; [ -x $t ] && [ -f $t ] || continue; $t >/dev/null 2>&1 || { echo "FAIL $t"; n=$((n+1)); }; done; test $n = 0'; }

build_jq() { configure_install --disable-docs --disable-maintainer-mode --with-oniguruma=builtin; }
test_jq() { run_mac "echo '{\"a\":[1,2]}' | bin/jq '.a | add' | grep -qx 3"; }

build_sqlite() { configure_install --disable-readline; }
test_sqlite() { run_mac "bin/sqlite3 :memory: 'select 6*7' | grep -qx 42"; }

build_pcre2() { configure_install; }
test_pcre2() { run_mac "printf 'foo\nbar\n' | bin/pcre2grep -n 'ba.' | grep -qx '2:bar'"; }

build_oniguruma() {
  configure_host --disable-shared
  make_j; make_j install
  make_j check TESTS=
  stage_files test testc test_back test_options test_regset
}
test_oniguruma() { run_mac ./testc; run_mac ./test_back; run_mac ./test_options; run_mac ./test_regset; }

build_nlohmann_json() {
  cmake_install . -DJSON_BuildTests=ON -DJSON_Install=ON
  stage_glob "$B/build/tests" 'test-*'
}
test_nlohmann_json() {
  # 15 of the tests read json_test_data, which is not in the release tarball: they are not run
  run_mac 'n=0; r=0; for t in ./test-*; do case $t in *unit*) ;; esac; if $t >/tmp/oc-t.$$ 2>&1; then r=$((r+1)); elif grep -q "json_test_data" /tmp/oc-t.$$; then :; else echo "FAIL $t"; n=$((n+1)); fi; done; rm -f /tmp/oc-t.$$; echo "$r tests passed"; test $n = 0 && test $r -gt 50'
}

# --- network and crypto
build_libevent() {
  configure_host --disable-shared --disable-openssl
  make_j; make_j install
  make_j -C test regress
  stage_files test regress
}
test_libevent() { run_mac './regress --quiet main/.. evbuffer/..'; }

build_gmp() {
  # without --with-pic the assembler parts have text relocations: ld64.lld does not complain and
  # the program dies with SIGBUS at its start
  configure_install --disable-shared --with-pic
}
build_mpfr() { configure_install --disable-shared --with-gmp="$PFX"; }

build_mbedtls() {
  cmake_install . -DENABLE_TESTING=OFF -DENABLE_PROGRAMS=ON -DUSE_SHARED_MBEDTLS_LIBRARY=OFF -DUSE_STATIC_MBEDTLS_LIBRARY=ON
  stage_files "$B/build/programs/test" selftest
}
test_mbedtls() { run_mac ./selftest; }

build_nghttp2() { cmake_install . -DENABLE_LIB_ONLY=ON -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF -DENABLE_STATIC_LIB=ON -DENABLE_SHARED_LIB=OFF -DENABLE_DOC=OFF; }

build_c_ares() {
  cmake_install . -DCARES_STATIC=ON -DCARES_SHARED=OFF -DCARES_BUILD_TESTS=OFF -DCARES_BUILD_TOOLS=ON
  stage "$B/stage"; mkdir -p "$B/stage"; cp "$PFX/bin/ahost" "$B/stage/"
}
test_c_ares() { run_mac './ahost localhost | grep -q 127.0.0.1'; }

build_libssh2() {
  # the libraries of mbedTLS are named: the search of CMake would look below the roots of the toolchain
  cmake_install . -DCRYPTO_BACKEND=mbedTLS -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF \
    -DMBEDTLS_INCLUDE_DIR="$PFX/include" -DMBEDTLS_LIBRARY="$PFX/lib/libmbedtls.a" \
    -DMBEDX509_LIBRARY="$PFX/lib/libmbedx509.a" -DMBEDCRYPTO_LIBRARY="$PFX/lib/libmbedcrypto.a"
}

build_curl() {
  configure_install --with-mbedtls="$PFX" --with-nghttp2="$PFX" --enable-ares="$PFX" --without-libpsl --without-libidn2 \
    --without-brotli --without-zstd --disable-ldap --disable-docs --disable-manual --without-ca-bundle --without-ca-path
}
test_curl() {
  run_mac 'bin/curl -V | grep -q mbedTLS'
  run_mac 'echo hi > f && bin/curl -s "file://$PWD/f" | grep -qx hi'
}

build_curl_st() {
  configure_install --with-secure-transport --with-nghttp2="$PFX" --enable-ares="$PFX" --without-libpsl --without-libidn2 \
    --without-brotli --without-zstd --disable-ldap --disable-docs --disable-manual
}
test_curl_st() { run_mac 'bin/curl -V | grep -q SecureTransport && bin/curl -sI https://example.com | head -n 1 | grep -q 200'; }

build_libressl() { cmake_install . -DLIBRESSL_TESTS=OFF -DLIBRESSL_APPS=ON; }
test_libressl() { run_mac 'bin/openssl version | grep -q LibreSSL && echo hi | bin/openssl sha256 | grep -q 98ea6e4f'; }

build_libffi() { configure_install --disable-docs; }

# --- shells, editors, terminal
build_lua() {
  make_j macosx CC="$CC -std=gnu99" AR="$AR rcu" RANLIB="$RANLIB"
  make_j install INSTALL_TOP="$PREFIX"
}
test_lua() { run_mac "echo 'print(6*7)' | bin/lua - | grep -qx 42"; }

build_libedit() { configure_install --disable-shared --with-pic; }
build_readline() { configure_install --disable-shared; }

build_ncurses() {
  # libraries only (static), wide characters with the terminfo part in its own library (-ltinfow)
  configure_install --without-shared --with-normal --enable-widec --with-termlib --enable-pc-files --with-pkg-config-libdir="$PFX/lib/pkgconfig" \
    --without-progs --without-tests --without-manpages --without-cxx --without-cxx-binding --without-ada --without-debug \
    --disable-db-install --without-gpm --with-build-cc=gcc
}

build_tmux() {
  # no utf8proc of the host; libevent and ncurses are the static ones of the prefix
  configure_install --disable-utf8proc LIBEVENT_CFLAGS="-I$PFX/include" LIBEVENT_LIBS="-L$PFX/lib -levent_core" \
    LIBNCURSES_CFLAGS="-I$PFX/include/ncursesw" LIBNCURSES_LIBS="-L$PFX/lib -lncursesw -ltinfow"
}
test_tmux() { run_mac 'bin/tmux -V | grep -q "^tmux 3.5a"'; }

build_nano() {
  configure_install --disable-nls --disable-libmagic NCURSESW_CFLAGS="-I$PFX/include/ncursesw" NCURSESW_LIBS="-L$PFX/lib -lncursesw -ltinfow"
}
test_nano() { run_mac 'bin/nano --version | grep -q "GNU nano"'; }

build_less() { configure_install; }
test_less() { run_mac 'bin/less --version | grep -q "^less 679"'; }

build_bash() {
  # the helper programs (mkbuiltins) run on the build host: GCC 15 and newer compile as C23
  configure_install --without-bash-malloc --disable-nls CC_FOR_BUILD="gcc -std=gnu17"
}
test_bash() { run_mac "bin/bash -c 'echo \$((6*7))' | grep -qx 42"; }

build_htop() {
  # htop compiles with -D_XOPEN_SOURCE=600 and includes <sys/sysctl.h> before its config.h: with strict POSIX
  # macros <sys/ucred.h> and <sys/proc.h> of the SDK use u_int, which <sys/types.h> then hides
  CFLAGS="$CFLAGS -D_DARWIN_C_SOURCE" configure_install --disable-hwloc --disable-sensors --disable-capabilities --disable-delayacct \
    HTOP_NCURSESW_CONFIG_SCRIPT=/bin/false LIBS="-L$PFX/lib -lncursesw -ltinfow" CPPFLAGS="-I$PFX/include -I$PFX/include/ncursesw"
}
test_htop() { run_mac 'bin/htop --version | grep -q "^htop 3.4.1"'; }

# --- GNU and other tools
build_coreutils() {
  # configure of a cross build: statfs has f_bsize, otherwise df does not build
  configure_install --disable-nls --without-selinux fu_cv_sys_stat_statfs2_bsize=yes
}
test_coreutils() {
  run_mac 'bin/expr 6 "*" 7 | grep -qx 42 && printf "b\na\n" | bin/sort | head -n 1 | grep -qx a &&
    echo hi | bin/sha256sum | grep -q 98ea6e4f && bin/date -u -d @0 +%Y | grep -qx 1970 && bin/stat -c %s bin/ls >/dev/null &&
    echo hi | bin/base64 | grep -qx aGkK && bin/df . >/dev/null && bin/ls bin | grep -qx ls'
}

build_grep() { configure_install --disable-nls --disable-perl-regexp; }
test_grep() { run_mac "printf 'a\nb\n' | bin/grep -n b | grep -qx '2:b' && echo abc | bin/grep -E 'a(b|x)c' >/dev/null"; }

build_sed() { configure_install --disable-nls; }
test_sed() { run_mac 'echo abc | bin/sed s/b/X/ | grep -qx aXc'; }

build_gawk() {
  # _NSGetExecutablePath without #include <mach-o/dyld.h>: Clang 16 and newer reject the implicit declaration
  CFLAGS="$CFLAGS -include mach-o/dyld.h" configure_install --disable-nls --without-readline --without-mpfr
}
test_gawk() { run_mac "echo 'a b' | bin/gawk '{print \$2}' | grep -qx b"; }

build_findutils() { configure_install --disable-nls; }
test_findutils() { run_mac 'bin/find bin -type f -name find | grep -q find && bin/find bin -type f | bin/xargs ls >/dev/null'; }

build_rsync() { configure_install --disable-openssl --disable-xxhash --disable-zstd --disable-lz4 --disable-md2man; }
test_rsync() { run_mac 'bin/rsync -a bin/ dst/ && test -x dst/rsync'; }

build_openssh() {
  # install-nokeys: the host keys would be made by a program of the target
  configure_host --without-openssl --without-pam --disable-strip
  make_j
  make_j install-nokeys
}
test_openssh() { run_mac 'bin/ssh -V 2>&1 | grep -q OpenSSH && bin/ssh-keygen -q -t ed25519 -N "" -f k && test -s k.pub'; }

build_git() {
  # no configure: the variables of the Makefile; uname_S selects the Darwin settings (CommonCrypto,
  # the fsmonitor daemon with FSEvents); RUNTIME_PREFIX makes the installation relocatable
  make_j prefix="$PREFIX" uname_S=Darwin uname_M="$ARCH" CC="$CC" AR="$AR" RANLIB="$RANLIB" NO_GETTEXT=1 NO_TCLTK=1 NO_PERL=1 \
    NO_PYTHON=1 NO_EXPAT=1 NO_CURL=1 NO_OPENSSL=1 RUNTIME_PREFIX=1 gitexecdir=libexec/git-core \
    template_dir=share/git-core/templates INSTALL=install install
}
test_git() {
  run_mac 'export HOME=$PWD/h && mkdir -p h r && cd r && ../bin/git init -q . && ../bin/git config user.name t &&
    ../bin/git config user.email t@example.com && echo hi > f && ../bin/git add f && ../bin/git commit -q -m one &&
    ../bin/git log --oneline | grep -q one &&
    ../bin/git config core.fsmonitor true && ../bin/git fsmonitor--daemon start && ../bin/git fsmonitor--daemon status &&
    echo x >> f && ../bin/git status --short | grep -q "^ M f"; rc=$?; ../bin/git fsmonitor--daemon stop; exit $rc'
}

build_libgit2() {
  cmake_install . -DBUILD_TESTS=ON -DUSE_HTTPS=OFF -DUSE_SSH=OFF -DBUILD_CLI=OFF -DBUILD_SHARED_LIBS=OFF
  stage_files "$B/build" libgit2_tests
}
test_libgit2() { run_mac './libgit2_tests -score::buf -score::oid'; }

build_libgit2_st() { cmake_install . -DBUILD_TESTS=OFF -DUSE_HTTPS=SecureTransport -DUSE_SSH=OFF -DBUILD_CLI=ON; }
test_libgit2_st() { run_mac 'bin/git2 --version | grep -q 1.9.1'; }

build_redis() {
  # -j1: with -j the Makefile of the dependencies removes its own directories; the Makefile asks uname
  make -j1 uname_S=Darwin uname_M="$ARCH" CC="$CC" MALLOC=libc BUILD_TLS=no USE_SYSTEMD=no OPTIMIZATION=-O2 PREFIX="$PREFIX" install
}
test_redis() {
  run_mac 'bin/redis-server --version | grep -q "Redis server v=8.0.3" && { bin/redis-server --port 16399 --save "" >/dev/null 2>&1 & p=$!;
    sleep 2; bin/redis-cli -p 16399 ping | grep -qx PONG; rc=$?; kill $p; exit $rc; }'
}

build_xxhash() { make_j UNAME=Darwin CC="$CC" AR="$AR" PREFIX="$PREFIX" install; }
test_xxhash() { run_mac 'echo hi | bin/xxhsum | grep -q stdin'; }

build_lmdb() {
  cd libraries/liblmdb
  make_j CC="$CC" AR="$AR" SOEXT=.dylib prefix="$PREFIX" install
  make_j CC="$CC" AR="$AR" mtest mtest2 mtest3 mtest5
  stage_files . mtest mtest2 mtest3 mtest5 mdb_stat
}
test_lmdb() { run_mac 'for t in mtest mtest2 mtest3 mtest5; do rm -rf testdb; mkdir testdb; ./$t >/dev/null || { echo "FAIL $t"; exit 1; }; done; ./mdb_stat testdb | grep -q "Main DB"'; }

build_fswatch() {
  # libtool's partial link (ld -r) of a shared libfswatch: ld64.lld does not implement -r
  configure_install --disable-nls --disable-shared
}
test_fswatch() {
  run_mac 'bin/fswatch --version | grep -q fswatch && mkdir w && { (sleep 2; touch w/x) & bin/fswatch -1 w | grep -q w/x; }'
}

build_hidapi() { cmake_install . -DHIDAPI_BUILD_HIDTEST=ON; }
test_hidapi() { run_mac 'bin/hidtest 2>&1 | grep -q "runtime version 0.16.0"'; }

build_libusb() {
  # shared (the default): a static libusb-1.0.la does not carry the frameworks of configure (LIBS), and the examples
  # link only it. The examples are in .libs (the others are libtool wrappers), the tests link the library statically
  configure_install --enable-examples-build --enable-tests-build
  rm -rf "$B/stage"; mkdir -p "$B/stage/lib"
  # not stress and stress_mt: thousands of contexts, each enumerates the devices; they take longer than the test may.
  # Not macos: it expects the interface versions of the newest IOUSBLib.h (800 and 650); the open one of IOUSBFamily
  # has up to 550 and 500, which libusb then uses
  cp examples/.libs/listdevs examples/.libs/testlibusb tests/set_option tests/init_context "$B/stage/" || return 1
  cp "$PREFIX"/lib/libusb-1.0.0.dylib "$B/stage/lib/" || return 1
  stage "$B/stage"
}
test_libusb() {
  run_mac './listdevs >/dev/null && ./testlibusb >/dev/null &&
    for t in set_option init_context; do ./$t >/dev/null || { echo "FAIL $t"; exit 1; }; done'
}

build_libzip() {
  # CommonCrypto for the AES encryption of the archives
  cmake_install . -DENABLE_COMMONCRYPTO=ON -DENABLE_OPENSSL=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF -DENABLE_BZIP2=OFF \
    -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DBUILD_REGRESS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF -DBUILD_SHARED_LIBS=OFF
}
test_libzip() {
  run_mac 'bin/ziptool -n t.zip add a hello set_file_encryption 0 AES-256 secret &&
    test "$(bin/ziptool t.zip set_password secret cat 0)" = hello && bin/zipcmp t.zip t.zip'
}

build_openvpn() {
  # mbedTLS and lz4 of the prefix; the plugins and DCO are Linux or PAM features
  configure_install --with-crypto-library=mbedtls --enable-lz4 --disable-lzo --disable-plugin-auth-pam --disable-dco --disable-systemd \
    --disable-unit-tests MBEDTLS_CFLAGS="-I$PFX/include" MBEDTLS_LIBS="-L$PFX/lib -lmbedtls -lmbedx509 -lmbedcrypto" \
    LZ4_CFLAGS="-I$PFX/include" LZ4_LIBS="$PFX/lib/liblz4.a" IFCONFIG=/sbin/ifconfig ROUTE=/sbin/route NETSTAT=/usr/sbin/netstat
}
test_openvpn() { run_mac 'sbin/openvpn --version | grep -q "^OpenVPN 2.6.14" && sbin/openvpn --genkey secret k && test -s k'; }

build_sudo() {
  # make install changes the owner to root, which a build is not: it installs as the user, and its directories
  # (/etc, /run, /var) are below the prefix; configure finds the systemd directory of the build host, which would be
  # written to
  configure_host --disable-tmpfiles.d --with-pam --disable-nls --without-sendmail --disable-shared --sysconfdir="$PREFIX/etc" \
    --with-rundir="$PREFIX/run" --with-vardir="$PREFIX/var" --with-logpath="$PREFIX/var/log/sudo.log"
  make_j
  make_j install install_uid="$(id -u)" install_gid="$(id -g)"
}
test_sudo() {
  # sudo itself refuses to start unless it is owned by root and setuid: visudo parses a sudoers file with the plugin code
  run_mac 'sbin/visudo -V | grep -q "visudo version 1.9.17p1" && echo "root ALL=(ALL) ALL" > s && sbin/visudo -c -f s | grep -q "parsed OK"'
}

build_glew() {
  # glewinfo asks for an accelerated renderer (kCGLPFAAccelerated), which a Mac without GPU has not: a program of
  # our own makes a context with the software renderer and calls glewInit
  cmake_install build/cmake -DBUILD_UTILS=ON -DGLEW_X11=OFF -DBUILD_SHARED_LIBS=OFF
  mkdir -p "$B/stage"
  # GLEW_NO_GLU: no GLU in the SDK
  cat > "$B/t.c" <<'EOF'
#include <GL/glew.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/CGLRenderers.h>
#include <stdio.h>
int main(void) {
  CGLPixelFormatAttribute a[] = { kCGLPFARendererID, (CGLPixelFormatAttribute)kCGLRendererGenericFloatID, (CGLPixelFormatAttribute)0 };
  CGLPixelFormatObj pf; CGLContextObj ctx; GLint n;
  if (CGLChoosePixelFormat(a, &pf, &n) || CGLCreateContext(pf, NULL, &ctx) || CGLSetCurrentContext(ctx)) return 2;
  if (glewInit() != GLEW_OK) return 3;
  printf("GLEW %s, OpenGL 2.1 %d\n", glewGetString(GLEW_VERSION), GLEW_VERSION_2_1);
  return GLEW_VERSION_2_1 ? 0 : 1;
}
EOF
  "$CC" -O2 -DGLEW_STATIC -DGLEW_NO_GLU -I"$PREFIX/include" "$B/t.c" "$PREFIX"/lib/libGLEW.a -framework OpenGL -o "$B/stage/t"
  stage "$B/stage"
}
test_glew() { run_mac './t | grep -q "^GLEW 2.2.0, OpenGL 2.1 1"'; }

build_dfu_util() {
  configure_install USB_CFLAGS="-I$PFX/include/libusb-1.0" USB_LIBS="$PFX/lib/libusb-1.0.a -framework IOKit -framework CoreFoundation -framework Security"
}
test_dfu_util() { run_mac 'bin/dfu-util --version | grep -q "dfu-util 0.11" && { bin/dfu-util -l >/dev/null; }'; }

build_osx_cpu_temp() {
  # SMC of IOKitLib (IOConnectCallStructMethod); the Makefile has no install directory
  make_j CC="$CC" osx-cpu-temp
  stage_files . osx-cpu-temp
}
test_osx_cpu_temp() { run_mac './osx-cpu-temp | grep -q "°C"'; }

build_efsw() {
  # FSEvents (CoreServices) and kqueue watchers; a program of our own watches a directory and creates a file in it
  cmake_install . -DBUILD_SHARED_LIBS=OFF -DBUILD_TEST_APP=OFF -DBUILD_STATIC_LIBS=ON
  mkdir -p "$B/stage"
  cat > "$B/t.cpp" <<'EOF'
#include <efsw/efsw.hpp>
#include <unistd.h>
#include <fcntl.h>
#include <string>
struct L : efsw::FileWatchListener {
  volatile bool got;
  L() : got(false) {}
  void handleFileAction(efsw::WatchID, const std::string&, const std::string& name, efsw::Action, std::string) { if (name == "x") got = true; }
};
int main() {
  efsw::FileWatcher fw; L l;
  if (fw.addWatch("w", &l, false) < 0) return 2;
  fw.watch();
  sleep(1);
  close(open("w/x", O_CREAT | O_WRONLY, 0644));
  for (int i = 0; i < 50 && !l.got; i++) usleep(100000);
  return l.got ? 0 : 1;
}
EOF
  "$CXX" -O2 -std=c++11 -I"$PREFIX/include" "$B/t.cpp" "$PREFIX"/lib/libefsw*.a -framework CoreServices -framework CoreFoundation \
    -o "$B/stage/t"
  stage "$B/stage"
}
test_efsw() { run_mac 'mkdir w && ./t'; }

build_aria2() {
  # TLS through the Security framework (AppleTLS), the XML parser of the SDK for Metalink; no libraries of the build host
  configure_install --with-appletls --without-openssl --without-gnutls --without-libxml2 --with-libexpat --without-sqlite3 \
    --without-libssh2 --without-libcares --without-libgmp --without-libgcrypt --without-libnettle --disable-nls \
    EXPAT_CFLAGS="-I$PFX/include" EXPAT_LIBS=-lexpat
}
test_aria2() { run_mac 'bin/aria2c --version | grep -q "aria2 version 1.37.0" && bin/aria2c --version | grep -q "AppleTLS"'; }

build_libcbor() {
  # the project asks CMake for the archiver of the compiler (CMAKE_C_COMPILER_AR, the one of LTO), which the wrapper of
  # OSXCross does not have: no interprocedural optimization
  cmake_install . -DWITH_TESTS=OFF -DWITH_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF
}

build_libfido2() {
  # HID access of IOKit (hid_osx.c); libcbor and LibreSSL of the prefix. The toolchain file of OSXCross sets
  # PKG_CONFIG_SYSROOT_DIR to its MacPorts directory, which pkg-config puts in front of the paths of the prefix: the
  # include and library directory are given again. It finds zlib only through pkg-config, and macOS has no zlib.pc:
  # one for the zlib of the SDK, in a prefix that pkg-config of CMake searches (CMAKE_PREFIX_PATH)
  mkdir -p "$B/pc/lib/pkgconfig"
  printf 'Name: zlib\nDescription: zlib of the SDK\nVersion: 1.2.12\nLibs: -lz\n' > "$B/pc/lib/pkgconfig/zlib.pc"
  cmake_install . -DCMAKE_PREFIX_PATH="$PFX;$B/pc" -DCMAKE_C_FLAGS="-I$PFX/include" -DCMAKE_EXE_LINKER_FLAGS="-L$PFX/lib" -DBUILD_EXAMPLES=OFF -DBUILD_TOOLS=ON -DBUILD_TESTS=OFF -DBUILD_MANPAGES=OFF -DBUILD_STATIC_LIBS=ON \
    -DBUILD_SHARED_LIBS=OFF -DUSE_HIDAPI=OFF
}
test_libfido2() { run_mac 'bin/fido2-token -V 2>&1 | grep -q "1.15.0" && bin/fido2-token -L >/dev/null'; }

build_vim() {
  # configure cannot run its test programs when cross compiling: the results of a Mac. No Darwin support: its part
  # os_macosx.m is Objective-C with AppKit
  configure_install --with-features=normal --without-x --disable-gui --disable-darwin --disable-nls --with-tlib="ncursesw -ltinfow" --disable-selinux \
    --disable-gpm --disable-sysmouse --disable-netbeans --disable-channel --with-vim-name=vim \
    vim_cv_toupper_broken=no vim_cv_terminfo=yes vim_cv_tgetent=zero vim_cv_getcwd_broken=no vim_cv_stat_ignores_slash=no \
    vim_cv_memmove_handles_overlap=yes vim_cv_bcopy_handles_overlap=no vim_cv_memcpy_handles_overlap=no \
    vim_cv_tty_group=world vim_cv_tty_mode=0620 ac_cv_sizeof_int=4 ac_cv_small_wchar_t=no vim_cv_timer_create=no \
    vim_cv_timer_create_with_lrt=no vim_cv_uname_output=Darwin vim_cv_uname_r_output=25.0.0 vim_cv_uname_m_output="$ARCH" CPPFLAGS="-I$PFX/include -I$PFX/include/ncursesw"
}
test_vim() {
  run_mac 'bin/vim --version | grep -q "VIM - Vi IMproved 9.1" && bin/vim -es -u NONE -c "call writefile([string(6*7)], \"o\")" -c q &&
    grep -qx 42 o'
}

build_tcpdump() {
  # the libpcap of the SDK; configure would run the pcap-config of the build host (-I/usr/include), so it finds none
  configure_install --without-crypto --without-smi --without-cap-ng ac_cv_path_PCAP_CONFIG= ac_cv_path_ac_pt_PCAP_CONFIG=
}
test_tcpdump() { run_mac 'bin/tcpdump --version 2>&1 | grep -q "tcpdump version 4.99.5" && bin/tcpdump -D | grep -q "^1\."'; }

# --- C++
build_fmt() {
  # libc++ 21 does not include <cstdlib> from other headers any more (malloc undeclared)
  cmake_install . -DFMT_TEST=ON -DFMT_DOC=OFF -DCMAKE_CXX_FLAGS="-include cstdlib"
  stage_glob "$B/build/bin" '*-test'
}
test_fmt() { run_mac 'for t in ./*-test; do $t >/dev/null || { echo "FAIL $t"; exit 1; }; done'; }

build_spdlog() {
  cmake_install . -DSPDLOG_BUILD_TESTS=ON -DSPDLOG_BUILD_EXAMPLE=OFF
  stage_files "$B/build/tests" spdlog-utests
}
test_spdlog() { run_mac './spdlog-utests'; }

build_googletest() {
  cmake_install . -DBUILD_GMOCK=ON -Dgtest_build_tests=ON -Dgmock_build_tests=ON
  mkdir -p "$B/stage"
  find "$B/build" -type f -perm -u+x \( -name 'gtest*test' -o -name 'googletest*test' -o -name 'gmock*test' -o -name '*_test' \) \
    ! -name '*[_]' -exec cp {} "$B/stage/" \;
  stage "$B/stage"
}
test_googletest() { run_mac 'n=0; for t in ./*; do $t >/dev/null 2>&1 || { echo "FAIL $t"; n=$((n+1)); }; done; test $n = 0'; }

build_libuv() {
  # the tests are built only with the shared library
  cmake_install . -DLIBUV_BUILD_TESTS=ON -DLIBUV_BUILD_SHARED=ON
  stage_files "$B/build" uv_run_tests_a
}
test_libuv() { run_mac './uv_run_tests_a timer && ./uv_run_tests_a idle_ref && ./uv_run_tests_a loop_alive && ./uv_run_tests_a thread_mutex'; }

# --- build tools
build_ninja() { cmake_install . -DBUILD_TESTING=OFF; }
test_ninja() { run_mac 'bin/ninja --version | grep -q "^1.13.0"'; }

build_cmake() {
  # the Xcode generator needs ApplicationServices/ApplicationServices.h (LaunchServices), which the
  # SDK does not have: its use is switched off
  sedi 's|^#  if !TARGET_OS_IPHONE|#  if 0|' Source/cmGlobalXCodeGenerator.cxx
  # CPack's DragNDrop generator calls LocaleStringToLangAndRegionCodes of CoreServices, which the placeholder
  # CoreServices.framework of the SDK does not declare: no CoreServices
  cmake_install . -DBUILD_TESTING=OFF -DCMAKE_USE_OPENSSL=OFF -DBUILD_CursesDialog=OFF -DHAVE_CoreServices=0
}
test_cmake() { run_mac 'bin/cmake --version | grep -q "cmake version 4.0.3"'; }

build_gnumake() { configure_install --disable-nls --without-guile; }
test_gnumake() { run_mac 'bin/make --version | grep -q "GNU Make 4.4.1"'; }

build_pkgconf() { configure_install --disable-shared; }
test_pkgconf() { run_mac 'bin/pkgconf --version | grep -qx 2.5.1'; }

# --- images and fonts
build_libpng() {
  cmake_install . -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF
  # the tests are not built in a cross build: pngtest by hand
  mkdir -p "$B/stage"
  "$CC" -O2 -I. -I"$B/build" pngtest.c "$B/build/libpng16.a" -lz -lm -o "$B/stage/pngtest"
  cp pngtest.png "$B/stage/"
  stage "$B/stage"
}
test_libpng() { run_mac './pngtest pngtest.png >/dev/null 2>&1'; }

build_libjpeg_turbo() {
  # no nasm on the build host
  cmake_install . -DWITH_SIMD=0 -DENABLE_SHARED=OFF
}
test_libjpeg_turbo() {
  run_mac 'printf "P6\n2 2\n255\n\377\0\0\0\377\0\0\0\377\377\377\0" > a.ppm && bin/cjpeg a.ppm > a.jpg && bin/djpeg a.jpg > b.ppm &&
    bin/jpegtran -rotate 90 a.jpg > c.jpg && test -s c.jpg && head -c 2 b.ppm | grep -q P6'
}

build_libtiff() {
  # codecs of the build host (jbig, libdeflate ...) are switched off
  cmake_install . -Dtiff-tests=OFF -Dtiff-docs=OFF -Dtiff-contrib=OFF -Djbig=OFF -Dlibdeflate=OFF -Dlzma=OFF -Dzstd=OFF -Dwebp=OFF \
    -Djpeg=OFF -Dlerc=OFF -Dpixarlog=OFF
}

build_freetype() { configure_install --with-png=no --with-harfbuzz=no --with-brotli=no --with-bzip2=no; }

build_libiconv() { configure_install --disable-nls; }
test_libiconv() { run_mac "printf hi | bin/iconv -f UTF-8 -t UTF-16LE | od -An -tx1 | tee /dev/stderr | grep -q '68 *00 *69 *00'"; }

build_gettext() {
  # the cross-compile guess of gnulib for setlocale_null is "not thread-safe", and then libgettextpo lacks
  # gl_get_setlocale_null_lock
  gl_cv_func_setlocale_null_all_mtsafe=yes gl_cv_func_setlocale_null_one_mtsafe=yes \
  configure_install --disable-java --disable-csharp --without-emacs --disable-openmp --without-git --without-cvs \
    --disable-nls --disable-dependency-tracking
}

build_libsodium() { configure_install; }

build_file() {
  # only the program: magic.mgc needs a native file of the same version
  configure_host --disable-shared --disable-libseccomp
  make_j -C src magic.h
  make_j -C src file
  stage_files src file
}
test_file() { run_mac './file -v | grep -q "file-5.46"'; }

# --- compilers and tools (group "compilers": very large, off by default)
build_llvm() {
  # a cross build: LLVM builds its own tools (llvm-tblgen ...) for the build host in a second CMake run, which
  # must not see the compilers of the target in the environment
  unset CC CXX AR RANLIB NM STRIP CFLAGS CXXFLAGS CPPFLAGS LDFLAGS OTOOL LIPO INSTALL_NAME_TOOL CC_FOR_BUILD CXX_FOR_BUILD
  # clang-repl's test of the linker flag --long-plt (an ELF flag) fails in try_compile with this cross setup: it is set
  cmake_install "$SRC/llvm" -DLLVM_ENABLE_PROJECTS=clang -DLLVM_TARGETS_TO_BUILD="X86;AArch64" \
    -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DCLANG_ENABLE_ARCMT=OFF -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
    -DLLVM_HOST_TRIPLE="$HOST" -DHAVE_LINKER_FLAG_LONG_PLT=0
  c=$(basename "$(readlink "$PREFIX/bin/clang")")
  stage_files "$PREFIX" bin/clang "bin/$c"
}
test_llvm() {
  run_mac 'bin/clang --version | grep -q "clang version 23.1.6"'
  run_mac 'echo "int f(int x) { return x + 1; }" | bin/clang -x c - -S -o - -target x86_64-apple-macos11 -nostdinc | grep -q _f'
}

build_compiler_rt() {
  # the builtins and the profile runtime; the sanitizers need CoreFoundation/CFBase.h of the full SDK, so
  # they are off. The Darwin part of compiler-rt calls xcodebuild, lipo, ld, codesign and sysctl of a Mac:
  # the same replacements as in build_compiler_rt.sh of OSXCross
  cd compiler-rt
  f=cmake/Modules/CompilerRTDarwinUtils.cmake
  sedi 's|COMMAND xcodebuild -version -sdk ${sdk_name}.internal Path|COMMAND xcrun -sdk ${sdk_name}.internal --show-sdk-path|' "$f"
  sedi 's|COMMAND xcodebuild -version -sdk ${sdk_name} Path|COMMAND xcrun -sdk ${sdk_name} --show-sdk-path|' "$f"
  sedi 's|COMMAND xcodebuild -version -sdk ${sdk_name}.internal SDKVersion|COMMAND xcrun -sdk ${sdk_name}.internal --show-sdk-version|' "$f"
  sedi 's|COMMAND xcodebuild -version -sdk ${sdk_name} SDKVersion|COMMAND xcrun -sdk ${sdk_name} --show-sdk-version|' "$f"
  sedi 's|COMMAND lipo |COMMAND xcrun lipo |' "$f"
  sedi 's|COMMAND ld |COMMAND xcrun ld |' "$f"
  sedi 's|COMMAND sysctl hw.cputype|COMMAND true|' "$f"
  sedi 's|COMMAND sysctl hw.cpusubtype|COMMAND true|' "$f"
  sedi 's|COMMAND codesign |COMMAND true |' cmake/Modules/AddCompilerRT.cmake
  sedi 's|${CMAKE_COMMAND} -E ${COMPILER_RT_LINK_OR_COPY}|ln -sf|' lib/builtins/CMakeLists.txt
  mkdir -p build && cd build
  cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
    -DCOMPILER_RT_ENABLE_IOS=OFF -DCMAKE_LIPO="$(command -v xcrun >/dev/null && xcrun -f lipo)" \
    -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_AR="$(command -v "$AR")" -DDARWIN_osx_ARCHS="$ARCH" -DDARWIN_osx_BUILTIN_ARCHS="$ARCH" \
    -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
    -DCOMPILER_RT_BUILD_ORC=OFF -DCOMPILER_RT_BUILD_MEMPROF=OFF -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF
  cmake --build . -j "$JOBS"
  ls lib/darwin
  # a program that needs the 128-bit division of the builtins; the archive of this build is linked first
  mkdir -p "$B/stage"
  printf '#include <stdio.h>\nint main(int argc, char **argv) { __int128 a = (__int128)argc * 1000000000000000000LL * 1000; a /= 7; printf("%%d\\n", (int)(a %% 1000)); return 0; }\n' > "$B/rt.c"
  "$CC" -O0 "$B/rt.c" lib/darwin/libclang_rt.osx.a -o "$B/stage/rt"
  cp lib/darwin/libclang_rt.osx.a "$B/stage/"
  stage "$B/stage"
}
test_compiler_rt() { run_mac './rt | grep -qx "[0-9]*"'; }

build_cctools_port() {
  # the tools of cctools-port as programs of the Mac; without libtapi (ld64 cannot read .tbd files)
  cd cctools
  ./configure --host="$HOST" --prefix="$PREFIX"
  make_j
  make_j install
}
test_cctools_port() {
  run_mac 'bin/lipo -info bin/ar | grep -q x86_64 && bin/otool -hv bin/ar | grep -q MH_MAGIC_64 && bin/nm bin/ar >/dev/null &&
    bin/size bin/ar >/dev/null && bin/strings bin/ar >/dev/null && bin/ar rcs t.a bin/ar && bin/ranlib t.a && bin/ar t t.a | grep -qx ar'
}

# --- games (group "games": needs 7z)
# sevenzip: 7zz (7-Zip) or 7z (p7zip)
sevenzip() { if command -v 7zz >/dev/null 2>&1; then echo 7zz; else echo 7z; fi; }
# sdl_framework NAME FRAMEWORK: FRAMEWORK (e.g. SDL2.framework) from the disk image of the release of SDL, into
# $B/fw (SDL's own build of it; its Cocoa backend needs the headers of AppKit, which the SDK does not have)
sdl_framework() {
  local d=$B/dmg/$1 f
  fetch "$1"
  rm -rf "$d"; mkdir -p "$d" "$B/fw"
  (cd "$d" && "$(sevenzip)" x -y "$(src_file "$1")" >/dev/null)
  f=$(find "$d" -type d -name "$2" | head -n 1)
  if [ -z "$f" ]; then
    # some versions of 7-Zip give the HFS+ partition of the image as a file of its own
    find "$d" -type f \( -name '*.hfs' -o -name '*.hfsx' -o -name '*.img' \) | while read -r f; do
      (cd "$d" && "$(sevenzip)" x -y "$f" >/dev/null)
    done
    f=$(find "$d" -type d -name "$2" | head -n 1)
  fi
  [ -n "$f" ] || { echo "no $2 in $(src_file "$1")" >&2; return 1; }
  cp -RP "$f" "$B/fw/"
}
build_sauerbraten() {
  # the client of Cube 2: Sauerbraten 2020_12_29 (C++, OpenGL) with SDL2, SDL2_image and SDL2_mixer as the
  # frameworks of SDL's releases; the objects of CLIENT_OBJS of src/Makefile and enet, as that Makefile builds
  # them, without its Mac launcher (Objective-C, not needed by the client)
  local o objs fl st=$B/stage
  sdl_framework sdl2 SDL2.framework
  sdl_framework sdl2-image SDL2_image.framework
  sdl_framework sdl2-mixer SDL2_mixer.framework
  fl="-O2 -fomit-frame-pointer -ffast-math -fsigned-char -fno-exceptions -fno-rtti -w -F$B/fw"
  fl="$fl -I$B/fw/SDL2.framework/Headers -I$B/fw/SDL2_image.framework/Headers -I$B/fw/SDL2_mixer.framework/Headers"
  cd src
  objs=$(sed -n '/^CLIENT_OBJS=/,/^$/p' Makefile | grep -o '[a-z]*/[a-z0-9_-]*\.o')
  mkdir -p "$B/obj/shared" "$B/obj/engine" "$B/obj/fpsgame" "$B/obj/enet"
  for o in $objs; do
    echo "$CXX $fl -Ishared -Iengine -Ifpsgame -Ienet/include -c ${o%.o}.cpp -o $B/obj/$o"
  done > "$B/cmds"
  for o in callbacks compress host list packet peer protocol unix; do
    echo "$CC $fl -Ienet/include -DHAS_SOCKLEN_T=1 -c enet/$o.c -o $B/obj/enet/$o.o"
  done >> "$B/cmds"
  xargs -P "$JOBS" -I{} sh -c '{}' < "$B/cmds"
  rm -rf "$st"; mkdir -p "$st/bin" "$st/Frameworks"
  # shellcheck disable=SC2086,SC2046 # the flags and names have no blanks
  "$CXX" $fl -o "$st/bin/sauer_client" $(for o in $objs; do echo "$B/obj/$o"; done) "$B"/obj/enet/*.o \
    -framework SDL2 -framework SDL2_image -framework SDL2_mixer -framework OpenGL -lz -Wl,-rpath,@executable_path/../Frameworks
  cp -RP "$B"/fw/*.framework "$st/Frameworks/"
  cd ..
  tar -cf - data packages | tar -xf - -C "$st"
  stage "$st"
}
test_sauerbraten() {
  # the SSH user must be the user logged in at the Mac (the window server); no sound device needed. The client
  # loads the map complex and quits; its log shows the OpenGL renderer and the map
  run_mac 'SDL_AUDIODRIVER=dummy bin/sauer_client -q"$PWD/home" -w640 -h480 -t0 -x"map complex; sleep 2000 [quit]" > log 2>&1;
    rc=$?; cat log; test $rc = 0 && grep -q "^Renderer: " log && grep -q "read map packages/base/complex.ogz" log'
}

# ---------------------------------------------------------------------------------------------
# main
SELECTED=$(select_projects) || exit 2
setup_osxcross || exit 1
[ -n "$LLVMBIN" ] && [ -x "$LLVMBIN/clang" ] || die "no clang (the wrapper of OSXCross runs it): give --llvm DIR"
LLVMBIN=$(cd "$LLVMBIN" && pwd)
TOOLPATH=$OSX/bin:$LLVMBIN:/usr/bin:/bin:/usr/sbin:/sbin
verify_sdk || exit 1
for a in $ARCHS; do verify_compiler "$a" || exit 1; done
for tool in cmake ninja make gcc perl curl tar; do command -v "$tool" >/dev/null 2>&1 || die "$tool is needed on the build host"; done
echo "OSXCross: $OSX, flavor $OSXCROSS_BUILD_FLAVOR, deployment target $TARGET, $JOBS jobs per architecture"
echo "work directory: $WORK (downloads in $DL, this run in $RUN)"
RROOT=
if [ -n "$SSH" ]; then remote_init || die "cannot use $SSH"; fi
trap 'remote_done; finish' EXIT

say "sources of $(echo $SELECTED | wc -w | tr -d " ") project(s), cache $DL"
for n in $SELECTED; do
  [ -z "$(missing_tool "$n")" ] || continue
  for s in $(src_name "$n") $(extra_sources "$n"); do fetch "$s" || exit 1; done
done
if [ "$NARCH" -gt 1 ]; then say "building for $ARCHS (in parallel), $VARIANT SDK"; else say "building for $ARCHS, $VARIANT SDK"; fi
rm -f "$RES"/*
start=$(date +%s)
for a in $ARCHS; do
  (
    DONE=0; TOTAL=$(echo $SELECTED | wc -w | tr -d ' ')
    for n in $SELECTED; do run_project "$n" "$a"; done
  ) &
  BUILDERS="$BUILDERS $!"
done
wait
end=$(date +%s)

# the table
fails=0
echo
printf '%-15s %-10s %-6s %-10s\n' Project x86_64 test arm64
for n in $SELECTED; do
  row=$(printf '%-15s' "$n")
  for a in $ARCHS; do
    if [ -f "$RES/$n.$a" ]; then read -r b t < "$RES/$n.$a"; else b=missing; t=-; fi
    case $b in
      ok) cell=ok;;
      skip) cell=skipped; fails=$((fails + 1));;
      core) cell="full only";;
      tool) cell="no tool";;
      *) cell="FAIL $b"; fails=$((fails + 1));;
    esac
    if [ "$a" = x86_64 ]; then
      [ "$t" = FAIL ] && fails=$((fails + 1))
      row="$row $(printf '%-10s %-6s' "$cell" "$t")"
    else
      row="$row $(printf '%-10s' "$cell")"
    fi
  done
  echo "$row"
done
echo
echo "logs: $LOGS/PROJECT.ARCH.log; $((end - start)) s; $fails failures"
[ "$fails" = 0 ] && RUN_OK=1
[ "$fails" = 0 ]
