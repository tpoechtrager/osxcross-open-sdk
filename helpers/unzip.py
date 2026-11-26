#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""unzip.py ZIPFILE DESTDIR: unpack a zip archive (the host may lack unzip)."""
import argparse
import sys
import zipfile


def main(argv):
    p = argparse.ArgumentParser(prog="unzip.py", description="Unpack a zip archive.")
    p.add_argument("zipfile")
    p.add_argument("destdir")
    a = p.parse_args(argv[1:])
    with zipfile.ZipFile(a.zipfile) as z:
        z.extractall(a.destdir)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
