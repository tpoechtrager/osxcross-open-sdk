# Details

Details of the Open SDK.

## Stub libraries (.tbd)

The SDK has no binaries: the libraries are text stubs (`.tbd`) that tell the linker which symbols exist.  
At run time macOS loads its own libraries.

- **`libSystem.B.tbd`** is made from
  - the declarations in the headers (clang AST), kept if the sources of the userland projects name them,
  - the alias lists of `Libc`, `libpthread`, `libplatform` and `libdispatch`,
  - the system call stubs that xnu's `create-syscalls.pl` makes,
  - the export lists of `Libm`, `CommonCrypto` and `launchd`,
  - for x86_64 the legacy names (`_select`, `_opendir`, ...).

  Extra and excluded symbols are in `data/symbols/`, each with its source.
- **`libc++.1.tbd`, `libc++abi.tbd`**: LLVM's ABI lists of the release.
- **The other libraries and frameworks**: the declarations in their headers and the export lists  
  of their projects.
- **Install names and versions** are in `data/libraries.txt`, with the project file that states each value;  
  `helpers/check_libraries.py` checks them. A value without a public source is the lowest possible one.

## Headers written for this SDK

There is no open source header for these, so they are written for this SDK (0BSD; the sources of every  
name and value are in [SOURCES.md](SOURCES.md)):

- `TargetConditionals.h`: the target macros of macOS, with the CPU taken from the compiler's predefined macros.
- `architecture/arm64/fenv.h`: the C99 interface only, with the bit positions from the Arm Architecture  
  Reference Manual.
- `os/log.h`: `os_log` and its variants work like the system's: the compiler's builtin  
  `__builtin_os_log_format` encodes the arguments, and the program calls the function of `libSystem` that  
  logs them. With a compiler without the builtin (GCC) the macros check their arguments and log nothing.  
  Read the messages with `log show --info --debug --predicate 'process == "name"'`; tested on macOS 26.0  
  (x86_64).
- `os/signpost.h`, `os/activity.h`, `os/trace.h`: stand-ins. A program that uses them builds, links and runs,  
  but nothing is recorded. The system's interface for them has no public source, so it is not used.
- `xpc/xpc.h`: the one typedef that `Security` needs (`xpc_object_t`); nothing else of XPC.

## Changes to the sources

Headers are installed with the projects' own scripts and Makefiles (xnu header lists, Libc `headers.sh`,  
`mach_install_mig.sh`, AvailabilityVersions, `unifdef`); headers that are only filtered with `unifdef`  
stay as they are. If the generator changes a header, it adds the line  
`Modified by osxcross-open-sdk (DATE): <what>` behind the license comment (APSL 2.0 section 2.2,  
Apache 2.0 section 4).

The changes:

- missing includes, a missing semicolon and `DYLD_EXCLAVEKIT_UNAVAILABLE`  
  in `mach-o/dyld.h`, `dyld_images.h`, `string_x86.h`;
- Libm's ARM `math.h` and `complex.h` are used for arm64 too, with the condition of the Intel variant  
  for `llrint` and `llround`; `__exp10` and `__exp10f` are declared (Clang emits calls to them);
- `mach/port.h` (macOS 26.4 and later) compiles with g++;
- the platform `bridgeos` is removed from availability annotations (GCC does not know it);
- CoreFoundation: an include of `CFMachPort.h` and a small block of macros in  
  `CFAvailability.h` (CF-1153.18 of 2018 lacks them);
- CommonCrypto: `<availability.h>` is written `<Availability.h>`;
- the SDKs of macOS 14.3 and older (libc++ 16): `<format>` is no longer marked unavailable, so `<chrono>`  
  compiles with `-std=c++20`.

## Sources

- [SOURCES.md](SOURCES.md) names the public source of every value, including each key of `SDKSettings.json`.
- `data/manifests/` pins tag and commit of every project per macOS release.
- Releases that the public AvailabilityVersions does not know yet (after 14.3) come from  
  `data/availability-extra.dsl`, which names its sources.
