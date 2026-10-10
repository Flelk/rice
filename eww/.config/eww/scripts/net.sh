#!/bin/sh
# Network panel helper. Detaches first: eww kills onclick commands after 200ms.
#   net.sh toggle N              toggle the panel on monitor N
#   net.sh close                 close it (no-op if already closed)
#   net.sh tab wifi|bt           switch tab (bluetooth starts a scan)
#   net.sh wifi-power            turn wifi on/off
#   net.sh wifi ACTION ID        ACTION/ID come from wifi.sh (up|down|forget UUID, new|new-secure B64SSID)
#   net.sh bt-power | bt-scan    turn bluetooth on/off, scan again
#   net.sh bt ACTION MAC         connect|disconnect|pair|forget
#   net.sh audio SINK            make audio sink number SINK the output (usb dongle headsets)
if [ -z "$NET_DETACHED" ]; then
    NET_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

# discovery stops by itself after this long, or when the panel closes
SCAN_SECS=30

scan() {
    pkill -f "bluetoothctl --timeout $SCAN_SECS scan on"
    bluetoothctl --timeout "$SCAN_SECS" scan on >/dev/null 2>&1 &
}

# shows text under the list for a few seconds (unless a newer message replaced it)
msg() {
    eww update net_msg="$1"
    sleep 4
    [ "$(eww get net_msg)" = "$1" ] && eww update net_msg=""
}

# marks row ID busy while the rest of the command runs; on failure shows FAIL_MSG
busy() {
    id=$1 fail=$2; shift 2
    eww update net_busy="$id"
    if "$@" >/dev/null 2>&1; then eww update net_busy=""
    else eww update net_busy=""; msg "$fail"; fi
}

open() {
    ~/.config/eww/scripts/panel.sh close   # one panel at a time
    eww update net_tab=wifi
    eww open net --screen "${1:-0}" && eww update net_open=true
    nmcli dev wifi rescan >/dev/null 2>&1
}

close() {
    [ "$(eww get net_open)" = "true" ] || return 0
    eww update net_open=false net_busy="" net_msg=""
    eww close net   # hyprland animates the slide out
    pkill -f "bluetoothctl --timeout $SCAN_SECS scan on"
}

bt_pair() {
    bluetoothctl pairable on &&
    bluetoothctl --agent NoInputNoOutput pair "$1" &&
    bluetoothctl trust "$1" &&
    bluetoothctl connect "$1"
}

case "$1" in
    toggle) if [ "$(eww get net_open)" = "true" ]; then close
            else open "$2"; fi ;;
    close)  close ;;
    tab)    eww update net_tab="$2"
            if [ "$2" = bt ]; then scan; else nmcli dev wifi rescan >/dev/null 2>&1; fi ;;

    wifi-power)
        if [ "$(nmcli radio wifi)" = enabled ]; then nmcli radio wifi off; else nmcli radio wifi on; fi ;;
    wifi)
        case "$2" in
            up)   busy "$3" "couldn't connect" nmcli con up uuid "$3" ;;
            down) busy "$3" "couldn't disconnect" nmcli con down uuid "$3" ;;
            forget) busy "$3" "couldn't forget it" nmcli con delete uuid "$3" ;;
            new)  ssid=$(printf %s "$3" | base64 -d) || exit 1
                  busy "$3" "couldn't connect" nmcli dev wifi connect "$ssid" ;;
            new-secure)
                  ssid=$(printf %s "$3" | base64 -d) || exit 1
                  pw=$(fuzzel --dmenu --password --prompt-only "$ssid  " </dev/null) || exit 0
                  [ -n "$pw" ] || exit 0
                  busy "$3" "wrong password?" nmcli dev wifi connect "$ssid" password "$pw" ;;
            enterprise) msg "802.1X network: set it up with nmtui" ;;
        esac ;;

    bt-power)
        if bluetoothctl show | grep -q "Powered: yes"; then bluetoothctl power off
        else bluetoothctl power on && scan; fi ;;
    bt-scan) scan ;;
    audio)
        printf %s "$2" | grep -Eq '^[0-9]+$' || exit 1
        busy "sink$2" "couldn't switch output" pactl set-default-sink "$2" ;;
    bt)
        # only ever a mac address (names are made up by the device, so they never get here)
        printf %s "$3" | grep -Eq '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' || exit 1
        case "$2" in
            connect)    busy "$3" "couldn't connect" bluetoothctl connect "$3" ;;
            disconnect) busy "$3" "couldn't disconnect" bluetoothctl disconnect "$3" ;;
            pair)       busy "$3" "pairing failed" bt_pair "$3" ;;
            forget)     busy "$3" "couldn't forget it" bluetoothctl remove "$3" ;;
        esac ;;
esac
