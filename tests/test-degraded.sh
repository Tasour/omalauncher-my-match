#!/usr/bin/env bash
# I28: degraded network fixtures: 429, 5xx, offline, truncated and oversized
# payloads must fail gracefully and never poison an existing cache.
set -euo pipefail

SCHEDS="${1:?usage: test-degraded.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
TEAMS="${2:?usage: test-degraded.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
EXTRA="${3:?usage: test-degraded.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
KNOCK="${4:?usage: test-degraded.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
NEXT="${5:?usage: test-degraded.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
HIST="${6:?usage: test-degraded.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export FIXTURES="$ROOT/tests/fixtures"
export PATH="$ROOT/tests/bin:$PATH"
export TEST_FAVSTR="LYON"
export TEST_FAVLG="ned.1"
export TEST_FAVTID=""
export TEST_FAVNOTID=""
unset MOCK_MODE MOCK_INVALID MOCK_LOGO

MODES="429 500 503 offline trunc big"

pass() { printf 'PASS %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  tail -8 "$TMP"/*.err 2>/dev/null || true
  exit 1
}
new_home() {
  local home="$TMP/$1"
  mkdir -p "$home/.cache"
  printf '%s' "$home"
}
run_mode() {
  local home=$1 mode=$2 script=$3 out=$4 err=$5
  HOME="$home" MOCK_MODE="$mode" bash "$script" >"$out" 2>"$err"
}
cache_tree_ok() {
  local home=$1 label=$2 found=0 f
  for f in "$home"/.cache/espn-*.json; do
    [ -e "$f" ] || continue
    found=1
    jq -e 'type == "object" or type == "array"' "$f" >/dev/null 2>&1 ||
      fail "$label: $f is not valid JSON"
    [ -s "$f.meta" ] || fail "$label: $f has no metadata"
    jq -e '.v == 1 and .ttl > 0 and .exp > .at' "$f.meta" >/dev/null 2>&1 ||
      fail "$label: $f metadata is invalid"
  done
  [ "$found" -eq 1 ] || fail "$label: no cache was left behind"
  if find "$home/.cache" -name '*.tmp' -print -quit | grep -q .; then
    fail "$label: temporary cache file left behind"
  fi
}

# --- teamsDb: every mode falls back to a complete, valid cache --------------
TEAMS_HOME=$(new_home teams)
HOME="$TEAMS_HOME" bash "$TEAMS" >"$TMP/teams-base.json" 2>"$TMP/teams-base.err" ||
  fail "teamsDb warm-up failed"
jq -e 'any(.[]; .abbr == "LYON" and .league == "fra.1")' "$TMP/teams-base.json" >/dev/null 2>&1 ||
  fail "teamsDb warm-up lost LYON"
TEAMS_META="$TEAMS_HOME/.cache/espn-teams.json.meta"
TEAMS_AT=$(jq -r '.at' "$TEAMS_META")
for mode in $MODES; do
  run_mode "$TEAMS_HOME" "$mode" "$TEAMS" "$TMP/teams-$mode.json" "$TMP/teams-$mode.err" ||
    fail "teamsDb must fall back to its cache under MOCK_MODE=$mode"
  jq -e 'any(.[]; .abbr == "LYON" and .league == "fra.1")' "$TMP/teams-$mode.json" >/dev/null 2>&1 ||
    fail "teamsDb cache fallback lost LYON under MOCK_MODE=$mode"
  [ "$TEAMS_AT" = "$(jq -r '.at' "$TEAMS_META")" ] ||
    fail "teamsDb refreshed fetchedAt under MOCK_MODE=$mode"
  cache_tree_ok "$TEAMS_HOME" "teamsDb MOCK_MODE=$mode"
done
pass "teamsDb survives 429/5xx/offline/truncated/oversized failures"

# --- teamsDb: a cold failure writes no half-valid cache ---------------------
for mode in $MODES; do
  home=$(new_home "teams-cold-$mode")
  if run_mode "$home" "$mode" "$TEAMS" "$TMP/teams-cold-$mode.json" "$TMP/teams-cold-$mode.err"; then
    fail "teamsDb must fail on a cold MOCK_MODE=$mode"
  fi
  if find "$home/.cache" -name 'espn-*.json' -print -quit | grep -q .; then
    fail "teamsDb wrote a cache after a cold MOCK_MODE=$mode failure"
  fi
  if find "$home/.cache" -name '*.tmp' -print -quit | grep -q .; then
    fail "teamsDb left a temporary file after a cold MOCK_MODE=$mode failure"
  fi
done
pass "teamsDb cold failures write no poisoned cache"

# --- extra: truncated and oversized responses fall back to the base cache ---
EXTRA_HOME=$(new_home extra)
HOME="$EXTRA_HOME" bash "$EXTRA" >"$TMP/extra-base.json" 2>"$TMP/extra-base.err" ||
  fail "extra warm-up failed"
jq -e 'any(.[]; .league == "ned.1" and .state == "post")' "$TMP/extra-base.json" >/dev/null 2>&1 ||
  fail "extra warm-up lost the ned.1 match"
