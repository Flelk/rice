#!/usr/bin/env bash
# Weather for the dashboard (wttr.in, location from your IP), one JSON object:
#   {"ok":true,"icon":"󰖙","temp":71,"feels":70,"desc":"Sunny","quip":"...","hi":75,"lo":58,
#    "rain":10,"humidity":70,"wind":"8 mph","sunrise":"07:27","sunset":"19:02","moon":"Waxing Crescent",
#    "hours":[{"time":"15:00","icon":"󰖙","temp":73},...]}
# Cached 15 minutes in ~/.cache/eww/weather.json. Stale cache is used when offline.
UNITS=F          # F or C
LOCATION=""      # empty = from your IP, or a city like "Boston"
CACHE="$HOME/.cache/eww/weather.json"
mkdir -p "${CACHE%/*}"

if [ ! -s "$CACHE" ] || [ -n "$(find "$CACHE" -mmin +15)" ]; then
	raw=$(curl -sf --max-time 8 "https://wttr.in/${LOCATION// /+}?format=j1") &&
		jq -e .current_condition >/dev/null 2>&1 <<< "$raw" && printf '%s' "$raw" > "$CACHE"
fi
[ -s "$CACHE" ] || { echo '{"ok":false,"hours":[]}'; exit 0; }

# Day Or Night: between sunrise and sunset
now=$(date +%s)
rise=$(date -d "$(jq -r '.weather[0].astronomy[0].sunrise' "$CACHE")" +%s 2>/dev/null || echo 0)
set=$(date -d "$(jq -r '.weather[0].astronomy[0].sunset' "$CACHE")" +%s 2>/dev/null || echo 0)
day=false; (( now >= rise && now < set )) && day=true

jq -c --arg u "$UNITS" --argjson day "$day" --argjson hour "$(date +%-H)" '
	# wttr weather codes -> material weather icons
	def icon($d): tostring as $c
		| if   $c == "113" then (if $d then "󰖙" else "󰖔" end)
		  elif $c == "116" then (if $d then "󰖕" else "󰼱" end)
		  elif ($c | IN("119","122")) then "󰖐"
		  elif ($c | IN("143","248","260")) then "󰖑"
		  elif ($c | IN("200","386","389","392","395")) then "󰙾"
		  elif ($c | IN("182","185","281","284","311","314","317","320","350","362","365","374","377")) then "󰙿"
		  elif ($c | IN("179","227","230","323","326","329","332","335","338","368","371")) then "󰖘"
		  elif ($c | IN("302","305","308","356","359")) then "󰖖"
		  else "󰖗" end;
	def kind: tostring as $c
		| if   ($c | IN("200","386","389","392","395")) then "storm"
		  elif ($c | IN("179","227","230","323","326","329","332","335","338","368","371")) then "snow"
		  elif ($c | IN("182","185","281","284","311","314","317","320","350","362","365","374","377")) then "sleet"
		  elif ($c | IN("176","263","266","293","296","299","302","305","308","353","356","359")) then "rain"
		  elif ($c | IN("143","248","260")) then "fog"
		  elif ($c | IN("119","122")) then "cloudy"
		  elif $c == "116" then "partly"
		  else "clear" end;
	def t($x): $x | tonumber;
	def hm: strptime("%I:%M %p") | strftime("%H:%M");
	.current_condition[0] as $now | .weather[0] as $today
	| t(if $u == "F" then $now.temp_F else $now.temp_C end) as $temp
	| ($now.weatherCode | kind) as $k
	| (if $u == "F" then [$temp <= 32, $temp >= 90] else [$temp <= 0, $temp >= 32] end) as [$cold, $hot]
	# Quip: one line under the condition
	| (if   $k == "storm" then "thunderstorms, stay inside"
	   elif $k == "snow"  then "snow! winter is here"
	   elif $k == "sleet" then "sleet, worst of both worlds"
	   elif $k == "rain"  then "rain today, grab an umbrella"
	   elif $cold         then "freezing out, grab a jacket"
	   elif $hot          then "hot one, stay hydrated"
	   elif $k == "fog"   then "foggy, take it slow"
	   elif $k == "cloudy" then "gray all day, perfect coding weather"
	   elif $k == "partly" then "a few clouds, nothing serious"
	   elif $day          then "clear skies, go touch grass"
	   else "clear night, good one for stargazing" end) as $quip
	# Next 5 Hours: 3 hour slots from now on, spilling into tomorrow
	| [ .weather[0:2] | to_entries[] | .key as $d | .value.hourly[]
	    | {h: ($d * 24 + (.time | tonumber / 100)), code: .weatherCode, temp: (if $u == "F" then .tempF else .tempC end)} ]
	| map(select(.h > $hour))[0:5] as $hours
	| {
		ok: true,
		icon: ($now.weatherCode | icon($day)),
		temp: $temp,
		feels: t(if $u == "F" then $now.FeelsLikeF else $now.FeelsLikeC end),
		unit: $u,
		desc: ($now.weatherDesc[0].value | ascii_downcase | gsub("^\\s+|\\s+$"; "")),
		quip: $quip,
		hi: t(if $u == "F" then $today.maxtempF else $today.maxtempC end),
		lo: t(if $u == "F" then $today.mintempF else $today.mintempC end),
		rain: ([$today.hourly[].chanceofrain | tonumber] | max),
		humidity: t($now.humidity),
		wind: (if $u == "F" then "\($now.windspeedMiles) mph" else "\($now.windspeedKmph) km/h" end),
		sunrise: ($today.astronomy[0].sunrise | hm),
		sunset: ($today.astronomy[0].sunset | hm),
		moon: ($today.astronomy[0].moon_phase | ascii_downcase),
		hours: [ $hours[] | (.h % 24) as $hh
		         | {time: "\($hh | tostring | if length == 1 then "0" + . else . end):00",
		            icon: (.code | icon($hh >= 7 and $hh < 19)), temp: (.temp | tonumber)} ]
	}' "$CACHE" 2>/dev/null || echo '{"ok":false,"hours":[]}'
