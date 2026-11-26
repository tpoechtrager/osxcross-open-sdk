#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# The static checks of the scripts: tests/lint.sh
#   bash -n of the generator, shellcheck (warnings and errors) of every shell
#   script, and a syntax check of every Python file (nothing is written)
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.." || exit 2
rc=0
bash -n make-open-sdk.sh lib/*.sh || rc=1
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x -S warning make-open-sdk.sh lib/*.sh tests/*.sh tests/unit/*.sh extras/*.sh || rc=1
else
  echo "tests/lint.sh: shellcheck is not installed" >&2
  rc=1
fi
python3 -I -c '
import sys
for f in sys.argv[1:]:
    with open(f) as fh:
        compile(fh.read(), f, "exec")
' helpers/*.py tools/*.py tests/*.py tests/unit/*.py || rc=1
[ "$rc" = 0 ] && echo "tests/lint.sh: ok"
exit $rc
