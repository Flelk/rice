#!/bin/sh
# Screen brightness: the backlight on a laptop, DDC/CI on a desktop (external monitors have no.

buses() {
    # monitor i2c buses, detected once per boot (detection is slow)
    cache="${XDG_RUNTIME_DIR:-/tmp}/eww-ddc-buses"
    [ -s "$cache" ] || ddcutil detect --brief 2>/dev/null |
        awk '/I2C bus:/{sub(".*i2c-",""); print}' > "$cache"
    cat "$cache"
}
last="${XDG_RUNTIME_DIR:-/tmp}/eww-brightness"

# laptop: the backlight is quick to read and set, no DDC needed
if [ -n "$(ls /sys/class/backlight 2>/dev/null)" ]; then
    case "$1" in
        get) brightnessctl -m | cut -d, -f4 | tr -d % ;;
        set) brightnessctl -q set "$(( $2 < 1 ? 1 : $2 ))%"   # 0% is a black screen
             eww update brightness="$2" ;;
    esac
    exit 0
fi

case "$1" in
    get)
        if [ ! -s "$last" ]; then
            ddcutil getvcp 10 --bus "$(buses | head -n1)" --brief 2>/dev/null |
                awk '{print $4; f=1} END {if (!f) print 50}' > "$last"
        fi
        cat "$last" ;;
    set)
        if [ -z "$BRIGHT_DETACHED" ]; then
            BRIGHT_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
            exit 0
        fi
        echo "$2" > "$last"
        sleep 0.15
        # a newer slider value arrived while we waited: let that call handle it
        [ "$(cat "$last")" = "$2" ] || exit 0
        eww update brightness="$2"
        for b in $(buses); do
            ddcutil setvcp 10 "$2" --bus "$b" --noverify &
        done
        wait ;;
esac
