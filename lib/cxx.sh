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
  local I=$STAGE_INC/c++/v1   # the headers of libc++
  log "CXX"
  echo "libc++ headers"
  rm -rf "$I"; mkdir -p "$I" "$STAGE_LIB" "$STAGE_WORK"
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
  quiet python3 -I "$HELPERS/cxx_syms.py" "$SRC/llvm-project" "$STAGE_WORK"   # (it prints the counts of symbols)
  # (LLVM 20 and later, see the file)
  if [ "${LIBCXX_VERSION%%.*}" -ge 20 ]; then
    syms_for_archs "$DATA/symbols/libcxx-extra.txt" >> "$STAGE_WORK/libcxx.syms"
  fi
  mk_lib_tbd libc++abi "$STAGE_LIB/libc++abi.tbd" "$STAGE_WORK/libcxxabi.syms"
  # libc++.1.dylib re-exports libc++abi (libcxx/CMakeLists.txt, LIBCXX_CXX_ABI
  # system-libcxxabi on Apple platforms); the stub lists its symbols so that
  # programs only record libc++.1
  mk_lib_tbd libc++.1 "$STAGE_LIB/libc++.1.tbd" "$STAGE_WORK/libcxx.syms" --reexport-symbols "$STAGE_WORK/libcxxabi.syms"
  ln -sf libc++.1.tbd "$STAGE_LIB/libc++.tbd"
}
