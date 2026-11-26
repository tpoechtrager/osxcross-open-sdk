#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# More libraries from public sources (not with --core).
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# More libraries from public sources (not with --core): one function per
# library, which installs its headers and writes its .tbd.
# ---------------------------------------------------------------------------
step_libs() {
  log "Libs"
  mkdir -p "$STAGE_INC" "$STAGE_LIB" "$STAGE_WORK"
  libs_zlib
  libs_bzip2
  libs_expat
  libs_libffi
  libs_libedit
  libs_libxml2
  libs_libobjc
  libs_libutil
  libs_libpcap
  libs_libarchive
  libs_openpam
  libs_libxslt
  libs_libcurl
  libs_ncurses
  libs_sqlite
}

# ext_tbd NAME CLANGFLAGS EXCLUDE-SYMFILE|- HEADER...  (NAME: a library of data/libraries.txt)
ext_tbd() {
  local name=$1 flags=$2 excl=$3; shift 3
  header_syms "$STAGE_WORK/$name.syms" "$flags" "$@"
  if [ "$excl" != "-" ]; then
    # excl lists bare symbols; syms lines are "arch symbol"
    awk 'NR==FNR{e[$1]=1;next} !($2 in e)' "$excl" "$STAGE_WORK/$name.syms" > "$STAGE_WORK/$name.syms.f"
    mv "$STAGE_WORK/$name.syms.f" "$STAGE_WORK/$name.syms"
  fi
  mk_lib_tbd "$name" "$STAGE_LIB/$name.tbd" "$STAGE_WORK/$name.syms"
}

libs_zlib() {
  echo "zlib"
  cp "$SRC/zlib/zlib/zlib.h" "$SRC/zlib/zlib/zconf.h" "$STAGE_INC/"
  syms_for_archs "$SRC/zlib/libz.exp" > "$STAGE_WORK/libz.syms"
  mk_lib_tbd libz.1 "$STAGE_LIB/libz.1.tbd" "$STAGE_WORK/libz.syms"
  ln -sf libz.1.tbd "$STAGE_LIB/libz.tbd"
}

libs_bzip2() {
  echo "bzip2"
  cp "$SRC/bzip2/bzip2/bzlib.h" "$STAGE_INC/"
  ext_tbd libbz2.1.0 "" "$SRC/bzip2/unexports" bzlib.h
  ln -sf libbz2.1.0.tbd "$STAGE_LIB/libbz2.tbd"
}

libs_expat() {
  echo "expat"
  cp "$SRC/expat/expat/lib/expat.h" "$SRC/expat/expat/lib/expat_external.h" "$STAGE_INC/"
  ext_tbd libexpat.1 "" - expat.h expat_external.h
  ln -sf libexpat.1.tbd "$STAGE_LIB/libexpat.tbd"
}

