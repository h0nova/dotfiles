#!/usr/bin/env bash
# Rotates windows around in a circle (right -> bottom -> left -> top -> right)
# instead of dwindle's default togglesplit which just flips back and forth
# between two states. Achieved by alternating togglesplit and togglesplit+swapsplit.

STATE_FILE="/tmp/.hypr_rotate_split_state"
state=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

hyprctl dispatch layoutmsg togglesplit

if [ "$state" = "1" ]; then
    hyprctl dispatch layoutmsg swapsplit
    echo 0 > "$STATE_FILE"
else
    echo 1 > "$STATE_FILE"
fi
