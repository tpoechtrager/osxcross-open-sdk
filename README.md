# osxcross-open-sdk

A macOS SDK for [OSXCross](https://github.com/tpoechtrager/osxcross) and other toolchains, built from open source only.

- [What it is](#what-it-is)
- [Download](#download)
- [Use of Open SDK in OSXCross](#use-of-open-sdk-in-osxcross)
- [Building the SDK](#building-the-sdk)
- [Licenses](#licenses)
- [Known limits](#known-limits)
- [More documentation](#more-documentation)

---

## What it is

osxcross-open-sdk is an open macOS SDK: it contains **nothing proprietary of Apple's** and is not  
derived from an SDK made by Apple. It is built by `make-open-sdk.sh` from public sources only,  
so it can be shared, for example in public container images and in CI jobs.  
Every file comes from one of these:

- Apple's open source releases ([apple-oss-distributions](https://github.com/apple-oss-distributions),  
  APSL 2.0 and the licenses of the single projects), at the tags of a macOS release;
- LLVM (`libc++` and `libc++abi`);
- other open source projects (`sqlite3`, liblzma of `xz`; the Swift runtime of swift.org for the optional Swift add-on);
- files written for this SDK (0BSD): a few headers and the `.tbd` stubs.

[docs/SOURCES.md](docs/SOURCES.md) names the public source of every header, symbol list,  
install name and version. A real SDK was used only to test a result, never as a source.

### What works

- C, C++ (libc++), Objective-C without Foundation and Swift without Foundation, for x86_64 and arm64.
- **GCC** (OSXCross `build_gcc.sh`): C, C++ and Fortran, for x86_64 and arm64.
- The C library, POSIX, Mach, `pthreads`, `libdispatch`, blocks.
- Libraries of `/usr/lib`: `zlib`, `bzip2`, `expat`, `libffi`, `libedit` (with the readline layer),  
  `libxml2`, `libxslt`, `sqlite3`, `liblzma` (stub only, without `lzma.h`), `libcurl`, `libarchive`, `libpcap`,  
  `OpenPAM`, `ncurses`, `libiconv`, `libresolv`, `CommonCrypto`, the launchd API, `dns_sd`.
- `os_log` (`<os/log.h>`): the messages appear in the unified log of macOS, see [docs/DETAILS.md](docs/DETAILS.md#headers-written-for-this-sdk).  
  Signposts, activities and `os_trace` compile and run but record nothing.
- The frameworks `CoreFoundation`, `DiskArbitration`, `SystemConfiguration`, `Security` (including `SecureTransport`)  
  and `IOKit` (`IOKitLib`, power sources, power management and the device families `storage`, `hid`,  
  `hidsystem`, `graphics`, `i2c`, `ndrvsupport` and `usb`).
- XPC (`<xpc/xpc.h>`): the documented C interface up to macOS 12.0, see [docs/DETAILS.md](docs/DETAILS.md#headers-written-for-this-sdk).
- File System Events (`<CoreServices/CoreServices.h>`, only this part of `CoreServices`), see [docs/DETAILS.md](docs/DETAILS.md#headers-written-for-this-sdk).
- The sanitizer runtimes of compiler-rt build against the full SDK: `asan`, `ubsan`, `lsan`, `tsan`, `rtsan`, `tysan`.

### What does not work

- **`Foundation`, `AppKit`** and all other frameworks: there is no public source for them.  
  `Foundation` is an empty placeholder, so that `-framework Foundation`  
  links; `#import <Foundation/Foundation.h>` fails.
- Swift with `Foundation`, `import Darwin` (no module maps except the one of `CoreFoundation`).
- `libbsm`, the other `IOKit` device families (`storage/ata`, `network`, ...) and `CoreServices` except File System Events.
- `IOKit/hidsystem/IOHIDEventSystemClient.h` and `IOHIDServiceClient.h`: no open source defines their functions  
  (see [docs/SOURCES.md](docs/SOURCES.md#iokit-device-families)).
- XPC sessions and listeners (`xpc_session`, `xpc_listener`) and the parts of XPC that have no public value  
  (see [docs/SOURCES.md](docs/SOURCES.md#xpcxpch-and-its-symbols)).

### Variants

| Variant | macOS releases | Architectures | Size (26.5) |
|---|---|---|---|
| full (default) | 14.3, 15.5, 26.0, 26.5 | x86_64, arm64 | 2.7 MB |
| core (`--core`) | 11.3, 12.3, 13.3, 14.3, 15.5, 26.0, 26.5 | x86_64, arm64 | 1.7 MB |

- **full** has everything listed under [What works](#what-works).
- **core** has only C, C++ and POSIX: the headers of the C library and `libc++`, and the stubs of `libSystem`,  
  `libresolv`, `libc++`, `libc++abi` and `libiconv`. It is meant for code that needs only the C and C++ library:  
  GCC with `libstdc++`, and small CI jobs.

### Tested projects

Open source projects built with the full Open SDK of macOS 26.5 for x86_64 and arm64 include  
`zlib`, `curl`, `git`, `cmake`, `sqlite`, `bash`, `coreutils`, `fmt`, `redis`, `LLVM/Clang` and `cctools-port`.

The x86_64 builds ran on macOS 26.0. The full list, what each build needed and what does not build  
is in [docs/TESTED.md](docs/TESTED.md).

---

## Download

The tarballs are attached to the [GitHub releases](../../releases) of this repository:

| File | SDK |
|---|---|
| `MacOSX<VER>-open-sdk-<hash>.tar.xz` | full |
| `MacOSX<VER>-open-core-sdk-<hash>.tar.xz` | core |
| `SHA256SUMS` | SHA-256 of the tarballs |

`<VER>` is the macOS release (see [Variants](#variants)), `<hash>` the first 7 characters of the git commit hash  
of this repository that built the SDK.

**Identifying an SDK.** Every SDK contains files that say which build it is:

- `OpenSDK.json` in its root: the generator commit hash, the macOS release, the variant, the libc++ release, and  
  the tag and commit hash of every project.
- `SDKSettings.json` and `SDKSettings.plist`: the generator commit hash (key `OpenSDKGeneratorCommit`).

The hash is `unknown` if the generator is not a git checkout, and ends with `-modified` if tracked files  
are changed; the script warns in both cases.  
With `unknown`, the notices in the changed headers carry the day of the build instead of the date of the commit,  
and the SDK is not reproducible; the script warns about that too.

**Reproducible.** Two builds give the same file tree if they use

- the same commit of this repository, and
- the same macOS release and the same options (`--core`, `--libcxx`, `--min-deployment-target`).

The compiler does not matter (tested: Clang 11 to 23). The `.tar.xz` files themselves can still differ,  
depending on the versions of `tar` and `xz`. `make-open-sdk.sh --tree-hash` prints a hash of the file tree  
instead: two builds that match in the points above print the same hash.

## Use of Open SDK in OSXCross

Put the tarball into the `tarballs/` directory of OSXCross and build as usual; the names of the tarballs  
have the form `MacOSX<VER>-open-sdk-<hash>.tar.xz` and `MacOSX<VER>-open-core-sdk-<hash>.tar.xz`:

```sh
cp MacOSX26.5-open-sdk-<hash>.tar.xz osxcross/tarballs/
cd osxcross && ./build.sh
```

The directory inside the tarball is `MacOSX26.5.sdk`, as OSXCross expects. The lowest deployment target  
that the SDK names is 11.0 (`--min-deployment-target` changes it, see [Options](docs/BUILDING.md#options-make-open-sdksh)).

---

## Building the SDK

`make-open-sdk.sh` builds the SDK from the public sources;  
`--macos 14.3,26.5` or `--macos all` builds several, `--release` all of them with `SHA256SUMS`.  
The full guide, with dependencies, options, steps and tests, is in [docs/BUILDING.md](docs/BUILDING.md).

---

## Licenses

- The generator: GPL-2.0-only ([LICENSE](LICENSE)), including `data/` and `tests/`.
- Files written for the SDK (listed in `data/own-files.txt`: `TargetConditionals.h`, `os/log.h`, `xpc/xpc.h`,  
  `CoreServices/FSEvents.h`, the `.tbd` stubs, the settings, ...): 0BSD, so programs that include them are not affected.
- Apple's open source projects: mostly APSL 2.0; `libdispatch`, `launchd` and `mDNSResponder` Apache 2.0;  
  others BSD, MIT or zlib (parts of `Libc`, `libarchive`, `libpcap`, OpenPAM, `expat`, `libffi`, `libxml2`, `curl`, `zlib`).
- `libc++` and `libunwind`: Apache 2.0 with LLVM exceptions; `sqlite3`, `liblzma`: public domain.

Every SDK carries the full license texts of each project in `usr/share/licenses/open-sdk/<project>/`,  
with `LICENSES.md`, which names project, tag, license and the SDK files that come from it.  
A project without a license file gets the notice block of its headers, or the published text of its license  
(`launchd`: the Apache License 2.0 of apache.org). This is a description of the facts, not legal advice.

## Known limits

- **Symbols that macOS does not export.** A symbol is in a `.tbd` if a header declares it and  
  the open sources mention it. Some are not defined in the libSystem of every macOS release;  
  a program that uses one links but stops at start with "symbol not found".
- **Versions.** Stubs without a public version source (`sqlite3`, `liblzma`, `Foundation`, `CoreServices`)  
  have the lowest compatibility version.
- **`CoreFoundation`** is CF-1153.18 (2018), the last one Apple published: newer CF APIs are missing.
- **arm64e and x86_64h.** The stubs give arm64e the symbols of arm64. x86_64h is not listed:  
  the linker uses the x86_64 symbols for it.

---

## More documentation

- [docs/BUILDING.md](docs/BUILDING.md): dependencies, options, steps, tests, new macOS releases
- [docs/TESTED.md](docs/TESTED.md): the projects that were built with the SDK
- [docs/LIBCXX.md](docs/LIBCXX.md): libc++, availability, the static libc++
- [docs/DETAILS.md](docs/DETAILS.md): stub libraries, the headers written for this SDK, changes to the sources, sources
- [docs/SOURCES.md](docs/SOURCES.md): the public source of every value
