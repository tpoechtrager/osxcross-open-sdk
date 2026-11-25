#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Common helpers: logging, portability wrappers, tool checks.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# log TEXT...: a heading of the output.  After the first one, the first heading
# of a step is preceded by an empty line (LOG_GAP=1 is set by the loop over the steps).
LOG_PRINTED=0 LOG_GAP=0
log() {
  if [ "$LOG_GAP" = 1 ] && [ "$LOG_PRINTED" = 1 ]; then echo >&2; fi
  LOG_GAP=0 LOG_PRINTED=1
  printf '== %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Portability helpers: the script runs on Linux, macOS (bash 3.2, BSD tools),
# FreeBSD and OpenBSD.  No GNU-only options (sed -i, head -n -N, cp -a,
# sha256sum, tar --sort, ...) and no bash 4 features below.
# ---------------------------------------------------------------------------
# sed_inplace FILE SED-ARGS...: like GNU `sed -i`; BSD sed needs a suffix
# argument for -i, and the two flavours disagree on what it means.
sed_inplace() {
  local f=$1 t; shift
  t=$f.oc-sed.$$
  sed "$@" "$f" > "$t" && cat "$t" > "$f"
  rm -f "$t"
}

# perl_first_include FILE TEXT: put TEXT (with \n for new lines) in front of
# the first #include line of FILE (what GNU sed does with 0,/^#include/s//.../)
perl_first_include() {
  OC_TEXT=$2 perl -pi -e 'BEGIN { ($t = $ENV{OC_TEXT}) =~ s/\\n/\n/g } if (!$d && s/^#include/${t}#include/) { $d = 1 }' "$1"
}

# copy_tree FROM TO: copy the contents of the directory FROM into TO, keeping
# symlinks and modes (cp -a is not available on OpenBSD)
copy_tree() { cp -RPp "$1/." "$2/"; }

# sha256_check HASH FILE
sha256_check() {
  local sum
  if command -v sha256sum >/dev/null 2>&1; then sum=$(sha256sum "$2" | cut -d' ' -f1)
  elif command -v shasum >/dev/null 2>&1; then sum=$(shasum -a 256 "$2" | cut -d' ' -f1)
  elif command -v sha256 >/dev/null 2>&1; then sum=$(sha256 -q "$2")
  else sum=$(openssl dgst -sha256 "$2" | sed 's/.*= *//'); fi
  [ "$sum" = "$1" ]
}

# GNU make for the Makefiles of xnu: gmake on the BSDs, make elsewhere
# shellcheck disable=SC2209
if command -v gmake >/dev/null 2>&1; then MAKE=gmake; else MAKE=make; fi
export MAKE

die() { echo "make-open-sdk.sh: $*" >&2; exit 1; }

# to_log LOG COMMAND...: run COMMAND with its output (stdout and stderr) in
# LOG.  With -v (VERBOSE=1) the output is shown too, and so it is in build.log;
# the status is the one of COMMAND (pipefail).
to_log() {
  local log=$1; shift
  if [ "${VERBOSE:-0}" = 1 ]; then "$@" 2>&1 | tee "$log"; else "$@" > "$log" 2>&1; fi
}

# quiet COMMAND...: run COMMAND without its standard output (a count of files
# or symbols that the steps do not show); with -v it is shown.
quiet() {
  if [ "${VERBOSE:-0}" = 1 ]; then "$@"; else "$@" > /dev/null; fi
}

# show_log FILE: with -v, show a log that a helper wrote (the errors of clang
# that gen_symbols.py expects)
show_log() {
  if [ "${VERBOSE:-0}" = 1 ]; then cat "$1"; fi
}

# run_logged LOG COMMAND...: run a command of Apple's scripts with its output
# in LOG; if it fails, show the end of the log and stop.
run_logged() {
  local log=$1; shift
  to_log "$log" "$@" || { tail -n 30 "$log" >&2; die "failed: $* (the log is $log)"; }
}

# generator_commit: the commit of this repository if it is a git checkout
# without changes to tracked files; the commit and "-modified" if there are
# changes, "unknown" if this is not a checkout (a copy, an export of git archive).  Only the
# repository at the script's own directory counts, never an enclosing one.
generator_commit() {
  [ -e "$SELF/.git" ] && command -v git >/dev/null 2>&1 || { echo unknown; return; }
  local c
  c=$(git -C "$SELF" rev-parse HEAD 2>/dev/null) || { echo unknown; return; }
  if [ -n "$(git -C "$SELF" status --porcelain --untracked-files=no 2>/dev/null)" ]; then echo "$c-modified"; else echo "$c"; fi
}

# generator_label COMMIT: what the tarball's name and the "Generator" line show:
# the first 7 characters of a commit (with "-modified" if it has that), or "unknown"
generator_label() {
  case $1 in
    unknown) echo unknown;;
    *-modified) echo "$(echo "$1" | cut -c1-7)-modified";;
    *) echo "$1" | cut -c1-7;;
  esac
}

