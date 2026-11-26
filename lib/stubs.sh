#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Stub libraries: libSystem, libresolv and libiconv.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# Stub libraries
# ---------------------------------------------------------------------------
step_stubs() {
  mkdir -p "$STAGE_LIB" "$STAGE_WORK"
  log "Stubs"
  echo "libSystem"
  stubs_libsystem_headers
  # the parts of libSystem whose headers are only in the full SDK
  if [ "$VARIANT" = full ]; then
    stubs_dnssd
    stubs_commoncrypto
    stubs_launchd
  fi
  stubs_compiler_rt
  stubs_libsystem_tbd
  echo "libresolv"
  stubs_libresolv
  stubs_libiconv
}

# stubs_libsystem_headers: the symbols of libSystem that the headers of the
# step headers declare and the system call stubs (libsystem.syms; the next
# functions add to it)
stubs_libsystem_headers() {
  python3 -I "$HELPERS/syscall_syms.py" "$SRC/xnu" "$STAGE_WORK" "$STAGE_WORK/syscalls.syms" ||
    die "the system call stubs of xnu could not be listed"
  python3 -I "$HELPERS/libsystem_syms.py" "$STAGE" "$CLANG_PATH" "$STAGE_WORK/libsystem.syms" "$SRC" \
    --extra "$DATA/symbols/libsystem-extra.txt" --exclude "$DATA/symbols/libsystem-exclude.txt" \
    --errors "$STAGE_WORK/libsystem.errors" --syscalls "$STAGE_WORK/syscalls.syms" ||
    die "libsystem_syms.py failed (the errors of clang are in $STAGE_WORK/libsystem.errors)"
  show_log "$STAGE_WORK/libsystem.errors"
}

# stubs_dnssd: libsystem_dnssd is part of libSystem: its header is not in the
# list of xnu or Libc, so it comes here with the other libraries of the full SDK
stubs_dnssd() {
  [ -f "$SRC/mDNSResponder/mDNSShared/dns_sd.h" ] ||
    die "mDNSResponder of this release has no mDNSShared/dns_sd.h"
  cp "$SRC/mDNSResponder/mDNSShared/dns_sd.h" "$STAGE_INC/"
  header_syms "$STAGE_WORK/dnssd.syms" "" dns_sd.h
  cat "$STAGE_WORK/dnssd.syms" >> "$STAGE_WORK/libsystem.syms"
}

