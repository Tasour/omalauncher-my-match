#!/system/bin/sh
# Mesure embarquée : écrit dans /sdcard/omalauncher-measure, indépendante du lien USB.
OUT=/sdcard/omalauncher-measure
PKG=dev.omalauncher
rm -rf "$OUT"
mkdir -p "$OUT"
STAY=$(settings get global stay_on_while_plugged_in 2>/dev/null)
settings put global stay_on_while_plugged_in 7 2>/dev/null
svc power stayon true 2>/dev/null
{
  echo "date=$(date)"
  getprop
  echo "--- battery ---"; dumpsys battery
  echo "--- power ---"; dumpsys power
  echo "--- display ---"; dumpsys display
  echo "--- whitelist ---"; dumpsys deviceidle whitelist
  echo "--- services ---"; dumpsys activity services "$PKG"
  echo "--- meminfo ---"; dumpsys meminfo "$PKG"
  echo "--- netstats ---"; dumpsys netstats detail
  echo "--- ps ---"; ps -A -o PID,PPID,USER,NAME
  echo "--- settings ---"
  settings get system peak_refresh_rate
  settings get global stay_on_while_plugged_in
  settings get system screen_off_timeout
} > "$OUT/static.txt" 2>&1
sample() {
  for d in /proc/[0-9]*; do
    p=${d#/proc/}
    c=$(cat "$d/comm" 2>/dev/null) || continue
    case "$c" in
      bash|libproot.so|curl|jq|perl|proot|libproot-loader.so)
        echo "=== $p $c ==="
        tr '\0' ' ' < "$d/cmdline" 2>/dev/null
        echo
        awk '{print "utime="$14" stime="$15}' "$d/stat" 2>/dev/null
        ;;
    esac
  done
}
sample > "$OUT/guest_t0.txt" 2>&1
for d in /proc/[0-9]*; do p=${d#/proc/}; [ -r "$d/stat" ] || continue; echo "$p $(cat "$d/stat" 2>/dev/null)"; done > "$OUT/proc_t0.txt" 2>&1
dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1
sleep 30
for d in /proc/[0-9]*; do p=${d#/proc/}; [ -r "$d/stat" ] || continue; echo "$p $(cat "$d/stat" 2>/dev/null)"; done > "$OUT/proc_t1.txt" 2>&1
sample > "$OUT/guest_t1.txt" 2>&1
dumpsys gfxinfo "$PKG" > "$OUT/gfxinfo.txt" 2>&1
uiautomator dump "$OUT/ui.xml" >/dev/null 2>&1 || true
settings put global stay_on_while_plugged_in "$STAY" 2>/dev/null
svc power stayon false 2>/dev/null
echo done > "$OUT/DONE"
