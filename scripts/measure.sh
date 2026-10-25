#!/usr/bin/env bash
# Mesures Omalauncher / my-match. Usage:
#   ./scripts/measure.sh before
#   ./scripts/measure.sh before --screen-off
#   ./scripts/measure.sh after  --screen-off --battery
# Ne modifie aucun réglage. Écran allumé sauf --screen-off.
set -euo pipefail
PKG=${PKG:-dev.omalauncher}
PHASE=${1:-before}
shift || true
SCREEN_OFF=0
BATTERY=0
for a in "$@"; do
  case "$a" in
    --screen-off) SCREEN_OFF=1 ;;
    --battery) BATTERY=1 ;;
    *) echo "option inconnue: $a" >&2; exit 2 ;;
  esac
done
if ! adb get-state >/dev/null 2>&1; then
  echo "ADB: aucun appareil. Rebrancher/déverrouiller/autoriser le débogage USB." >&2
  exit 1
fi
OUT="measurements/$PHASE/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
say() { printf '\n=== %s ===\n' "$*"; }
run() { local name=$1; shift; say "$name"; adb shell "$@" >"$OUT/$name.txt" 2>&1 || true; }

say "sortie: $OUT"
run device getprop
run battery dumpsys battery
run package dumpsys package "$PKG"
run display dumpsys display
run power dumpsys power
run deviceidle dumpsys deviceidle whitelist
run services dumpsys activity services "$PKG"
run media dumpsys media_session
run meminfo dumpsys meminfo "$PKG"
run netstats dumpsys netstats detail
run ps ps -A -o PID,PPID,USER,VSZ,RSS,NAME
run top top -b -n 2 -d 5 -o PID,PPID,USER,NAME,%CPU
run settings_refresh settings get system peak_refresh_rate
run settings_stay_awake settings get global stay_on_while_plugged_in
run settings_timeout settings get system screen_off_timeout
run guest_procs sh -c "ps -A -o PID,PPID,NAME | grep -E 'bash|opencode|libproot|proot|curl|jq|espn' || true"
run orphans sh -c "for d in /proc/[0-9]*; do p=\${d#/proc/}; [ \"\$p\" = 1 ] && continue; ppid=\$(awk '{print \$4}' \$d/stat 2>/dev/null); [ \"\$ppid\" = 1 ] && echo \"\$p \$(cat \$d/comm 2>/dev/null)\"; done || true"

say "gfxinfo (reset, 30 s au repos, dump)"
adb shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1 || true
sleep 30
adb shell dumpsys gfxinfo "$PKG" >"$OUT/gfxinfo.txt" 2>&1 || true

say "CPU par PID sur 10 s (deltas /proc/<pid>/stat)"
adb shell 'for d in /proc/[0-9]*; do p=${d#/proc/}; [ -r "$d/stat" ] || continue; s=$(cat "$d/stat" 2>/dev/null) || continue; echo "$p $s"; done' >"$OUT/proc_t0.txt" 2>&1 || true
sleep 10
adb shell 'for d in /proc/[0-9]*; do p=${d#/proc/}; [ -r "$d/stat" ] || continue; s=$(cat "$d/stat" 2>/dev/null) || continue; echo "$p $s"; done' >"$OUT/proc_t1.txt" 2>&1 || true

if [ "$BATTERY" = 1 ]; then
  say "batterystats --charged"
  adb shell dumpsys batterystats --charged "$PKG" >"$OUT/batterystats.txt" 2>&1 || true
fi

if [ "$SCREEN_OFF" = 1 ]; then
  say "écran éteint 60 s"
  adb shell input keyevent 26 >/dev/null 2>&1 || true
  sleep 2
  adb shell 'for d in /proc/[0-9]*; do p=${d#/proc/}; [ -r "$d/stat" ] || continue; s=$(cat "$d/stat" 2>/dev/null) || continue; echo "$p $s"; done' >"$OUT/proc_off_t0.txt" 2>&1 || true
  sleep 60
  adb shell 'for d in /proc/[0-9]*; do p=${d#/proc/}; [ -r "$d/stat" ] || continue; s=$(cat "$d/stat" 2>/dev/null) || continue; echo "$p $s"; done' >"$OUT/proc_off_t1.txt" 2>&1 || true
  adb shell dumpsys power >"$OUT/power_screen_off.txt" 2>&1 || true
  adb shell input keyevent 224 >/dev/null 2>&1 || true
fi

say "terminé: $OUT"
