#!/usr/bin/env bash
# Animate the visual history of a file (or a renamed/re-formatted lineage of files) from git.
# One frame per version that renders differently from the one before it.
#
#   animate-history.sh [options] <path>...       image files tracked in git, treated as ONE lineage
#   animate-history.sh [options] --frames <dir>  pre-rendered PNGs (e.g. page screenshots), name order
#
# Options:
#   -o, --out FILE    output .gif or .mp4 (default: <first-path-stem>-history.gif)
#   -s, --size N|WxH  canvas size (default 512)
#   -f, --fps N       frames per second (default 2)
#   --hold N          seconds to hold the final frame (default 2)
#   --bg COLOR        canvas background, any CSS/ffmpeg colour name or hex (default white)
#   --label           caption each frame with date and short sha (needs Chrome/Chromium)
#   --keep DIR        keep the rendered frames in DIR
#   -C DIR            run against the git repo at DIR
#
# Needs: git, ffmpeg. SVG needs rsvg-convert or Chrome/Chromium. Bash 3.2 compatible.
set -euo pipefail

die() { printf 'animate-history: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*" >&2; }

out="" size="512" fps="2" hold="2" bg="white" label=0 keep="" frames_dir="" repo="."
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--out) out="$2"; shift 2 ;;
    -s|--size) size="$2"; shift 2 ;;
    -f|--fps) fps="$2"; shift 2 ;;
    --hold) hold="$2"; shift 2 ;;
    --bg) bg="$2"; shift 2 ;;
    --label) label=1; shift ;;
    --keep) keep="$2"; shift 2 ;;
    --frames) frames_dir="$2"; shift 2 ;;
    -C) repo="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done ;;
    -*) die "unknown option $1" ;;
    *) paths+=("$1"); shift ;;
  esac
done

command -v ffmpeg >/dev/null || die "ffmpeg not found (brew install ffmpeg / apt install ffmpeg)"
case "$size" in
  *x*) W="${size%x*}" H="${size#*x}" ;;
  *) W="$size" H="$size" ;;
esac
case "$W$H" in *[!0-9]*|"") die "bad --size $size" ;; esac

find_chrome() {
  local c
  for c in "${CHROME:-}" google-chrome google-chrome-stable chromium chromium-browser chrome \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
    [ -n "$c" ] || continue
    if [ -x "$c" ]; then printf '%s' "$c"; return 0; fi
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  return 1
}
CHROME="$(find_chrome || true)"
[ "$label" = 1 ] && [ -z "$CHROME" ] && die "--label needs Chrome or Chromium (set CHROME=/path/to/chrome)"

work="$(mktemp -d "${TMPDIR:-/tmp}/animate-history.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/frames"

# Fit any image onto the WxH canvas, centred, aspect preserved.
fit() { # in out
  ffmpeg -nostdin -v error -y -i "$1" -frames:v 1 \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=${bg}" \
    "$2"
}

# Render through Chrome: the image centred on the canvas, optional caption underneath.
chrome_render() { # in out caption
  local html="$work/wrap.html" cap="" img_h="$H"
  if [ -n "$3" ]; then
    img_h=$((H - 48))
    cap="<div style=\"height:48px;display:flex;align-items:center;justify-content:center;font:500 18px ui-monospace,Menlo,monospace;color:#666\">$3</div>"
  fi
  cat > "$html" <<EOF
<!doctype html><html><body style="margin:0;background:${bg};width:${W}px;height:${H}px;overflow:hidden">
<div style="height:${img_h}px;box-sizing:border-box;padding:16px"><img src="file://$1" style="width:100%;height:100%;object-fit:contain"></div>
${cap}</body></html>
EOF
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size="${W},${H}" --screenshot="$work/shot.png" "file://$html" >/dev/null 2>&1 \
    || die "Chrome failed to render $1"
  fit "$work/shot.png" "$2"
}

render() { # in out
  case "$(printf '%s' "${1##*.}" | tr '[:upper:]' '[:lower:]')" in
    svg)
      if command -v rsvg-convert >/dev/null; then
        rsvg-convert -w "$W" -h "$H" --keep-aspect-ratio -o "$work/svg.png" "$1" && fit "$work/svg.png" "$2"
      elif [ -n "$CHROME" ]; then chrome_render "$1" "$2" ""
      else die "SVG needs rsvg-convert (brew install librsvg) or Chrome/Chromium"; fi ;;
    *) fit "$1" "$2" ;;
  esac
}

