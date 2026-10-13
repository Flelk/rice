#!/bin/sh
# Prints the laptop battery for the bar as json: {"on", "pct", "state", "icon", "low"}

root=${POWER_SUPPLY_DIR:-/sys/class/power_supply}   # override to test without a battery

for b in "$root"/*; do
    [ "$(cat "$b/type" 2>/dev/null)" = Battery ] || continue
    [ "$(cat "$b/scope" 2>/dev/null)" = Device ] && continue
    pct=$(cat "$b/capacity" 2>/dev/null) || continue
    status=$(cat "$b/status" 2>/dev/null)

    lvl=$(( (pct + 5) / 10 ))
    case "$status" in
        Charging)      state=charging; icons="󰢟 󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅" ;;
        Discharging)   state=battery;  icons="󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹" ;;
        *)             state=plugged;  icons="󰢟 󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅" ;;
    esac
    icon=$(echo $icons | cut -d' ' -f$(( lvl + 1 )))
    low=false
    [ "$state" = battery ] && [ "$pct" -le 15 ] && low=true
    printf '{"on":true,"pct":%d,"state":"%s","icon":"%s","low":%s}\n' "$pct" "$state" "$icon" "$low"
    exit 0
done
echo '{"on":false,"pct":0,"state":"","icon":"","low":false}'