# data/libraries.txt: install name, current and compatibility version of the
# stub libraries.  lib_field NAME COLUMN, lib_current NAME.
lib_field() { awk -v n="$1" -v c="$2" '$1 == n { print $c }' "$DATA/libraries.txt"; }

# tag_version PROJECT: the number of the tag of PROJECT in the manifest
# ("libffi-40" gives 40), at most three components
tag_version() {
  local t
  t=$(echo "$PROJECTS" | awk -v p="$1" '$1 == p { print $2 }')
  [ -n "$t" ] || die "the manifest of macOS $SDK_VERSION has no project $1"
  echo "${t#"$1"-}" | cut -d. -f1-3
}

lib_current() {
  local v
  v=$(lib_field "$1" 3)
  case $v in tag:*) tag_version "${v#tag:}";; *) echo "$v";; esac
}

# mk_lib_tbd NAME OUTFILE SYMFILE [MK_TBD-OPTION...]: the .tbd of a library of
# data/libraries.txt
mk_lib_tbd() {
  local name=$1 out=$2 syms=$3 inst cur compat; shift 3
  inst=$(lib_field "$name" 2); cur=$(lib_current "$name"); compat=$(lib_field "$name" 4)
  [ -n "$inst" ] && [ -n "$cur" ] && [ -n "$compat" ] || die "data/libraries.txt has no complete line for $name"
  python3 -I "$HELPERS/mk_tbd.py" "$out" "$inst" "$cur" "$syms" --compat "$compat" ${1+"$@"}
}

# add_notice FILE TEXT: the notice that a header was changed by this script
# (helpers/notice.py).  The date is the one of the change, not of the build.
NOTICE_DATE=2026-11-24
add_notice() { python3 -I "$HELPERS/notice.py" "$NOTICE_DATE" "$1" "$2"; }

# has_step NAME: is the step in the list of steps to run?
has_step() { case " $STEPS " in *" $1 "*) return 0;; *) return 1;; esac; }

# find_yacc: set YACC (the program) and YACC_FLAGS to a yacc that works.
# OPEN_SDK_YACC, if set, is the only candidate (a program and its flags, for
# example "bison -y").  Otherwise the first working one of yacc, bison -y and the
# places where MacPorts and Homebrew put bison.  yacc can exist and still fail:
# the command line tools of macOS have a yacc that wants Xcode's bison.
find_yacc() {
  local c cmd flags t=$WORK/yacc-test cands
  if [ -n "${OPEN_SDK_YACC:-}" ]; then cands=$OPEN_SDK_YACC
  else
    cands="yacc
bison -y
/opt/local/bin/bison -y
/opt/homebrew/opt/bison/bin/bison -y
/usr/local/opt/bison/bin/bison -y"
  fi
  rm -rf "$t"; mkdir -p "$t"
  printf '%%%%\ns: ;\n' > "$t/t.y"
  YACC=
  # shellcheck disable=SC2034
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    cmd=${c%% *}; flags=
    [ "$cmd" = "$c" ] || flags=${c#* }
    command -v "$cmd" >/dev/null 2>&1 || continue
    if (cd "$t" && "$cmd" $flags -d t.y) >/dev/null 2>&1; then
      YACC=$(command -v "$cmd"); YACC_FLAGS=$flags
      break
    fi
  done <<EOF2
$cands
EOF2
  rm -rf "$t"
  [ -n "$YACC" ]
}

# BASE_TOOLS: the tools that every run needs, whatever the steps.
BASE_TOOLS="python3 perl sed awk cut tr sort find"

# tools_of_step STEP: the tools that STEP needs besides BASE_TOOLS.
tools_of_step() {
  case $1 in
    fetch)                echo git; [ "$CORE" = 1 ] || echo curl;;
    host)                 echo "$CLANG" flex;;
    headers)              echo "$MAKE" "$CLANG";;
    stubs|cxx|frameworks) echo "$CLANG";;
    libs)                 echo "$CLANG" curl;;
    tarball)              echo tar;;
    swift)                echo bsdtar "$CLANG";;
  esac
}

