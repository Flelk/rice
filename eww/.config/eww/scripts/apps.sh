#!/usr/bin/env bash
# App list for the start panel, read from .desktop files (user ones override system ones).
#   apps.sh all            every launchable app as TSV: id \t name \t icon
#   apps.sh pinned         pinned apps as JSON rows of 4, "+" tile last: [[{id,name,icon},...],...]
#   apps.sh search QUERY   first 6 apps whose name contains QUERY, as JSON: [{id,name,icon},...]
# pinned apps live in ~/.config/eww/pinned, one desktop id per line (e.g. kitty.desktop)
PINNED="$HOME/.config/eww/pinned"
COLS=4

all() {
	for dir in "$HOME/.local/share/applications" /usr/share/applications \
	           "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications; do
		[ -d "$dir" ] && for f in "$dir"/*.desktop; do [ -f "$f" ] && echo "$f"; done
	done | awk -F= '
		FNR == 1 { if (id != "" && name != "" && !hide) print id "\t" name "\t" icon
		           id = FILENAME; sub(".*/", "", id); name = icon = ""; hide = 0; main = 0 }
		/^\[/    { main = ($0 == "[Desktop Entry]") }
		main && $1 == "Name"      && name == "" { name = substr($0, 6) }
		main && $1 == "Icon"      { icon = substr($0, 6) }
		main && $1 == "NoDisplay" && $2 == "true" { hide = 1 }
		main && $1 == "Hidden"    && $2 == "true" { hide = 1 }
		main && $1 == "Type"      && $2 != "Application" { hide = 1 }
		END      { if (id != "" && name != "" && !hide) print id "\t" name "\t" icon }
	' $(cat) | awk -F'\t' '!seen[$1]++' | sort -t$'\t' -k2,2f
}

# icon name from a .desktop file -> image file (eww needs a path), generic app icon if none found
icon_path() {
	case "$1" in /*) [ -f "$1" ] && { echo "$1"; return; } ;; esac
	if [ -n "$1" ]; then
		for d in "$HOME/.local/share/icons/hicolor" /usr/share/icons/hicolor; do
			for s in scalable 256x256 128x128 96x96 64x64 48x48 32x32; do
				for e in svg png; do [ -f "$d/$s/apps/$1.$e" ] && { echo "$d/$s/apps/$1.$e"; return; }; done
			done
		done
		for e in png svg; do [ -f "/usr/share/pixmaps/$1.$e" ] && { echo "/usr/share/pixmaps/$1.$e"; return; }; done
	fi
	echo /usr/share/icons/Adwaita/scalable/mimetypes/application-x-executable.svg
}

to_json() {
	while IFS=$'\t' read -r id name icon; do printf '%s\t%s\t%s\n' "$id" "$name" "$(icon_path "$icon")"; done |
	jq -Rnc '[inputs | split("\t") | {id: .[0], name: .[1], icon: (.[2] // "")}]'
}

case "$1" in
	all) all ;;
	pinned)
		touch "$PINNED"
		all | awk -F'\t' 'FILENAME == ARGV[1] { order[$1] = FNR; next } $1 in order { print order[$1] "\t" $0 }' "$PINNED" - \
			| sort -n | cut -f2- | to_json \
			| jq -c --argjson n "$COLS" '. + [{id: "+", name: "add", icon: ""}] | [range(0; length; $n) as $i | .[$i:$i + $n]]' ;;
	search)
		all | awk -F'\t' -v q="$2" 'index(tolower($2), tolower(q))' | head -6 | to_json ;;
esac
