#!/usr/bin/env bash

# Asks hyprland for active workspaces and keeps just the number
hyprctl activeworkspace -j | jq '.id'

# The Listener
socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | # Connects to event socket and streams every event out
while read -r line; do # Handles each event one line at a time
	case $line in # Ignores logs that don't start with workspace
			workspace*) hyprctl activeworkspace -j | jq '.id' ;;
		esac
	done
	
