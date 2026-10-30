#!/usr/bin/env bash
# Full gate: the fast suite plus the long source/degraded/concurrency tests.
# Local iteration can stay on tests/run.sh (make test); CI runs this.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIDGET="$ROOT/widget/my-match.optimized.owl"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"$ROOT/tests/run.sh"

for v in scheds teamsDb extra knock nextup histfull; do
  python3 "$ROOT/tests/extract.py" "$WIDGET" "$v" >"$TMP/$v.sh"
done

bash "$ROOT/tests/test-sources.sh" \
  "$TMP/scheds.sh" "$TMP/teamsDb.sh" "$TMP/extra.sh" \
  "$TMP/knock.sh" "$TMP/nextup.sh" "$TMP/histfull.sh"
bash "$ROOT/tests/test-degraded.sh" \
  "$TMP/scheds.sh" "$TMP/teamsDb.sh" "$TMP/extra.sh" \
  "$TMP/knock.sh" "$TMP/nextup.sh" "$TMP/histfull.sh"
bash "$ROOT/tests/test-cache-concurrency.sh" \
  "$TMP/teamsDb.sh" "$TMP/extra.sh" "$TMP/knock.sh"

printf 'ALL SLOW SOURCE TESTS PASSED\n'