# Fail early, with all missing tools at once.  Only the tools of the steps
# that run are needed.
check_tools() {
  local t s missing=""

  # 1. Every tool of every step that runs must be in the PATH.
  for t in $BASE_TOOLS $(for s in $STEPS; do tools_of_step "$s"; done); do
    command -v "$t" >/dev/null 2>&1 || case " $missing " in *" $t "*) ;; *) missing="$missing $t";; esac
  done
  # xz: the xz tool, or bsdtar with liblzma (macOS has no xz)
  if has_step tarball; then
    command -v xz >/dev/null 2>&1 || command -v bsdtar >/dev/null 2>&1 || missing="$missing xz(or bsdtar)"
  fi
  if [ -n "$missing" ]; then
    echo "make-open-sdk.sh: missing tools:$missing" >&2
    echo "Needed: git curl python3 perl flex yacc (or bison), GNU make, clang, tar, xz or bsdtar." >&2
    exit 1
  fi

  # 2. Versions and variants.
  python3 -I -c 'import sys; sys.exit(sys.version_info < (3, 7))' 2>/dev/null ||
    die "Python 3.7 or newer is needed ($(python3 -V 2>&1))"
  if has_step headers && ! "$MAKE" --version 2>/dev/null | grep -q GNU; then
    die "GNU make is needed for the Makefiles of xnu (BSD: pkg/pkg_add gmake)"
  fi

  # 3. yacc, only if migcom has to be built.
  if has_step host && [ ! -x "$HOST/bin/migcom" ]; then
    if ! find_yacc; then
      if [ -n "${OPEN_SDK_YACC:-}" ]; then die "OPEN_SDK_YACC='$OPEN_SDK_YACC' does not work"; fi
      die "no working yacc: macOS command line tools have a yacc that needs Xcode. Install bison (MacPorts: /opt/local/bin/bison, Homebrew: /opt/homebrew/opt/bison/bin/bison or /usr/local/opt/bison/bin/bison) or set OPEN_SDK_YACC"
    fi
  fi
}

# clean_work build|all: delete the build files (build: keep src/, the clones)
# or the whole work directory.  Only a directory that this script made.
clean_work() {
  [ -e "$WORK" ] || { log "nothing to clean: $WORK does not exist"; return 0; }
  [ -f "$WORK/.open-sdk-work" ] || die "$WORK is not a work directory of this script (no .open-sdk-work), not deleting it"
  if [ "$1" = all ]; then
    log "delete $WORK"
    rm -rf "${WORK:?}"
  else
    log "delete the build files in $WORK (src/ stays)"
    find "${WORK:?}" -mindepth 1 -maxdepth 1 ! -name src ! -name .open-sdk-work -exec rm -rf {} +
  fi
}

# ---------------------------------------------------------------------------
# Headers
# ---------------------------------------------------------------------------
# Clean environment for Apple's scripts
# (The scripts start `bash`: on the BSDs it is in /usr/local/bin, so the
# directory of the running bash is added to the PATH if it is not a standard one.)
case $(dirname "$BASH") in /usr/bin|/bin|/usr/sbin) AENV_PATH=;; *) AENV_PATH=:$(dirname "$BASH");; esac
aenv() { env -i HOME="$HOME" PATH="$HOST/bin:/usr/bin:/bin:/usr/sbin$AENV_PATH" TERM=dumb \
  CLANG="$(command -v "$CLANG")" "$@"; }


# Apple's scripts name /usr/bin/perl and /bin/bash; the BSDs have them in
# /usr/local/bin.  Point the scripts that we run at the interpreter in the PATH.
fix_shebangs() {
  local d f
  for d in Libc/xcodescripts Libinfo/xcodescripts ncurses/xcodescripts xnu/libsyscall/xcodescripts xnu/bsd/sys xnu/bsd/kern; do
    [ -d "$SRC/$d" ] || continue
    for f in "$SRC/$d"/*; do
      [ -f "$f" ] || continue
      if [ ! -x /usr/bin/perl ]; then
        head -n 1 "$f" | grep -q '^#! */usr/bin/perl' && sed_inplace "$f" '1s|^#! */usr/bin/perl|#!/usr/bin/env perl|'
      fi
      if [ ! -x /bin/bash ]; then
        head -n 1 "$f" | grep -q '^#! */bin/bash' && sed_inplace "$f" '1s|^#! */bin/bash|#!/usr/bin/env bash|'
      fi
    done
  done
  return 0
}
