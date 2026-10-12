#!/bin/sh
# Notes panel helper (Obsidian). Detaches first: eww kills onclick commands after 200ms.
# The vault is ~/Notes: each folder in it is a notebook, folders inside a notebook are
# sections, and .md files and .canvas boards are pages. Notebooks/pages are picked by the "id" numbers in
# notes_books/notes_pages, so names never end up inside a shell command.
#   notes.sh toggle N     toggle the panel on monitor N
#   notes.sh close        close it (no-op if already closed)
#   notes.sh book ID      show/hide notebook ID's pages in the drawer
#   notes.sh open ID      open notebook ID at its most recently edited page
#   notes.sh page ID      open page ID from the drawer
#   notes.sh new-book     name a new notebook (fuzzel)
#   notes.sh new-page     name a new page (fuzzel) in the notebook shown in the drawer, then open it
#   notes.sh del-book ID  move notebook ID to the trash (after a fuzzel yes/no)
#   notes.sh del-page ID  move page ID to the trash (after a fuzzel yes/no)
if [ -z "$NOTES_DETACHED" ]; then
    NOTES_DETACHED=1 setsid -f "$0" "$@" >/dev/null 2>&1
    exit 0
fi

VAULT="$HOME/Notes"
CFG="$HOME/.config/obsidian/obsidian.json"

# "3m" / "2h" / "5d" since a unix time (jq function, used below)
AGE='def age: (now - .) as $s | if $s < 3600 then "\($s / 60 | floor)m"
    elif $s < 86400 then "\($s / 3600 | floor)h" else "\($s / 86400 | floor)d" end;'

# pages under folder $1 (find -printf format $2): notes and canvases, skipping hidden folders
files() {
    find "$1" \( -name '*.md' -o -name '*.canvas' \) ! -path '*/.*' -printf "$2"
}

# [{id, name, pages, age}], most recently edited notebook first
books() {
    find "$VAULT" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n' |
    while IFS= read -r b; do
        n=$(files "$VAULT/$b" '.\n' | wc -l)
        last=$(files "$VAULT/$b" '%T@\n' | sort -n | tail -n1)
        printf '%s\t%s\t%s\n' "$b" "$n" "${last:-0}"
    done | jq -R -s -c "$AGE"'
        split("\n") | map(select(. != "") | split("\t")
            | {name: .[0], pages: (.[1] | tonumber), t: (.[2] | tonumber)})
        | sort_by(-.t) | to_entries
        | map(.value + {id: .key, age: (if .value.t > 0 then (.value.t | age) else "empty" end)})'
}

# sections of notebook $1: [{name, pages: [{id, name, rel, age, canvas}]}], loose pages first (name ""),
# newest page first inside each section
pages() {
    files "$VAULT/$1" '%T@\t%P\n' | jq -R -s -c "$AGE"'
        split("\n") | map(select(. != "") | split("\t") | {t: (.[0] | tonumber), rel: .[1]})
        | sort_by(-.t) | to_entries
        | map(.value + {id: .key, age: (.value.t | age),
                        name: (.value.rel | split("/") | last | sub("\\.(md|canvas)$"; "")),
                        canvas: (.value.rel | endswith(".canvas")),
                        section: (.value.rel | split("/") | .[:-1] | join(" / "))})
        | group_by(.section) | map({name: .[0].section, pages: map(del(.t, .section))})'
}

# fills the drawer with notebook $1's pages; $2 = its id in notes_books
show_book() {
    p=$(pages "$1")
    # drawer height: ~32px per page, ~28px per section heading, scrolls past 420px
    h=$(printf %s "$p" | jq '[.[] | (.pages | length) * 32 + (if .name != "" then 28 else 0 end)] | add // 0 | [., 420] | min')
    eww update notes_pages="$p" notes_book="$1" notes_drawer_h="$h" notes_sel="$2"
}

# reloads both lists after a change, keeping the drawer on the same notebook if it still exists
# (ids are positions in the list, so they shift)
refresh() {
    b=$(books)
    name=$(eww get notes_book)
    sel=$(printf %s "$b" | jq --arg n "$name" '[.[] | select(.name == $n) | .id][0] // -1')
    eww update notes_books="$b"
    if [ "$(eww get notes_sel)" -ge 0 ] && [ "$sel" -ge 0 ]; then show_book "$name" "$sel"
    else eww update notes_sel=-1 notes_book="" notes_pages="[]"; fi
}

# fuzzel yes/no; "keep it" comes first so a stray enter never deletes anything
confirm() {
    [ "$(printf 'keep it\ndelete %s\n' "$1" | fuzzel --dmenu --prompt "$1?  " --lines 2)" = "delete $1" ]
}

