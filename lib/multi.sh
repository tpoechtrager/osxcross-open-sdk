#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Several SDKs in one run: --macos LIST and --release.
# Sourced by make-open-sdk.sh; not meant to be run on its own.
#
# The script calls itself once for every SDK (run_multi), each with its own
# work directory <work-dir>/<release>[-core].  The clones in src/ are not
# shared: src/<project> holds one tag, and the releases use different tags, so
# a shared src/ would be cloned again whenever the release changes.

# tarball_name RELEASE VARIANT LABEL: the file name of a tarball (LABEL: generator_label)
tarball_name() {
  case $2 in
    full) echo "MacOSX$1-open-sdk-$3.tar.xz";;
    *)    echo "MacOSX$1-open-core-sdk-$3.tar.xz";;
  esac
}

# expand_macos_list LIST VARIANT: the SDKs that --macos LIST (a comma-separated
# list of releases, or "all") names, as "RELEASE VARIANT" lines in the order of
# the list (all: of data/releases.txt), a release once.  VARIANT is the one of
# --core (core) or not (full).  Without --core, "all" makes the core SDK of the
# releases that have no full SDK; a release that is named has to have one.
# Status 2 for a bad list or a full SDK that does not exist, 1 for an unknown release.
expand_macos_list() {
  local list=$1 variant=$2 v seen=" "
  if [ "$list" = all ]; then
    for v in $(releases); do
      if [ "$variant" = core ] || ! releases full | grep -qxF "$v"; then echo "$v core"; else echo "$v full"; fi
    done
    return 0
  fi
  if ! printf '%s\n' "$list" | grep -Eq '^[0-9]+\.[0-9]+(,[0-9]+\.[0-9]+)*$'; then
    echo "make-open-sdk.sh: --macos expects a version like 26.5, a comma-separated list (14.3,26.5) or all, not '$list'" >&2
    return 2
  fi
  for v in $(printf '%s\n' "$list" | tr , ' '); do
    case $seen in *" $v "*) continue;; esac
    seen="$seen$v "
    if ! releases | grep -qxF "$v"; then
      echo "make-open-sdk.sh: no manifest for macOS $v; releases with a manifest: $(releases | tr '\n' ' ')" >&2
      return 1
    fi
    if [ "$variant" = full ] && ! releases full | grep -qxF "$v"; then
      echo "make-open-sdk.sh: the full SDK is made for macOS $(releases full | head -n 1) and later; use --core for macOS $v" >&2
      return 2
    fi
    echo "$v $variant"
  done
}

# expand_release_list: the SDKs of --release: for every release of
# data/releases.txt the full SDK (if it has one) and the core SDK, as
# "RELEASE VARIANT" lines
expand_release_list() {
  local v
  for v in $(releases); do
    if releases full | grep -qxF "$v"; then echo "$v full"; fi
    echo "$v core"
  done
}

# run_multi RELEASE_MODE OUTDIR LIST: make the SDKs of LIST ("RELEASE VARIANT"
# lines) one after the other, each by a run of this script in the work
# directory $WORK/<release>[-core], the tarballs in OUTDIR.  The others are made
# even if one fails; the status is 1 then.  With --clean, --clean-all or
# --show-config the run only does that for every SDK.  RELEASE_MODE=1 (--release):
# SHA256SUMS of the tarballs in OUTDIR, if all were made.
run_multi() {
  local release=$1 out=$2 list=$3 v var sub args n=0 total failed='' rc tmp label sums name
  total=$(printf '%s\n' "$list" | wc -l | tr -d ' ')
  tmp=$(mktemp "${TMPDIR:-/tmp}/open-sdk-multi.XXXXXX") || die "cannot make a temporary file"
  # shellcheck disable=SC2064  # $tmp now
  trap "rm -f '$tmp'" EXIT
  while read -r v var; do
    n=$((n + 1))
    sub=$v; [ "$var" = full ] || sub=$v-core
    args=(--macos "$v" -w "$WORK/$sub" -o "$out" --min-deployment-target "$MIN_DEPLOYMENT_TARGET" --clang "$CLANG")
    if [ "$var" = core ]; then args+=(--core); fi
    if [ "$FORCE" = 1 ]; then args+=(--force); fi
    if [ "$TREE_HASH" = 1 ]; then args+=(--tree-hash); fi
    if [ "$VERBOSE" = 1 ]; then args+=(-v); fi
    if [ -n "$STEPS" ]; then args+=(-s "$STEPS"); fi
    case $CLEAN in
      build) args+=(--clean);;
      all) args+=(--clean-all);;
      *) if [ "$SHOW" = 1 ]; then args+=(--show-config); fi;;
    esac
    if [ -z "$CLEAN" ] && [ "$SHOW" = 0 ]; then
      printf '\n==== SDK %s of %s: macOS %s (%s)\n\n' "$n" "$total" "$v" "$var" >&2
    elif [ "$n" -gt 1 ]; then echo
    fi
    # (set +e: a failed SDK does not stop the others)
    set +e
    bash "$SELF/make-open-sdk.sh" "${args[@]}" | tee -a "$tmp"
    rc=${PIPESTATUS[0]}
    set -e
    if [ "$rc" -ne 0 ]; then failed="$failed
  macOS $v ($var)"; fi
  done <<EOF
$list
EOF
  if [ "$CLEAN" = all ]; then
    # the directory of the SDKs, if nothing else is in it
    rmdir "$WORK" 2>/dev/null || true   # (|| true: it has other files, or it is not there)
  fi
  if [ -n "$CLEAN" ] || [ "$SHOW" = 1 ]; then
    [ -z "$failed" ] || { echo "make-open-sdk.sh: failed:$failed" >&2; return 1; }
    return 0
  fi
  echo >&2
  if [ "$TREE_HASH" = 1 ]; then
    echo "Tree hashes" >&2
    grep 'tree hash' "$tmp" | sed 's/^ *//; s/^/  /' >&2 || true   # (|| true: no line if no SDK was made)
    echo >&2
  fi
  if [ -n "$failed" ]; then
    echo "make-open-sdk.sh: $(printf '%s\n' "$failed" | awk 'NF' | wc -l | tr -d ' ') of $total SDKs failed:$failed" >&2
    return 1
  fi
  echo "make-open-sdk.sh: $total SDKs made in $out" >&2
  if [ "$release" = 1 ]; then
    label=$(generator_label "$(generator_commit)")
    sums=$out/SHA256SUMS
    # the format of sha256sum and shasum -a 256, sorted by file name
    while read -r v var; do tarball_name "$v" "$var" "$label"; done <<EOF | sort > "$sums.names"
$list
EOF
    : > "$sums.new"
    while read -r name; do
      [ -f "$out/$name" ] || { rm -f "$sums.names" "$sums.new"; die "$out/$name does not exist, no SHA256SUMS (the step tarball did not run?)"; }
      printf '%s  %s\n' "$(sha256_of "$out/$name")" "$name" >> "$sums.new"
    done < "$sums.names"
    rm -f "$sums.names"
    mv "$sums.new" "$sums"
    echo "make-open-sdk.sh: $sums" >&2
  fi
}
