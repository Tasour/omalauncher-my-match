#!/usr/bin/env bash
# Ouvre un lien de partage dans Omalauncher sur le téléphone (ADB).
# Usage: ./scripts/open-share-link.sh "$(./scripts/encode-share-link.py widget/my-match.owl)"
set -euo pipefail
LINK=${1:?usage: $0 '<share link>'}
adb get-state >/dev/null 2>&1 || { echo "ADB indisponible" >&2; exit 1; }
adb shell am start -n dev.omalauncher/.MainActivity -a android.intent.action.VIEW -d "$LINK"
