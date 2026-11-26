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
  local args="" h; for h in "$@"; do args="$args $name/$h"; done
  # shellcheck disable=SC2086
  header_syms "$STAGE_WORK/fw-$name.syms" "-F$STAGE_FW" $args
  if [ -f "$DATA/symbols/$name-extra.txt" ]; then
    syms_for_archs "$DATA/symbols/$name-extra.txt" >> "$STAGE_WORK/fw-$name.syms"
  fi
  mk_lib_tbd "$name" "$STAGE_FW/$name.framework/$name.tbd" "$STAGE_WORK/fw-$name.syms"
}

# fw_placeholder NAME: a framework without headers and symbols, only the .tbd
# (a framework of data/libraries.txt)
fw_placeholder() {
  rm -rf "$STAGE_FW/$1.framework"; mkdir -p "$STAGE_FW/$1.framework"
  : > "$STAGE_WORK/fw-$1.syms"
  mk_lib_tbd "$1" "$STAGE_FW/$1.framework/$1.tbd" "$STAGE_WORK/fw-$1.syms"
}

step_frameworks() {
  mkdir -p "$STAGE_WORK" "$STAGE_FW"

  log "Frameworks"
  echo "CoreFoundation"
  local H=$STAGE_FW/CoreFoundation.framework/Headers
  rm -rf "$STAGE_FW/CoreFoundation.framework"; mkdir -p "$H"
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
  cat "$DATA/CFCompat.h.in" >> "$H/CFAvailability.h"
  add_notice "$H/CFAvailability.h" "annotation macros for the headers of other frameworks added at the end"
  add_notice "$H/CoreFoundation.h" "include of CFMachPort.h added"
  cp "$SRC/CarbonHeaders/MacTypes.h" "$SRC/CarbonHeaders/ConditionalMacros.h" "$STAGE_INC/"
  local hl; hl=$(cd "$H" && ls *.h | tr '\n' ' ')
  # shellcheck disable=SC2086
  fw_tbd CoreFoundation $hl

  echo "IOKit"
  H=$STAGE_FW/IOKit.framework/Headers; rm -rf "$STAGE_FW/IOKit.framework"; mkdir -p "$H/ps" "$H/pwr_mgt"
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

  echo "DiskArbitration"
  H=$STAGE_FW/DiskArbitration.framework/Headers; rm -rf "$STAGE_FW/DiskArbitration.framework"; mkdir -p "$H"
  cp "$SRC"/DiskArbitration/DiskArbitration/{DADisk,DADissenter,DASession,DiskArbitration}.h "$H/"
  fw_tbd DiskArbitration DADisk.h DADissenter.h DASession.h DiskArbitration.h

  echo "Security"
  # Security's oids.h includes libDER/DERItem.h, which includes libDER_config.h; xnu
  # has both in EXTERNAL_HEADERS/libDER (APSL 2.0), unchanged here.  The rest of libDER is not
  # installed.  xpc/xpc.h is the one typedef that xnu's libkern/os/trace.h also writes
  # (line 36) for SecCode.h; libxpc itself has no open source.
  # The own files of the full SDK (data/own-files.txt): xpc/xpc.h and the
  # module map of CoreFoundation.
  install_own_files full
  # The xnu of macOS 26.5 has them; earlier releases do not, and get the small
  # own DERItem.h (the same types and struct).
  mkdir -p "$STAGE_INC/libDER"
  if [ -f "$SRC/xnu/EXTERNAL_HEADERS/libDER/DERItem.h" ] && [ -f "$SRC/xnu/EXTERNAL_HEADERS/libDER/libDER_config.h" ]; then
    cp "$SRC/xnu/EXTERNAL_HEADERS/libDER/DERItem.h" "$SRC/xnu/EXTERNAL_HEADERS/libDER/libDER_config.h" "$STAGE_INC/libDER/"
  else
    install_own_file usr/include/libDER/DERItem.h
  fi
  H=$STAGE_FW/Security.framework/Headers; rm -rf "$STAGE_FW/Security.framework"; mkdir -p "$H"
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
  H=$STAGE_FW/SystemConfiguration.framework/Headers; rm -rf "$STAGE_FW/SystemConfiguration.framework"; mkdir -p "$H"
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
