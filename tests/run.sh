#!/usr/bin/env bash
# Run every offline check after a widget change: owl, bash -n, data fixtures.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIDGET="$ROOT/widget/my-match.optimized.owl"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OWL_JAR="${OWL_JAR:-/tmp/opencode/owl.jar}"
if [ -f "$OWL_JAR" ]; then
  java -jar "$OWL_JAR" check "$WIDGET"
  echo "PASS owl check"
else
  echo "SKIP owl check (set OWL_JAR to the owl checker jar)"
fi

for v in gamesScript seasonScript standingsScript liveScript heroOddsScript scheds teamsDb extra knock nextup histfull; do
  python3 "$ROOT/tests/extract.py" "$WIDGET" "$v" >"$TMP/$v.sh"
  bash -n "$TMP/$v.sh"
  echo "PASS bash -n $v"
done

bash "$ROOT/tests/test-games.sh" "$TMP/gamesScript.sh" "$WIDGET" "$TMP/liveScript.sh"
bash "$ROOT/tests/test-league-scope.sh" "$TMP/extra.sh" "$TMP/nextup.sh" "$TMP/histfull.sh"
bash "$ROOT/tests/test-cache-meta.sh" "$TMP/standingsScript.sh"
python3 "$ROOT/tests/test-audit-improvements.py"