libs_libffi() {
  echo "libffi"
  # PUBLIC_HEADERS_FOLDER_PATH[sdk=macosx*] = /usr/include/ffi (libffi.xcodeproj)
  mkdir -p "$STAGE_INC/ffi"
  cp "$SRC"/libffi/darwin/include/*.h "$STAGE_INC/ffi/"
  ext_tbd libffi "" - ffi/ffi.h
}

# as libedit/xcodescripts/install_misc.sh installs it: histedit.h,
# editline/readline.h, the links readline/readline.h and readline/history.h
# to it, and libedit.2.tbd, libedit.3.0.tbd and libreadline.tbd as links to
# libedit.3.tbd.  The symbols come from both headers (libedit.xcconfig:
# OTHER_TAPI_FLAGS -extra-public-header readline.h histedit.h).
libs_libedit() {
  local h n
  echo "libedit"
  cp "$SRC/libedit/src/histedit.h" "$STAGE_INC/"
  mkdir -p "$STAGE_INC/editline" "$STAGE_INC/readline"
  cp "$SRC/libedit/src/editline/readline.h" "$STAGE_INC/editline/"
  for h in readline.h history.h; do ln -sf ../editline/readline.h "$STAGE_INC/readline/$h"; done
  ext_tbd libedit.3 "" "$SRC/libedit/unexports" histedit.h editline/readline.h
  for n in libedit libedit.2 libedit.3.0 libreadline; do ln -sf libedit.3.tbd "$STAGE_LIB/$n.tbd"; done
}

# the headers are in /usr/include/libxml (PUBLIC_HEADERS_FOLDER_PATH in
# Configurations/libxml2.a.xcconfig) and /usr/include/libxml2/libxml is a link
# to ../libxml (the "Create /usr/include/libxml2/libxml Symlink" phase of libxml2.xcodeproj)
libs_libxml2() {
  local xh
  echo "libxml2"
  mkdir -p "$STAGE_INC/libxml" "$STAGE_INC/libxml2"
  cp "$SRC"/libxml2/libxml2/include/libxml/*.h "$STAGE_INC/libxml/"
  cp "$SRC/libxml2/Pregenerated Files/include/libxml/xmlversion.h" "$STAGE_INC/libxml/"
  ln -sf ../libxml "$STAGE_INC/libxml2/libxml"
  xh=$(cd "$STAGE_INC/libxml" && ls *.h | sed 's#^#libxml/#' | tr '\n' ' ')
  # shellcheck disable=SC2086
  ext_tbd libxml2.2 "" - $xh
  ln -sf libxml2.2.tbd "$STAGE_LIB/libxml2.tbd"
}

# libobjc: the headers come from the step headers; the symbols of the headers
# and those of data/symbols/libobjc-extra.txt
libs_libobjc() {
  local oh
  echo "libobjc"
  oh=$(cd "$STAGE_INC/objc" && ls *.h | sed 's#^#objc/#' | tr '\n' ' ')
  # shellcheck disable=SC2086
  ext_tbd libobjc.A "-x objective-c -fobjc-runtime=macosx" - $oh
  syms_for_archs "$DATA/symbols/libobjc-extra.txt" >> "$STAGE_WORK/libobjc.A.syms"
  mk_lib_tbd libobjc.A "$STAGE_LIB/libobjc.A.tbd" "$STAGE_WORK/libobjc.A.syms"
  ln -sf libobjc.A.tbd "$STAGE_LIB/libobjc.tbd"
}

libs_libutil() {
  echo "libutil"
  syms_for_archs "$SRC/libutil/libutil.exports" > "$STAGE_WORK/libutil.syms"
  mk_lib_tbd libutil "$STAGE_LIB/libutil.tbd" "$STAGE_WORK/libutil.syms"
}

libs_libpcap() {
  echo "libpcap"
  mkdir -p "$STAGE_INC/pcap"
  cp "$SRC/libpcap/libpcap/pcap.h" "$SRC/libpcap/libpcap/pcap-bpf.h" "$SRC/libpcap/libpcap/pcap-namedb.h" "$STAGE_INC/"
  cp "$SRC"/libpcap/libpcap/pcap/*.h "$STAGE_INC/pcap/"; rm -f "$STAGE_INC/pcap/pcap-ng.h"
  ext_tbd libpcap.A "" - pcap.h pcap-namedb.h
  ln -sf libpcap.A.tbd "$STAGE_LIB/libpcap.tbd"
}

libs_libarchive() {
  echo "libarchive"
  cp "$SRC/libarchive/libarchive/libarchive/archive.h" "$SRC/libarchive/libarchive/libarchive/archive_entry.h" "$STAGE_INC/"
  ext_tbd libarchive.2 "" "$SRC/libarchive/unexports" archive.h archive_entry.h
  ln -sf libarchive.2.tbd "$STAGE_LIB/libarchive.tbd"
}

libs_openpam() {
  echo "OpenPAM"
  mkdir -p "$STAGE_INC/security"
  cp "$SRC"/OpenPAM/openpam/include/security/*.h "$STAGE_INC/security/"
  ext_tbd libpam.2 "" - security/pam_appl.h security/pam_modules.h security/openpam.h
  ln -sf libpam.2.tbd "$STAGE_LIB/libpam.tbd"
}

# libxslt and libexslt (one project)
libs_libxslt() {
  echo "libxslt"
  echo "libexslt"
  mkdir -p "$STAGE_INC/libxslt" "$STAGE_INC/libexslt"
  cp "$SRC"/libxslt/libxslt/libxslt/*.h "$STAGE_INC/libxslt/"
  cp "$SRC"/libxslt/libxslt/libexslt/*.h "$STAGE_INC/libexslt/"
  # The public headers are those with ATTRIBUTES = (Public, ) in libxslt.xcodeproj;
  # these are not (transformInternals.h has no attribute)
  rm -f "$STAGE_INC"/libxslt/{libxslt,triodef,trio,win32config,xsltutilsInternal,xsltwin32config,transformInternals}.h \
    "$STAGE_INC/libexslt/libexslt.h"
  cp "$SRC/libxslt/Pregenerated Files/include/libxslt/xsltconfig.h" "$STAGE_INC/libxslt/" ||
    die "libxslt has no Pregenerated Files/include/libxslt/xsltconfig.h"
  cp "$SRC/libxslt/Pregenerated Files/include/libexslt/exsltconfig.h" "$STAGE_INC/libexslt/" ||
    die "libxslt has no Pregenerated Files/include/libexslt/exsltconfig.h"
  syms_for_archs "$SRC/libxslt/Pregenerated Files/libxslt.exp" > "$STAGE_WORK/libxslt.syms"
  mk_lib_tbd libxslt.1 "$STAGE_LIB/libxslt.1.tbd" "$STAGE_WORK/libxslt.syms"
  ln -sf libxslt.1.tbd "$STAGE_LIB/libxslt.tbd"
  syms_for_archs "$SRC/libxslt/Pregenerated Files/libexslt.exp" > "$STAGE_WORK/libexslt.syms"
  mk_lib_tbd libexslt.0 "$STAGE_LIB/libexslt.0.tbd" "$STAGE_WORK/libexslt.syms"
  ln -sf libexslt.0.tbd "$STAGE_LIB/libexslt.tbd"
}

libs_libcurl() {
  echo "libcurl"
  mkdir -p "$STAGE_INC/curl"
  (cd "$SRC/curl/curl/include/curl" && cp *.h "$STAGE_INC/curl/"); rm -f "$STAGE_INC/curl/stdcheaders.h"
  ext_tbd libcurl.4 "" - curl/curl.h curl/easy.h curl/multi.h curl/urlapi.h curl/options.h curl/header.h \
    curl/websockets.h curl/mprintf.h
  ln -sf libcurl.4.tbd "$STAGE_LIB/libcurl.tbd"
}

# ncurses with panel, form and menu (one project)
libs_ncurses() {
  local N=$SRC/ncurses B=$STAGE_WORK/ncurses n
  echo "ncurses"
  echo "panel"
  echo "form"
  echo "menu"
  rm -rf "$B"; mkdir -p "$B"
  # Apple's own bootstrap script generates curses.h and term.h with awk and sh
  (cd "$N" && run_logged "$B.log" plain_env PROJECT_DIR="$N" BUILT_PRODUCTS_DIR="$B" \
     bash -e xcodescripts/bootstrap_headers.sh)
  cp "$N"/ncurses/include/tic.h "$N"/ncurses/menu/eti.h "$N"/ncurses/panel/panel.h \
     "$N"/ncurses/include/ncurses_dll.h "$N"/ncurses/include/unctrl.h "$N"/ncurses/include/nc_tparm.h \
     "$N"/ncurses/form/form.h "$N"/ncurses/include/termcap.h "$N"/ncurses/menu/menu.h \
     "$N"/ncurses/include/term_entry.h "$B/term.h" "$B/curses.h" "$STAGE_INC/"
  cp "$B/curses.h" "$STAGE_INC/ncurses.h"
  local cf="-D_XOPEN_SOURCE_EXTENDED=1"
  ext_tbd libncurses.5.4 "$cf" - curses.h term.h termcap.h unctrl.h tic.h term_entry.h nc_tparm.h
  ext_tbd libpanel.5.4 "$cf" - panel.h
  ext_tbd libform.5.4 "$cf" - form.h
  ext_tbd libmenu.5.4 "$cf" - menu.h eti.h
  for n in ncurses curses termcap; do ln -sf libncurses.5.4.tbd "$STAGE_LIB/lib$n.tbd"; done
  for n in panel form menu; do ln -sf lib$n.5.4.tbd "$STAGE_LIB/lib$n.tbd"; done
}

libs_sqlite() {
  local sq
  echo "sqlite3"
  FETCH_QUIET=1 fetch_sqlite
  sq=$(sqlite_dir)
  cp "$sq/sqlite3.h" "$sq/sqlite3ext.h" "$STAGE_INC/"
  ext_tbd libsqlite3 "" - sqlite3.h
}
