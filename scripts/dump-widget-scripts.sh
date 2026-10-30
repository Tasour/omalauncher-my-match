#!/usr/bin/env bash
# Dump every shell script embedded in the widget to a build directory, for
# review, shellcheck or editing away from the 2k-line monolith. The widget
# stays the source of truth: this is a development aid, not a build step.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIDGET="$ROOT/widget/my-match.optimized.owl"
OUT="${1:-$ROOT/build/widget-scripts}"

mkdir -p "$OUT"
for v in gamesScript seasonScript standingsScript liveScript heroOddsScript \
         scheds teamsDb extra knock nextup histfull; do
  python3 "$ROOT/tests/extract.py" "$WIDGET" "$v" >"$OUT/$v.sh"
  printf '%s\n' "$OUT/$v.sh"
done
