# osxcross-open-sdk

A macOS SDK for [OSXCross](https://github.com/tpoechtrager/osxcross) and other toolchains, built from open source only.

- [What it is](#what-it-is)
- [Documentation](#documentation)
- [Variants](#variants)
- [Getting the Open SDK](#getting-the-open-sdk)
- [What works](#what-works)
- [What does not work](#what-does-not-work)
- [Known limits](#known-limits)
- [Possible additions](#possible-additions)
- [Licenses](#licenses)

---

## What it is

The Open SDK is a macOS SDK built from open source only (by `make-open-sdk.sh`).  
It contains **nothing proprietary of Apple's**: no file, header text or symbol list is taken from an SDK  
or a program made by Apple, so it can be shared, for example in public container images and in CI jobs.  
Every file comes from one of these:

- Apple's open source releases ([apple-oss-distributions](https://github.com/apple-oss-distributions),  
  APSL 2.0 and the licenses of the single projects), at the tags of a macOS release;
- LLVM (`libc++` and `libc++abi`);
- other open source projects (`sqlite3`, liblzma of `xz`; the Swift runtime of swift.org for the optional Swift add-on);
- files written for the Open SDK (0BSD): a few headers and the `.tbd` stubs, with names, signatures and values from open  
  source projects and from Apple's public documentation.

[docs/SOURCES.md](docs/SOURCES.md) names the public source of every header, symbol list,  
install name and version. A real SDK was used only to test a result, never as a source.

## Documentation

| File | Content |
|---|---|
| [docs/FEATURES.md](docs/FEATURES.md) | What works, what does not, known limits |
| [docs/TESTED.md](docs/TESTED.md) | The projects that were built with the Open SDK |
| [docs/BUILDING.md](docs/BUILDING.md) | Dependencies, options, tests, reproducible builds, new macOS releases |
| [docs/SOURCES.md](docs/SOURCES.md) | The public source of every value |
| [docs/DETAILS.md](docs/DETAILS.md) | Stub libraries, the headers written for the Open SDK, changes to the sources, licenses |
| [docs/LIBCXX.md](docs/LIBCXX.md) | libc++, availability, the (optional) static libc++ |

## Variants

| Variant | macOS releases | Architectures | Size (26.5) |
|---|---|---|---|
| full (default) | 14.3, 15.5, 26.0, 26.5 | x86_64, arm64 | 2.7 MB |
| core (`--core`) | 11.3, 12.3, 13.3, 14.3, 15.5, 26.0, 26.5 | x86_64, arm64 | 1.7 MB |

- **full** has everything listed under [What works](#what-works).
- **core** has only C, C++ and POSIX: the headers of the C library and `libc++`, and the stubs of `libSystem`,  
  `libresolv`, `libc++`, `libc++abi` and `libiconv`. It is meant for code that needs only the C and C++ library:  
  GCC with `libstdc++`, and small CI jobs.

## Getting the Open SDK

### Download

The [GitHub releases](../../releases) of this repository have the tarballs of every macOS release  
(see [Variants](#variants)), with `SHA256SUMS`:

- `MacOSX<VER>-open-sdk-<hash>.tar.xz`: the full Open SDK
- `MacOSX<VER>-open-core-sdk-<hash>.tar.xz`: the core Open SDK

`<VER>` is the macOS release, `<hash>` the commit of this repository that built it  
(see [Identifying an SDK](docs/BUILDING.md#identifying-an-sdk)).

### Use in OSXCross

```sh
cp MacOSX26.5-open-sdk-<hash>.tar.xz osxcross/tarballs/
cd osxcross && ./build.sh
```

The tarball contains `MacOSX26.5.sdk`, as OSXCross expects. The lowest deployment target that the Open SDK names  
is 11.0 (`--min-deployment-target` changes it, see [Options](docs/BUILDING.md#options-make-open-sdksh)).

### Build it yourself

```sh
./make-open-sdk.sh                    # the full Open SDK of macOS 26.5, into out/
./make-open-sdk.sh --core --macos 14.3  # the core Open SDK of macOS 14.3
```

Dependencies, options and reproducible builds: [docs/BUILDING.md](docs/BUILDING.md).

## What works

- C, C++ (libc++), Objective-C without Foundation and Swift without Foundation, for x86_64 and arm64.
- **GCC**: OSXCross `build_gcc.sh` builds with it, with C, C++ and Fortran for x86_64 and arm64.
- The C library, POSIX, Mach, `pthreads`, `libdispatch`, blocks, `os_log`, XPC, and the libraries of `/usr/lib`  
  (`zlib`, `libxml2`, `sqlite3`, `libcurl`, `libpcap`, `ncurses`, ...).
- The frameworks `CoreFoundation`, `Security`, `SystemConfiguration`, `DiskArbitration`, `OpenGL`, File System Events  
  and `IOKit` with its device families (`storage`, `hid`, `usb`, `serial`, ...).
- Link stubs without headers of `Foundation`, `AppKit`, `Metal`, `QuartzCore`, `WebKit` and other frameworks,  
  for languages that declare what they use themselves (Rust: `winit`, `wgpu`, ...).
- Open source projects such as `curl`, `git`, `cmake`, `tcpdump`, `vim` and `LLVM/Clang` build with it;  
  their x86_64 builds ran on macOS 26.0 ([docs/TESTED.md](docs/TESTED.md)).

Details: [docs/FEATURES.md](docs/FEATURES.md#what-works).

## What does not work

- **`Foundation`, `AppKit`** and the other frameworks without public source: no headers,  
  so `#import <Foundation/Foundation.h>` fails.
- Swift with `Foundation`, `import Darwin`.
- Frameworks without a stub (`CoreData`, `GameController`, `IOSurface`, ...) and some `IOKit` device families.

Details: [docs/FEATURES.md](docs/FEATURES.md#what-does-not-work).

## Known limits

- The Open SDK can list a few functions that not every macOS release has. A program that calls one links,  
  and only stops at start with "symbol not found"; with Apple's SDK it would not link.  
  Code that already builds with Apple's SDK is not affected.
- The headers of `CoreFoundation` are from 2018, the last release Apple published, with newer declarations  
  from swift-corelibs-foundation. Some newer functions can be linked, but you have to declare them yourself.

Details: [docs/FEATURES.md](docs/FEATURES.md#known-limits).

## Possible additions

The Open SDK covers most of what open sources allow under the rules of this repository  
([AGENTS.md](AGENTS.md#the-rule-that-matters-most): nothing comes from an SDK or a binary of Apple's).  

What could still be added:

- What [metal-cpp](https://github.com/apple/metal-cpp) needs (`CoreGraphics/CGGeometry.h`, `IOSurface/IOSurfaceRef.h`  
  and three `Foundation` constants), so that Metal programs in C++ build.
- The C API of JavaScriptCore (`JavaScriptCore/JavaScript.h`), from WebKit's open source.
- Link stubs of more frameworks, and the Objective-C class names in the link stubs, from Apple's documentation.
- More `IOKit` device families (`network`, `storage/ata`, ...) and module maps for `import Darwin`.
- A core Open SDK of macOS 10.13 with i386.

What is not possible:

Headers of `Foundation`, `AppKit` and the other frameworks without public source.  
Apple's documentation names their functions, classes and types, which is enough for a stub, but not for a header:  
it has no macros, no values of the enumerations, no layouts of the structures and no inline functions,  
and no other public source has them all. Wrong values would only fail at run time.

## Licenses

- The generator: GPL-2.0-only ([LICENSE](LICENSE)), including `data/` and `tests/`.
- Files written for the Open SDK (`data/own-files.txt`): 0BSD, so programs that include them are not affected.
- Everything else keeps the license of its project: mostly APSL 2.0 (Apple's open source), Apache 2.0 with  
  LLVM exceptions (`libc++`), BSD, MIT, zlib or public domain.

Every Open SDK carries the full license texts in `usr/share/licenses/open-sdk/<project>/`, and `LICENSES.md`  
names the project, tag and license of every file ([details](docs/DETAILS.md#licenses-in-the-sdk)).  
This is a description of the facts, not legal advice.
