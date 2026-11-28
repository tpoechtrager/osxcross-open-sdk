# Tested projects

Open source projects that were built with the full Open SDK of macOS 26.5 for x86_64 and arm64 (OSXCross  
llvm flavor, Clang 23.1.6, `ld64.lld`, deployment target 11.0). The x86_64 programs ran on macOS 26.0:  
with the test suite of the project where it could be built, otherwise with a smoke test.  
`tests/projects.sh` builds and tests the projects except the Rust crates, see [BUILDING.md](BUILDING.md#tests).

- **Compression:** `zlib`, `bzip2`, `xz`, `zstd`, `lz4`, `brotli`, `libarchive`
- **Data formats:** `expat`, `libxml2`, `libyaml`, `jansson`, `cJSON`, `json-c`, `jq`,  
  `sqlite`, `pcre2`, `oniguruma`, `nlohmann-json`
- **Network and crypto:** `curl` (also with SecureTransport), `c-ares`, `nghttp2`, `libssh2`, `mbedtls`,  
  `libressl`, `libsodium`, `libevent`, `libuv`, `openssh`, `rsync`, `openvpn`, `aria2` (SecureTransport),  
  `libzip` (CommonCrypto), `sudo` (OpenPAM; `visudo` runs), `tcpdump` (libpcap)
- **C++:** `fmt`, `spdlog`, `googletest`
- **Build tools:** `cmake`, `ninja`, `gnumake`, `pkgconf`
- **Images and fonts:** `libpng`, `libjpeg-turbo`, `libtiff`, `freetype`
- **Shells and editors:** `bash`, `nano`, `less`, `tmux`, `vim` (without its Darwin part), `lua`, `ncurses`, `readline`, `libedit`
- **GNU and other tools:** `coreutils`, `grep`, `sed`, `gawk`, `findutils`, `file`, `gettext`, `libiconv`,  
  `gmp`, `mpfr`, `libffi`, `xxhash`, `lmdb`, `redis`
- **Version control:** `git`, `libgit2` (also with SecureTransport)
- **File system events:** the `git` fsmonitor daemon, `fswatch`, `efsw` (a program watches a directory)
- **IOKit device families:** `htop` (its disk I/O meter reads `IOKit/storage`), `hidapi` (`hidtest`),  
  `libusb` (`listdevs`, `testlibusb` and its tests `set_option`, `init_context`), `dfu-util`,  
  `libfido2` (`fido2-token`; IOKit HID), `osx-cpu-temp` (SMC),  
  `libserialport` (`list_ports`; IOKit serial)
- **OpenGL:** `glew` (a program makes a context with the software renderer and calls `glewInit`)
- **Games (OpenGL):** `Cube 2: Sauerbraten` (with the SDL2 frameworks of SDL's releases; shows its menu and plays a map)
- **Rust crates** (Rust 1.100, OSXCross as the linker; the crates declare what they use of the frameworks):
  - `winit` (opens a window)
  - `core-graphics`, `core-text`
  - `cpal` (lists the audio devices)
  - `enigo`, `global-hotkey` (Carbon) were built, but not tested
  - `rdev` (Carbon; display size)
  - `sysinfo` (OpenDirectory; memory, CPUs, disks; x86_64 only)
  - `wry` with `tao` (WebKit) were built, but not tested
  - `rfd` (UniformTypeIdentifiers) was built, but not tested; it needs `-framework CoreGraphics` as well
  - `glutin` with `glow` (a window with an OpenGL context; draws and reads a pixel back)
  - `eframe` with the glow backend (OpenGL; opens its window and draws frames)
  - `skia-safe` with the prebuilt Skia (draws into a bitmap)
  - `wgpu` was built, but not tested
  - `xcap` (AVFoundation, CoreMedia; lists the monitors), `nokhwa` (AVFoundation; lists the cameras)
  - `macroquad` (ImageIO, Vision, MetalKit) was built, but not tested
- **Compilers and tools:**
  - `LLVM/Clang` (the compiler works on macOS)
  - `cctools-port` (builds, and its tools work on macOS)
  - `compiler-rt` (builds, and its runtimes work on macOS)
- **Swift** (6.4.3 with the Swift add-on and SwiftPM, deployment target 14.0):  
  `swift-collections`, `swift-algorithms`, `swift-numerics`, `swift-atomics` (a program uses their libraries)

**Not covered**

- The Xcode generator of `cmake` is switched off: it needs the headers of `ApplicationServices`.
- C and Objective-C code that includes the headers of `Foundation`, `AppKit` or `Metal` (the SDK has only their link stubs).

**What the builds showed**

- Some projects exposed errors of the SDK (missing headers or symbols); they are fixed.
- Several projects needed a workaround in the project or the toolchain (a `configure` option, a `make` variable,  
  a newer `config.sub`).
