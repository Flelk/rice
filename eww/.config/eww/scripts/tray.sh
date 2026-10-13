#!/bin/sh
# Tray Dropdown: toggle [N] | close
if [ -z "$TRAY_DETACHED" ]; then
    TRAY_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

open() {
    ~/.config/eww/scripts/panel.sh close
    ~/.config/eww/scripts/net.sh close
    ~/.config/eww/scripts/start.sh close
    ~/.config/eww/scripts/notes.sh close
    eww update tray_open=true
    eww open tray --screen "${1:-$(hyprctl activeworkspace -j | jq .monitorID)}"
}

close() {
    [ "$(eww get tray_open)" = "true" ] || return 0
    eww update tray_open=false
    eww close tray
}

case "$1" in
    toggle) if [ "$(eww get tray_open)" = "true" ]; then close
            else open "$2"; fi ;;
    close)  close ;;
esac
