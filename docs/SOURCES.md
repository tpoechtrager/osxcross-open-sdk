# Sources

Nothing in this repository or in an Open SDK made by it comes from an SDK made by  
Apple or from a binary of Apple's.

Every table, list and number below has a public source. "Tested against" a  
real SDK or a real macOS is a test result (it works or it does not), never a source.

Where no public source gives a value, the generator chooses a cautious one (for example the lowest possible version).  
Such values are listed under "Chosen by the generator"; none of them is read from an SDK or a binary of Apple's.

"apple-oss" before a project (apple-oss Libc, apple-oss libiconv) means the project of Apple's open source releases,  
[github.com/apple-oss-distributions/\<name\>](https://github.com/apple-oss-distributions), at the tag that `data/manifests/` names for the macOS release,  
not the project of the same name elsewhere (FreeBSD's Libc, GNU libiconv).  
Projects that only Apple has (xnu, dyld, Libsystem, IOKitUser, AvailabilityVersions, ...) are always those.

**Libraries (`.tbd`)**

| What | Public source |
|---|---|
| Install names and versions of the `.tbd`s | The project files named in `data/libraries.txt` ([details](#install-names-and-versions-of-the-tbds)) |
| Symbols of `libSystem.B.tbd` | Headers, alias lists, system calls, export lists ([details](#symbols-of-libsystembtbd)) |
| compiler-rt builtins in `libSystem.B.tbd` | LLVM `apple_versioning.c` and `CMakeLists.txt` ([details](#compiler-rt-builtins-in-libsystembtbd)) |
| Functions of libunwind without a header | `libunwind/src/libunwind.cpp` of apple-oss libunwind-201 ([details](#functions-of-libunwind-without-a-header)) |
| Private symbols for the sanitizers | Private headers of the apple-oss projects dyld, libmalloc, libdispatch, libplatform ([details](#private-symbols-for-the-sanitizers)) |
| Other public symbols of `libSystem.B.tbd` without a header | apple-oss Libc, libplatform, Libm, libpthread ([details](#other-symbols-of-libsystembtbd-without-a-header)) |
| libedit's readline layer | The install script of apple-oss libedit ([details](#libedits-readline-layer)) |
| Symbols of the other `.tbd`s | Headers and export lists of the apple-oss projects ([details](#symbols-of-the-other-tbds)) |
| Symbols of `libiconv.2.tbd` | The public headers of apple-oss libiconv ([details](#symbols-of-libiconv2tbd)) |
| `liblzma.5.tbd` | xz 5.0.8 (upstream), libtool, apple-oss libarchive ([details](#liblzma5tbd)) |
| Symbols of libc++ and libc++abi | LLVM's ABI lists ([details](#symbols-of-libc-and-libcabi)) |
| libc++ release of each macOS release | LLVM's availability table ([details](#libc-release-of-each-macos-release)) |

**Headers**

| What | Public source |
|---|---|
| Headers of the Open SDK | The install scripts of the apple-oss projects ([details](#headers-of-the-open-sdk)) |
| Repairs of those headers | Own work, with a notice in each file ([details](#repairs-of-those-headers)) |
| `__exp10`, `__exp10f` in `math.h` | LLVM `RuntimeLibcalls.td` ([details](#__exp10-__exp10f-in-mathh)) |
| `TargetConditionals.h` | CarbonHeaders, compiler macros ([details](#targetconditionalsh)) |
| `architecture/arm64/fenv.h` | apple-oss Libm, Arm Architecture Reference Manual, xnu ([details](#architecturearm64fenvh)) |
| `libDER/DERItem.h`, `libDER/libDER_config.h` | xnu `EXTERNAL_HEADERS/libDER/` ([details](#libderderitemh-libderlibder_configh)) |
| `os/log.h` | LLVM, Swift 5.2.5, xnu, configd ([details](#oslogh)) |
| `os/signpost.h`, `os/activity.h`, `os/trace.h` | Swift 5.2.5, apple-oss Security, xnu; some values chosen by the generator ([details](#ossignposth-osactivityh-ostraceh)) |
| `xpc/xpc.h` and its symbols | Apple's XPC documentation, WebKit `XPCSPI.h` ([details](#xpcxpch-and-its-symbols)) |
| `stdbool.h`, `stdarg.h`, `float.h` of the scans | ISO C99, Clang's predefined macros ([details](#c-headers-of-the-scans)) |

**Frameworks**

| What | Public source |
|---|---|
| `CoreFoundation.modulemap`, `CFCompat.h.in` | swift-corelibs-foundation, AvailabilityVersions, Clang's documentation ([details](#corefoundationmodulemap-cfcompathin)) |
| Newer `CoreFoundation` declarations and symbols | swift-corelibs-foundation, Apple's documentation ([details](#newer-corefoundation-declarations-and-symbols)) |
| `CoreServices/FSEvents.h` and its symbols | Apple's documentation, fsevent-sys, dotnet/macios ([details](#coreservicesfseventsh-and-its-symbols)) |
| `Security` names of macOS 27.0 | Apple's documentation, apple-oss Security 61901.120.67 ([details](#security-names-of-macos-270)) |
| `IOKit` device families | IOKitUser's module map, the Xcode projects of the families, IOUSBFamily 560.4.2, IOSerialFamily 93.200.2, Apple documentation ([details](#iokit-device-families)) |
| Link stubs of 20 frameworks without headers in the Open SDK (Foundation, AppKit, CoreGraphics, ...) | Apple's documentation, GNUstep, open projects ([details](#link-stubs-from-apples-documentation)) |
| `OpenGL.framework` (headers, link stub) | Khronos OpenGL Registry (`gl.xml`), open projects that declare CGL ([details](#openglframework)) |
| Install names of Foundation, CoreServices | dyld and the apple-oss projects CF and Security ([details](#install-names-of-foundation-coreservices)) |
| Layout of the frameworks, `Cocoa.framework` | Apple's documentation of framework bundles and of Cocoa, python-build-standalone ([details](#framework-layout-and-cocoaframework)) |
| Swift runtime stubs | The swift.org package ([details](#swift-runtime-stubs)) |

**SDK metadata and releases**

| What | Public source |
|---|---|
| `SDKSettings.json`, `SDKSettings.plist` | The keys that Clang and OSXCross read ([details](#sdksettingsjson-sdksettingsplist)) |
| `SystemVersion.plist`, the releases | AppleDB for the build number of each release ([details](#systemversionplist-the-releases)) |
| `availability-extra.dsl` | AvailabilityVersions, release notes, LLVM ([details](#availability-extradsl)) |
| Manifests | distribution-macOS, `git ls-remote` ([details](#manifests)) |

## Details of the sources

### Install names and versions of the `.tbd`s

**Files:**

- `data/libraries.txt`

**Details:**

Every `.tbd` gives the install name of its library (the path at which a program looks for it at run time,  
`/usr/lib/libSystem.B.dylib`, for example) and its current and compatibility version.  
`data/libraries.txt` has one line per library with these values and, in its last column, the file that states them.

**Sources** (one per library, named in its line):

- the xcconfig files, Xcode projects and Makefiles of the apple-oss projects  
  (`Libsystem/Libsystem.xcconfig`, `libiconv/libiconv.xcodeproj`, `libpcap/Makefile`, ...)
- LLVM's install-property tests and `CMakeLists.txt` (libc++, libc++abi)
- dyld's source (Foundation)

**Chosen by the generator:** the lowest possible value (`1.0.0` for the frameworks whose versions no open source gives);  
the sections below do not repeat this.

**Checks:** `tools/check_libraries.py` checks the table against the sources.

---

### Symbols of `libSystem.B.tbd`

**Files:**

- `helpers/libsystem_syms.py`
- `helpers/syscall_syms.py`
- `data/symbols/libsystem-*.txt`

**Sources:**

- apple-oss [Libc](https://github.com/apple-oss-distributions/Libc/tree/Libc-1752.120.2), [Libm](https://github.com/apple-oss-distributions/Libm/tree/Libm-2026), [libpthread](https://github.com/apple-oss-distributions/libpthread/tree/libpthread-539.100.4), [libplatform](https://github.com/apple-oss-distributions/libplatform/tree/libplatform-375.120.2), [libmalloc](https://github.com/apple-oss-distributions/libmalloc/tree/libmalloc-812.100.31), [libdispatch](https://github.com/apple-oss-distributions/libdispatch/tree/libdispatch-1542.100.32), [Libinfo](https://github.com/apple-oss-distributions/Libinfo/tree/Libinfo-600), [libresolv](https://github.com/apple-oss-distributions/libresolv/tree/libresolv-96), [Libnotify](https://github.com/apple-oss-distributions/Libnotify/tree/Libnotify-348.120.4),  
  [copyfile](https://github.com/apple-oss-distributions/copyfile/tree/copyfile-240), [removefile](https://github.com/apple-oss-distributions/removefile/tree/removefile-85.100.6), [dyld](https://github.com/apple-oss-distributions/dyld/tree/dyld-1378), [libunwind](https://github.com/apple-oss-distributions/libunwind/tree/libunwind-201), [syslog](https://github.com/apple-oss-distributions/syslog/tree/syslog-406), [libclosure](https://github.com/apple-oss-distributions/libclosure/tree/libclosure-96), [architecture](https://github.com/apple-oss-distributions/architecture/tree/architecture-282): headers, source code, alias lists
- apple-oss [cctools](https://github.com/apple-oss-distributions/cctools/tree/cctools-1024.3): [`libmacho`](https://github.com/apple-oss-distributions/cctools/tree/cctools-1024.3/libmacho)
- [xnu](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6): [`libsyscall`](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6/libsyscall) ([`syscall.map`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/libsyscall/Platforms/syscall.map), [`create-syscalls.pl`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/libsyscall/xcodescripts/create-syscalls.pl)), [`osfmk/mach`](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6/osfmk/mach), [`libkern/os`](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6/libkern/os), [`libkern/libkern/OSAtomic.h`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/libkern/libkern/OSAtomic.h)
- apple-oss [CommonCrypto](https://github.com/apple-oss-distributions/CommonCrypto/tree/CommonCrypto-600035), [launchd](https://github.com/apple-oss-distributions/launchd/tree/launchd-842.92.1): public headers, [`exports.exp-in`](https://github.com/apple-oss-distributions/CommonCrypto/blob/CommonCrypto-600035/exports.exp-in), [`liblaunch/*.c`](https://github.com/apple-oss-distributions/launchd/tree/launchd-842.92.1/liblaunch), [`liblaunch/bootstrap_priv.h`](https://github.com/apple-oss-distributions/launchd/blob/launchd-842.92.1/liblaunch/bootstrap_priv.h)
- [Libsystem](https://github.com/apple-oss-distributions/Libsystem/tree/Libsystem-1356): [`requiredlibs`](https://github.com/apple-oss-distributions/Libsystem/blob/Libsystem-1356/requiredlibs), source code
- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6: [`llvm/include/llvm/IR/RuntimeLibcalls.td`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/llvm/include/llvm/IR/RuntimeLibcalls.td)

**Details:**

`libSystem.B.tbd` lists the functions and variables that a program can link from libSystem  
(`printf`, `pthread_create`, ...). The list starts with the headers of the Open SDK and is then narrowed down:

- Every function and global variable that a header declares is a candidate (`printf` from `stdio.h`),  
  under the name that the header gives the linker (on x86_64, `stat` is `_stat$INODE64`).  
  The headers are those that the Open SDK installs from the apple-oss projects ([Headers of the Open SDK](#headers-of-the-open-sdk)).
- A header can also declare what libSystem does not define (a function of another library or of the kernel).  
  So a candidate is kept only if the source code of a project that libSystem is built from names it  
  (the projects and xnu directories above: `USERLAND` in `helpers/libsystem_syms.py`).

Then names are added that the headers do not give:

- Second names under which a library exports a function (aliases): the alias lists of Libc (`xcodescripts/alias.list`),  
  libpthread (`xcodescripts/pthread.aliases`), libplatform (`xcodeconfig/libplatform.aliases`) and libdispatch  
  (`xcodeconfig/libdispatch.aliases`), and the maps of system call names of xnu (`libsyscall/Platforms/syscall.map`,  
  also per architecture).
- The raw system call stubs (`___open`, `___ulock_wait`, ...): what xnu's  
  `libsyscall/xcodescripts/create-syscalls.pl` makes (`helpers/syscall_syms.py`).
- The math functions of x86_64 that `math.h` does not declare: the export list of Libm for Intel (`Exports/libm_Intel.a.exp`).
- The functions of CommonCrypto (`CC_SHA256`, ...): libSystem re-exports libcommonCrypto (`Libsystem/requiredlibs`);  
  the public headers of CommonCrypto, as far as its `exports.exp-in` exports them.
- The functions of launchd (`launch_data_alloc`, ...): libSystem re-exports libxpc, which contains them (`Libsystem/requiredlibs`);  
  the public headers of launchd, as far as its `liblaunch/*.c` defines them,  
  and `_bootstrap_get_root` and `_bootstrap_look_up_per_user` of its `bootstrap_priv.h`.
- On x86_64 also the old plain names (`_opendir` next to `_opendir$INODE64`), which configure scripts look for:  
  Libc builds a "legacy" variant of these functions (`VARIANT_LEGACY_MACROS` in `xcodescripts/variants.xcconfig`).
- Single names added or taken out by hand, each with the file that defines it (`data/symbols/libsystem-extra.txt`,  
  `libsystem-exclude.txt`; the libcalls `__exp10` and `__sincos_stret` with LLVM's `RuntimeLibcalls.td`).

More symbols, each in a section of its own:
- The builtins of compiler-rt: [below](#compiler-rt-builtins-in-libsystembtbd).
- The functions of libunwind that no header declares: [below](#functions-of-libunwind-without-a-header).
- The private symbols that the sanitizers of compiler-rt need: [below](#private-symbols-for-the-sanitizers).
- Public functions that the scan of the headers does not find: [below](#other-symbols-of-libsystembtbd-without-a-header).
- The symbols of libxpc (full Open SDK): [below](#xpcxpch-and-its-symbols).

---

### compiler-rt builtins in `libSystem.B.tbd`

**Files:**

- `data/symbols/compiler-rt.txt`
- `lib/stubs.sh`

**Sources:**

- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6: [`compiler-rt/lib/builtins/apple_versioning.c`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/compiler-rt/lib/builtins/apple_versioning.c) (the same file in LLVM 16 to 23),  
  [`compiler-rt/lib/builtins/CMakeLists.txt`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/compiler-rt/lib/builtins/CMakeLists.txt), [`int_types.h`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/compiler-rt/lib/builtins/int_types.h), [`Darwin-excludes/osx.txt`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/compiler-rt/lib/builtins/Darwin-excludes/osx.txt)
- [Libsystem](https://github.com/apple-oss-distributions/Libsystem/tree/Libsystem-1356): [`requiredlibs`](https://github.com/apple-oss-distributions/Libsystem/blob/Libsystem-1356/requiredlibs)

**Details:**

The builtins are helper functions that code made by Clang calls for what the CPU has no instruction for  
(`__divti3` for a 128-bit division, `__muldc3` for a complex multiplication, `__atomic_*` for objects that are not lock-free).  
libSystem contains them: `Libsystem/requiredlibs` of the open source release names `compiler_rt`.
- Which builtins libSystem has: `apple_versioning.c`,  
  `NOT_HERE_BEFORE_10_6` ("Symbols in libSystem.dylib in 10.6 and later") and  
  `NOT_HERE_IN_10_8_AND_EARLIER` (the `__atomic_*` functions).  Not taken over are the sections  
  `#if __powerpc__` and `#if __arm__ && __DYNAMIC__`.  That leaves 99 + 40 names.
- Which of them each architecture has: what compiler-rt builds for it (`CMakeLists.txt`):  
  132 names for x86_64, 119 for arm64.
  - The x87 variants (12 names: `x86_80_BIT_SOURCES`) are only built for x86_64.
  - `__enable_execute_stack` is only built for x86_64: LLVM 23 has `list(REMOVE_ITEM aarch64_SOURCES enable_execute_stack.c)`  
    "Don't build enable_execute_stack on arm64 darwin" for Apple platforms (not yet in LLVM 21).

**Not in the Open SDK:** the tf variants (7 names), for both architectures: they need a 128-bit floating-point type (`CRT_HAS_TF_MODE`  
in `int_types.h`); `long double` is the x87 type on x86_64 and `double` on arm64, and Clang has no `__float128` for these targets  
(tested with Clang 23). `Darwin-excludes/osx.txt` also lists five tf builtins.

**Checks:** a check of the result, not a source of names: `libclang_rt.osx.a` of an open source build of LLVM 23.1.6  
defines the 92 (x86_64) and 79 (arm64) names of the first section and none of the names that are not in the Open SDK.

---

### Functions of libunwind without a header

**Files:**

- `data/symbols/libunwind.txt`
- `lib/stubs.sh`

**Sources:**

- apple-oss [libunwind](https://github.com/apple-oss-distributions/libunwind/tree/libunwind-201), tag `libunwind-201` (manifest): [`libunwind/src/`](https://github.com/apple-oss-distributions/libunwind/tree/libunwind-201/libunwind/src)
- [dyld](https://github.com/apple-oss-distributions/dyld/tree/dyld-1378): [`include/mach-o/dyld_priv.h`](https://github.com/apple-oss-distributions/dyld/blob/dyld-1378/include/mach-o/dyld_priv.h), [`libdyld/libdyldGlue.cpp`](https://github.com/apple-oss-distributions/dyld/blob/dyld-1378/libdyld/libdyldGlue.cpp)
- [LLVM](https://github.com/llvm/llvm-project): [`libunwind/src/libunwind.cpp`](https://github.com/llvm/llvm-project/blob/llvmorg-17.0.0/libunwind/src/libunwind.cpp) of [`llvmorg-17.0.0`](https://github.com/llvm/llvm-project/tree/llvmorg-17.0.0) (compared); [`llvm/lib/ExecutionEngine/RuntimeDyld/RTDyldMemoryManager.cpp`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/llvm/lib/ExecutionEngine/RuntimeDyld/RTDyldMemoryManager.cpp)  
  and [`llvm/lib/ExecutionEngine/Orc/TargetProcess/RegisterEHFrames.cpp`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/llvm/lib/ExecutionEngine/Orc/TargetProcess/RegisterEHFrames.cpp) of [`llvmorg-23.1.6`](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) (they call `__register_frame`)

**Details:**

Functions that libunwind (part of libSystem) exports but that no installed header declares;  
LLVM's JIT (RTDyldMemoryManager, ORC) uses them to register the unwind information of the code it makes.
- `libunwind/src/libunwind.cpp` defines `__unw_add_dynamic_fde` and  
  `__unw_remove_dynamic_fde` without `_LIBUNWIND_HIDDEN`.
  - `libunwind/src/CMakeLists.txt` compiles with `-fvisibility=hidden` only the objects of the static library  
    (`unwind_static_objects`), so the dynamic library exports them.
  - They are declared in `libunwind/src/libunwind_ext.h`, which is not installed.
  - `UnwindLevel1-gcc-ext.c` (`__register_frame`, `__deregister_frame`) calls them.
- `_unw_iterate_dwarf_unwind_cache`: `_LIBUNWIND_WEAK_ALIAS(__unw_iterate_dwarf_unwind_cache, unw_iterate_dwarf_unwind_cache)`  
  exports the alias (`_LIBUNWIND_EXPORT` in `libunwind/src/config.h`); the function itself is hidden.
- The other `__unw_*` functions are `_LIBUNWIND_HIDDEN`; their aliases `unw_*` are in `libunwind.h`.
- `_dyld_find_unwind_sections`, which libunwind calls (`libunwind/src/AddressSpace.hpp`, under `__APPLE__`),  
  is in `data/symbols/libsystem-spi.txt`: dyld's `dyld_priv.h` declares it, `libdyldGlue.cpp` defines it.

**Not in the Open SDK:** LLVM's libunwind (`llvmorg-17.0.0` and later) has the same names and four more exports  
(`__unw_add_dynamic_eh_frame_section`, `__unw_add_find_dynamic_unwind_sections` and their `remove` functions).  
Nothing open shows that macOS has them.

---

### Private symbols for the sanitizers

**Files:**

- `data/symbols/libsystem-spi.txt`
- `helpers/spi_syms.py`
- `lib/stubs.sh`

**Sources:**

- [dyld](https://github.com/apple-oss-distributions/dyld/tree/dyld-1378): [`include/mach-o/dyld_priv.h`](https://github.com/apple-oss-distributions/dyld/blob/dyld-1378/include/mach-o/dyld_priv.h), [`libdyld/libdyldGlue.cpp`](https://github.com/apple-oss-distributions/dyld/blob/dyld-1378/libdyld/libdyldGlue.cpp)
- apple-oss [libmalloc](https://github.com/apple-oss-distributions/libmalloc/tree/libmalloc-812.100.31), [libdispatch](https://github.com/apple-oss-distributions/libdispatch/tree/libdispatch-1542.100.32), [libplatform](https://github.com/apple-oss-distributions/libplatform/tree/libplatform-375.120.2): their private headers (below) and source files
- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6: [`compiler-rt/lib/`](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6/compiler-rt/lib) (which symbols the sanitizers use)

**Details:**

The sanitizers of compiler-rt (AddressSanitizer, ThreadSanitizer, ...) declare and call private functions and variables  
of libSystem that no public header declares; the list names the user of each.  
The Open SDK gets only the symbols in `libSystem.B.tbd`, no private header.  
Each symbol is declared in a private header of its project and defined in its source:
- dyld `dyld_priv.h` (`_dyld_get_shared_cache_uuid`, `_dyld_get_shared_cache_range`, `_dyld_get_image_slide`, `_dyld_find_unwind_sections`,  
  `dyld_shared_cache_iterate_text`, `_dyld_get_dyld_header`; defined in `libdyldGlue.cpp`)
- libmalloc `private/make_tapi_happy.h` (`malloc_zones`, `malloc_num_zones`)
- libdispatch `private/mach_private.h` (`dispatch_mach_create`, `dispatch_mach_create_f`)  
  and `private/layout_private.h` (`dispatch_queue_offsets`)
- libplatform `private/os/lock_private.h` (`os_unfair_lock_lock_with_options`, `os_lock_lock`, `os_lock_unlock`, `os_lock_trylock`)

**Checks:** `helpers/spi_syms.py` checks this for each release: the header must declare the name and a source file  
of the project (not a test) must name it. `_dyld_get_dyld_header` is only in the sources of macOS 26.5,  
so the other releases do not get it (compiler-rt imports it weakly).

---

### Other symbols of `libSystem.B.tbd` without a header

**Files:**

- `data/symbols/libsystem-extra.txt`
- `lib/stubs.sh`

**Sources:**

- apple-oss [Libc](https://github.com/apple-oss-distributions/Libc/tree/Libc-1752.120.2), [libplatform](https://github.com/apple-oss-distributions/libplatform/tree/libplatform-375.120.2), [Libm](https://github.com/apple-oss-distributions/Libm/tree/Libm-2026), [libpthread](https://github.com/apple-oss-distributions/libpthread/tree/libpthread-539.100.4)
- [swift-numerics](https://github.com/apple/swift-numerics/tree/eb58826429e1eae3a573a3a7b1a6ee3707b81b5f) eb58826: [`Sources/_NumericsShims/include/_NumericsShims.h`](https://github.com/apple/swift-numerics/blob/eb58826429e1eae3a573a3a7b1a6ee3707b81b5f/Sources/_NumericsShims/include/_NumericsShims.h)
- [LLVM review D40856](https://reviews.llvm.org/D40856)

**Details:**

Public functions that the scan of the headers does not find, because the header declares them only under a condition  
or as a macro; each line of the file names the source.
- `fileno_unlocked`: Libc `stdio/FreeBSD/fileno.c` (the header has only a macro).
- `_os_nospin_lock_lock`: libplatform `src/os/lock.c` (`libkern/OSSpinLockDeprecated.h` declares it only with `OSSPINLOCK_USE_INLINED=1`).
- `lgamma_r` and `lgammaf_r` for arm64: `Libm/Source/ARM/math.h` declares them only with `_REENTRANT`; `Libm/Source/ARM/lgamma.c` and `lgammaf.c` define them;  
  the export list of Libm for Intel has them; swift-numerics declares `lgamma_r` itself and links it.
- `____chkstk_darwin` (four underscores), the stack probe of Darwin that Clang calls (LLVM review D40856):  
  `libpthread/src/pthread_asm.s` defines it with `.globl` for x86_64, i386 and arm64,  
  and `src/exports_internal.h` declares the C function `___chkstk_darwin`, whose Mach-O name has the fourth underscore.

**Checks:** the prebuilt Skia of `skia-safe` references `____chkstk_darwin` (see [TESTED.md](TESTED.md)); that is a test result, not a source.

---

### libedit's readline layer

**Files:**

- `lib/libs.sh` (`libs_libedit`)

**Source:**

- apple-oss [libedit](https://github.com/apple-oss-distributions/libedit/tree/libedit-65) (the tag of `data/manifests/`, `libedit-65` for macOS 26.5): [`xcodescripts/install_misc.sh`](https://github.com/apple-oss-distributions/libedit/blob/libedit-65/xcodescripts/install_misc.sh), [`libedit.xcconfig`](https://github.com/apple-oss-distributions/libedit/blob/libedit-65/xcodescripts/libedit.xcconfig)

**Details:**

macOS has no GNU readline: `readline/readline.h` and `libreadline.tbd` are libedit under the names of readline.
- `install_misc.sh` says which files there are: `histedit.h`, `editline/readline.h`,  
  `readline/readline.h` and `readline/history.h` as links to it, and `libedit.2`, `libedit.3.0` and `libreadline`  
  as links to `libedit.3`.
- `libedit.xcconfig` says which symbols `libedit.3.tbd` has: those of `readline.h` and `histedit.h`  
  (`OTHER_TAPI_FLAGS`: `-extra-public-header readline.h histedit.h`), without the names of the project's `unexports`.

---

### Symbols of the other `.tbd`s

**Files:**

- `helpers/header_syms.py`
- `lib/libs.sh`

**Source:**

- the apple-oss project of `data/manifests/` that builds the library ([zlib](https://github.com/apple-oss-distributions/zlib/tree/zlib-100.120.1), [bzip2](https://github.com/apple-oss-distributions/bzip2/tree/bzip2-49), [libxml2](https://github.com/apple-oss-distributions/libxml2/tree/libxml2-39.10), [libxslt](https://github.com/apple-oss-distributions/libxslt/tree/libxslt-21.13), [expat](https://github.com/apple-oss-distributions/expat/tree/expat-47), [ncurses](https://github.com/apple-oss-distributions/ncurses/tree/ncurses-79), [libffi](https://github.com/apple-oss-distributions/libffi/tree/libffi-40),  
  [libedit](https://github.com/apple-oss-distributions/libedit/tree/libedit-65), [libutil](https://github.com/apple-oss-distributions/libutil/tree/libutil-73), [libarchive](https://github.com/apple-oss-distributions/libarchive/tree/libarchive-167.120.3), [libresolv](https://github.com/apple-oss-distributions/libresolv/tree/libresolv-96), ...): its installed headers and its export list where it has one  
  (`libz.exp`, `unexports`, `libutil.exports`, `libxslt.exp`, ...)

**Details:**

The symbols of each library of `/usr/lib` other than libSystem (`libz.tbd`, `libxml2.tbd`, ...):  
the functions and variables that the headers installed from its project declare (clang AST),  
narrowed to the project's export list where it has one. Per library:
- libxml2: the whole export list of the project, `Pregenerated Files/libxml2.exp` (`EXPORTED_SYMBOLS_FILE` in  
  `Configurations/libxml2.xcconfig`), not the headers.
- expat: the headers, scanned with `-DXML_DTD=1 -DXML_GE=1` (`OTHER_TAPI_FLAGS` in `expat.xcodeproj`).
- ncurses: the headers, scanned with `-DTAPI` (`COMMON_TAPI_FLAGS` in `xcodeconfig/base.xcconfig`).  
  With it `curses.h` declares each function a second time with the `$NCURSES60` name (`ifTAPI` in `curses.head`);  
  programs that use the 15.0 ABI (`NCURSES_EXPORT_ABI60` in the same header) reference these names.
- libffi: `ffi.h` and `tramp.h` (a Public header in `libffi.xcodeproj`).
- libpcap: `pcap.h`, `pcap-namedb.h` and the headers of `pcap/` that they include with functions, `pcap/pcap.h`,  
  `pcap/bpf.h` and `pcap/namedb.h`. The functions of the last two are built into the library: `bpf_dump.c`, `bpf_filter.c`,  
  `bpf_image.c`, `etherent.c` and `nametoaddr.c` are in the sources of the target of [`libpcap.xcodeproj`](https://github.com/apple-oss-distributions/libpcap/blob/libpcap-146/libpcap.xcodeproj/project.pbxproj)  
  and in `COMMON_C_SRC` of [`libpcap/Makefile`](https://github.com/apple-oss-distributions/libpcap/blob/libpcap-146/libpcap/Makefile).
- libresolv: the headers of the project and its `installapi.h`, as the project's own build does (`libresolv.xcconfig`,  
  with `-D__BIND_INSTALLAPI`), and the Private header `dns_private.h` (`libresolv.xcodeproj`; not installed in the Open SDK).

**Not in the Open SDK:** names declared with hidden visibility (`#pragma GCC visibility push(hidden)`): they are not exported.

---

### Symbols of `libiconv.2.tbd`

**Files:**

- `data/symbols/libiconv.txt`
- `lib/stubs.sh` (`stubs_libiconv`)

**Source:**

- apple-oss [libiconv](https://github.com/apple-oss-distributions/libiconv/tree/libiconv-115.120.2): its public headers

**Details:**

The functions and the variable that a program can link from libiconv, as the headers declare them:
- `citrus/iconv.h`: `iconv`, `iconv_open`, `iconv_close`, `__iconv_get_list`, `__iconv_free_list`, `__iconv`,  
  `iconv_open_into`, `libiconv_set_relocation_prefix`, `iconvlist`, `iconv_canonicalize`, `iconvctl`, `_libiconv_version`  
  (a C name: the symbol is `__libiconv_version`);
- `libcharset/localcharset.h`: `locale_charset`;
- `libcharset/libcharset.h`: `libcharset_set_relocation_prefix`.

---

### `liblzma.5.tbd`

**Files:**

- `lib/libs.sh` (`libs_lzma`)
- `lib/fetch.sh` (`fetch_xz`)
- `data/manifests/` (the `xz` line)
- `data/libraries.txt`

**Sources:**

- xz ([tukaani-project/xz](https://github.com/tukaani-project/xz), upstream): tag [`v5.0.8`](https://github.com/tukaani-project/xz/tree/v5.0.8) (pinned to its commit in the manifest): [`src/liblzma/api`](https://github.com/tukaani-project/xz/tree/v5.0.8/src/liblzma/api),  
  [`src/liblzma/Makefile.am`](https://github.com/tukaani-project/xz/blob/v5.0.8/src/liblzma/Makefile.am), [`COPYING`](https://github.com/tukaani-project/xz/blob/v5.0.8/COPYING);  
  tag [`v5.2.13`](https://github.com/tukaani-project/xz/tree/v5.2.13): [`src/liblzma/liblzma_generic.map`](https://github.com/tukaani-project/xz/blob/v5.2.13/src/liblzma/liblzma_generic.map) (and later releases)
- apple-oss [libarchive](https://github.com/apple-oss-distributions/libarchive/tree/libarchive-167.120.3): [`config.h`](https://github.com/apple-oss-distributions/libarchive/blob/libarchive-167.120.3/config.h), [`libarchive.xcodeproj`](https://github.com/apple-oss-distributions/libarchive/tree/libarchive-167.120.3/libarchive.xcodeproj)
- [libtool](https://www.gnu.org/software/libtool/): the install name of `-version-info`

**Details:**

The library of xz, only in the full Open SDK (step `libs`); liblzma is in the public domain (`COPYING`).
- Why 5.0.8: liblzma keeps the ABI of 5.0 in every later `liblzma.5`  
  (`src/liblzma/liblzma_generic.map` of later releases lists these names under `XZ_5.0`),  
  and the `config.h` of libarchive has no `HAVE_LZMA_STREAM_ENCODER_MT`,  
  the first function of 5.2. The releases 5.6.0 and 5.6.1 are avoided.
- That macOS has the library: `libarchive.xcodeproj` links `liblzma.tbd`.
- The symbols: the functions that `lzma.h` and `lzma/*.h` of `src/liblzma/api` declare (clang AST);  
  they are the `XZ_5.0` node of the map of xz 5.2.13.
- The install name `/usr/lib/liblzma.5.dylib` and current version 6.8: libtool's names  
  for `-version-info 5:8:0` (`src/liblzma/Makefile.am`).

**Not in the Open SDK:** `lzma.h`: the Open SDK has no header of liblzma; a program uses the one of its own xz.

**Chosen by the generator:** the compatibility version is the lowest possible one (1): Apple's build settings of liblzma are not public.

---

### Symbols of libc++ and libc++abi

**Files:**

- `helpers/cxx_syms.py`
- `data/symbols/libcxx-extra.txt`
- `data/symbols/libcxxabi-typed-new.txt`

**Source:**

- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-21.1.8), the release of the libc++ (21.1.8, the default of macOS 26.5; `data/libcxx-versions.txt` has the others):  
  [`libcxx/lib/abi/*.abilist`](https://github.com/llvm/llvm-project/tree/llvmorg-21.1.8/libcxx/lib/abi), [`libcxxabi/lib/*.exp`](https://github.com/llvm/llvm-project/tree/llvmorg-21.1.8/libcxxabi/lib),  
  [`libcxxabi/src/CMakeLists.txt`](https://github.com/llvm/llvm-project/blob/llvmorg-21.1.8/libcxxabi/src/CMakeLists.txt), [`libcxxabi/src/vendor/apple/shims.cpp`](https://github.com/llvm/llvm-project/blob/llvmorg-21.1.8/libcxxabi/src/vendor/apple/shims.cpp)

**Details:**

- The symbols: the ABI lists `*.abilist` and `*.exp`.
- libc++ re-exports the names of the `.exp` files of libc++abi, but not those of `libcxxabi/lib/symbols-not-reexported.exp`  
  (LLVM 19 and later; `libcxxabi/src/CMakeLists.txt`: `export_symbols`, `reexport_symbols`): they are only in `libc++abi.tbd`.
- The extra list says which header needs which symbol.
- The ten typed `operator new`/`operator delete` (with `std::__type_descriptor_t`): `shims.cpp`  
  (LLVM 19 and later; the file does not exist in LLVM 18 and earlier).  
  The libc++ headers do not declare them; they are in `libc++abi.tbd` and re-exported by `libc++.tbd`.

---

### libc++ release of each macOS release

**Files:**

- `data/releases.txt`
- `data/libcxx-versions.txt`

**Source:**

- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-22.1.8) 22.1.8: the availability table [`libcxx/include/__configuration/availability.h`](https://github.com/llvm/llvm-project/blob/llvmorg-22.1.8/libcxx/include/__configuration/availability.h)

**Details:**

Which release of libc++ each macOS release has; see the comment of `data/releases.txt`.

---

### Headers of the Open SDK

**Files:**

- `lib/headers.sh`
- `lib/stubs.sh` (CommonCrypto, launchd)
- `lib/libs.sh`
- `lib/frameworks.sh`

**Source:**

- the apple-oss projects of `data/manifests/` (tag and commit pinned) and their own install scripts

**Details:**

The headers are installed with the scripts of the projects themselves where they exist  
(xnu Makefiles, `Libc/xcodescripts/headers.sh`, `mach_install_mig.sh`,  
`AvailabilityVersions/availability`, ncurses `bootstrap_headers.sh`).

---

### Repairs of those headers

**Files:**

- `lib/headers.sh` (`headers_fixups`)
- `lib/cxx.sh`

**Source:**

- none, own work

**Details:**

Each repair is shown in the code with the reason.  
Each repaired file carries a notice (APSL 2.0 section 2.2).

---

### `__exp10`, `__exp10f` in `math.h`

**Files:**

- `lib/headers.sh`

**Source:**

- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6: [`llvm/include/llvm/IR/RuntimeLibcalls.td`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/llvm/include/llvm/IR/RuntimeLibcalls.td) (the libcalls of `DarwinExp10`)

**Details:**

The declarations of `__exp10` and `__exp10f`, which Clang calls for `exp10` and `pow(10, x)`;  
Libm does not declare them. Their names and signatures are those of `RuntimeLibcalls.td`.

---

### `TargetConditionals.h`

**Files:**

- `data/headers/usr/include/TargetConditionals.h`

**Sources:**

- [CarbonHeaders-18.1](https://github.com/apple-oss-distributions/CarbonHeaders/tree/CarbonHeaders-18.1): [`TargetConditionals.h`](https://github.com/apple-oss-distributions/CarbonHeaders/blob/CarbonHeaders-18.1/TargetConditionals.h)
- the apple-oss projects [dyld](https://github.com/apple-oss-distributions/dyld/tree/dyld-1378), [CF](https://github.com/apple-oss-distributions/CF/tree/CF-1153.18), [Security](https://github.com/apple-oss-distributions/Security/tree/Security-61901.120.67), [libmalloc](https://github.com/apple-oss-distributions/libmalloc/tree/libmalloc-812.100.31), [xnu](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6), [mDNSResponder](https://github.com/apple-oss-distributions/mDNSResponder/tree/mDNSResponder-2881.120.11), [objc4](https://github.com/apple-oss-distributions/objc4/tree/objc4-951.7): the macros they use
- [Clang](https://github.com/llvm/llvm-project): its predefined macros

**Details:**

`TargetConditionals.h` defines the macros that tell code for which system and CPU it is built  
(`TARGET_OS_OSX`, `TARGET_CPU_ARM64`, ...). Own text (0BSD): CarbonHeaders-18.1 has an old `TargetConditionals.h`  
without the macros of the current systems, and the one of CF is for Linux.
- The names: `CarbonHeaders/TargetConditionals.h` (`TARGET_CPU_*`, `TARGET_RT_*`, `TARGET_OS_MAC`, ...) and the macros that  
  open source projects use (`TARGET_OS_OSX`, `TARGET_OS_IOS`, `TARGET_OS_SIMULATOR`, `TARGET_OS_MACCATALYST`, `TARGET_OS_XR`,  
  `TARGET_OS_DRIVERKIT`, `TARGET_OS_LINUX` in the projects above).
- The values: the compiler's predefined macros (the CPU from `__x86_64__`, `__arm64__`, ...; the header describes macOS only).

**Not in the Open SDK:** a macro that no open source file names.

---

### `architecture/arm64/fenv.h`

**Files:**

- `data/headers/usr/include/architecture/arm64/fenv.h`

**Sources:**

- apple-oss [Libm](https://github.com/apple-oss-distributions/Libm/tree/Libm-2026) [`Source/ARM/fenv.h`](https://github.com/apple-oss-distributions/Libm/blob/Libm-2026/Source/ARM/fenv.h)
- the Arm Architecture Reference Manual
- [xnu](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6) [`osfmk/mach/arm/_structs.h`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/osfmk/mach/arm/_structs.h)

**Details:**

The floating-point environment of arm64 (`fenv_t`, `FE_TONEAREST`, ... for `fegetenv` and the like):
- The constants, `fexcept_t` and the size of `fenv_t`: `Libm/Source/ARM/fenv.h`.
- The bit positions of FPSR and FPCR: the Arm Architecture Reference Manual.
- The field names `__fpsr` and `__fpcr`: `xnu/osfmk/mach/arm/_structs.h` (`struct __darwin_arm_neon_state64`).

---

### `libDER/DERItem.h`, `libDER/libDER_config.h`

**Files:**

- `lib/frameworks.sh`
- `data/headers/usr/include/libDER/DERItem.h` (the own file for the releases before 26.5)

**Source:**

- [xnu](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6): [`EXTERNAL_HEADERS/libDER/`](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6/EXTERNAL_HEADERS/libDER) (APSL 2.0)

**Details:**

`oids.h` of apple-oss Security needs them.  
They are copied unchanged from `xnu/EXTERNAL_HEADERS/libDER/` where xnu has them (macOS 26.5).  
For the earlier releases `data/headers/usr/include/libDER/DERItem.h` is an own file with the same typedefs and struct  
(its comment names the xnu header).

---

### `os/log.h`

**Files:**

- `data/headers/usr/include/os/log.h`
- `data/symbols/libsystem-extra.txt`

**Sources:**

- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6: [`clang/include/clang/Basic/Builtins.td`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/clang/include/clang/Basic/Builtins.td) (Apache-2.0 with LLVM exception)
- [swift-5.2.5-RELEASE](https://github.com/swiftlang/swift/tree/swift-5.2.5-RELEASE): [`stdlib/public/Darwin/os/`](https://github.com/swiftlang/swift/tree/swift-5.2.5-RELEASE/stdlib/public/Darwin/os) (Apache-2.0 with Runtime Library Exception)
- [xnu](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6): [`libkern/os/log.h`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/libkern/os/log.h), [`config/Libkern.exports`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/config/Libkern.exports)
- [configd](https://github.com/apple-oss-distributions/configd/tree/configd-1405.120.5): [`SystemConfiguration.fproj/SCD.c`](https://github.com/apple-oss-distributions/configd/blob/configd-1405.120.5/SystemConfiguration.fproj/SCD.c)
- [Libsystem](https://github.com/apple-oss-distributions/Libsystem/tree/Libsystem-1356): [`init.c`](https://github.com/apple-oss-distributions/Libsystem/blob/Libsystem-1356/init.c)

**Details:**

`os_log` is the logging interface of macOS (`os_log(OS_LOG_DEFAULT, "...")`); programs write messages to the system log with it.  
Own text (0BSD). The format string is an ordinary C string literal; no section name of Apple's is used.
- The builtins `__builtin_os_log_format` and `__builtin_os_log_format_buffer_size`: LLVM's `Builtins.td`.
- The call `_os_log_impl(dso, log, type, format, buffer, length)`: swift-5.2.5-RELEASE `stdlib/public/Darwin/os/os.m`  
  (`_swift_os_log`), and the type of `length` (`uint32_t`) from `ob_len` of `os_trace_blob.h` in the same directory.
- `os_log_t`, `os_log_create(const char *subsystem, const char *category)`, the values of `OS_LOG_TYPE_DEFAULT` 0x00,  
  `INFO` 0x01, `DEBUG` 0x02, `ERROR` 0x10, `FAULT` 0x11 (type `uint8_t`), `OS_LOG_DEFAULT` as the object `_os_log_default`,  
  `OS_LOG_DISABLED` as `NULL`, `__dso_handle`: xnu `libkern/os/log.h` (kernel copy, APSL 2.0; only these facts, no text).
- The exports `__os_log_default`, `_os_log_create`: xnu `config/Libkern.exports`.
- `os_log_type_enabled(log, type)` and its use: configd `SCD.c` (line 590).
- That the symbols are in libSystem: `libsystem_trace.dylib` is part of it, `Libsystem/init.c` (`_libtrace_init`).

**Checks:** whether the result runs (messages with the right type and arguments in `log show`) was tested on macOS;  
that is a test result, not a source.

---

### `os/signpost.h`, `os/activity.h`, `os/trace.h`

**Files:**

- `data/headers/usr/include/os/` (`signpost.h`, `activity.h`, `trace.h`)

**Sources:**

- [swift-5.2.5-RELEASE](https://github.com/swiftlang/swift/tree/swift-5.2.5-RELEASE): [`stdlib/public/SwiftShims/OSOverlayShims.h`](https://github.com/swiftlang/swift/blob/swift-5.2.5-RELEASE/stdlib/public/SwiftShims/OSOverlayShims.h), [`stdlib/public/Darwin/os/os_signpost.swift`](https://github.com/swiftlang/swift/blob/swift-5.2.5-RELEASE/stdlib/public/Darwin/os/os_signpost.swift)
- apple-oss [Security](https://github.com/apple-oss-distributions/Security/tree/Security-61901.120.67): files that call these interfaces (APSL 2.0)
- [xnu](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6): [`libkern/os/trace.h`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/libkern/os/trace.h) (APSL 2.0)

**Details:**

Interfaces for tracing (signposts mark intervals for Instruments, activities group log messages).  
The headers are no-op stand-ins, nothing crosses into the system: no symbol is imported, no value reaches a system function,  
nothing is traced. Own text (0BSD).
- Names and values that a public source states: `OS_SIGNPOST_ID_NULL`, `OS_SIGNPOST_ID_INVALID`, `OS_SIGNPOST_ID_EXCLUSIVE`  
  (`0xEEEEB0B5B2B2EEEE`), `OS_LOG_CATEGORY_POINTS_OF_INTEREST` and the 64-bit type of `os_signpost_id_t`: `OSOverlayShims.h`.
- The names `OS_SIGNPOST_EVENT`, `OS_SIGNPOST_INTERVAL_BEGIN`, `OS_SIGNPOST_INTERVAL_END`, `os_signpost_enabled`,  
  `os_signpost_id_generate`, `os_signpost_id_make_with_pointer`: `os_signpost.swift`.
- The names and the form of the calls `os_signpost_event_emit`, `os_signpost_interval_begin/_end`, `os_signpost_emit_with_type`,  
  `OS_SIGNPOST_ENABLE_TELEMETRY`: Security (`keychain/SigninMetrics/OctagonSignPosts.h`, `OSX/utilities/SecDbStats.c`).
- The names and the form of the calls `os_activity_t`, `os_activity_create`, `OS_ACTIVITY_CURRENT`, `OS_ACTIVITY_FLAG_DEFAULT`,  
  `OS_ACTIVITY_FLAG_IF_NONE_PRESENT`, `os_activity_scope`, `os_activity_scope_enter/_leave`, `struct os_activity_scope_state_s`,  
  `os_activity_initiate`: Security (`OSX/sec/Security/SecTrust.c`, `SecLogging.c`, `OSX/include/security_keychain/SecItem.cpp`).
- The names and form of `os_trace`, `os_trace_info`, `os_trace_debug`, `os_trace_error`, `os_trace_fault`,  
  `os_trace_info_enabled`, `os_trace_debug_enabled`: xnu `libkern/os/trace.h` (names only).

**Chosen by the generator:** used only inside these headers: the numbers of `os_signpost_type_t` (1, 2, 3),  
the values of `os_activity_flag_t` (0 and 2), the size of `struct os_activity_scope_state_s`,  
the empty string of `OS_SIGNPOST_ENABLE_TELEMETRY`. `os_activity_create` returns `NULL`; the objects of the system are not made.

---

### `xpc/xpc.h` and its symbols

**Files:**

- `data/headers/usr/include/xpc/xpc.h`
- `data/symbols/libsystem-xpc.txt`
- `lib/stubs.sh` (`stubs_xpc`)

**Sources:**

- Apple's [XPC documentation](https://developer.apple.com/documentation/xpc)
- [WebKit](https://github.com/WebKit/WebKit/tree/4940531db2fa) 4940531 (Apple's own open source project):  
  [`Source/WTF/wtf/spi/darwin/XPCSPI.h`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Source/WTF/wtf/spi/darwin/XPCSPI.h) (BSD-2-Clause; facts only, no text)
- [Libsystem](https://github.com/apple-oss-distributions/Libsystem/tree/Libsystem-1356): [`requiredlibs`](https://github.com/apple-oss-distributions/Libsystem/blob/Libsystem-1356/requiredlibs), [`xcodescripts/linker_arguments.sh`](https://github.com/apple-oss-distributions/Libsystem/blob/Libsystem-1356/xcodescripts/linker_arguments.sh)

**Details:**

XPC is the interface of macOS for messages between processes (`xpc_connection_create`, `xpc_dictionary_create`, ...).  
Own text (0BSD), full Open SDK only. Apple publishes no source code of libxpc. libSystem re-exports it, so its symbols are in `libSystem.B.tbd`:  
`Libsystem/requiredlibs` lists `xpc`, and `linker_arguments.sh` links each of them with `-Wl,-reexport-l<lib>`.
- The functions and variables, their parameters and the release that brought each one:  
  the documentation, the C declaration on the page of each name.  
  152 names from macOS 12.0 or earlier and 16 of sessions, listeners and rich errors (13.0 and 14.0), all in the full Open SDK of 14.3 and later; each has `API_AVAILABLE` with its release.
- The object and block types, `XPC_GLOBAL_OBJECT`, `XPC_ARRAY_APPEND`, `XPC_CONNECTION_MACH_SERVICE_LISTENER` (`1 << 0`),  
  the order of the activity states and the 11 variables behind `XPC_TYPE_*`, `XPC_ERROR_*` and  
  `XPC_ERROR_KEY_DESCRIPTION`: WebKit's `XPCSPI.h`.
- Which functions return an object that the caller releases (`OS_OBJECT_RETURNS_RETAINED`): the names with create or copy,  
  and `xpc_connection_send_message_with_reply_sync`, whose page says so.

#### Sessions, listeners and rich errors (macOS 13.0 and 14.0)

- The Objective-C pages of the documentation (fetched 2026-11-27) give the C declarations and the releases.
- The types of the blocks and the types `xpc_session_t` (`OS_xpc_session`) and `xpc_listener_t` (`OS_xpc_listener`):  
  the Swift pages of the same names.
- The `create` functions return a retained object (their pages say to call `xpc_release`); the other results are not annotated  
  (a result that the caller releases but the header does not say leaks under ARC; the opposite crashes).
- `xpc_rich_error_can_retry` and `xpc_rich_error_copy_description` have no release on their pages.
- The flags: the pages name `none`, `inactive`, `privileged` (session) and `none`, `inactive` (listener) in Swift and  
  `XPC_SESSION_CREATE_INACTIVE`, `XPC_LISTENER_CREATE_INACTIVE` in the text, but give no value, no C type and no other C name.  
  The open projects that name values (rama, objc2, pyobjc) take them from Apple's headers, so they are no source.

**Not in the Open SDK (no public value):**
- `XPC_TYPE_*` of the other types (the documentation names the macros, not their variables),  
  `XPC_BOOL_TRUE`/`FALSE`, `XPC_CONNECTION_MACH_SERVICE_PRIVILEGED`, `XPC_EVENT_KEY_NAME`.
- The flags of sessions and listeners (see above).
- The functions of macOS 14.4 and later (peer requirements; the full Open SDK of 14.3 must not have them).
- `XPC_TYPE_SESSION`, `XPC_TYPE_LISTENER`, `XPC_TYPE_RICH_ERROR` (no public variable behind them).

**Chosen by the generator:**
- the release 14.0 of `xpc_rich_error_can_retry` and `xpc_rich_error_copy_description` (their pages give none): that of  
  `XPC_TYPE_RICH_ERROR` (the sessions of 13.0 return rich errors, so 13.0 is possible);
- the types `xpc_session_create_flags_t` and `xpc_listener_create_flags_t` are `uint64_t`,  
  wide enough for any enumeration, so that a call with 0 or any value of the real type passes it correctly.

**Checks:** `data/symbols/libsystem-xpc.txt` names the source and release of every symbol; the step stubs stops if the declarations  
of the header differ from the list.

---

### C headers of the scans

**Files:**

- `helpers/clang_scan.py`

**Sources:**

- ISO C99 (7.15, 7.16, 5.2.4.2.2)
- C11 (5.2.4.2.2)
- [Clang](https://github.com/llvm/llvm-project)'s builtins and predefined macros

**Details:**

The symbol scans (`header_syms.py`, `libsystem_syms.py`) need `stdbool.h`, `stdarg.h` and `float.h`.  
The Open SDK does not contain them, the compiler provides them;  
the `clang` of FreeBSD and OpenBSD does not (the system's own headers are in `/usr/include`).  
Only a header that is missing is supplied, in a temporary directory that is not part of the Open SDK.
- `stdbool.h`: ISO C99 7.16.
- `stdarg.h`: ISO C99 7.15, with the `__builtin_va_*` functions of Clang.
- `float.h`: ISO C99 and C11 5.2.4.2.2, with the macros that Clang predefines (`__DBL_MAX__` and so on).

---

### `CoreFoundation.modulemap`, `CFCompat.h.in`

**Files:**

- `data/headers/System/Library/Frameworks/CoreFoundation.framework/Versions/A/Modules/module.modulemap`
- `data/CFCompat.h.in`

**Sources:**

- [swift-corelibs-foundation](https://github.com/swiftlang/swift-corelibs-foundation/tree/swift-6.0-RELEASE), tag swift-6.0-RELEASE: [`Sources/CoreFoundation/include/CFBase.h`](https://github.com/swiftlang/swift-corelibs-foundation/blob/swift-6.0-RELEASE/Sources/CoreFoundation/include/CFBase.h), [`CFAvailability.h`](https://github.com/swiftlang/swift-corelibs-foundation/blob/swift-6.0-RELEASE/Sources/CoreFoundation/include/CFAvailability.h) (Apache 2.0)
- [AvailabilityVersions](https://github.com/apple-oss-distributions/AvailabilityVersions/tree/AvailabilityVersions-157.2): [`Availability.h`](https://github.com/apple-oss-distributions/AvailabilityVersions/blob/AvailabilityVersions-157.2/templates/Availability.h)
- apple-oss [CF-1153.18](https://github.com/apple-oss-distributions/CF/tree/CF-1153.18): [`CFAvailability.h`](https://github.com/apple-oss-distributions/CF/blob/CF-1153.18/CFAvailability.h) (APSL 2.0)
- the apple-oss projects [DiskArbitration](https://github.com/apple-oss-distributions/DiskArbitration/tree/DiskArbitration-535.120.1.0.1), [configd](https://github.com/apple-oss-distributions/configd/tree/configd-1405.120.5) ([`SystemConfiguration.fproj`](https://github.com/apple-oss-distributions/configd/tree/configd-1405.120.5/SystemConfiguration.fproj)), [Security](https://github.com/apple-oss-distributions/Security/tree/Security-61901.120.67): the macros their headers use
- [Clang's documentation](https://clang.llvm.org/docs/Modules.html#module-map-language): "Module Map Language"

**Details:**

- `CFCompat.h.in` is appended to `CFAvailability.h` of apple-oss CF (APSL 2.0): the macros that the headers of  
  DiskArbitration, SystemConfiguration and Security use, but the older `CFAvailability.h` does not define.
  - Which macros: the headers of these projects, which use them.
  - Their definitions (`CF_ASSUME_NONNULL_*`, `CF_BRIDGED_TYPE`, `CF_IMPLICIT_BRIDGING_*`, `CF_SWIFT_NAME`, `CF_SWIFT_UNAVAILABLE`,  
    `CF_CLOSED_ENUM`, `CF_STRING_ENUM` and `CF_EXTENSIBLE_STRING_ENUM` (`swift_wrapper`), `CF_ENUM` and `CF_OPTIONS`  
    with one argument): swift-corelibs-foundation's `CFBase.h` and `CFAvailability.h`.
  - `CF_AVAILABLE` and the like through `__OSX_AVAILABLE_STARTING`: `Availability.h` of AvailabilityVersions.
- `module.modulemap` lets Clang and Swift import CoreFoundation as a module: own text (0BSD),  
  a framework module as Clang's documentation of modules describes it.

---

### Newer CoreFoundation declarations and symbols

**Files:**

- `data/CF/`
- `helpers/apply_diff.py`
- `data/symbols/doc/CoreFoundation.txt`
- `tools/doc_symbols.py`
- `data/licenses/swift-corelibs-foundation-LICENSE.txt`
- `lib/frameworks.sh`

**Sources:**

- [swift-corelibs-foundation](https://github.com/swiftlang/swift-corelibs-foundation/tree/swift-6.4.3-RELEASE), tag swift-6.4.3-RELEASE (8ddfb630bbb5):  
  [`Sources/CoreFoundation/include`](https://github.com/swiftlang/swift-corelibs-foundation/tree/swift-6.4.3-RELEASE/Sources/CoreFoundation/include) (Apache 2.0 with Runtime Library Exception)
- [Apple's documentation of Core Foundation](https://developer.apple.com/documentation/corefoundation) (fetched 2026-11-26 and 2026-11-27)
- apple-oss [CF-1153.18](https://github.com/apple-oss-distributions/CF/tree/CF-1153.18) (`data/manifests/`): headers, [`CFSocketStream.c`](https://github.com/apple-oss-distributions/CF/blob/CF-1153.18/CFSocketStream.c)
- [xnu](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6): [`osfmk/mach/machine.h`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/osfmk/mach/machine.h)

**Details:**

The base is CF-1153.18, which has none of the APIs that came after 2018 (`CFDateFormatterCreateISO8601Formatter`, for example).  
The newer declarations come from swift-corelibs-foundation; Apple's documentation decides which of them are taken over.

#### Newer declarations

Each file that has text of swift-corelibs-foundation carries a `Modified by osxcross-open-sdk` line that names the source.
- `data/CF/CFNotificationCenter.h` and `data/CF/CFAttributedString.h`: the headers of that project, with the  
  includes written as in a framework (`<CoreFoundation/...>`); `CFNotificationCenterGetDistributedCenter` is  
  declared for `TARGET_OS_OSX` only (the project's `TARGET_OS_OSX || TARGET_OS_WIN32` is for its Windows port).  
  `CoreFoundation.h` includes both.
- `data/CF/additions.patch` (a unified diff of the CF-1153.18 headers, applied by `helpers/apply_diff.py`):  
  in `CFBase.h` the version numbers of 10.10 and 10.11, in `CFBundle.h` `CFBundleIsExecutableLoadable`,  
  `CFBundleIsExecutableLoadableForURL`, `CFBundleIsArchitectureLoadable` and `kCFBundleExecutableArchitectureARM64`,  
  in `CFDateFormatter.h` `CFISO8601DateFormatOptions` and `CFDateFormatterCreateISO8601Formatter`, in `CFError.h`  
  `kCFErrorLocalizedFailureKey`, in `CFNumberFormatter.h` the four styles of 10.11, in `CFURL.h` the resource keys  
  of 10.11 to 11.3 and two bookmark options, in `CFUserNotification.h` the two keys that CF-1153.18 declares  
  only for iOS.

#### Typed declarations

`data/CF/typed.patch` (applied after `additions.patch`): the typed declarations of the project's headers that Apple's  
documentation shows as well (the Swift declarations of its pages give the type names and the optionality  
of every parameter and result):
- the aliases `CFLocaleIdentifier`, `CFLocaleKey`, `CFCalendarIdentifier`, `CFRunLoopMode`, `CFErrorDomain`,  
  `CFDateFormatterKey`, `CFNumberFormatterKey` and `CFStreamPropertyKey` (`CF_STRING_ENUM` or  
  `CF_EXTENSIBLE_STRING_ENUM`) and `CFNotificationName` (in `CFLocale.h` and `CFTimeZone.h`) in the places  
  where the project uses them; the pages of the constants are members of the alias pages (`cflocalekey/...`);
- `CFRunLoopRunResult` as the result of `CFRunLoopRunInMode`;
- the enumerations with a type but no name (`CF_ENUM(CFOptionFlags) {`) of `CFCalendar.h`, `CFMessagePort.h`,  
  `CFPropertyList.h`, `CFSocket.h` and `CFUserNotification.h` (the pages type their constants `CFOptionFlags`,  
  `Int32` and `CFIndex`);
- `CF_ASSUME_NONNULL_BEGIN/END` and `_Nullable` in `CFPreferences.h`, `_Null_unspecified` in `CFStream.h`  
  (the pages show `?` and `!`; the other headers have no annotation in the project).

#### What was taken over

Apple's documentation decides: a declaration of the project's header that it lists for macOS  
(the page of each name is in the documentation's JSON; the page names the module "Core Foundation" and macOS).  
The release in each `API_AVAILABLE(macos(...))` is the `introducedAt` of that page (the project writes `10.16` for `11.0`).

#### Values

Every enumerator and constant that both CF-1153.18 and the project's headers have  
is the same (compared with Clang's AST of both header sets: no difference). The documentation's pages give names, kinds and  
releases but no values, so the values of the added enumerators have the project as their only source;  
one of them can be checked in open code: `kCFBundleExecutableArchitectureARM64` is `CPU_TYPE_ARM64` (xnu `osfmk/mach/machine.h`).

#### Symbols of `CoreFoundation.tbd`

- The symbols of `CoreFoundation.tbd` come from the headers as before. `data/symbols/doc/CoreFoundation.txt` adds  
  the C functions and global data that the documentation lists for macOS and that no header of the Open SDK names  
  (made by `tools/doc_symbols.py --headers <Headers of a built Open SDK> CoreFoundation`; the list says  
  which day the pages were fetched, and the release of each name, which the generator applies:  
  the Open SDK of 14.3 has none of 15.0 or later). Functions that headers define inline (`CFSwapInt32`, ...) and  
  `kCFNotFound` are in the documentation too and are not exported; the headers name them, so the list leaves them out.
- The stream constants (`kCFStreamPropertySOCKSProxy`, `kCFStreamSocketSecurityLevel...`, `kCFStreamErrorDomainSSL`, ...)  
  are in the list although no header of the Open SDK declares them: the documentation names the module "Core Foundation",  
  and CF-1153.18's own `CFSocketStream.c` defines them (`CONST_STRING_DECL`).
- `CoreFoundation.tbd`'s `current-version` stays 1153.18 (the version of the source of the library, not of the headers).

#### Not in the Open SDK

- Nothing else of the project's headers: `CF_NOESCAPE`, `CF_BRIDGED_MUTABLE_TYPE`, the types of `CFLog` and `CFUniChar`,  
  and everything that the documentation does not list (`CFDateComponents`, `CFDateInterval`, `CFRunArray`,  
  `CFLogUtilities.h`, `kCFLocaleTemperatureUnitKey`, the private headers, `CFStream.h`'s SOCKS names).
- What is written for the Swift runtime or other systems: `Boolean` as `bool`, `kCFNotFound` as a `static const`  
  (CF-1153.18 and Apple's have an enumerator), `TARGET_OS_WASI`, `TARGET_OS_BSD`, `TARGET_OS_WIN32`,  
  `DEPLOYMENT_RUNTIME_SWIFT`, `CF_SWIFT_*`, `_CF*` functions of `ForSwiftFoundationOnly.h`, `CF_PRIVATE`.

---

### `CoreServices/FSEvents.h` and its symbols

**Files:**

- `data/headers/System/Library/Frameworks/CoreServices.framework/Versions/A/Headers/`
- `data/symbols/CoreServices-fsevents.txt`
- `lib/frameworks.sh`

**Sources:**

- Apple's documentation of [File System Events](https://developer.apple.com/documentation/coreservices/file_system_events)  
  and of the module [Core Services](https://developer.apple.com/documentation/coreservices)
- fsevent-sys ([octplane/fsevent-rust](https://github.com/octplane/fsevent-rust/tree/8a5d1684e0c423efdc2ebf7ec50b4c56143a3441) 8a5d168): [`fsevent-sys/src/fsevent.rs`](https://github.com/octplane/fsevent-rust/blob/8a5d1684e0c423efdc2ebf7ec50b4c56143a3441/fsevent-sys/src/fsevent.rs) (MIT)
- [dotnet/macios](https://github.com/dotnet/macios/tree/908ef972fc3fc5e822839a9d97643e43bfa5574f) 908ef97: [`src/CoreServices/FSEvents.cs`](https://github.com/dotnet/macios/blob/908ef972fc3fc5e822839a9d97643e43bfa5574f/src/CoreServices/FSEvents.cs) (MIT; written by hand, author and copyright in its head; facts only, the C names of the flags are not there)
- [libuv](https://github.com/libuv/libuv/tree/de4c8602d54255c4e7f3fa91dd6f44b682679724) de4c860: [`src/unix/darwin-stub.h`](https://github.com/libuv/libuv/blob/de4c8602d54255c4e7f3fa91dd6f44b682679724/src/unix/darwin-stub.h) (MIT)
- [`git`](https://github.com/git/git/tree/acba8bf9753134d9bde89f94369f775838a8c5fe) acba8bf: [`compat/fsmonitor/fsm-listen-darwin.c`](https://github.com/git/git/blob/acba8bf9753134d9bde89f94369f775838a8c5fe/compat/fsmonitor/fsm-listen-darwin.c), [`config.mak.uname`](https://github.com/git/git/blob/acba8bf9753134d9bde89f94369f775838a8c5fe/config.mak.uname)
- [`fswatch`](https://github.com/emcrisostomo/fswatch/tree/40dfff9) 40dfff9: [`libfswatch/CMakeLists.txt`](https://github.com/emcrisostomo/fswatch/blob/40dfff9/libfswatch/CMakeLists.txt), [`fsevents_monitor.cpp`](https://github.com/emcrisostomo/fswatch/blob/40dfff9/libfswatch/src/libfswatch/c++/fsevents_monitor.cpp)
- Go [`fsnotify/fsevents`](https://github.com/fsnotify/fsevents/tree/v0.2.0) v0.2.0 (f73112e): [`wrap.go`](https://github.com/fsnotify/fsevents/blob/v0.2.0/wrap.go)
- ld64 of [cctools-port](https://github.com/tpoechtrager/cctools-port/tree/ef969083aecf77dee1814d6961a06b88af23edef) ef96908: [`cctools/ld64/src/ld/Options.cpp`](https://github.com/tpoechtrager/cctools-port/blob/ef969083aecf77dee1814d6961a06b88af23edef/cctools/ld64/src/ld/Options.cpp) (`Options::findFile`)

**Details:**

FSEvents tells a program which files and directories changed (`FSEventStreamCreate`, ...); `git`, `fswatch` and file watchers use it.  
Own text (0BSD), full Open SDK only. Apple publishes no source code of CoreServices. `CoreServices.h` includes only `FSEvents.h`.
- The functions, types, the fields of `FSEventStreamContext`, the constants and the release that brought each one:  
  the documentation of File System Events, the C declaration on the page of each name. It shows the flags and  
  `kFSEventStreamEventIdSinceNow` as enumerators and the keys of the extended data as macros, so the 22 functions are the only symbols.
- The values of the flags and of `kFSEventStreamEventIdSinceNow`, the order of the fields of `FSEventStreamContext`,  
  and `kFSEventStreamCreateFlagUseExtendedData`, `kFSEventStreamCreateFlagFullHistory` and `kFSEventStreamEventFlagItemCloned`,  
  which the documentation does not list: fsevent-sys. The same values, and the strings of  
  `kFSEventStreamEventExtendedDataPathKey` (`"path"`) and `kFSEventStreamEventExtendedFileIDKey` (`"fileID"`): dotnet/macios.  
  Part of the values are also in libuv; `kFSEventStreamEventFlagItemCloned` also in `git`.
- The other symbols of the stub: the module Core Services of Apple's documentation, as for the other stubs  
  (made by `tools/doc_symbols.py`, see [Link stubs](#link-stubs-from-apples-documentation); the page of each symbol is in its line of `data/symbols/doc/CoreServices.txt`).
- The stub re-exports `CoreFoundation` (`reexported-libraries`, install name from `data/libraries.txt`);  
  ld64 looks it up at that path (`Options::findFile`), so `CoreFoundation.framework/Versions/A/CoreFoundation.tbd` is the file,  
  see [framework layout](#framework-layout-and-cocoaframework).
- Why CoreServices re-exports CoreFoundation: open projects link only `-framework CoreServices` (`git`: `config.mak.uname`;  
  `fswatch`: `libfswatch/CMakeLists.txt`; `fsnotify/fsevents`: `wrap.go`) and call CF functions  
  (`CFStringCreateWithCString` and `CFArrayCreate` in `fsm-listen-darwin.c`, `CFRunLoopGetCurrent` in `fsevents_monitor.cpp`,  
  `CFArrayCreateMutable` in `wrap.go`), so they rely on it (default branches as of 2026-11-26).

**Not in the Open SDK:**
- The flags `WithDocId` and `DeviceState` of dotnet/macios: no C name in these sources.
- `kFSEventStreamEventExtendedDocIDKey`: the documentation lists it for macOS 14.0 and dotnet/macios gives `"docID"`,  
  but it is not taken over yet.

**Checks:** `data/symbols/CoreServices-fsevents.txt` names the source and release of every symbol; the step frameworks stops  
if the declarations of the header differ from the list.

---

### Security names of macOS 27.0

**Files:**

- `data/symbols/doc/Security.txt`
- `lib/frameworks.sh` (`fw_tbd`)

**Sources:**

- Apple's [documentation of Security](https://developer.apple.com/documentation/security) (fetched 2026-11-27)
- apple-oss [Security-61901.120.67](https://github.com/apple-oss-distributions/Security/tree/Security-61901.120.67) (the open source release of macOS 26.5)

**Details:**

- The names that the documentation lists for Security and that Security-61901.120.67 lacks:  
  four variables (`kSecCFErrorDetachedCertificates`, `kSecCodeInfoChosenSignature`, `kSecCodeInfoSignerInfoSKID`, `kSecCodeInfoTotalSignatures`),  
  five `errSecCS*` enumerators, `kSecCSMaxSignatures` and the enumerators of `SecQWACTLSBindingError`.
- Their pages say macOS 10.0, which is no release (the same pages say iOS 2.0 and visionOS 1.0).  
  The open source release of 26.5 ends at `errSecCSRemoteSignerFailed` (-66990) and has none of them,  
  so they are newer than 26.5.
- The generator has no Open SDK of 27.0, so no `.tbd` has the variables yet (`data/symbols/doc/Security.txt` names the release)  
  and the headers do not declare the enumerators (their values have no public source); they come with such an Open SDK.
- Not gaps: `SecTransformCustomGetAttribute` is exported as `_SecTranformCustomGetAttribute` (the `__asm__` name in `SecCustomTransform.h`),  
  and `sec_object_t` is declared by `SecProtocolObject.h`.

**Chosen by the generator:** the release 27.0 of these names: the conservative choice, as they are newer than 26.5.

---

### `IOKit` device families

**Files:**

- `lib/frameworks.sh` (`iokit_families`, `fw_tbd`)
- `data/USBCompat.h.in`
- `helpers/write_licenses.py`

**Sources:**

- [IOKitUser](https://github.com/apple-oss-distributions/IOKitUser/tree/IOKitUser-100231.120.3): [`Modules/IOKit.modulemap`](https://github.com/apple-oss-distributions/IOKitUser/blob/IOKitUser-100231.120.3/Modules/IOKit.modulemap), the target `IOKit` of its Xcode project
- the Xcode projects of [IOStorageFamily](https://github.com/apple-oss-distributions/IOStorageFamily/tree/IOStorageFamily-337.100.1), [IOCDStorageFamily](https://github.com/apple-oss-distributions/IOCDStorageFamily/tree/IOCDStorageFamily-62), [IODVDStorageFamily](https://github.com/apple-oss-distributions/IODVDStorageFamily/tree/IODVDStorageFamily-46), [IOBDStorageFamily](https://github.com/apple-oss-distributions/IOBDStorageFamily/tree/IOBDStorageFamily-26), [IOHIDFamily](https://github.com/apple-oss-distributions/IOHIDFamily/tree/IOHIDFamily-2238.120.5), [IOGraphics](https://github.com/apple-oss-distributions/IOGraphics/tree/IOGraphics-600)
- [IOUSBFamily](https://github.com/apple-oss-distributions/IOUSBFamily/tree/IOUSBFamily-560.4.2) 560.4.2 (headers); [630.4.5](https://github.com/apple-oss-distributions/IOUSBFamily/tree/IOUSBFamily-630.4.5) (compared; [`Headers/USBHub.h`](https://github.com/apple-oss-distributions/IOUSBFamily/blob/IOUSBFamily-630.4.5/IOUSBFamily/Headers/USBHub.h), [`Classes/AppleUSBOHCI_RootHub.cpp`](https://github.com/apple-oss-distributions/IOUSBFamily/blob/IOUSBFamily-630.4.5/AppleUSBOHCI/Classes/AppleUSBOHCI_RootHub.cpp),  
  [`Classes/AppleUSBUHCI_RootHub.cpp`](https://github.com/apple-oss-distributions/IOUSBFamily/blob/IOUSBFamily-630.4.5/AppleUSBUHCI/Classes/AppleUSBUHCI_RootHub.cpp), [`Classes/AppleUSBEHCIHubInfo.cpp`](https://github.com/apple-oss-distributions/IOUSBFamily/blob/IOUSBFamily-630.4.5/AppleUSBEHCI/Classes/AppleUSBEHCIHubInfo.cpp), [`PortStatusGatherer.m`](https://github.com/apple-oss-distributions/IOUSBFamily/blob/IOUSBFamily-630.4.5/USBProberV2/PortStatusGatherer.m))
- [IOSerialFamily](https://github.com/apple-oss-distributions/IOSerialFamily/tree/IOSerialFamily-93.200.2) 93.200.2: [`IOSerialFamily.xcodeproj`](https://github.com/apple-oss-distributions/IOSerialFamily/blob/IOSerialFamily-93.200.2/IOSerialFamily.xcodeproj/project.pbxproj), [`APPLE_LICENSE`](https://github.com/apple-oss-distributions/IOSerialFamily/blob/IOSerialFamily-93.200.2/APPLE_LICENSE) (APSL 1.1)
- [xnu](https://github.com/apple-oss-distributions/xnu/tree/xnu-12377.121.6): [`iokit/IOKit/Makefile`](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/iokit/IOKit/Makefile)
- Apple's documentation of the kernel ([developer.apple.com/documentation/kernel](https://developer.apple.com/documentation/kernel), pages downloaded 2026-11-26/27)
- [libusb](https://github.com/libusb/libusb/tree/v1.0.30) 1.0.30: [`os/darwin_usb.c`](https://github.com/libusb/libusb/blob/v1.0.30/libusb/os/darwin_usb.c)
- [Libinfo](https://github.com/apple-oss-distributions/Libinfo/tree/Libinfo-600): [`APPLE_LICENSE`](https://github.com/apple-oss-distributions/Libinfo/blob/Libinfo-600/APPLE_LICENSE) (the APSL 1.1 text)
- [distribution-macOS](https://github.com/apple-oss-distributions/distribution-macOS): `release.json`

**Details:**

The headers of `IOKit.framework` for storage, HID (keyboards, mice, game controllers), graphics, I²C and USB devices  
(`IOKit/hid/IOHIDManager.h`, `IOKit/usb/IOUSBLib.h`, ...), which libusb, hidapi and SDL include, and of serial ports  
(`IOKit/serial/IOSerialKeys.h`, `ioss.h`), which libserialport includes.

#### The headers

- The families: the modules `storage` (without `storage/ata`), `hid`, `hidsystem`, `graphics`, `i2c`, `ndrvsupport`, `serial` and `usb`  
  of IOKitUser's `Modules/IOKit.modulemap`.
- The headers of each directory: the `PBXCopyFilesBuildPhase` of the Xcode project that copies  
  them to `IOKit.framework/Versions/A/Headers/<dir>`:
  - IOStorageFamily, IOCDStorageFamily, IODVDStorageFamily, IOBDStorageFamily: `storage/`,  
    then `unifdef -UKERNEL` as the shell script phase of the same projects does;
  - IOHIDFamily (target `InstallHeaders`): `hid/` and `hidsystem/` in part;
  - IOKitUser (target `IOKit`): the rest of `hid/` and `hidsystem/`, and `graphics/IOGraphicsLib.h`;
  - IOGraphics (targets `IOGraphics Headers`, `IONDRVSupport Headers`): `graphics/`, `i2c/`, `ndrvsupport/`;
  - IOUSBFamily (the `CopyFiles` phase with the destination `IOKit.framework/Versions/A/Headers/usb`): `usb/`,  
    `USB.h`, `USBSpec.h`, `IOUSBLib.h` and `IOUSBUserClient.h`, copied as they are (their kernel parts are under `#if KERNEL`).  
    The other headers of the project go to `Kernel.framework` and are not installed.
  - IOSerialFamily (the two `CopyFiles` phases with the destination `IOKit.framework/Versions/A/Headers/serial`): `serial/`,  
    `IOSerialKeys.h` and `ioss.h`, copied as they are (the project has no `unifdef` phase; the kernel part of `IOSerialKeys.h`  
    is under `#if KERNEL`).
- IOUSBFamily 560.4.2 and not the last tag, 630.4.5: `USB.h` of 630.4.5 is an empty file (as are many other headers of that tag),  
  and `IOUSBLib.h` needs its types; 560.4.2 is the newest tag that has it. The two tags differ in the userspace headers  
  in one comment of `IOUSBLib.h` and four constants of `USBSpec.h` (`kUSBFunctionRemoteWakeCapableBit` and three more).
- `IOKit/IOUserServer.h` (with `kIOUserServerClassKey`, `kIOUserServerNameKey`, `kIOUserServerTagKey`): xnu's `iokit/IOKit/Makefile`  
  lists it in `INSTALL_IF_MI_LIST`, the headers that go to `IOKit.framework/Headers`, as the other headers of this directory  
  (it is copied after `unifdef`, as they are; the DriverKit parts are under `DRIVERKIT_PRIVATE`).

#### Constants appended to `usb/USB.h`

`data/USBCompat.h.in`, with the notice of `helpers/notice.py`: the enumerators that `USB.h` lacks,  
from Apple's documentation of the kernel:
- `kUSBDeviceSpeedSuperPlus`, `kUSBDeviceSpeedSuperPlusBy2` and `kUSBReEnumerate*`: libusb uses them;  
  the pages are `1646359-anonymous` (the enumeration of `kUSBDeviceSpeedLow`) and `usbreenumerateoptions`;
- the other `kUSB*` constants of the enumerations that the same documentation numbers `1643xxx` and `1646xxx` (the  
  enumerations of the old `USB.h`: hub, billboard, notification and root hub constants), name and value as the pages declare them;
- 38 of them are also in IOUSBFamily 630.4.5 with the same value.

#### Symbols

The declarations of these headers (as for the other frameworks), defined in IOKitUser.
- `IOKit.tbd` gets nothing from `usb/`: `IOUSBLib.h` is the interface of a CFPlugIn (UUID macros and structures of function pointers,  
  no function), `IOUSBUserClient.h` only constants.

#### Licenses and tags

- Licenses: APSL 2.0; the headers of IOGraphics carry the APSL 1.1 notice, its text is the `APPLE_LICENSE` of Libinfo.  
  IOSerialFamily: APSL 1.1, its own `APPLE_LICENSE`.  
  IOHIDFamily has no license file (the notice of `IOHIDKeys.h` and the APSL 2.0 text of xnu).
- Tags: `release.json` of distribution-macOS for 14.3, 15.5, 26.0 and 26.5 (see [Manifests](#manifests)), except IOUSBFamily:  
  `release.json` does not list it, its manifest lines are `fixed` with the tag 560.4.2; nor IOSerialFamily: `fixed` with its newest tag,  
  93.200.2 (its two headers are the same as in 93);  
  the core-only releases do not have these projects.

#### Not in the Open SDK

- `storage/IOFireWireStorageCharacteristics.h` of the module map belongs to IOFireWireSerialBusProtocolTransport  
  and is not installed.
- Not in `storage/`: the enumerators of Apple's documentation of the kernel that the headers declare only for the kernel  
  (`kIOStorageAccess*`, `kIOStorageOption*`, `kIOStoragePriority*`, `kIOStorageProvisionType*`, `kIOStorageSynchronizeOption*`  
  of `IOStorage.h`, `IOPartitionScheme.h`, ...: they are under `#ifdef KERNEL`, which `unifdef -UKERNEL` removes, as in the  
  projects' own build), and `kCDFeatures*` and `kDVDFeatures*`, which no open release of IOCDStorageFamily  
  or IODVDStorageFamily declares.
- Not in `usb/USB.h`: the four `kUSBFunctionRemoteWake*`/`kUSBLowPowerSuspendStateBit` names, whose value 630.4.5 gives as 0 and 1 but the pages  
  as `IOUSBBit(0)` and `IOUSBBit(1)`; and the constants of the `IOUSBHostFamily` of the kernel (`kIOUSB*`, `kUSBHost*`, the `tIOUSB*`  
  and `tUSBHost*` enumerations): that project is not open, and its headers go to `Kernel.framework`.
- Not in `IOKit.tbd`: `IORPCMessageFromMach` (declared in `IORPC.h`; no open source exports it from `IOKit`: xnu defines it for the kernel,  
  DriverKit is not part of the Open SDK) and `IONDRVLibrariesInitialize` (a kernel function of IOGraphics, which has only  
  `_IONDRVLibrariesInitialize` in `IONDRVLibraries.h`, a header that is not installed).
- Not installed: `hidsystem/IOHIDEventSystemClient.h` and `hidsystem/IOHIDServiceClient.h`  
  (IOKitUser `hidsystem.subproj`): IOKitUser builds their functions from  
  `hid.subproj/IOHIDEventSystemClient.c` and `IOHIDServiceClient.c`, which are empty in the open source releases  
  (`IOKitUser` of macOS 14.3 to 26.5), so no open source defines them.

---

### Link stubs from Apple's documentation

**Files:**

- `data/symbols/doc/`
- `data/symbols/CoreGraphics-extra.txt`
- `data/symbols/Carbon-extra.txt`
- `tools/doc_symbols.py`
- `lib/frameworks.sh`
- `data/libraries.txt`

**Sources:**

- [Apple's documentation](https://developer.apple.com/documentation) (each list names the days its pages were fetched)
- GNUstep: [libs-base](https://github.com/gnustep/libs-base/tree/f3d4795594c5) f3d4795 (`Headers/Foundation`), [libs-gui](https://github.com/gnustep/libs-gui/tree/af9ee9812aae) af9ee98 (`Headers/AppKit`) (LGPL; names only)
- [winit](https://github.com/rust-windowing/winit/tree/b1a0534) b1a0534: [`winit-appkit/src/ffi.rs`](https://github.com/rust-windowing/winit/blob/b1a0534/winit-appkit/src/ffi.rs), [`winit-appkit/src/window_delegate.rs`](https://github.com/rust-windowing/winit/blob/b1a0534/winit-appkit/src/window_delegate.rs)
- [GLFW](https://github.com/glfw/glfw/tree/92dcf4c) 92dcf4c: [`src/cocoa_init.m`](https://github.com/glfw/glfw/blob/92dcf4c/src/cocoa_init.m)
- [neovide](https://github.com/neovide/neovide/tree/95c913b) 95c913b: [`src/window/application/macos/hotkey.rs`](https://github.com/neovide/neovide/blob/95c913b/src/window/application/macos/hotkey.rs)
- [acsandmann/rift](https://github.com/acsandmann/rift/tree/2d28eac) 2d28eac: [`src/sys/carbon.rs`](https://github.com/acsandmann/rift/blob/2d28eac/src/sys/carbon.rs)
- [anomalyco/hex](https://github.com/anomalyco/hex/tree/3b936b9) 3b936b9, [MystikoLab/rustcast](https://github.com/MystikoLab/rustcast/tree/6f5d1aa) 6f5d1aa, [qingjian](https://github.com/qingjian-team/qingjian/tree/d75ca0e) d75ca0e, [zed](https://github.com/zed-industries/zed/tree/ed8dc1b) ed8dc1b, [n2ray/xdesk](https://github.com/n2ray/xdesk/tree/1f9a0cf) 1f9a0cf, [enigo](https://github.com/enigo-rs/enigo/tree/v0.6.1) 0.6.1, [rdev](https://github.com/Narsil/rdev/tree/0e2a1c8) 0.5.3 (0e2a1c8):  
  their `extern` blocks for Carbon (the files are named in `data/symbols/Carbon-extra.txt`)
- [WebKit](https://github.com/WebKit/WebKit/tree/4940531db2fa) 4940531 (Apple's own open source project, BSD-2-Clause): [`Source/WebKit/Configurations/WebKit.xcconfig`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Source/WebKit/Configurations/WebKit.xcconfig),  
  [`Configurations/WebKitProjectPaths.xcconfig`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Configurations/WebKitProjectPaths.xcconfig), [`Configurations/SDKVariant.xcconfig`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Configurations/SDKVariant.xcconfig), [`Configurations/Version.xcconfig`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Configurations/Version.xcconfig)
- for the install names: the projects of the table under [Install names](#install-names)

**Details:**

Full Open SDK only. Apple publishes no source code of these frameworks (except WebKit and OpenDirectory, see note 4 of [the frameworks](#the-frameworks)):  
the Open SDK has only their `.tbd`, no headers  
(the documentation does not give the values of macros, enumerators and the fields of structs).  
They are for languages and packages that declare what they use themselves (Rust crates, for example):  
a crate that calls `CGMainDisplayID` declares it and links `-framework CoreGraphics`; the stub lets that link work.

#### The symbols

- The C functions and global variables and constants that Apple's documentation lists for macOS  
  (the page of each symbol is in its line of `data/symbols/doc/<name>.txt`, with the release that brought it).
- `tools/doc_symbols.py` makes the lists from the JSON form of  
  the pages (`developer.apple.com/tutorials/data/documentation/...`).
- The full Open SDK of a release has the symbols of that release and earlier.
- The pages: the Swift pages of the framework and the pages they refer to; some symbols have only an  
  Objective-C page (`developer.apple.com/documentation/appkit/nsbeep`, for example).
- A page whose `metadata.platforms` is missing or does not name macOS counts if the platforms of its declaration  
  name macOS (`CGDisplayStreamCreate`, `CGWindowListCreateImage`, `AudioServicesPlaySystemSoundWithDetails`);  
  it has no release then ("-": in every Open SDK), or that of the other platforms from 26.0 on, which share the number.
- The framework of a symbol is the module that its page names. The Swift pages list constants that other  
  frameworks define under Foundation (members of `NSNotification.Name`, `NSAttributedString.Key`, ...);  
  for them the Objective-C page (`developer.apple.com/documentation/appkit/<name>`) names the framework.
- Where there is no such page: the headers of GNUstep, which follow the split of Apple's frameworks  
  (`libs-base` `Headers/Foundation`, `libs-gui` `Headers/AppKit`). A constant under Foundation that only `libs-gui` declares goes to AppKit;  
  a member of an extension that neither declares is left out.

**Not in the Open SDK:**
- Names with a leading underscore, which the pages of Swift initializers give  
  (`_CTFontCreateWithName` on the page of `CTFont.init(_:size:)`, for example).
- From WebKit's own sources (WebKit 4940531, newer than macOS 26.5, so the release of a name is not known):  
  the constants of its public headers that the documentation does not list, the C functions of its Private headers  
  (`WKStringCreateWithUTF8CString`, ...), the re-export of WebKitLegacy and libobjc (`WebKit.xcconfig`),  
  and the private symbols of CoreGraphics, CoreText and QuartzCore that its `spi/` headers declare  
  (no project of [TESTED.md](TESTED.md) needs them).

**Checks:** WebKit's own headers (WebKit 4940531) declare all 85 names of the WebKit list; that is a check, not a source.

**Limits:**
- Very old symbols stay in the lists as long as the page names macOS: the File Manager of CoreServices (`FSGetCatalogInfo`,  
  `PBGetCatalogInfoSync`, ... of 10.0 to 10.5), the Web Services constants `kWS...` (10.2) and `pi` (10.0); the page says  
  deprecated, not removed, and no open source says which release still exports them.
- The documentation does not say which symbols exist on only one architecture, or which functions are not  
  exported (inline): every symbol is in the stub for x86_64 and arm64. A symbol that a release of macOS does  
  not export links, but the program stops at start with "symbol not found".
- CoreMedia's stub also has functions that the headers define inline; whether a release exports them is not known  
  from an open source (as for the other stubs).

#### The frameworks

The framework of each list is the module that the pages of Apple's documentation name.

| Framework | Modules of the documentation | Notes |
|---|---|---|
| Foundation, CoreGraphics, AppKit, CoreText, CoreVideo | the framework's own | |
| QuartzCore | "Core Animation" | |
| Metal | "Metal" | [1] |
| CoreAudio | "Core Audio", "Core Audio Types" | |
| AudioToolbox | "Audio Toolbox" | |
| ApplicationServices | "Application Services", "ColorSync" | [2] |
| Carbon | none | [below](#carbon) |
| CoreServices | "Core Services" | [FSEvents](#coreservicesfseventsh-and-its-symbols) |
| AVFoundation, CoreMedia, ImageIO, Vision, MetalKit | "AVFoundation", "Core Media", "Image I/O", "Vision", "MetalKit" | [3] |
| WebKit, UniformTypeIdentifiers, OpenDirectory | "WebKit", "Uniform Type Identifiers", "Open Directory" | [4] |

1. The pages of four `NS...` constants (`NSProcessPerformanceProfileDefault`, `NSDeviceCertificationiPhonePerformanceGaming`, ...)  
   name Metal as their module, so they are in the stub of Metal.
2. ColorSync is a framework inside ApplicationServices, and the crates link its functions through ApplicationServices  
   (winit: `CGDisplayCreateUUIDFromDisplayID`, `CGDisplayGetDisplayIDFromUUID`,  
   with a comment that ColorSync is part of ApplicationServices): one list for both.  
   There is no ColorSync stub and no re-export: no open source names the re-exports of ApplicationServices.
3. - AVFoundation: the `AVMediaType...` and `AVCaptureSessionPreset...` constants, the notification names and the `AVMake...` functions;  
     the Objective-C classes are not in the stub. The documentation pages of the notification names and a few more  
     (213 pages) were fetched on 2026-11-27 because the pages that refer to them were not cached.
   - ImageIO: `kCGImageProperty...`, `kCGImageSource...`, `CGImageSource...`, ...
   - Vision: the documentation names few C symbols: the constants (`VNImageOption...`, the joint names of the pose observations,  
     `VNNormalizedIdentityRect`) and a few functions; nearly all of Vision is Objective-C classes, which the stub does not have.
   - MetalKit: `MTKTextureLoaderOption...`, `MTKModelError...` and the `MTK...FromModelIO` functions.
4. - The Objective-C pages of the constants that the Swift pages name were fetched on  
     2026-11-27 from `developer.apple.com/documentation/<framework>/<name>`.
   - The lists have the global constants (`WKWebsiteDataType...`, `UTType...`, `kOD...`) and the  
     functions of Open Directory's C interface (`ODNodeCreateWithName`, ...).
   - The stub of `OpenDirectory` carries them directly: Open Directory's project builds them in a sub-umbrella, `CFOpenDirectory`,  
     that `OpenDirectory` re-exports (`OTHER_LDFLAGS` `-sub_umbrella CFOpenDirectory`), and no `CFOpenDirectory` stub is made.
   - No Objective-C classes, as for the other stubs. The symbols come from Apple's documentation only.

#### Symbols that the documentation does not list

Open projects that declare them themselves and link them from these frameworks, so they rely on them;  
each line of the file names the project and file.

- `CoreGraphics-extra.txt`: the private functions `CGSMainConnectionID` and `CGSSetWindowBackgroundBlurRadius` (winit).
- `Carbon-extra.txt`: see [Carbon](#carbon).

#### Carbon

Carbon has no list from the documentation (it has no pages of C symbols of its own): only `Carbon-extra.txt`,  
the names that open projects declare themselves in an `extern` block with `link(name = "Carbon")`, so they rely on them.  
Each entry of the file names the projects (commit) and files.

- Keyboard layout: `TISCopyCurrentKeyboardLayoutInputSource`, `TISGetInputSourceProperty`,  
  `kTISPropertyUnicodeKeyLayoutData`, `LMGetKbdType` (winit; GLFW uses the same four from the HIToolbox bundle,  
  which is a framework inside Carbon), and `UCKeyTranslate`.
- Text Input Sources: `TISCopyCurrentKeyboardInputSource` (enigo, rdev), `TISCopyCurrentASCIICapableKeyboardLayoutInputSource`  
  (enigo), `TISCreateInputSourceList` (hex, rustcast), `TISSelectInputSource` (rustcast), `TISEnableInputSource`,  
  `TISRegisterInputSource` (qingjian), and the constants `kTISProperty*`, `kTISCategoryKeyboardInputSource`, `kTISType*`  
  and `kTISNotifySelectedKeyboardInputSourceChanged` (hex, zed, xdesk, qingjian).  
  The constants are `CFStringRef` data symbols, the others functions; the stub lists both kinds the same way.
- Event handlers and hot keys: `RegisterEventHotKey`, `UnregisterEventHotKey`, `InstallEventHandler`, `RemoveEventHandler`,  
  `GetApplicationEventTarget`, `GetEventParameter` (neovide), `GetEventKind` (rift; hex).  
  Apple's page of the Carbon Event Manager guide ([Tasks/CarbonEventsTasks.html](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/Carbon_Event_Manager/Tasks/CarbonEventsTasks.html))  
  names `InstallEventHandler`, `RemoveEventHandler`, `GetApplicationEventTarget`, `GetEventKind` and `GetEventParameter` too.
- Which of them HIToolbox exports on its own and which Carbon re-exports is not known from an open source: all are in the stub  
  of Carbon, as the projects link them with `-framework Carbon`.
- Apple's documentation puts `UCKeyTranslate` in Core Services (the stub of CoreServices has it too);  
  winit links it with `-framework Carbon`, so it is in the stub of Carbon,  
  as there is no re-export of CoreServices by Carbon in an open source.

#### Install names

All are `/System/Library/Frameworks/<Name>.framework/Versions/<V>/<Name>`; the column `Versions/` gives `<V>`,  
the directory of the version in the bundle (see [framework layout](#framework-layout-and-cocoaframework)).  
"The full path" in the notes means that the source names exactly this path.

| Framework | `Versions/` | Sources |
|---|---|---|
| Foundation | C | dyld's source, see [below](#install-names-of-foundation-coreservices) |
| CoreGraphics, Carbon, QuartzCore, ApplicationServices | A | python-build-standalone, maiko [1] |
| AppKit | C | python-build-standalone, maiko [1] |
| CoreText | A | python-build-standalone [1] |
| CoreVideo, Metal, CoreAudio, AudioToolbox | A | maiko [1] |
| AVFoundation | A | tymbal [2] |
| CoreMedia | A | wireshark [2] |
| ImageIO | A | ctx [2] |
| Vision | A | markitai [2] |
| MetalKit | A | pulp, fono [2] |
| WebKit | A | WebKit's own `WebKit.xcconfig`, Webviews.jl, gosx [3] |
| UniformTypeIdentifiers | A | python-build-standalone [1] |
| OpenDirectory | A | OpenDirectory-146 [3] |

1. The lists of macOS system libraries of [astral-sh/python-build-standalone](https://github.com/astral-sh/python-build-standalone/tree/139273f) 139273f, [`src/validation.rs`](https://github.com/astral-sh/python-build-standalone/blob/139273f/src/validation.rs) (MPL-2.0),  
   and [michidk/maiko](https://github.com/michidk/maiko/tree/f984528) f984528, [`crates/patcher/src/macos.rs`](https://github.com/michidk/maiko/blob/f984528/crates/patcher/src/macos.rs) (MIT).
2. - AVFoundation: [odvcencio/tymbal](https://github.com/odvcencio/tymbal/tree/9184eeb) 9184eeb, [`internal/coreaudio/permission_darwin.go`](https://github.com/odvcencio/tymbal/blob/9184eeb/internal/coreaudio/permission_darwin.go) (MIT; the full path, from which a Go  
     program imports `AVMakeRectWithAspectRatioInsideRect`).
   - CoreMedia: [wireshark/wireshark](https://github.com/wireshark/wireshark/tree/f09629a) f09629a, [`CMakeLists.txt`](https://github.com/wireshark/wireshark/blob/f09629a/CMakeLists.txt) (GPL-2.0; the full path in a dyld message in a comment).
   - ImageIO: [ctxrs/ctx](https://github.com/ctxrs/ctx/tree/0b117cb) 0b117cb, [`scripts/check-release-binary-compat.sh`](https://github.com/ctxrs/ctx/blob/0b117cb/scripts/check-release-binary-compat.sh) (Apache-2.0; the full path in a list of the  
     system libraries that a program may link).
   - Vision: [Ynewtime/markitai](https://github.com/Ynewtime/markitai/tree/c5d13fd) c5d13fd, [`crates/markitai-core/src/system_frameworks.rs`](https://github.com/Ynewtime/markitai/blob/c5d13fd/crates/markitai-core/src/system_frameworks.rs) (MIT; the full path that the program loads).
   - MetalKit (nothing else was found): [Generous-Corp/pulp](https://github.com/Generous-Corp/pulp/tree/f9a7b39) f9a7b39,  
     [`test/fixtures/no_editor_link_floor/test_no_editor_runtime_deps.cmake`](https://github.com/Generous-Corp/pulp/blob/f9a7b39/test/fixtures/no_editor_link_floor/test_no_editor_runtime_deps.cmake) (MIT; the full path in a recorded list of the libraries  
     a program links) and [bogdanr/fono](https://github.com/bogdanr/fono/tree/c4d7c36) c4d7c36, [`.github/workflows/ci.yml`](https://github.com/bogdanr/fono/blob/c4d7c36/.github/workflows/ci.yml) (GPL-3.0; the full path in a list of allowed system libraries).
3. - WebKit: [WebKit](https://github.com/WebKit/WebKit/tree/4940531db2fa) 4940531, [`Source/WebKit/Configurations/WebKit.xcconfig`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Source/WebKit/Configurations/WebKit.xcconfig) (`PRODUCT_NAME = WebKit`,  
     `DYLIB_INSTALL_NAME_BASE` through [`Configurations/WebKitProjectPaths.xcconfig`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Configurations/WebKitProjectPaths.xcconfig) to `/System/Library/Frameworks`,  
     `Versions/A/` from [`Configurations/SDKVariant.xcconfig`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Configurations/SDKVariant.xcconfig)) and [`Configurations/Version.xcconfig`](https://github.com/WebKit/WebKit/blob/4940531db2fa/Configurations/Version.xcconfig)  
     (`DYLIB_COMPATIBILITY_VERSION = 1`). Also [sunoru/Webviews.jl](https://github.com/sunoru/Webviews.jl/tree/b28fb63) b28fb63, [`src/platforms/apple/Impl.jl`](https://github.com/sunoru/Webviews.jl/blob/b28fb63/src/platforms/apple/Impl.jl) (MIT; `const libWebKit` is the full path), and  
     [odvcencio/gosx](https://github.com/odvcencio/gosx/tree/08c6d78) 08c6d78, [`desktop/bind_darwin.go`](https://github.com/odvcencio/gosx/blob/08c6d78/desktop/bind_darwin.go) (MIT; the full path in its `cgo_import_dynamic` line of `WKStringCreateWithUTF8CString`).
   - OpenDirectory: apple-oss [OpenDirectory](https://github.com/apple-oss-distributions/OpenDirectory/tree/OpenDirectory-146), tag OpenDirectory-146, [`OpenDirectory.xcodeproj/project.pbxproj`](https://github.com/apple-oss-distributions/OpenDirectory/blob/OpenDirectory-146/OpenDirectory.xcodeproj/project.pbxproj)  
     (`INSTALL_PATH = /System/Library/Frameworks`, `PRODUCT_NAME = OpenDirectory`, `FRAMEWORK_VERSION = A`,  
     `DYLIB_COMPATIBILITY_VERSION = DYLIB_CURRENT_VERSION = 1`).

---

### OpenGL.framework

**Files:**

- `data/opengl/` (`registry.txt`, `cgl-enums.txt`, `cgl-functions.txt`, `extensions.txt`)
- `helpers/gl_registry.py`
- `helpers/write_opengl_headers.py`
- `helpers/opengl_syms.py`
- `lib/frameworks.sh`
- `lib/fetch.sh`

**Sources:**

- Khronos Group: the OpenGL API Registry, [`xml/gl.xml`](https://github.com/KhronosGroup/OpenGL-Registry/blob/6af574a14089ccfee87efe230ebcdd8742859813/xml/gl.xml) of [KhronosGroup/OpenGL-Registry](https://github.com/KhronosGroup/OpenGL-Registry/tree/6af574a14089ccfee87efe230ebcdd8742859813)  
  (commit and SHA-256 in `data/opengl/registry.txt`; Apache-2.0)
- Khronos Group: [`api/KHR/khrplatform.h`](https://github.com/KhronosGroup/EGL-Registry/blob/aa39a34729e6d20b0b982e279c351976a5c91075/api/KHR/khrplatform.h) of [KhronosGroup/EGL-Registry](https://github.com/KhronosGroup/EGL-Registry/tree/aa39a34729e6d20b0b982e279c351976a5c91075) aa39a34 (the C types; facts only)
- [servo/cgl-rs](https://github.com/servo/cgl-rs/tree/d97cc08) d97cc08: [`src/cgl.rs`](https://github.com/servo/cgl-rs/blob/d97cc08/src/cgl.rs) (MIT or Apache-2.0)
- [ValveSoftware/vogl](https://github.com/ValveSoftware/vogl/tree/434dcc5) 434dcc5: [`glspec/cglenum.spec`](https://github.com/ValveSoftware/vogl/blob/434dcc5/glspec/cglenum.spec) (MIT, "hand generated"), [`glspec/cgl.spec`](https://github.com/ValveSoftware/vogl/blob/434dcc5/glspec/cgl.spec)
- [apitrace](https://github.com/apitrace/apitrace/tree/28bb3ab) 28bb3ab: [`dispatch/glimports.hpp`](https://github.com/apitrace/apitrace/blob/28bb3ab/dispatch/glimports.hpp) (MIT), [`specs/cglapi.py`](https://github.com/apitrace/apitrace/blob/28bb3ab/specs/cglapi.py)
- [factor/factor](https://github.com/factor/factor/tree/f05a4e9) f05a4e9: [`basis/core-graphics/core-graphics.factor`](https://github.com/factor/factor/blob/f05a4e9/basis/core-graphics/core-graphics.factor) (BSD)
- [mesa](https://gitlab.freedesktop.org/mesa/mesa/-/tree/7564f95) 7564f95 ([gitlab.freedesktop.org/mesa/mesa](https://gitlab.freedesktop.org/mesa/mesa)): [`src/glx/apple/apple_cgl.h`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/7564f95/src/glx/apple/apple_cgl.h),  
  [`apple_cgl.c`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/7564f95/src/glx/apple/apple_cgl.c), [`apple_visual.c`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/7564f95/src/glx/apple/apple_visual.c), [`apple_glx_context.c`](https://gitlab.freedesktop.org/mesa/mesa/-/blob/7564f95/src/glx/apple/apple_glx_context.c) (MIT)
- [wine-mirror/wine](https://github.com/wine-mirror/wine/tree/ecca8e7) ecca8e7: [`dlls/winemac.drv/opengl.c`](https://github.com/wine-mirror/wine/blob/ecca8e7/dlls/winemac.drv/opengl.c) (LGPL-2.1)
- [XQuartz/xorg-server](https://github.com/XQuartz/xorg-server/tree/0ea9b59) 0ea9b59: [`hw/xquartz/GL/indirect.c`](https://github.com/XQuartz/xorg-server/blob/0ea9b59/hw/xquartz/GL/indirect.c) (MIT)
- [baldurk/renderdoc](https://github.com/baldurk/renderdoc/tree/762d40b) 762d40b: [`renderdoc/driver/gl/cgl_platform.cpp`](https://github.com/baldurk/renderdoc/blob/762d40b/renderdoc/driver/gl/cgl_platform.cpp) (MIT)
- [GLFW](https://github.com/glfw/glfw/tree/92dcf4c) 92dcf4c: [`include/GLFW/glfw3.h`](https://github.com/glfw/glfw/blob/92dcf4c/include/GLFW/glfw3.h)
- [raysan5/raylib](https://github.com/raysan5/raylib/tree/e045e8f) e045e8f: [`src/rlgl.h`](https://github.com/raysan5/raylib/blob/e045e8f/src/rlgl.h)
- [Syphon/Syphon-Framework](https://github.com/Syphon/Syphon-Framework/tree/f476167) f476167: [`SyphonGLVertices.h`](https://github.com/Syphon/Syphon-Framework/blob/f476167/SyphonGLVertices.h), [`SyphonServerGLVertices.h`](https://github.com/Syphon/Syphon-Framework/blob/f476167/SyphonServerGLVertices.h)
- [godotengine/godot](https://github.com/godotengine/godot/tree/7c97c29) 7c97c29: [`thirdparty/glad/gl.c`](https://github.com/godotengine/godot/blob/7c97c29/thirdparty/glad/gl.c)
- Apple's archived [OpenGL Programming Guide for Mac](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide)

**Details:**

OpenGL is the old 3D graphics interface (`glDrawArrays`, ...); CGL is the part of macOS that creates its contexts (`CGLCreateContext`).  
Headers and install name only come from open sources; Apple's headers and libraries are not read.  
The headers are written by the generator at build time from the data files, not copied.
- **OpenGL itself** (names, values and signatures of the functions and tokens of `gl.h`, `gl3.h`, `glext.h`):  
  `gl.xml`, downloaded by the step `fetch`. The C types are those of Khronos' `KHR/khrplatform.h` (`int8_t`, `float`, `intptr_t`, ...).
- **Which header has what.** The headers are named as open projects include them:
  - `<OpenGL/gl.h>`, `<OpenGL/OpenGL.h>`, `<OpenGL/CGLTypes.h>`, `<OpenGL/CGLCurrent.h>`, `<OpenGL/CGLRenderers.h>`: mesa
  - `<OpenGL/OpenGL.h>`, `<OpenGL/CGLDevice.h>`, `<OpenGL/CGLIOSurface.h>`: apitrace
  - `<OpenGL/gl.h>`, `<OpenGL/gl3.h>`, `<OpenGL/gl3ext.h>`: GLFW (with `GLFW_INCLUDE_GLCOREARB` and `GLFW_INCLUDE_GLEXT`)
  - `<OpenGL/glext.h>`: raylib
  - `<OpenGL/gltypes.h>`: Syphon-Framework
- **The profiles of `gl.h` and `gl3.h`:**
  - `gl.h` is the legacy profile: what `gl.xml` requires for OpenGL 1.0 to 2.1 in the compatibility profile.
  - `gl3.h` is the core profile: OpenGL 1.0 to 4.1 without what the registry removes for it.
  - The limit 2.1 / 3.2 to 4.1 is the one of the contexts that `kCGLOGLPVersion_Legacy`, `_3_2_Core` and `_GL4_Core` select  
    (`data/opengl/cgl-enums.txt`; Apple's archived guide names Legacy and 3.2 Core).
  - `gl.h` and `gl3.h` may be included together. `gl3ext.h` is empty: no source says which extensions a core context has.
- **The CGL types and constants** (`CGLTypes.h`, `CGLRenderers.h`): no Khronos standard, no current Apple documentation.  
  Every value is declared by an open project that wrote it down (`data/opengl/cgl-enums.txt` names them per entry): cgl-rs, vogl, apitrace, Factor.  
  The names are also used or listed by apitrace, Wine, XQuartz, mesa, renderdoc and Apple's archived guide.  
  Values with one source: the `kCGLBad...` errors, the `kCGLRP...` renderer properties (vogl only),  
  the `kCGLOGLPVersion_...` profiles (apitrace only) and `kCGLRendererGenericFloatID` (Factor only).
- **The CGL functions** (`data/opengl/cgl-functions.txt`): those that at least two of apitrace (which also names the header of each),  
  vogl, cgl-rs, mesa, Wine, XQuartz, renderdoc and Apple's guide name. The parameter types follow mesa `apple_cgl.h` and apitrace.
- **Exports of `OpenGL.tbd`** (conservative):
  - every command that `gl.xml` requires for OpenGL 1.0 to 4.1;
  - the CGL functions above;
  - the functions of the extensions of `data/opengl/extensions.txt` (`GL_APPLE_fence`, `GL_APPLE_vertex_array_object`,  
    `GL_APPLE_vertex_array_range`, `GL_APPLE_texture_range`, `GL_APPLE_flush_buffer_range`, `GL_EXT_framebuffer_object`):  
    Apple's guide (the pages `opengl_designstrategies`, `opengl_vertexdata`, `opengl_texturedata`, `opengl_offscreen`)  
    calls each of them by name in its sample code, with no lookup. Other extensions are not exported and not declared.
- **Install name** `/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL`: mesa `apple_cgl.c` (`OPENGL_FRAMEWORK_PATH`).  
  Godot's glad loader names the same framework by `.../OpenGL.framework/Versions/Current/OpenGL`.

**Not in the Open SDK:**
- CGL values that no source declares: the other renderer IDs, the buffer and color mode bits (`kCGLRGB888Bit`, ...),  
  the constants of `CGLProfiler.h` (apitrace only, and it notes that the header is gone), `CGLContext.h` and `CGLMacro.h`.
- CGL functions that only apitrace names: `CGLGetContextRetainCount`, `CGLReleasePBuffer`, `CGLGetPBufferRetainCount`,  
  `CGLSetFullScreenOnDisplay`; and the functions that apitrace calls undocumented.
- GLU (`glu.h`, `libGLU`) and the functions of OpenGL 4.2 and later.

**License:** `gl.xml` is licensed Apache-2.0 (`SPDX-License-Identifier: Apache-2.0` in its first comment);  
the generated `gltypes.h`, `gl.h`, `gl3.h`, `glext.h` and `gl3ext.h` carry that notice and are Apache-2.0 too.  
No header of the Registry (`glext.h`, `glcorearb.h`, MIT) is copied: the generator reads only `gl.xml`.

---

### Install names of Foundation, CoreServices

**Files:**

- `lib/frameworks.sh`
- `data/libraries.txt`

**Sources:**

- [dyld](https://github.com/apple-oss-distributions/dyld/tree/dyld-1378): [`cache_builder/NewSharedCacheBuilder.cpp`](https://github.com/apple-oss-distributions/dyld/blob/dyld-1378/cache_builder/NewSharedCacheBuilder.cpp)
- apple-oss [Security](https://github.com/apple-oss-distributions/Security/tree/Security-61901.120.67): [`OSX/libsecurity_translocate/lib/SecTranslocateLSNotification.cpp`](https://github.com/apple-oss-distributions/Security/blob/Security-61901.120.67/OSX/libsecurity_translocate/lib/SecTranslocateLSNotification.cpp)
- apple-oss [CF](https://github.com/apple-oss-distributions/CF/tree/CF-1153.18): [`CFUtilities.c`](https://github.com/apple-oss-distributions/CF/blob/CF-1153.18/CFUtilities.c)

**Details:**

- Foundation, `/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation`: dyld's `NewSharedCacheBuilder.cpp` names it.
- CoreServices, `/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices`: the frameworks inside  
  `Versions/A` of `CoreServices.framework`, which Security (`SecTranslocateLSNotification.cpp`)  
  and CF (`CFUtilities.c`) name.

---

### Framework layout and `Cocoa.framework`

**Files:**

- `lib/frameworks.sh` (`fw_layout`)
- `data/libraries.txt`
- `tests/sdk-check.py`

**Sources:**

- Apple's ["Anatomy of Framework Bundles"](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/FrameworkAnatomy.html)
- Apple's ["Cocoa Application Layer"](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/OSX_Technology_Overview/CocoaApplicationLayer/CocoaApplicationLayer.html)
- ld64 of [cctools-port](https://github.com/tpoechtrager/cctools-port/tree/ef969083aecf77dee1814d6961a06b88af23edef) ef96908: [`cctools/ld64/src/ld/Options.cpp`](https://github.com/tpoechtrager/cctools-port/blob/ef969083aecf77dee1814d6961a06b88af23edef/cctools/ld64/src/ld/Options.cpp) (`Options::findFile`)
- [astral-sh/python-build-standalone](https://github.com/astral-sh/python-build-standalone/tree/139273f) 139273f: [`src/validation.rs`](https://github.com/astral-sh/python-build-standalone/blob/139273f/src/validation.rs) (MPL-2.0)
- [GLFW](https://github.com/glfw/glfw/tree/92dcf4c) 92dcf4c: [`src/cocoa_monitor.m`](https://github.com/glfw/glfw/blob/92dcf4c/src/cocoa_monitor.m), [`src/CMakeLists.txt`](https://github.com/glfw/glfw/blob/92dcf4c/src/CMakeLists.txt)

**Details:**

- The layout: the files are in `Versions/<V>`, `Versions/Current` is a link to the current version, and the top level has links  
  to `Versions/Current/<Name>` and `Headers` (and `Resources`). The page does not describe `Modules`;  
  it is linked the same way, where the framework has one (Clang finds `Name.framework/Modules/module.modulemap`).
- The letter `<V>` is that of the install name of the framework in `data/libraries.txt` (each with its source in [Install names](#install-names)).
- Why the install name must be the path of the file: a re-exported library is looked up at its install name below the Open SDK  
  plus `.tbd` (ld64: `Options::findFile`; `ld64.lld` does the same).  
  The test `tests/sdk-check.sh` compares the install name of every `.tbd` with its path.
- `Cocoa.framework` re-exports `AppKit` and `Foundation`: "The Cocoa umbrella framework (`Cocoa.framework`) imports the core Objective-C  
  frameworks for app development: AppKit, Foundation, and Core Data" ("Cocoa Application Layer").  
  There is no `CoreData` in the Open SDK, so it is not re-exported.
- `CoreGraphics` is not re-exported: GLFW's sources (`src/cocoa_monitor.m`) call `CGDisplay...` functions and its build  
  (`src/CMakeLists.txt`) links `Cocoa`, `IOKit`, `QuartzCore` and `CoreFoundation` but not `CoreGraphics`, so a program may  
  rely on one of them, but no public source says which framework gives them. With a re-export of `CoreGraphics`  
  the link of the glfw crate lacks only `UCKeyTranslate` (Carbon) and the Objective-C classes.
- Install name `/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa`: python-build-standalone.

---

### Swift runtime stubs

**Files:**

- `lib/swift.sh`
- `helpers/swift_stubs.py`

**Source:**

- [swift.org](https://www.swift.org): the macOS toolchain package that `OPEN_SDK_SWIFT_PKG` names (`swift-<version>-RELEASE-osx.pkg`, Apache-2.0)

**Details:**

The symbols and install names of the stubs are read from its `usr/lib/swift/macosx/libswift*.dylib`.

---

### `SDKSettings.json`, `SDKSettings.plist`

**Files:**

- `lib/meta.sh`

**Sources:**

- [Clang](https://github.com/llvm/llvm-project)
- [OSXCross](https://github.com/tpoechtrager/osxcross/tree/8d457942c0237df988eb191c1c88546ad09e2696) 8d45794: [`wrapper/src/target.cpp`](https://github.com/tpoechtrager/osxcross/blob/8d457942c0237df988eb191c1c88546ad09e2696/wrapper/src/target.cpp)
- [AvailabilityVersions](https://github.com/apple-oss-distributions/AvailabilityVersions/tree/AvailabilityVersions-157.2)

**Details:**

Files that tell Clang and OSXCross the version of the Open SDK and what it supports; only the keys that they read.
- Each value: the section "Keys of SDKSettings.json" below.
- The iOS version of a macOS release (for `VersionMap`) comes from the DSL of AvailabilityVersions  
  (`data/availability-extra.dsl` for the releases after the public tags).
- `SDKSettings.plist` has only `Version`, which OSXCross reads for SDKs without a JSON file  
  (`wrapper/src/target.cpp`, `readSDKInfo`), and `OpenSDKGeneratorCommit`.

---

### `SystemVersion.plist`, the releases

**Files:**

- `data/releases.txt`
- `lib/meta.sh`

**Source:**

- [AppleDB](https://appledb.dev): the page `appledb.dev/firmware/macOS/<build>.html` of each release

**Details:**

- `ProductVersion` is the macOS release of the Open SDK (`--macos`), `ProductName` is `macOS`.
- `ProductBuildVersion` is the public build of the release where `data/releases.txt` names one, else empty  
  (`OPEN_SDK_BUILD_VERSION` sets another value). The build is that of AppleDB for the release (x.y, as the manifests are pinned):
  - macOS 11.3: `20E232`
  - macOS 12.3: `21E230`
  - macOS 13.3: `22E252`
  - macOS 14.3: `23D56`, released on 2024-01-22
  - macOS 15.5: `24F74`
  - macOS 26.0: `25A354`
  - macOS 26.5: `25F71`, released on 2026-05-11

**Chosen by the generator:** the releases, their default libc++ and the variants (full and core, or core only) are choices of the generator.

---

### `availability-extra.dsl`

**Files:**

- `data/availability-extra.dsl` (its comment has the details)

**Sources:**

- [AvailabilityVersions-138.7](https://github.com/apple-oss-distributions/AvailabilityVersions/tree/AvailabilityVersions-138.7): [`availability.dsl`](https://github.com/apple-oss-distributions/AvailabilityVersions/blob/AvailabilityVersions-138.7/availability.dsl)
- Apple's release notes and the public version lists
- the xnu tags of the manifests
- [OSXCross](https://github.com/tpoechtrager/osxcross/tree/8d457942c0237df988eb191c1c88546ad09e2696) 8d45794: [`build.sh`](https://github.com/tpoechtrager/osxcross/blob/8d457942c0237df988eb191c1c88546ad09e2696/build.sh)
- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-21.1.8) 21.1.8: [`llvm/lib/TargetParser/Triple.cpp`](https://github.com/llvm/llvm-project/blob/llvmorg-21.1.8/llvm/lib/TargetParser/Triple.cpp)

**Details:**

The macOS releases after 14.3, the last one that the public tags of AvailabilityVersions list, in the syntax of its DSL;  
only version numbers. They give the macros of `Availability.h` for the newer releases (`__MAC_15_0`, ...).
- macOS 14.4 to 15.0 and visionOS 1.1 and 2.0: the lines of `availability.dsl` behind `#ifndef __OPENSOURCE__`.
- Which iOS, tvOS, watchOS and visionOS release came with a macOS release: the release notes and the version lists.
- DriverKit: the Darwin version of the release; the Darwin versions: the xnu tags and OSXCross' `build.sh`.
- macOS 16.0, iOS and tvOS 19.0, watchOS 12.0, visionOS 3.0 (the numbers before the year-based 26):  
  `Triple.cpp` (`getCanonicalVersionForOS`, `getiOSVersion`).

**Not in the Open SDK:** bridgeOS lines after 14.3 and the `set` lines (dyld version sets): no public source has their numbers.

---

### Manifests

**Files:**

- `data/manifests/`

**Sources:**

- [distribution-macOS](https://github.com/apple-oss-distributions/distribution-macOS) `release.json`
- `git ls-remote` of the projects

**Details:**

The tag and commit of every project for each macOS release (`tools/manifest.py`).  
The `sqlite` and `xz` lines are the same in every manifest; `--new` copies them.

<br>

## Keys of SDKSettings.json

Clang and OSXCross read these keys:

| Key | Value and its source |
|---|---|
| `CanonicalName` | `macosx` and the version of the Open SDK. |
| `DisplayName` | Free text that this generator chooses: `macOS <version> (open source SDK)`. |
| `Version` | The macOS release of the Open SDK (the option `--macos`). |
| `MaximumDeploymentTarget` | `<release>.99`, as in LLVM's test inputs ([details](#maximumdeploymenttarget)) |
| `VersionMap.macOS_iOSMac`, `VersionMap.iOSMac_macOS` | Mac Catalyst versions: Clang's minimum, AvailabilityVersions ([details](#versionmapmacos_iosmac-versionmapiosmac_macos)) |
| `SupportedTargets.macosx.Archs` | `arm64`, `arm64e`, `x86_64`, `x86_64h` ([details](#supportedtargetsmacosxarchs)) |
| `SupportedTargets.macosx.LLVMTargetTripleSys`, `.LLVMTargetTripleVendor` | `macos`, `apple` ([details](#supportedtargetsmacosxllvmtargettriplesys-llvmtargettriplevendor)) |
| `SupportedTargets.macosx.MinimumDeploymentTarget` | `11.0`, the oldest macOS release of `data/manifests/` ([details](#supportedtargetsmacosxminimumdeploymenttarget)) |
| `OpenSDKGeneratorCommit` | The commit of this generator; no Apple key, no program reads it ([details](#opensdkgeneratorcommit)) |

Of these, `OpenSDKGeneratorCommit` is read by no program; it is also in `SDKSettings.plist`.  
Clang reads further keys (`LLVMTargetTripleEnvironment`, `SystemPrefix`) only  
as optional; they are not in the file, which clang treats as empty. The keys of an  
SDK made by Apple that no program reads (`DefaultVariant`, `Variants`,  
`DeviceFamilies`, `IsBaseSDK`, `ValidDeploymentTargets` and others) are not  
in the file either.

## Details of the keys

### `MaximumDeploymentTarget`

**Files:**

- `lib/meta.sh`

**Source:**

- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6, test inputs: [`clang/test/Driver/Inputs/MacOSX15.1.sdk/SDKSettings.json`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/clang/test/Driver/Inputs/MacOSX15.1.sdk/SDKSettings.json)

**Details:**

The release with `.99`, the form that clang accepts for "any later bugfix release"; the test inputs show the form.

---

### `VersionMap.macOS_iOSMac`, `VersionMap.iOSMac_macOS`

**Files:**

- `lib/meta.sh`
- `helpers/avail_dsl.py`

**Sources:**

- [Clang](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6: [`clang/lib/Driver/ToolChains/Darwin.cpp`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/clang/lib/Driver/ToolChains/Darwin.cpp)
- [AvailabilityVersions](https://github.com/apple-oss-distributions/AvailabilityVersions/tree/AvailabilityVersions-157.2)

**Details:**

- 10.15 is 13.1: `minimumMacCatalystDeploymentTarget()` in `Darwin.cpp`.
- The iOS version of the Open SDK's macOS release comes from the DSL of AvailabilityVersions (`helpers/avail_dsl.py --ios-version`).

---

### `SupportedTargets.macosx.Archs`

**Files:**

- `lib/meta.sh`

**Source:**

- [Clang](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6: [`clang/lib/Driver/ToolChains/Darwin.cpp`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/clang/lib/Driver/ToolChains/Darwin.cpp) (`getArchTypeForMachOArchName`)

**Details:**

`arm64`, `arm64e`, `x86_64`, `x86_64h`: the `-arch` names that the driver maps to macOS triples.

---

### `SupportedTargets.macosx.LLVMTargetTripleSys`, `.LLVMTargetTripleVendor`

**Files:**

- `lib/meta.sh`

**Source:**

- [LLVM](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.6) 23.1.6: [`llvm/lib/TargetParser/Triple.cpp`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.6/llvm/lib/TargetParser/Triple.cpp) and the driver

**Details:**

`macos`, `apple`: the triple `arm64-apple-macos`, as in `Triple.cpp` (`macos`) and the driver.

---

### `SupportedTargets.macosx.MinimumDeploymentTarget`

**Files:**

- `lib/meta.sh`

**Source:**

- none, a choice of this generator

**Details:**

`11.0` by default, the oldest macOS release of `data/manifests/` (macOS 11).  
`--min-deployment-target` or `OPEN_SDK_MIN_DEPLOYMENT_TARGET` sets another value. Programs for lower targets are not tested.

---

### `OpenSDKGeneratorCommit`

**Files:**

- `lib/meta.sh`
- `lib/common.sh` (`generator_commit`)

**Source:**

- none, an own value of this generator, no Apple key

**Details:**

The 40 characters of the commit of this repository  
(`git rev-parse HEAD`) that built the Open SDK, also in `SDKSettings.plist` and as `generator.commit` of `OpenSDK.json`.  
`-modified` is added to the commit if tracked files have changes; the value is `unknown` if the commit cannot be read (not a checkout, no `git`).

**Checks:** Clang reads only the keys it knows (`DarwinSDKInfo` in `clang/lib/Basic/DarwinSDKInfo.cpp`), OSXCross  
(`wrapper/src/target.cpp`) only the keys listed above; an unknown key is ignored (tested with Clang 23).
