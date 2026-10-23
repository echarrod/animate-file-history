---
name: animate-file-history
description: Turn a file's git history into an animation, one frame per visually different version - a logo's evolution, a page's redesigns. Use when asked to animate, replay or show the evolution of a logo, image, icon or web page over time.
argument-hint: <what to animate, e.g. all images matching "logo" | our home page> [frame time, e.g. 0.5s per frame]
---

# animate-file-history

Build a GIF (or MP4) of how something looked over the life of the repo. The request is in plain language
(`$ARGUMENTS`), so the job is: work out which files it means, collect every version of them from git, render
each one, drop versions that look the same as the one before, and stitch the rest into an animation.

The bundled script does the git walking, rendering, visual dedupe and encoding:
`scripts/animate-history.sh`, **relative to this skill's base directory** - not the user's repo. Below,
`$SKILL` stands for that directory; call the script by its absolute path. `--help` lists every option. Your part is choosing the files and,
for pages, producing the screenshots.

## 1. Check the tools

```bash
command -v git ffmpeg rsvg-convert; ls "/Applications/Google Chrome.app" 2>/dev/null; command -v chromium google-chrome
```

`ffmpeg` is required. SVG needs `rsvg-convert` (`brew install librsvg` / `apt install librsvg2-bin`) or
Chrome/Chromium. `--label` captions and HTML pages need Chrome/Chromium (`CHROME=/path` overrides
detection). If something is missing, say what and how to install it - don't silently drop SVG versions.

## 2. Resolve the request to files

Search the **whole history of the current branch**, not just today's tree - logos get renamed, moved and
re-exported, and deleted files still belong in the story:

```bash
git log --format= --name-only -- ':(glob,icase)**/*logo*' | sort -u
```

Search for what the thing is *called*, not only the user's word. A logo also lives in `favicon*`,
`apple-touch-icon*`, `*mark*`, `*lockup*`, `*wordmark*`, `*brand*` and the product's own name - early versions
are often only in the favicon. Widen the glob list accordingly and look at what comes back.

Filter to renderable types: `png jpg jpeg gif webp bmp svg` for images; `html` for static pages. Ignore
build output and vendored copies (`dist/`, `build/`, `node_modules/`, `.next/`).

Then group the matches into **lineages** - one lineage per animation:

- The same artwork across renames, moves or a format change (`logo.png` → `brand/logo.svg`) is **one**
  lineage. Pass all its paths to one run; the script merges them into a single timeline by commit date.
- Variants that coexist (`logo-dark.svg`, `logo-mono.svg`, `favicon.png`, sized exports like
  `logo@2x.png`) are **separate** lineages. Default to one animation per lineage, and only animate the
  variants the request plausibly means (usually the primary logo, not every favicon size).

If the grouping is genuinely ambiguous (several unrelated "logo" files, or nothing matches), show the
candidate list with commit counts (`git log --follow --oneline -- <path> | wc -l`) and ask before rendering.

## 3a. Images: run the script

```bash
"$SKILL/scripts/animate-history.sh" -o logo-history.gif --label <path> [<older-path> ...]
```

Useful options: `-s 512` or `-s 1200x800` canvas, `-t 0.25` seconds per version (default for images; page screenshots via `--frames` default to 0.8; use the user's value if
they gave one, e.g. "0.5s per frame" → `-t 0.5`), `--hold 1.5` seconds on the final frame, `--bg '#0b0b0b'` for logos drawn for dark backgrounds, `--keep DIR` to keep the frames,
`-o x.mp4` for video, `--skip <sha>` (repeatable) to drop a version the user doesn't want. It prints `keep`/`skip` per commit and `kept N of M versions` on stderr.

Paths are relative to the current directory (or `-C DIR`), like any git pathspec; run from the repo root
and pass them as the history list above shows them. The script follows renames itself (`git log
--follow`), so the current path alone is usually enough unless the file was re-created under a new name.

## 3b. Pages: screenshot each version, then run the script on the folder

A page needs rendering at each commit. Find the page's source
(`index.html`, `app/page.tsx`, `src/pages/index.vue`, ...) and list the commits that touched it **or what it
renders** - a home page's look also changes through its components and CSS:

```bash
git log --format='%H %cs' --reverse -- <page file> <its components/styles dirs>
```

If that is more than ~40 commits, sample (one per week or month, plus the first and last) and say so.
Screenshots go in one folder named `<YYYY-MM-DD>_<short-sha>.png`, so files sort by date and the name becomes
the caption.

- **Static HTML**: no build. Export the commit with `git archive <sha> | tar -x -C "$snap"` and screenshot the
  file with `"$CHROME" --headless=new --hide-scrollbars --window-size=1280,800 --screenshot=... "file://$snap/<page>.html"`.
  Delete `$snap` afterwards and keep it outside the repo.
