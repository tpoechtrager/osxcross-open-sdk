#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""check_libraries.py SRC

Checks the values of data/libraries.txt against the sources of the projects:
SRC is the directory with the clones (build/src).  For every library it looks
for the lines of the project that define install name and versions, and prints
what it does not find.  Maintenance tool, run it for a new macOS release; a
difference is not always an error (an older release can have older values),
but every difference should be understood.
"""
import argparse
import os
import re
import sys

# name: [(file below SRC, regular expression that must match a line)]
CHECKS = {
    "libSystem.B": [("Libsystem/Libsystem.xcconfig", r"^INSTALL_PATH = \$\(SDK_INSTALL_ROOT\)/usr/lib"),
                    ("Libsystem/Libsystem.xcconfig", r"^DYLIB_NAME_VERSION_SUFFIX = \.B")],
    "libresolv.9": [("libresolv/xcodescripts/libresolv.xcconfig", r"^INSTALL_PATH = /usr/lib"),
                    ("libresolv/xcodescripts/libresolv.xcconfig", r"^FRAMEWORK_VERSION = 9"),
                    ("libresolv/xcodescripts/links.sh", r"ln -s libresolv\.9\.tbd")],
    "libiconv.2": [("libiconv/libiconv.xcodeproj/project.pbxproj", r"DYLIB_CURRENT_VERSION = 7;"),
                   ("libiconv/libiconv.xcodeproj/project.pbxproj", r"PRODUCT_NAME = iconv\.2;")],
    "libc++.1": [("llvm-project/libcxx/test/libcxx/vendor/apple/system-install-properties.sh.cpp", r"/usr/lib/libc\+\+\.1\.dylib"),
                 ("llvm-project/libcxx/test/libcxx/vendor/apple/system-install-properties.sh.cpp", r"compatibility version 1\.0\.0")],
    "libc++abi": [("llvm-project/libcxxabi/test/vendor/apple/system-install-properties.sh.cpp", r"compatibility version 1\.0\.0")],
    "libz.1": [("zlib/zlib.xcconfig", r"^DYLIB_CURRENT_VERSION = 1\.2\.12"), ("zlib/zlib.xcconfig", r"^DYLIB_COMPATIBILITY_VERSION = 1$")],
    "libbz2.1.0": [("bzip2/xcodeconfig/libs.xcconfig", r"^DYLIB_CURRENT_VERSION = 1\.0\.8")],
    "libexpat.1": [("expat/expat.xcodeproj/project.pbxproj", r"DYLIB_COMPATIBILITY_VERSION = 7;"),
                   ("expat/expat.xcodeproj/project.pbxproj", r"DYLIB_CURRENT_VERSION = 8;")],
    "libffi": [("libffi/libffi.xcodeproj/project.pbxproj", r"DYLIB_COMPATIBILITY_VERSION = 1;"),
               ("libffi/libffi.xcodeproj/project.pbxproj", r"PRODUCT_NAME = ffi;")],
    "libedit.3": [("libedit/xcodescripts/libedit.xcconfig", r"^DYLIB_COMPATIBILITY_VERSION = 2"),
                  ("libedit/xcodescripts/libedit.xcconfig", r"^DYLIB_CURRENT_VERSION = 3\.0"),
                  ("libedit/xcodescripts/libedit.xcconfig", r"^PRODUCT_NAME = edit\.3")],
    "libxml2.2": [("libxml2/Configurations/libxml2.xcconfig", r"^PRODUCT_NAME = libxml2\.2"),
                  ("libxml2/Configurations/libxml2.xcconfig", r"^DYLIB_COMPATIBILITY_VERSION = 10\.0\.0"),
                  ("libxml2/Configurations/libxml2.xcconfig", r"^DYLIB_CURRENT_VERSION = 10\.9\.0")],
    "libobjc.A": [("objc4/objc.xcodeproj/project.pbxproj", r"DYLIB_CURRENT_VERSION = 228;"),
                  ("objc4/objc.xcodeproj/project.pbxproj", r"PRODUCT_NAME = objc\.A;")],
    "libutil": [("libutil/libutil.xcodeproj/project.pbxproj", r"DYLIB_COMPATIBILITY_VERSION = 1\.0;"),
                ("libutil/libutil.xcodeproj/project.pbxproj", r"DYLIB_CURRENT_VERSION = 1\.0;")],
    "libpcap.A": [("libpcap/Makefile", r"-compatibility_version 1 -current_version 1 .*-install_name /usr/lib/libpcap\.A\.dylib")],
    "libarchive.2": [("libarchive/xcodeconfig/libs.xcconfig", r"^DYLIB_COMPATIBILITY_VERSION = 9"),
                     ("libarchive/xcodeconfig/libs.xcconfig", r"^DYLIB_CURRENT_VERSION = 9\.2"),
                     ("libarchive/libarchive.xcodeproj/project.pbxproj", r"path = libarchive\.2\.dylib;")],
    "libpam.2": [("OpenPAM/openpam.xcodeproj/project.pbxproj", r"DYLIB_COMPATIBILITY_VERSION = 3\.0\.0;"),
                 ("OpenPAM/openpam.xcodeproj/project.pbxproj", r"PRODUCT_NAME = pam\.2;")],
    "libxslt.1": [("libxslt/Configurations/libxslt.xcconfig", r"^PRODUCT_NAME = libxslt\.1"),
                  ("libxslt/Configurations/libxslt.xcconfig", r"^DYLIB_COMPATIBILITY_VERSION = 3\.0\.0"),
                  ("libxslt/Configurations/libxslt.xcconfig", r"^DYLIB_CURRENT_VERSION = 3\.26\.0")],
    "libexslt.0": [("libxslt/Configurations/libexslt.xcconfig", r"^PRODUCT_NAME = libexslt\.0"),
                   ("libxslt/Configurations/libexslt.xcconfig", r"^DYLIB_COMPATIBILITY_VERSION = 9\.0\.0"),
                   ("libxslt/Configurations/libexslt.xcconfig", r"^DYLIB_CURRENT_VERSION = 9\.15\.0")],
    "libcurl.4": [("curl/xcconfigs/libcurl-version.xcconfig", r"^CURL_LIBRARY_VERSION = 4"),
                  ("curl/xcconfigs/libcurl-version.xcconfig", r"^DYLIB_COMPATIBILITY_VERSION = 7"),
                  ("curl/xcconfigs/libcurl-version.xcconfig", r"^DYLIB_CURRENT_VERSION = 9")],
    "libncurses.5.4": [("ncurses/ncurses/panel/Makefile", r"-compatibility_version \$\{ABI_VERSION\} -current_version \$\{ABI_VERSION\}"),
                       ("ncurses/ncurses/panel/Makefile", r"^ABI_VERSION\s*=\s*5\.4")],
    "liblzma.5": [("xz/src/liblzma/Makefile.am", r"-version-info 5:8:0$"),
                  ("libarchive/libarchive.xcodeproj/project.pbxproj", r"liblzma\.tbd in Frameworks")],
    "CoreFoundation": [("CF/Makefile", r"-compatibility_version 150 ")],
    "DiskArbitration": [("DiskArbitration/DiskArbitration.xcodeproj/project.pbxproj", r"DYLIB_COMPATIBILITY_VERSION = 1;"),
                        ("Security/OSX/libsecurity_translocate/lib/SecTranslocateDANotification.cpp", r"DiskArbitration\.framework/Versions/A/DiskArbitration")],
    "SystemConfiguration": [("configd/configd.xcodeproj/project.pbxproj", r"DYLIB_COMPATIBILITY_VERSION = 1;"),
                            ("configd/configd.xcodeproj/project.pbxproj", r"INSTALL_PATH = \"?\$\(SYSTEM_LIBRARY_DIR\)/Frameworks\"?;")],
    "IOKit": [("IOKitUser/IOKitUser.xcodeproj/project.pbxproj", r"DYLIB_CURRENT_VERSION = 275\.0\.0;"),
              ("IOKitUser/IOKitUser.xcodeproj/project.pbxproj", r"DYLIB_COMPATIBILITY_VERSION = 1\.0\.0;")],
    "Security": [("Security/OSX/config/security_framework_macos.xcconfig", r"^FRAMEWORK_VERSION = A"),
                 ("Security/OSX/config/security_framework_macos.xcconfig", r"^DYLIB_COMPATIBILITY_VERSION = 1")],
    "Foundation": [("dyld/cache_builder/NewSharedCacheBuilder.cpp", r"Foundation\.framework/Versions/C/Foundation")],
    "CoreServices": [("CF/CFUtilities.c", r"/System/Library/Frameworks/CoreServices\.framework/Versions/A/Frameworks/"),
                     ("Security/OSX/libsecurity_translocate/lib/SecTranslocateLSNotification.cpp",
                      r"/System/Library/Frameworks/CoreServices\.framework/Versions/A/Frameworks/")],
}


def main(argv):
    p = argparse.ArgumentParser(prog="check_libraries.py", description="Check data/libraries.txt against the sources.")
    p.add_argument("src", help="the directory with the clones (build/src)")
    src = p.parse_args(argv[1:]).src
    bad = 0
    for name, checks in sorted(CHECKS.items()):
        for rel, rx in checks:
            path = os.path.join(src, rel)
            try:
                with open(path, errors="replace") as f:
                    text = f.read()
            except OSError:
                print("%s: missing file %s" % (name, rel))
                bad += 1
                continue
            if not re.search(rx, text, re.M):
                print("%s: no line /%s/ in %s" % (name, rx, rel))
                bad += 1
    print("%d differences" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
