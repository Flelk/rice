#!/bin/sh
# Prints the default sink volume (0-100) now and again on every sink change.
get() { wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d\n", $2 * 100 + 0.5}'; }
get
pactl subscribe | while read -r line; do
	case $line in
		*"on sink "*|*"on server "*) get ;;
	esac
done
