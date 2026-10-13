#!/bin/sh
# Power panel helper. Detaches first: eww kills onclick commands after 200ms.
#   panel.sh toggle N  toggle the panel on monitor N
#   panel.sh close     close it (no-op if already closed)
#   panel.sh arm A     arm action A, enter confirms
#   panel.sh ask A     open panel with A armed
#   panel.sh confirm   run armed action
#   panel.sh disarm    cancel it
#   panel.sh <action>  close it, then run poweroff|reboot|lock|suspend|logout
if [ -z "$PANEL_DETACHED" ]; then
    PANEL_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

open() {
    ~/.config/eww/scripts/tray.sh close
    ~/.config/eww/scripts/net.sh close   # one panel at a time
    ~/.config/eww/scripts/start.sh close
    ~/.config/eww/scripts/notes.sh close
    # everything is shown before the window maps: no staged reveal, so the
    # sliders are usable right away and the layer doesn't resize while sliding in
    eww update panel_stage=4 panel_open=true
    eww open panel --screen "${1:-$(hyprctl activeworkspace -j | jq .monitorID)}"
}

# Power Confirm:
arm() {
    if [ "$(eww get power_arm)" = "$1" ]; then disarm; return; fi
    eww update power_arm="$1"
    hyprctl dispatch 'hl.dsp.submap("power-confirm")' >/dev/null
    sleep 5
    [ "$(eww get power_arm)" = "$1" ] && disarm
}

disarm() {
    [ -n "$(eww get power_arm)" ] || return 0
    eww update power_arm=""
    hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
}

close() {
    disarm
    [ "$(eww get panel_open)" = "true" ] || return 0
    eww update panel_stage=0 panel_open=false
    eww close panel   # hyprland animates the slide out
}

case "$1" in
    toggle)   if [ "$(eww get panel_open)" = "true" ]; then close
              else open "$2"; fi ;;
    close)    close ;;
    arm)      arm "$2" ;;
    ask)      [ "$(eww get panel_open)" = "true" ] || open "$(hyprctl monitors -j | jq '.[] | select(.focused) | .id')"
              arm "$2" ;;
    disarm)   disarm ;;
    confirm)  a=$(eww get power_arm)
              [ -n "$a" ] && exec "$0" "$a" ;;
    poweroff) close; systemctl poweroff ;;
    reboot)   close; systemctl reboot ;;
    suspend)  close; systemctl suspend ;;
    lock)     close; pidof hyprlock >/dev/null || hyprlock ;;
    logout)   close; command -v hyprshutdown >/dev/null && exec hyprshutdown
              hyprctl dispatch 'hl.dsp.exit()' ;;
esac
