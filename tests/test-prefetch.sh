#!/usr/bin/env bash
# H2H prefetch: the next match of each team is cached before it becomes hero.
set -euo pipefail

PREFETCH="${1:?usage: test-prefetch.sh prefetchScript.sh}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME/.cache"
export FIXTURES="$ROOT/tests/fixtures"
export PATH="$ROOT/tests/bin:$PATH"
export TEST_PREFETCH="fra.2|fra.2:401876708|1793386800|GRE"

pass() { printf 'PASS %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  tail -8 "$TMP/err" 2>/dev/null || true
  exit 1
}

bash "$PREFETCH" >"$TMP/out" 2>"$TMP/err" || fail "prefetch script failed"
F="$HOME/.cache/espn-odds/fra.2-401876708.json"
[ -s "$F" ] || fail "prefetch did not write the summary cache"
jq -e '.hv == 1 and .h2h != null and .h2h.n == 5' "$F" >/dev/null 2>&1 ||
  fail "prefetched cache lacks H2H"
pass "next-match summary is prefetched with H2H"

printf 'ALL PREFETCH TESTS PASSED\n'
