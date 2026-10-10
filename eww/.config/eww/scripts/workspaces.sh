#!/usr/bin/env bash

# Prints the workspace buttons as JSON: [{"n":1,"label":"1","class":"ws active"}, ...]
# 1-5 always show; all 10 show once anything above 5 is in use.
#   active   = focused workspace     (white)
#   occupied = has windows, or is on screen on the other monitor (gray)
#   ws       = empty                 (dim)
print() {
	jq -nc --argjson ws "$(hyprctl workspaces -j)" --argjson mon "$(hyprctl monitors -j)" '
		($mon | map(select(.focused))[0].activeWorkspace.id) as $active
		| ([$ws[] | select(.windows > 0) | .id] + [$mon[].activeWorkspace.id]) as $used
		| (if any($used[]; . > 5) then 10 else 5 end) as $count
		| [range(1; $count + 1) as $n | {
			n: $n,
			label: (if $n == 10 then "0" else "\($n)" end),
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
		workspace\>\>*|focusedmon\>\>*|openwindow\>\>*|closewindow\>\>*|movewindow\>\>*|moveworkspace\>\>*|createworkspace\>\>*|destroyworkspace\>\>*) print ;;
	esac
done
