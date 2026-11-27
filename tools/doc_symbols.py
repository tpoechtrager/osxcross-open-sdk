#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""doc_symbols.py [--docs DIR]... [--gnustep-base DIR] [--gnustep-gui DIR] [--headers DIR] [--out DIR] FRAMEWORK...

Writes data/symbols/doc/FRAMEWORK.txt: the C functions and global data of a
framework that the SDK has no headers of, as Apple's documentation lists them for macOS.
The generator makes a link stub (FRAMEWORK.tbd, no headers) of the list.

--docs (one or more) is a directory with JSON pages of
developer.apple.com/documentation, as
https://developer.apple.com/tutorials/data/documentation/<path>.json gives
them, each at DIR/<path>.json; an index.tsv next to DIR (lines: URL, HTTP
status, time UTC) gives the days the pages were fetched.  The list names the
page of every symbol (<path>, below developer.apple.com/documentation/) and no
text of the documentation.

A page is a symbol of the list if its metadata names it as a C function
(externalID c:@F@<name>) or a global variable or constant (c:@<name>, not a
type alias), names macOS as a platform, and one of the modules of FRAMEWORKS
as its module.  A page that names macOS only in the platforms of its
declarations counts too (release "-", or that of the other platforms from 26.0 on).  The tool warns about the pages
that the symbol references of the pages of these frameworks name and that
the directory lacks (neither <page>.json nor <page>.json.404 for a page that
answered 404): fetch them, or the list lacks the symbols of the Objective-C
pages that only they have.  Macros and enumerators are not symbols, and neither are names
with a leading underscore (the pages of Swift initializers name such functions,
e.g. _CTFontCreateWithName for CTFont.init(_:size:)).  The documentation does
not say which symbols exist only on one architecture: every symbol is for
both.

