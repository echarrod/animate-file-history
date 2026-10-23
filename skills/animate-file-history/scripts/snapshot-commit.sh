#!/usr/bin/env bash
# Screenshot a route of a web app as it was at one commit.
# Usage: snapshot-commit.sh [-C REPO] [-r /route] [-d 'dev command with {port}'] [-f https://prod.example] [-R REGEX=>URL] SHA OUTDIR
# Writes OUTDIR/<YYYY-MM-DD>_<short-sha>.png and prints "ok|blank|error|fail <date> <sha> <detail>" on stdout.
# Snapshots come from `git archive` (nothing touches REPO). Dependencies are installed from that commit's own
# lockfile, cached per lockfile so repeated commits reuse one install (old commits import packages the current
# tree no longer has, so borrowing the current node_modules gives blank pages). Local .env* files are copied
# into the throwaway snapshot so the app can start; their values are never printed.
set -uo pipefail

repo=. route=/ devcmd='npm run dev -- --port {port}'
fallback= rewrite=
while getopts "C:r:d:f:R:" o; do case $o in C) repo=$OPTARG;; r) route=$OPTARG;; d) devcmd=$OPTARG;; f) fallback=$OPTARG;; R) rewrite=$OPTARG;; *) exit 2;; esac; done
shift $((OPTIND - 1))
sha=${1:?usage: snapshot-commit.sh [-C REPO] [-r /route] [-d cmd] SHA OUTDIR} out=${2:?outdir}
here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$repo" rev-parse --show-toplevel) && sha=$(git -C "$repo" rev-parse --verify -q "$sha^{commit}") || { echo "fail - $1 not a commit"; exit 1; }
date=$(git -C "$repo" show -s --format=%cs "$sha") short=${sha:0:7}
mkdir -p "$out"; png="$out/${date}_${short}.png"

work=$(mktemp -d); snap=$work/s; mkdir -p "$snap"
cleanup() { [ -n "${pid:-}" ] && kill "$pid" 2>/dev/null; pkill -P "${pid:-0}" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT
git -C "$repo" archive "$sha" | tar -x -C "$snap" || { echo "fail $date $short archive"; exit 1; }
for f in "$repo"/.env "$repo"/.env.*; do [ -f "$f" ] && cp "$f" "$snap/" ; done
cd "$snap" || exit 1

# Install from this commit's lockfile, once per distinct lockfile.
cache=${SNAPSHOT_CACHE:-${TMPDIR:-/tmp}/animate-file-history-deps}; mkdir -p "$cache"
lock=$(ls bun.lock bun.lockb pnpm-lock.yaml yarn.lock package-lock.json 2>/dev/null | head -1)
key=$( { cat package.json "${lock:-/dev/null}"; } | shasum | cut -c1-16)
if [ ! -d "$cache/$key/node_modules" ]; then
  mkdir -p "$cache/$key.tmp" && cp package.json ${lock:+"$lock"} "$cache/$key.tmp/"
  case "$lock" in
    bun.lock*) inst="bun install --frozen-lockfile" ;;
    pnpm-lock.yaml) inst="pnpm install --frozen-lockfile" ;;
    yarn.lock) inst="yarn install --frozen-lockfile" ;;
    *) inst="npm ci --no-audit --no-fund --ignore-scripts" ;;
  esac
  ( cd "$cache/$key.tmp" && $inst >install.log 2>&1 ) \
    || ( cd "$cache/$key.tmp" && npm install --no-audit --no-fund --ignore-scripts --legacy-peer-deps >install.log 2>&1 ) \
    || { echo "fail $date $short install: $(tail -1 "$cache/$key.tmp/install.log")"; rm -rf "$cache/$key.tmp"; exit 1; }
  rm -f "$cache/$key.tmp/package.json" "$cache/$key.tmp/$lock"; mv "$cache/$key.tmp" "$cache/$key"
fi
ln -s "$cache/$key/node_modules" node_modules

port=$(python3 -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1])')
sh -c "${devcmd//\{port\}/$port}" >dev.log 2>&1 & pid=$!
up=0; for _ in $(seq 60); do curl -s -o /dev/null "http://localhost:$port$route" && { up=1; break; }; kill -0 "$pid" 2>/dev/null || break; sleep 1; done
[ $up = 1 ] || { echo "fail $date $short dev server did not start: $(tail -1 dev.log | cut -c1-120)"; exit 1; }

res=$(PLAYWRIGHT_DIR="${PLAYWRIGHT_DIR:-$repo}" node "$here/screenshot-page.mjs" "http://localhost:$port$route" "$png" ${fallback:+--fallback-origin "$fallback"} ${rewrite:+--rewrite "$rewrite"}); code=$?
broken=$(printf '%s' "$res" | sed -n 's/.*"brokenImages":\([0-9]*\).*/\1/p')
case $code in
  0) echo "ok $date $short broken-images=${broken:-0} $res" ;;
  3) echo "error $date $short $res"; rm -f "$png" ;;
  4) echo "blank $date $short $res"; rm -f "$png" ;;
  *) echo "fail $date $short screenshot: $res"; rm -f "$png" ;;
esac
