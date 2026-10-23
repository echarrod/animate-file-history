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
#   -t, --frame-time S  seconds each version is shown (default 0.25)
#   -f, --fps N       alternative to --frame-time: versions per second
#                     (default 0.25s per version; 0.8s with --frames, as full pages need time to read)
#   --hold N          seconds to hold the final frame (default 1.5)
#   --bg COLOR        canvas background, any CSS/ffmpeg colour name or hex (default white)
#   --label           caption each frame with date and short sha (needs Chrome/Chromium)
#   --keep DIR        keep the rendered frames in DIR
#   --keep-blank      keep frames that are one flat colour (skipped by default)
#   --skip SHA        leave out the version from this commit (repeatable, any unique sha prefix)
#   -C DIR            run against the git repo at DIR
#
# Needs: git, ffmpeg. SVG needs rsvg-convert or Chrome/Chromium. Bash 3.2 compatible.
set -euo pipefail

die() { printf 'animate-history: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*" >&2; }

skips=" " out="" size="512" frame_time="" hold="1.5" bg="white" label=0 keep_blank=0 keep="" frames_dir="" repo="."
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--out) out="$2"; shift 2 ;;
    -s|--size) size="$2"; shift 2 ;;
    -t|--frame-time) frame_time="$2"; shift 2 ;;
    -f|--fps) frame_time="$(awk -v f="$2" 'BEGIN { printf "%.4f", 1 / f }')"; shift 2 ;;
    --hold) hold="$2"; shift 2 ;;
    --bg) bg="$2"; shift 2 ;;
    --label) label=1; shift ;;
    --keep) keep="$2"; shift 2 ;;
    --keep-blank) keep_blank=1; shift ;;
    --skip) skips="$skips$2 "; shift 2 ;;
    --frames) frames_dir="$2"; shift 2 ;;
    -C) repo="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
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

# Fit any image onto a solid WxH canvas, centred, aspect preserved, transparency flattened onto --bg.
fit() { # in out
  ffmpeg -nostdin -v error -y -i "$1" -f lavfi -i "color=c=${bg}:s=${W}x${H}" -filter_complex \
    "[0:v]scale=${W}:${H}:force_original_aspect_ratio=decrease[s];[1:v][s]overlay=(W-w)/2:(H-h)/2,format=rgb24" \
    -frames:v 1 "$2"
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
  rm -f "$work/shot.png"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size="${W},${H}" --screenshot="$work/shot.png" "file://$html" >/dev/null 2>&1 || return 1
  [ -s "$work/shot.png" ] || return 1
  fit "$work/shot.png" "$2"
}

render() { # in out
  case "$(printf '%s' "${1##*.}" | tr '[:upper:]' '[:lower:]')" in
    svg)
      if command -v rsvg-convert >/dev/null; then
        rsvg-convert -w "$W" -h "$H" --keep-aspect-ratio -o "$work/svg.png" "$1" && fit "$work/svg.png" "$2"
      elif [ -n "$CHROME" ]; then
        # Chrome draws a broken-image icon for invalid SVG instead of failing, so check it parses first.
        if command -v xmllint >/dev/null && ! xmllint --noout "$1" 2>/dev/null; then return 1; fi
        chrome_render "$1" "$2" ""
      else die "SVG needs rsvg-convert (brew install librsvg) or Chrome/Chromium"; fi ;;
    *) fit "$1" "$2" ;;
  esac
}

pixel_hash() { ffmpeg -nostdin -v error -i "$1" -f rawvideo -pix_fmt rgb24 - | cksum | cut -d' ' -f1; }

kept=0 seen=0 prev=""
# A frame that is one flat colour (a page that failed to render, an empty or fully transparent image).
is_blank() { # rendered.png
  ffmpeg -v error -i "$1" -vf "scale=32:20,format=gray" -f rawvideo - 2>/dev/null | od -An -v -tu1 | tr -s ' \n' '\n' \
    | awk 'NF { n++; s += $1; q += $1 * $1 } END { m = s / n; exit !(n > 0 && q / n - m * m < 1) }'
}

add_frame() { # rendered.png source caption [counted]
  local h; h="$(pixel_hash "$1")"
  [ -n "${4:-}" ] || seen=$((seen + 1))
  if [ "$keep_blank" != 1 ] && is_blank "$1"; then log "  skip  $3  (blank: one flat colour; --keep-blank to keep)"; return; fi
  if [ "$h" = "$prev" ]; then log "  skip  $3  (renders identically to the previous frame)"; return; fi
  prev="$h"; kept=$((kept + 1))
  local f; f="$work/frames/$(printf '%04d' "$kept").png"
  if [ "$label" = 1 ] && ! chrome_render "$2" "$f" "$3"; then
    log "  warn  $3  (caption render failed, using the frame without it)"; cp "$1" "$f"
  elif [ "$label" != 1 ]; then cp "$1" "$f"; fi
  log "  keep  $3"
}

