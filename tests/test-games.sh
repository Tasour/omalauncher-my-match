#!/usr/bin/env bash
# Offline regression tests for the my-match data path.
set -euo pipefail

GAMES="${1:?usage: test-games.sh games.sh widget.owl [live.sh]}"
WIDGET="${2:?widget path}"
LIVE="${3:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/tests/fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME"
export FIXTURES
export PATH="$ROOT/tests/bin:$PATH"
export MOCK_LOG="$TMP/curl.log"
OUT="$TMP/out.json"

run_games() {
  : >"$MOCK_LOG"
  MOCK_INVALID="${MOCK_INVALID:-0}" bash "$GAMES" >"$OUT" 2>"$TMP/err"
}
pass() { printf 'PASS %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  tail -8 "$TMP/err" 2>/dev/null || true
  exit 1
}
assert_match() {
  jq -e --arg a "$2" 'length > 0 and ([.[] | .home.abbr, .away.abbr] | index($a) != null)' "$OUT" >/dev/null 2>&1 ||
    fail "$1"
}

# --- static guards -----------------------------------------------------------
grep -q 'has("events") or has("leagues")' "$GAMES" || fail "games fetch validates the ESPN response"
grep -q 'SIG=.*WANTLG' "$GAMES" || fail "SIG includes WANTLG"
grep -q '! -s "$f"' "$GAMES" || fail "empty monthly cache entries are refetched"
grep -Fq ',t.leagues??[],[t.league]' "$WIDGET" || fail "favLg falls back when a team has no league"
grep -q '+sh(favStr)+' "$WIDGET" || fail "favStr goes through sh()"
grep -q '+sh(favLg)+' "$WIDGET" || fail "favLg goes through sh()"
pass "static guards"

# --- full league list (fallback) --------------------------------------------
export TEST_FAVSTR="LYON"
export TEST_FAVTID=""
export TEST_FAVNOTID=""
export TEST_FAVLG=""
run_games || fail "games should succeed with the full league list"
assert_match "full list finds LYON" "LYON"
jq -e '.v == 1 and .exp > .at' "$HOME/.cache/espn-games.json.meta" >/dev/null 2>&1 ||
  fail "games cache lacks metadata"
if find "$HOME/.cache/espn-logos/soccer" -name '.*.tmp' -o -name '.*.lock' 2>/dev/null | grep -q .; then
  fail "logo downloads left a temp file or lock"
fi
pass "full list finds LYON"

# --- atomic crest download --------------------------------------------------
export MOCK_LOGO=1
LOGO="$HOME/.cache/espn-logos/soccer"
rm -rf "$LOGO"
mkdir -p "$LOGO/.stale.lock"
touch -d '20 minutes ago' "$LOGO/.stale.lock"
printf 'x' >"$LOGO/.stale.tmp"
touch -d '20 minutes ago' "$LOGO/.stale.tmp"
run_games || fail "games should download a crest"
find "$LOGO" -name '*.png' | grep -q . || fail "crest was not stored"
find "$LOGO" \( -name '.*.tmp' -o -name '.*.lock' \) | grep -q . &&
  fail "temp file or lock left after a crest download"
unset MOCK_LOGO
pass "crests download atomically"

# --- dynamic league list -----------------------------------------------------
export TEST_FAVLG="fra.1"
run_games || fail "games should succeed with the dynamic list"
assert_match "dynamic list finds LYON" "LYON"
pass "dynamic list finds LYON"

export TEST_FAVSTR="ARS"
export TEST_FAVLG="eng.1"
run_games || fail "games should succeed for eng.1"
assert_match "eng.1 finds ARS" "ARS"
pass "eng.1 finds ARS"

# --- an invalid response must not poison the cache ---------------------------
export TEST_FAVSTR="LYON"
export TEST_FAVLG="fra.1"
rm -rf "$HOME/.cache/espn-games.json" "$HOME/.cache/espn-games.sig" "$HOME/.cache/espn-games-months"
if MOCK_INVALID=1 run_games; then fail "an invalid ESPN response should fail the source"; fi
if find "$HOME/.cache/espn-games-months" -name '*.ok' -type f 2>/dev/null | grep -q .; then
  fail "an invalid response wrote a monthly cache .ok"
fi
pass "invalid response does not poison the cache"

run_games || fail "a valid response after an invalid one should succeed"
assert_match "cache recovers after an invalid response" "LYON"
pass "cache recovers after an invalid response"

# --- transient failures: 429, 5xx, offline, truncated JSON -----------------
export TEST_FAVSTR="LYON"
export TEST_FAVLG="fra.1"
for mode in 429 500 offline trunc; do
  rm -rf "$HOME/.cache/espn-games.json" "$HOME/.cache/espn-games.json.meta" \
    "$HOME/.cache/espn-games.sig" "$HOME/.cache/espn-games-months"
  export MOCK_MODE="$mode"
  if run_games; then fail "MOCK_MODE=$mode should fail"; fi
  if find "$HOME/.cache/espn-games-months" -name '*.ok' 2>/dev/null | grep -q .; then
    fail "MOCK_MODE=$mode wrote a monthly .ok"
  fi
done
unset MOCK_MODE
pass "429/5xx/offline/truncated do not poison the cache"

run_games || fail "recovery after transient failures"
assert_match "recovery after transient failures" "LYON"
rm -rf "$HOME/.cache/espn-games-months"
export MOCK_MODE=offline
run_games || fail "offline should fall back to a valid cache"
assert_match "offline serves the cache" "LYON"
unset MOCK_MODE
pass "offline serves the cache"

# --- SIG must change when the league list changes ---------------------------
export TEST_FAVSTR="LYON"
export TEST_FAVLG="fra.1"
run_games || fail "fra.1 run"
SIG1=$(cat "$HOME/.cache/espn-games.sig")
export TEST_FAVLG="eng.1"
run_games || fail "eng.1 run"
SIG2=$(cat "$HOME/.cache/espn-games.sig")
[ "$SIG1" != "$SIG2" ] || fail "SIG must change with WANTLG"
pass "SIG changes with WANTLG"

# --- sh() quoting: a quote in the value must not run code -------------------
PWN="$TMP/pwned"
export TEST_FAVSTR="LYON'; touch $PWN; echo '"
export TEST_FAVLG=""
run_games || true
[ ! -e "$PWN" ] || fail "sh() quoting allowed code execution"
pass "sh() quoting blocks injection"

# --- live gate: no live match, no network call ------------------------------
if [ -n "$LIVE" ]; then
  mkdir -p "$HOME/.cache"
  printf '[]' >"$HOME/.cache/espn-live-index.json"
  rm -f "$HOME/.cache/espn-live.json"
  : >"$MOCK_LOG"
  bash "$LIVE" >"$TMP/live.out" 2>"$TMP/live.err" || fail "live source should exit 0 with no live match"
  if grep -q 'site.api.espn.com' "$MOCK_LOG"; then fail "live source made a network call with no live match"; fi
  jq -e '(.items // []) | length == 0' "$TMP/live.out" >/dev/null 2>&1 || fail "live output should be empty"
  pass "live gate makes no call when no match is live"
fi

printf 'ALL TESTS PASSED\n'
