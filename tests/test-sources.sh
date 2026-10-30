#!/usr/bin/env bash
# I27: offline shape and cache-fallback tests for the secondary sources.
# The extracted scripts are the real widget scripts; only curl is faked.
set -euo pipefail

SCHEDS="${1:?usage: test-sources.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
TEAMS="${2:?usage: test-sources.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
EXTRA="${3:?usage: test-sources.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
KNOCK="${4:?usage: test-sources.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
NEXT="${5:?usage: test-sources.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"
HIST="${6:?usage: test-sources.sh scheds.sh teamsDb.sh extra.sh knock.sh nextup.sh histfull.sh}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME/.cache" "$TMP/nofixtures"
export FIXTURES="$ROOT/tests/fixtures"
export PATH="$ROOT/tests/bin:$PATH"
export MOCK_LOG="$TMP/curl.log"
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
meta_ok() {
  [ -s "$1" ] && jq -e '.v == 1 and .ttl > 0 and .exp > .at' "$1" >/dev/null 2>&1
}
run() { bash "$1" >"$2" 2>"$TMP/err"; }

# --- scheds: 7 team-schedule responses -> rounds + anchors ------------------
: >"$MOCK_LOG"
run "$SCHEDS" "$TMP/scheds.json" || fail "scheds should succeed with schedule fixtures"
jq -e '.rounds | type == "object" and length > 0' "$TMP/scheds.json" >/dev/null 2>&1 ||
  fail "scheds output has no rounds"
jq -e '.anchors | type == "object" and length > 0' "$TMP/scheds.json" >/dev/null 2>&1 ||
  fail "scheds output has no anchors"
jq -e '.anchors["fra.1"] | .jn > 0 and .at > 0' "$TMP/scheds.json" >/dev/null 2>&1 ||
  fail "scheds anchor for fra.1 is incomplete"
jq -e '.rounds | to_entries | any(.key | startswith("fra.1:"))' "$TMP/scheds.json" >/dev/null 2>&1 ||
  fail "scheds rounds do not carry fra.1 keys"
[ "$(grep -c -- '/schedule' "$MOCK_LOG" || true)" -eq 7 ] ||
  fail "scheds did not request the seven schedule endpoints"
pass "scheds builds rounds and anchors"

# --- teamsDb: catalogue shape, then offline fallback ------------------------
run "$TEAMS" "$TMP/teams.json" || fail "teamsDb should succeed with a teams fixture"
jq -e 'type == "array" and length > 0' "$TMP/teams.json" >/dev/null 2>&1 ||
  fail "teamsDb produced no catalogue"
jq -e 'any(.[]; .abbr == "LYON" and .league == "fra.1" and .tag == "L1" and .kind == "c" and .tid == "167")' \
  "$TMP/teams.json" >/dev/null 2>&1 || fail "teamsDb lost the LYON club entry"
jq -e 'all(.[]; has("key") and has("name") and has("short") and has("abbr") and has("display") and has("logo") and has("league") and has("tag") and has("kind") and has("tid"))' \
  "$TMP/teams.json" >/dev/null 2>&1 || fail "teamsDb entry shape is incomplete"
meta_ok "$HOME/.cache/espn-teams.json.meta" || fail "teamsDb cache lacks metadata"
TEAMS_AT=$(jq -r '.at' "$HOME/.cache/espn-teams.json.meta")
MOCK_MODE=offline bash "$TEAMS" >"$TMP/teams-off.json" 2>"$TMP/teams-off.err" ||
  fail "teamsDb should serve its cache offline"
jq -e 'any(.[]; .abbr == "LYON" and .league == "fra.1")' "$TMP/teams-off.json" >/dev/null 2>&1 ||
  fail "teamsDb offline fallback lost the catalogue"
[ "$TEAMS_AT" = "$(jq -r '.at' "$HOME/.cache/espn-teams.json.meta")" ] ||
  fail "teamsDb cache-only fallback refreshed fetchedAt"
pass "teamsDb catalogue and offline fallback"

# --- extra: past matches, then base-cache fallback offline ------------------
run "$EXTRA" "$TMP/extra.json" || fail "extra should succeed with fixtures"
jq -e 'type == "array" and length > 0' "$TMP/extra.json" >/dev/null 2>&1 ||
  fail "extra produced no matches"
jq -e 'any(.[]; .league == "ned.1" and .tag == "NED" and .state == "post" and .home.abbr == "AJAX")' \
  "$TMP/extra.json" >/dev/null 2>&1 || fail "extra lost the ned.1 played match"
meta_ok "$HOME/.cache/espn-extra-base.json.meta" || fail "extra base cache lacks metadata"
meta_ok "$HOME/.cache/espn-extra.json.meta" || fail "extra output cache lacks metadata"
EXTRA_AT=$(jq -r '.at' "$HOME/.cache/espn-extra.json.meta")
MOCK_MODE=offline bash "$EXTRA" >"$TMP/extra-off.json" 2>"$TMP/extra-off.err" ||
  fail "extra should serve its base cache offline"
