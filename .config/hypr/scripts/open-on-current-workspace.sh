#!/usr/bin/env bash
# Launches $@ pinned to whatever workspace is active right now.
# Kills any existing instance first: pavucontrol (and similar GTK apps)
# can be single-instance and just re-present their old window instead
# of opening fresh, leaving it stuck on whatever workspace it was on
# before — this guarantees a brand-new window on the current workspace.

bin="$1"
shift

pkill -x "$bin" 2>/dev/null
# give the old instance a moment to actually release before relaunching
for _ in 1 2 3 4 5; do
    pgrep -x "$bin" >/dev/null || break
    sleep 0.1
done

ws="$(hyprctl activeworkspace -j | jq -r '.id')"
exec hyprctl dispatch exec "[workspace $ws] $bin $*"