EXTRA_META="$EXTRA_HOME/.cache/espn-extra.json.meta"
EXTRA_AT=$(jq -r '.at' "$EXTRA_META")
for mode in trunc big; do
  run_mode "$EXTRA_HOME" "$mode" "$EXTRA" "$TMP/extra-$mode.json" "$TMP/extra-$mode.err" ||
    fail "extra must fall back to its base cache under MOCK_MODE=$mode"
  jq -e 'any(.[]; .league == "ned.1" and .state == "post")' "$TMP/extra-$mode.json" >/dev/null 2>&1 ||
    fail "extra fallback lost the ned.1 match under MOCK_MODE=$mode"
  [ "$EXTRA_AT" = "$(jq -r '.at' "$EXTRA_META")" ] ||
    fail "extra refreshed fetchedAt under MOCK_MODE=$mode"
  cache_tree_ok "$EXTRA_HOME" "extra MOCK_MODE=$mode"
done
pass "extra falls back on truncated/oversized responses"

# --- histfull: rate-limited and oversized responses keep the history -------
HIST_HOME=$(new_home hist)
HOME="$HIST_HOME" bash "$HIST" >"$TMP/hist-base.json" 2>"$TMP/hist-base.err" ||
  fail "histfull warm-up failed"
jq -e 'has("ned.1") and (.["ned.1"] | length) > 0' "$TMP/hist-base.json" >/dev/null 2>&1 ||
  fail "histfull warm-up lost the ned.1 history"
HIST_META="$HIST_HOME/.cache/espn-history.json.meta"
HIST_AT=$(jq -r '.at' "$HIST_META")
for mode in 429 big; do
  run_mode "$HIST_HOME" "$mode" "$HIST" "$TMP/hist-$mode.json" "$TMP/hist-$mode.err" ||
    fail "histfull must fall back to its base cache under MOCK_MODE=$mode"
  jq -e 'has("ned.1") and (.["ned.1"] | length) > 0' "$TMP/hist-$mode.json" >/dev/null 2>&1 ||
    fail "histfull fallback lost the ned.1 history under MOCK_MODE=$mode"
  [ "$HIST_AT" = "$(jq -r '.at' "$HIST_META")" ] ||
    fail "histfull refreshed fetchedAt under MOCK_MODE=$mode"
  cache_tree_ok "$HIST_HOME" "histfull MOCK_MODE=$mode"
done
pass "histfull falls back on rate-limited/oversized responses"

# --- sources that abort on a total failure must leave the cache untouched ---
KNOCK_HOME=$(new_home knock)
HOME="$KNOCK_HOME" bash "$KNOCK" >"$TMP/knock-base.json" 2>"$TMP/knock-base.err" ||
  fail "knock warm-up failed"
KNOCK_CACHE="$KNOCK_HOME/.cache/espn-knock.json"
[ -s "$KNOCK_CACHE" ] || fail "knock wrote no cache"
KNOCK_SUM=$(sha256sum "$KNOCK_CACHE")
for mode in trunc big; do
  if run_mode "$KNOCK_HOME" "$mode" "$KNOCK" "$TMP/knock-$mode.json" "$TMP/knock-$mode.err"; then
    fail "knock must fail under MOCK_MODE=$mode instead of trusting the payload"
  fi
  [ "$KNOCK_SUM" = "$(sha256sum "$KNOCK_CACHE")" ] ||
    fail "knock cache changed after a MOCK_MODE=$mode failure"
  cache_tree_ok "$KNOCK_HOME" "knock MOCK_MODE=$mode"
done
pass "knock failures leave the cache untouched"

NEXT_HOME=$(new_home next)
HOME="$NEXT_HOME" bash "$NEXT" >"$TMP/next-base.json" 2>"$TMP/next-base.err" ||
  fail "nextup warm-up failed"
NEXT_CACHE="$NEXT_HOME/.cache/espn-nextup.json"
[ -s "$NEXT_CACHE" ] || fail "nextup wrote no cache"
NEXT_SUM=$(sha256sum "$NEXT_CACHE")
if run_mode "$NEXT_HOME" 429 "$NEXT" "$TMP/next-429.json" "$TMP/next-429.err"; then
  fail "nextup must fail under MOCK_MODE=429 instead of trusting the payload"
fi
[ "$NEXT_SUM" = "$(sha256sum "$NEXT_CACHE")" ] ||
  fail "nextup cache changed after a MOCK_MODE=429 failure"
cache_tree_ok "$NEXT_HOME" "nextup MOCK_MODE=429"
pass "nextup failures leave the cache untouched"

# --- scheds has no cache: degraded responses must fail with no residue ------
for mode in trunc big; do
  home=$(new_home "scheds-$mode")
  if run_mode "$home" "$mode" "$SCHEDS" "$TMP/scheds-$mode.json" "$TMP/scheds-$mode.err"; then
    fail "scheds must fail under MOCK_MODE=$mode"
  fi
  if find "$home/.cache" -name 'espn-*' -print -quit | grep -q .; then
    fail "scheds wrote a cache under MOCK_MODE=$mode"
  fi
  if find "$home/.cache" -name '*.tmp' -print -quit | grep -q .; then
    fail "scheds left a temporary file under MOCK_MODE=$mode"
  fi
done
pass "scheds fails cleanly on degraded responses"

printf 'ALL DEGRADED-NETWORK TESTS PASSED\n'
