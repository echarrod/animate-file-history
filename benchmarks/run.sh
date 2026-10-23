#!/usr/bin/env bash
# Benchmark animate-file-history across model/effort configs using headless Claude Code.
# Usage: run.sh [-n TRIALS] [model:effort ...]   (default: haiku, sonnet, opus x low, medium)
# Needs the skill installed (scripts/link-skills.sh or the plugin), ffmpeg, ffprobe, jq. Spends real tokens.
# Prints one TSV row per run: model effort trial pass frames turns input output cache_read cache_create cost_usd seconds
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
trials=1
if [ "${1:-}" = "-n" ]; then trials=$2; shift 2; fi
configs=("$@"); [ ${#configs[@]} -gt 0 ] || configs=(haiku:low haiku:medium sonnet:low sonnet:medium opus:low opus:medium)
prompt='Animate the history of our logo into out.gif.'

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
"$here/make-fixture.sh" "$work/repo" >/dev/null

# Ground truth: the script run directly on the right lineage (4 distinct versions of 6 commits).
want=$(cd "$work/repo" && "$here/../skills/animate-file-history/scripts/animate-history.sh" -o "$work/want.gif" --label brand/logo.svg 2>/dev/null >/dev/null \
  && ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$work/want.gif")

# Pixel identity of the output, not just its frame count: hash of every decoded frame.
sig() { ffmpeg -v error -i "$1" -f framemd5 - 2>/dev/null | grep -v '^#' | awk -F, '{print $6}' | sort | uniq | shasum | cut -d" " -f1; }
frames() { ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 "$1" 2>/dev/null || echo 0; }

want_sig=$(sig "$work/want.gif")

for cfg in "${configs[@]}"; do
  model=${cfg%%:*} effort=${cfg##*:}
  for t in $(seq "$trials"); do
    rm -f "$work/repo/out.gif"
    start=$(date +%s)
    json=$(cd "$work/repo" && claude -p "$prompt" --model "$model" --effort "$effort" --output-format json \
      --permission-mode bypassPermissions --no-session-persistence </dev/null 2>/dev/null) || json='{}'
    secs=$(( $(date +%s) - start ))
    got=$(frames "$work/repo/out.gif")
    pass=no; [ "$got" = "$want" ] && [ "$(sig "$work/repo/out.gif")" = "$want_sig" ] && pass=yes
    printf '%s\t%s\t%s\t%s\t%s\t' "$model" "$effort" "$t" "$pass" "$got"
    jq -r --arg s "$secs" '[.num_turns, .usage.input_tokens, .usage.output_tokens, .usage.cache_read_input_tokens,
      .usage.cache_creation_input_tokens, .total_cost_usd, $s] | @tsv' <<<"$json"
  done
done
