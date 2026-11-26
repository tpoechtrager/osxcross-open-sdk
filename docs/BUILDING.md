# Building the SDK

How to build the SDK with `make-open-sdk.sh`. Back to the [README](../README.md).

## Quick start

```sh
./make-open-sdk.sh                  # full SDK of macOS 26.5 -> out/
./make-open-sdk.sh --core           # core SDK
./make-open-sdk.sh --macos 14.3     # SDK of macOS 14.3
./make-open-sdk.sh --list-releases  # releases that can be built
./make-open-sdk.sh --help           # all options
```

A run clones about 450 MB of sources (pinned tags).

## Dependencies

All hosts need:

- `bash` 3.2 or newer, `git`, `python3` 3.7 or newer, `perl`, GNU `make`
- `flex` and `yacc` (or `bison`)
- `clang` 11 or newer (tested: 11, 14, 16, 17 and 23; Clang 10 does not know macOS 11)
- `tar` and `xz` (or `bsdtar`)
- `curl`, for the full SDK (the sqlite archive)

The script checks the tools at the start and names the missing ones.

What to install besides the base system:

**Linux** (Debian/Ubuntu):

```sh
apt install git curl python3 perl make flex bison clang xz-utils
```

**macOS:** the Command Line Tools provide `git`, `curl`, `python3`, `perl`, `make`, `flex`, `clang` and `bsdtar`  
(`xz` is not needed, `bsdtar` compresses). Their `yacc` is a stub that needs Xcode, so add `bison`  
from MacPorts or Homebrew:

```sh
xcode-select --install
brew install bison        # or: port install bison
```

**FreeBSD** (packages; `clang`, `flex`, `yacc`, `xz` and `bsdtar` are in the base system):

```
git curl python3 perl gmake bash
```

**OpenBSD** (packages; `clang`, `flex`, `yacc` and `bsdtar` come from the base system or the packages):

```
git curl python3 perl gmake bash xz
```

The script looks for bison in `/opt/local/bin`, `/opt/homebrew/opt/bison/bin` and `/usr/local/opt/bison/bin`;  
`OPEN_SDK_YACC` names another one.

**Tested:** the SDKs are built and checked on Linux. The syntax of the script and its unit tests ran under  
`/bin/bash` 3.2 of macOS 26.0. Earlier versions of the script also built the SDK on macOS 26.0, FreeBSD 15.1  
and OpenBSD 8.0.

## Options (`./make-open-sdk.sh`)

| Option | Meaning |
|---|---|
| `--macos VERSION` | another macOS release (`--list-releases`, `data/releases.txt`; default 26.5; full SDK from 14.3, core SDK from 11.3) |
| `--min-deployment-target VERSION` | lowest deployment target in `SDKSettings.json` (default 11.0, from `data/releases.txt`) |
| `--core` | the core SDK (no `libs` and `frameworks` steps) |
| `--libcxx VERSION` | libc++ of another LLVM release (16.0.6 to 22.1.8, see [libc++](LIBCXX.md)) |
| `--clang PATH` | the clang that builds the host tools and parses the headers |
| `-w`, `--work-dir DIR` | sources and build files (default `build/`) |
| `-o`, `--output-dir DIR` | where the tarball goes (default `out/`) |
| `-s`, `--steps "STEPS"` | run only these steps |
| `--tree-hash` | print a SHA-256 over the file tree (types, names, link targets, executable bits and contents) after the tarball |
| `--force` | replace an output file that this script did not make |
| `-v`, `--verbose` | also show the output that otherwise goes only to logs, and every command that the steps run (lines that start with `+`); it is in `build.log` too |
| `--clean`, `--clean-all` | delete the build files (keeping `src/`), or the work directory |
| `--show-config`, `--version` | print what would be built, or the commit of the script |

Relative paths are taken from the current directory. The script reads only its options and the variables  
`OPEN_SDK_WORK_DIR`, `OPEN_SDK_OUTPUT_DIR`, `OPEN_SDK_CLANG`, `OPEN_SDK_YACC`, `OPEN_SDK_BUILD_VERSION`,  
`OPEN_SDK_MIN_DEPLOYMENT_TARGET`, `OPEN_SDK_SWIFT_PKG`, `OPEN_SDK_AV_TAG` and `OPEN_SDK_BSDTAR`.  
The variables of OSXCross (`SDK_VERSION`, `TARBALL_DIR`, ...) have no effect.

**Output:** `out/MacOSX<VER>-open-sdk-<hash>.tar.xz`, or `MacOSX<VER>-open-core-sdk-<hash>.tar.xz` with `--core`.  
The `-open` keeps it apart from a tarball made from Apple's SDK. What `<hash>` is, and how an SDK names its  
commit, is in the [README](../README.md#download).

**Steps:** `fetch host headers stubs cxx libs frameworks meta tarball`. `fetch` checks every clone  
against the commit in `data/manifests/` and stops if a tag was moved. A failing step stops the script;  
the logs are in the work directory.

**Swift add-on** (not a default step): adds stubs of the Swift runtime, made from the dylibs  
of the swift.org package (Apache 2.0; the script has no checksum for it) and needs bsdtar.  
Swift 6.4.3 was tested with the full SDK and deployment target 14.0 (the lowest that works):  
`import Swift` and `import CoreFoundation` work.

```sh
OPEN_SDK_SWIFT_PKG=swift-<version>-RELEASE-osx.pkg ./make-open-sdk.sh -s swift
```

## Tests

```sh
tests/lint.sh                                     # bash -n, shellcheck, Python syntax
tests/unit/run.sh                                 # helpers, data files, options and shell functions
tests/sdk-check.sh out/MacOSX26.5-open-sdk-<hash>.tar.xz # every header alone
tests/run.sh --osxcross /path/to/osxcross/target  # the test programs
```

`tests/sdk-check.sh` compiles every header of `usr/include` on its own (C and C++, x86_64 and arm64;  
`--gcc` also with GCC). `tests/run.sh` builds `tests/programs/` for both architectures and runs them  
on a Mac with `--ssh HOST`. Last result: all 11 SDKs (7 core, 4 full) pass both checks,  
and their x86_64 programs ran on macOS 26.0.

## New macOS releases

`helpers/manifest.py --new <version>` writes the manifest of a release from distribution-macOS.  
Then add a line to `data/releases.txt` (libc++ release, variants, `ProductBuildVersion` with its source),  
the LLVM release to `data/libcxx-versions.txt` if it is new, and the versions of the other platforms  
to `data/availability-extra.dsl`, build, check with `tests/sdk-check.sh` and `tests/run.sh`,  
and update the docs.
