#!/usr/bin/env bash

# Prints the workspace buttons as JSON: [{"n":1,"label":"1","class":"ws active"}, ...]
# 1-5 always show; all 10 show once anything above 5 is in use.
# workspaces on the OMEN (main monitor) are plain, ones on another monitor get its number as a superscript: "2²"
#   active   = focused workspace     (white)
#   occupied = has windows, or is on screen on the other monitor (gray)
#   ws       = empty                 (dim)
print() {
	jq -nc --argjson ws "$(hyprctl workspaces -j)" --argjson mon "$(hyprctl monitors -j)" '
		def sup: tostring | explode | map([8304, 185, 178, 179, 8308, 8309, 8310, 8311, 8312, 8313][. - 48]) | implode;   # 2 -> ²
		($mon | map(select(.focused))[0].activeWorkspace.id) as $active
		# monitor number: OMEN = 1, the rest 2, 3, ... in hyprland order
		| (($mon | map(select(.description | test("OMEN"))) | .[0].id) // 0) as $main
		| ([$mon[].id | select(. != $main)] | sort) as $others
		| ($ws | map({key: "\(.id)", value: .monitorID}) | from_entries) as $where
		| ([$ws[] | select(.windows > 0) | .id] + [$mon[].activeWorkspace.id]) as $used
		| (if any($used[]; . > 5) then 10 else 5 end) as $count
		| [range(1; $count + 1) as $n | {
			n: $n,
			label: ((if $n == 10 then "0" else "\($n)" end)
				+ ($where["\($n)"] as $m | if $m == null or $m == $main then ""
				   else ($others | index($m)) + 2 | sup end)),
			class: (if $n == $active then "ws active"
			        elif any($used[]; . == $n) then "ws occupied"
			        else "ws" end)
		}]'
}

print

# The Listener: reprint on anything that can change the buttons
socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | # Connects to event socket and streams every event out
while read -r line; do # Handles each event one line at a time
	case $line in
		workspace\>\>*|focusedmon\>\>*|openwindow\>\>*|closewindow\>\>*|movewindow\>\>*|moveworkspace\>\>*|createworkspace\>\>*|destroyworkspace\>\>*|monitoradded\>\>*|monitorremoved\>\>*) print ;;
	esac
done
