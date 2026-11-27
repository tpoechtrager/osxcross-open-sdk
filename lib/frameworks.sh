#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Frameworks (not with --core).
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# Frameworks (not with --core): CoreFoundation, IOKit, DiskArbitration,
# Security, SystemConfiguration: headers from the open source releases and a
# <Name>.tbd in the framework directory (Name.framework/Name.tbd); CoreServices:
# own headers (File System Events only) and the symbols of Apple's documentation;
# Foundation, CoreGraphics, AppKit, CoreText, CoreVideo, QuartzCore, Metal, CoreAudio,
# AudioToolbox, ApplicationServices, Carbon, WebKit, UniformTypeIdentifiers,
# OpenDirectory, AVFoundation, CoreMedia: only the .tbd, with the symbols of Apple's documentation (fw_doc).
# ---------------------------------------------------------------------------
# fw_tbd NAME HEADER... (a framework of data/libraries.txt; headers relative to Headers/):
# the symbols that HEADERs declare, without those of data/symbols/NAME-exclude.txt, and
# with those of data/symbols/NAME-extra.txt and, if there is a list, those of data/symbols/doc/NAME.txt
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
  if [ -f "$DATA/symbols/doc/$name.txt" ]; then
    # the symbols of the documentation that no header names (tools/doc_symbols.py --headers)
    doc_symbols "$DATA/symbols/doc/$name.txt" > "$STAGE_WORK/fw-$name.doclist" ||
      die "data/symbols/doc/$name.txt has bad lines"
    syms_for_archs "$STAGE_WORK/fw-$name.doclist" >> "$STAGE_WORK/fw-$name.syms"
  fi
  mk_lib_tbd "$name" "$STAGE_FW/$name.framework/$name.tbd" "$STAGE_WORK/fw-$name.syms"
}

# fw_doc NAME [MK_TBD-OPTION...]: a framework without open source and without headers,
# only the .tbd (a framework of data/libraries.txt), a link stub for programs that
# declare what they use themselves: the symbols of data/symbols/doc/NAME.txt (made
# by tools/doc_symbols.py from Apple's documentation; none for Carbon) that came with
# macOS SDK_VERSION or earlier, and those of data/symbols/NAME-extra.txt
fw_doc() {
  local name=$1; shift
  rm -rf "$STAGE_FW/$name.framework"; mkdir -p "$STAGE_FW/$name.framework"
  : > "$STAGE_WORK/fw-$name.list"
  if [ -f "$DATA/symbols/doc/$name.txt" ]; then
    doc_symbols "$DATA/symbols/doc/$name.txt" > "$STAGE_WORK/fw-$name.list" ||
      die "data/symbols/doc/$name.txt has bad lines"
  fi
  if [ -f "$DATA/symbols/$name-extra.txt" ]; then
    symbol_list "$DATA/symbols/$name-extra.txt" >> "$STAGE_WORK/fw-$name.list"
  fi
  require_lines "$STAGE_WORK/fw-$name.list" 1 "no symbols for $name"
  syms_for_archs "$STAGE_WORK/fw-$name.list" > "$STAGE_WORK/fw-$name.syms"
  mk_lib_tbd "$name" "$STAGE_FW/$name.framework/$name.tbd" "$STAGE_WORK/fw-$name.syms" ${1+"$@"}
}

