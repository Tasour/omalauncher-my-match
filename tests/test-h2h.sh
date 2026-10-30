#!/usr/bin/env bash
# N07: the hero summary script extracts the head-to-head form for the home team.
set -euo pipefail

HERO="${1:?usage: test-h2h.sh heroOddsScript.sh bannerScript.sh}"
BANNER="${2:?usage: test-h2h.sh heroOddsScript.sh bannerScript.sh}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME/.cache"
export FIXTURES="$ROOT/tests/fixtures"
export PATH="$ROOT/tests/bin:$PATH"
export TEST_HERO_LG="fra.2"
export TEST_HERO_ID="fra.2:401876708"
export TEST_HERO_AT="$(( $(date +%s) + 86400 ))"
export TEST_HERO_ST="pre"
export TEST_HERO_HID="6994"
export TEST_HERO_HABBR="GRE"
export TEST_HERO_HL="soccer-500-167.png"
export TEST_HERO_AL="soccer-500-168.png"
export MOCK_LOGO=1

pass() { printf 'PASS %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  tail -8 "$TMP/err" 2>/dev/null || true
  exit 1
}

bash "$HERO" >"$TMP/out.json" 2>"$TMP/err" || fail "hero summary script failed"
jq -e '.hv == 1 and .h2h != null' "$TMP/out.json" >/dev/null 2>&1 ||
  fail "no head-to-head object"
jq -e '.h2h.n == 5 and .h2h.w == 3 and .h2h.d == 1 and .h2h.l == 1' "$TMP/out.json" >/dev/null 2>&1 ||
  fail "wrong head-to-head form (expected 3W 1D 1L over 5)"
jq -e '.h2h.last.hs == "2" and .h2h.last.as == "1" and .h2h.last.won == true' "$TMP/out.json" >/dev/null 2>&1 ||
  fail "wrong last head-to-head result (expected 2-1 win)"
bash "$BANNER" >/dev/null 2>"$TMP/banner.err" || fail "banner logo source failed"
[ -s "$HOME/.cache/espn-logos/banner/soccer-500-167.png" ] ||
  fail "home banner logo was not downloaded"
[ -s "$HOME/.cache/espn-logos/banner/soccer-500-168.png" ] ||
  fail "away banner logo was not downloaded"
pass "banner logos are cached at high resolution"

jq -e '.sv == 3 and .info.venue == "Stade des Alpes" and (.stats|length) == 2 and (.events|length) == 3 and (.lineups|length) == 2 and (.news|length) == 1' "$TMP/out.json" >/dev/null 2>&1 ||
  fail "match centre fields are incomplete"
jq -e '.odds.ho != null and .odds.h != null and (.h2h.list|length) == 5 and .h2h.list[0].d != ""' "$TMP/out.json" >/dev/null 2>&1 ||
  fail "odds movement or H2H list is incomplete"
pass "head-to-head form is 3W 1D 1L over 5"

printf 'ALL H2H TESTS PASSED\n'
