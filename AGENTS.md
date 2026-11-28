# AGENTS.md

Guidance for AI agents working on osxcross-open-sdk. Read this before
changing scripts, data or writing commits.

## What this is

`make-open-sdk.sh` builds a macOS SDK tarball (`MacOSX<version>-open-sdk-<hash>.tar.xz`,
`MacOSX<version>-open-core-sdk-<hash>.tar.xz` with `--core`) from open source only:
Apple's open source releases (github.com/apple-oss-distributions), LLVM's
libc++ and a few upstream projects. See `README.md`.

## The rule that matters most

**Nothing in this repository or in a generated SDK may come from an SDK
made by Apple or from a binary of Apple's.** Every header, symbol, install
name, version, list and table must be derivable from a public open source
project, a standard, or public documentation, and its source is named
(in a comment next to it, in `data/`, and in `docs/SOURCES.md`).
Reading public documentation is fine; copying code or header text from
Apple's SDKs is not. Real SDKs or a real macOS may be used to test a result
(works / does not work) and to find a bug, but no name, value or list read
from them goes into the repository, and no value is found by trying on a
real macOS. If there is no public source for a value, choose the
conservative value and say so in `docs/SOURCES.md`.

Not a source, because it is made from Apple's SDKs or binaries (the license of the project does not change that):
- The `objc2-*` crates and other generated bindings (`bindgen`-made `*-sys` crates, `carbon-bindgen`, `global-hotkey`,
  `super_native_extensions`): objc2's `LICENSE.md` says "These crates are derived from Apple SDKs shipped with Xcode".
- Darling: its framework stubs come from its stub generator, which runs on macOS and reads Apple's frameworks
  (darling-docs, "Generating stubs").
- nixpkgs' Apple SDK packages: `pkgs/os-specific/darwin/apple-sdk/default.nix` downloads Apple's `DevSDK_OSX1012.pkg`
  from swcdn.apple.com and copies its headers; lists such as `impure_deps.nix` are generated on a Mac.
- Header dumps (`class-dump`), ipsw diffs and symbol lists read from Apple's binaries: they copy Apple's
  declarations as a whole. Single paths and names that a public project shows from its own build (an install
  name in `otool -L` output, a dyld message, a crash report) are facts and allowed as a source.
- A project that only includes Apple's headers, such as Godot, OBS Studio or SDL with `<Carbon/Carbon.h>`
  (it shows that a name is used, not its declaration).

A source is what Apple itself published as open source, and what a project declares itself. WebKit is Apple's own
open source project (BSD-2-Clause) and always allowed as a source, its `spi/` headers included, without asking: that
Apple took the names from its own SDK does not matter, because Apple published them under a free license. From it we
take facts (names, values, signatures), no text.

Other sources that Apple made from its own SDK and published under BSD or a similar license are allowed in principle,
but an agent must ask the user before it uses one.

A source counts only for what the file at the named commit says itself; read it before naming it.

Pages of Apple's online documentation that were read for this project may be cached locally in
`~/dev/apple-docs` (its `README.md` says when they were fetched):
- The cache holds only pages downloaded directly from developer.apple.com, unchanged. A name or value may be
  taken from it or from the online page.
- Never name the cache as a source. Name the page of Apple's online documentation
  (`developer.apple.com/documentation/...`) and, for a list made from the cache, when it was downloaded.
- Nothing of it (JSON, text of the documentation) goes into the repository or an SDK; only facts
  (names, signatures, values), in own wording.
- The documentation has no values for most macros and enumerators and no fields of structs; those need
  another public source.

## Layout

| Path | Purpose |
|---|---|
| `make-open-sdk.sh` | Options, defaults, the loop over the steps. |
| `lib/*.sh` | The steps (`fetch`, `host`, `headers`, `stubs`, `cxx`, `libs`, `frameworks`, `meta`, `tarball`, `swift`) and common functions. |
| `helpers/*.py` | Python helpers (Python 3.7, standard library only, run with `python3 -I`): `write_*` writes a file of the SDK, `*_syms` a symbol list, the others without prefix are tools of single steps (e.g. `scrub_platforms`, `xnu_headers`, `tree_hash`); the modules that the helpers import are `clang_scan`, `data_files` and `notice`. |
| `tools/*.py` | Maintenance tools that the generator does not run (`manifest.py`, `check_libraries.py`, `doc_symbols.py`). |
| `data/manifests/` | Tags and commits of every project per macOS release. |
| `README.md` | Overview, download, short build instructions, licenses, known limits. |
| `docs/` | `SOURCES.md` (the public source of every value: headers, symbols, install names, versions, `SDKSettings.json` keys), `BUILDING.md` (dependencies, options, tests), `TESTED.md`, `LIBCXX.md`, `DETAILS.md`. |
| `data/` | The releases (`releases.txt`), own files (`own-files.txt`; the copied ones in `headers/`, by their path in the SDK, 0BSD), symbol lists with their sources (`symbols/`), install names and versions (`libraries.txt`), `libcxx-versions.txt`, `availability-extra.dsl`, `CFCompat.h.in`, license texts (`licenses/`). |
| `extras/` | Optional tools, e.g. `build-libcxx-static.sh`. |
| `tests/` | Unit tests (`unit/`), the lint script (`lint.sh`), the header check (`sdk-check.sh` with `sdk-check.py`; its allow list is `tests/data/header-allow.txt`), the test programs (`programs/`, `run.sh`) and the open source projects of `docs/TESTED.md` (`projects.sh`). |
| `.github/workflows/` | `ci.yml` (tests, all releases, an OSXCross build) and `release.yml` (tarballs of a tag). |

