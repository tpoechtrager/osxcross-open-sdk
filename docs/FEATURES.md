# What the Open SDK can do

What works with the full Open SDK, what does not, and its known limits. Back to the [README](../README.md).

- [What works](#what-works)
- [What does not work](#what-does-not-work)
- [Known limits](#known-limits)

## What works

- C, C++ (libc++), Objective-C without Foundation and Swift without Foundation, for x86_64 and arm64.
- **GCC** (OSXCross `build_gcc.sh`): C, C++ and Fortran, for x86_64 and arm64.
- The C library, POSIX, Mach, `pthreads`, `libdispatch`, blocks.
- Libraries of `/usr/lib`: `zlib`, `bzip2`, `expat`, `libffi`, `libedit` (with the readline layer),  
  `libxml2`, `libxslt`, `sqlite3`, `liblzma` (stub only, without `lzma.h`), `libcurl`, `libarchive`, `libpcap`,  
  `OpenPAM`, `ncurses`, `libiconv`, `libresolv`, `CommonCrypto`, the launchd API, `dns_sd`.
- `os_log` (`<os/log.h>`): the messages appear in the unified log of macOS, see [DETAILS.md](DETAILS.md#headers-written-for-this-sdk).  
  Signposts, activities and `os_trace` compile and run but record nothing.
- The frameworks `CoreFoundation`, `DiskArbitration`, `SystemConfiguration`, `Security` (including `SecureTransport`)  
  and `IOKit` (`IOKitLib`, power sources, power management and the device families `storage`, `hid`,  
  `hidsystem`, `graphics`, `i2c`, `ndrvsupport`, `serial` and `usb`).
- XPC (`<xpc/xpc.h>`): the documented C interface up to macOS 12.0 and sessions, listeners and rich errors (13.0, 14.0), see [DETAILS.md](DETAILS.md#headers-written-for-this-sdk).
- File System Events (`<CoreServices/CoreServices.h>`, the only headers of `CoreServices`), see [DETAILS.md](DETAILS.md#headers-written-for-this-sdk).
- Link stubs without headers of `Foundation`, `CoreGraphics`, `AppKit`, `CoreText`, `CoreVideo`, `QuartzCore`, `Metal`,  
  `CoreAudio`, `AudioToolbox`, `ApplicationServices` (with `ColorSync`), `Carbon`, `WebKit`,  
  `UniformTypeIdentifiers`, `OpenDirectory`, `AVFoundation`, `CoreMedia`, `ImageIO`, `Vision` and `MetalKit`:  
  the C functions and constants of Apple's documentation, for languages and crates that declare what they use themselves  
  (Rust: `winit`, `wgpu`, `cpal`, `enigo`, `global-hotkey`, `xcap`, `nokhwa`, `macroquad`), see [DETAILS.md](DETAILS.md#stub-libraries-tbd) and [TESTED.md](TESTED.md).
- `Cocoa.framework`: the umbrella, a stub that re-exports `AppKit` and `Foundation` (`-framework Cocoa`; no headers, no `CoreData`).
- Every framework has the layout of a framework bundle: `Name.framework/Versions/<V>/Name.tbd` (the path of its install name),  
  `Versions/Current` and links `Name.tbd`, `Headers` and `Modules` at the top.
- `OpenGL.framework`: the headers `gl.h` (legacy, up to 2.1), `gl3.h` (core, 3.2 to 4.1), `glext.h`, `gl3ext.h`, `gltypes.h` and the CGL headers  
  (`OpenGL.h`, `CGLTypes.h`, `CGLCurrent.h`, `CGLDevice.h`, `CGLIOSurface.h`, `CGLRenderers.h`), and the link stub.  
  The OpenGL part is made from the Khronos Registry's `gl.xml`; the CGL part from open projects that declare it.  
  A program makes a CGL context without a window, draws into a framebuffer object and reads the pixels back  
  (see [DETAILS.md](DETAILS.md#openglframework) and [TESTED.md](TESTED.md)).
- The sanitizer runtimes of compiler-rt build against the full SDK: `asan`, `ubsan`, `lsan`, `tsan`, `rtsan`, `tysan`.

**Tested projects.** Open source projects built with the full Open SDK of macOS 26.5 for x86_64 and arm64 include  
`zlib`, `curl`, `git`, `cmake`, `sqlite`, `bash`, `coreutils`, `fmt`, `redis`, `LLVM/Clang` and `cctools-port`.  
The x86_64 builds ran on macOS 26.0. The full list and what each build needed is in [TESTED.md](TESTED.md).

## What does not work

- **`Foundation`, `AppKit`** and all other frameworks: there is no public source for their headers;  
  `#import <Foundation/Foundation.h>` fails. Objective-C classes are not in the stubs.
- Rust crates that compile C or Objective-C against the headers of these frameworks, and frameworks  
  without a stub (`CoreData`, `GameController`, `IOSurface`, ...).
- `OpenGL.framework`: no GLU (`glu.h`), no extensions except those that Apple's guide for Mac names ([SOURCES.md](SOURCES.md#openglframework)),  
  no renderer IDs except the software renderer, no `NSOpenGL*` (AppKit).
- Swift with `Foundation`, `import Darwin` (no module maps except the one of `CoreFoundation`).
- `libbsm`, the other `IOKit` device families (`storage/ata`, `network`, ...) and the headers of `CoreServices` except File System Events.
- `IOKit/hidsystem/IOHIDEventSystemClient.h` and `IOHIDServiceClient.h`: no open source defines their functions  
  (see [SOURCES.md](SOURCES.md#iokit-device-families)).
- The flags of XPC sessions and listeners, the peer requirements (14.4) and the parts of XPC that have no public value  
  (see [SOURCES.md](SOURCES.md#xpcxpch-and-its-symbols)).

## Known limits

- **Symbols that macOS does not export.** A symbol is in a `.tbd` if a header declares it and  
  the open sources mention it. Some are not defined in the libSystem of every macOS release;  
  a program that uses one links but stops at start with "symbol not found".
- **Versions.** Stubs without a public version source (`sqlite3`, `liblzma`, `Foundation`, `CoreServices`,  
  `CoreGraphics`, `AppKit`, `CoreText`, `CoreVideo`, `QuartzCore`, `Metal`, `CoreAudio`, `AudioToolbox`,  
  `ApplicationServices`, `Carbon`, `OpenGL`, `WebKit`, `UniformTypeIdentifiers`, `OpenDirectory`,  
  `AVFoundation`, `CoreMedia`, `ImageIO`, `Vision`, `MetalKit`)  
  have the lowest compatibility version.
- **`CoreFoundation`** is CF-1153.18 (2018), the last one Apple published, with the newer public declarations  
  that swift-corelibs-foundation has (`CFNotificationCenter`, `CFAttributedString`, ISO 8601 date formatters,  
  newer URL resource keys, ...) and its typed string aliases (`CFLocaleKey`, `CFRunLoopMode`, ...),  
  `CFRunLoopRunResult` and nullability. `CoreFoundation.tbd` also has the symbols of newer APIs that Apple's documentation  
  lists for macOS but no open header declares (`CFStringTokenizer`, `CFURLEnumerator`, `CFFileDescriptor`, `CFFileSecurity`,  
  the typed allocator functions, ...): declare them yourself. The `.tbd` is not the 1153.18 library's; its version stays 1153.18.
- **arm64e and x86_64h.** The stubs give arm64e the symbols of arm64. x86_64h is not listed:  
  the linker uses the x86_64 symbols for it.
