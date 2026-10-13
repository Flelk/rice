#!/bin/bash
# Joke Screensaver Loop: omarchy style, big text + random tte effect, key or focus loss quits
cd "$(dirname "$0")" || exit 1
art="${XDG_RUNTIME_DIR:-/tmp}/screensaver-$$.txt"
# Test: run.sh horror = only vim jokes
[[ $1 == horror ]] && force=VIM
# Effects: fireworks x3, no binary/matrix
effects=(fireworks fireworks fireworks beams blackhole bouncyballs bubbles burn colorshift crumble
         expand highlight laseretch middleout orbittingvolley pour rings scattered slice spotlights
         spray swarm sweep synthgrid thunderstorm unstable vhstape waves wipe)

# In Focus: 3s grace while the other monitors open
started=$SECONDS
in_focus() { (( SECONDS - started < 3 )) || hyprctl activewindow -j | jq -e '.class == "screensaver"' >/dev/null 2>&1; }
quit() { rm -f "$art"; pkill -P $$; ./screensaver.sh stop; exit 0; }
trap quit SIGINT SIGTERM SIGHUP

printf '\033]11;rgb:00/00/00\007'
hyprctl eval 'hl.config({ cursor = { invisible = true } })' >/dev/null
tput civis
stty -echo

# Horror Mode: vim jokes bleed, then the creature
blood=(--final-gradient-stops ff2020 b30000 4a0000 --final-gradient-direction vertical)
wait_key() { read -rsn1 -t "$1" && return 1; in_focus; }
play() {   # play FILE EFFECT [ARGS], quits on key
    tte -i "$1" --frame-rate 60 --canvas-width 0 --canvas-height 0 --reuse-canvas \
        --anchor-canvas c --anchor-text c --no-eol --no-restore-cursor "${@:2}" "${blood[@]}" &
    while kill -0 $! 2>/dev/null; do wait_key 1 || return 1; done
}
horror() {
    printf '\033]11;rgb:08/00/00\007'
    case $((RANDOM % 6)) in
        0|1) play "$art" burn --starting-color 1a0000 --burn-colors 2a0000 8a0303 ff2020 ff6a00 4a0000 ;;
        2)   play "$art" rain --rain-colors 8a0303 b30000 ff2020 ;;
        3)   play "$art" smoke --starting-color 1a0000 --smoke-gradient-stops 4a0000 8a0303 2a0000 ;;
        4)   play "$art" vhstape --glitch-line-colors 4a0000 b30000 ff2020 --glitch-wave-colors 8a0303 ff2020 --noise-colors 1a0000 4a0000 8a0303 ;;
        5)   play "$art" unstable --unstable-color 8a0303 ;;
    esac || return 1
    # Creature: glitches the text, flashes in 3 times
    wait_key 1 || return 1
    ./creature.py "$art" &
    while kill -0 $! 2>/dev/null; do wait_key 0.5 || return 1; done
    # Lights Out
    printf '\033]11;rgb:00/00/00\007'
    clear; wait_key 2 || return 1
}

# Wait For Resize: kitty starts at 80x24
for _ in $(seq 100); do [ "$(stty size)" != "24 80" ] && break; sleep 0.02; done

deck=()
while true; do
    # Pick Joke: split on "%", shuffled deck so every joke shows before repeats
    if (( ${#deck[@]} == 0 )); then
        mapfile -d '' deck < <(awk -v only="$force" 'BEGIN { RS = "\n%\n" } { sub(/\n?%\n*$/, ""); if ($0 != "" && $0 ~ only) printf "%s\0", $0 }' jokes.txt | shuf -z)
    fi
    joke=${deck[0]}
    deck=("${deck[@]:1}")
    printf '%s\n' "$joke" | ./bigtext.py > "$art"
    if [[ $joke == *VIM* ]]; then
        horror || quit
    else
        printf '\033]11;rgb:00/00/00\007'
        tte -i "$art" --frame-rate 120 --canvas-width 0 --canvas-height 0 --reuse-canvas \
            --anchor-canvas c --anchor-text c --no-eol --no-restore-cursor \
            "${effects[RANDOM % ${#effects[@]}]}" &
        while kill -0 $! 2>/dev/null; do
            { read -rsn1 -t 1 || ! in_focus; } && quit
        done
        for _ in 1 2 3; do { read -rsn1 -t 1 || ! in_focus; } && quit; done
    fi
    clear
done
