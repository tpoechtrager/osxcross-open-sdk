#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Frameworks (not with --core).
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# Frameworks (not with --core): CoreFoundation, IOKit, DiskArbitration,
# Security, SystemConfiguration: headers from the open source releases and a
# <Name>.tbd in the framework directory (Name.framework/Name.tbd); Foundation
# and CoreServices: only the .tbd (fw_placeholder).
# ---------------------------------------------------------------------------
# fw_tbd NAME HEADER... (a framework of data/libraries.txt; headers relative to Headers/)
fw_tbd() {
  local name=$1; shift
  local FW=$STAGE/System/Library/Frameworks W=$STAGE/work
  local args="" h s; for h in "$@"; do args="$args $name/$h"; done
  # shellcheck disable=SC2086
  python3 -I "$HELPERS/hdr_syms.py" "$STAGE" "$(command -v "$CLANG")" "$W/fw-$name.syms" "-F$FW" -- $args
  [ -f "$DATA/symbols/$name-extra.txt" ] && while read -r s; do
    [ -n "$s" ] && { echo "x86_64 $s"; echo "arm64 $s"; }
  done < <(sed 's/#.*//' "$DATA/symbols/$name-extra.txt") >> "$W/fw-$name.syms"
  mk_lib_tbd "$name" "$FW/$name.framework/$name.tbd" "$W/fw-$name.syms"
}

# fw_placeholder NAME: a framework without headers and symbols, only the .tbd
# (a framework of data/libraries.txt)
fw_placeholder() {
  local FW=$STAGE/System/Library/Frameworks W=$STAGE/work
  rm -rf "$FW/$1.framework"; mkdir -p "$FW/$1.framework"
  : > "$W/fw-$1.syms"
  mk_lib_tbd "$1" "$FW/$1.framework/$1.tbd" "$W/fw-$1.syms"
}

