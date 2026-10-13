#!/usr/bin/env bash
# Storage for the dashboard, one JSON object:
#   {"free":"75G","used":"18G","total":"98G","pct":19,
#    "dirs":[{"name":"Downloads","path":"/home/you/Downloads","icon":"󰉍","size":"1.2G"},...]}
# Folders that don't exist are skipped. Sizes come from du (5s cap each).
DIRS=(
	"Downloads|$HOME/Downloads|󰉍"
	"Pictures|$HOME/Pictures|󰉏"
	"Notes|$HOME/Notes|󰠮"
	"dotfiles|$HOME/dotfiles|󱁿"
	"~/.config|$HOME/.config|󱁿"
	"~/.cache|$HOME/.cache|󰃢"
)

read -r total used free pct < <(df -h --output=size,used,avail,pcent / | tail -1 | tr -d '%')

for d in "${DIRS[@]}"; do
	IFS='|' read -r name path icon <<< "$d"
	[ -d "$path" ] || continue
	size=$(timeout 5 du -sh "$path" 2>/dev/null | cut -f1)
	jq -nc --arg n "$name" --arg p "$path" --arg i "$icon" --arg s "${size:-?}" '{name: $n, path: $p, icon: $i, size: $s}'
done | jq -sc --arg t "$total" --arg u "$used" --arg f "$free" --argjson pct "$pct" \
	'{free: $f, used: $u, total: $t, pct: $pct, dirs: .}'
