#!/usr/bin/env bash
# I29: two refreshes racing on the same cache must leave valid JSON, valid
# metadata and no temporary files behind.
set -euo pipefail

TEAMS="${1:?usage: test-cache-concurrency.sh teamsDb.sh extra.sh knock.sh}"
EXTRA="${2:?usage: test-cache-concurrency.sh teamsDb.sh extra.sh knock.sh}"
KNOCK="${3:?usage: test-cache-concurrency.sh teamsDb.sh extra.sh knock.sh}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'for p in $(jobs -p); do kill "$p" 2>/dev/null || true; done; rm -rf "$TMP"' EXIT

export FIXTURES="$ROOT/tests/fixtures"
export PATH="$ROOT/tests/bin:$PATH"
export TEST_FAVSTR="LYON"
export TEST_FAVLG="ned.1"
export TEST_FAVTID=""
export TEST_FAVNOTID=""
unset MOCK_MODE MOCK_INVALID MOCK_LOGO

pass() { printf 'PASS %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  tail -8 "$TMP"/*.err 2>/dev/null || true
  exit 1
}

race() {
  local name=$1 script=$2
  local home="$TMP/$name"
  mkdir -p "$home/.cache"
  : >"$TMP/$name.curl.log"

  HOME="$home" MOCK_LOG="$TMP/$name.curl.log" bash "$script" \
    >"$TMP/$name.a.json" 2>"$TMP/$name.a.err" &
  local pa=$!
  HOME="$home" MOCK_LOG="$TMP/$name.curl.log" bash "$script" \
    >"$TMP/$name.b.json" 2>"$TMP/$name.b.err" &
  local pb=$!
  wait "$pa" || fail "$name: first parallel run failed"
  wait "$pb" || fail "$name: second parallel run failed"

  jq -e . "$TMP/$name.a.json" >/dev/null 2>&1 || fail "$name: first output is not JSON"
  jq -e . "$TMP/$name.b.json" >/dev/null 2>&1 || fail "$name: second output is not JSON"

  local found=0 f
  for f in "$home"/.cache/espn-*.json; do
    [ -e "$f" ] || continue
    found=1
    jq -e 'type == "object" or type == "array"' "$f" >/dev/null 2>&1 ||
      fail "$name: $f is not valid JSON after the race"
    [ -s "$f.meta" ] || fail "$name: $f has no metadata after the race"
    jq -e '.v == 1 and .ttl > 0 and .exp > .at' "$f.meta" >/dev/null 2>&1 ||
      fail "$name: $f metadata is invalid after the race"
  done
  [ "$found" -eq 1 ] || fail "$name: no cache was written"

  if find "$home/.cache" -name '*.tmp' -print -quit | grep -q .; then
    fail "$name: a temporary file survived the race"
  fi

  pass "$name caches stay valid under two parallel refreshes"
}

race teamsDb "$TEAMS"
race extra "$EXTRA"
race knock "$KNOCK"

printf 'ALL CACHE CONCURRENCY TESTS PASSED\n'
