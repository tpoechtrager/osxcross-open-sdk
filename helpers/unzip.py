#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""unzip.py ZIPFILE DESTDIR: unpack a zip archive (the host may lack unzip)."""
import sys
import zipfile


def main(argv):
    if len(argv) != 3:
        sys.stderr.write(__doc__)
        return 2
    with zipfile.ZipFile(argv[1]) as z:
        z.extractall(argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
