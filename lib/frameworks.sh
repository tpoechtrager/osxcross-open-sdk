#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Frameworks (not with --core).
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# Frameworks (not with --core): CoreFoundation, IOKit, DiskArbitration,
# Security, SystemConfiguration: headers from the open source releases and a
# <Name>.tbd in the framework directory (Name.framework/Name.tbd); CoreServices:
# own headers (File System Events only); Foundation: only the .tbd
# (fw_placeholder).
# ---------------------------------------------------------------------------
# fw_tbd NAME HEADER... (a framework of data/libraries.txt; headers relative to Headers/):
# the symbols that HEADERs declare, without those of data/symbols/NAME-exclude.txt, and
# with those of data/symbols/NAME-extra.txt
fw_tbd() {
  local name=$1; shift
  local args="" h; for h in "$@"; do args="$args $name/$h"; done
  # shellcheck disable=SC2086
  header_syms "$STAGE_WORK/fw-$name.syms" "-F$STAGE_FW" $args
  if [ -f "$DATA/symbols/$name-exclude.txt" ]; then
    symbol_list "$DATA/symbols/$name-exclude.txt" > "$STAGE_WORK/fw-$name.exclude"
    awk 'NR == FNR { x[$1] = 1; next } !($2 in x)' "$STAGE_WORK/fw-$name.exclude" "$STAGE_WORK/fw-$name.syms" \
      > "$STAGE_WORK/fw-$name.syms.new"
    mv "$STAGE_WORK/fw-$name.syms.new" "$STAGE_WORK/fw-$name.syms"
  fi
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

# iokit_families HEADERS: the headers of the IOKit device families storage, hid,
# hidsystem, graphics, i2c and ndrvsupport (the modules of these names in
# IOKitUser's Modules/IOKit.modulemap, without storage/ata) in HEADERS/<dir>.
# Each list is the one that the project's Xcode project copies to
# IOKit.framework/Versions/A/Headers/<dir> (its PBXCopyFilesBuildPhase); the
# storage families run `unifdef -UKERNEL` on their headers after the copy (a
# shell script phase of the same projects), and so does this step.  Sets
# IOKIT_FAMILY_SCAN to these headers (for the symbol scan of IOKit.tbd).
# storage/IOFireWireStorageCharacteristics.h of the module map belongs to
# IOFireWireSerialBusProtocolTransport and is not installed here.
iokit_families() {
  local H=$1 h
  mkdir -p "$H/storage" "$H/hid" "$H/hidsystem" "$H/graphics" "$H/i2c" "$H/ndrvsupport"
  for h in IOAppleLabelScheme IOApplePartitionScheme IOBlockStorageDevice IOBlockStorageDriver \
           IOFDiskPartitionScheme IOFilterScheme IOGUIDPartitionScheme IOMedia IOMediaBSDClient \
           IOPartitionScheme IOStorage IOStorageCardCharacteristics IOStorageControllerCharacteristics \
           IOStorageDeviceCharacteristics IOStorageProtocolCharacteristics; do
    run_unifdef -UKERNEL -o "$H/storage/$h.h" "$SRC/IOStorageFamily/$h.h"
  done
  for h in IOCDBlockStorageDevice IOCDMedia IOCDMediaBSDClient IOCDPartitionScheme IOCDTypes; do
    run_unifdef -UKERNEL -o "$H/storage/$h.h" "$SRC/IOCDStorageFamily/$h.h"
  done
  for h in IODVDBlockStorageDevice IODVDMedia IODVDMediaBSDClient IODVDTypes; do
    run_unifdef -UKERNEL -o "$H/storage/$h.h" "$SRC/IODVDStorageFamily/$h.h"
  done
  for h in IOBDBlockStorageDevice IOBDMedia IOBDMediaBSDClient IOBDTypes; do
    run_unifdef -UKERNEL -o "$H/storage/$h.h" "$SRC/IOBDStorageFamily/$h.h"
  done
  # IOHIDFamily: the phases "Copy IOKit HID" and "Copy IOKit HIDSystem" of the target InstallHeaders
  cp "$SRC"/IOHIDFamily/IOHIDFamily/{IOHIDDeviceKeys,IOHIDDeviceTypes,IOHIDEventServiceKeys,IOHIDEventServiceTypes,IOHIDKeys,IOHIDProperties,IOHIDUsageTables}.h \
     "$SRC/IOHIDFamily/IOHIDLib/IOHIDLibObsolete.h" "$H/hid/"
  cp "$SRC"/IOHIDFamily/IOHIDSystem/IOKit/hidsystem/{IOHIDParameter,IOHIDShared,IOHIDTypes,IOLLEvent,ev_keymap}.h "$H/hidsystem/"
  # IOKitUser: the phases "Copy HID Headers", "Copy HIDSystem Headers" and "Copy Files B" of the target IOKit
  cp "$SRC"/IOKitUser/hid.subproj/{IOHIDBase,IOHIDDevice,IOHIDDevicePlugIn,IOHIDElement,IOHIDLib,IOHIDManager,IOHIDQueue,IOHIDTransaction,IOHIDValue}.h "$H/hid/"
  cp "$SRC"/IOKitUser/hidsystem.subproj/{IOHIDEventSystemClient,IOHIDLib,IOHIDServiceClient,IOHIDUserDevice,event_status_driver}.h "$H/hidsystem/"
  cp "$SRC/IOKitUser/graphics.subproj/IOGraphicsLib.h" "$H/graphics/"
  # IOGraphics: the copy phases of the targets IOGraphics Headers and IONDRVSupport Headers
  cp "$SRC"/IOGraphics/IOGraphicsFamily/IOKit/graphics/{IOAccelClientConnect,IOAccelSurfaceConnect,IOAccelTypes,IOFramebufferShared,IOGraphicsEngine,IOGraphicsInterface,IOGraphicsInterfaceTypes,IOGraphicsTypes}.h "$H/graphics/"
  cp "$SRC/IOGraphics/IOGraphicsFamily/IOKit/i2c/IOI2CInterface.h" "$H/i2c/"
  cp "$SRC"/IOGraphics/IONDRVSupport/IOKit/ndrvsupport/{IOMacOSTypes,IOMacOSVideo}.h "$H/ndrvsupport/"
  IOKIT_FAMILY_SCAN=$(cd "$H" && ls storage/*.h hid/*.h hidsystem/*.h graphics/*.h i2c/*.h ndrvsupport/*.h | tr '\n' ' ')
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
  iokit_families "$H"
  # iokitmig.h (a MIG interface) includes iokitmig_c.h, which MIG makes while IOKit is built
  # and which is not in the sources: it is copied above but not scanned for symbols.
  # The functions that the headers of the device families declare are defined in
  # IOKitUser (hid.subproj, hidsystem.subproj, graphics.subproj), but for those of
  # data/symbols/IOKit-exclude.txt.
  # shellcheck disable=SC2086
  fw_tbd IOKit IOKitLib.h IOCFBundle.h IOCFPlugIn.h IOCFSerialize.h IOCFURLAccess.h IOCFUnserialize.h \
    IODataQueueClient.h ps/IOPowerSources.h ps/IOPSKeys.h pwr_mgt/IOPMLib.h pwr_mgt/IOPMKeys.h \
    $IOKIT_FAMILY_SCAN

  echo "DiskArbitration"
  H=$STAGE_FW/DiskArbitration.framework/Headers; rm -rf "$STAGE_FW/DiskArbitration.framework"; mkdir -p "$H"
  cp "$SRC"/DiskArbitration/DiskArbitration/{DADisk,DADissenter,DASession,DiskArbitration}.h "$H/"
  fw_tbd DiskArbitration DADisk.h DADissenter.h DASession.h DiskArbitration.h

  echo "Security"
  # Security's oids.h includes libDER/DERItem.h, which includes libDER_config.h; xnu
  # has both in EXTERNAL_HEADERS/libDER (APSL 2.0), unchanged here.  The rest of libDER is not
  # installed.  SecCode.h includes xpc/xpc.h, which the step stubs installs (stubs_xpc).
  # The own files of the full SDK (data/own-files.txt): xpc/xpc.h, the
  # module map of CoreFoundation and the headers of CoreServices.
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

  # CoreServices: only File System Events, with the own headers installed
  # above (CoreServices.h includes only FSEvents.h); CoreServices has no open
  # source.
  # data/symbols/CoreServices-fsevents.txt gives the source of every symbol,
  # and the declarations of FSEvents.h must be exactly the names of the list.
  # Install name: the layout that the CF and Security sources use for the
  # frameworks inside it (data/libraries.txt).  The stub re-exports
  # CoreFoundation, so that a program that links only CoreServices (git, fswatch,
  # Go fsevents; docs/SOURCES.md) also finds the CF functions.
  echo "CoreServices"
  header_syms "$STAGE_WORK/fw-CoreServices.all" "-F$STAGE_FW" CoreServices/CoreServices.h CoreServices/FSEvents.h
  syms_for_archs "$DATA/symbols/CoreServices-fsevents.txt" | sort > "$STAGE_WORK/fw-CoreServices.syms"
  sort "$STAGE_WORK/fw-CoreServices.all" | cmp -s - "$STAGE_WORK/fw-CoreServices.syms" ||
    die "the declarations of CoreServices/FSEvents.h and data/symbols/CoreServices-fsevents.txt differ (see $STAGE_WORK/fw-CoreServices.all)"
  mk_lib_tbd CoreServices "$STAGE_FW/CoreServices.framework/CoreServices.tbd" "$STAGE_WORK/fw-CoreServices.syms" \
    --reexport-library "$(lib_field CoreFoundation 2)"
  # The linker (ld64, ld64.lld) finds a re-exported library by its install name below the SDK's
  # root plus ".tbd" (.../CoreFoundation.framework/Versions/A/CoreFoundation.tbd)
  mkdir -p "$STAGE_FW/CoreFoundation.framework/Versions/A"
  ln -sf ../../CoreFoundation.tbd "$STAGE_FW/CoreFoundation.framework/Versions/A/CoreFoundation.tbd"
}
