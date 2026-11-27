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
| Functions of libunwind without a header | `libunwind/src/libunwind.cpp` of libunwind-201 ([details](#functions-of-libunwind-without-a-header)) |
| Private symbols for the sanitizers | Private headers of dyld, libmalloc, libdispatch, libplatform ([details](#private-symbols-for-the-sanitizers)) |
| libedit's readline layer | libedit's own install script ([details](#libedits-readline-layer)) |
| `__exp10`, `__exp10f` in `math.h` | LLVM `RuntimeLibcalls.td` ([details](#__exp10-__exp10f-in-mathh)) |
| Symbols of the other `.tbd` | Headers and export lists of the projects ([details](#symbols-of-the-other-tbd)) |
| Symbols of `libiconv.2.tbd` | The public headers of libiconv ([details](#symbols-of-libiconv2tbd)) |
| `liblzma.5.tbd` | xz 5.0.8 (upstream), libtool, libarchive ([details](#liblzma5tbd)) |
| Symbols of libc++ and libc++abi | LLVM's ABI lists ([details](#symbols-of-libc-and-libcabi)) |
| libc++ release of each macOS release | LLVM's availability table ([details](#libc-release-of-each-macos-release)) |
| `TargetConditionals.h` | CarbonHeaders, compiler macros ([details](#targetconditionalsh)) |
| `architecture/arm64/fenv.h` | Libm, Arm Architecture Reference Manual, xnu ([details](#architecturearm64fenvh)) |
| `libDER/DERItem.h`, `libDER/libDER_config.h` | xnu `EXTERNAL_HEADERS/libDER/` ([details](#libderderitemh-libderlibder_configh)) |
| `os/log.h` | LLVM, Swift 5.2.5, xnu, configd ([details](#oslogh)) |
| `os/signpost.h`, `os/activity.h`, `os/trace.h` | Swift 5.2.5, Security, xnu; some own values ([details](#ossignposth-osactivityh-ostraceh)) |
| `xpc/xpc.h` and its symbols | Apple's XPC documentation, WebKit `XPCSPI.h` ([details](#xpcxpch-and-its-symbols)) |
| `CoreFoundation.modulemap`, `CFCompat.h.in` | swift-corelibs-foundation, AvailabilityVersions, Clang's documentation ([details](#corefoundationmodulemap-cfcompathin)) |
| Newer `CoreFoundation` declarations and symbols | swift-corelibs-foundation, Apple's documentation ([details](#newer-corefoundation-declarations-and-symbols)) |
| `SDKSettings.json`, `SDKSettings.plist` | The keys that Clang and OSXCross read ([details](#sdksettingsjson-sdksettingsplist)) |
| `SystemVersion.plist`, the releases | AppleDB for the build number of each release ([details](#systemversionplist-the-releases)) |
| `availability-extra.dsl` | AvailabilityVersions, release notes, LLVM ([details](#availability-extradsl)) |
| `CoreServices/FSEvents.h` and its symbols | Apple's documentation, fsevent-sys, dotnet/macios ([details](#coreservicesfseventsh-and-its-symbols)) |
| `Security` names of macOS 27.0 | Apple's documentation, Security 61901.120.67 ([details](#security-names-of-macos-270)) |
| `IOKit` device families | IOKitUser's module map, the Xcode projects of the families, IOUSBFamily 560.4.2, Apple documentation ([details](#iokit-device-families)) |
| Link stubs of Foundation, CoreGraphics, AppKit, CoreText, CoreVideo, QuartzCore, Metal, CoreAudio, AudioToolbox, ApplicationServices, Carbon | Apple's documentation, GNUstep, open projects ([details](#link-stubs-from-apples-documentation)) |
| `OpenGL.framework` (headers, link stub) | Khronos OpenGL Registry (`gl.xml`), open projects that declare CGL ([details](#openglframework)) |
| Install names of Foundation, CoreServices | dyld, CF and Security sources ([details](#install-names-of-foundation-coreservices)) |
| Layout of the frameworks, `Cocoa.framework` | Apple's documentation of framework bundles and of Cocoa, python-build-standalone ([details](#framework-layout-and-cocoaframework)) |
| Swift runtime stubs | The swift.org package ([details](#swift-runtime-stubs)) |
| Manifests | distribution-macOS, `git ls-remote` ([details](#manifests)) |
| `stdbool.h`, `stdarg.h`, `float.h` of the scans | ISO C99, Clang's predefined macros ([details](#c-headers-of-the-scans)) |

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
- The functions of libunwind that no header declares: [below](#functions-of-libunwind-without-a-header).
- The private symbols that the sanitizers of compiler-rt need: [below](#private-symbols-for-the-sanitizers).
- The symbols of libxpc (full SDK): [below](#xpcxpch-and-its-symbols).

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

### Functions of libunwind without a header

**Files:** `data/symbols/libunwind.txt`, `lib/stubs.sh`

- `libunwind/src/libunwind.cpp` of `libunwind-201` (manifest) defines `__unw_add_dynamic_fde` and `__unw_remove_dynamic_fde`
  without `_LIBUNWIND_HIDDEN`.
  - `libunwind/src/CMakeLists.txt` compiles with `-fvisibility=hidden` only the objects of the static library
    (`unwind_static_objects`), so the dynamic library exports them.
  - They are declared in `libunwind/src/libunwind_ext.h`, which is not installed.
  - `UnwindLevel1-gcc-ext.c` (`__register_frame`, `__deregister_frame`) calls them; LLVM's JIT (RTDyldMemoryManager, ORC) uses these.
- `_unw_iterate_dwarf_unwind_cache`: `_LIBUNWIND_WEAK_ALIAS(__unw_iterate_dwarf_unwind_cache, unw_iterate_dwarf_unwind_cache)`
  exports the alias (`_LIBUNWIND_EXPORT` in `libunwind/src/config.h`); the function itself is hidden.
- The other `__unw_*` functions are `_LIBUNWIND_HIDDEN`; their aliases `unw_*` are in `libunwind.h`.
- LLVM's libunwind (`llvmorg-17.0.0` and later) has the same names and four more exports
  (`__unw_add_dynamic_eh_frame_section`, `__unw_add_find_dynamic_unwind_sections` and their `remove` functions).
  Nothing open shows that macOS has them, so they are not in the list.
- `_dyld_find_unwind_sections`, which libunwind calls (`libunwind/src/AddressSpace.hpp`, under `__APPLE__`),
  is in `data/symbols/libsystem-spi.txt`: dyld `include/mach-o/dyld_priv.h` declares it,
  `libdyld/libdyldGlue.cpp` defines it.

---

### Private symbols for the sanitizers

**Files:** `data/symbols/libsystem-spi.txt`, `helpers/spi_syms.py`, `data/symbols/libsystem-extra.txt`, `lib/stubs.sh`

- The sanitizer runtimes of compiler-rt (LLVM 23, `compiler-rt/lib/`) declare these private functions and variables
  themselves and refer to them; the list names the user of each.
  The SDK gets only the symbols in `libSystem.B.tbd`, no private header.
- Each symbol is declared in a private header of the project of the manifest that defines it:
  - dyld `include/mach-o/dyld_priv.h` (`_dyld_get_shared_cache_uuid`, `_dyld_get_shared_cache_range`, `_dyld_get_image_slide`, `_dyld_find_unwind_sections`,
    `dyld_shared_cache_iterate_text`, `_dyld_get_dyld_header`; defined in `libdyld/libdyldGlue.cpp`)
  - libmalloc `private/make_tapi_happy.h` (`malloc_zones`, `malloc_num_zones`)
  - libdispatch `private/mach_private.h` (`dispatch_mach_create`, `dispatch_mach_create_f`)
    and `private/layout_private.h` (`dispatch_queue_offsets`)
  - libplatform `private/os/lock_private.h` (`os_unfair_lock_lock_with_options`, `os_lock_lock`, `os_lock_unlock`, `os_lock_trylock`)
- `helpers/spi_syms.py` checks this for each release: the header must declare the name and a source file
  of the project (not a test) must name it. `_dyld_get_dyld_header` is only in the sources of macOS 26.5,
  so the other releases do not get it (compiler-rt imports it weakly).
- Two public functions that the scan of the headers does not find, in `data/symbols/libsystem-extra.txt`:
  - `fileno_unlocked` (`Libc/stdio/FreeBSD/fileno.c`; the header has only a macro)
  - `_os_nospin_lock_lock` (`libplatform/src/os/lock.c`; `libkern/OSSpinLockDeprecated.h` declares it only with `OSSPINLOCK_USE_INLINED=1`)
- `____chkstk_darwin` (four underscores), the stack probe of Darwin that Clang calls (llvm review D40856)
  (a prebuilt Skia object references it): `libpthread/src/pthread_asm.s` defines it with `.globl` for x86_64, i386 and arm64,
  and `src/exports_internal.h` declares the C function `___chkstk_darwin`, whose Mach-O name has the fourth underscore.

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
- libxml2: the whole export list of the project, `Pregenerated Files/libxml2.exp` (`EXPORTED_SYMBOLS_FILE` in
  `Configurations/libxml2.xcconfig`), not the headers.
- expat: the headers, scanned with `-DXML_DTD=1 -DXML_GE=1` (`OTHER_TAPI_FLAGS` in `expat.xcodeproj`).
- ncurses: the headers, scanned with `-DTAPI` (`COMMON_TAPI_FLAGS` in `xcodeconfig/base.xcconfig`).  
  With it `curses.h` declares each function a second time with the `$NCURSES60` name (`ifTAPI` in `curses.head`);  
  programs that use the 15.0 ABI (`NCURSES_EXPORT_ABI60` in the same header) reference these names.
- libffi: `ffi.h` and `tramp.h` (a Public header in `libffi.xcodeproj`).
- libresolv: the headers of the project and its `installapi.h`, as the project's own build does (`libresolv.xcconfig`,
  with `-D__BIND_INSTALLAPI`), and the Private header `dns_private.h` (`libresolv.xcodeproj`; not installed in the SDK).
  Names declared with hidden visibility (`#pragma GCC visibility push(hidden)`) are not exported; the scan leaves them out.

---

### Symbols of `libiconv.2.tbd`

**Files:** `data/symbols/libiconv.txt`, `lib/stubs.sh` (`stubs_libiconv`)

- The functions and the variable that the public headers of the project libiconv declare:
  - `citrus/iconv.h`: `iconv`, `iconv_open`, `iconv_close`, `__iconv_get_list`, `__iconv_free_list`, `__iconv`,  
    `iconv_open_into`, `libiconv_set_relocation_prefix`, `iconvlist`, `iconv_canonicalize`, `iconvctl`, `_libiconv_version`  
    (a C name: the symbol is `__libiconv_version`);
  - `libcharset/localcharset.h`: `locale_charset`;
  - `libcharset/libcharset.h`: `libcharset_set_relocation_prefix`.

---

### `liblzma.5.tbd`

**Files:** `lib/libs.sh` (`libs_lzma`), `lib/fetch.sh` (`fetch_xz`), `data/manifests/` (the `xz` line), `data/libraries.txt`

- Source: the tag `v5.0.8` of xz ([github.com/tukaani-project/xz](https://github.com/tukaani-project/xz)),  
  pinned to its commit in the manifest; liblzma is in the public domain (`COPYING`).
- Why 5.0.8: liblzma keeps the ABI of 5.0 in every later `liblzma.5`  
  (`src/liblzma/liblzma_generic.map` of later releases lists these names under `XZ_5.0`),  
  and the `config.h` of Apple's libarchive (apple-oss libarchive) has no `HAVE_LZMA_STREAM_ENCODER_MT`,  
  the first function of 5.2. The releases 5.6.0 and 5.6.1 are avoided.
- macOS has the library: `libarchive.xcodeproj` of apple-oss libarchive links `liblzma.tbd`.
- Symbols: the functions that `lzma.h` and `lzma/*.h` of `src/liblzma/api` declare (clang AST);  
  they are the `XZ_5.0` node of the map of xz 5.2.13.
- No header: like the library of the system, the SDK has no `lzma.h`; a program uses the one of its own xz.
- Install name `/usr/lib/liblzma.5.dylib` and current version 6.8: libtool's names for  
  `-version-info 5:8:0` (`src/liblzma/Makefile.am`).
- The compatibility version is the lowest possible one (1): Apple's build settings of liblzma are not public.
- Only in the full SDK (step `libs`).

---

### Symbols of libc++ and libc++abi

**Files:** `helpers/cxx_syms.py`, `data/symbols/libcxx-extra.txt`, `data/symbols/libcxxabi-typed-new.txt`

- `libcxx/lib/abi/*.abilist` and `libcxxabi/lib/*.exp` of the LLVM release.
- libc++ re-exports the names of the `.exp` files of libc++abi, but not those of `libcxxabi/lib/symbols-not-reexported.exp`
  (LLVM 19 and later; `libcxxabi/src/CMakeLists.txt`: `export_symbols`, `reexport_symbols`): they are only in `libc++abi.tbd`.
- The extra list says which header needs which symbol.
- The ten typed `operator new`/`operator delete` (with `std::__type_descriptor_t`) come from `libcxxabi/src/vendor/apple/shims.cpp`
  (LLVM 19 and later; the file does not exist in LLVM 18 and earlier).
  The libc++ headers do not declare them; they are in `libc++abi.tbd` and re-exported by `libc++.tbd`.

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

### `xpc/xpc.h` and its symbols

**Files:** `data/headers/usr/include/xpc/xpc.h`, `data/symbols/libsystem-xpc.txt`, `lib/stubs.sh` (`stubs_xpc`)

- Own text (0BSD), full SDK only. libxpc has no open source release. libSystem re-exports it, so its symbols are in `libSystem.B.tbd`:  
  `Libsystem/requiredlibs` lists `xpc`, and `Libsystem/xcodescripts/linker_arguments.sh` links each of them with `-Wl,-reexport-l<lib>`.
- The functions and variables, their parameters and the release that brought each one:  
  Apple's XPC documentation (developer.apple.com/documentation/xpc), the C declaration on the page of each name.  
  152 names from macOS 12.0 or earlier and 16 of sessions, listeners and rich errors (13.0 and 14.0), all in the full SDK of 14.3 and later; each has `API_AVAILABLE` with its release.
- The object and block types, `XPC_GLOBAL_OBJECT`, `XPC_ARRAY_APPEND`, `XPC_CONNECTION_MACH_SERVICE_LISTENER` (`1 << 0`),  
  the order of the activity states and the 11 variables behind `XPC_TYPE_*`, `XPC_ERROR_*` and `XPC_ERROR_KEY_DESCRIPTION`:  
  WebKit `Source/WTF/wtf/spi/darwin/XPCSPI.h` (BSD-2-Clause; facts only, no text).
- Which functions return an object that the caller releases (`OS_OBJECT_RETURNS_RETAINED`): the names with create or copy,  
  and `xpc_connection_send_message_with_reply_sync`, whose page says so.
- The session, listener and rich error functions (macOS 13.0 and 14.0): the Objective-C pages of  
  developer.apple.com/documentation/xpc (fetched 2026-11-27) give the C declarations and the releases.  
  The types of the blocks and the types `xpc_session_t` (`OS_xpc_session`) and `xpc_listener_t` (`OS_xpc_listener`):  
  the Swift pages of the same names.  
  The `create` functions return a retained object (their pages say to call `xpc_release`); the other results are not annotated  
  (a result that the caller releases but the header does not say leaks under ARC; the opposite crashes).
- `xpc_rich_error_can_retry` and `xpc_rich_error_copy_description` have no release on their pages;  
  they get 14.0, that of `XPC_TYPE_RICH_ERROR` (the sessions of 13.0 return rich errors, so 13.0 is possible).
- The flags: the pages name `none`, `inactive`, `privileged` (session) and `none`, `inactive` (listener) in Swift and  
  `XPC_SESSION_CREATE_INACTIVE`, `XPC_LISTENER_CREATE_INACTIVE` in the text, but give no value, no C type and no other C name.  
  The open projects that name values (rama, objc2, pyobjc) take them from Apple's headers, so they are no source.  
  Left out: the flags; the types `xpc_session_create_flags_t` and `xpc_listener_create_flags_t` are `uint64_t`,  
  wide enough for any enumeration, so that a call with 0 or any value of the real type passes it correctly.
- `data/symbols/libsystem-xpc.txt` names the source and release of every symbol; the step stubs stops if the declarations  
  of the header differ from the list.
- **Left out, no public value:** `XPC_TYPE_*` of the other types (the documentation names the macros, not their variables),  
  `XPC_BOOL_TRUE`/`FALSE`, `XPC_CONNECTION_MACH_SERVICE_PRIVILEGED`, `XPC_EVENT_KEY_NAME`.  
  Also left out: the functions of macOS 14.4 and later (peer requirements; the full SDK of 14.3 must not have them),  
  `XPC_TYPE_SESSION`, `XPC_TYPE_LISTENER`, `XPC_TYPE_RICH_ERROR` (no public variable behind them).

---

### `CoreServices/FSEvents.h` and its symbols

**Files:** `data/headers/System/Library/Frameworks/CoreServices.framework/Versions/A/Headers/`, `data/symbols/CoreServices-fsevents.txt`,  
`lib/frameworks.sh`

- Own text (0BSD), full SDK only. CoreServices has no open source release. `CoreServices.h` includes only `FSEvents.h`.
- The functions, types, the fields of `FSEventStreamContext`, the constants and the release that brought each one:  
  Apple's documentation of File System Events (developer.apple.com/documentation/coreservices/file_system_events),  
  the C declaration on the page of each name. It shows the flags and `kFSEventStreamEventIdSinceNow` as enumerators  
  and the keys of the extended data as macros, so the 22 functions are the only symbols.
- The values of the flags and of `kFSEventStreamEventIdSinceNow`, the order of the fields of `FSEventStreamContext`,  
  and `kFSEventStreamCreateFlagUseExtendedData`, `kFSEventStreamCreateFlagFullHistory` and `kFSEventStreamEventFlagItemCloned`,  
  which the documentation does not list:  
  fsevent-sys of github.com/octplane/fsevent-rust, `fsevent-sys/src/fsevent.rs` (MIT).
- The same values, and the strings of `kFSEventStreamEventExtendedDataPathKey` (`"path"`) and `kFSEventStreamEventExtendedFileIDKey` (`"fileID"`):  
  dotnet/macios, `src/CoreServices/FSEvents.cs` (MIT; facts only, the C names of the flags are not there).
- Part of the values also in libuv, `src/unix/darwin-stub.h` (MIT); `kFSEventStreamEventFlagItemCloned` also in `git`,  
  `compat/fsmonitor/fsm-listen-darwin.c`.
- `data/symbols/CoreServices-fsevents.txt` names the source and release of every symbol; the step frameworks stops  
  if the declarations of the header differ from the list.
- The other symbols of the stub: the C functions and global data of the module Core Services of Apple's  
  documentation (`data/symbols/doc/CoreServices.txt`, the page of each symbol in its line, made by  
  `tools/doc_symbols.py` like the lists of the other stubs, see [Link stubs](#link-stubs-from-apples-documentation)),  
  without headers; they are added to the symbols above, whose check against the header does not change.
- **Left out, no C name in these sources:** the flags of dotnet/macios `WithDocId`, `DeviceState` and the key `docID`.
- The stub re-exports `CoreFoundation` (`reexported-libraries`, install name from `data/libraries.txt`);  
  `CoreFoundation.framework/Versions/A/CoreFoundation.tbd` is the file (see [framework layout](#framework-layout-and-cocoaframework)):  
  the linker looks for a re-exported library at its install name below the SDK plus `.tbd`  
  (ld64: `Options::findFile` in `ld/Options.cpp` of cctools-port; ld64.lld does the same).
- Why CoreServices re-exports CoreFoundation: open projects link only `CoreServices`  
  and call CF functions, so they rely on it (default branches as of 2026-11-26):
  - `git` (commit acba8bf): `config.mak.uname` links `-framework CoreServices`;  
    `compat/fsmonitor/fsm-listen-darwin.c` calls `CFStringCreateWithCString` and `CFArrayCreate`.
  - `fswatch` (commit 40dfff9): `libfswatch/CMakeLists.txt` finds only `CoreServices`;  
    `fsevents_monitor.cpp` calls `CFRunLoopGetCurrent`.
  - Go `fsnotify/fsevents` (v0.2.0, commit f73112e): `wrap.go` links `-framework CoreServices`;  
    it calls `CFArrayCreateMutable`.

---

### `CoreFoundation.modulemap`, `CFCompat.h.in`

**Files:** `data/headers/System/Library/Frameworks/CoreFoundation.framework/Versions/A/Modules/module.modulemap`, `data/CFCompat.h.in`

- `CFCompat.h.in` (appended to `CFAvailability.h` of CF, APSL 2.0): the macros that the headers of DiskArbitration,  
  SystemConfiguration and Security use, but the older `CFAvailability.h` does not define.
  - Which macros: the headers of these projects, which use them.
  - Their definitions (`CF_ASSUME_NONNULL_*`, `CF_BRIDGED_TYPE`, `CF_IMPLICIT_BRIDGING_*`, `CF_SWIFT_NAME`, `CF_SWIFT_UNAVAILABLE`,  
    `CF_CLOSED_ENUM`, `CF_STRING_ENUM`, `CF_ENUM` and `CF_OPTIONS` with one argument): swift-corelibs-foundation,  
    tag swift-6.0-RELEASE, `Sources/CoreFoundation/include/CFBase.h` and `CFAvailability.h` (Apache 2.0).
  - `CF_AVAILABLE` and the like through `__OSX_AVAILABLE_STARTING`: `Availability.h` of AvailabilityVersions.
- `module.modulemap`: own text (0BSD), a framework module as Clang's documentation of modules describes it  
  ("Module Map Language").

---

### Newer CoreFoundation declarations and symbols

**Files:** `data/CF/`, `helpers/apply_diff.py`, `data/symbols/doc/CoreFoundation.txt`, `tools/doc_symbols.py`,  
`data/licenses/swift-corelibs-foundation-LICENSE.txt`, `lib/frameworks.sh`

- The base is CF-1153.18 (apple-oss-distributions/CF, `data/manifests/`), which has none of the APIs that came after 2018.
- The declarations: github.com/swiftlang/swift-corelibs-foundation, tag swift-6.4.3-RELEASE (8ddfb630bbb5),  
  `Sources/CoreFoundation/include` (Apache 2.0 with Runtime Library Exception). Each file that has such text  
  carries a `Modified by osxcross-open-sdk` line that names the source.
  - `data/CF/CFNotificationCenter.h` and `data/CF/CFAttributedString.h`: the headers of that project, with the  
    includes written as in a framework (`<CoreFoundation/...>`); `CFNotificationCenterGetDistributedCenter` is  
    declared for `TARGET_OS_OSX` only (the project's `TARGET_OS_OSX || TARGET_OS_WIN32` is for its Windows port).  
    `CoreFoundation.h` includes both.
  - `data/CF/additions.patch` (a unified diff of the CF-1153.18 headers, applied by `helpers/apply_diff.py`):  
    in `CFBase.h` the version numbers of 10.10 and 10.11, in `CFBundle.h` `CFBundleIsExecutableLoadable`,  
    `CFBundleIsExecutableLoadableForURL`, `CFBundleIsArchitectureLoadable` and `kCFBundleExecutableArchitectureARM64`,  
    in `CFDateFormatter.h` `CFISO8601DateFormatOptions` and `CFDateFormatterCreateISO8601Formatter`, in `CFError.h`  
    `kCFErrorLocalizedFailureKey`, in `CFNumberFormatter.h` the four styles of 10.11, in `CFURL.h` the resource keys  
    of 10.11 to 11.3 and two bookmark options, in `CFUserNotification.h` the two keys that CF-1153.18 declares only  
    for iOS.
- What was taken over: a declaration of the project's header that Apple's documentation lists for macOS  
  (the page of each name is in the documentation's JSON; the page names the module "Core Foundation" and macOS).  
  The release in each `API_AVAILABLE(macos(...))` is the `introducedAt` of that page (the project writes  
  `10.16` for `11.0`). Nothing else of the project's headers: the enumerations of types, nullability and other  
  annotations, and everything that the documentation does not list (`CFDateComponents`, `CFDateInterval`,  
  `CFRunArray`, `CFLogUtilities.h`, `kCFLocaleTemperatureUnitKey`, the private headers, `CFStream.h`'s SOCKS names).
- Left out as written for the Swift runtime or other systems: `Boolean` as `bool`, `kCFNotFound` as a `static const`  
  (CF-1153.18 and Apple's have an enumerator), `TARGET_OS_WASI`, `TARGET_OS_BSD`, `TARGET_OS_WIN32`,  
  `DEPLOYMENT_RUNTIME_SWIFT`, `CF_SWIFT_*`, `_CF*` functions of `ForSwiftFoundationOnly.h`, `CF_PRIVATE`.
- Values: every enumerator and constant that both CF-1153.18 and the project's headers have is the same  
  (compared with Clang's AST of both header sets: no difference). The documentation's pages give names, kinds and  
  releases but no values, so the values of the added enumerators have the project as their only source;  
  one of them can be checked in open code: `kCFBundleExecutableArchitectureARM64` is `CPU_TYPE_ARM64`  
  (xnu `osfmk/mach/machine.h`).
- The symbols of `CoreFoundation.tbd` come from the headers as before. `data/symbols/doc/CoreFoundation.txt` adds  
  the C functions and global data that the documentation lists for macOS and that no header of the SDK names  
  (made by `tools/doc_symbols.py --headers <Headers of a built SDK> CoreFoundation`; the list says  
  which day the pages were fetched, and the release of each name, which the generator applies:  
  the SDK of 14.3 has none of 15.0 or later). Functions that headers define inline (`CFSwapInt32`, ...) and  
  `kCFNotFound` are in the documentation too and are not exported; the headers name them, so the list leaves them out.
- The stream constants (`kCFStreamPropertySOCKSProxy`, `kCFStreamSocketSecurityLevel...`, `kCFStreamErrorDomainSSL`, ...)  
  are in the list although no header of the SDK declares them: the documentation names the module "Core Foundation",  
  and CF-1153.18's own `CFSocketStream.c` defines them (`CONST_STRING_DECL`).
- `CoreFoundation.tbd`'s `current-version` stays 1153.18 (the version of the source of the library, not of the headers).

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

### Security names of macOS 27.0

**Files:** `data/symbols/doc/Security.txt`, `lib/frameworks.sh` (`fw_tbd`)

- The names that Apple's documentation lists for Security and that the open source release of macOS 26.5 (Security-61901.120.67) lacks:  
  four variables (`kSecCFErrorDetachedCertificates`, `kSecCodeInfoChosenSignature`, `kSecCodeInfoSignerInfoSKID`, `kSecCodeInfoTotalSignatures`),  
  five `errSecCS*` enumerators, `kSecCSMaxSignatures` and the enumerators of `SecQWACTLSBindingError`  
  (developer.apple.com/documentation/security, fetched 2026-11-27).
- Their pages say macOS 10.0, which is no release (the same pages say iOS 2.0 and visionOS 1.0).  
  The open source release of 26.5 ends at `errSecCSRemoteSignerFailed` (-66990) and has none of them,  
  so they are newer than 26.5: the conservative release is 27.0. The values of the enumerators have no public source.
- The generator has no SDK of 27.0, so no `.tbd` has the variables yet (`data/symbols/doc/Security.txt` names the release)  
  and the headers do not declare the enumerators; they come with such an SDK.
- Not gaps: `SecTransformCustomGetAttribute` is exported as `_SecTranformCustomGetAttribute` (the `__asm__` name in `SecCustomTransform.h`),  
  and `sec_object_t` is declared by `SecProtocolObject.h`.

---

### `IOKit` device families

**Files:** `lib/frameworks.sh` (`iokit_families`, `fw_tbd`), `data/USBCompat.h.in`, `helpers/write_licenses.py`

- The families: the modules `storage` (without `storage/ata`), `hid`, `hidsystem`, `graphics`, `i2c`, `ndrvsupport` and `usb`  
  of IOKitUser's `Modules/IOKit.modulemap`.
- The headers of each directory: the `PBXCopyFilesBuildPhase` of the Xcode project that copies them  
  to `IOKit.framework/Versions/A/Headers/<dir>`:
  - IOStorageFamily, IOCDStorageFamily, IODVDStorageFamily, IOBDStorageFamily: `storage/`,  
    then `unifdef -UKERNEL` as the shell script phase of the same projects does;
  - IOHIDFamily (target `InstallHeaders`): `hid/` and `hidsystem/` in part;
  - IOKitUser (target `IOKit`): the rest of `hid/` and `hidsystem/`, and `graphics/IOGraphicsLib.h`;
  - IOGraphics (targets `IOGraphics Headers`, `IONDRVSupport Headers`): `graphics/`, `i2c/`, `ndrvsupport/`;
  - IOUSBFamily (the `CopyFiles` phase with the destination `IOKit.framework/Versions/A/Headers/usb`): `usb/`,  
    `USB.h`, `USBSpec.h`, `IOUSBLib.h` and `IOUSBUserClient.h`, copied as they are (their kernel parts are under `#if KERNEL`).  
    The other headers of the project go to `Kernel.framework` and are not installed.
- `storage/IOFireWireStorageCharacteristics.h` of the module map belongs to IOFireWireSerialBusProtocolTransport  
  and is not installed.
- Symbols: the declarations of these headers (as for the other frameworks), defined in IOKitUser.
- Not installed: `hidsystem/IOHIDEventSystemClient.h` and `hidsystem/IOHIDServiceClient.h`  
  (IOKitUser `hidsystem.subproj`): IOKitUser builds their functions from  
  `hid.subproj/IOHIDEventSystemClient.c` and `IOHIDServiceClient.c`, which are empty in the open source releases  
  (`IOKitUser` of macOS 14.3 to 26.5), so no open source defines them.
- IOUSBFamily 560.4.2 and not the last tag, 630.4.5: `USB.h` of 630.4.5 is an empty file (as are many other headers of that tag),  
  and `IOUSBLib.h` needs its types; 560.4.2 is the newest tag that has it. The two tags differ in the userspace headers  
  in one comment of `IOUSBLib.h` and four constants of `USBSpec.h` (`kUSBFunctionRemoteWakeCapableBit` and three more).
- Appended to `usb/USB.h` (`data/USBCompat.h.in`, with the notice of `helpers/notice.py`): the enumerators `kUSBDeviceSpeedSuperPlus = 4`,  
  `kUSBDeviceSpeedSuperPlusBy2 = 5`, `kUSBReEnumerateCaptureDeviceBit = 30` and  
  `kUSBReEnumerateCaptureDeviceMask = (1 << kUSBReEnumerateCaptureDeviceBit)`:  
  - neither open tag (560.4.2, 630.4.5) has them; libusb 1.0.30 (`os/darwin_usb.c`) uses them;  
  - source: Apple's public documentation of the kernel, the declarations of these four enumerators:  
    the enumeration of `kUSBDeviceSpeedLow` (`developer.apple.com/documentation/kernel/1646359-anonymous`) and  
    `USBReEnumerateOptions` (`developer.apple.com/documentation/kernel/usbreenumerateoptions`);  
  - the other enumerators of `USBReEnumerateOptions` are left out.
- `IOKit.tbd` gets nothing from `usb/`: `IOUSBLib.h` is the interface of a CFPlugIn (UUID macros and structures of function pointers,  
  no function), `IOUSBUserClient.h` only constants.
- Licenses: APSL 2.0; the headers of IOGraphics carry the APSL 1.1 notice, its text is the `APPLE_LICENSE` of Libinfo.  
  IOHIDFamily has no license file (the notice of `IOHIDKeys.h` and the APSL 2.0 text of xnu).
- Tags: `release.json` of distribution-macOS for 14.3, 15.5, 26.0 and 26.5 (see [Manifests](#manifests)), except IOUSBFamily:  
  `release.json` does not list it, its manifest lines are `fixed` with the tag 560.4.2;  
  the core-only releases do not have these projects.

---

### Link stubs from Apple's documentation

**Files:** `data/symbols/doc/`, `data/symbols/CoreGraphics-extra.txt`,  
`tools/doc_symbols.py`, `lib/frameworks.sh`, `data/libraries.txt`

- Full SDK only. These frameworks have no open source release: the SDK has only their `.tbd`, no headers  
  (the documentation does not give the values of macros, enumerators and the fields of structs).  
  They are for languages and packages that declare what they use themselves (Rust crates, for example).
- The symbols: the C functions and global variables and constants that Apple's documentation lists for macOS  
  (developer.apple.com/documentation; the page of each symbol is in its line of `data/symbols/doc/<name>.txt`,  
  with the release that brought it). `tools/doc_symbols.py` makes the lists from the JSON form of the pages  
  (developer.apple.com/tutorials/data/documentation/...); each list names the days they were fetched.  
  The full SDK of a release has the symbols of that release and earlier.  
  Left out: names with a leading underscore, which the pages of Swift initializers give  
  (`_CTFontCreateWithName` on the page of `CTFont.init(_:size:)`, for example).
- The pages: the Swift pages of the framework and the pages they refer to; some symbols have only an  
  Objective-C page (`developer.apple.com/documentation/appkit/nsbeep`, for example).
  A page whose `metadata.platforms` is missing or does not name macOS counts if the platforms of its declaration  
  name macOS (`CGDisplayStreamCreate`, `CGWindowListCreateImage`, `AudioServicesPlaySystemSoundWithDetails`);  
  it has no release then ("-": in every SDK), or that of the other platforms from 26.0 on, which share the number.
- The framework of a symbol is the module that its page names. The Swift pages list constants that other  
  frameworks define under Foundation (members of `NSNotification.Name`, `NSAttributedString.Key`, ...);  
  for them the Objective-C page (`developer.apple.com/documentation/appkit/<name>`) names the framework.
- Where there is no such page: the headers of GNUstep, which follow the split of Apple's frameworks  
  (github.com/gnustep/libs-base, `Headers/Foundation`, and github.com/gnustep/libs-gui, `Headers/AppKit`, LGPL;  
  names only; the commits are in the lists). A constant under Foundation that only `libs-gui` declares goes to AppKit;  
  a member of an extension that neither declares is left out.
- Very old symbols stay in the lists as long as the page names macOS: the File Manager of CoreServices (`FSGetCatalogInfo`,  
  `PBGetCatalogInfoSync`, ... of 10.0 to 10.5), the Web Services constants `kWS...` (10.2) and `pi` (10.0); the page says  
  deprecated, not removed, and no open source says which release still exports them.  
- The documentation does not say which symbols exist on only one architecture, or which functions are not  
  exported (inline): every symbol is in the stub for x86_64 and arm64. A symbol that a release of macOS does  
  not export links, but the program stops at start with "symbol not found".
- Symbols that the documentation does not list, which open projects declare themselves and link from  
  these frameworks, so they rely on them (`CoreGraphics-extra.txt`, each line names the project and file):  
  the private functions `CGSMainConnectionID` and `CGSSetWindowBackgroundBlurRadius`  
  (winit b1a0534, `winit-appkit/src/window_delegate.rs`).
- Install names: Foundation's is the one that dyld's source names (below). CoreGraphics (`Versions/A`) and AppKit  
  (`Versions/C`): the lists of macOS system libraries of astral-sh/python-build-standalone 139273f, `src/validation.rs`  
  (MPL-2.0), and michidk/maiko f984528, `crates/patcher/src/macos.rs` (MIT).
- CoreText's install name (`Versions/A`) has one source: the list of astral-sh/python-build-standalone 139273f,  
  `src/validation.rs` (MPL-2.0).
- CoreVideo's install name (`Versions/A`) has one source: the list of michidk/maiko f984528,  
  `crates/patcher/src/macos.rs` (MIT).
- QuartzCore's install name (`Versions/A`): the same two lists (python-build-standalone 139273f, `src/validation.rs`;  
  maiko f984528, `crates/patcher/src/macos.rs`). Its symbols are those of the documentation module "Core Animation".
- Metal's install name (`Versions/A`) has one source: the list of michidk/maiko f984528, `crates/patcher/src/macos.rs` (MIT).  
  The pages of four `NS...` constants (`NSProcessPerformanceProfileDefault`, `NSDeviceCertificationiPhonePerformanceGaming`, ...)  
  name Metal as their module, so they are in the stub of Metal.
- CoreAudio's install name (`Versions/A`) has one source: the list of michidk/maiko f984528, `crates/patcher/src/macos.rs` (MIT).  
  Its symbols are those of the documentation modules "Core Audio" and "Core Audio Types".
- AudioToolbox's install name (`Versions/A`) has one source: the list of michidk/maiko f984528, `crates/patcher/src/macos.rs` (MIT).  
  Its symbols are those of the documentation module "Audio Toolbox".
- ApplicationServices' install name (`Versions/A`): the same two lists (python-build-standalone 139273f, `src/validation.rs`;  
  maiko f984528, `crates/patcher/src/macos.rs`).  
  Its symbols are those of the documentation modules "Application Services" and "ColorSync", in one list:  
  ColorSync is a framework inside ApplicationServices, and the crates link its functions through ApplicationServices  
  (winit b1a0534, `winit-appkit/src/ffi.rs`: `CGDisplayCreateUUIDFromDisplayID`, `CGDisplayGetDisplayIDFromUUID`,  
  with a comment that ColorSync is part of ApplicationServices).  
  There is no ColorSync stub and no re-export: no open source names the re-exports of ApplicationServices.
- Carbon has no list from the documentation (it has no pages of C symbols of its own): only `Carbon-extra.txt`,  
  the names that open projects declare themselves in an `extern` block with `link(name = "Carbon")`, so they rely on them.  
  Each entry of the file names the projects (commit) and files; a project that only includes Apple's `<Carbon/Carbon.h>`  
  (Godot, OBS Studio, SDL) is no source here, and neither is a binding made by `bindgen` or `objc2` from Apple's headers  
  (`global-hotkey`, `super_native_extensions`):
  - Keyboard layout: `TISCopyCurrentKeyboardLayoutInputSource`, `TISGetInputSourceProperty`,  
    `kTISPropertyUnicodeKeyLayoutData`, `LMGetKbdType` (winit b1a0534, `winit-appkit/src/ffi.rs`; GLFW 92dcf4c,  
    `src/cocoa_init.m`, uses the same four from the HIToolbox bundle, which is a framework inside Carbon), and `UCKeyTranslate`.  
  - Text Input Sources: `TISCopyCurrentKeyboardInputSource`, `TISCopyCurrentASCIICapableKeyboardLayoutInputSource` (enigo 0.6.1,  
    rdev 0.5.3), `TISCreateInputSourceList` (anomalyco/hex 3b936b9, MystikoLab/rustcast 6f5d1aa), `TISSelectInputSource`  
    (rustcast), `TISEnableInputSource`, `TISRegisterInputSource` (qingjian d75ca0e), and the constants `kTISProperty*`,  
    `kTISCategoryKeyboardInputSource`, `kTISType*` and `kTISNotifySelectedKeyboardInputSourceChanged` (hex, zed ed8dc1b,  
    n2ray/xdesk 1f9a0cf, qingjian).  
    The constants are `CFStringRef` data symbols, the others functions; the stub lists both kinds the same way.  
  - Event handlers and hot keys: `RegisterEventHotKey`, `UnregisterEventHotKey`, `InstallEventHandler`, `RemoveEventHandler`,  
    `GetApplicationEventTarget`, `GetEventParameter` (neovide 95c913b, `src/window/application/macos/hotkey.rs`),  
    `GetEventKind` (acsandmann/rift 2d28eac, `src/sys/carbon.rs`; hex).  
    Apple's page of the Carbon Event Manager guide (`developer.apple.com/library/archive/documentation/Carbon/Conceptual/Carbon_Event_Manager/Tasks/CarbonEventsTasks.html`)  
    names `InstallEventHandler`, `RemoveEventHandler`, `GetApplicationEventTarget`, `GetEventKind` and `GetEventParameter` too.
  - Which of them HIToolbox exports on its own and which Carbon re-exports is not known from an open source: all are in the stub  
    of Carbon, as the projects link them with `-framework Carbon`.  
  Apple's documentation puts `UCKeyTranslate` in Core Services (the stub of CoreServices has it too);  
  winit links it with `-framework Carbon`, so it is in the stub of Carbon,  
  as there is no re-export of CoreServices by Carbon in an open source.  
  Carbon's install name (`Versions/A`): the same two lists as for CoreGraphics (python-build-standalone 139273f,  
  `src/validation.rs`; maiko f984528, `crates/patcher/src/macos.rs`).
- Versions: the lowest possible ones (`1.0.0`), as for the other frameworks without a version source.

---

### OpenGL.framework

**Files:** `data/opengl/` (`registry.txt`, `cgl-enums.txt`, `cgl-functions.txt`, `extensions.txt`),  
`helpers/gl_registry.py`, `helpers/write_opengl_headers.py`, `helpers/opengl_syms.py`, `lib/frameworks.sh`, `lib/fetch.sh`

- Headers and install name only come from open sources; Apple's headers and libraries are not read.  
  The headers are written by the generator at build time from the data files, not copied.
- **OpenGL itself** (names, values and signatures of the functions and tokens of `gl.h`, `gl3.h`, `glext.h`):  
  the OpenGL API Registry of the Khronos Group, `xml/gl.xml` of github.com/KhronosGroup/OpenGL-Registry  
  (commit and SHA-256 in `data/opengl/registry.txt`; downloaded by the step `fetch`).  
  `gl.xml` is licensed Apache-2.0 (`SPDX-License-Identifier: Apache-2.0` in its first comment);  
  the generated `gltypes.h`, `gl.h`, `gl3.h`, `glext.h` and `gl3ext.h` carry that notice and are Apache-2.0 too.  
  No header of the Registry (`glext.h`, `glcorearb.h`, MIT) is copied: the generator reads only `gl.xml`.  
  The C types are those of the Registry's `KHR/khrplatform.h` (`int8_t`, `float`, `intptr_t`, ...).
- **Which header has what.** The names of the headers are those that open projects include:  
  `<OpenGL/gl.h>`, `<OpenGL/gl3.h>`, `<OpenGL/glext.h>`, `<OpenGL/gl3ext.h>`, `<OpenGL/OpenGL.h>`, `<OpenGL/CGLTypes.h>`,  
  `<OpenGL/CGLCurrent.h>`, `<OpenGL/CGLRenderers.h>`, `<OpenGL/CGLDevice.h>`, `<OpenGL/CGLIOSurface.h>`  
  (mesa 7564f95, `src/glx/apple/apple_cgl.h` and `apple_visual.c`; apitrace 28bb3ab, `dispatch/glimports.hpp`;  
  GLFW and the projects that include `gl3ext.h` for `GLFW_INCLUDE_GLCOREARB`) and `<OpenGL/gltypes.h>`  
  (Syphon-Framework and libpag include it).  
  `gl.h` is the legacy profile and has what `gl.xml` requires for OpenGL 1.0 to 2.1 in the compatibility profile;  
  `gl3.h` is the core profile, OpenGL 1.0 to 4.1 without what the registry removes for the core profile.  
  The limit 2.1 / 3.2 to 4.1 is the one of the contexts that `kCGLOGLPVersion_Legacy`, `_3_2_Core` and `_GL4_Core` select  
  (`data/opengl/cgl-enums.txt`; Apple's archived "OpenGL Programming Guide for Mac" names Legacy and 3.2 Core).  
  `gl.h` and `gl3.h` may be included together. `gl3ext.h` is empty: no source says which extensions a core context has.
- **The CGL types and constants** (`CGLTypes.h`, `CGLRenderers.h`): no Khronos standard, no current Apple documentation.  
  Every value is declared by an open project that wrote it down (`data/opengl/cgl-enums.txt` names them per entry):  
  servo/cgl-rs d97cc08 `src/cgl.rs` (MIT or Apache-2.0), ValveSoftware/vogl 434dcc5 `glspec/cglenum.spec` (MIT, "hand generated"),  
  apitrace 28bb3ab `dispatch/glimports.hpp` (MIT), factor/factor f05a4e9 `basis/core-graphics/core-graphics.factor` (BSD).  
  The names are also used or listed by apitrace `specs/cglapi.py`, Wine (`dlls/winemac.drv/opengl.c`), XQuartz (`hw/xquartz/GL/indirect.c`),  
  mesa, renderdoc and Apple's archived programming guide.  
  Values with one source: the `kCGLBad...` errors, the `kCGLRP...` renderer properties (vogl only),  
  the `kCGLOGLPVersion_...` profiles (apitrace only) and `kCGLRendererGenericFloatID` (Factor only).  
  Left out because no source declares a value: the other renderer IDs, the buffer and color mode bits (`kCGLRGB888Bit`, ...),  
  the constants of `CGLProfiler.h` (apitrace only, and it notes that the header is gone), `CGLContext.h` and `CGLMacro.h`.
- **The CGL functions** (`data/opengl/cgl-functions.txt`): those that at least two projects name  
  (apitrace `specs/cglapi.py`, which also names the header of each, vogl `glspec/cgl.spec`, servo/cgl-rs,  
  mesa `apple_cgl.c`, Wine, XQuartz, renderdoc, Apple's guide). The parameter types follow mesa `apple_cgl.h` and apitrace.  
  Left out because only apitrace names them: `CGLGetContextRetainCount`, `CGLReleasePBuffer`, `CGLGetPBufferRetainCount`,  
  `CGLSetFullScreenOnDisplay`; and the functions that apitrace calls undocumented.
- **Exports of `OpenGL.tbd`** (conservative):  
  every command that `gl.xml` requires for OpenGL 1.0 to 4.1;  
  the CGL functions above;  
  the functions of the extensions of `data/opengl/extensions.txt` (`GL_APPLE_fence`, `GL_APPLE_vertex_array_object`,  
  `GL_APPLE_vertex_array_range`, `GL_APPLE_texture_range`, `GL_APPLE_flush_buffer_range`, `GL_EXT_framebuffer_object`):  
  Apple's guide for Mac (developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide,  
  the pages `opengl_designstrategies`, `opengl_vertexdata`, `opengl_texturedata`, `opengl_offscreen`)  
  calls each of these functions by name in its sample code, with no lookup. Other extensions are not exported and not declared.  
  Not in the stub: GLU (`glu.h`, `libGLU`), the functions of OpenGL 4.2 and later, `CGLContext.h`.
- Install name `/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL`: mesa `src/glx/apple/apple_cgl.c` (`OPENGL_FRAMEWORK_PATH`).  
  Godot's glad loader names the same framework by `.../OpenGL.framework/Versions/Current/OpenGL`.  
  Versions: the lowest possible ones (`1.0.0`), as for the other frameworks without a version source.

---

### Install names of Foundation, CoreServices

**Files:** `lib/frameworks.sh`, `data/libraries.txt`

- The install name of Foundation is the one that dyld's source names.
- That of CoreServices follows the layout of the frameworks inside it,  
  which `CF/CFUtilities.c` and Security's `SecTranslocateLSNotification.cpp` name. The versions are the lowest possible ones.

---

### Framework layout and `Cocoa.framework`

**Files:** `lib/frameworks.sh` (`fw_layout`), `data/libraries.txt`, `tests/sdk-check.py`

- The layout: Apple's "Anatomy of Framework Bundles" (developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/FrameworkAnatomy.html):  
  the files are in `Versions/<V>`, `Versions/Current` is a link to the current version, and the top level has links  
  to `Versions/Current/<Name>` and `Headers` (and `Resources`). The page does not describe `Modules`;  
  it is linked the same way, where the framework has one (Clang finds `Name.framework/Modules/module.modulemap`).
- The letter `<V>` is that of the install name of the framework in `data/libraries.txt` (each with its source above).
- Why the install name must be the path of the file: a re-exported library is looked up at its install name below the SDK  
  plus `.tbd` (ld64: `Options::findFile` in `ld/Options.cpp` of cctools-port; `ld64.lld` does the same).  
  The test `tests/sdk-check.sh` compares the install name of every `.tbd` with its path.
- `Cocoa.framework` re-exports `AppKit` and `Foundation`: "The Cocoa umbrella framework (`Cocoa.framework`) imports the core Objective-C  
  frameworks for app development: AppKit, Foundation, and Core Data" (Apple's "Cocoa Application Layer",  
  developer.apple.com/library/archive/documentation/MacOSX/Conceptual/OSX_Technology_Overview/CocoaApplicationLayer/CocoaApplicationLayer.html).  
  There is no `CoreData` in the SDK, so it is not re-exported.
- `CoreGraphics` is not re-exported: glfw's sources (`src/cocoa_monitor.m`) call `CGDisplay...` functions and its build links only
  `Cocoa`, so a program may rely on that, but no public source says which framework gives them.  With a re-export of `CoreGraphics`
  the link of the glfw crate lacks only `UCKeyTranslate` (Carbon) and the Objective-C classes.
- Install name `/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa`: astral-sh/python-build-standalone 139273f, `src/validation.rs`  
  (MPL-2.0). Versions: the lowest possible ones (`1.0.0`), as for the other frameworks without a version source.

---

### Swift runtime stubs

**Files:** `lib/swift.sh`, `helpers/swift_stubs.py`

- The dylibs of the package of swift.org (Apache-2.0); the install names are read from them.

---

### Manifests

**Files:** `data/manifests/`

- `release.json` of distribution-macOS and `git ls-remote` of the projects (`tools/manifest.py`).
- The `sqlite` and `xz` lines are the same in every manifest; `--new` copies them.

---

### C headers of the scans

**Files:** `helpers/clang_scan.py`

- The symbol scans (`header_syms.py`, `libsystem_syms.py`) need `stdbool.h`, `stdarg.h` and `float.h`.
  The SDK does not contain them, the compiler provides them;
  the `clang` of FreeBSD and OpenBSD does not (the system's own headers are in `/usr/include`).  
  Only a header that is missing is supplied, in a temporary directory that is not part of the SDK.
- `stdbool.h`: ISO C99 7.16.
- `stdarg.h`: ISO C99 7.15, with the `__builtin_va_*` functions of Clang.
- `float.h`: ISO C99 and C11 5.2.4.2.2, with the macros that Clang predefines (`__DBL_MAX__` and so on).

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
