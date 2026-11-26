#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Tests of the functions of lib/common.sh and lib/fetch.sh that need neither
# network nor a compiler: tests/unit/test_common.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/open-sdk-test.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT
fail=0 n=0

check() { # description, ok or no
  n=$((n + 1))
  if [ "$2" = ok ]; then echo "ok $n - $1"; else echo "not ok $n - $1"; fail=1; fi
}
is() { [ "$1" = "$2" ] && echo ok || { echo "   got '$1', want '$2'" >&2; echo no; }; }

# lib: run a function of lib/common.sh and lib/fetch.sh in a subshell with
# the variables of make-open-sdk.sh that it reads
# shellcheck disable=SC2034  # the variables are read by the functions
lib() (
  SELF=$ROOT HELPERS=$ROOT/helpers DATA=$ROOT/data SDK_VERSION=26.5 STAGE=$T/stage
  PROJECTS="Libsystem Libsystem-1356.100.2.0.1 0123
libffi libffi-40 4567"
  . "$ROOT/lib/common.sh"
  . "$ROOT/lib/fetch.sh"
  "$@"
)

check "version_lt 11.3 14.3" "$(lib version_lt 11.3 14.3 && echo ok || echo no)"
check "version_lt 14.10 14.3 is false" "$(lib version_lt 14.10 14.3 && echo no || echo ok)"
check "version_lt 14.3 14.3 is false" "$(lib version_lt 14.3 14.3 && echo no || echo ok)"
check "version_lt 26.5 26.5.1" "$(lib version_lt 26.5 26.5.1 && echo ok || echo no)"

check "tag_version takes at most three components" "$(is "$(lib tag_version Libsystem)" 1356.100.2)"
check "tag_version of a short tag" "$(is "$(lib tag_version libffi)" 40)"
check "tag_version of a project that is not in the manifest fails" "$(lib tag_version nothere >/dev/null 2>&1 && echo no || echo ok)"
check "lib_current of a tag: entry" "$(is "$(lib lib_current libSystem.B)" 1356.100.2)"
check "lib_current of a number" "$(is "$(lib lib_current libz.1)" 1.2.12)"
check "lib_field reads the install name" "$(is "$(lib lib_field libz.1 2)" /usr/lib/libz.1.dylib)"

printf '# head\n_a   # source\n\n  _b\n# _c\n' > "$T/syms.txt"
check "symbol_list skips comments and empty lines" "$(is "$(lib symbol_list "$T/syms.txt" | tr '\n' ' ')" "_a _b ")"
check "syms_for_archs gives both architectures" "$(is "$(lib syms_for_archs "$T/syms.txt" | tr '\n' ',')" "x86_64 _a,x86_64 _b,arm64 _a,arm64 _b,")"

printf '# head\n_a all\n_b x86_64   # only here\n_c arm64\n' > "$T/byarch.txt"
check "syms_by_arch gives the symbols of each architecture" "$(is "$(lib syms_by_arch "$T/byarch.txt" | tr '\n' ',')" "x86_64 _a,x86_64 _b,arm64 _a,arm64 _c,")"
for bad in '_a' '_a ppc' '_a all x'; do
  printf '%s\n' "$bad" > "$T/badarch.txt"
  check "syms_by_arch refuses the line '$bad'" "$(lib syms_by_arch "$T/badarch.txt" >/dev/null 2>&1 && echo no || echo ok)"
done
crt=$(lib syms_by_arch "$ROOT/data/symbols/compiler-rt.txt")
check "compiler-rt.txt: 132 symbols for x86_64 and 119 for arm64" "$(is "$(echo "$crt" | grep -c '^x86_64 ') $(echo "$crt" | grep -c '^arm64 ')" "132 119")"
check "  ___udivti3 for both, the x87 and arm64-less ones only for x86_64" "$(is "$(echo "$crt" | grep -E ' (___udivti3|___divxc3|___enable_execute_stack)$' | tr '\n' ',')" "x86_64 ___divxc3,x86_64 ___enable_execute_stack,x86_64 ___udivti3,arm64 ___udivti3,")"
check "  no tf variants" "$(echo "$crt" | grep -qE '(tf|tc3)' && echo no || echo ok)"
check "  and no duplicates" "$(is "$(echo "$crt" | sort | uniq -d | wc -l | tr -d ' ')" 0)"

lib mk_lib_tbd libz.1 "$T/libz.1.tbd" <(lib syms_for_archs "$T/syms.txt") >/dev/null 2>&1
check "mk_lib_tbd writes the install name of data/libraries.txt" "$(grep -q "^install-name: *'/usr/lib/libz.1.dylib'" "$T/libz.1.tbd" && echo ok || echo no)"
check "  and its versions" "$(grep -q '^current-version: 1.2.12' "$T/libz.1.tbd" && grep -q '^compatibility-version: 1$' "$T/libz.1.tbd" && echo ok || echo no)"
check "mk_lib_tbd of a library that is not in the table fails" "$(lib mk_lib_tbd nothere "$T/x.tbd" "$T/syms.txt" >/dev/null 2>&1 && echo no || echo ok)"

