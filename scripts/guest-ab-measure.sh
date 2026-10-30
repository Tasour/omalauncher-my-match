#!/bin/sh
# Runs inside Omalauncher's guest terminal. Measures v5.7 then v5.8, 30 s each,
# and posts the raw samples to the PC. Launch it in the background, then go home.
set -u

LOCK=/tmp/ab-measure.lock
[ -e "$LOCK" ] && { echo "already running"; exit 0; }
touch "$LOCK"

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
cp "$f" /tmp/my-match.current.owl 2>/dev/null || true

fetch() { curl -fsSL --connect-timeout 5 --url "$1" -o "$2"; }
fetch "$BASE/widget/my-match.owl" /tmp/my-match.v57.owl ||
  fetch "$GH/widget/my-match.owl" /tmp/my-match.v57.owl ||
  { echo "v57 download failed"; exit 1; }
fetch "$BASE/widget/my-match.optimized.owl" /tmp/my-match.v58.owl ||
  fetch "$GH/widget/my-match.optimized.owl" /tmp/my-match.v58.owl ||
  { echo "v58 download failed"; exit 1; }
grep -q 'version:"5.7"' /tmp/my-match.v57.owl || { echo "v57 bad"; exit 1; }
grep -q 'version:"5.8"' /tmp/my-match.v58.owl || { echo "v58 bad"; exit 1; }
trap 'install /tmp/my-match.v58.owl 2>/dev/null || true; rm -f "$LOCK"' EXIT INT TERM

net() { awk '/wlan0:|rmnet_data0:/ {print}' /proc/net/dev; }
sample() {
  ps -eo pid,ppid,user,comm,args |
    awk -v me="$$" '$3 ~ /u0_a446|10446/ && $1 != me && $0 !~ /guest-ab-measure|ab-measure|ab\.sh|sleep 0\.5/ {print}' |
    cut -c1-300
}
install() { cp "$1" .my-match.new && mv .my-match.new "$f"; }
cleanup_widget() { pkill -f 'WANT=' 2>/dev/null || true; sleep 2; }

measure() {
  label="$1"
  out="/tmp/measure-$label.txt"
  {
    echo "=== $label ==="
    date
    echo "--- version ---"
    grep -o 'version:"[^"]*"' "$f" | head -1
    echo "--- loadavg ---"
    cat /proc/loadavg
    echo "--- net0 ---"
    net
    echo "--- ps0 ---"
    sample
    i=0
    while [ "$i" -lt 60 ]; do
      echo "--- sample $i ---"
      sample
      i=$((i + 1))
      sleep 0.5
    done
    echo "--- net1 ---"
    net
    echo "--- ps1 ---"
    sample
    echo "--- end ---"
  } >"$out" 2>&1
  echo "measured $label -> $out"
}

echo "prepare: laisse le terminal et reviens a l'ecran d'accueil"
sleep 8
cleanup_widget
install /tmp/my-match.v57.owl
sleep 6
measure before
cleanup_widget
install /tmp/my-match.v58.owl
sleep 6
measure after
install /tmp/my-match.v58.owl
cat /tmp/measure-before.txt /tmp/measure-after.txt >/tmp/ab-measure.txt
if curl -fsSL --connect-timeout 10 -X POST --data-binary @/tmp/ab-measure.txt --url "$BASE/measure" -o /tmp/ab-post.out; then
  echo "POST OK: $(cat /tmp/ab-post.out)"
else
  echo "POST FAILED"
fi
echo "done"
