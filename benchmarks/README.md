# Benchmarks

Token use and pass rate for `animate-file-history` across models and effort levels, driven by headless
Claude Code (`claude -p`).

```bash
benchmarks/run.sh -n 3 haiku:low haiku:medium sonnet:low sonnet:medium opus:low opus:medium
```

`make-fixture.sh` builds a throwaway repo: a logo redrawn 3 times, a formatting-only commit (must be deduped), a
pure move into `brand/` (history must be followed across the rename) and an unrelated dark variant (must be left
out). The prompt is `Animate the history of our logo into out.gif.` A run **passes** only when `out.gif` is
pixel-identical to the script run directly on the right lineage with `--label` (4 distinct versions of 6 commits,
dark variant left out), so a wrong file set, missing captions or a changed size all fail.

## Results (23 Oct 2026, 3 trials per cell, image path only)

Passes out of 3, and mean output tokens per run:

| Model | Low effort | Medium effort |
|---|---|---|
| Haiku | 3/3 · ~1,000 tokens | 3/3 · ~1,300 tokens |
| Sonnet | 3/3 · ~710 tokens | 3/3 · ~690 tokens |
| Opus | 3/3 · ~580 tokens | 3/3 · ~920 tokens |

- Every cell produced the identical, correct GIF, so the image workflow does not need a large model or high
  effort. Haiku at low effort is enough; it just writes a little more per run.
- The skill is mostly work the script does (git walk, render, dedupe, encode); the model picks paths and runs it
  once. The skill text itself is ~2k tokens.
- Total input is dominated by the host session's context (the system prompt and installed skill list), not by this
  skill, so it varies by setup and isn't tabulated.
- **Not benchmarked:** page animation (screenshots per commit, framework builds), which needs more judgement.