printf 'one\ntwo\n' > "$T/f"
lib sed_inplace "$T/f" 's/one/1/'
check "sed_inplace changes the file" "$(is "$(tr '\n' ' ' < "$T/f")" "1 two ")"
check "  and leaves no temporary file" "$(set -- "$T"/f.*; [ ! -e "$1" ] && echo ok || echo no)"

mkdir -p "$T/from/d" "$T/to"; echo x > "$T/from/d/file"; ln -s d/file "$T/from/link"
lib copy_tree "$T/from" "$T/to"
check "copy_tree copies files" "$([ -f "$T/to/d/file" ] && echo ok || echo no)"
check "  and keeps links" "$(is "$(readlink "$T/to/link")" d/file)"

check "default_release is the release marked default" "$(is "$(lib default_release)" "$(awk '$5 == "default" { print $1 }' "$ROOT/data/releases.txt")")"
check "releases full starts with 14.3" "$(is "$(lib releases full | head -n 1)" 14.3)"
check "releases lists the core releases too" "$(is "$(lib releases | head -n 1)" 11.3)"
check "release_value gives the libc++ of a release" "$(is "$(lib release_value 14.3 2)" 16.0.6)"
check "llvm_commit of a release of the table" "$(lib llvm_commit 16.0.6 | grep -Eq '^[0-9a-f]{40}$' && echo ok || echo no)"
check "manifest_projects gives three fields" "$(lib manifest_projects "$ROOT/data/manifests/macos-265.txt" | awk 'NF != 3 { bad = 1 } END { print (NR > 10 && !bad) ? "ok" : "no" }')"
check "manifest_xz gives the commit" "$(lib manifest_xz "$ROOT/data/manifests/macos-265.txt" 4 | grep -Eq '^[0-9a-f]{40}$' && echo ok || echo no)"
check "manifest_sqlite gives the URL" "$(lib manifest_sqlite "$ROOT/data/manifests/macos-265.txt" 2 | grep -q '^https://.*\.zip$' && echo ok || echo no)"

lib install_own_files all
check "install_own_files copies the own headers by their path" "$(cmp -s "$ROOT/data/headers/usr/include/os/log.h" "$T/stage/usr/include/os/log.h" && echo ok || echo no)"
check "  only those of the variant" "$([ ! -e "$T/stage/usr/include/xpc/xpc.h" ] && echo ok || echo no)"
check "  and no fallback" "$([ ! -e "$T/stage/usr/include/libDER/DERItem.h" ] && echo ok || echo no)"

mkdir -p "$T/src/old" "$T/src/new"; echo tag-1 > "$T/src/old/.oc-tag"; echo tag-2 > "$T/src/new/.open-sdk-tag"
# shellcheck disable=SC2034  # SRC is read by migrate_tag_marks
(SRC=$T/src; lib migrate_tag_marks)
check "migrate_tag_marks renames the mark .oc-tag" "$(is "$(cat "$T/src/old/.open-sdk-tag" 2>/dev/null)" tag-1)"
check "  and keeps the new marks" "$([ ! -e "$T/src/old/.oc-tag" ] && [ "$(cat "$T/src/new/.open-sdk-tag")" = tag-2 ] && echo ok || echo no)"

# the mark of the stage
mkdir -p "$T/stage"
check "stage_mark_check without a mark fails" "$(lib stage_mark_check release=26.5 >/dev/null 2>&1 && echo no || echo ok)"
lib stage_mark_set release 26.5; lib stage_mark_set variant core; lib stage_mark_set libcxx 21.1.8
check "stage_mark_check of the same values passes" "$(lib stage_mark_check release=26.5 variant=core libcxx=21.1.8 && echo ok || echo no)"
check "stage_mark_check of another release fails" "$(lib stage_mark_check release=14.3 >/dev/null 2>&1 && echo no || echo ok)"
check "  and names both releases" "$(lib stage_mark_check release=14.3 2>&1 | grep -q 'release 26.5, not for release 14.3' && echo ok || echo no)"
check "stage_mark_check of another variant fails" "$(lib stage_mark_check variant=full >/dev/null 2>&1 && echo no || echo ok)"
check "stage_mark_check of another libc++ fails" "$(lib stage_mark_check libcxx=20.1.0 >/dev/null 2>&1 && echo no || echo ok)"
lib stage_mark_set release 14.3
check "stage_mark_set replaces a key and keeps the others" "$(is "$(sort "$T/stage/.open-sdk-stage" | tr '\n' ' ')" 'libcxx 21.1.8 release 14.3 variant core ')"

echo "1..$n"
exit $fail
