#!/usr/bin/env bash
# Warns when the wallpaper set via `awww img` no longer matches the wallpaper
# the current color theme (colors.conf, waybar, kitty, etc.) was generated
# from — e.g. after switching wallpaper directly instead of via apply-theme.sh.

INTERVAL=30
THEME_STATE="$HOME/.cache/theme_wallpaper_state"
NOTIFIED_CACHE="$HOME/.cache/theme_sync_notified"

while true; do
    CURRENT=$(awww query 2>/dev/null | grep -oP 'image: \K\S+' | head -n1)

    if [[ -n "$CURRENT" && -f "$THEME_STATE" ]]; then
        THEMED=$(cat "$THEME_STATE")
        CURRENT_REAL=$(realpath "$CURRENT" 2>/dev/null)

        if [[ -n "$CURRENT_REAL" && "$CURRENT_REAL" != "$THEMED" ]]; then
            # Only notify once per mismatched wallpaper, not every 30s
            if [[ ! -f "$NOTIFIED_CACHE" ]] || [[ "$(cat "$NOTIFIED_CACHE")" != "$CURRENT_REAL" ]]; then
                notify-send -t 15000 -a 'Theme' -u normal 'Тема не синхронізована' \
                    "Шпалера змінена на $(basename "$CURRENT_REAL"), але кольори згенеровані з $(basename "$THEMED"). Запусти apply-theme.sh."
                echo "$CURRENT_REAL" > "$NOTIFIED_CACHE"
            fi
        else
            # Back in sync — clear so a future mismatch notifies again
            rm -f "$NOTIFIED_CACHE"
        fi
    fi

    sleep "$INTERVAL"
done
