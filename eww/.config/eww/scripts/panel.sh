#!/bin/sh
# Power panel helper. Detaches first: eww kills onclick commands after 200ms.
#   panel.sh toggle N  toggle the panel on monitor N
#   panel.sh close     close it (no-op if already closed)
#   panel.sh <action>  close it, then run poweroff|reboot|lock|suspend|logout
if [ -z "$PANEL_DETACHED" ]; then
    PANEL_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

open() {
    ~/.config/eww/scripts/net.sh close   # one panel at a time
    eww open panel --screen "${1:-0}" && eww update panel_open=true
    # sections fade in one after another
    for n in 1 2 3 4; do sleep 0.08; eww update panel_stage=$n; done
}

close() {
    [ "$(eww get panel_open)" = "true" ] || return 0
    eww update panel_stage=0 panel_open=false
    eww close panel   # hyprland animates the slide out
}

case "$1" in
    toggle)   if [ "$(eww get panel_open)" = "true" ]; then close
              else open "$2"; fi ;;
    close)    close ;;
    poweroff) close; systemctl poweroff ;;
    reboot)   close; systemctl reboot ;;
    suspend)  close; systemctl suspend ;;
    lock)     close; pidof hyprlock >/dev/null || hyprlock ;;
    logout)   close; hyprctl dispatch 'hl.dsp.exit()' ;;
esac
