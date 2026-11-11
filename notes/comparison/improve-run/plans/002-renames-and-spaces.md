# Plan 002: Parse rename entries and paths with spaces correctly

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 26c40fa..HEAD -- src/parse.js test/parse.test.js`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-parity-test.md
- **Category**: bug
- **Planned at**: commit `26c40fa`, 2026-11-11

## Why this matters

`git mv` shows up as a staged edit instead of a rename, the `R` count in the
summary line is always missing, and the path list holds the similarity score
(`R100`) instead of the file name. Any path with a space is cut at the first
space. Both come from one line of code that treats every entry as
space-separated fields.

## Current state

`src/parse.js:22-27`:

```js
} else if (line.startsWith('1 ') || line.startsWith('2 ')) {
  const parts = line.split(' ');
  const xy = parts[1];
  if (xy[0] !== '.') s.staged += 1;
  if (xy[1] !== '.') s.modified += 1;
  s.paths.push(parts[8]);
```

Reference behaviour, `legacy/glance.py`: `1` lines split into at most 9 fields
(`split(' ', 8)`) so the path keeps its spaces; `2` lines split into at most 10
fields, add 1 to `renamed` (not `staged`), add 1 to `modified` when Y is not
`.`, and take the new path as the text before the tab in the last field.

Conventions: `node:test`, `assert/strict`, one `test()` per behaviour, see
`test/parse.test.js`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Tests | `npm test` | exit 0 |

## Scope

**In scope**:
- `src/parse.js`
- `test/parse.test.js`
- `test/parity.test.js` (only to remove cases from `KNOWN_FAILURES`)

**Out of scope**:
- `u` lines, detached HEAD, quoted paths — plans 003, 004 and later.
- `legacy/`, `test/expected/`.

## Git workflow

- Branch: `advisor/002-renames-and-spaces`
- One commit per step; e.g. `fix: parse rename entries`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Split `1` and `2` lines separately

Give `2 ` lines their own branch. For `1 `, use `line.split(' ')` with the
path being everything from field 9 on (`parts.slice(8).join(' ')`). For `2 `,
count `renamed` instead of `staged`, count `modified` when Y is not `.`, and
take the new path from field 10 onward, up to the tab.

**Verify**: `npm test` → existing tests pass except possibly the rename test (see Step 2).

### Step 2: Tests

Add tests to `test/parse.test.js`, modelled on the existing ones: a rename, a
rename then edit (`RM`), a modified path with a space, a rename where both
paths contain spaces. Update the existing rename test if it no longer matches
the reference behaviour.

**Verify**: `npm test` → exit 0, 4 new tests pass.

### Step 3: Shrink the known failures

Remove `rename-staged`, `rename-then-modified`, `rename-spaces` and
`modified-spaces` from `KNOWN_FAILURES` in `test/parity.test.js`.

**Verify**: `npm test` → exit 0; 13 parity tests pass, 3 skipped.

## Test plan

- 4 new unit tests in `test/parse.test.js`, modelled on the existing tests.
- 4 parity cases move from skipped to passing.

## Done criteria

- [ ] `npm test` exits 0
- [ ] 4 new tests in `test/parse.test.js` exist and pass
- [ ] `KNOWN_FAILURES` no longer contains `rename-staged`, `rename-then-modified`, `rename-spaces`, `modified-spaces`
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- The code at `src/parse.js:22-27` doesn't match the excerpt.
- Fixing renames requires changing `legacy/` or `test/expected/`.
- A parity case that passed before this plan now fails.

## Maintenance notes

- Plan 003 adds a `u ` branch next to the new `2 ` branch.
- Reviewer: check the tab split for `2` lines.
