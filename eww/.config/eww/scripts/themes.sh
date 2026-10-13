#!/usr/bin/env bash
# Theme picker (SUPER + T): theme tabs on top, that theme's wallpapers below.
# Clicking a wallpaper applies its theme + that wallpaper (~/.local/bin/theme).
# Detaches first: eww kills onclick commands after 200ms.
#   themes.sh toggle             open / close on the focused monitor
#   themes.sh close              close it (no-op if already closed)
#   themes.sh pick NAME WALL     apply theme NAME with wallpaper WALL
# While it's open the "themes" submap is on: ESC / SUPER + T close it.
if [ -z "$THEMES_DETACHED" ]; then
    THEMES_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

palettes="$HOME/.config/theme"
walls="$HOME/dotfiles/wallpapers"
state="$HOME/.local/state/theme"
thumbs="$HOME/.cache/theme/thumbs"

# Thumbnail: small cached copy, 4k pngs are too slow to draw on open
thumb() {
    local out="$thumbs/$2/$(basename "${1%.*}").jpg"
    if [ ! -f "$out" ] || [ "$1" -nt "$out" ]; then
        mkdir -p "$thumbs/$2"
        ffmpeg -loglevel error -y -i "$1" -vf "scale=384:216:force_original_aspect_ratio=increase,crop=384:216" -frames:v 1 "$out"
    fi
    echo "$out"
}

# Picker Data: [{name, dots, rows: [[{path, thumb}] x3]}]
data() {
    shopt -s nullglob
    for p in "$palettes"/*.sh; do
        local name=$(basename "$p" .sh)
        local pool=("$walls/$name"/*.{png,jpg,jpeg,webp})
        [ ${#pool[@]} -gt 0 ] || pool=("$walls/mono/stairs.png")
        local dots=$(source "$p"; echo "$accent ${ansi[1]} ${ansi[2]} ${ansi[3]} ${ansi[4]}")
        for w in $(printf '%s\n' "${pool[@]}" | sort); do
            printf '%s\t%s\t%s\t%s\n' "$name" "$dots" "$w" "$(thumb "$w" "$name")"
        done
    done | jq -Rsc '
        split("\n") | map(select(. != "") | split("\t"))
        | group_by(.[0])
        | map({name: .[0][0], dots: (.[0][1] | split(" ")),
               walls: map({path: .[2], thumb: .[3]})})
        | sort_by(if .name == "mono" then 0 else 1 end, .name)
        | map(.rows = [range(0; .walls | length; 3) as $i | .walls[$i:$i+3]] | del(.walls))'
}

# Push State: eww reload (theme change) resets every var, so this runs after it too
push() {
    eww update themes_data="$(data)" \
        themes_cur="$(cat "$state/name" 2>/dev/null || echo mono)" \
        themes_wall="$(readlink "$state/wallpaper")" \
        themes_tab="$1" themes_open=true
}

open() {
    ~/.config/eww/scripts/tray.sh close
    ~/.config/eww/scripts/panel.sh close   # one panel at a time
    ~/.config/eww/scripts/net.sh close
    ~/.config/eww/scripts/start.sh close
    ~/.config/eww/scripts/notes.sh close
    ~/.config/eww/scripts/dash.sh close
    push "$(cat "$state/name" 2>/dev/null || echo mono)"
    eww open themes --screen "$(hyprctl activeworkspace -j | jq .monitorID)"
    hyprctl dispatch 'hl.dsp.submap("themes")' >/dev/null
}

close() {
    # always leave the submap, even if eww lost track of the window
    hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null
    # no themes_open check: an eww reload resets it while the window stays up
    eww update themes_open=false
    eww close themes 2>/dev/null
}

case "$1" in
    toggle) if [ "$(eww get themes_open)" = "true" ]; then close
            else open; fi ;;
    close)  close ;;
    pick)   ~/.local/bin/theme "$2" "$3"
            # a theme change reloads eww: reopen on the same tab
            if [ "$(eww get themes_open)" != "true" ]; then
                push "$2"
                eww open themes --screen "$(hyprctl activeworkspace -j | jq .monitorID)"
            else
                eww update themes_wall="$(readlink "$state/wallpaper")" themes_cur="$2"
            fi ;;
esac
