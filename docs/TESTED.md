# Tested projects

Open source projects that were built with the full Open SDK of macOS 26.5 for x86_64 and arm64 (OSXCross  
llvm flavor, Clang 23.1.6, `ld64.lld`, deployment target 11.0). The x86_64 programs ran on macOS 26.0:  
with the test suite of the project where it could be built, otherwise with a smoke test. 29 of the  
projects were also built with the stable flavor (cctools/ld64).

- **Compression:** `zlib`, `bzip2`, `xz`, `zstd`, `lz4`, `brotli`, `libarchive`
- **Data formats:** `expat`, `libxml2`, `libyaml`, `jansson`, `cJSON`, `json-c`, `jq`,  
  `sqlite`, `pcre2`, `oniguruma`, `nlohmann-json`
- **Network and crypto:** `curl` (also with SecureTransport), `c-ares`, `nghttp2`, `libssh2`, `mbedtls`,  
  `libressl`, `libsodium`, `libevent`, `libuv`, `openssh`, `rsync`
- **C++:** `fmt`, `spdlog`, `googletest`
- **Build tools:** `cmake`, `ninja`, `gnumake`, `pkgconf`
- **Images and fonts:** `libpng`, `libjpeg-turbo`, `libtiff`, `freetype`
- **Shells and editors:** `bash`, `nano`, `less`, `tmux`, `lua`, `ncurses`, `readline`, `libedit`
- **GNU and other tools:** `coreutils`, `grep`, `sed`, `gawk`, `findutils`, `file`, `gettext`, `libiconv`,  
  `gmp`, `mpfr`, `libffi`, `xxhash`, `lmdb`, `redis`
- **Version control:** `git`, `libgit2` (also with SecureTransport)
- **File system events:** the `git` fsmonitor daemon, `fswatch`
- **IOKit device families:** `htop` (its disk I/O meter reads `IOKit/storage`), `hidapi` (`mac/hid.c` and `hidtest`), `libusb` (`listdevs`)
- **Compilers and tools:** `LLVM/Clang` (the compiler works on macOS), `cctools-port` (builds, and its tools work on macOS),  
  `compiler-rt` (builds, and its runtimes work on macOS)

**Not covered**

- The Xcode generator of `cmake` is switched off: it needs `ApplicationServices`.
- Projects that need `Foundation`, `AppKit` or `Metal` were not tried.

**What the builds showed**

- Some projects exposed errors of the SDK (missing headers or symbols); they are fixed.
- Several projects needed a workaround in the project or the toolchain (a `configure` option, a `make` variable,  
  a newer `config.sub`).