# stubs_commoncrypto: CommonCrypto is part of libSystem too (Libsystem/requiredlibs
# lists commonCrypto).  The public headers are those of CommonCrypto/include; a
# declaration is a symbol of libSystem if the export list of the project
# (exports.exp-in) has it.  <availability.h> is <Availability.h> for the
# case-sensitive file systems of the hosts that build the SDK.
stubs_commoncrypto() {
  local cch ccn=
  mkdir -p "$STAGE_INC/CommonCrypto"
  for cch in "$SRC"/CommonCrypto/include/*.h; do
    sed 's/^#include <availability\.h>/#include <Availability.h>/' "$cch" > "$STAGE_INC/CommonCrypto/$(basename "$cch")"
    if grep -q '^#include <availability\.h>' "$cch"; then
      add_notice "$STAGE_INC/CommonCrypto/$(basename "$cch")" "the include of availability.h is written Availability.h"
    fi
    ccn="$ccn CommonCrypto/$(basename "$cch")"
  done
  # shellcheck disable=SC2086
  header_syms "$STAGE_WORK/commoncrypto.all" "" $ccn
  awk 'NR == FNR { e[$1] = 1; next } ($2 in e)' "$SRC/CommonCrypto/exports.exp-in" "$STAGE_WORK/commoncrypto.all" \
    > "$STAGE_WORK/commoncrypto.syms"
  require_lines "$STAGE_WORK/commoncrypto.syms" 40 "CommonCrypto has too few exported declarations"
  cat "$STAGE_WORK/commoncrypto.syms" >> "$STAGE_WORK/libsystem.syms"
}

# stubs_launchd: launchd's liblaunch (bootstrap_*, launch_*, vproc_*) is in
# libxpc, which libSystem re-exports (Libsystem/requiredlibs lists xpc).  The
# public headers are those of the Xcode project (ATTRIBUTES Public); its script
# xcscripts/liblaunch-postflight.sh moves bootstrap.h to servers/ and links
# bootstrap_defs.h to it.  A declaration is a symbol if liblaunch/*.c
# defines the function.  launchd-842.92.1 is the last published launchd and
# is in no release.json, so the manifests keep it as a fixed tag.
stubs_launchd() {
  mkdir -p "$STAGE_INC/servers"
  cp "$SRC/launchd/liblaunch/launch.h" "$SRC/launchd/liblaunch/vproc.h" "$STAGE_INC/"
  cp "$SRC/launchd/liblaunch/bootstrap.h" "$STAGE_INC/servers/"
  ln -sf bootstrap.h "$STAGE_INC/servers/bootstrap_defs.h"
  header_syms "$STAGE_WORK/launchd.all" "" launch.h vproc.h servers/bootstrap.h
  grep -ho '^[A-Za-z_][A-Za-z0-9_]*(' "$SRC"/launchd/liblaunch/*.c | sed 's/($//' | sort -u > "$STAGE_WORK/launchd.defs"
  awk 'NR == FNR { d["_" $1] = 1; next } ($2 in d)' "$STAGE_WORK/launchd.defs" "$STAGE_WORK/launchd.all" > "$STAGE_WORK/launchd.syms"
  require_lines "$STAGE_WORK/launchd.syms" 40 "liblaunch has too few declared and defined functions"
  cat "$STAGE_WORK/launchd.syms" >> "$STAGE_WORK/libsystem.syms"
}

# stubs_compiler_rt: the builtins of compiler-rt that libSystem has (128-bit
# integer division, __atomic_* ...), per architecture (data/symbols/compiler-rt.txt)
stubs_compiler_rt() {
  syms_by_arch "$DATA/symbols/compiler-rt.txt" >> "$STAGE_WORK/libsystem.syms"
}

# stubs_libsystem_tbd: libSystem.B.tbd and the links of the libraries that are
# part of libSystem
stubs_libsystem_tbd() {
  local n
  require_lines "$STAGE_WORK/libsystem.syms" 6000 \
    "libSystem has only $(wc -l < "$STAGE_WORK/libsystem.syms") symbols, something went wrong (see $STAGE_WORK/libsystem.errors)"
  mk_lib_tbd libSystem.B "$STAGE_LIB/libSystem.B.tbd" "$STAGE_WORK/libsystem.syms"
  for n in libSystem libc libm libpthread libdl libinfo libutil librpcsvc; do
    ln -sf libSystem.B.tbd "$STAGE_LIB/$n.tbd"
  done
}

# stubs_libresolv: libresolv (-lresolv): the project makes its stub from the
# headers, with TAPI's installapi: resolv.h, nameser.h, dns.h, dns_util.h and
# the extra header installapi.h of the project (OTHER_TAPI_FLAGS in
# libresolv/xcodescripts/libresolv.xcconfig); links.sh makes the link
# libresolv.tbd to libresolv.9.tbd
stubs_libresolv() {
  mkdir -p "$STAGE_WORK/resolv-extra"
  cp "$SRC/libresolv/installapi.h" "$STAGE_WORK/resolv-extra/"
  header_syms "$STAGE_WORK/libresolv.syms" "-I$STAGE_WORK/resolv-extra" resolv.h nameser.h dns.h dns_util.h installapi.h
  # _res (__res) is defined in libSystem: "the main thread's __res_state should
  # come from libSystem to avoid breaking compatibility with older binaries"
  # (libresolv/res_state.c); it is in data/symbols/libsystem-extra.txt
  grep -v ' __res$' "$STAGE_WORK/libresolv.syms" > "$STAGE_WORK/libresolv.syms.f"
  mv "$STAGE_WORK/libresolv.syms.f" "$STAGE_WORK/libresolv.syms"
  mk_lib_tbd libresolv.9 "$STAGE_LIB/libresolv.9.tbd" "$STAGE_WORK/libresolv.syms"
  ln -sf libresolv.9.tbd "$STAGE_LIB/libresolv.tbd"
}

# stubs_libiconv: libiconv (-liconv; libstdc++ links against it); the symbols
# are those of data/symbols/libiconv.txt
stubs_libiconv() {
  local h f
  # the layout of libiconv differs between releases
  for h in iconv.h libcharset.h localcharset.h; do
    f=$(find "$SRC/libiconv" -name "$h" -path '*/citrus/*' -o -name "$h" -path '*/libcharset/*' | sort | head -n 1)
    [ -n "$f" ] || f=$(find "$SRC/libiconv" -name "$h" | sort | head -n 1)
    cp "$f" "$STAGE_INC/"
  done
  syms_for_archs "$DATA/symbols/libiconv.txt" > "$STAGE_WORK/libiconv.syms"
  echo "libiconv"
  mk_lib_tbd libiconv.2 "$STAGE_LIB/libiconv.2.tbd" "$STAGE_WORK/libiconv.syms"
  ln -sf libiconv.2.tbd "$STAGE_LIB/libiconv.tbd"
}
