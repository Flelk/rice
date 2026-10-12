#!/bin/sh
# Start panel helper (arch button, left side). Detaches first: eww kills onclick commands after 200ms.
#   start.sh toggle N        toggle the panel on monitor N
#   start.sh close           close it (no-op if already closed)
#   start.sh rice            open/close the rice drawer
#   start.sh search QUERY    fill start_results with apps matching QUERY
#   start.sh first           launch the top search result (enter in the search box)
#   start.sh launch ID       close, then launch app ID (a .desktop id)
#   start.sh pin | unpin ID  pick an app to pin with fuzzel | unpin app ID
#   start.sh update          close, update the system with yay in kitty
#   start.sh reload eww|hypr|mako
#   start.sh edit hypr|eww|kitty|fuzzel|mako|fastfetch|dotfiles    open that config in code
if [ -z "$START_DETACHED" ]; then
    START_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

APPS=~/.config/eww/scripts/apps.sh
PINNED=~/.config/eww/pinned

open() {
    ~/.config/eww/scripts/panel.sh close   # one panel at a time
    ~/.config/eww/scripts/net.sh close
    ~/.config/eww/scripts/notes.sh close
    eww update start_pinned="$($APPS pinned)" start_query="" start_results="[]" start_rice=false
    eww open start --screen "${1:-0}" && eww update start_open=true
    # sections fade in one after another
    for n in 1 2 3 4 5; do sleep 0.08; eww update start_stage=$n; done
}

close() {
    [ "$(eww get start_open)" = "true" ] || return 0
    eww update start_stage=0 start_open=false start_rice=false
    eww close start   # hyprland animates the slide out
}

launch() {
    close
    gtk-launch "$1"
}

case "$1" in
    toggle) if [ "$(eww get start_open)" = "true" ]; then close
            else open "$2"; fi ;;
    close)  close ;;
    rice)   if [ "$(eww get start_rice)" = "true" ]; then eww update start_rice=false
            else eww update start_rice=true; fi ;;
    search) eww update start_query="$2"
            if [ -z "$2" ]; then eww update start_results="[]"
            else
                res=$($APPS search "$2")
                # only show it if nothing newer was typed meanwhile
                [ "$(eww get start_query)" = "$2" ] && eww update start_results="$res"
            fi ;;
    first)  id=$($APPS search "$(eww get start_query)" | jq -r '.[0].id // empty')
            [ -n "$id" ] && launch "$id" ;;
    launch) launch "$2" ;;
    pin)    choice=$($APPS all | cut -f2 | fuzzel --dmenu --prompt "pin  ") || exit 0
            id=$($APPS all | awk -F'\t' -v n="$choice" '$2 == n { print $1; exit }')
            [ -n "$id" ] && ! grep -qxF "$id" "$PINNED" && echo "$id" >> "$PINNED"
            eww update start_pinned="$($APPS pinned)" ;;
    unpin)  rest=$(grep -vxF "$2" "$PINNED")
            printf '%s\n' "$rest" | sed '/^$/d' > "$PINNED"
            eww update start_pinned="$($APPS pinned)" ;;
    update) close
            kitty --title "system update" sh -c 'yay; echo; printf "done, press enter to close"; read _'
            eww update start_updates="$( (checkupdates; yay -Qua) 2>/dev/null | wc -l)" ;;
    reload) close
            case "$2" in
                eww)  eww reload ;;
                hypr) hyprctl reload ;;
                mako) makoctl reload ;;
            esac ;;
    edit)   close
            case "$2" in
                dotfiles) code ~/dotfiles ;;
                *)        code ~/dotfiles/"$2"/.config/"$2" ;;
            esac ;;
esac