# Obsidian only opens links into vaults it knows: add ~/Notes to its list the first time
ensure_vault() {
    mkdir -p "$VAULT"
    [ -f "$CFG" ] && jq -e --arg p "$VAULT" '.vaults // {} | map(select(.path == $p)) | length > 0' "$CFG" >/dev/null && return
    mkdir -p "$(dirname "$CFG")"
    id=$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n')
    [ -s "$CFG" ] || echo '{}' > "$CFG"
    jq --arg id "$id" --arg p "$VAULT" '.vaults[$id] = {path: $p, ts: (now * 1000 | floor), open: true}' "$CFG" > "$CFG.tmp" &&
        mv "$CFG.tmp" "$CFG"
}

# open file $1 (relative to the vault) in Obsidian
obsidian_open() {
    ensure_vault
    file=$(printf %s "$1" | jq -sRr @uri)
    vault=$(printf %s "${VAULT##*/}" | jq -sRr @uri)
    close
    obsidian "obsidian://open?vault=$vault&file=$file" >/dev/null 2>&1 &
}

# asks for a name with fuzzel (prompt $1), prints it as a safe file name:
# no characters Windows can't store (your notes may sync there), no leading dot
ask_name() {
    fuzzel --dmenu --prompt-only "$1  " </dev/null | tr -d '\\/:*?"<>|' | sed 's/^[ .]*//; s/ *$//'
}

book_name() {
    printf %s "$1" | grep -Eq '^[0-9]+$' || exit 1
    eww get notes_books | jq -r --argjson i "$1" '.[] | select(.id == $i) | .name'
}

# asks for a page name, creates it in notebook $1 (or keeps it if it exists) and opens it
new_page() {
    n=$(ask_name "page")
    [ -n "$n" ] || return 0
    [ -e "$VAULT/$1/$n.md" ] || : > "$VAULT/$1/$n.md"
    obsidian_open "$1/$n.md"
}

open() {
    ~/.config/eww/scripts/panel.sh close   # one panel at a time
    ~/.config/eww/scripts/net.sh close
    ~/.config/eww/scripts/start.sh close
    mkdir -p "$VAULT"
    # filled in before the window maps so it doesn't resize while sliding in
    eww update notes_books="$(books)" notes_sel=-1 notes_book="" notes_pages="[]" notes_open=true
    eww open notes --screen "${1:-0}"
}

close() {
    [ "$(eww get notes_open)" = "true" ] || return 0
    eww update notes_open=false notes_sel=-1
    eww close notes   # hyprland animates the slide out
}

case "$1" in
    toggle) if [ "$(eww get notes_open)" = "true" ]; then close
            else open "$2"; fi ;;
    close)  close ;;
    book)   if [ "$(eww get notes_sel)" = "$2" ]; then eww update notes_sel=-1; exit 0; fi
            name=$(book_name "$2")
            [ -n "$name" ] || exit 1
            show_book "$name" "$2" ;;
    open)   name=$(book_name "$2")
            [ -n "$name" ] || exit 1
            last=$(files "$VAULT/$name" '%T@\t%P\n' | sort -rn | head -n1 | cut -f2)
            if [ -n "$last" ]; then obsidian_open "$name/$last"
            else new_page "$name"; fi ;;   # empty notebook: start its first page
    page)   printf %s "$2" | grep -Eq '^[0-9]+$' || exit 1
            rel=$(eww get notes_pages | jq -r --argjson i "$2" '.[].pages[] | select(.id == $i) | .rel')
            [ -n "$rel" ] && obsidian_open "$(eww get notes_book)/$rel" ;;
    new-book)
            name=$(ask_name "notebook")
            [ -n "$name" ] || exit 0
            mkdir -p "$VAULT/$name"
            refresh ;;
    new-page)
            name=$(eww get notes_book)
            [ -n "$name" ] && new_page "$name" ;;
    # deletes go to the trash (thunar's Trash), so a mistake can be undone from there
    del-book)
            name=$(book_name "$2")
            [ -n "$name" ] || exit 1
            confirm "$name" || exit 0
            gio trash "$VAULT/$name" && refresh ;;
    del-page)
            printf %s "$2" | grep -Eq '^[0-9]+$' || exit 1
            rel=$(eww get notes_pages | jq -r --argjson i "$2" '.[].pages[] | select(.id == $i) | .rel')
            [ -n "$rel" ] || exit 1
            confirm "${rel##*/}" || exit 0
            gio trash "$VAULT/$(eww get notes_book)/$rel" && refresh ;;
esac
