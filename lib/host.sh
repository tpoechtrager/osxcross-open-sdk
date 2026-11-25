#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Host tools and shims for the Apple build scripts.
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# Host tools
# ---------------------------------------------------------------------------
# host_line TOOL STATE: one line of the step host.
host_line() { printf '%-22s %s\n' "$1" "$2"; }

step_host() {
  log "Host tools"
  # The tools depend on the sources of three projects: build them again when
  # --macos changes the tags (a work directory can serve several releases).
  local p stamp=
  for p in bootstrap_cmds developer_cmds xnu; do
    [ -f "$SRC/$p/.oc-tag" ] || die "no sources of $p in $SRC (step fetch)"
    stamp="$stamp $p $(cat "$SRC/$p/.oc-tag")"
  done
  # (|| true: there is no stamp before the first build)
  if [ "$(cat "$HOST/.stamp" 2>/dev/null || true)" != "$stamp" ]; then
    rm -rf "${HOST:?}"
  fi
  mkdir -p "$HOST/bin" "$HOST/inc/sys" "$HOST/inc2" "$HOST/migshim"
  # unifdef (developer_cmds), BSD licensed
  if [ ! -x "$HOST/bin/unifdef" ]; then
    host_line unifdef building
    cp "$SRC/developer_cmds/unifdef/tree.h" "$HOST/inc/sys/tree.h"
    "$CLANG" -O1 -w -D__unused='__attribute__((unused))' -D__uintptr_t=uintptr_t \
      -include stdint.h -I"$HOST/inc" -o "$HOST/bin/unifdef" \
      "$SRC/developer_cmds/unifdef/unifdef.c"
  else
    host_line unifdef present
  fi
  # decomment (xnu/SETUP)
  if [ ! -x "$HOST/bin/decomment" ]; then
    host_line decomment building
    printf '#include <stdlib.h>\n#include <string.h>\n#include <unistd.h>\n' > "$HOST/inc2/libc.h"
    "$CLANG" -O1 -w -I"$HOST/inc2" -o "$HOST/bin/decomment" "$SRC/xnu/SETUP/decomment/decomment.c"
  else
    host_line decomment present
  fi
  # migcom (bootstrap_cmds).  Needs a handful of Mach types; give it tiny
  # shim headers instead of the full xnu headers.
  if [ ! -x "$HOST/bin/migcom" ]; then
    host_line migcom building
    local b=$WORK/build/migcom
    # yacc and flex can exist and still fail (see find_yacc)
    [ -n "${YACC:-}" ] || find_yacc || die "no working yacc (install bison or set OPEN_SDK_YACC)"
    rm -rf "$b"; mkdir -p "$b"
    printf '%%%%\n. ;\n' > "$b/t.l"
    (cd "$b" && flex t.l) >/dev/null 2>&1 || die "flex does not work"
    rm -rf "$b"; mkdir -p "$b"
    cp "$SRC"/bootstrap_cmds/migcom.tproj/* "$b/"
    make_mig_shim
    # The shim headers replace Mach headers that a Linux host lacks.  On BSD and
    # macOS they would hide the host's own sys/_types.h and machine/types.h,
    # so they come last there.
    local shim_inc=(-I "$HOST/migshim")
    [ "$(uname -s)" = Linux ] || shim_inc=(-idirafter "$HOST/migshim")
    (cd "$b" && "$YACC" $YACC_FLAGS -d -o parser.c parser.y && cp parser.h y.tab.h && flex -o lexxer.c lexxer.l &&
      "$CLANG" -w -O1 -std=gnu99 -D_GNU_SOURCE -DMIG_VERSION='"bootstrap_cmds"' \
        -D__unused='__attribute__((unused))' -include sys/types.h -include stdlib.h \
        -include string.h -include unistd.h -include "$HOST/migshim/oc_shim.h" -I. "${shim_inc[@]}" -o "$HOST/bin/migcom" \
        error.c global.c header.c lexxer.c mig.c parser.c routine.c server.c statement.c \
        string.c type.c user.c utils.c)
  else
    host_line migcom present
  fi
  cp "$SRC/bootstrap_cmds/migcom.tproj/mig.sh" "$HOST/bin/mig"
  # (#!/bin/bash: the BSDs have bash in /usr/local/bin)
  sed_inplace "$HOST/bin/mig" '1s|^#!.*|#!/usr/bin/env bash|; s#^arch=`/usr/bin/arch`#arch=x86_64#; s#/usr/bin/mktemp#mktemp#'
  make_shims
  echo "$stamp" > "$HOST/.stamp"
}

make_mig_shim() {
  local X=$SRC/xnu/osfmk/mach S=$HOST/migshim
  mkdir -p "$S/machine" "$S/mach/machine" "$S/sys/_types" "$S/libkern"
  cp "$X"/{message,port,vm_types,boolean,kern_return,std_types,ndr,error}.h "$S/mach/"
  echo '#include <limits.h>' > "$S/machine/limits.h"
  printf '#include <stdint.h>\ntypedef uint64_t user_addr_t;typedef uint64_t user_size_t;typedef int64_t user_ssize_t;typedef uint64_t user_long_t;\n' > "$S/machine/types.h"
  cat > "$S/mach/machine/vm_types.h" <<'EOF'
#include <stdint.h>
typedef uintptr_t vm_offset_t; typedef uintptr_t vm_size_t;
typedef uint64_t mach_vm_address_t; typedef uint64_t mach_vm_offset_t; typedef uint64_t mach_vm_size_t;
typedef uint64_t vm_map_offset_t; typedef uint64_t vm_map_address_t; typedef uint64_t vm_map_size_t;
typedef uint64_t vm32_offset_t; typedef uint32_t natural_t; typedef int integer_t;
typedef uintptr_t mach_port_context_t;
EOF
  printf 'typedef int kern_return_t;\n#define KERN_SUCCESS 0\n#define KERN_NO_ACCESS 8\n' > "$S/mach/machine/kern_return.h"
  echo 'typedef unsigned int boolean_t;' > "$S/mach/machine/boolean.h"
  # newer xnu (macOS 26) declares options with __options_decl from sys/cdefs.h
  cat > "$S/oc_shim.h" <<'EOF2'
#ifndef OC_SHIM_H
#define OC_SHIM_H
#include <stdint.h>
#define __options_decl(_name, _type, ...) typedef _type _name; enum __VA_ARGS__
#define __enum_decl(_name, _type, ...) typedef _type _name; enum __VA_ARGS__
#endif
EOF2
  touch "$S/sys/appleapiopts.h" "$S/TargetConditionals.h" "$S/libkern/OSByteOrder.h"
  cat > "$S/Availability.h" <<'EOF'
#include <stdint.h>
#define __API_AVAILABLE(...)
#define __API_UNAVAILABLE(...)
#define __API_DEPRECATED(...)
#define __WATCHOS_PROHIBITED
#define __TVOS_PROHIBITED
#define __enum_decl(name, type, ...) typedef type name; enum __VA_ARGS__
#define __options_decl(name, type, ...) typedef type name; enum __VA_ARGS__
#define __kernel_ptr_semantics
#define __kernel_data_semantics
#define __sized_by(x)
#define __counted_by(x)
#define __unsafe_indexable
#define __single
#define __indexable
#define __bidi_indexable
EOF
  printf '#define __ptrauth(...)\n#define __ptrauth_objc_isa_pointer\n#define __ptrauth_restricted_intptr(...)\n' > "$S/ptrauth.h"
  echo '#include <stdint.h>' > "$S/sys/_types.h"
  echo 'typedef unsigned int mach_port_t;' > "$S/sys/_types/_mach_port_t.h"
  echo '#include <stdint.h>' > "$S/sys/_types/_uuid_t.h"
}

make_shims() {
  local b=$HOST/bin
  # `ed - FILE < strip-header.ed` as used by Libc/xcodescripts/headers.sh
  cat > "$b/ed" <<'EOF'
#!/bin/sh
sed '/^\/\/Begin-Libc$/,/^\/\/End-Libc$/d' "$2" > "$2.oc-ed.$$" && cat "$2.oc-ed.$$" > "$2"
rm -f "$2.oc-ed.$$"
EOF
  # xcrun -find TOOL for Apple build scripts
  cat > "$b/xcrun" <<'EOF'
#!/bin/sh
tool=
while [ $# -gt 0 ]; do case "$1" in -find) tool=$2; shift 2;; -sdk|--sdk) shift 2;; *) shift;; esac; done
d=$(dirname "$0")
case "$tool" in
  mig) echo "$d/mig";; cc|clang) echo "$d/mig-cc";; unifdef) echo "$d/unifdef";;
  *) command -v "$tool" || exit 1;;
esac
EOF
  # the C preprocessor behind mig.sh: translate -arch into -target
  cat > "$b/mig-cc" <<'EOF'
#!/bin/sh
args=""
while [ $# -gt 0 ]; do
  case "$1" in
    -arch) case "$2" in
             i386) args="$args -target i386-apple-macosx10.13";;
             x86_64*) args="$args -target x86_64-apple-macosx10.13";;
             *) args="$args -target arm64-apple-macosx11.0";; esac; shift 2;;
    -isysroot) shift 2;;
    *) args="$args $1"; shift;;
  esac
done
exec ${CLANG:-clang} $args
EOF
  chmod +x "$b/ed" "$b/xcrun" "$b/mig-cc" "$b/mig"
}
