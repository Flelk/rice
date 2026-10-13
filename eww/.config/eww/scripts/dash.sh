#!/bin/sh
# Dashboard helper (SUPER + TAB). Detaches first: eww kills onclick commands after 200ms.
#   dash.sh toggle      toggle the dashboard on the focused monitor
#   dash.sh close       close it (no-op if already closed)
#   dash.sh open PATH   close, then open PATH in the file manager
#   dash.sh sky         fade the tiles out, open the stargazing view over them (sky.py)
#   dash.sh back        close the stargazing view, tiles fade back in
#   dash.sh esc         back from stargazing, else close
# While it's open the "dash" submap is on: ESC / SUPER + TAB close it.
if [ -z "$DASH_DETACHED" ]; then
    DASH_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

open() {
    ~/.config/eww/scripts/tray.sh close
    ~/.config/eww/scripts/panel.sh close   # one panel at a time
    ~/.config/eww/scripts/net.sh close
    ~/.config/eww/scripts/start.sh close
    ~/.config/eww/scripts/notes.sh close
    eww update dash_open=true
    eww open dash --screen "$(hyprctl activeworkspace -j | jq .monitorID)"
    hyprctl dispatch 'hl.dsp.submap("dash")' >/dev/null
    # tiles fade in one column after another
    stages
}

stages() {
    for n in 1 2 3 4; do sleep 0.06; eww update dash_stage=$n; done
}

# Stargazing Window: sky.py writes its pid here
SKY_PID="${XDG_RUNTIME_DIR:-/tmp}/eww-sky.pid"
sky_open() {
    [ -s "$SKY_PID" ] && kill -0 "$(cat "$SKY_PID")" 2>/dev/null
}
sky_close() {
    sky_open && kill "$(cat "$SKY_PID")"
    rm -f "$SKY_PID"
}

close() {
    # always leave the submap, even if eww lost track of the window
    hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
    sky_close
    [ "$(eww get dash_open)" = "true" ] || return 0
    eww update dash_stage=0 dash_open=false
    eww close dash   # hyprland fades it out
}

case "$1" in
    toggle) if [ "$(eww get dash_open)" = "true" ]; then close
            else open; fi ;;
    close)  close ;;
    open)   close; thunar "$2" ;;
    sky)    sky_open && exit 0
            eww update dash_stage=0
            exec ~/.config/eww/scripts/sky.py "$(hyprctl activeworkspace -j | jq .monitorID)" ;;
    back)   sky_close
            [ "$(eww get dash_open)" = "true" ] && stages ;;
    esc)    if sky_open; then "$0" back; else close; fi ;;
esac
