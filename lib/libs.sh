#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# More libraries from public sources (not with --core).
# Sourced by make-open-sdk.sh; not meant to be run on its own.

# ---------------------------------------------------------------------------
# More libraries from public sources (not with --core)
# ---------------------------------------------------------------------------
# ext_tbd NAME CLANGFLAGS EXCLUDE-SYMFILE|- HEADER...  (NAME: a library of data/libraries.txt)
ext_tbd() {
  local name=$1 flags=$2 excl=$3; shift 3
  local W=$STAGE/work L=$STAGE/usr/lib
  python3 -I "$HELPERS/hdr_syms.py" "$STAGE" "$(command -v "$CLANG")" "$W/$name.syms" "$flags" -- "$@"
  if [ "$excl" != "-" ]; then
    # excl lists bare symbols; syms lines are "arch symbol"
    awk 'NR==FNR{e[$1]=1;next} !($2 in e)' "$excl" "$W/$name.syms" > "$W/$name.syms.f"
    mv "$W/$name.syms.f" "$W/$name.syms"
  fi
  mk_lib_tbd "$name" "$L/$name.tbd" "$W/$name.syms"
}

# exp2syms EXPORTS OUT: the symbols of an exports file (one per line, # starts
# a comment line) as "<arch> <symbol>" for both architectures
exp2syms() {
  local a
  for a in x86_64 arm64; do grep -v '^#' "$1" | grep -v '^$' | sed "s/^/$a /"; done > "$2"
}

libs_basic() {
  local I=$STAGE/usr/include L=$STAGE/usr/lib W=$STAGE/work h n s
  mkdir -p "$I" "$L" "$W"
  echo "zlib"
  cp "$SRC/zlib/zlib/zlib.h" "$SRC/zlib/zlib/zconf.h" "$I/"
  sed 's/^/x86_64 /' "$SRC/zlib/libz.exp" > "$W/libz.syms"; sed 's/^/arm64 /' "$SRC/zlib/libz.exp" >> "$W/libz.syms"
  mk_lib_tbd libz.1 "$L/libz.1.tbd" "$W/libz.syms"
  ln -sf libz.1.tbd "$L/libz.tbd"
  echo "bzip2"
  cp "$SRC/bzip2/bzip2/bzlib.h" "$I/"
  ext_tbd libbz2.1.0 "" "$SRC/bzip2/unexports" bzlib.h
  ln -sf libbz2.1.0.tbd "$L/libbz2.tbd"
  echo "expat"
  cp "$SRC/expat/expat/lib/expat.h" "$SRC/expat/expat/lib/expat_external.h" "$I/"
  ext_tbd libexpat.1 "" - expat.h expat_external.h
  ln -sf libexpat.1.tbd "$L/libexpat.tbd"
  echo "libffi"
  # PUBLIC_HEADERS_FOLDER_PATH[sdk=macosx*] = /usr/include/ffi (libffi.xcodeproj)
  mkdir -p "$I/ffi"
  cp "$SRC"/libffi/darwin/include/*.h "$I/ffi/"
  ext_tbd libffi "" - ffi/ffi.h
  echo "libedit"
  # as libedit/xcodescripts/install_misc.sh installs it: histedit.h,
  # editline/readline.h, the links readline/readline.h and readline/history.h
  # to it, and libedit.2.tbd, libedit.3.0.tbd and libreadline.tbd as links to
  # libedit.3.tbd.  The symbols come from both headers (libedit.xcconfig:
  # OTHER_TAPI_FLAGS -extra-public-header readline.h histedit.h).
  cp "$SRC/libedit/src/histedit.h" "$I/"
  mkdir -p "$I/editline" "$I/readline"
  cp "$SRC/libedit/src/editline/readline.h" "$I/editline/"
  for h in readline.h history.h; do ln -sf ../editline/readline.h "$I/readline/$h"; done
  ext_tbd libedit.3 "" "$SRC/libedit/unexports" histedit.h editline/readline.h
  for n in libedit libedit.2 libedit.3.0 libreadline; do ln -sf libedit.3.tbd "$L/$n.tbd"; done
  echo "libxml2"
  # the headers are in /usr/include/libxml (PUBLIC_HEADERS_FOLDER_PATH in
  # Configurations/libxml2.a.xcconfig) and /usr/include/libxml2/libxml is a link
  # to ../libxml (the "Create /usr/include/libxml2/libxml Symlink" phase of libxml2.xcodeproj)
  mkdir -p "$I/libxml" "$I/libxml2"
  cp "$SRC"/libxml2/libxml2/include/libxml/*.h "$I/libxml/"
  cp "$SRC/libxml2/Pregenerated Files/include/libxml/xmlversion.h" "$I/libxml/"
  ln -sf ../libxml "$I/libxml2/libxml"
  local xh; xh=$(cd "$I/libxml" && ls *.h | sed 's#^#libxml/#' | tr '\n' ' ')
  # shellcheck disable=SC2086
  ext_tbd libxml2.2 "" - $xh
  ln -sf libxml2.2.tbd "$L/libxml2.tbd"
  echo "libobjc"
  local oh; oh=$(cd "$I/objc" && ls *.h | sed 's#^#objc/#' | tr '\n' ' ')
  # shellcheck disable=SC2086
  ext_tbd libobjc.A "-x objective-c -fobjc-runtime=macosx" - $oh
  while read -r s; do
    echo "x86_64 $s"; echo "arm64 $s"
  done < <(sed 's/#.*//' "$DATA/symbols/libobjc-extra.txt" | awk 'NF') > "$W/libobjc.extra"
  cat "$W/libobjc.extra" >> "$W/libobjc.A.syms"
  mk_lib_tbd libobjc.A "$L/libobjc.A.tbd" "$W/libobjc.A.syms"
  ln -sf libobjc.A.tbd "$L/libobjc.tbd"
}

