#!/bin/sh
# Monitor brightness over DDC/CI (external monitors have no backlight device).
#   brightness.sh get      print brightness of the first monitor (0-100)
#   brightness.sh set N    set every monitor to N (latest call wins while dragging)
case "$1" in
    get)
        ddcutil getvcp 10 --display 1 --brief 2>/dev/null | awk '{print $4; f=1} END {if (!f) print 50}' ;;
    set)
        if [ -z "$BRIGHT_DETACHED" ]; then
            BRIGHT_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
            exit 0
        fi
        echo "$2" > "${XDG_RUNTIME_DIR:-/tmp}/eww-brightness"
        sleep 0.15
        # a newer slider value arrived while we waited: let that call handle it
        [ "$(cat "${XDG_RUNTIME_DIR:-/tmp}/eww-brightness")" = "$2" ] || exit 0
        eww update brightness="$2"
        for d in $(ddcutil detect --brief 2>/dev/null | awk '/^Display/{print $2}'); do
            ddcutil setvcp 10 "$2" --display "$d" --noverify &
        done
        wait ;;
esac
