#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# All tests that need neither network nor compiler: tests/unit/run.sh
HERE=$(cd "$(dirname "$0")" && pwd)
rc=0
python3 -I -m unittest discover -s "$HERE" -t "$HERE" 2>&1 || rc=1
bash "$HERE/test_options.sh" || rc=1
bash "$HERE/test_common.sh" || rc=1
exit $rc
