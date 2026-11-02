#!/bin/sh
NODE=$(command -v node 2>/dev/null)
if [ -z "$NODE" ]; then
  for n in "$HOME/.local/share/mise/installs/node/lts/bin/node" "$HOME/.local/share/mise/installs/node/current/bin/node"; do
    if [ -x "$n" ]; then NODE="$n"; break; fi
  done
fi
[ -x "$NODE" ] || exit 0
exec "$NODE" "$HOME/.config/omalauncher/widgets/fd-analysis.js"