if [ -n "$frames_dir" ]; then
  [ -d "$frames_dir" ] || die "no such directory $frames_dir"
  frames_dir="$(cd "$frames_dir" && pwd)"
  : "${out:=$(basename "$frames_dir")-history.gif}"
  for src in "$frames_dir"/*.png; do
    [ -e "$src" ] || die "no .png files in $frames_dir"
    fit "$src" "$work/r.png"
    stem="$(basename "$src" .png)"
    add_frame "$work/r.png" "$src" "$(printf '%s' "$stem" | sed 's/_/ · /g')"
  done
else
  [ ${#paths[@]} -gt 0 ] || die "give at least one path, or --frames DIR (see --help)"
  # Paths are relative to the -C dir (default: cwd), like git's own pathspecs; make them root-relative.
  prefix="$(git -C "$repo" rev-parse --show-prefix)" || die "$repo is not a git repo"
  repo="$(git -C "$repo" rev-parse --show-toplevel)"
  : "${out:=$(basename "${paths[0]%.*}")-history.gif}"
  # Every commit touching each path, following renames: "<unix time>\t<sha>\t<date>\t<path at that commit>".
  for p in "${paths[@]}"; do
    # No --reverse: combined with --follow it stops following at the first rename. Reverse by hand instead.
    git -C "$repo" log --follow --diff-filter=d --format='%x01%ct%x09%H%x09%cs' --name-only -- "$prefix$p" \
      | awk -v FS='\t' '/^\001/ { sub(/^\001/, ""); c = $0; next } NF && c { print c "\t" $0; c = "" }' \
      | awk '{ l[NR] = $0 } END { for (i = NR; i >= 1; i--) print l[i] }'
  done | sort -s -t "$(printf '\t')" -k1,1n | awk -F '\t' '!seen[$2]++' > "$work/versions.tsv"
  [ -s "$work/versions.tsv" ] || die "no history found for: ${paths[*]}"

  prev_blob=""
  while IFS="$(printf '\t')" read -r _ sha date path; do
    seen=$((seen + 1))
    caption="$date · ${sha:0:7}"
    for k in $skips; do
      case "$sha" in "$k"*) log "  skip  $caption  (--skip)"; continue 2 ;; esac
    done
    blob="$(git -C "$repo" rev-parse -q --verify "$sha:$path" 2>/dev/null)" \
      || { log "  skip  $caption  ($path missing at this commit)"; continue; }
    if [ "$blob" = "$prev_blob" ]; then log "  skip  $caption  (same bytes)"; continue; fi
    prev_blob="$blob"
    case "${path##*/}" in *.*) ext="${path##*.}" ;; *) ext=bin ;; esac
    src="$work/v.$ext"
    git -C "$repo" cat-file blob "$blob" > "$src"
    render "$src" "$work/r.png" || { log "  skip  $caption  (could not render $path)"; continue; }
    add_frame "$work/r.png" "$src" "$caption" counted
  done < "$work/versions.tsv"
fi

[ "$kept" -gt 0 ] || die "nothing rendered"
log "kept $kept of $seen versions"

# Concat list with a duration per frame. The last frame gets --hold, and is listed again because
# the concat demuxer ignores the duration of the final entry.
list="$work/list.txt" step="${frame_time:-$([ -n "$frames_dir" ] && echo 0.8 || echo 0.25)}"
last="$(ls "$work"/frames/*.png | tail -n 1)"
: > "$list"
for f in "$work"/frames/*.png; do
  d="$step"; [ "$f" = "$last" ] && d="$hold"
  printf "file '%s'\nduration %s\n" "$f" "$d" >> "$list"
done
printf "file '%s'\n" "$last" >> "$list"
total="$(awk -v n="$kept" -v s="$step" -v h="$hold" 'BEGIN { printf "%.4f", (n - 1) * s + h }')"

case "$out" in
  *.mp4)
    ffmpeg -nostdin -v error -y -f concat -safe 0 -i "$list" \
      -vf "fps=30,pad=ceil(iw/2)*2:ceil(ih/2)*2,format=yuv420p" -c:v libx264 -movflags +faststart -t "$total" "$out" ;;
  *.gif)
    ffmpeg -nostdin -v error -y -f concat -safe 0 -i "$list" \
      -fps_mode vfr -vf "split[a][b];[a]palettegen=stats_mode=single[p];[b][p]paletteuse=new=1:dither=sierra2_4a" -loop 0 "$out" ;;
  *) die "output must end in .gif or .mp4" ;;
esac

if [ -n "$keep" ]; then mkdir -p "$keep" && cp "$work"/frames/*.png "$keep"/; fi
printf '%s\n' "$out"
