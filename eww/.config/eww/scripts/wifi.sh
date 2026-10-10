#!/usr/bin/env bash

# Prints the wifi tab as JSON:
#   {"on":true,
#    "known":  [{"ssid":"home","signal":72,"secure":true,"active":true,"known":true,
#                "icon":"󰤥","action":"down","id":"<uuid>"}, ...],   saved networks in range
#    "unknown":[...]}                                                 everything else in range
# action + id go straight to net.sh:
#   up|down|forget id = uuid of the saved connection
#   new|new-secure id = the ssid in base64 (anyone can name an access point, so a raw ssid never goes in a command)
#   enterprise     802.1X networks, not handled here

# uuid<TAB>ssid of every saved wifi connection
saved() {
	nmcli -g UUID,TYPE con show | while IFS=: read -r uuid type; do
		[ "$type" = 802-11-wireless ] &&
			printf '%s\t%s\n' "$uuid" "$(nmcli -g 802-11-wireless.ssid con show uuid "$uuid")"
	done
}

jq -nc --arg on "$(nmcli radio wifi)" \
	--rawfile saved <(saved) \
	--rawfile scan <(nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID dev wifi list --rescan no) '
	def unesc: gsub("\\\\(?<c>.)"; .c);   # nmcli escapes ":" and "\" in terse output
	($saved | split("\n") | map(select(. != "") | split("\t") | {key: (.[1] | unesc), value: .[0]})
		| from_entries) as $known
	| ($scan | split("\n") | map(select(. != "")
		| capture("^(?<active>[^:]*):(?<signal>[^:]*):(?<sec>[^:]*):(?<ssid>.*)$")
		| .ssid |= unesc | select(.ssid != ""))
		# one row per ssid, even when several access points share it
		| group_by(.ssid) | map({
			ssid: .[0].ssid,
			signal: (map(.signal | tonumber) | max),
			secure: (.[0].sec | . != "" and . != "--"),
			enterprise: any(.[]; .sec | test("802\\.1X")),
			active: any(.[]; .active == "yes"),
			known: ($known[.[0].ssid] != null)})
		| sort_by([(.active | not), -.signal])
		| map(. + {
			icon: (if .signal >= 75 then "󰤨" elif .signal >= 50 then "󰤥" elif .signal >= 25 then "󰤢" else "󰤟" end),
			action: (if .known then (if .active then "down" else "up" end)
			         elif .enterprise then "enterprise"
			         elif .secure then "new-secure" else "new" end),
			id: (if .known then $known[.ssid] else (.ssid | @base64) end)})) as $nets
	| {on: ($on == "enabled"), known: ($nets | map(select(.known))), unknown: ($nets | map(select(.known | not)))}'
