#!/bin/sh
# Power mode (power-profiles-daemon). Detaches first: eww kills onclick commands after 200ms.
#   profile.sh get         print performance|balanced|power-saver, or "none" without the daemon
#   profile.sh set NAME    switch to NAME
if [ -z "$PROFILE_DETACHED" ]; then
    PROFILE_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

get() { powerprofilesctl get 2>/dev/null || echo none; }

case "$1" in
    get) get ;;
    set) case "$2" in performance|balanced|power-saver) ;; *) exit 1 ;; esac
         eww update power_profile="$2"   # light the button up right away
         powerprofilesctl set "$2"
         eww update power_profile="$(get)" ;;   # back to the real one if that failed
esac
