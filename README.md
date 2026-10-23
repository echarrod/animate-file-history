# skillsed

Ed's public agent skills: markdown guidance for Claude Code and other agents.

## Layout

- `skills/<name>/SKILL.md` - the skill (frontmatter `name` + `description`, then the body).
- `skills/<name>/references/` - supporting detail loaded on demand.

## Using a skill

Symlink or copy `skills/<name>` into `~/.claude/skills/` (user level) or a project's `.claude/skills/`.