## Conventions

- Scripts run on Linux, macOS (bash 3.2, BSD tools), FreeBSD and OpenBSD: no
  GNU-only options, no bash 4 features.
- No error is hidden: no `|| true` without a comment that says which error
  is expected.
- A change of the SDK's content needs a comparison of the old and the new
  tree (`diff -r` of the unpacked tarballs); say in the commit what differs
  and why. A change that must not alter the SDK is checked with
  `--tree-hash` of the full and `--core` SDK of macOS 26.5 and 14.3
  (`OpenSDK.json` names the generator commit, so compare without it or
  build both from a clean tree).
- The generator builds with Clang 11 or newer (the result is the same with every
  version); the full SDK is made for macOS 14.3 and later, the core SDK (`--core`)
  for 11.3 and later.
- Builds run with a clean environment (`env -i`), one at a time, in a work
  directory of their own (`--work-dir`, `--output-dir`).
- Licenses: the generator is GPL-2.0-only (`LICENSE`); files
  that are copied into the SDK and were written here are 0BSD
  (`data/headers/`). A changed APSL/Apache header gets the
  `Modified by osxcross-open-sdk` line (`helpers/notice.py`).
- Never push, never tag, never create a release without being asked.
- Before a push, the commits since the last audit are audited: every name, value, list and
  install name has a named public source that contains it at the named commit, nothing is
  taken from an SDK or binary of Apple's (a real SDK only as a check, e.g. that no comment
  text is copied), no source is one that AGENTS.md excludes, and docs/SOURCES.md says the same.
  The audit names the range it covers; a finding is fixed or decided before the push.

## Tests before a commit

Run what the change touches, at least:

```sh
tests/lint.sh       # bash -n, shellcheck -x -S warning, the syntax of the Python files
tests/unit/run.sh
./make-open-sdk.sh --core && tests/sdk-check.sh out/MacOSX26.5-open-core-sdk-*.tar.xz
```

For changes of headers or stubs also the full SDK, `tests/sdk-check.sh` on
it and `tests/run.sh --sdk <tarball> --osxcross <target>` (both architectures); a run on a
Mac with `--ssh HOST` where possible.

## Releases

- The tarballs name the generator commit in their name, `OpenSDK.json`, `SDKSettings.json` and `SDKSettings.plist`: every commit
  changes their SHA-256 and `--tree-hash`. Hashes in a report are only valid
  for the commit they were built from.

## Style of README.md and docs/

- File names: every Markdown file has an upper-case name (`README.md`,
  `docs/BUILDING.md`). The README stays short; details go to `docs/`.
- Short, but without leaving out important details. Facts are checked
  against the code and `--help`; nothing is claimed that was not tested
  (say what was not, e.g. arm64 at run time).
- It must read well both in the file and rendered. There is no fixed line
  limit: break at natural points (end of a sentence or clause, before
  "see", before a list of sources), not at a column; lines of up to about
  120 characters are fine.
- Avoid dense paragraphs: an enumeration (sources, conditions, values)
  becomes a list, one item per thing; a short entry stays on one line.
- A line that continues in the same paragraph or list item ends with two
  spaces, so the rendered text breaks where the source does.
- No last line of a paragraph or list item with only one or two words.
  Do not split an inline code span over two lines.
- Keep tables narrow (few, short columns); a long table becomes a short
  table plus a list, or a list with the term in bold. Reference tables
  (`docs/SOURCES.md`) keep two short columns: the entry and a summary
  that names the sources, with a link to a section below the table. The
  section has a `**Files:**` line (the files of the repository) and lists
  the details, one source per item; sections are separated by `---`.