- **Framework page** (React, Next, Vue, Astro, ...): it must run to render. Use `snapshot-commit.sh` per commit:

  ```bash
  "$SKILL/scripts/snapshot-commit.sh" -C <repo> -r /<route> -f https://<production site> <sha> "$shots"
  ```

  It exports the commit, installs **that commit's own lockfile** (cached per lockfile), starts the dev server
  (`-d 'cmd with {port}'` if it isn't `npm run dev -- --port {port}`), and screenshots through Playwright
  (`scripts/screenshot-page.mjs`, needs `playwright-core` and Chrome - the repo's own is found via
  `PLAYWRIGHT_DIR`). It waits for network idle and every `<img>`, dismisses a cookie banner, and prints one
  line: `ok`, `blank`, `error` (an error page such as "couldn't load in this browser") or `fail` (install or dev
  server). Only `ok` writes a PNG. Ask before running this if it means more than a handful of installs.

Check the results before animating, don't trust `ok` alone:

- **Never borrow the current `node_modules`.** Old commits import packages the current tree dropped (e.g.
  `react-router-dom`), and the page renders blank. That is why the script installs per commit.
- **`blank` / `error` / `fail` commits**: look at the dev log, try once to fix the cause (a missing env var, a
  wrong `-d` command, `--ignore-scripts` skipping a needed build step), otherwise skip the commit and say how many.
- **Broken images** (`broken-images=N` on the `ok` line, with the URLs): assets the dev server can't serve
  (platform-hosted paths like `/__l5e/...`, gitignored or uploaded files). `-f <production site>` fetches them
  from prod. If images are still broken, say so in the report - don't ship a GIF full of empty boxes silently.
  Fix on the fly rather than reporting afterwards.
- Look at a contact sheet of the frames (`ffmpeg -pattern_type glob -i '*.png' -vf scale=320:-1,tile=6x6 -frames:v 1 sheet.png`)
  before the final run.

Then:

```bash
"$SKILL/scripts/animate-history.sh" --frames "$shots" -s 1280x800 --label -o home-page-history.gif
```

Identical screenshots are dropped the same way as identical images, and so are blank (one flat colour) ones
(`--keep-blank` to keep them). Use a fixed window size for every
shot, and prefer `-o x.mp4` for long or detailed pages - GIFs of full pages get large.

## 3c. Across several repos

When the logo lives in more than one repo (an app, a dashboard, a website), run the script in each repo with
`--keep <dir>` and no `--label`, then copy each kept frame into one folder named
`<YYYY-MM-DD>_<repo>-<short-sha>.png` - the `keep` lines on stderr give the date and sha of each kept frame in
order. Add `-2`, `-3` to names that collide (several files changed in one commit). Then run
`--frames <folder> --label -t 0.25` on the merged folder for one timeline across all of them.

## 4. Report

Give the output path, how many versions were found and how many made it into the animation, the date
range, and anything skipped (unrenderable, failed builds, sampled out). Open it if asked (`open x.gif`).
Write output to wherever the user wants it, defaulting to the current directory - never commit it unless
asked.

## Gotchas

- **Dedupe is on rendered pixels, not bytes.** A re-exported PNG or reformatted SVG is skipped if it renders
  identically; a one-pixel nudge counts as a change. That is the point - don't add a byte-level filter on top.
- **SVGs that reference external files** (fonts, `<image href>`) render without them, since only the
  SVG itself is pulled from history. Embedded content is fine.
- **Animated GIF sources** contribute their first frame only.
- **Merge commits are not walked** - `git log` shows the file's changes on the branch that made them, which is
  what you want for a timeline.
- **Shallow clones** (CI, `--depth 1`) have no history. Check `git rev-parse --is-shallow-repository` and
  suggest `git fetch --unshallow` if it prints `true`.
- **Captions** need Chrome/Chromium because the bundled ffmpeg builds often lack `drawtext`.

## Model and effort

The judgement here is small (pick files, group lineages, choose a sample); the heavy lifting is the script and
shell loops. Default to **Sonnet on low effort**. Opus or higher effort buys nothing for this task, and a fork
or subagent is unnecessary. Raise effort only when lineage grouping is genuinely ambiguous.

Most of a run's tokens are the session's inherited context (CLAUDE.md, skill and tool lists, ~100k+), re-read
from cache each turn, not the work itself. A run in a lean session costs far less than one in a loaded one.

### Benchmarks

Measure with the session transcript (sums `usage` over assistant turns):

```bash
f=$(ls -t ~/.claude/projects/<project-dir>/*.jsonl | head -1)
jq -s '[.[]|select(.message.usage)|.message.usage]|{turns:length,out:(map(.output_tokens)|add),cache_read:(map(.cache_read_input_tokens)|add),cache_create:(map(.cache_creation_input_tokens)|add)}' "$f"
```

| Date | Model / effort | Task | Turns | Output tok | Cache read | Cache create | Result |
|---|---|---|---|---|---|---|---|
| 2026-10-23 | Sonnet 5.5 / low | storra home page, discovery only (before rendering) | 9 | 3.6k | 731k | 134k | files + route history found in ~7 calls |

Add a row per run (full run, not just discovery); compare Opus / higher effort only if a Sonnet-low run
gets the lineage or sampling wrong.
