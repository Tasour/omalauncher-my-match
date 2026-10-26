#!/bin/sh
# Exact A/B: wrap curl and jq, count every call over a 90 s startup + 120 s steady window.
set -u

LOCK=/tmp/ab-wrapper.lock
[ -e "$LOCK" ] && { echo "already running"; exit 0; }
touch "$LOCK"

BASE="http://192.168.0.119:1764"
GH="https://raw.githubusercontent.com/Tasour/omalauncher-my-match/main"
DIR="$HOME/.config/omalauncher/widgets"

cd "$DIR" || { echo "no widgets dir"; exit 1; }
f=$(grep -l 'My Matches' *.owl 2>/dev/null | head -1)
f=${f:-shared-my-matches-football.owl}
echo "target=$f"

install() { cp "$1" .my-match.new && mv .my-match.new "$f"; }
fetch() { curl -fsSL --connect-timeout 5 "$1" -o "$2"; }
fetch "$BASE/widget/my-match.owl" /tmp/my-match.v57.owl ||
  fetch "$GH/widget/my-match.owl" /tmp/my-match.v57.owl ||
  { echo "v57 download failed"; exit 1; }
fetch "$BASE/widget/my-match.optimized.owl" /tmp/my-match.v58.owl ||
  fetch "$GH/widget/my-match.optimized.owl" /tmp/my-match.v58.owl ||
  { echo "v58 download failed"; exit 1; }
grep -q 'version:"5.7"' /tmp/my-match.v57.owl || { echo "v57 bad"; exit 1; }
grep -q 'version:"5.8"' /tmp/my-match.v58.owl || { echo "v58 bad"; exit 1; }

install_wrappers() {
  cat >/usr/local/bin/curl <<'EOS'
#!/bin/sh
echo "$(date +%s) curl $*" >> /tmp/curl-calls.log
exec /usr/bin/curl "$@"
EOS
  cat >/usr/local/bin/jq <<'EOS'
#!/bin/sh
echo "$(date +%s) jq $*" >> /tmp/jq-calls.log
exec /usr/bin/jq "$@"
EOS
  chmod +x /usr/local/bin/curl /usr/local/bin/jq
}
remove_wrappers() { rm -f /usr/local/bin/curl /usr/local/bin/jq; }
install_wrappers
trap 'remove_wrappers; install /tmp/my-match.v58.owl 2>/dev/null || true; rm -f "$LOCK"' EXIT INT TERM

run_phase() {
  label="$1"
  file="$2"
  install "$file"
  : >/tmp/curl-calls.log
  : >/tmp/jq-calls.log
  echo "initial $label $(date +%s)" >/tmp/phase-$label.txt
  sleep 90
  echo "steady_start $label $(date +%s)" >>/tmp/phase-$label.txt
  sleep 120
  echo "steady_end $label $(date +%s)" >>/tmp/phase-$label.txt
  cp /tmp/curl-calls.log /tmp/curl-$label.log
  cp /tmp/jq-calls.log /tmp/jq-$label.log
  echo "calls $label: curl=$(wc -l </tmp/curl-$label.log) jq=$(wc -l </tmp/jq-$label.log)" >>/tmp/phase-$label.txt
}

run_phase v57 /tmp/my-match.v57.owl
run_phase v58 /tmp/my-match.v58.owl
install /tmp/my-match.v58.owl

cat /tmp/phase-v57.txt /tmp/phase-v58.txt /tmp/curl-v57.log /tmp/curl-v58.log /tmp/jq-v57.log /tmp/jq-v58.log >/tmp/ab-wrapper.txt
if curl -fsSL --connect-timeout 10 -X POST --data-binary @/tmp/ab-wrapper.txt "$BASE/measure" -o /tmp/ab-wrapper.out; then
  echo "POST OK"
else
  echo "POST FAILED"
fi
echo "done"
