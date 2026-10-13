#!/bin/sh
# Escape: Close Open Eww Panel
for p in panel net start notes tray dash themes; do
    [ "$(eww get ${p}_open)" = "true" ] && ~/.config/eww/scripts/$p.sh close
done
exit 0