pixel_hash() { ffmpeg -nostdin -v error -i "$1" -f rawvideo -pix_fmt rgb24 - | cksum | cut -d' ' -f1; }

kept=0 seen=0 prev=""
add_frame() { # rendered.png source caption
  local h; h="$(pixel_hash "$1")"
  seen=$((seen + 1))
  if [ "$h" = "$prev" ]; then log "  skip  $3  (renders identically to the previous frame)"; return; fi
  prev="$h"; kept=$((kept + 1))
  local f; f="$work/frames/$(printf '%04d' "$kept").png"
  if [ "$label" = 1 ]; then chrome_render "$2" "$f" "$3"; else cp "$1" "$f"; fi
  log "  keep  $3"
}

if [ -n "$frames_dir" ]; then
  [ -d "$frames_dir" ] || die "no such directory $frames_dir"
  frames_dir="$(cd "$frames_dir" && pwd)"
  : "${out:=$(basename "$frames_dir")-history.gif}"
  n=0
  for src in "$frames_dir"/*.png; do
    [ -e "$src" ] || die "no .png files in $frames_dir"
    n=$((n + 1))
    fit "$src" "$work/r.png"
    stem="$(basename "$src" .png)"
    add_frame "$work/r.png" "$src" "$(printf '%s' "$stem" | sed 's/_/ · /g')"
  done
else
  [ ${#paths[@]} -gt 0 ] || die "give at least one path, or --frames DIR (see --help)"
  repo="$(cd "$repo" && git rev-parse --show-toplevel)" || die "$repo is not a git repo"
  : "${out:=$(basename "${paths[0]%.*}")-history.gif}"
  # Every commit touching each path, following renames: "<unix time>\t<sha>\t<date>\t<path at that commit>".
  for p in "${paths[@]}"; do
    git -C "$repo" log --follow --diff-filter=d --format='%x01%ct%x09%H%x09%cs' --name-only -- "$p" \
      | awk -v FS='\t' '/^\001/ { sub(/^\001/, ""); c = $0; next } NF && c { print c "\t" $0; c = "" }'
  done | sort -t "$(printf '\t')" -k1,1n -u > "$work/versions.tsv"
  [ -s "$work/versions.tsv" ] || die "no history found for: ${paths[*]}"

  prev_blob=""
  while IFS="$(printf '\t')" read -r _ sha date path; do
    blob="$(git -C "$repo" rev-parse -q --verify "$sha:$path" 2>/dev/null)" || continue
    caption="$date · ${sha:0:7}"
    if [ "$blob" = "$prev_blob" ]; then log "  skip  $caption  (same bytes)"; seen=$((seen + 1)); continue; fi
    prev_blob="$blob"
    ext="${path##*.}"
    src="$work/v.$ext"
    git -C "$repo" cat-file blob "$blob" > "$src"
    render "$src" "$work/r.png" || { log "  skip  $caption  (could not render $path)"; continue; }
    add_frame "$work/r.png" "$src" "$caption"
  done < "$work/versions.tsv"
fi

[ "$kept" -gt 0 ] || die "nothing rendered"
log "kept $kept of $seen versions"

# Concat list with a duration per frame; the last frame is listed twice so its duration applies.
list="$work/list.txt" step="$(awk -v f="$fps" 'BEGIN { printf "%.4f", 1 / f }')"
: > "$list"
for f in "$work"/frames/*.png; do printf "file '%s'\nduration %s\n" "$f" "$step" >> "$list"; done
last="$(ls "$work"/frames/*.png | tail -n 1)"
printf "file '%s'\nduration %s\nfile '%s'\n" "$last" "$hold" "$last" >> "$list"

case "$out" in
  *.mp4)
    ffmpeg -nostdin -v error -y -f concat -safe 0 -i "$list" \
      -vf "fps=30,pad=ceil(iw/2)*2:ceil(ih/2)*2,format=yuv420p" -c:v libx264 -movflags +faststart "$out" ;;
  *.gif)
    ffmpeg -nostdin -v error -y -f concat -safe 0 -i "$list" \
      -fps_mode vfr -vf "split[a][b];[a]palettegen=stats_mode=single[p];[b][p]paletteuse=new=1:dither=sierra2_4a" -loop 0 "$out" ;;
  *) die "output must end in .gif or .mp4" ;;
esac

if [ -n "$keep" ]; then mkdir -p "$keep" && cp "$work"/frames/*.png "$keep"/; fi
printf '%s\n' "$out"
