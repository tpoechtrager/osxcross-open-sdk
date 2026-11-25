#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Tests of the options and checks of make-open-sdk.sh that need neither network
# nor a compiler: tests/unit/test_options.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
GEN=$HERE/../../make-open-sdk.sh
T=$(mktemp -d "${TMPDIR:-/tmp}/open-sdk-test.XXXXXX") || exit 2
T=$(cd "$T" && pwd -P) || exit 2   # the physical path (on macOS /var is a link): the script prints physical paths
trap 'rm -rf "$T"' EXIT
fail=0 n=0

# gen ARGS...: run the script in a clean environment; sets rc and out
gen() { out=$(cd "$T" && env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin bash "$GEN" "$@" 2>&1); rc=$?; }
# genenv VAR=VALUE... -- ARGS...
genenv() { local e=(); while [ "$1" != -- ]; do e+=("$1"); shift; done; shift
  out=$(cd "$T" && env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin ${e[@]+"${e[@]}"} bash "$GEN" "$@" 2>&1); rc=$?; }
check() { # description, condition result
  n=$((n + 1))
  if [ "$2" = ok ]; then echo "ok $n - $1"; else echo "not ok $n - $1"; echo "   rc=$rc out=$out" | head -5; fail=1; fi
}
has() { case $out in *"$1"*) echo ok;; *) echo no;; esac; }
isrc() { [ "$rc" = "$1" ] && echo ok || echo no; }

gen --help;                         check "--help works" "$(isrc 0)"
check "--help names --core" "$(has '--core')"
gen --version;                      check "--version prints the commit of the script" "$( printf '%s\n' "$out" | grep -Eq '^make-open-sdk\.sh ([0-9a-f]{7}(-modified)?|unknown)$' && echo ok || echo no)"
gen --bogus;                        check "an unknown option is refused (rc 2)" "$(isrc 2)"
gen -s nonsense;                    check "an unknown step is refused (rc 2)" "$(isrc 2)"
gen --macos x;                      check "a bad --macos is refused (rc 2)" "$(isrc 2)"
gen --macos 9.9 --show-config;      check "a release without manifest is refused" "$(isrc 1)"
check "  and lists the ones that exist" "$(has 26.5)"
gen --libcxx 1.2.3 --show-config;   check "an LLVM release that is not in the table is refused" "$(isrc 1)"
gen --libcxx abc;                   check "a bad --libcxx is refused (rc 2)" "$(isrc 2)"
gen -w;                             check "a missing value is refused (rc 2)" "$(isrc 2)"
gen --list-releases;                check "--list-releases works" "$(isrc 0)"
check "  the default is marked" "$(has '26.5'"$(printf '\t')"'libc++ 21.1.8'"$(printf '\t')"'(default)')"
gen --show-config;                  check "--show-config works" "$(isrc 0)"
check "  default macOS 26.5" "$(has 'macos 26.5')"
check "  full SDK by default" "$(has 'variant full')"
gen --show-config --core --macos 14.3 --libcxx=17.0.6
check "  --core, --macos, --libcxx=value" "$( [ "$(has 'variant core')$(has 'macos 14.3')$(has 'libcxx 17.0.6')" = okokok ] && echo ok || echo no)"
check "  the steps of --core have no libs" "$( case $out in (*"steps fetch host headers stubs cxx meta tarball"*) echo ok;; (*) echo no;; esac)"
gen --show-config --macos 13.3;     check "the full SDK of macOS 13.3 is refused (rc 2)" "$(isrc 2)"
check "  and the message names --core" "$(has 'use --core')"
gen --show-config --macos 13.3 --core; check "the core SDK of macOS 13.3 is taken" "$(isrc 0)"
gen --show-config --macos 14.3;     check "the full SDK of macOS 14.3 is taken" "$(isrc 0)"
gen --list-releases;                check "--list-releases marks the releases that have only the core SDK" "$(has "13.3"$'\t'"libc++ 16.0.6"$'\t'"(core SDK only)")"
# the variables of OSXCross' tools.sh do not matter
genenv SDK_VERSION=11.3 TARBALL_DIR=/nonexistent/tarballs WORK=/nonexistent/work LIBCXX_VERSION=16.0.6 CLANG=/nonexistent/clang -- --show-config
check "the variables of OSXCross are ignored" "$( [ "$(has 'macos 26.5')$(has 'libcxx 21.1.8')" = okok ] && case $out in (*nonexistent*) echo no;; (*) echo ok;; esac || echo no)"
genenv OPEN_SDK_WORK_DIR=/w1 OPEN_SDK_OUTPUT_DIR=/o1 OPEN_SDK_CLANG=/c1/clang -- --show-config
check "OPEN_SDK_* variables are read" "$( [ "$(has 'work /w1')$(has 'output /o1')$(has 'clang /c1/clang')" = okokok ] && echo ok || echo no)"
genenv OPEN_SDK_WORK_DIR=/w1 -- --show-config -w /w2 -o /o2
check "options win over the variables" "$( [ "$(has 'work /w2')$(has 'output /o2')" = okok ] && echo ok || echo no)"
gen --show-config -w rel/w -o rel/o
check "relative paths become absolute" "$( [ "$(has "work $T/rel/w")$(has "output $T/rel/o")" = okok ] && echo ok || echo no)"
# --clean only touches a directory that the script made
mkdir -p "$T/foreign"; : > "$T/foreign/keep"
gen -w "$T/foreign" --clean;        check "--clean refuses a foreign directory" "$(isrc 1)"
check "  and keeps its files" "$([ -f "$T/foreign/keep" ] && echo ok || echo no)"
mkdir -p "$T/mine/src" "$T/mine/stage"; : > "$T/mine/.open-sdk-work"; : > "$T/mine/src/clone"; : > "$T/mine/stage/x"
gen -w "$T/mine" --clean;           check "--clean works in its own directory" "$(isrc 0)"
check "  it keeps src/ and deletes the rest" "$([ -f "$T/mine/src/clone" ] && [ ! -e "$T/mine/stage" ] && echo ok || echo no)"
gen -w "$T/mine" --clean-all;       check "--clean-all works" "$(isrc 0)"
check "  it deletes the work directory" "$([ ! -e "$T/mine" ] && echo ok || echo no)"
gen -w "$T/gone" --clean;           check "--clean of a missing directory is not an error" "$(isrc 0)"

