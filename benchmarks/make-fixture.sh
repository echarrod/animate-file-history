#!/usr/bin/env bash
# Build a throwaway repo with a logo history: 4 redesigns, a formatting-only commit (should be deduped),
# a pure move to brand/, and an unrelated dark variant. Usage: make-fixture.sh DIR
set -euo pipefail
dir=${1:?usage: make-fixture.sh DIR}
rm -rf "$dir"; mkdir -p "$dir"; cd "$dir"
git init -q -b main
git config user.name Bench; git config user.email bench@example.com

svg() { # fill shape
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200"><rect width="200" height="200" fill="#fff"/>%s<text x="100" y="185" font-size="20" text-anchor="middle" fill="%s">Acme</text></svg>\n' "$2" "$1"
}
commit() { GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -qam "$2" 2>/dev/null || { git add -A; GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -qm "$2"; }; }

echo hello > README.md; git add -A; commit 2024-01-01T10:00:00 init
svg '#c00' '<circle cx="100" cy="90" r="60" fill="#c00"/>' > logo.svg; git add -A; commit 2024-02-01T10:00:00 "add logo"
svg '#06c' '<circle cx="100" cy="90" r="60" fill="#06c"/>' > logo.svg; commit 2024-04-01T10:00:00 "recolour logo"
svg '#06c' '<rect x="40" y="30" width="120" height="120" rx="20" fill="#06c"/>' > logo.svg; commit 2024-06-01T10:00:00 "square logo"
{ printf '<?xml version="1.0"?>\n\n'; cat logo.svg; } > tmp && mv tmp logo.svg; commit 2024-07-01T10:00:00 "reformat svg only"
mkdir brand; git mv logo.svg brand/logo.svg; commit 2024-08-01T10:00:00 "move logo to brand/"
svg '#093' '<polygon points="100,25 165,150 35,150" fill="#093"/>' > brand/logo.svg; git add -A; commit 2024-09-01T10:00:00 "triangle logo"
svg '#fff' '<polygon points="100,25 165,150 35,150" fill="#fff"/>' | sed 's/fill="#fff"\/><polygon/fill="#111"\/><polygon/' > brand/logo-dark.svg; git add -A; commit 2024-10-01T10:00:00 "dark variant"
