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