# --min-deployment-target
gen --show-config
check "the minimum deployment target is 11.0 by default" "$(has 'min-deployment-target 11.0')"
gen --show-config --min-deployment-target 10.13
check "--min-deployment-target 10.13 is taken" "$(has 'min-deployment-target 10.13')"
genenv OPEN_SDK_MIN_DEPLOYMENT_TARGET=10.15 -- --show-config
check "OPEN_SDK_MIN_DEPLOYMENT_TARGET is read" "$(has 'min-deployment-target 10.15')"
genenv OPEN_SDK_MIN_DEPLOYMENT_TARGET=10.15 -- --show-config --min-deployment-target=12.0
check "  and the option wins" "$(has 'min-deployment-target 12.0')"
for bad in x 11 11.0.1 11.x -1.0 "" 26.6 27.0; do
  gen --show-config --min-deployment-target "$bad"
  check "a bad --min-deployment-target '$bad' is refused (rc 2)" "$(isrc 2)"
done
gen --show-config --macos 14.3 --min-deployment-target 14.3
check "a minimum equal to the release is accepted" "$(isrc 0)"
gen --show-config --macos 14.3 --min-deployment-target 15.0
check "a minimum above the release is refused (rc 2)" "$(isrc 2)"

# the commit of the generator: the label of the tarball name, "unknown" without a checkout
gl() { ( . "$HERE/../../lib/common.sh"; generator_label "$1" ); }
check "the label of a commit is its first 7 characters" "$( [ "$(gl 0123456789abcdef0123456789abcdef01234567)" = 0123456 ] && echo ok || echo no)"
check "the label unknown stays as it is" "$( [ "$(gl unknown)" = unknown ] && echo ok || echo no)"
check "the label of a modified commit is its first 7 characters and -modified" "$( [ "$(gl 0123456789abcdef0123456789abcdef01234567-modified)" = 0123456-modified ] && echo ok || echo no)"
mkdir -p "$T/nogit"
# shellcheck disable=SC2034  # SELF is read by generator_commit
gc() { ( SELF=$T/nogit; . "$HERE/../../lib/common.sh"; generator_commit ); }
check "generator_commit is unknown outside a checkout" "$( [ "$(gc)" = unknown ] && echo ok || echo no)"
if command -v git >/dev/null 2>&1; then
  mkdir -p "$T/repo"
  git -C "$T/repo" init -q && echo one > "$T/repo/f" && git -C "$T/repo" add f &&
    git -C "$T/repo" -c user.name=t -c user.email=t@example.com commit -q -m one
  # shellcheck disable=SC2034  # SELF is read by generator_commit
  gcr() { ( SELF=$T/repo; . "$HERE/../../lib/common.sh"; generator_commit ); }
  check "generator_commit is the whole commit in a clean checkout" "$( [ "$(gcr)" = "$(git -C "$T/repo" rev-parse HEAD)" ] && echo ok || echo no)"
  echo two > "$T/repo/f"
  check "generator_commit adds -modified if a tracked file is changed" "$( [ "$(gcr)" = "$(git -C "$T/repo" rev-parse HEAD)-modified" ] && echo ok || echo no)"
