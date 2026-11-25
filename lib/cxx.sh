#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# libc++ and libc++abi.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# C++: libc++ / libc++abi from the LLVM release that matches the macOS release
# (macOS 14: LLVM 16.0.6, _LIBCPP_VERSION 160006)
# ---------------------------------------------------------------------------

step_cxx() {
  FETCH_QUIET=1 fetch_llvm
  local I=$STAGE/usr/include/c++/v1 L=$STAGE/usr/lib W=$STAGE/work a
  log "CXX"
  echo "libc++ headers"
  rm -rf "$I"; mkdir -p "$I" "$L" "$W"
  copy_tree "$SRC/llvm-project/libcxx/include" "$I"
  rm -f "$I/CMakeLists.txt" "$I/__config_site.in" "$I/libcxx.imp"
  # Upstream LLVM 16 marks <format> as unavailable on Apple platforms (the
  # dylib was not considered ready), which breaks every <chrono> include in
  # C++20 mode: the marking is taken out (the later releases do not have it).
  if [ -f "$I/__availability" ]; then
    perl -0pi -e 's/(#\s+define _LIBCPP_AVAILABILITY_FORMAT)\s*\\\n\s*__attribute__\(\(unavailable\)\)\n#\s+define _LIBCPP_AVAILABILITY_DISABLE_FTM___cpp_lib_format/$1\n\/\/ #   define _LIBCPP_AVAILABILITY_DISABLE_FTM___cpp_lib_format/' "$I/__availability"
    if grep -q '^// #   define _LIBCPP_AVAILABILITY_DISABLE_FTM___cpp_lib_format' "$I/__availability"; then
      add_notice "$I/__availability" "the marking of <format> as unavailable removed"
    fi
  fi
  cp "$SRC"/llvm-project/libcxxabi/include/{cxxabi.h,__cxxabi_config.h} "$I/"
  python3 -I "$HELPERS/cxx_site.py" "$SRC/llvm-project/libcxx/include/__config_site.in" "$I/__config_site"
  # LLVM 17 and later: the header of the assertion handler is made by CMake
  # from the vendor template (a vendor may bring its own)
  local ah=$SRC/llvm-project/libcxx/vendor/llvm/default_assertion_handler.in
  [ -f "$ah" ] && cp "$ah" "$I/__assertion_handler"
  echo "libc++ stub"
  echo "libc++abi stub"
  quiet python3 -I "$HELPERS/cxx_syms.py" "$SRC/llvm-project" "$W"   # (it prints the counts of symbols)
  case $LIBCXX_VERSION in 20.*|21.*|22.*|23.*)
    for a in x86_64 arm64; do
      grep -v '^#' "$DATA/symbols/libcxx-extra.txt" | sed "s/^/$a /" >> "$W/libcxx.syms"
    done;;
  esac
  mk_lib_tbd libc++abi "$L/libc++abi.tbd" "$W/libcxxabi.syms"
  # libc++.1.dylib re-exports libc++abi (libcxx/CMakeLists.txt, LIBCXX_CXX_ABI
  # system-libcxxabi on Apple platforms); the stub lists its symbols so that
  # programs only record libc++.1
  mk_lib_tbd libc++.1 "$L/libc++.1.tbd" "$W/libcxx.syms" --reexport-symbols "$W/libcxxabi.syms"
  ln -sf libc++.1.tbd "$L/libc++.tbd"
}
