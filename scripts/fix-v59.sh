#!/bin/sh
# Install my-match v5.9 on the phone and clear the poisoned v5.8 games cache.
set -u

LOCK=/tmp/my-match-fix.lock
[ -e "$LOCK" ] && { echo "already running"; exit 0; }
touch "$LOCK"
trap 'rm -f "$LOCK"' EXIT INT TERM

BASE="${OMA_BASE:-}"
if [ -z "$BASE" ] && [ -r "$HOME/.config/omalauncher/measure-base" ]; then
  BASE=$(head -n 1 "$HOME/.config/omalauncher/measure-base" 2>/dev/null | tr -d '\r')
fi
printf '%s' "$BASE" | grep -Eq '^https?://[A-Za-z0-9._:-]+$' || BASE="http://127.0.0.1:1764"
GH="https://raw.githubusercontent.com/Tasour/omalauncher-my-match/main"
DIR="$HOME/.config/omalauncher/widgets"

cd "$DIR" || { echo "no widgets dir"; exit 1; }
f=$(grep -l 'My Matches' *.owl 2>/dev/null | head -1)
f=${f:-shared-my-matches-football.owl}
echo "target=$f"

if ! curl -fsSL --connect-timeout 10 --url "$BASE/widget/my-match.optimized.owl" -o /tmp/my-match.v59.owl; then
  curl -fsSL --connect-timeout 20 "$GH/widget/my-match.optimized.owl" -o /tmp/my-match.v59.owl || exit 1
fi
grep -q 'version:"5.9.1"' /tmp/my-match.v59.owl || { echo "bad download"; exit 1; }

cp /tmp/my-match.v59.owl .my-match.new && mv .my-match.new "$f"
# The v5.8 monthly cache is poisoned by empty .ok entries; v5.9 also changes SIG.
rm -rf ~/.cache/espn-games-months ~/.cache/espn-games.json ~/.cache/espn-games.sig
rm -f ~/.cache/espn-live.json ~/.cache/espn-live-index.json

echo "installed $(grep -o 'version:"[^"]*"' "$f" | head -1)"
sleep 20
{
  echo "target=$f"
  grep -o 'version:"[^"]*"' "$f" | head -1
  date
  if command -v owl-check >/dev/null 2>&1; then
    owl-check "$f" 2>&1 | head -40
  else
    echo "owl-check missing"
  fi
} >/tmp/my-match-fix.txt
curl -fsSL --connect-timeout 10 -X POST --data-binary @/tmp/my-match-fix.txt --url "$BASE/measure" -o /tmp/my-match-fix.out || true
echo done
