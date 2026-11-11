#!/usr/bin/env bash
# Re-record legacy/cases/*.porcelain from real git. Each case builds a small
# repo in a temp dir and captures `git status --porcelain=v2 --branch`.
# Dates and identities are pinned so commit ids are stable across runs.
set -euo pipefail
OUT="$(cd "$(dirname "$0")/.." && pwd)/legacy/cases"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
export GIT_AUTHOR_DATE='2026-01-01T00:00:00Z' GIT_COMMITTER_DATE='2026-01-01T00:00:00Z'
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

fresh() { rm -rf "$WORK/r"; mkdir "$WORK/r"; cd "$WORK/r"; git init -q -b main
  printf 'a\n' > a.txt; printf 's\n' > 'has space.txt'; printf 'x\ny\nz\n' > old.txt
  git add .; git commit -qm init; }
record() { git -c core.quotePath=true status --porcelain=v2 --branch > "$OUT/$1.porcelain"; }

mkdir -p "$OUT"
fresh; record clean
fresh; printf 'b\n' >> a.txt; record modified
fresh; printf 'b\n' >> a.txt; git add a.txt; printf 'c\n' >> a.txt; record staged-and-modified
fresh; printf 'n\n' > added.txt; git add added.txt; record added-staged
fresh; git rm -q a.txt; record deleted-staged
fresh; printf 'u\n' > notes.md; record untracked
fresh; printf 'u\n' > 'new file.txt'; record untracked-spaces
fresh; printf 't\n' >> 'has space.txt'; record modified-spaces
fresh; git mv old.txt new.txt; record rename-staged
fresh; git mv old.txt new.txt; printf 'w\n' >> new.txt; record rename-then-modified
fresh; git mv 'has space.txt' 'now spaced.txt'; record rename-spaces
fresh; printf 'e\n' > "caf$(printf '\303\251').txt"; record quoted-nonascii
fresh; git checkout -qb other; printf 'theirs\n' > a.txt; git commit -qam theirs
  git checkout -q main; printf 'ours\n' > a.txt; git commit -qam ours
  git merge -q other >/dev/null 2>&1 || true; record conflict
fresh; git clone -q --bare . "$WORK/origin.git"; git remote add origin "$WORK/origin.git"
  git fetch -q origin; git branch -q -u origin/main
  git clone -q "$WORK/origin.git" "$WORK/other"; (cd "$WORK/other" && printf 'r\n' > r.txt && git add r.txt && git commit -qm remote && git push -q origin main)
  printf 'l\n' > l.txt; git add l.txt; git commit -qm local; git fetch -q origin; record ahead-behind
  rm -rf "$WORK/origin.git" "$WORK/other"
fresh; git checkout -q --detach HEAD; record detached
rm -rf "$WORK/r"; mkdir "$WORK/r"; cd "$WORK/r"; git init -q -b main; printf 'n\n' > first.txt; record initial
echo "recorded $(ls "$OUT"/*.porcelain | wc -l | tr -d ' ') cases with $(git --version)"
