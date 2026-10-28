#!/usr/bin/env bash
# Build the made-up Acme logo history behind assets/demo.gif: 21 wordmark versions, some big redesigns and some
# tiny tweaks (size, colour, weight). Usage: make-demo-fixture.sh DIR, then
#   animate-history.sh -C DIR --label --size 360 -t 0.5 -o assets/demo.gif logo.svg
set -euo pipefail
dir=$1; rm -rf "$dir"; mkdir -p "$dir"; cd "$dir"
git init -q -b main; git config user.name Acme; git config user.email acme@example.com
# w FONT SIZE WEIGHT FILL BG [style] [letter-spacing] [extra]
w() { printf '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="200" viewBox="0 0 400 200">%s<text x="200" y="%s" font-family="%s" font-size="%s" font-weight="%s" font-style="%s" letter-spacing="%s" text-anchor="middle" fill="%s">Acme</text>%s</svg>\n' \
  "$([ "$5" = none ] && echo '' || echo "<rect width=\"400\" height=\"200\" fill=\"$5\"/>")" "${9:-118}" "$1" "$2" "$3" "${6:-normal}" "${7:-0}" "$4" "${8:-}"; }
n=0
v() { n=$((n+1)); local m=$(( (n-1)*6 )); local y=$((2015 + m/12)) mo=$((1 + m%12))
  w "$@" > logo.svg; git add -A
  local d; d=$(printf '%04d-%02d-01T10:00:00' $y $mo)
  GIT_AUTHOR_DATE=$d GIT_COMMITTER_DATE=$d git commit -qm "logo v$n"; }
v "Courier New, monospace" 56 400 "#222" "#fff"
v "Courier New, monospace" 70 400 "#222" "#fff"
v "Courier New, monospace" 70 700 "#222" "#fff"
v "Brush Script MT, cursive" 80 400 "#d4202a" "#fff"
v "Brush Script MT, cursive" 80 400 "#e8590c" "#fff"
v "Georgia, serif" 72 400 "#1b1b1b" "#fff" normal 0 '<rect x="60" y="45" width="280" height="100" fill="none" stroke="#1b1b1b" stroke-width="3"/>'
v "Georgia, serif" 72 400 "#1b1b1b" "#fff" normal 0 '<rect x="60" y="45" width="280" height="100" fill="none" stroke="#1b1b1b" stroke-width="6"/>'
v "Georgia, serif" 72 400 "#fff" "#1b1b1b" italic 0
v "Georgia, serif" 72 400 "#f2c14e" "#1b1b1b" italic 0
v "Helvetica Neue, Arial, sans-serif" 76 700 "#0057d9" "#fff" normal -3
v "Helvetica Neue, Arial, sans-serif" 76 700 "#0a7d5a" "#fff" normal -3
v "Helvetica Neue, Arial, sans-serif" 90 700 "#0a7d5a" "#fff" normal -4
v "Futura, Avenir, sans-serif" 84 500 "#6b2fd6" "#fff" normal 6
v "Futura, Avenir, sans-serif" 84 500 "#6b2fd6" "#f3ecff" normal 6
v "Futura, Avenir, sans-serif" 84 500 "#c026d3" "#f3ecff" normal 6
v "Didot, Bodoni 72, serif" 92 400 "#111" "#fff" normal 0
v "Didot, Bodoni 72, serif" 92 400 "#111" "#fff" normal 10
v "Impact, Haettenschweiler, sans-serif" 88 400 "#ff3b30" "#111" normal 2
v "Impact, Haettenschweiler, sans-serif" 88 400 "#ffd60a" "#111" normal 2
v "Avenir Next, Helvetica Neue, sans-serif" 70 300 "#0f766e" "#fff" normal 1
v "Avenir Next, Helvetica Neue, sans-serif" 70 600 "#0f766e" "#fff" normal 1