jq -e 'any(.[]; .league == "ned.1" and .state == "post")' "$TMP/extra-off.json" >/dev/null 2>&1 ||
  fail "extra offline fallback lost the played match"
[ "$EXTRA_AT" = "$(jq -r '.at' "$HOME/.cache/espn-extra.json.meta")" ] ||
  fail "extra cache-only fallback refreshed fetchedAt"
pass "extra output and offline fallback"

# --- knock: bracket shape, then empty-response cache fallback ---------------
run "$KNOCK" "$TMP/knock.json" || fail "knock should succeed with a UEFA fixture"
jq -e 'type == "array" and length > 0' "$TMP/knock.json" >/dev/null 2>&1 ||
  fail "knock produced no matches"
jq -e 'any(.[]; .league == "uefa.champions" and .tag == "C1" and (.home.abbr | length) > 0 and (.away.abbr | length) > 0)' \
  "$TMP/knock.json" >/dev/null 2>&1 || fail "knock match shape is incomplete"
meta_ok "$HOME/.cache/espn-knock.json.meta" || fail "knock cache lacks metadata"
KNOCK_AT=$(jq -r '.at' "$HOME/.cache/espn-knock.json.meta")
ORIG_FIXTURES="$FIXTURES"
FIXTURES="$TMP/nofixtures"
run "$KNOCK" "$TMP/knock-fallback.json" || fail "knock should keep its cache when responses are empty"
jq -e 'any(.[]; .id == "uefa.champions:ucl-post-1")' "$TMP/knock-fallback.json" >/dev/null 2>&1 ||
  fail "knock cache fallback lost the stored match"
[ "$KNOCK_AT" = "$(jq -r '.at' "$HOME/.cache/espn-knock.json.meta")" ] ||
  fail "knock cache-only fallback refreshed fetchedAt"
FIXTURES="$ORIG_FIXTURES"
pass "knock bracket and cache fallback"

# --- nextup: upcoming matches, then empty-response cache fallback -----------
run "$NEXT" "$TMP/next.json" || fail "nextup should succeed with fixtures"
jq -e 'type == "array" and length > 0' "$TMP/next.json" >/dev/null 2>&1 ||
  fail "nextup produced no upcoming matches"
jq -e 'any(.[]; .state == "pre" and (.home.abbr | length) > 0 and (.away.abbr | length) > 0)' \
  "$TMP/next.json" >/dev/null 2>&1 || fail "nextup match shape is incomplete"
meta_ok "$HOME/.cache/espn-nextup.json.meta" || fail "nextup cache lacks metadata"
NEXT_AT=$(jq -r '.at' "$HOME/.cache/espn-nextup.json.meta")
FIXTURES="$TMP/nofixtures"
run "$NEXT" "$TMP/next-fallback.json" || fail "nextup should keep its cache when responses are empty"
jq -e 'any(.[]; .state == "pre")' "$TMP/next-fallback.json" >/dev/null 2>&1 ||
  fail "nextup cache fallback lost the stored fixtures"
[ "$NEXT_AT" = "$(jq -r '.at' "$HOME/.cache/espn-nextup.json.meta")" ] ||
  fail "nextup cache-only fallback refreshed fetchedAt"
FIXTURES="$ORIG_FIXTURES"
pass "nextup fixtures and cache fallback"

# --- histfull: grouped history, then offline fallback -----------------------
run "$HIST" "$TMP/hist.json" || fail "histfull should succeed with fixtures"
jq -e 'type == "object" and has("ned.1") and (.["ned.1"] | length) > 0' "$TMP/hist.json" >/dev/null 2>&1 ||
  fail "histfull produced no ned.1 history"
jq -e --arg lg "ned.1" '.[$lg][] | has("id") and has("league") and has("at") and has("home") and has("away")' \
  "$TMP/hist.json" >/dev/null 2>&1 || fail "histfull match shape is incomplete"
meta_ok "$HOME/.cache/espn-hist-base.json.meta" || fail "histfull base cache lacks metadata"
meta_ok "$HOME/.cache/espn-history.json.meta" || fail "histfull output cache lacks metadata"
HIST_AT=$(jq -r '.at' "$HOME/.cache/espn-history.json.meta")
MOCK_MODE=offline bash "$HIST" >"$TMP/hist-off.json" 2>"$TMP/hist-off.err" ||
  fail "histfull should serve its base cache offline"
jq -e 'has("ned.1") and (.["ned.1"] | length) > 0' "$TMP/hist-off.json" >/dev/null 2>&1 ||
  fail "histfull offline fallback lost the history"
[ "$HIST_AT" = "$(jq -r '.at' "$HOME/.cache/espn-history.json.meta")" ] ||
  fail "histfull cache-only fallback refreshed fetchedAt"
pass "histfull grouping and offline fallback"

printf 'ALL SOURCES TESTS PASSED\n'
