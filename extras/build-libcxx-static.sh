#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# build-libcxx-static.sh -- libc++ and libc++abi as static libraries for macOS,
# to go with an open SDK that was made with the same --libcxx version.
#
# A program that links them (-nostdlib++ libc++.a libc++abi.a) does not use
# the libc++.1.dylib of the Mac it runs on.  It can then use every feature of
# the libc++ version, on every macOS version down to the deployment target
# below (the SDK headers need -D_LIBCPP_DISABLE_AVAILABILITY for that, because
# they mark features as "introduced in macOS N" for the system library).
# Not covered: exceptions thrown through the boundary to the system's libc++,
# and types of another libc++ copy in the same process (std::string passed
# to a system dylib that is built against another libc++ ABI state).
#
# usage: build-libcxx-static.sh -s SDK_DIR -v LLVM_VERSION -o OUT_DIR [-d TARGET] [-a "ARCHS"]
#   -s  an open SDK made with --libcxx LLVM_VERSION (extracted, MacOSX*.sdk)
#   -v  LLVM version, e.g. 20.1.8
#   -o  output: OUT_DIR/lib/{libc++.a,libc++abi.a,libc++experimental.a} (universal)
#   -d  deployment target of the libraries (default 11.0)
#   -a  architectures (default "x86_64 arm64")
# Needs git, cmake, ninja and clang (CLANG, default clang) with llvm-ar,
# llvm-ranlib and llvm-lipo next to it; network access for the LLVM sources.
#
set -euo pipefail

CLANG=${CLANG:-clang}
SDK="" VER="" OUT="" DT=11.0 ARCHS="x86_64 arm64"
while getopts s:v:o:d:a: o; do
  case $o in s) SDK=$OPTARG;; v) VER=$OPTARG;; o) OUT=$OPTARG;; d) DT=$OPTARG;; a) ARCHS=$OPTARG;; *) exit 1;; esac
done
[ -d "$SDK/usr/include" ] && [ -n "$VER" ] && [ -n "$OUT" ] || { sed -n '2,28p' "$0"; exit 1; }
BIN=$(dirname "$(command -v "$CLANG")")
SDK=$(cd "$SDK" && pwd)
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)

SRC=$OUT/llvm-project
# (a clone of an earlier version of this script has the mark .oc-tag)
if [ -f "$SRC/.oc-tag" ] && [ ! -e "$SRC/.open-sdk-tag" ]; then mv "$SRC/.oc-tag" "$SRC/.open-sdk-tag"; fi
if [ ! -f "$SRC/.open-sdk-tag" ] || [ "$(cat "$SRC/.open-sdk-tag")" != "llvmorg-$VER" ]; then
  rm -rf "${SRC:?}"
  git -c advice.detachedHead=false clone -q --depth 1 --branch "llvmorg-$VER" --filter=blob:none --sparse \
    https://github.com/llvm/llvm-project "$SRC"
  git --git-dir="$SRC/.git" --work-tree="$SRC" sparse-checkout set runtimes cmake llvm/cmake libcxx libcxxabi libunwind libc third-party
  echo "llvmorg-$VER" > "$SRC/.open-sdk-tag"
fi

for a in $ARCHS; do
  B=$OUT/build-$a
  # The options match the __config_site of the open SDK (write_cxx_config_site.py).
  cmake -S "$SRC/runtimes" -B "$B" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_BUILD_TYPE=Release -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_C_COMPILER="$BIN/clang" -DCMAKE_CXX_COMPILER="$BIN/clang++" \
    -DCMAKE_C_COMPILER_TARGET="$a-apple-macosx$DT" -DCMAKE_CXX_COMPILER_TARGET="$a-apple-macosx$DT" \
    -DCMAKE_AR="$BIN/llvm-ar" -DCMAKE_RANLIB="$BIN/llvm-ranlib" \
    -DCMAKE_OSX_SYSROOT="$SDK" -DCMAKE_OSX_ARCHITECTURES="$a" -DCMAKE_OSX_DEPLOYMENT_TARGET="$DT" \
    -DCMAKE_INSTALL_PREFIX="$B/install" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
    -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXXABI_ENABLE_SHARED=OFF \
    -DLIBCXX_HERMETIC_STATIC_LIBRARY=ON -DLIBCXXABI_HERMETIC_STATIC_LIBRARY=ON \
    -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=ON -DLIBCXXABI_USE_LLVM_UNWINDER=OFF \
    -DLIBCXX_INCLUDE_TESTS=OFF -DLIBCXX_INCLUDE_BENCHMARKS=OFF -DLIBCXXABI_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_TESTS=OFF -DLIBCXX_INSTALL_MODULES=OFF \
    -DLIBCXX_PSTL_BACKEND=libdispatch -DLIBCXX_HARDENING_MODE=none \
    -DLIBCXX_ENABLE_VENDOR_AVAILABILITY_ANNOTATIONS=ON -DLIBCXX_ENABLE_TIME_ZONE_DATABASE=OFF
  ninja -C "$B" install-cxx install-cxxabi
done

mkdir -p "$OUT/lib"
for l in libc++.a libc++abi.a libc++experimental.a; do
  # shellcheck disable=SC2046
  "$BIN/llvm-lipo" -create $(for a in $ARCHS; do echo "$OUT/build-$a/install/lib/$l"; done) -output "$OUT/lib/$l"
done
echo "static libraries: $OUT/lib"
