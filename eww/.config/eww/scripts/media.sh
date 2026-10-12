#!/usr/bin/env bash
# Now playing for the start panel, one JSON line per change:
#   {"on":true,"playing":true,"title":"...","artist":"...","art":"/path/to/cover.jpg"}
# "on" is false when no player is running. Cover art is downloaded once into ~/.cache/eww/art.
ART="$HOME/.cache/eww/art"
mkdir -p "$ART"

cover() {
	case "$1" in
		file://*) printf %s "${1#file://}" ;;
		http*)    f="$ART/$(printf %s "$1" | md5sum | cut -c1-16)"
		          [ -s "$f" ] || curl -sfL --max-time 5 -o "$f" "$1"
		          [ -s "$f" ] && printf %s "$f" ;;
	esac
}

emit() {
	IFS=$'\x1f' read -r status title artist url <<< "$1"
	if [ -z "$status" ]; then echo '{"on":false,"playing":false,"title":"","artist":"","art":""}'; return; fi
	jq -nc --arg s "$status" --arg t "$title" --arg a "$artist" --arg art "$(cover "$url")" \
		'{on: true, playing: ($s == "Playing"), title: $t, artist: $a, art: $art}'
}

emit ""
playerctl --follow metadata --format $'{{status}}\x1f{{title}}\x1f{{artist}}\x1f{{mpris:artUrl}}' 2>/dev/null |
	while IFS= read -r line; do emit "$line"; done
