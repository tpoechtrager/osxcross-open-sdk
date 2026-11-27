# Building the SDK

How to build the SDK with `make-open-sdk.sh`. Back to the [README](../README.md).

## Quick start

```sh
./make-open-sdk.sh                  # full SDK of macOS 26.5 -> out/
./make-open-sdk.sh --core           # core SDK
./make-open-sdk.sh --macos 14.3     # SDK of macOS 14.3
./make-open-sdk.sh --macos 14.3,26.5  # both, one after the other
./make-open-sdk.sh --macos all --core # the core SDK of every release
./make-open-sdk.sh --release        # every SDK of every release, with SHA256SUMS
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

**Tested:** the SDKs of macOS 26.5 (full and `--core`) are built on Linux, macOS 26.0 (Intel, `/bin/bash` 3.2),  
FreeBSD 15.1 and OpenBSD 8.0 with the same `--tree-hash`; the unit tests ran on macOS.  
The `clang` of FreeBSD and OpenBSD has no `stdbool.h`, `stdarg.h` and `float.h`;  
the symbol scans then bring their own (see [SOURCES.md](SOURCES.md#c-headers-of-the-scans)).

## Options (`./make-open-sdk.sh`)

| Option | Meaning |
|---|---|
| `--macos VERSION` | another macOS release (`--list-releases`, `data/releases.txt`; default 26.5; full SDK from 14.3, core SDK from 11.3) |
| `--macos LIST` | several releases, comma-separated (`14.3,26.5`) or `all` (every release of `data/releases.txt`) |
| `--release` | every release, the full SDK (where there is one) and the core SDK of each |
| `--min-deployment-target VERSION` | lowest deployment target in `SDKSettings.json` (default 11.0, from `data/releases.txt`) |
| `--core` | the core SDK (no `libs` and `frameworks` steps) |
| `--libcxx VERSION` | libc++ of another LLVM release (16.0.6 to 22.1.8, see [libc++](LIBCXX.md)) |
| `--clang PATH` | the clang that builds the host tools and parses the headers |
| `-w`, `--work-dir DIR` | sources and build files (default `build/`) |
| `-o`, `--output-dir DIR` | where the tarball goes (default `out/`) |
| `-s`, `--steps "STEPS"` | run only these steps; they use the staging of an earlier run and stop if it was made for another release, variant, libc++ or deployment target |
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

**Several SDKs.** With `--macos LIST` (or `all`) the script builds the SDKs one after the other, each by a run of itself  
in `<work-dir>/<VERSION>` (`<VERSION>-core` with `--core`); a list of one release is a normal run.  

- The sources are not shared: the clones of `src/` hold one tag per project, and the releases use different tags.
- Without `--core`, `all` makes the core SDK of the releases that have no full SDK (11.3 to 13.3);
  a release that is named needs `--core` for that, as with one release.
- A SDK that fails does not stop the others; the script lists the failed ones and exits with status 1.
- `--libcxx` and `OPEN_SDK_BUILD_VERSION` need exactly one release.
- `--clean`, `--clean-all` and `--show-config` act on every SDK of the list.

`--release` builds every SDK of every release (not with `--macos` or `--core`) into `<output-dir>/release/<commit>/`,  
with a `SHA256SUMS` file there (sorted by name, the format of `sha256sum` and `shasum -a 256`; only if all were made).  
It stops if the commit of this repository is `-modified` or `unknown`.  
With `--tree-hash`, the tree hashes of all SDKs are printed again at the end.

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
tests/projects.sh --osxcross ~/dev/osxcross --sdk out/MacOSX26.5-open-sdk-<hash>.tar.xz # the projects of TESTED.md
```

`tests/sdk-check.sh` compiles every header of `usr/include` on its own (C and C++, x86_64 and arm64;  
`--gcc` also with GCC). `tests/run.sh` builds `tests/programs/` for both architectures and runs them  
on a Mac with `--ssh HOST`. Last result: all 11 SDKs (7 core, 4 full) pass both checks,  
and their x86_64 programs ran on macOS 26.0.

**OSXCross of `tests/projects.sh`:**
- `--osxcross DIR`: an OSXCross target, or a checkout whose `target/` is used if it is built;  
  otherwise a target is built from `git archive` of the checkout (the checkout is never written).
- Without `--osxcross`, OSXCross is cloned (`OSXCROSS_GIT`, `OSXCROSS_REF`; default: master of  
  github.com/tpoechtrager/osxcross) and built.
- A built target is kept in `build/osxcross` for the next run; `--flavor llvm|stable` builds one also  
  if the checkout has a target.
- The SDK of `--sdk` is selected with `SDKROOT`, so one target builds with every SDK.

**`tests/projects.sh`** builds the projects of [TESTED.md](TESTED.md) for x86_64 and arm64 and, with  
`--ssh HOST`, runs the x86_64 programs and tests of the projects on a Mac.
- The sources (URL, SHA-256), recipes and tests are in the script; downloads are kept in `build/projects/dl`.
- `--list` shows the projects of the groups, `--only "NAME ..."` builds some of them (and what they need).
- Groups (`--group`): `main` (the default), `compilers` (LLVM, compiler-rt, cctools-port: very large),  
  `games` (Cube 2: Sauerbraten with the SDL frameworks of SDL's releases; needs `7z` or `7zz`) and `all`.
- With a core SDK the projects that need the full SDK are shown as "full only"; a project whose tool is  
  missing as "no tool". Neither counts as a failure.
- The test of Cube 2: Sauerbraten opens a window: the user of `--ssh` must be logged in at the Mac.

## New macOS releases

`tools/manifest.py --new <version>` writes the manifest of a release from distribution-macOS.  
Then add a line to `data/releases.txt` (libc++ release, variants, `ProductBuildVersion` with its source),  
the LLVM release to `data/libcxx-versions.txt` if it is new, and the versions of the other platforms  
to `data/availability-extra.dsl`, build, check with `tests/sdk-check.sh` and `tests/run.sh`,  
and update the docs.  
The lists of `data/symbols/doc/` come from Apple's documentation: `tools/doc_symbols.py --help` says  
how to make them again from newer pages.
The list of CoreFoundation needs the `Headers` of a built SDK (`--headers`): it has only the names that no header mentions,  
so make it again after a change of those headers.