fi
gen --help
check "--help names the commit in the tarball name" "$(has 'open-sdk-<COMMIT>.tar.xz')"

# -v, --verbose: only the build shows more; the other actions print the same
gen --show-config; plain=$out
gen -v --show-config
check "-v is accepted" "$(isrc 0)"
check "  and changes nothing of --show-config" "$( [ "$out" = "$plain" ] && echo ok || echo no)"
gen --show-config --verbose
check "--verbose is accepted" "$( [ "$rc" = 0 ] && [ "$out" = "$plain" ] && echo ok || echo no)"
gen --help
check "--help names --verbose" "$(has '-v, --verbose')"
# to_log, quiet, show_log: the output goes to the log, and with VERBOSE=1 also to stdout
# shellcheck disable=SC2034  # VERBOSE is read by the functions of common.sh
vt() { ( set -o pipefail; VERBOSE=$1; shift; . "$HERE/../../lib/common.sh"; "$@" ); }
out=$(vt 0 to_log "$T/v.log" echo logged-line); rc=$?
check "to_log without -v writes only the log" "$( [ "$rc" = 0 ] && [ -z "$out" ] && [ "$(cat "$T/v.log")" = logged-line ] && echo ok || echo no)"
out=$(vt 1 to_log "$T/v.log" echo logged-line); rc=$?
check "to_log with -v shows the output and writes the log" "$( [ "$rc" = 0 ] && [ "$out" = logged-line ] && [ "$(cat "$T/v.log")" = logged-line ] && echo ok || echo no)"
out=$(vt 1 to_log "$T/v.log" sh -c 'echo err >&2; exit 3'); rc=$?
check "  it keeps the failure of the command and its stderr" "$( [ "$rc" != 0 ] && [ "$out" = err ] && [ "$(cat "$T/v.log")" = err ] && echo ok || echo no)"
out=$(vt 0 to_log "$T/v2.log" false); rc=$?
check "  also without -v" "$( [ "$rc" != 0 ] && echo ok || echo no)"
out=$(vt 0 quiet echo count); check "quiet hides stdout without -v" "$( [ -z "$out" ] && echo ok || echo no)"
out=$(vt 1 quiet echo count); check "  and shows it with -v" "$( [ "$out" = count ] && echo ok || echo no)"
out=$(vt 0 show_log "$T/v.log"); check "show_log shows nothing without -v" "$( [ -z "$out" ] && echo ok || echo no)"
out=$(vt 1 show_log "$T/v.log"); check "  and the file with -v" "$( [ "$out" = err ] && echo ok || echo no)"

echo "1..$n"
exit $fail