# more libraries (second group)
libs_system() {
  local I=$STAGE/usr/include L=$STAGE/usr/lib W=$STAGE/work
  mkdir -p "$I" "$L" "$W"

  echo "libutil"
  exp2syms "$SRC/libutil/libutil.exports" "$W/libutil.syms"
  mk_lib_tbd libutil "$L/libutil.tbd" "$W/libutil.syms"

  echo "libpcap"
  mkdir -p "$I/pcap"
  cp "$SRC/libpcap/libpcap/pcap.h" "$SRC/libpcap/libpcap/pcap-bpf.h" "$SRC/libpcap/libpcap/pcap-namedb.h" "$I/"
  cp "$SRC"/libpcap/libpcap/pcap/*.h "$I/pcap/"; rm -f "$I/pcap/pcap-ng.h"
  ext_tbd libpcap.A "" - pcap.h pcap-namedb.h
  ln -sf libpcap.A.tbd "$L/libpcap.tbd"

  echo "libarchive"
  cp "$SRC/libarchive/libarchive/libarchive/archive.h" "$SRC/libarchive/libarchive/libarchive/archive_entry.h" "$I/"
  ext_tbd libarchive.2 "" "$SRC/libarchive/unexports" archive.h archive_entry.h
  ln -sf libarchive.2.tbd "$L/libarchive.tbd"

  echo "OpenPAM"
  mkdir -p "$I/security"
  cp "$SRC"/OpenPAM/openpam/include/security/*.h "$I/security/"
  ext_tbd libpam.2 "" - security/pam_appl.h security/pam_modules.h security/openpam.h
  ln -sf libpam.2.tbd "$L/libpam.tbd"

  echo "libxslt"
  echo "libexslt"
  mkdir -p "$I/libxslt" "$I/libexslt"
  cp "$SRC"/libxslt/libxslt/libxslt/*.h "$I/libxslt/"
  cp "$SRC"/libxslt/libxslt/libexslt/*.h "$I/libexslt/"
  # The public headers are those with ATTRIBUTES = (Public, ) in libxslt.xcodeproj;
  # these are not (transformInternals.h has no attribute)
  rm -f "$I"/libxslt/{libxslt,triodef,trio,win32config,xsltutilsInternal,xsltwin32config,transformInternals}.h "$I/libexslt/libexslt.h"
  cp "$SRC/libxslt/Pregenerated Files/include/libxslt/xsltconfig.h" "$I/libxslt/" ||
    die "libxslt has no Pregenerated Files/include/libxslt/xsltconfig.h"
  cp "$SRC/libxslt/Pregenerated Files/include/libexslt/exsltconfig.h" "$I/libexslt/" ||
    die "libxslt has no Pregenerated Files/include/libexslt/exsltconfig.h"
  exp2syms "$SRC/libxslt/Pregenerated Files/libxslt.exp" "$W/libxslt.syms"
  mk_lib_tbd libxslt.1 "$L/libxslt.1.tbd" "$W/libxslt.syms"
  ln -sf libxslt.1.tbd "$L/libxslt.tbd"
  exp2syms "$SRC/libxslt/Pregenerated Files/libexslt.exp" "$W/libexslt.syms"
  mk_lib_tbd libexslt.0 "$L/libexslt.0.tbd" "$W/libexslt.syms"
  ln -sf libexslt.0.tbd "$L/libexslt.tbd"

  echo "libcurl"
  mkdir -p "$I/curl"
  (cd "$SRC/curl/curl/include/curl" && cp *.h "$I/curl/"); rm -f "$I/curl/stdcheaders.h"
  ext_tbd libcurl.4 "" - curl/curl.h curl/easy.h curl/multi.h curl/urlapi.h curl/options.h curl/header.h curl/websockets.h curl/mprintf.h
  ln -sf libcurl.4.tbd "$L/libcurl.tbd"
}

libs_curses_sqlite() {
  local I=$STAGE/usr/include L=$STAGE/usr/lib W=$STAGE/work n
  mkdir -p "$I" "$L" "$W"

  echo "ncurses"
  echo "panel"
  echo "form"
  echo "menu"
  local N=$SRC/ncurses B=$W/ncurses
  rm -rf "$B"; mkdir -p "$B"
  # Apple's own bootstrap script generates curses.h and term.h with awk and sh
  (cd "$N" && run_logged "$B.log" env -i PATH="/usr/bin:/bin:/usr/sbin$AENV_PATH" PROJECT_DIR="$N" BUILT_PRODUCTS_DIR="$B" \
     bash -e xcodescripts/bootstrap_headers.sh)
  cp "$N"/ncurses/include/tic.h "$N"/ncurses/menu/eti.h "$N"/ncurses/panel/panel.h \
     "$N"/ncurses/include/ncurses_dll.h "$N"/ncurses/include/unctrl.h "$N"/ncurses/include/nc_tparm.h \
     "$N"/ncurses/form/form.h "$N"/ncurses/include/termcap.h "$N"/ncurses/menu/menu.h \
     "$N"/ncurses/include/term_entry.h "$B/term.h" "$B/curses.h" "$I/"
  cp "$B/curses.h" "$I/ncurses.h"
  local cf="-D_XOPEN_SOURCE_EXTENDED=1"
  ext_tbd libncurses.5.4 "$cf" - curses.h term.h termcap.h unctrl.h tic.h term_entry.h nc_tparm.h
  ext_tbd libpanel.5.4 "$cf" - panel.h
  ext_tbd libform.5.4 "$cf" - form.h
  ext_tbd libmenu.5.4 "$cf" - menu.h eti.h
  for n in ncurses curses termcap; do ln -sf libncurses.5.4.tbd "$L/lib$n.tbd"; done
  for n in panel form menu; do ln -sf lib$n.5.4.tbd "$L/lib$n.tbd"; done

  echo "sqlite3"
  FETCH_QUIET=1 fetch_sqlite
  local SQ
  SQ=$SRC/$(basename "$SQLITE_URL" .zip)
  cp "$SQ/sqlite3.h" "$SQ/sqlite3ext.h" "$I/"
  ext_tbd libsqlite3 "" - sqlite3.h
}

step_libs() {
  log "Libs"
  libs_basic
  libs_system
  libs_curses_sqlite
}