# iokit_families HEADERS: the headers of the IOKit device families storage, hid,
# hidsystem, graphics, i2c, ndrvsupport and usb (the modules of these names in
# IOKitUser's Modules/IOKit.modulemap, without storage/ata) in HEADERS/<dir>.
# Each list is the one that the project's Xcode project copies to
# IOKit.framework/Versions/A/Headers/<dir> (its PBXCopyFilesBuildPhase); the
# storage families run `unifdef -UKERNEL` on their headers after the copy (a
# shell script phase of the same projects), and so does this step.  Sets
# IOKIT_FAMILY_SCAN to these headers (for the symbol scan of IOKit.tbd).
# storage/IOFireWireStorageCharacteristics.h of the module map belongs to
# IOFireWireSerialBusProtocolTransport and is not installed here.
# usb: the four headers that IOUSBFamily's CopyFiles phase installs in
# IOKit.framework/Headers/usb (the other headers go to Kernel.framework); they are
# copied as they are: their kernel parts are under #if KERNEL.
iokit_families() {
  local H=$1 h
  mkdir -p "$H/storage" "$H/hid" "$H/hidsystem" "$H/graphics" "$H/i2c" "$H/ndrvsupport" "$H/usb"
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
  # hidsystem/IOHIDEventSystemClient.h and IOHIDServiceClient.h are not installed: IOKitUser builds their functions
  # from hid.subproj/IOHIDEventSystemClient.c and IOHIDServiceClient.c, which are empty in the open source releases
  cp "$SRC"/IOKitUser/hidsystem.subproj/{IOHIDLib,IOHIDUserDevice,event_status_driver}.h "$H/hidsystem/"
  cp "$SRC/IOKitUser/graphics.subproj/IOGraphicsLib.h" "$H/graphics/"
  # IOGraphics: the copy phases of the targets IOGraphics Headers and IONDRVSupport Headers
  cp "$SRC"/IOGraphics/IOGraphicsFamily/IOKit/graphics/{IOAccelClientConnect,IOAccelSurfaceConnect,IOAccelTypes,IOFramebufferShared,IOGraphicsEngine,IOGraphicsInterface,IOGraphicsInterfaceTypes,IOGraphicsTypes}.h "$H/graphics/"
  cp "$SRC/IOGraphics/IOGraphicsFamily/IOKit/i2c/IOI2CInterface.h" "$H/i2c/"
  cp "$SRC"/IOGraphics/IONDRVSupport/IOKit/ndrvsupport/{IOMacOSTypes,IOMacOSVideo}.h "$H/ndrvsupport/"
  # IOUSBFamily: the phase "CopyFiles" of the target that has the destination IOKit.framework/Versions/A/Headers/usb
  cp "$SRC"/IOUSBFamily/IOUSBFamily/Headers/{USB,USBSpec,IOUSBLib}.h "$SRC/IOUSBFamily/IOUSBUserClient/Headers/IOUSBUserClient.h" "$H/usb/"
  # constants of the speeds and the re-enumerate options that the open headers lack (libusb uses them)
  cat "$DATA/USBCompat.h.in" >> "$H/usb/USB.h"
  add_notice "$H/usb/USB.h" "constants of the device speeds and of USBReEnumerateOptions added at the end"
  IOKIT_FAMILY_SCAN=$(cd "$H" && ls storage/*.h hid/*.h hidsystem/*.h graphics/*.h i2c/*.h ndrvsupport/*.h usb/*.h | tr '\n' ' ')
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
  # declarations that CF-1153.18 lacks, from swift-corelibs-foundation (data/CF/): two headers
  # and an additions.patch to others (the notices name what each file got)
  cp "$DATA/CF/CFNotificationCenter.h" "$DATA/CF/CFAttributedString.h" "$H/"
  python3 -I "$HELPERS/apply_diff.py" "$H" "$DATA/CF/additions.patch" || die "data/CF/additions.patch does not apply"
  # the typed string aliases, nullability and typed enumerations (a second patch, made against the result
  # of the first, so that each can be updated alone)
  python3 -I "$HELPERS/apply_diff.py" "$H" "$DATA/CF/typed.patch" || die "data/CF/typed.patch does not apply"
  perl -pi -e 's|^(#include <CoreFoundation/CFBase.h>)|$1\n#include <CoreFoundation/CFMachPort.h>\n#include <CoreFoundation/CFAttributedString.h>\n#include <CoreFoundation/CFNotificationCenter.h>|' "$H/CoreFoundation.h"
  cat "$DATA/CFCompat.h.in" >> "$H/CFAvailability.h"
  add_notice "$H/CFAvailability.h" "annotation macros for the headers of other frameworks added at the end"
  add_notice "$H/CoreFoundation.h" "includes of CFMachPort.h, CFAttributedString.h and CFNotificationCenter.h added"
  # swift-corelibs-foundation swift-6.4.3-RELEASE (8ddfb630bbb581f71fba5960a821dbbd9215a70e), Sources/CoreFoundation/include
  local cfn="from swift-corelibs-foundation swift-6.4.3-RELEASE, Apache 2.0 with Runtime Library Exception"
  add_notice "$H/CFNotificationCenter.h" "$cfn; includes as in a framework, the distributed center for macOS only"
  add_notice "$H/CFAttributedString.h" "$cfn; includes as in a framework"
  add_notice "$H/CFBase.h" "version numbers of 10.10 and 10.11 added ($cfn)"
  add_notice "$H/CFBundle.h" "CFBundleIsExecutableLoadable, CFBundleIsExecutableLoadableForURL, CFBundleIsArchitectureLoadable and kCFBundleExecutableArchitectureARM64 added ($cfn)"
  add_notice "$H/CFDateFormatter.h" "CFISO8601DateFormatOptions and CFDateFormatterCreateISO8601Formatter added ($cfn)"
  add_notice "$H/CFError.h" "kCFErrorLocalizedFailureKey added ($cfn)"
  add_notice "$H/CFNumberFormatter.h" "the styles of 10.11 added ($cfn)"
  add_notice "$H/CFURL.h" "the resource keys and bookmark options of 10.7 to 11.3 added ($cfn)"
  add_notice "$H/CFUserNotification.h" "kCFUserNotificationAlertTopMostKey and kCFUserNotificationKeyboardTypesKey declared for macOS ($cfn)"
  local typed="typed declarations as in swift-corelibs-foundation swift-6.4.3-RELEASE (Apache 2.0 with Runtime Library Exception)"
  add_notice "$H/CFCalendar.h" "CFCalendarIdentifier used, kCFCalendarComponentsWrap typed ($typed)"
  add_notice "$H/CFDateFormatter.h" "CFDateFormatterKey added and used ($typed)"
  add_notice "$H/CFError.h" "CFErrorDomain added and used ($typed)"
  add_notice "$H/CFLocale.h" "CFLocaleIdentifier, CFLocaleKey and CFCalendarIdentifier added and used ($typed)"
  add_notice "$H/CFMessagePort.h" "the result codes typed ($typed)"
  add_notice "$H/CFNumberFormatter.h" "CFNumberFormatterKey added and used ($typed)"
  add_notice "$H/CFPreferences.h" "nullability added ($typed)"
  add_notice "$H/CFPropertyList.h" "the read error codes typed ($typed)"
  add_notice "$H/CFRunLoop.h" "CFRunLoopMode and CFRunLoopRunResult added and used ($typed)"
  add_notice "$H/CFSocket.h" "the socket flags typed ($typed)"
  add_notice "$H/CFStream.h" "CFStreamPropertyKey added and used, nullability added ($typed)"
  add_notice "$H/CFTimeZone.h" "CFNotificationName used ($typed)"
  add_notice "$H/CFUserNotification.h" "the alert levels, responses and button flags typed ($typed)"
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
  # IOKitUser (hid.subproj, hidsystem.subproj, graphics.subproj).
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
  fw_layout CoreServices   # its headers are in Versions/A: the scan below finds them through the link Headers
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

  # Foundation, CoreGraphics, AppKit, CoreText, CoreVideo, QuartzCore, Metal, CoreAudio,
  # AudioToolbox, ApplicationServices, Carbon, WebKit, UniformTypeIdentifiers,
  # OpenDirectory, AVFoundation, CoreMedia: link stubs without headers (fw_doc).  Foundation
  # also lets `-framework Foundation` link (Clang adds it for -fobjc-arc, and build systems
  # pass it without using Foundation).  A program loads the system's frameworks at run time.
  local fw
  for fw in Foundation CoreGraphics AppKit CoreText CoreVideo QuartzCore Metal CoreAudio AudioToolbox ApplicationServices \
    Carbon WebKit UniformTypeIdentifiers OpenDirectory AVFoundation CoreMedia; do
    echo "$fw"
    fw_doc "$fw"
  done

  # OpenGL: headers made from the OpenGL Registry's gl.xml and the CGL lists of data/opengl/
  # (helpers/write_opengl_headers.py), and the link stub with the exports of
  # helpers/opengl_syms.py (docs/SOURCES.md, "OpenGL.framework")
  echo "OpenGL"
  FETCH_QUIET=1 fetch_opengl_registry
  rm -rf "$STAGE_FW/OpenGL.framework"; mkdir -p "$STAGE_FW/OpenGL.framework"
  python3 -I "$HELPERS/write_opengl_headers.py" "$SRC/OpenGL-Registry/gl.xml" "$DATA/opengl" \
    "$STAGE_FW/OpenGL.framework/Headers" "$NOTICE_DATE"
  python3 -I "$HELPERS/opengl_syms.py" "$SRC/OpenGL-Registry/gl.xml" "$DATA/opengl" "$STAGE_WORK/fw-OpenGL.list"
  require_lines "$STAGE_WORK/fw-OpenGL.list" 900 "OpenGL has too few exports"
  syms_for_archs "$STAGE_WORK/fw-OpenGL.list" > "$STAGE_WORK/fw-OpenGL.syms"
  mk_lib_tbd OpenGL "$STAGE_FW/OpenGL.framework/OpenGL.tbd" "$STAGE_WORK/fw-OpenGL.syms"

  # CoreServices: only File System Events, with the own headers installed
  # above (CoreServices.h includes only FSEvents.h); CoreServices has no open
  # source.  The stub also has the symbols of Apple's documentation.
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
  # The stub also has the symbols of Apple's documentation (data/symbols/doc/CoreServices.txt,
  # like fw_doc), without headers; those of FSEvents are in both lists.
  doc_symbols "$DATA/symbols/doc/CoreServices.txt" > "$STAGE_WORK/fw-CoreServices.doc" ||
    die "data/symbols/doc/CoreServices.txt has bad lines"
  syms_for_archs "$STAGE_WORK/fw-CoreServices.doc" >> "$STAGE_WORK/fw-CoreServices.syms"
  sort -u "$STAGE_WORK/fw-CoreServices.syms" > "$STAGE_WORK/fw-CoreServices.syms.new"
  mv "$STAGE_WORK/fw-CoreServices.syms.new" "$STAGE_WORK/fw-CoreServices.syms"
  mk_lib_tbd CoreServices "$STAGE_FW/CoreServices.framework/CoreServices.tbd" "$STAGE_WORK/fw-CoreServices.syms" \
    --reexport-library "$(lib_field CoreFoundation 2)"

  # Cocoa: the umbrella framework.  Apple's documentation says that it imports AppKit, Foundation
  # and Core Data; the SDK has no Core Data, so the stub re-exports the other two (docs/SOURCES.md).
  # Only the .tbd, no headers: an umbrella of the sort that data/libraries.txt lists.
  echo "Cocoa"
  rm -rf "$STAGE_FW/Cocoa.framework"; mkdir -p "$STAGE_FW/Cocoa.framework"
  : > "$STAGE_WORK/fw-Cocoa.syms"
  mk_lib_tbd Cocoa "$STAGE_FW/Cocoa.framework/Cocoa.tbd" "$STAGE_WORK/fw-Cocoa.syms" \
    --reexport-library "$(lib_field AppKit 2)" --reexport-library "$(lib_field Foundation 2)"

  fw_layout
}

# fw_layout: the layout of a framework bundle (Apple's "Anatomy of Framework Bundles"): the files
# are in Versions/V (V is the version in the install name of data/libraries.txt), Versions/Current
# is a link to V, and the top level has links to Versions/Current/NAME.tbd, Headers and Modules.
# The linker (ld64, ld64.lld) finds a re-exported library at its install name below the SDK's root
# plus ".tbd" (.../CoreServices.framework/Versions/A/CoreServices.tbd), so the install name of every
# .tbd must be the path of the file (tests/sdk-check.sh checks it).
# fw_layout [NAME...]: the frameworks given (all of the stage without arguments); safe to repeat.
fw_layout() {
  local d name inst v e
  local fws="$*"
  [ $# -gt 0 ] || fws=$(cd "$STAGE_FW" && ls -d ./*.framework | sed 's#^\./##; s#\.framework$##')
  for name in $fws; do
    d=$STAGE_FW/$name.framework
    inst=$(lib_field "$name" 2)
    case $inst in
      /System/Library/Frameworks/"$name".framework/Versions/*/"$name") v=${inst#*/Versions/}; v=${v%%/*};;
      *) die "the install name of $name is not that of a framework: $inst";;
    esac
    mkdir -p "$d/Versions/$v"
    for e in "$name.tbd" Headers Modules Resources; do
      if [ -e "$d/$e" ] && [ ! -L "$d/$e" ]; then
        [ ! -e "$d/Versions/$v/$e" ] || die "$d/$e is also in Versions/$v"
        mv "$d/$e" "$d/Versions/$v/$e"
      fi
    done
    ln -sfn "$v" "$d/Versions/Current"
    for e in "$name.tbd" Headers Modules Resources; do
      [ ! -e "$d/Versions/$v/$e" ] || ln -sfn "Versions/Current/$e" "$d/$e"
    done
  done
}
