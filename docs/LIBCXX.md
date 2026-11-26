# libc++

Headers and `libc++.1.tbd` come from one LLVM release (the default of each macOS release is in `data/releases.txt`):  
16.0.6 for macOS 14.3 and older, 19.1.7 for 15.5, 20.1.8 for 26.0, 21.1.8 for 26.5. `--libcxx` takes another one.

At run time the program uses the `libc++.1.dylib` of the Mac. LLVM's headers therefore mark every function  
with the macOS release that first had it, and the compiler rejects a function that is newer than the  
deployment target (OSXCross sets it). LLVM's table (`libcxx/include/__configuration/availability.h`) names  
the macOS release for each LLVM release:

| LLVM | table of LLVM 22.1.8 | table of LLVM 21.1.8 |
|---|---|---|
| 16 | macOS 14.0 | macOS 14.0 |
| 18 | macOS 15.0 | macOS 15.0 |
| 19 | macOS 15.4 | not listed |
| 20 | macOS 26.0 | not listed |
| 21, 22 | not listed | not listed |

"Not listed" means that the table has no macOS release for that LLVM release yet. Everything the release  
added is then marked unavailable on Apple platforms, so newer headers only offer what the Mac's dylib has.

Tested on macOS 26.0 with `-std=c++23 -mmacosx-version-min=26.0` and the default SDK: `std::format`,  
`std::print`, `std::expected`, `std::ranges::to`, `std::mdspan`, `std::jthread`, `<flat_map>`,  
atomic wait and `std::pmr` work. `std::from_chars` for `double` needs LLVM 22 headers (`--libcxx 22.1.8`).  
Time zones of `std::chrono` and `<syncstream>` do not work (experimental in libc++; macOS has no `tzdata.zi`).  
Below macOS 14 `<format>` and `<print>` are rejected.

`extras/build-libcxx-static.sh` builds `libc++.a` and `libc++abi.a` of the same LLVM release: it clones  
the LLVM sources (needs git, cmake and ninja).  
With `-D_LIBCPP_DISABLE_AVAILABILITY -nostdlib++ libc++.a libc++abi.a` a program can use every feature  
down to macOS 11.0.

```sh
CLANG=/path/to/clang extras/build-libcxx-static.sh \
  -s MacOSX26.5.sdk -v 21.1.8 -o libcxx-static
```
