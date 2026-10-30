# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Ed's public agent skills: markdown guidance plus small bash helpers under `scripts/`. There is no build, lint or test tooling. This repo is public, so
never commit credentials, personal data, private paths or anything specific to a private project.

## Layout

- `skills/<name>/SKILL.md` - the skill (frontmatter `name` + `description`, then the body).
- `skills/<name>/references/` - supporting detail loaded on demand.
- `skills/<name>/scripts/` - executable helpers the skill runs.
- `.claude-plugin/` - marketplace + plugin manifests so the repo installs as a Claude Code plugin.

## Keep the README in step

The README is the public face of every skill. Any change to a skill's behaviour, options, defaults, install
path or examples updates `README.md` in the same commit - including the options table and the example GIFs
in `assets/` when their output would now look different. Before committing, diff the skill's `--help` (or
SKILL.md options) against the README and fix any drift.

## Documentation vs code

When a repository's documentation and its existing code disagree, follow the conventions in the existing code for the task in hand, then sort each inconsistency out rather than only reporting it (Ed, 30 Oct 2026). For each one, ask Ed how to proceed - one AskUserQuestion question per inconsistency, naming the doc and the code that disagree, with the options (fix the doc to match the code, change the code to match the doc, or leave it) and your recommendation first - then carry out the answer in the same session. Fix one yourself without asking only when the doc is plainly stale (it names a file, flag or value the code has since replaced) and the fix is to the doc alone. In your final reply, list each inconsistency and what was done about it.