step_frameworks() {
  local I=$STAGE/usr/include FW=$STAGE/System/Library/Frameworks W=$STAGE/work
  mkdir -p "$W" "$FW"

  log "Frameworks"
  echo "CoreFoundation"
  local H=$FW/CoreFoundation.framework/Headers
  rm -rf "$FW/CoreFoundation.framework"; mkdir -p "$H"
  local h
  for h in $(grep -ho '<CoreFoundation/[A-Za-z_]*\.h>' "$SRC/CF/CoreFoundation.h" | sed 's#<CoreFoundation/##;s#>##'); do
    cp "$SRC/CF/$h" "$H/"
  done
  cp "$SRC/CF/CoreFoundation.h" "$SRC/CF/CFAvailability.h" "$SRC/CF/CFMachPort.h" "$H/"
  # headers that the copied headers include in turn (CFPlugIn.h: CFPlugInCOM.h)
  local more=1 n
  while [ "$more" = 1 ]; do
    more=0
    for n in $(grep -ho '#[[:space:]]*include <CoreFoundation/[A-Za-z0-9_]*\.h>' "$H"/*.h | sed 's#.*CoreFoundation/##; s#>##' | sort -u); do
      if [ ! -f "$H/$n" ] && [ -f "$SRC/CF/$n" ]; then cp "$SRC/CF/$n" "$H/"; more=1; fi
    done
  done
  perl -pi -e 's|^(#include <CoreFoundation/CFBase.h>)|$1\n#include <CoreFoundation/CFMachPort.h>|' "$H/CoreFoundation.h"
  cat "$DATA/headers/CFCompat.h.in" >> "$H/CFAvailability.h"
  add_notice "$H/CFAvailability.h" "annotation macros for the headers of other frameworks added at the end"
  add_notice "$H/CoreFoundation.h" "include of CFMachPort.h added"
  mkdir -p "$FW/CoreFoundation.framework/Modules"; cp "$DATA/headers/CoreFoundation.modulemap" "$FW/CoreFoundation.framework/Modules/module.modulemap"
  cp "$SRC/CarbonHeaders/MacTypes.h" "$SRC/CarbonHeaders/ConditionalMacros.h" "$I/"
  local hl; hl=$(cd "$H" && ls *.h | tr '\n' ' ')
  # shellcheck disable=SC2086
  fw_tbd CoreFoundation $hl

  echo "IOKit"
  H=$FW/IOKit.framework/Headers; rm -rf "$FW/IOKit.framework"; mkdir -p "$H/ps" "$H/pwr_mgt"
  local fl; fl=$(python3 -I "$HELPERS/xnu_headers.py" "$SRC/xnu" --print-flags)
  for h in IOBSD IODataQueueShared IOKitKeys IOKitServer IOMapTypes IOMessage IOReturn IORPC IOSharedLock IOTypes OSMessageNotification; do
    # shellcheck disable=SC2086
    run_unifdef $fl -o "$H/$h.h" "$SRC/xnu/iokit/IOKit/$h.h"
  done
  # shellcheck disable=SC2086
  for h in IOPM IOPMLibDefs; do   # IOPMLib.h includes IOPMLibDefs.h (xnu iokit/IOKit/pwr_mgt/Makefile: INSTALL_IF_MI_LIST)
    run_unifdef $fl -o "$H/pwr_mgt/$h.h" "$SRC/xnu/iokit/IOKit/pwr_mgt/$h.h"
  done
  cp "$SRC"/IOKitUser/{IOCFBundle,IOCFPlugIn,IOCFSerialize,IOCFURLAccess,IOCFUnserialize,IODataQueueClient,IOKitLib,iokitmig}.h "$H/"
  cp "$SRC"/IOKitUser/ps.subproj/{IOPowerSources,IOPSKeys,IOUPSPlugIn}.h "$H/ps/"
  cp "$SRC"/IOKitUser/pwr_mgt.subproj/{IOPMLib,IOPMKeys,IOPMAssertionCategories}.h "$H/pwr_mgt/"
  # iokitmig.h (a MIG interface) includes iokitmig_c.h, which MIG makes while IOKit is built
  # and which is not in the sources: it is copied above but not scanned for symbols.
  fw_tbd IOKit IOKitLib.h IOCFBundle.h IOCFPlugIn.h IOCFSerialize.h IOCFURLAccess.h IOCFUnserialize.h \
    IODataQueueClient.h ps/IOPowerSources.h ps/IOPSKeys.h pwr_mgt/IOPMLib.h pwr_mgt/IOPMKeys.h
  # Security's oids.h includes libDER/DERItem.h, which includes libDER_config.h; xnu
  # has both in EXTERNAL_HEADERS/libDER (APSL 2.0), unchanged here.  The rest of libDER is not
  # installed.  xpc/xpc.h is the one typedef that xnu's libkern/os/trace.h also writes
  # (line 36) for SecCode.h; libxpc itself has no open source.
  mkdir -p "$I/xpc" "$I/libDER"
  cp "$DATA/headers/xpc.h" "$I/xpc/xpc.h"
  # The xnu of macOS 26.5 has them; earlier releases do not, and get the small
  # own DERItem.h (the same types and struct).
  if [ -f "$SRC/xnu/EXTERNAL_HEADERS/libDER/DERItem.h" ] && [ -f "$SRC/xnu/EXTERNAL_HEADERS/libDER/libDER_config.h" ]; then
    cp "$SRC/xnu/EXTERNAL_HEADERS/libDER/DERItem.h" "$SRC/xnu/EXTERNAL_HEADERS/libDER/libDER_config.h" "$I/libDER/"
  else
    cp "$DATA/headers/DERItem.h" "$I/libDER/DERItem.h"
  fi

  echo "DiskArbitration"
  H=$FW/DiskArbitration.framework/Headers; rm -rf "$FW/DiskArbitration.framework"; mkdir -p "$H"
  cp "$SRC"/DiskArbitration/DiskArbitration/{DADisk,DADissenter,DASession,DiskArbitration}.h "$H/"
  fw_tbd DiskArbitration DADisk.h DADissenter.h DASession.h DiskArbitration.h

  echo "Security"
  H=$FW/Security.framework/Headers; rm -rf "$FW/Security.framework"; mkdir -p "$H"
  python3 -I "$HELPERS/security_headers.py" "$SRC/Security/header_symlinks" "$H"
  # SecProtocolOptions.h and SecProtocolMetadata.h include each other before they declare
  # their type, so clang reports an error in C if SecProtocolMetadata.h comes first: the
  # scan names SecProtocolOptions.h first.
  local sec_headers=""
  for h in "$H"/*.h; do
    h=${h##*/}; [ "$h" = SecProtocolOptions.h ] || sec_headers="$sec_headers $h"
  done
  # shellcheck disable=SC2086
  fw_tbd Security SecProtocolOptions.h $sec_headers

  echo "SystemConfiguration"
  H=$FW/SystemConfiguration.framework/Headers; rm -rf "$FW/SystemConfiguration.framework"; mkdir -p "$H"
  for h in CaptiveNetwork DHCPClientPreferences SCDynamicStore SCDynamicStoreCopyDHCPInfo SCDynamicStoreCopySpecific \
           SCDynamicStoreKey SCNetwork SCNetworkConfiguration SCNetworkConnection SCNetworkReachability SCPreferences \
           SCPreferencesPath SCPreferencesSetSpecific SCSchemaDefinitions SystemConfiguration; do
    cp "$SRC/configd/SystemConfiguration.fproj/$h.h" "$H/"
  done
  # shellcheck disable=SC2046
  fw_tbd SystemConfiguration $(cd "$H" && ls *.h | tr '\n' ' ')

  # A placeholder without headers and symbols: it lets `-framework Foundation`
  # link (Clang adds it for -fobjc-arc, and build systems pass it without
  # using Foundation).  The install name is the one that dyld's sources
  # name; the versions are the lowest possible ones (data/libraries.txt).  The
  # program loads the system's Foundation at run time.
  echo "Foundation"
  fw_placeholder Foundation

  # The same for CoreServices: autoconf and CMake builds of curl link
  # `-framework CoreServices` on every macOS target, and no program of the
  # projects of this SDK needs a symbol of it.  Install name: the layout that
  # the CF and Security sources use for the frameworks inside it
  # (data/libraries.txt).
  echo "CoreServices"
  fw_placeholder CoreServices
}
