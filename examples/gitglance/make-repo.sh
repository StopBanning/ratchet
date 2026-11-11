#!/usr/bin/env bash
# Rebuild the gitglance fixture as a git repo at commit 26c40fa, the commit the
# example plans were written against.  Usage: make-repo.sh <empty target dir>
set -euo pipefail
SRC="$(cd "$(dirname "$0")/fixture-repo" && pwd)"
DEST="${1:?usage: make-repo.sh <target dir>}"
mkdir -p "$DEST"; cp -R "$SRC"/. "$DEST"/; cd "$DEST"
chmod +x legacy/glance.py scripts/record-cases.sh src/cli.js
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.com GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.com
git init -q -b main
git add legacy scripts .gitignore
GIT_AUTHOR_DATE=2026-10-01T10:00:00Z GIT_COMMITTER_DATE=2026-10-01T10:00:00Z git commit -qm "legacy: Python gitglance with recorded cases"
git add .
GIT_AUTHOR_DATE=2026-10-20T10:00:00Z GIT_COMMITTER_DATE=2026-10-20T10:00:00Z git commit -qm "port: Node version of gitglance (WIP, see README)"
git rev-parse --short HEAD
