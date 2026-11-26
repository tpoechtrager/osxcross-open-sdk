# Sources

Nothing in this repository or in an SDK made by it comes from an SDK made by  
Apple or from a binary of Apple's.  

Every table, list and number below has a public source. "Tested against" a  
real SDK or a real macOS is a test result (it works or it does not), never a source.

| What | Public source |
|---|---|
| Headers of the SDK | The projects' own install scripts ([details](#headers-of-the-sdk)) |
| Repairs of those headers | Own work, with a notice in each file ([details](#repairs-of-those-headers)) |
| Install names and versions of the `.tbd` | The project files named in `data/libraries.txt` ([details](#install-names-and-versions-of-the-tbd)) |
| Symbols of `libSystem.B.tbd` | Headers, alias lists, system calls, export lists ([details](#symbols-of-libsystembtbd)) |
| compiler-rt builtins in `libSystem.B.tbd` | LLVM `apple_versioning.c` and `CMakeLists.txt` ([details](#compiler-rt-builtins-in-libsystembtbd)) |
| libedit's readline layer | libedit's own install script ([details](#libedits-readline-layer)) |
| `__exp10`, `__exp10f` in `math.h` | LLVM `RuntimeLibcalls.td` ([details](#__exp10-__exp10f-in-mathh)) |
| Symbols of the other `.tbd` | Headers and export lists of the projects ([details](#symbols-of-the-other-tbd)) |
| Symbols of `libiconv.2.tbd` | The public headers of libiconv ([details](#symbols-of-libiconv2tbd)) |
| Symbols of libc++ and libc++abi | LLVM's ABI lists ([details](#symbols-of-libc-and-libcabi)) |
| libc++ release of each macOS release | LLVM's availability table ([details](#libc-release-of-each-macos-release)) |
| `TargetConditionals.h` | CarbonHeaders, compiler macros ([details](#targetconditionalsh)) |
| `architecture/arm64/fenv.h` | Libm, Arm Architecture Reference Manual, xnu ([details](#architecturearm64fenvh)) |
| License text of launchd | The published Apache License 2.0 ([details](#license-text-of-launchd)) |
| `libDER/DERItem.h`, `libDER/libDER_config.h` | xnu `EXTERNAL_HEADERS/libDER/` ([details](#libderderitemh-libderlibder_configh)) |
| `os/log.h` | LLVM, Swift 5.2.5, xnu, configd ([details](#oslogh)) |
| `os/signpost.h`, `os/activity.h`, `os/trace.h` | Swift 5.2.5, Security, xnu; some own values ([details](#ossignposth-osactivityh-ostraceh)) |
| `xpc/xpc.h` | xnu `libkern/os/trace.h` ([details](#xpcxpch)) |
| `CoreFoundation.modulemap`, `CFCompat.h.in` | Own work ([details](#corefoundationmodulemap-cfcompathin)) |
| `SDKSettings.json`, `SDKSettings.plist` | The keys that Clang and OSXCross read ([details](#sdksettingsjson-sdksettingsplist)) |
| `SystemVersion.plist`, the releases | AppleDB for the build number of each release ([details](#systemversionplist-the-releases)) |
| `availability-extra.dsl` | AvailabilityVersions, release notes, LLVM ([details](#availability-extradsl)) |
| Foundation and CoreServices placeholders | dyld, CF and Security sources ([details](#foundation-and-coreservices-placeholders)) |
| Swift runtime stubs | The swift.org package ([details](#swift-runtime-stubs)) |
| Manifests | distribution-macOS, `git ls-remote` ([details](#manifests)) |

## Details of the sources

### Headers of the SDK

**Files:** `lib/headers.sh`, `lib/stubs.sh` (CommonCrypto, launchd), `lib/libs.sh`, `lib/frameworks.sh`

- The projects of `data/manifests/` (tag and commit pinned), installed with the scripts of the projects themselves  
  where they exist (xnu Makefiles, `Libc/xcodescripts/headers.sh`, `mach_install_mig.sh`,  
  `AvailabilityVersions/availability`, ncurses `bootstrap_headers.sh`).

---

### Repairs of those headers

**Files:** `lib/headers.sh` (`headers_fixups`), `lib/cxx.sh`

- Own work, shown in the code with the reason.
- Each repaired file carries a notice (APSL 2.0 section 2.2).

---

### Install names and versions of the `.tbd`

**Files:** `data/libraries.txt`

- The install name, the current and the compatibility version of every `.tbd`.
- The line of the table names the file of the project that states it  
  (xcconfig, Xcode project, Makefile, LLVM's install-property tests, dyld's source).
- `tools/check_libraries.py` checks the table against the sources.
- Values without a public source are the lowest possible ones.

---

### Symbols of `libSystem.B.tbd`

**Files:** `helpers/libsystem_syms.py`, `helpers/syscall_syms.py`, `data/symbols/libsystem-*.txt`

- Declarations of the headers of the SDK (clang AST), kept if the name is in the sources of the userland projects.
- The alias and map files of Libc, libpthread, libplatform, libdispatch and libsyscall.
- The declarations of the public CommonCrypto headers that the project's own `exports.exp-in` exports  
  (libSystem re-exports libcommonCrypto: `Libsystem/requiredlibs`).
- The declarations of launchd's public headers that `liblaunch/*.c` defines  
  (libSystem re-exports libxpc: `Libsystem/requiredlibs`),  
  and `_bootstrap_get_root` and `_bootstrap_look_up_per_user` of `bootstrap_priv.h`.
- The system call stubs that `create-syscalls.pl` of xnu makes; the export lists of Libm.
- For x86_64 also the plain names of the legacy variant, which Libc builds with the macros of `VARIANT_LEGACY_MACROS`  
  (`Libc/xcodescripts/variants.xcconfig`).
- The extra and excluded symbols with the file that defines them  
  (the libcalls `__exp10` and `__sincos_stret` with LLVM's `RuntimeLibcalls.td`).
- The builtins of compiler-rt: [below](#compiler-rt-builtins-in-libsystembtbd).

---

### compiler-rt builtins in `libSystem.B.tbd`

**Files:** `data/symbols/compiler-rt.txt`, `lib/stubs.sh`

- `compiler-rt/lib/builtins/apple_versioning.c` of LLVM (the same file in LLVM 16 to 23) names the builtins
  that libSystem has: `NOT_HERE_BEFORE_10_6` ("Symbols in libSystem.dylib in 10.6 and later") and
  `NOT_HERE_IN_10_8_AND_EARLIER` (the `__atomic_*` functions).  Not taken over are the sections
  `#if __powerpc__` and `#if __arm__ && __DYNAMIC__`.  That leaves 99 + 40 names.
- That libSystem contains compiler-rt: `Libsystem/requiredlibs` of the open source release names `compiler_rt`.
- Per architecture only what compiler-rt builds for it (`compiler-rt/lib/builtins/CMakeLists.txt`): 132 names for x86_64, 119 for arm64.
  - The tf variants (7 names) are left out for both: they need a 128-bit floating-point type (`CRT_HAS_TF_MODE`
    in `int_types.h`); `long double` is the x87 type on x86_64 and `double` on arm64, and Clang has no `__float128` for these targets
    (tested with Clang 23). `Darwin-excludes/osx.txt` also lists five tf builtins.
  - The x87 variants (12 names: `x86_80_BIT_SOURCES`) are only built for x86_64.
  - `__enable_execute_stack` is only built for x86_64: LLVM 23 has `list(REMOVE_ITEM aarch64_SOURCES enable_execute_stack.c)`
    "Don't build enable_execute_stack on arm64 darwin" for Apple platforms (not yet in LLVM 21).
- A check of the result, not a source of names: `libclang_rt.osx.a` of an open source build of LLVM 23.1.6
  defines the 92 (x86_64) and 79 (arm64) names of the first section and none of the names that are left out.

---

### libedit's readline layer

**Files:** `lib/libs.sh`

- `readline/readline.h` and `libreadline.tbd` of the SDK.
- `libedit/xcodescripts/install_misc.sh` and `libedit.xcconfig`.

---

### `__exp10`, `__exp10f` in `math.h`

**Files:** `lib/headers.sh`

- The names and signatures of LLVM's `RuntimeLibcalls.td`; the published Libm does not declare them.

---

### Symbols of the other `.tbd`

**Files:** `helpers/header_syms.py`, the export lists of the projects  
(`libz.exp`, `unexports`, `libutil.exports`, `libxslt.exp`, ...)

- The headers (clang AST) and the export lists of the projects.
- libresolv: the headers of the project and its `installapi.h`, as the project's own build does (`libresolv.xcconfig`).

---

### Symbols of `libiconv.2.tbd`

**Files:** `data/symbols/libiconv.txt`, `lib/stubs.sh` (`stubs_libiconv`)

- The functions and the variable that the public headers of the project libiconv declare:
  - `citrus/iconv.h`: `iconv`, `iconv_open`, `iconv_close`, `__iconv_get_list`, `__iconv_free_list`, `__iconv`,  
    `iconv_open_into`, `libiconv_set_relocation_prefix`, `iconvlist`, `iconv_canonicalize`, `iconvctl`, `_libiconv_version`;
  - `libcharset/localcharset.h`: `locale_charset`;
  - `libcharset/libcharset.h`: `libcharset_set_relocation_prefix`.

---

### Symbols of libc++ and libc++abi

**Files:** `helpers/cxx_syms.py`, `data/symbols/libcxx-extra.txt`

- `libcxx/lib/abi/*.abilist` and `libcxxabi/lib/*.exp` of the LLVM release.
- The extra list says which header needs which symbol.

---

### libc++ release of each macOS release

**Files:** `data/releases.txt`, `data/libcxx-versions.txt`

- The availability table of LLVM (`libcxx/include/__configuration/availability.h`), see the comment of `data/releases.txt`.

---

### `TargetConditionals.h`

**Files:** `data/headers/usr/include/TargetConditionals.h`

- The names of `CarbonHeaders/TargetConditionals.h` and of the open source projects that use them.
- The values from the compiler's predefined macros.

---

### `architecture/arm64/fenv.h`

**Files:** `data/headers/usr/include/architecture/arm64/fenv.h`

- The constants, `fexcept_t` and the size of `fenv_t` of `Libm/Source/ARM/fenv.h`.
- The bit positions of FPSR and FPCR (Arm Architecture Reference Manual).
- The field names `__fpsr` and `__fpcr` from `xnu/osfmk/mach/arm/_structs.h` (`struct __darwin_arm_neon_state64`).

---

### License text of launchd

**Files:** `data/licenses/Apache-2.0.txt`

- The file `usr/share/licenses/open-sdk/launchd/LICENSE-Apache-2.0.txt` of the SDK.
- The text of the Apache License 2.0 as published at apache.org/licenses/LICENSE-2.0.txt  
  (SHA-256 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`).
- launchd's headers only carry the short notice (section 4(a) asks for a copy of the license).

---

### `libDER/DERItem.h`, `libDER/libDER_config.h`

**Files:** `lib/frameworks.sh`

- Copied unchanged from `xnu/EXTERNAL_HEADERS/libDER/` (APSL 2.0) where xnu has them (macOS 26.5),  
  as `oids.h` of Security needs them.
- For the earlier releases `data/headers/usr/include/libDER/DERItem.h` is an own file with the same typedefs and struct  
  (its comment names the xnu header).

---

### `os/log.h`

**Files:** `data/headers/usr/include/os/log.h`, `data/symbols/libsystem-extra.txt`

- Own text (0BSD). The builtins `__builtin_os_log_format` and `__builtin_os_log_format_buffer_size`: LLVM,  
  `clang/include/clang/Basic/Builtins.td` (Apache-2.0 with LLVM exception).
- The call `_os_log_impl(dso, log, type, format, buffer, length)`: swift-5.2.5-RELEASE `stdlib/public/Darwin/os/os.m`  
  (`_swift_os_log`), and the type of `length` (`uint32_t`) from `ob_len` of `os_trace_blob.h` in the same directory  
  (Apache-2.0 with Runtime Library Exception).
- `os_log_t`, `os_log_create(const char *subsystem, const char *category)`, the values of `OS_LOG_TYPE_DEFAULT` 0x00,  
  `INFO` 0x01, `DEBUG` 0x02, `ERROR` 0x10, `FAULT` 0x11 (type `uint8_t`), `OS_LOG_DEFAULT` as the object `_os_log_default`,  
  `OS_LOG_DISABLED` as `NULL`, `__dso_handle`: xnu `libkern/os/log.h` (kernel copy, APSL 2.0; only these facts, no text).
- The exports `__os_log_default`, `_os_log_create`: xnu `config/Libkern.exports`.
- `os_log_type_enabled(log, type)` and its use: configd `SystemConfiguration.fproj/SCD.c` (line 590).
- The symbols are in libSystem because `libsystem_trace.dylib` is part of it: `Libsystem/init.c` (`_libtrace_init`).
- Whether the result runs (messages with the right type and arguments in `log show`) was tested on macOS;  
  that is a test result, not a source.
- The format string is an ordinary C string literal; no section name of Apple's is used.

---

### `os/signpost.h`, `os/activity.h`, `os/trace.h`

**Files:** `data/headers/usr/include/os/` (`signpost.h`, `activity.h`, `trace.h`)

- No-op stand-ins, nothing crosses into the system: no symbol is imported, no value reaches a system function,  
  nothing is traced. Own text (0BSD).
- Names and values that a public source states: `OS_SIGNPOST_ID_NULL`, `OS_SIGNPOST_ID_INVALID`, `OS_SIGNPOST_ID_EXCLUSIVE`  
  (`0xEEEEB0B5B2B2EEEE`), `OS_LOG_CATEGORY_POINTS_OF_INTEREST` and the 64-bit type of `os_signpost_id_t`:  
  swift-5.2.5-RELEASE `stdlib/public/SwiftShims/OSOverlayShims.h`.
- The names `OS_SIGNPOST_EVENT`, `OS_SIGNPOST_INTERVAL_BEGIN`, `OS_SIGNPOST_INTERVAL_END`, `os_signpost_enabled`,  
  `os_signpost_id_generate`, `os_signpost_id_make_with_pointer`: `stdlib/public/Darwin/os/os_signpost.swift` of the same tag  
  (Apache-2.0 with Runtime Library Exception).
- The names and the form of the calls `os_signpost_event_emit`, `os_signpost_interval_begin/_end`, `os_signpost_emit_with_type`,  
  `OS_SIGNPOST_ENABLE_TELEMETRY`: Security (`keychain/SigninMetrics/OctagonSignPosts.h`, `OSX/utilities/SecDbStats.c`, APSL 2.0).
- The names and the form of the calls `os_activity_t`, `os_activity_create`, `OS_ACTIVITY_CURRENT`, `OS_ACTIVITY_FLAG_DEFAULT`,  
  `OS_ACTIVITY_FLAG_IF_NONE_PRESENT`, `os_activity_scope`, `os_activity_scope_enter/_leave`, `struct os_activity_scope_state_s`,  
  `os_activity_initiate`: Security (`OSX/sec/Security/SecTrust.c`, `SecLogging.c`, `OSX/include/security_keychain/SecItem.cpp`).
- The names and form of `os_trace`, `os_trace_info`, `os_trace_debug`, `os_trace_error`, `os_trace_fault`,  
  `os_trace_info_enabled`, `os_trace_debug_enabled`: xnu `libkern/os/trace.h` (APSL 2.0; names only).
- **Own values, with no public source, used only inside these headers:** the numbers of `os_signpost_type_t` (1, 2, 3),  
  the values of `os_activity_flag_t` (0 and 2), the size of `struct os_activity_scope_state_s`,  
  the empty string of `OS_SIGNPOST_ENABLE_TELEMETRY`. `os_activity_create` returns `NULL`; the objects of the system are not made.

---

### `xpc/xpc.h`

**Files:** `data/headers/usr/include/xpc/xpc.h`

- Own file with the one typedef `typedef void *xpc_object_t;` that `xnu/libkern/os/trace.h`  
  (line 36) writes for the case that `<xpc/xpc.h>` does not exist; `SecCode.h` of Security needs the type.

---

### `CoreFoundation.modulemap`, `CFCompat.h.in`

**Files:** `data/headers/System/Library/Frameworks/CoreFoundation.framework/Modules/module.modulemap`, `data/CFCompat.h.in`

- Own work; the macros are those that the CF and DiskArbitration headers need.

---

### `SDKSettings.json`, `SDKSettings.plist`

**Files:** `lib/meta.sh`

- Only the keys that Clang and OSXCross read; the source of each value is in the section "Keys of SDKSettings.json" below.
- The iOS version of a macOS release (for `VersionMap`) comes from the DSL of AvailabilityVersions  
  (`data/availability-extra.dsl` for the releases after the public tags).
- `SDKSettings.plist` has only `Version`, which OSXCross reads for SDKs without a JSON file  
  (`wrapper/src/target.cpp`, `readSDKInfo`), and `OpenSDKGeneratorCommit`.

---

### `SystemVersion.plist`, the releases

**Files:** `data/releases.txt`, `lib/meta.sh`

- `ProductVersion` is the macOS release of the SDK (`--macos`), `ProductName` is `macOS`.
- `ProductBuildVersion` is the public build of the release where `data/releases.txt` names one, else empty  
  (`OPEN_SDK_BUILD_VERSION` sets another value). The source of every build is AppleDB (https://appledb.dev),  
  the page `https://appledb.dev/firmware/macOS/<build>.html` of the release (x.y, as the manifests are pinned):
  - macOS 11.3: `20E232`
  - macOS 12.3: `21E230`
  - macOS 13.3: `22E252`
  - macOS 14.3: `23D56`, released on 2024-01-22
  - macOS 15.5: `24F74`
  - macOS 26.0: `25A354`
  - macOS 26.5: `25F71`, released on 2026-05-11
- The releases, their default libc++ and the variants (full and core, or core only) are choices of the generator.

---

### `availability-extra.dsl`

**Files:** `data/`

- See the comment of the file: the DSL of AvailabilityVersions-138.7 behind `__OPENSOURCE__`,  
  public release notes and version lists, the year-based version rule in LLVM's `Triple.cpp`.

---

### Foundation and CoreServices placeholders

**Files:** `lib/frameworks.sh`

- The install name of Foundation is the one that dyld's source names.
- That of CoreServices follows the layout of the frameworks inside it,  
  which `CF/CFUtilities.c` and Security's `SecTranslocateLSNotification.cpp` name. The versions are the lowest possible ones.

---

### Swift runtime stubs

**Files:** `lib/swift.sh`, `helpers/swift_stubs.py`

- The dylibs of the package of swift.org (Apache-2.0); the install names are read from them.

---

### Manifests

**Files:** `data/manifests/`

- `release.json` of distribution-macOS and `git ls-remote` of the projects (`tools/manifest.py`).

<br>

## Keys of SDKSettings.json

Clang and OSXCross read these keys:

| Key | Value and its source |
|---|---|
| `CanonicalName` | `macosx` and the version of the SDK. |
| `DisplayName` | Free text that this generator chooses: `macOS <version> (open source SDK)`. |
| `Version` | The macOS release of the SDK (the option `--macos`). |
| `MaximumDeploymentTarget` | `<release>.99`, as in LLVM's test inputs ([details](#maximumdeploymenttarget)) |
| `VersionMap.macOS_iOSMac`, `VersionMap.iOSMac_macOS` | Mac Catalyst versions: Clang's minimum, AvailabilityVersions ([details](#versionmapmacos_iosmac-versionmapiosmac_macos)) |
| `SupportedTargets.macosx.Archs` | `arm64`, `arm64e`, `x86_64`, `x86_64h` ([details](#supportedtargetsmacosxarchs)) |
| `SupportedTargets.macosx.LLVMTargetTripleSys`, `.LLVMTargetTripleVendor` | `macos`, `apple` ([details](#supportedtargetsmacosxllvmtargettriplesys-llvmtargettriplevendor)) |
| `SupportedTargets.macosx.MinimumDeploymentTarget` | `11.0`, the oldest macOS release of `data/manifests/` ([details](#supportedtargetsmacosxminimumdeploymenttarget)) |
| `OpenSDKGeneratorCommit` | The commit of this generator; no Apple key, no program reads it ([details](#opensdkgeneratorcommit)) |

Of these, `OpenSDKGeneratorCommit` is read by no program; it is also in `SDKSettings.plist`.  
Clang reads further keys (`LLVMTargetTripleEnvironment`, `SystemPrefix`) only
as optional; they are left out, which clang treats as empty. The keys of an
SDK made by Apple that no program reads (`DefaultVariant`, `Variants`,
`DeviceFamilies`, `IsBaseSDK`, `ValidDeploymentTargets` and others) are not
in the file.

## Details of the keys

### `MaximumDeploymentTarget`

- The release with `.99`, the form that clang accepts for "any later bugfix release"  
  (see the test inputs `clang/test/Driver/Inputs/MacOSX15.1.sdk/SDKSettings.json` of LLVM, which show the form).

---

### `VersionMap.macOS_iOSMac`, `VersionMap.iOSMac_macOS`

- 10.15 is 13.1: `minimumMacCatalystDeploymentTarget()` in `clang/lib/Driver/ToolChains/Darwin.cpp`.
- The iOS version of the SDK's macOS release comes from the DSL of AvailabilityVersions (`helpers/avail_dsl.py --ios-version`).

---

### `SupportedTargets.macosx.Archs`

- `arm64`, `arm64e`, `x86_64`, `x86_64h`: the `-arch` names that `clang/lib/Driver/ToolChains/Darwin.cpp` maps to macOS triples  
  (`getArchTypeForMachOArchName`).

---

### `SupportedTargets.macosx.LLVMTargetTripleSys`, `.LLVMTargetTripleVendor`

- `macos`, `apple`: the triple `arm64-apple-macos`, as in `llvm/lib/TargetParser/Triple.cpp` (`macos`) and the driver.

---

### `SupportedTargets.macosx.MinimumDeploymentTarget`

- `11.0` by default: a choice of this generator, the oldest macOS release of `data/manifests/` (macOS 11).
- `--min-deployment-target` or `OPEN_SDK_MIN_DEPLOYMENT_TARGET` sets another value. Programs for lower targets are not tested.

---

### `OpenSDKGeneratorCommit`

- Own value of this generator, no Apple key: the 40 characters of the commit of this repository
  (`git rev-parse HEAD`) that built the SDK, also in `SDKSettings.plist` and as `generator.commit` of `OpenSDK.json`.
- `-modified` is added to the commit if tracked files have changes; the value is `unknown` if the commit cannot be read (not a checkout, no `git`).
- Clang reads only the keys it knows (`DarwinSDKInfo` in `clang/lib/Basic/DarwinSDKInfo.cpp`), OSXCross
  (`wrapper/src/target.cpp`) only the keys listed above; an unknown key is ignored (tested with Clang 23).
