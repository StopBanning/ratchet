# Plan 001: Add a parity test against legacy/glance.py

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 26c40fa..HEAD -- src/ test/ legacy/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `26c40fa`, 2026-11-11

## Why this matters

The Node port in `src/` is meant to print exactly what `legacy/glance.py` prints
for the same input (README). Nothing checks that today: the Node tests use
hand-written inputs only, while 16 inputs recorded from real git sit unused in
`legacy/cases/`. A parity test turns "reach parity" into a number and gives
plans 002–004 a verification gate.

## Current state

- `legacy/glance.py` — reference; reads porcelain v2 on stdin, prints JSON with sorted keys.
- `legacy/cases/*.porcelain` — 16 recorded inputs.
- `src/parse.js` — `parse(text)` returns the same object shape as the Python `summarize`.
- `test/parse.test.js` — `node:test` + `node:assert/strict`, one `test()` per behaviour. Match its style.

Today 7 cases differ: `conflict`, `detached`, `modified-spaces`,
`quoted-nonascii`, `rename-spaces`, `rename-staged`, `rename-then-modified`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Tests | `npm test` | exit 0 |
| Reference output | `python3 legacy/glance.py < legacy/cases/<name>.porcelain` | one JSON line |

## Scope

**In scope**:
- `test/parity.test.js` (create)
- `test/expected/*.json` (create)

**Out of scope**:
- `src/` — this plan only measures; fixes are plans 002–004.
- `legacy/` — the reference must not change.

## Git workflow

- Branch: `advisor/001-parity-test`
- One commit, e.g. `test: add parity test against legacy`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Generate expected outputs

For every `legacy/cases/<name>.porcelain`, write
`python3 legacy/glance.py < legacy/cases/<name>.porcelain > test/expected/<name>.json`.

**Verify**: `ls test/expected/*.json | wc -l` → `16`

### Step 2: Write the parity test

Create `test/parity.test.js`: for each case, `parse()` the porcelain file and
`assert.deepEqual` the result against the expected JSON. Declare
`const KNOWN_FAILURES = new Set([...])` with the 7 cases listed above and run
those with `test.skip` so the suite stays green.

**Verify**: `npm test` → exit 0; output shows 9 parity tests passing and 7 skipped.

## Test plan

- 16 parity tests (9 pass, 7 skipped) in `test/parity.test.js`.
- Existing tests unchanged and passing.

## Done criteria

- [ ] `npm test` exits 0
- [ ] `test/parity.test.js` exists; 9 parity tests pass, 7 are skipped
- [ ] `test/expected/` holds 16 files
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- `python3 legacy/glance.py` fails on any case.
- More or fewer than 7 cases differ.

## Maintenance notes

- Plans 002–004 shrink `KNOWN_FAILURES`. When it is empty, the port has parity.
- If cases are re-recorded, regenerate `test/expected/`.
