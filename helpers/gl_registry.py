# SPDX-License-Identifier: GPL-2.0-only
"""The OpenGL API Registry (Khronos, gl.xml) and the data files of data/opengl/.

gl.xml is read with the standard library: its types, enums (tokens), commands,
the "feature" elements (the versions of OpenGL) and the "extension" elements.
Used by write_opengl_headers.py (the headers of OpenGL.framework) and
opengl_syms.py (the exports of OpenGL.tbd).
"""
import re
import xml.etree.ElementTree as ET

# The last version of OpenGL that the framework implements: OpenGL.framework of macOS
# supports contexts of 2.1 (legacy) and of 3.2 and 4.1 (core profile) and no later
# version (docs/SOURCES.md, "OpenGL.framework").
LEGACY_MAX = (2, 1)
CORE_MIN = (3, 2)
CORE_MAX = (4, 1)


def flatten(e, name_text=None):
    """The C text of a proto or param element; the text of <name> is NAME_TEXT, or
    left out if NAME_TEXT is ''."""
    out = [e.text or ""]
    for c in e:
        if c.tag == "name":
            if name_text is None:
                out.append(c.text or "")
            else:
                out.append(name_text)
        else:
            out.append(flatten(c, name_text))
        out.append(c.tail or "")
    return "".join(out)


def _norm(s):
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"\s*\*\s*", " *", s)   # "const GLubyte *", "GLenum *name"
    return s.strip()


class Command(object):
    def __init__(self, e):
        proto = e.find("proto")
        self.name = proto.find("name").text
        self.ret = _norm(flatten(proto, ""))
        self.params = [_norm(flatten(p)) for p in e.findall("param")]

    def declaration(self):
        ret = self.ret
        sep = "" if ret.endswith("*") else " "
        return "extern %s%s%s(%s);" % (ret, sep, self.name, ", ".join(self.params) or "void")


class Block(object):
    """One <feature> or <extension>: its requires and removes, in order."""
    def __init__(self, e):
        self.name = e.get("name")
        self.number = tuple(int(x) for x in e.get("number", "0.0").split("."))
        self.requires = []   # (profile, [("enum"|"command"|"type", name)])
        self.removes = []
        for r in e:
            if r.tag not in ("require", "remove"):
                continue
            items = [(c.tag, c.get("name")) for c in r if c.tag in ("enum", "command", "type")]
            (self.requires if r.tag == "require" else self.removes).append((r.get("profile"), items))


class Registry(object):
    def __init__(self, path):
        root = ET.parse(path).getroot()
        self.comment = (root.findtext("comment") or "").strip()
        self.enums = {}      # name -> (value text, type suffix)
        for g in root.findall("enums"):
            for e in g.findall("enum"):
                if e.get("api") not in (None, "gl"):
                    continue
                self.enums.setdefault(e.get("name"), (e.get("value"), e.get("type", "")))
        self.commands = {}
        for e in root.find("commands").findall("command"):
            c = Command(e)
            self.commands.setdefault(c.name, c)
        self.features = [Block(f) for f in root.findall("feature") if f.get("api") == "gl"]
        self.extensions = {}
        for x in root.find("extensions").findall("extension"):
            if "gl" in (x.get("supported") or "").split("|"):
                self.extensions[x.get("name")] = Block(x)
        self.types = {}
        for t in root.find("types").findall("type"):
            n = t.findtext("name") or t.get("name")
            if n:
                self.types.setdefault(n, flatten(t).strip())

    def copyright_lines(self):
        """The license notice at the top of gl.xml (its <comment>), the first lines up to the blank line"""
        out = []
        for l in self.comment.splitlines():
            if not l.strip():
                break
            out.append(l.strip())
        return out

    def select(self, lo, hi, profile):
        """The features of OpenGL LO..HI (version tuples) for PROFILE (compatibility or core):
        [(feature name, [enum names], [command names])], in the order of the registry; what a
        core profile removes is not in the result."""
        owner = {}   # (kind, name) -> index of the feature
        order = []
        feats = [f for f in self.features if lo <= f.number <= hi]
        for i, f in enumerate(feats):
            for prof, items in f.requires:
                if prof not in (None, profile):
                    continue
                for it in items:
                    if it[0] != "type" and it not in owner:
                        owner[it] = i
                        order.append(it)
            if profile == "core":
                for prof, items in f.removes:
                    if prof not in (None, "core"):
                        continue
                    for it in items:
                        if it in owner:
                            del owner[it]
        res = []
        for i, f in enumerate(feats):
            enums = [n for k, n in order if k == "enum" and owner.get((k, n)) == i]
            cmds = [n for k, n in order if k == "command" and owner.get((k, n)) == i]
            res.append((f.name, enums, cmds))
        return res

    def all_commands(self, hi):
        """Every command of the versions 1.0..HI that any profile has (the exports)"""
        names = []
        seen = set()
        for f in self.features:
            if f.number > hi:
                continue
            for _prof, items in f.requires:
                for k, n in items:
                    if k == "command" and n not in seen:
                        seen.add(n)
                        names.append(n)
        return names


def read_pipe_file(path):
    """The rows of a file of "|"-separated fields (data/opengl/cgl-functions.txt, extensions.txt)"""
    rows = []
    with open(path) as f:
        for line in f:
            line = line.split("#", 1)[0].rstrip("\n")
            if line.strip():
                rows.append([x.strip() for x in line.split("|")])
    return rows


def read_cgl_enums(path):
    """data/opengl/cgl-enums.txt: [(group, name, value text)]"""
    rows = []
    with open(path) as f:
        for line in f:
            w = line.split("#", 1)[0].split()
            if w:
                rows.append((w[0], w[1], w[2]))
    return rows