A symbol can have a page in Swift and one in Objective-C (at <framework>/<name>,
e.g. appkit/nsbeep; some symbols have only that one: the pages that the
others refer to, so the pages to read are the Swift pages and the pages
they refer to).  The Swift page lists the members of Swift extensions of
Foundation's types (e.g. NSNotification.Name, NSAttributedString.Key) under
Foundation, also those that other frameworks define; the Objective-C page
names the framework that defines it.  So the module of an Objective-C page
wins.  A symbol under Foundation without such a page: the
headers of GNUstep (gnustep-base for Foundation, gnustep-gui for AppKit,
which follow the split of Apple's frameworks) decide if gnustep-base does not
declare it: one that gnustep-gui declares goes to AppKit; a member of an
extension that neither declares is left out (its framework is not known).
Foundation and AppKit need --gnustep-base and --gnustep-gui.

CoreFoundation has headers (CF and swift-corelibs-foundation) that give most of
its symbols to the .tbd, so its list has only the symbols that no header names:
--headers DIR (the Headers of CoreFoundation.framework of a built SDK) is
needed for it.  A name that a header mentions is left out: either the header
declares it and the generator takes it from there, or it is an inline function
or an enumerator, which the library does not export.

Maintenance tool, not run by the generator; run it again for a newer
documentation (the lists name the days of the pages).
"""
import argparse
import json
import os
import re
import subprocess
import sys

# framework: the modules of the documentation (metadata.modules) whose symbols it exports
FRAMEWORKS = {
    "AppKit": ["AppKit"],
    "ApplicationServices": ["Application Services", "ColorSync"],
    "AudioToolbox": ["Audio Toolbox"],
    "AVFoundation": ["AVFoundation"],
    "CoreAudio": ["Core Audio", "Core Audio Types"],
    "CoreFoundation": ["Core Foundation"],
    "CoreGraphics": ["Core Graphics"],
    "CoreServices": ["Core Services"],
    "CoreMedia": ["Core Media"],
    "CoreText": ["Core Text"],
    "CoreVideo": ["Core Video"],
    "Foundation": ["Foundation"],
    "ImageIO": ["Image I/O"],
    "Metal": ["Metal"],
    "MetalKit": ["MetalKit"],
    "OpenDirectory": ["Open Directory"],
    "QuartzCore": ["Core Animation"],
    "UniformTypeIdentifiers": ["Uniform Type Identifiers"],
    "Vision": ["Vision"],
    "WebKit": ["WebKit"],
}
NS_FRAMEWORKS = ("Foundation", "AppKit")


def gnustep_names(root, sub, macro):
    """the names that the headers of root/Headers/sub declare with macro"""
    names = set()
    d = os.path.join(root, "Headers", sub)
    rx = re.compile(r"\b%s\b([^;{]*)[;{]" % macro)
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".h"):
            continue
        with open(os.path.join(d, fn), errors="replace") as f:
            text = f.read()
        text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
        text = re.sub(r"//[^\n]*", " ", text)
        for m in rx.finditer(text):
            decl = m.group(1)
            if "(" in decl:  # a function: the name before the parameters
                m2 = re.search(r"([A-Za-z_][A-Za-z0-9_]*)\s*\(", decl)
            else:
                m2 = re.search(r"([A-Za-z_][A-Za-z0-9_]*)\s*(\[[^\]]*\]\s*)?$", decl.strip())
            if m2:
                names.add(m2.group(1))
    return names


def header_names(d):
    """the identifiers that the headers of directory d use (comments included)"""
    names = set()
    for fn in sorted(os.listdir(d)):
        if fn.endswith(".h"):
            with open(os.path.join(d, fn), errors="replace") as f:
                names.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", f.read()))
    return names


def git_commit(root):
    try:
        return subprocess.check_output(["git", "-C", root, "rev-parse", "HEAD"], universal_newlines=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def mac_release(m, d):
    """the release of macOS that a page names: the introducedAt of metadata.platforms, or "-" if that
    list names macOS without one.  A page that names macOS only in the platforms of its declarations
    (primaryContentSections of the kind declarations) has "-", or, if metadata.platforms names
    other platforms from 26.0 on, the earliest of their releases: since 2025 all platforms
    have the same release numbers.  None: not for macOS"""
    plats = m.get("platforms")
    if plats:
        mac = [p for p in plats if p.get("name") == "macOS"]
        if mac:
            return mac[0].get("introducedAt", "-")
    for sec in d.get("primaryContentSections") or []:
        if sec.get("kind") == "declarations":
            for decl in sec.get("declarations") or []:
                if "macOS" in (decl.get("platforms") or []):
                    rel = [p["introducedAt"] for p in plats or [] if re.match(r"^(2[6-9]|[3-9][0-9])(\.[0-9]+)*$", p.get("introducedAt", ""))]
                    return min(rel, key=lambda r: [int(x) for x in r.split(".")]) if rel else "-"
    return None


def read_pages(docs, modules):
    """([(name, kind, macOS, page, module, extended, objc)] of every C symbol page for macOS,
    {page: the pages that refer to it} for the symbols that pages name, the first directories of the pages
    whose module is one of modules)"""
    out = []
    refs = {}
    dirs = set()
    for dp, dn, fn in os.walk(docs):
        dn.sort()
        for f in sorted(fn):
            if not f.endswith(".json"):
                continue
            path = os.path.join(dp, f)
            try:
                with open(path) as fh:
                    d = json.load(fh)
                m = d.get("metadata") or {}
            except (OSError, ValueError):
                continue
            page = os.path.relpath(path, docs)[:-len(".json")].replace(os.sep, "/")
            if any(x.get("name") in modules for x in m.get("modules") or []):
                dirs.add(page.split("/")[0])
            for r in (d.get("references") or {}).values():
                url = r.get("url") or "" if isinstance(r, dict) and r.get("kind") == "symbol" else ""
                if url.startswith("/documentation/"):
                    t = url[len("/documentation/"):].split("#")[0].lower()
                    if t.count("/") == 1:
                        refs.setdefault(t, set()).add(page)
            eid = m.get("externalID") or ""
            if eid.startswith("c:@F@") and "@" not in eid[5:]:
                name, kind = eid[5:], "func"
            elif eid.startswith("c:@") and "@" not in eid[3:] and m.get("symbolKind") != "typealias":
                name, kind = eid[3:], "data"
            else:
                continue
            if name.startswith("_"):
                continue
            mac = mac_release(m, d)
            if mac is None:
                continue
            mods = [x.get("name") for x in m.get("modules", [])]
            if len(mods) != 1:
                continue
            objc = (d.get("identifier") or {}).get("interfaceLanguage") == "occ"
            out.append((name, kind, mac, page, mods[0], m.get("extendedModule"), objc))
    return out, refs, dirs


def missing_pages(dirs, refs, frameworks):
    """the pages that symbol references of the pages name in a directory of a framework and that no
    directory of dirs has, neither as a page nor as a .json.404 file (one that answered 404)"""
    return sorted(t for t in refs if t.split("/")[0] in frameworks
                  and not any(os.path.exists(os.path.join(d, t + x)) for d in dirs for x in (".json", ".json.404")))


def fetch_days(dirs, pages):
    """the first and the last day (UTC) on which the pages were fetched, from the index.tsv
    next to each of dirs"""
    want = set(pages)
    days = []
    prefix = "https://developer.apple.com/tutorials/data/documentation/"
    for docs in dirs:
        try:
            with open(os.path.join(os.path.dirname(os.path.abspath(docs)), "index.tsv")) as f:
                for l in f:
                    p = l.rstrip("\n").split("\t")
                    if len(p) == 3 and p[1] == "200" and p[0].startswith(prefix) and p[0].endswith(".json"):
                        if p[0][len(prefix):-len(".json")] in want:
                            days.append(p[2][:10])
        except OSError:
            pass
    return (min(days), max(days)) if days else None


def assign(recs, frameworks, gs):
    """{framework: {name: (kind, macOS, page, note)}}"""
    mod2fw = {}
    for fw, mods in FRAMEWORKS.items():
        for m in mods:
            mod2fw[m] = fw
    by_name = {}
    for r in recs:
        by_name.setdefault(r[0], []).append(r)
    out = {fw: {} for fw in frameworks}
    for name in sorted(by_name):
        rs = sorted(by_name[name], key=lambda r: (not r[6], r[3]))  # Objective-C pages first
        kind, mac, page, mod, ext, objc = rs[0][1:]
        fw = mod2fw.get(mod)
        note = ""
        if fw == "Foundation" and not objc and name not in gs["Foundation"]:
            if name in gs["AppKit"]:
                fw, note = "AppKit", "gnustep-gui"
            elif ext:
                continue
        if fw in out:
            out[fw][name] = (kind, mac, page, note)
    return out


HEADER = """\
# The C functions and global data of {fw} that Apple's documentation lists
# for macOS: the symbols of {fw}.tbd of the full SDK ({what}).
# Made by tools/doc_symbols.py (do not edit) from the pages of
# developer.apple.com/documentation{days}.{gs}
#
# <symbol> <kind> <macOS> <page>{note}
#   kind    func (a function) or data (a variable or constant)
#   macOS   the release that brought it, as the page gives it; - if it gives none
#   page    the page of the symbol, developer.apple.com/documentation/<page>{note_doc}
# The documentation does not say which symbols exist only on one architecture:
# every symbol is for x86_64 and arm64.
"""
WHAT = "a link stub without headers; {fw} has no open source release"
# WebKit and OpenDirectory have one, but their lists, too, are made from the documentation only.
WHAT_OPEN = "a link stub without headers; made from the documentation only, not from the open source release of {fw}"
OPEN_SOURCE = {"WebKit", "OpenDirectory"}
WHAT_CF = "those that no header names; the headers give the rest"
NOTE_DOC = """
#   gnustep-gui  the page lists it under Foundation, the headers of GNUstep
#                place it in AppKit"""


def main(argv):
    ap = argparse.ArgumentParser(prog="doc_symbols.py", description=__doc__.split("\n\n")[1])
    ap.add_argument("--docs", action="append", required=True, metavar="DIR", help="a directory of JSON pages")
    ap.add_argument("frameworks", nargs="+", metavar="FRAMEWORK", help=", ".join(sorted(FRAMEWORKS)))
    ap.add_argument("--headers", metavar="DIR", help="CoreFoundation.framework/Headers of a built SDK (for CoreFoundation)")
    ap.add_argument("--gnustep-base", metavar="DIR", help="a clone of github.com/gnustep/libs-base")
    ap.add_argument("--gnustep-gui", metavar="DIR", help="a clone of github.com/gnustep/libs-gui")
    ap.add_argument("--out", metavar="DIR", help="the output directory (default: data/symbols/doc)")
    a = ap.parse_args(argv[1:])
    for fw in a.frameworks:
        if fw not in FRAMEWORKS:
            ap.error("unknown framework %s" % fw)
    gs = {"Foundation": set(), "AppKit": set()}
    gs_line = ""
    if any(f in NS_FRAMEWORKS for f in a.frameworks):
        if not (a.gnustep_base and a.gnustep_gui):
            ap.error("Foundation and AppKit need --gnustep-base and --gnustep-gui")
        gs["Foundation"] = gnustep_names(a.gnustep_base, "Foundation", "GS_EXPORT")
        gs["AppKit"] = gnustep_names(a.gnustep_gui, "AppKit", "APPKIT_EXPORT")
        gs_line = ("\n# The headers of GNUstep: github.com/gnustep/libs-base %s (Headers/Foundation,\n"
                   "# GS_EXPORT), github.com/gnustep/libs-gui %s (Headers/AppKit, APPKIT_EXPORT)."
                   % (git_commit(a.gnustep_base)[:12], git_commit(a.gnustep_gui)[:12]))
    out_dir = a.out or os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "symbols", "doc")
    modules = set(m for fw in a.frameworks for m in FRAMEWORKS[fw])
    recs = []
    refs = {}
    fw_dirs = set()
    for d in a.docs:
        rs, rf, ds = read_pages(d, modules)
        recs += rs
        for t, p in rf.items():
            refs.setdefault(t, set()).update(p)
        fw_dirs |= ds
    missing = missing_pages(a.docs, refs, fw_dirs)
    if missing:
        print("warning: %d pages that the documentation refers to are not in the cache (fetch them): %s%s"
              % (len(missing), " ".join(missing[:20]), " ..." if len(missing) > 20 else ""), file=sys.stderr)
    lists = assign(recs, a.frameworks, gs)
    if "CoreFoundation" in a.frameworks:
        if not a.headers:
            ap.error("CoreFoundation needs --headers")
        mentioned = header_names(a.headers)
        lists["CoreFoundation"] = {n: v for n, v in lists["CoreFoundation"].items() if n not in mentioned}
    os.makedirs(out_dir, exist_ok=True)
    for fw in a.frameworks:
        syms = lists[fw]
        if not syms:
            print("%s: no symbols" % fw, file=sys.stderr)
            return 1
        days = fetch_days(a.docs, [v[2] for v in syms.values()])
        days_s = ", fetched %s" % days[0] if days and days[0] == days[1] else (
            ", fetched %s to %s" % days if days else "")
        rows = [("_" + n, k, m, p, note) for n, (k, m, p, note) in sorted(syms.items())]
        w = max(len(r[0]) for r in rows)
        with open(os.path.join(out_dir, fw + ".txt"), "w") as f:
            ns = fw in NS_FRAMEWORKS
            f.write(HEADER.format(fw=fw, what=(WHAT_CF if fw == "CoreFoundation" else WHAT_OPEN if fw in OPEN_SOURCE else WHAT).format(fw=fw), days=days_s, gs=gs_line if ns else "",
                                  note=" [gnustep-gui]" if fw == "AppKit" else "",
                                  note_doc=NOTE_DOC if fw == "AppKit" else ""))
            for r in rows:
                f.write(("%-*s %-4s %-5s %s%s" % (w, r[0], r[1], r[2], r[3], " " + r[4] if r[4] else "")).rstrip() + "\n")
        print("%s: %d symbols" % (fw, len(rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
