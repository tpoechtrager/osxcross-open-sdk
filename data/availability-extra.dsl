# SPDX-License-Identifier: GPL-2.0-only
# availability-extra.dsl -- macOS releases after the last one that Apple's
# public AvailabilityVersions tags (AvailabilityVersions-151 and later) list
# (macOS 14.3).  Written for the open SDK; it contains only version numbers,
# which are public facts, and no text or data of any SDK made by Apple.
# The file continues the DSL of AvailabilityVersions (same syntax, see its
# README.md): helpers/avail_dsl.py appends it to the DSL of the
# AvailabilityVersions tag and cuts the result after the macOS version of the
# SDK that is built.  The DSL data and the generator are Apple's (APSL 2.0);
# this file may be used under the same license.
#
# Sources of the numbers
#  * macOS 14.4 ... 15.0 and visionOS 1.1/2.0: the lines of
#    AvailabilityVersions-138.7/availability.dsl (the macOS 14.3 release)
#    that sit behind its "#ifndef __OPENSOURCE__".
#  * The pairing of a macOS release with the iOS, tvOS, watchOS and visionOS
#    releases that shipped with it: Apple's release notes and the public
#    version lists of the operating systems (iOS 18.n and macOS 15.n,
#    watchOS 11.n, tvOS 18.n, visionOS 2.n; the number 26 for all platforms
#    from 2025 on, visionOS 26 included).
#  * DriverKit 23.n/24.n/25.n: the Darwin version of the release (as in the
#    DSL for 14.0 ... 14.3: DriverKit 23.3 with macOS 14.3 and Darwin 23.3).
#  * bridgeOS: no lines.  No public source states bridgeOS numbers for the
#    releases after macOS 14.3, so the bridgeOS versions stay at the ones of
#    the public DSL (up to 8.3); the SDK headers depend on them only through
#    the __BRIDGEOS_* macros.
#  * Darwin versions: the release manifests of distribution-macOS (xnu tags)
#    and the table in OSXCross' build.sh.
#  * macOS 16.0, iOS and tvOS 19.0, watchOS 12.0, visionOS 3.0: the numbers
#    that come before the year-based releases of 2025 (26.0 on all
#    platforms) and that tools still accept for them.  LLVM 21.1.8,
#    llvm/lib/TargetParser/Triple.cpp, Triple::getCanonicalVersionForOS and
#    Triple::getiOSVersion: "macOS 16 is canonicalized to macOS 26", "tvOS 19
#    corresponds to ios26", "visionOS 3 corresponds to ios 26+", "watchOS 12
#    corresponds to ios 26".
# A "set" line (the dyld version sets of Apple's DSL) is not written: the
# numbers are not public, and only private dyld headers use them.
# Every release is one group: the macOS line, then the other platforms.

version     macos               14.4
version     ios                 17.4
version     tvos                17.4
version     watchos             10.4
version     driverkit           23.4
version     visionos            1.1
version     macos               14.5
version     ios                 17.5
version     tvos                17.5
version     watchos             10.5
version     driverkit           23.5
version     visionos            1.2
version     macos               14.6
version     ios                 17.6
version     tvos                17.6
version     watchos             10.6
version     driverkit           23.6
version     visionos            1.3
version     macos               14.7
version     ios                 17.7
version     macos               15.0
version     ios                 18.0
version     tvos                18.0
version     watchos             11.0
version     driverkit           24.0
version     visionos            2.0
version     macos               15.1
version     ios                 18.1
version     tvos                18.1
version     watchos             11.1
version     driverkit           24.1
version     visionos            2.1
version     macos               15.2
version     ios                 18.2
version     tvos                18.2
version     watchos             11.2
version     driverkit           24.2
version     visionos            2.2
version     macos               15.3
version     ios                 18.3
version     tvos                18.3
version     watchos             11.3
version     driverkit           24.3
version     visionos            2.3
version     macos               15.4
version     ios                 18.4
version     tvos                18.4
version     watchos             11.4
version     driverkit           24.4
version     visionos            2.4
version     macos               15.5
version     ios                 18.5
version     tvos                18.5
version     watchos             11.5
version     driverkit           24.5
version     visionos            2.5
version     macos               15.6
version     ios                 18.6
version     tvos                18.6
version     watchos             11.6
version     driverkit           24.6
version     visionos            2.6
version     macos               15.7
version     ios                 18.7
version     macos               16.0
version     ios                 19.0
version     tvos                19.0
version     watchos             12.0
version     visionos            3.0
version     macos               26.0
version     ios                 26.0
version     tvos                26.0
version     watchos             26.0
version     driverkit           25.0
version     visionos            26.0
version     macos               26.1
version     ios                 26.1
version     tvos                26.1
version     watchos             26.1
version     driverkit           25.1
version     visionos            26.1
version     macos               26.2
version     ios                 26.2
version     tvos                26.2
version     watchos             26.2
version     driverkit           25.2
version     visionos            26.2
version     macos               26.3
version     ios                 26.3
version     tvos                26.3
version     watchos             26.3
version     driverkit           25.3
version     visionos            26.3
version     macos               26.4
version     ios                 26.4
version     tvos                26.4
version     watchos             26.4
version     driverkit           25.4
version     visionos            26.4
version     macos               26.5
version     ios                 26.5
version     tvos                26.5
version     watchos             26.5
version     driverkit           25.5
version     visionos            26.5
