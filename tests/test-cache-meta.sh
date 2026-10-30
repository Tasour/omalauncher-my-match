#!/usr/bin/env bash
# I12: every aggregate cache carries schema/version/TTL metadata, and a stale
# cache no longer hides a failed refresh.
set -euo pipefail

STANDINGS="${1:?usage: test-cache-meta.sh standings.sh}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME/.cache"
export FIXTURES="$ROOT/tests/fixtures"
export PATH="$ROOT/tests/bin:$PATH"
export TEST_FAVSTR="LYON"
export TEST_FAVLG="fra.1"
export TEST_FAVTID=""
export TEST_FAVNOTID=""
export MOCK_LOG="$TMP/curl.log"

CACHE="$HOME/.cache/espn-standings.json"
META="$CACHE.meta"

pass() { printf 'PASS %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  tail -8 "$TMP"/err 2>/dev/null || true
  exit 1
}
run() { bash "$STANDINGS" >"$TMP/out.json" 2>"$TMP/err"; }

run || fail "standings should succeed with the fixture"
jq -e 'length > 0' "$TMP/out.json" >/dev/null 2>&1 || fail "standings fixture produced no table"
[ -s "$META" ] || fail "cache metadata was not written"
jq -e '.v == 1 and .ttl > 0 and .exp > .at' "$META" >/dev/null 2>&1 ||
  fail "cache metadata lacks schema/ttl/expiry"
AT1=$(jq -r '.at' "$META")
pass "standings cache carries schema and expiry"

: >"$MOCK_LOG"
if ! MOCK_INVALID=1 run; then fail "a valid cache should cover a fetch failure"; fi
AT2=$(jq -r '.at' "$META")
[ "$AT1" = "$AT2" ] || fail "a cache-only fallback refreshed fetchedAt"
jq -e 'length > 0' "$TMP/out.json" >/dev/null 2>&1 || fail "cache-only fallback lost the table"
pass "cache-only fallback keeps fetchedAt"

printf '{"v":0,"at":0,"ttl":0,"exp":0}' >"$META"
run || fail "standings should migrate an old cache"
jq -e '.v == 1 and .exp > .at' "$META" >/dev/null 2>&1 || fail "old cache was not migrated"
jq -e 'length > 0' "$TMP/out.json" >/dev/null 2>&1 || fail "migration lost the fresh data"
pass "old cache schema is migrated"

printf '{"v":1,"at":%s,"ttl":1,"exp":1}' "$(date +%s)" >"$META"
if MOCK_INVALID=1 run; then
  fail "a stale cache must not hide a failed refresh"
fi
pass "expired cache does not hide a failed refresh"

run || fail "standings should recover after the expired failure"
jq -e 'length > 0' "$TMP/out.json" >/dev/null 2>&1 || fail "recovery lost the table"
pass "standings recovers after a stale failure"

printf 'ALL CACHE META TESTS PASSED\n'
