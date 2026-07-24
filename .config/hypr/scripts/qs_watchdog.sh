#!/usr/bin/env bash
# Keeps all 4 Quickshell components alive.
# exec-once only fires once at boot, so if Quickshell loses the race
# against the rest of the autostart apps (waybar, polkit, keyring,
# matugen/wallpaper init, dunst stop, etc.) it never gets another
# chance to start. This loop retries forever, both fixing that boot
# race and auto-recovering from any later crash.

MAIN_QML="$HOME/.config/hypr/scripts/quickshell/Main.qml"
ISLAND_QML="$HOME/.config/hypr/scripts/quickshell/DynamicIsland.qml"
LAUNCHER_QML="$HOME/.config/hypr/scripts/quickshell/AppLauncher.qml"
CLIPBOARD_QML="$HOME/.config/hypr/scripts/quickshell/ClipboardViewer.qml"

# Right after boot, check often so a lost race gets retried within
# seconds rather than waiting out the full steady-state interval.
BOOT_CHECKS=20
BOOT_INTERVAL=1
STEADY_INTERVAL=5

check_and_launch() {
    pgrep -f "quickshell.*Main\.qml"          >/dev/null || { quickshell -p "$MAIN_QML"      >/dev/null 2>&1 & disown; }
    pgrep -f "quickshell.*DynamicIsland\.qml" >/dev/null || { quickshell -p "$ISLAND_QML"    >/dev/null 2>&1 & disown; }
    pgrep -f "quickshell.*AppLauncher\.qml"   >/dev/null || { quickshell -p "$LAUNCHER_QML"  >/dev/null 2>&1 & disown; }
    pgrep -f "quickshell.*ClipboardViewer\.qml" >/dev/null || { quickshell -p "$CLIPBOARD_QML" >/dev/null 2>&1 & disown; }
}

for _ in $(seq 1 "$BOOT_CHECKS"); do
    check_and_launch
    sleep "$BOOT_INTERVAL"
done

while true; do
    check_and_launch
    sleep "$STEADY_INTERVAL"
done
