#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# SDKSettings, SystemVersion, license files.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# Metadata and licenses (the tarball: lib/tarball.sh)
# ---------------------------------------------------------------------------
step_meta() {
  log "Meta"
  local V=$SDK_VERSION M=$STAGE
  mkdir -p "$M/System/Library/CoreServices" "$M/usr/share/licenses/open-sdk"
  # GCC does not know the platform bridgeos in availability attributes; the
  # public headers of an SDK do not name it either.
  quiet python3 -I "$HELPERS/scrub_platforms.py" "$M/usr/include" "$NOTICE_DATE"   # (it prints a count)
  echo "SystemVersion.plist"
  cat > "$M/System/Library/CoreServices/SystemVersion.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ProductBuildVersion</key>
	<string>${BUILD_VERSION:-}</string>
	<key>ProductName</key>
	<string>macOS</string>
	<key>ProductVersion</key>
	<string>$V</string>
</dict>
</plist>
EOF
  echo "SDKSettings.plist"
  cat > "$M/SDKSettings.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>OpenSDKGeneratorCommit</key>
	<string>$GENERATOR_COMMIT</string>
	<key>Version</key>
	<string>$V</string>
</dict>
</plist>
EOF
  # SDKSettings.json has only the keys that a program reads (docs/SOURCES.md
  # names the reader of every key):
  #   clang, clang/lib/Basic/DarwinSDKInfo.cpp: CanonicalName (the platform
  #   "macosx"), DisplayName, Version, MaximumDeploymentTarget (required),
  #   VersionMap.macOS_iOSMac and .iOSMac_macOS (Mac Catalyst availability),
  #   SupportedTargets.macosx.Archs, .LLVMTargetTripleVendor, .LLVMTargetTripleSys
  #   OSXCross, wrapper/src/target.cpp (readSDKInfo): Version, DisplayName,
  #   CanonicalName, MaximumDeploymentTarget, SupportedTargets.macosx.MinimumDeploymentTarget
  #   (--min-deployment-target, default 11.0: the oldest release of data/manifests/)
  #   OpenSDKGeneratorCommit: no program reads it; the commit of this repository
  #   (with "-modified" if tracked files have changes, or "unknown"), the same key in
  #   SDKSettings.plist, and in OpenSDK.json
  local IOSV
  IOSV=$(python3 -I "$HELPERS/avail_dsl.py" --ios-version "$STAGE/avail-src/availability.dsl" "$V")
  echo "SDKSettings.json"
  cat > "$M/SDKSettings.json" <<EOF
{
  "CanonicalName": "macosx$V",
  "DisplayName": "macOS $V (open source SDK)",
  "Version": "$V",
  "OpenSDKGeneratorCommit": "$GENERATOR_COMMIT",
  "MaximumDeploymentTarget": "$V.99",
  "VersionMap": {
    "macOS_iOSMac": {"10.15": "13.1", "$V": "$IOSV"},
    "iOSMac_macOS": {"13.1": "10.15", "$IOSV": "$V"}
  },
  "SupportedTargets": {
    "macosx": {
      "Archs": ["arm64", "arm64e", "x86_64", "x86_64h"],
      "LLVMTargetTripleSys": "macos",
      "LLVMTargetTripleVendor": "apple",
      "MinimumDeploymentTarget": "$MIN_DEPLOYMENT_TARGET"
    }
  }
}
EOF
  # full license texts of every project that contributes to the SDK
  rm -rf "$M/usr/share/licenses/open-sdk"; mkdir -p "$M/usr/share/licenses/open-sdk"
  local lic_variant=$VARIANT swl=
  if [ -d "$M/usr/lib/swift" ] && [ -f "$WORK/swiftpkg/payload/usr/share/swift/LICENSE.txt" ]; then
    lic_variant=swift; swl=$WORK/swiftpkg/payload/usr/share/swift/LICENSE.txt
  fi
  echo "license texts"
  quiet python3 -I "$HELPERS/write_licenses.py" "$SRC" "$M/usr/share/licenses/open-sdk" "$lic_variant" \
    "$DATA/licenses/0BSD.txt" --apache-license "$DATA/licenses/Apache-2.0.txt" --sqlite "$(sqlite_dir)" \
    --own-files "$DATA/own-files.txt" --own-headers "$DATA/headers" --sdk "$M" \
    ${swl:+--swift-license "$swl"} --projects-out "$STAGE_WORK/projects.tsv"   # (it prints a count)
  local sq=
  [ "$VARIANT" = core ] || sq="sqlite_url=$SQLITE_URL sqlite_sha256=$SQLITE_SHA256"
  echo "OpenSDK.json"
  # shellcheck disable=SC2086
  python3 -I "$HELPERS/write_open_sdk_json.py" "$M/OpenSDK.json" "$STAGE_WORK/projects.tsv" \
    --own-files "$DATA/own-files.txt" --own-headers "$DATA/headers" \
    generator_commit="$GENERATOR_COMMIT" \
    macos_version="$V" macos_release="$MACOS_REL" variant="$VARIANT" libcxx="$LIBCXX_VERSION" $sq
  echo "README.LICENSE.txt"
  cat > "$M/README.LICENSE.txt" <<'EOF'
This SDK was built by osxcross-open-sdk (make-open-sdk.sh) from open source
code only. It is not Apple's SDK and contains no component of one: no part
of it was taken or derived from an SDK made by Apple. Every header and stub
library comes from the published source code of Apple's open source releases
(github.com/apple-oss-distributions), LLVM (libc++), sqlite.org and, with the
Swift add-on, swift.org, or was written for this SDK.

OpenSDK.json lists the generator and the tag and commit of every project.
The license texts of all projects that the SDK contains, and a list of
which files come from which project, are in usr/share/licenses/open-sdk/
(start with LICENSES.md). The files that were written for this SDK are under
the BSD Zero Clause License (usr/share/licenses/open-sdk/own-files-0BSD/).
EOF
}
