#!/usr/bin/env bash
# I11: the rivals/history sources follow the selected team's league, not a
# fixed whitelist. Uses the same offline curl and fixtures as test-games.sh.
set -euo pipefail

EXTRA="${1:?usage: test-league-scope.sh extra.sh nextup.sh histfull.sh}"
NEXT="${2:?usage: test-league-scope.sh extra.sh nextup.sh histfull.sh}"
HIST="${3:?usage: test-league-scope.sh extra.sh nextup.sh histfull.sh}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME/.cache"
export FIXTURES="$ROOT/tests/fixtures"
export PATH="$ROOT/tests/bin:$PATH"
export TEST_FAVLG="ned.1"
export TEST_FAVSTR=""
export TEST_FAVTID=""
export TEST_FAVNOTID=""
export MOCK_LOG="$TMP/curl.log"

pass() { printf 'PASS %s\n' "$1"; }
meta_ok() { [ -s "$1" ] && jq -e '.v == 1 and .ttl > 0 and .exp > .at' "$1" >/dev/null 2>&1; }
fail() {
  printf 'FAIL %s\n' "$1"
  tail -8 "$TMP"/*.err 2>/dev/null || true
  exit 1
}

bash "$EXTRA" >"$TMP/extra.json" 2>"$TMP/extra.err" || fail "extra should succeed with a fixture"
jq -e 'any(.[]; .league == "ned.1" and .tag == "NED" and .state != "pre")' "$TMP/extra.json" >/dev/null 2>&1 ||
  fail "extra follows a Dutch club into ned.1"
meta_ok "$HOME/.cache/espn-extra-base.json.meta" || fail "extra base cache lacks metadata"
meta_ok "$HOME/.cache/espn-extra.json.meta" || fail "extra output cache lacks metadata"
pass "extra follows a Dutch club into ned.1"

bash "$NEXT" >"$TMP/next.json" 2>"$TMP/next.err" || fail "nextup should succeed with a fixture"
jq -e 'any(.[]; .league == "ned.1" and .tag == "NED" and .state == "pre")' "$TMP/next.json" >/dev/null 2>&1 ||
  fail "nextup follows a Dutch club into ned.1"
meta_ok "$HOME/.cache/espn-nextup.json.meta" || fail "nextup cache lacks metadata"
pass "nextup follows a Dutch club into ned.1"

bash "$HIST" >"$TMP/hist.json" 2>"$TMP/hist.err" || fail "histfull should succeed with a fixture"
jq -e 'has("ned.1")' "$TMP/hist.json" >/dev/null 2>&1 ||
  fail "histfull follows a Dutch club into ned.1"
meta_ok "$HOME/.cache/espn-hist-base.json.meta" || fail "hist base cache lacks metadata"
meta_ok "$HOME/.cache/espn-history.json.meta" || fail "hist output cache lacks metadata"
pass "histfull follows a Dutch club into ned.1"

: >"$MOCK_LOG"
export TEST_FAVLG="foo.1"
bash "$EXTRA" >"$TMP/foo.json" 2>"$TMP/foo.err" || fail "extra should ignore an unsupported league"
if grep -q 'soccer/foo.1/' "$MOCK_LOG"; then fail "unsupported league must not be requested"; fi
jq -e 'any(.[]; .league == "foo.1") | not' "$TMP/foo.json" >/dev/null 2>&1 ||
  fail "unsupported league must not reach the output"
pass "unsupported league is ignored"

printf 'ALL LEAGUE SCOPE TESTS PASSED\n'
