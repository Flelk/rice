#!/bin/bash
# Joke Screensaver: start [horror] | stop (omarchy style, special workspace per monitor)
dir=$(dirname "$(readlink -f "$0")")

case "$1" in
    start)
        pidof hyprlock >/dev/null && exit 0
        pgrep -f "^kitty --class=screensaver" >/dev/null && exit 0
        focused=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
            hyprctl dispatch "hl.dsp.focus({ monitor = \"$mon\" })" >/dev/null
            hyprctl dispatch "hl.dsp.exec_cmd([[[workspace special:screensaver-$mon] kitty --class=screensaver --override font_size=18 --override window_padding_width=0 --override background_opacity=1 $dir/run.sh $2]])" >/dev/null
            # Wait For Window: it maps on the focused monitor
            n=$(hyprctl clients -j | jq '[.[] | select(.class == "screensaver")] | length')
            for _ in $(seq 50); do
                [ "$(hyprctl clients -j | jq '[.[] | select(.class == "screensaver")] | length')" -gt "$n" ] && break
                sleep 0.1
            done
        done
        hyprctl dispatch "hl.dsp.focus({ monitor = \"$focused\" })" >/dev/null ;;
    stop)
        pkill -f "^kitty --class=screensaver"
        hyprctl eval 'hl.config({ cursor = { invisible = false } })' >/dev/null ;;
esac
