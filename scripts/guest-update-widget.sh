#!/system/bin/sh
# À lancer dans le terminal invité d'Omalauncher (pas sur le PC).
# Remplace le widget partagé par la version optimisée, sans ADB.
set -u
DIR="$HOME/.config/omalauncher/widgets"
cd "$DIR" || { echo "no widgets dir"; exit 1; }
command -v perl >/dev/null 2>&1 || pacman -S --noconfirm perl
f=$(grep -l 'My Matches' *.owl 2>/dev/null | head -1)
f=${f:-shared-my-matches-football.owl}
echo "target=$f"
URL1="https://raw.githubusercontent.com/Tasour/omalauncher-my-match/main/widget/my-match.optimized.owl"
BASE="${OMA_BASE:-}"
[ -n "$BASE" ] || BASE=$(cat "$HOME/.config/omalauncher/measure-base" 2>/dev/null)
BASE="${BASE:-http://127.0.0.1:1764}"
URL2="$BASE/my-match.optimized.owl"
if ! curl -fsSL --connect-timeout 10 "$URL1" -o .my-match.new; then
  echo "GitHub failed, trying local server..."
  curl -fsSL --connect-timeout 10 "$URL2" -o .my-match.new || true
fi
if [ -s .my-match.new ] && grep -q 'widget"' .my-match.new; then
  mv .my-match.new "$f"
  echo UPDATED
  grep -o 'version:"[^"]*"' "$f" | head -1
  command -v owl-check >/dev/null 2>&1 && owl-check "$f" | head -20
else
  echo "DOWNLOAD FAILED"
  rm -f .my-match.new
fi
