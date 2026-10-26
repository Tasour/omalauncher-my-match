#!/usr/bin/env bash
# Pousse et lance la mesure embarquée, puis récupère /sdcard/omalauncher-measure.
set -euo pipefail
OUT="measurements/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
echo "attente ADB..."
pushed=0
for i in $(seq 1 120); do
  if adb devices 2>/dev/null | grep -q $'\tdevice'; then
    if adb push scripts/measure-device.sh /sdcard/measure-device.sh >/dev/null 2>&1; then pushed=1; break; fi
  fi
  sleep 1
done
[ "$pushed" = 1 ] || { echo "ADB: push impossible"; exit 1; }
echo "lancement de la mesure (30 s)..."
adb shell 'nohup sh /sdcard/measure-device.sh >/sdcard/omalauncher-measure-log.txt 2>&1 &' >/dev/null 2>&1 || true
for i in $(seq 1 90); do
  sleep 2
  if adb shell '[ -f /sdcard/omalauncher-measure/DONE ]' >/dev/null 2>&1; then break; fi
done
for i in $(seq 1 30); do
  if adb pull /sdcard/omalauncher-measure "$OUT" >/dev/null 2>&1; then break; fi
  sleep 2
done
echo "mesure récupérée: $OUT"
ls -la "$OUT"
