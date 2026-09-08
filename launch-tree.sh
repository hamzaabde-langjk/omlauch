#!/usr/bin/env bash
# rescan at most every 30 min (icon lookup is the slow part); delete apps.js to force
cache="$HOME/.config/quickshell/tree/apps.js"
if [ ! -s "$cache" ] || [ "$(( $(date +%s) - $(stat -c %Y "$cache") ))" -gt 1800 ]; then
  bash "$HOME/.config/quickshell/tree/list-apps.sh"
fi
exec quickshell -c "$HOME/.config/quickshell/tree"