- Program names, packages, options, files and variables are code spans
  (`` `git` ``, `` `--core` ``).
- Describe what the SDK is and does; do not argue about Apple's SDK or
  its license.
- `docs/SOURCES.md` is read by people who do not know the generator: say what a list or value is and why it is needed,
  with an example (`printf` from `stdio.h`), before naming the source; no shorthand that only the code explains.
- `docs/SOURCES.md`: where a value follows from how open projects use it, say so ("they rely on it"),
  not as a result of the SDK.
- `docs/SOURCES.md` is ordered like its overview tables (libraries, headers, frameworks, SDK metadata):
  a new section goes into the table of its area and in the same place below. A section has, in this order:
  - `**Files:**`: the files of this repository (not the files of the projects: they belong to Sources), one file or
    directory per list item.
  - `**Source:**` (one item) or `**Sources:**` (more): only the sources, short and at once visible; one project
    (or document) per list item, its files (tag or commit, file) separated by commas. No explanation here. A value
    of the generator itself says `**Source:**` with the item `none, ...`. Every source that the text names (project,
    tag or commit, file) is also in this list; a claim whose source cannot be named does not belong here.
  - `**Details:**`: what the list or value is and why it is needed, with an example, then what comes from which
    source (named by its short name; tag and commit are already above).
  - `**Files:**`, `**Source(s):**` and `**Details:**` each stand alone on their line, followed by a blank line.
    Files and Sources are always lists, also with a single item.
  - optional, in this order: `**Not in the Open SDK:**` (what is left out and why), `**Chosen by the generator:**`
    (every value that no public source gives and the generator chooses, such as a conservative release or the lowest
    possible version: all in this one list, so that a search finds them; none is read from an Apple SDK or binary), `**Checks:**` (tests that are no source).
    Where needed also `**Limits:**` and `**License:**`.
  - A section of more than about ten items gets subsections (`####`) by topic.
  - The same kind of fact for several things (an install name per framework, a module per stub)
    becomes a table with short columns and numbered notes below it, not one item per thing.
  - The overview tables name what a section covers in a few words, not a list of names.
  - A project whose name other projects share (Libc, Libm, libiconv, libedit, CF, Security, ...) is written
    "apple-oss Libc" when it is Apple's open source release (at least once per section and in the overview tables);
    projects that only Apple has (xnu, dyld, Libsystem, IOKitUser) need no prefix.
- A URL is written as a Markdown link with a readable text (`[File System Events](https://...)`), not as bare text;
  a pattern with a placeholder (`.../<name>`) stays a code span.
- After a change of a Markdown file, check that no link or anchor is broken: every `*.md` of the root and of
  `docs/` (`README.md`, `AGENTS.md`, `docs/*.md`), not only the changed file, because a renamed heading breaks
  the links of other files (`#getting-the-open-sdk`, `SOURCES.md#iokit-device-families`). `tests/lint.sh` checks it
  (`tests/md_links.py`).
- Where the SDK made by this generator is meant, write "Open SDK" ("the full Open SDK", "not in the Open SDK"),
  so it cannot be taken for Apple's SDK or any other SDK.
- `docs/TESTED.md`: a new entry looks like the ones there, as short as possible, with only
  the details that matter (an option it needs, what it was tested with). No build commands,
  no list of what was not tried, no counts.

## Commits

- Subject: `<file or area>: <Imperative summary>`. A commit that changes the structure
  but not the SDK and not the behaviour starts with `Refactor:`
  (`Refactor: lib: One function per task`).
- Body, wrapped at about 72 columns, short: cause first, then the fix, then side effects
  or limits. A commit of only documentation has the subject line and no body.
- A fix of a bug says how it was found (which test or program, on which system, with
  which compiler) and, if it was there for long, why it did not show before.
- A change of the SDK's content says briefly what differs (which parts of the SDK, no counts),
  in a paragraph that starts with "Compared with the previous commit, the full SDKs differ in …"
  (and the core SDKs).
- If a project builds (or links, or runs) now that did not before, a line
  "Builds now: …" names it, before `Testing:`; only projects that were built.
- A `Testing:` section lists only what was actually run, short. It does not list what
  was not tested; only if nothing was tested, it says so.
- No `Co-Authored-By` line and no other attribution of an AI, unless the user asks
  for it explicitly (e.g. "Found in an audit with …").
- There is no change log; the commit messages tell what changed and why.
- A commit that is changed before it is pushed (amend, fixup, rebase) keeps its author and
  committer date (`git rebase --committer-date-is-author-date`, `GIT_COMMITTER_DATE` with `--amend`).
