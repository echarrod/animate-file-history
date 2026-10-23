<h1 align="center">skillsed</h1>

<p align="center">
  <em>Small, sharp agent skills. Ask in plain English; get something you can show people.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/github/stars/echarrod/skillsed?style=flat-square&color=111111&label=stars" alt="Stars">
  <img src="https://img.shields.io/badge/Claude%20Code-plugin-111111?style=flat-square" alt="Claude Code plugin">
  <img src="https://img.shields.io/badge/works%20with-any%20SKILL.md%20agent-111111?style=flat-square" alt="Works with any SKILL.md agent">
  <img src="https://img.shields.io/badge/license-MIT-111111?style=flat-square" alt="MIT license">
</p>

---

## animate-file-history

<p align="center">
  <img src="assets/demo.gif" width="360" alt="A logo evolving through five versions from 2019 to 2025: a serif wordmark in a box, a blue rounded square, a purple-pink gradient square, the same gradient as a circle, and a teal-green circle with a play icon. Each frame is captioned with its commit date and short sha.">
</p>

<p align="center">
  <strong>Your logo's whole life story, straight out of git.</strong><br>
  One frame per version that actually <em>looks</em> different. Re-exports and reformatted SVGs are skipped.
</p>

```
/animate-file-history all images matching "logo"
/animate-file-history all versions of our home page
```

### In the wild: Storra

<p align="center">
  <img src="assets/storra-logo-history.gif" width="360" alt="The Storra logo evolving through 24 versions in 2026: a lowercase wordmark, black and red S monograms, then the folded-page mark and the Storra lockup in black and orange.">
</p>

<p align="center">
  Seven months of <a href="https://github.com/storra-eng">Storra</a>'s logo, from a lowercase wordmark through
  red S monograms to today's folded-page mark - stitched from favicons, headers and brand lockups across 27
  commits.
</p>

The agent works out which files you mean (following renames, moves and `png` → `svg` switches across the
whole history), pulls every version out of git, renders each one, drops versions whose pixels are identical
to the one before, and stitches the rest into a GIF or MP4 with date and commit captions.

- **Logos, icons, images**: `png`, `jpg`, `webp`, `gif`, `bmp`, `svg`.
- **Web pages**: static HTML is screenshotted at each commit; framework pages (React, Next, Vue, ...) are
  built and screenshotted in throwaway worktrees, sampled when the history is long.
- **Visual dedupe**: compared on rendered pixels, not bytes, so only real visual changes become frames.

Needs `git` and `ffmpeg`. SVGs need `rsvg-convert` or Chrome/Chromium; captions and pages need
Chrome/Chromium.

The engine is a plain bash script you can also run by hand:
[`skills/animate-file-history/scripts/animate-history.sh`](skills/animate-file-history/scripts/animate-history.sh)
(`--help` for options).

## Install

**Claude Code**, as two separate prompts:

```
/plugin marketplace add echarrod/skillsed
```
```
/plugin install skillsed@skillsed
```

Or in one step on Claude Code 2.1.275 or later:

```
/plugin install skillsed --marketplace echarrod/skillsed
```

Installed as a plugin, the command is namespaced: `/skillsed:animate-file-history`.

**Any agent that reads `SKILL.md`** (Codex, Cursor, Gemini CLI, OpenCode, Copilot and others):

```bash
npx skills add echarrod/skillsed
```

**By hand**: clone the repo and symlink or copy a skill folder into `~/.claude/skills/` (every project) or
a project's `.claude/skills/`. Installed this way the command is plain `/animate-file-history`.

```bash
git clone https://github.com/echarrod/skillsed.git
ln -s "$PWD/skillsed/skills/animate-file-history" ~/.claude/skills/animate-file-history
```

## Layout

- `skills/<name>/SKILL.md` - the skill (frontmatter `name` + `description`, then the body).
- `skills/<name>/scripts/` - executable helpers the skill runs.
- `skills/<name>/references/` - supporting detail loaded on demand.

## License

[MIT](LICENSE)
