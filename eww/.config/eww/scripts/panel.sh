#!/bin/sh
# Power panel helper. Detaches first: eww kills onclick commands after 200ms.
#   panel.sh           toggle the panel
#   panel.sh close     close it (no-op if already closed)
#   panel.sh <action>  close it, then run poweroff|reboot|lock|suspend|logout
if [ -z "$PANEL_DETACHED" ]; then
    PANEL_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

close() {
    [ "$(eww get panel_open)" = "true" ] || return 0
    eww update panel_open=false
    sleep 0.3
    eww close panel
}

case "$1" in
    "")       if [ "$(eww get panel_open)" = "true" ]; then close
              else eww open panel && eww update panel_open=true; fi ;;
    close)    close ;;
    poweroff) close; systemctl poweroff ;;
    reboot)   close; systemctl reboot ;;
    suspend)  close; systemctl suspend ;;
    lock)     close; pidof hyprlock >/dev/null || hyprlock ;;
    logout)   close; hyprctl dispatch 'hl.dsp.exit()' ;;
esac
