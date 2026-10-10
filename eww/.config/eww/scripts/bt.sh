#!/usr/bin/env bash

# Prints the bluetooth tab as JSON:
#   {"on":true,"scanning":false,
#    "known":  [{"mac":"AA:BB:..","name":"WH-1000XM4","icon":"󰋋","connected":true}, ...],  paired
#    "unknown":[...]}                                                   nearby, not paired (nearest first)
# devices that only advertise a mac address (beacons, trackers, ...) are left out of unknown.
# wireless headsets on their own usb dongle (logitech lightspeed etc.) aren't bluetooth, but they're
# known too: they show up as {"name":"G522","dongle":true,"sink":57,...} and their bluetooth side
# (most of them also advertise over bluetooth) is left out of unknown so it isn't listed twice

# mac<TAB>name<TAB>alias<TAB>icon<TAB>paired<TAB>connected<TAB>rssi for every device bluez knows
devices() {
	bluetoothctl devices | awk '$1 == "Device" {print $2}' | while read -r mac; do
		bluetoothctl info "$mac" | awk -v mac="$mac" '
			/^\t[A-Za-z]+: / {
				k = $1; sub(/:$/, "", k)
				v = $0; sub(/^\t[A-Za-z]+: /, "", v); gsub(/\t/, " ", v)
				f[k] = v
			}
			END {
				rssi = f["RSSI"]; sub(/.*\(/, "", rssi); sub(/\).*/, "", rssi)
				printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", mac, f["Name"], f["Alias"], f["Icon"],
					f["Paired"], f["Connected"], (rssi == "" ? -999 : rssi)
			}'
	done
}

show=$(bluetoothctl show)

jq -nc --arg show "$show" --rawfile devs <(devices) \
	--argjson sinks "$(pactl -f json list sinks 2>/dev/null || echo [])" \
	--arg default "$(pactl get-default-sink 2>/dev/null)" '
	def icon: if test("headset|headphone") then "󰋋"
		elif test("audio") then "󰓃"
		elif test("mouse") then "󰍽"
		elif test("keyboard") then "󰌌"
		elif test("gaming") then "󰊴"
		elif test("phone") then "󰏲"
		elif test("computer") then "󰟀"
		else "󰂯" end;
	($devs | split("\n") | map(select(. != "") | split("\t") | {
		mac: .[0], dongle: false, name: (if .[2] != "" then .[2] else .[1] end), hasname: (.[1] != ""),
		icon: (.[3] | icon), paired: (.[4] == "yes"), connected: (.[5] == "yes"),
		rssi: (.[6] | tonumber)})) as $all
	| ($sinks | map(select(.properties["device.bus"] == "usb"
			and (.properties["device.product.name"] // "" | test("wireless|lightspeed"; "i")))
		| {mac: "sink\(.index)", sink: .index, dongle: true, icon: "󰋋", connected: true,
		   default: (.name == $default),
		   # "G522 LIGHTSPEED - Wireless Mode" -> "G522"
		   name: (.properties["device.product.name"] | sub("(?i)\\s*(-\\s*)?(lightspeed|wireless).*$"; ""))})
	) as $dongles
	| {
		on: ($show | test("Powered: yes")),
		scanning: ($show | test("Discovering: yes")),
		known: ($dongles + ($all | map(select(.paired)) | sort_by([(.connected | not), .name]))),
		unknown: ($all | map(select((.paired | not) and .hasname)
			| select(.name | split(" ")[0] as $w | any($dongles[]; .name == $w) | not))
			| sort_by([-.rssi, .name]))
	}'
