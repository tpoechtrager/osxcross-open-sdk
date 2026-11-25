#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Stub libraries: libSystem and libiconv.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# Stub libraries
# ---------------------------------------------------------------------------
step_stubs() {
  local L=$STAGE/usr/lib a n s
  mkdir -p "$L" "$STAGE/work"
  log "Stubs"
  echo "libSystem"
  python3 -I "$HELPERS/syscall_syms.py" "$SRC/xnu" "$STAGE/work" "$STAGE/work/syscalls.syms" ||
    die "the system call stubs of xnu could not be listed"
  python3 -I "$HELPERS/gen_symbols.py" "$STAGE" "$(command -v "$CLANG")" "$STAGE/work/libsystem.syms" "$SRC" \
    "$STAGE/work/libsystem.errors" "$STAGE/work/syscalls.syms" ||
    die "gen_symbols.py failed (the errors of clang are in $STAGE/work/libsystem.errors)"
  show_log "$STAGE/work/libsystem.errors"
  # libsystem_dnssd is part of libSystem: its header is not in the list of xnu
  # or Libc, so it comes here with the other libraries of the full SDK
  if [ "$CORE" = 0 ]; then
    [ -f "$SRC/mDNSResponder/mDNSShared/dns_sd.h" ] ||
      die "mDNSResponder of this release has no mDNSShared/dns_sd.h"
    cp "$SRC/mDNSResponder/mDNSShared/dns_sd.h" "$STAGE/usr/include/"
    python3 -I "$HELPERS/hdr_syms.py" "$STAGE" "$(command -v "$CLANG")" "$STAGE/work/dnssd.syms" "" -- dns_sd.h
    cat "$STAGE/work/dnssd.syms" >> "$STAGE/work/libsystem.syms"
  fi
  # CommonCrypto is part of libSystem too (Libsystem/requiredlibs lists
  # commonCrypto).  The public headers are those of CommonCrypto/include; a
  # declaration is a symbol of libSystem if the export list of the project
  # (exports.exp-in) has it.  <availability.h> is <Availability.h> for the
  # case-sensitive file systems of the hosts that build the SDK.
  if [ "$CORE" = 0 ]; then
    local cch ccn=
    mkdir -p "$STAGE/usr/include/CommonCrypto"
    for cch in "$SRC"/CommonCrypto/include/*.h; do
      sed 's/^#include <availability\.h>/#include <Availability.h>/' "$cch" > "$STAGE/usr/include/CommonCrypto/$(basename "$cch")"
      if grep -q '^#include <availability\.h>' "$cch"; then
        add_notice "$STAGE/usr/include/CommonCrypto/$(basename "$cch")" "the include of availability.h is written Availability.h"
      fi
      ccn="$ccn CommonCrypto/$(basename "$cch")"
    done
    python3 -I "$HELPERS/hdr_syms.py" "$STAGE" "$(command -v "$CLANG")" "$STAGE/work/commoncrypto.all" "" -- $ccn
    awk 'NR == FNR { e[$1] = 1; next } ($2 in e)' "$SRC/CommonCrypto/exports.exp-in" "$STAGE/work/commoncrypto.all" \
      > "$STAGE/work/commoncrypto.syms"
    [ "$(wc -l < "$STAGE/work/commoncrypto.syms")" -ge 40 ] || die "CommonCrypto has too few exported declarations"
    cat "$STAGE/work/commoncrypto.syms" >> "$STAGE/work/libsystem.syms"
  fi
  # launchd's liblaunch (bootstrap_*, launch_*, vproc_*) is in libxpc, which
  # libSystem re-exports (Libsystem/requiredlibs lists xpc).  The public
  # headers are those of the Xcode project (ATTRIBUTES Public); its script
  # xcscripts/liblaunch-postflight.sh moves bootstrap.h to servers/ and links
  # bootstrap_defs.h to it.  A declaration is a symbol if liblaunch/*.c
  # defines the function.  launchd-842.92.1 is the last published launchd and
  # is in no release.json, so the manifests keep it as a fixed tag.
  if [ "$CORE" = 0 ]; then
    mkdir -p "$STAGE/usr/include/servers"
    cp "$SRC/launchd/liblaunch/launch.h" "$SRC/launchd/liblaunch/vproc.h" "$STAGE/usr/include/"
    cp "$SRC/launchd/liblaunch/bootstrap.h" "$STAGE/usr/include/servers/"
    ln -sf bootstrap.h "$STAGE/usr/include/servers/bootstrap_defs.h"
    python3 -I "$HELPERS/hdr_syms.py" "$STAGE" "$(command -v "$CLANG")" "$STAGE/work/launchd.all" "" -- launch.h vproc.h servers/bootstrap.h
    grep -ho '^[A-Za-z_][A-Za-z0-9_]*(' "$SRC"/launchd/liblaunch/*.c | sed 's/($//' | sort -u > "$STAGE/work/launchd.defs"
    awk 'NR == FNR { d["_" $1] = 1; next } ($2 in d)' "$STAGE/work/launchd.defs" "$STAGE/work/launchd.all" > "$STAGE/work/launchd.syms"
    [ "$(wc -l < "$STAGE/work/launchd.syms")" -ge 40 ] || die "liblaunch has too few declared and defined functions"
    cat "$STAGE/work/launchd.syms" >> "$STAGE/work/libsystem.syms"
  fi
  [ "$(wc -l < "$STAGE/work/libsystem.syms")" -ge 6000 ] ||
    die "libSystem has only $(wc -l < "$STAGE/work/libsystem.syms") symbols, something went wrong (see $STAGE/work/libsystem.errors)"
  mk_lib_tbd libSystem.B "$L/libSystem.B.tbd" "$STAGE/work/libsystem.syms"
  for n in libSystem libc libm libpthread libdl libinfo libutil librpcsvc; do
    ln -sf libSystem.B.tbd "$L/$n.tbd"
  done
  # libresolv (-lresolv): the project makes its stub from the headers, with
  # TAPI's installapi: resolv.h, nameser.h, dns.h, dns_util.h and the extra
  # header installapi.h of the project (OTHER_TAPI_FLAGS in
  # libresolv/xcodescripts/libresolv.xcconfig); links.sh makes the link
  # libresolv.tbd to libresolv.9.tbd
  echo "libresolv"
  mkdir -p "$STAGE/work/resolv-extra"
  cp "$SRC/libresolv/installapi.h" "$STAGE/work/resolv-extra/"
  python3 -I "$HELPERS/hdr_syms.py" "$STAGE" "$(command -v "$CLANG")" "$STAGE/work/libresolv.syms" \
    "-I$STAGE/work/resolv-extra" -- resolv.h nameser.h dns.h dns_util.h installapi.h
  # _res (__res) is defined in libSystem: "the main thread's __res_state should
  # come from libSystem to avoid breaking compatibility with older binaries"
  # (libresolv/res_state.c); it is in data/symbols/libsystem-extra.txt
  grep -v ' __res$' "$STAGE/work/libresolv.syms" > "$STAGE/work/libresolv.syms.f"
  mv "$STAGE/work/libresolv.syms.f" "$STAGE/work/libresolv.syms"
  mk_lib_tbd libresolv.9 "$L/libresolv.9.tbd" "$STAGE/work/libresolv.syms"
  ln -sf libresolv.9.tbd "$L/libresolv.tbd"
  # libiconv (-liconv; libstdc++ links against it)
  # the layout of libiconv differs between releases
  local h f
  for h in iconv.h libcharset.h localcharset.h; do
    f=$(find "$SRC/libiconv" -name "$h" -path '*/citrus/*' -o -name "$h" -path '*/libcharset/*' | sort | head -n 1)
    [ -n "$f" ] || f=$(find "$SRC/libiconv" -name "$h" | sort | head -n 1)
    cp "$f" "$STAGE/usr/include/"
  done
  { for a in x86_64 arm64; do
      for s in _iconv _iconv_open _iconv_close ___iconv_get_list ___iconv_free_list ___iconv _iconv_open_into \
               _libiconv_set_relocation_prefix _iconvlist _iconv_canonicalize _iconvctl _libiconv_version \
               _locale_charset _libcharset_set_relocation_prefix; do echo "$a $s"; done
    done; } > "$STAGE/work/libiconv.syms"
  echo "libiconv"
  mk_lib_tbd libiconv.2 "$L/libiconv.2.tbd" "$STAGE/work/libiconv.syms"
  ln -sf libiconv.2.tbd "$L/libiconv.tbd"
}
