#!/bin/sh
# Screenshot helper (bar button + SUPER SHIFT S). Detaches first: eww kills onclick commands after 200ms.
#   screenshot.sh          drag to select a region (Esc cancels)
#   screenshot.sh screen   the whole focused monitor
# Saves to ~/Pictures/Screenshots, copies to the clipboard, and shows a notification with a preview.
if [ -z "$SHOT_DETACHED" ]; then
    SHOT_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date '+%Y-%m-%d_%H-%M-%S').png"

case "$1" in
    screen)
        output=$(hyprctl monitors -j | jq -r '.[] | select(.focused).name')
        grim -o "$output" "$file" || exit 1 ;;
    *)
        region=$(slurp -d -b '#00000066' -c '#ffffffcc' -w 2) || exit 0   # Esc: no screenshot
        grim -g "$region" "$file" || exit 1 ;;
esac

wl-copy --type image/png < "$file"
notify-send -a screenshot -i "$file" "Screenshot saved" "copied to clipboard · ${file#"$HOME"/}"
