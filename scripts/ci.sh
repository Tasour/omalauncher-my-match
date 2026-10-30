#!/usr/bin/env bash
# Offline CI entry point: the same gates on a laptop and in any CI runner.
# owl-check stays a device gate (it needs the running launcher); set OWL_JAR
# to a checker jar to add a compile gate where one is available.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 -m py_compile tests/*.py
# shellcheck disable=SC1091
./tests/run-all.sh
