# Advisor run: gitglance, findings

Run of this skill against `fixture-repo/` rebuilt at commit `26c40fa`
(`./make-repo.sh <dir>`), 2026-11-11. Effort `standard`, non-interactive.

## Recon

- Node ESM, no dependencies. `npm test` → `node --test test/`: 6 tests, 6 pass.
- No lint, typecheck or formatter.
- **Reference:** `legacy/glance.py`, the Python original. README: "Until the
  port reaches parity, the Python version is the source of truth." Runs
  read-only: `python3 legacy/glance.py < <porcelain file>` prints one JSON line.
- **Cases:** 16 files in `legacy/cases/*.porcelain`, recorded from real git by
  `scripts/record-cases.sh` with pinned dates and identities. Ran the recorder
  twice into a temp copy: byte-identical. The Node tests do not use them.
- **Reference vs port today** (ran both on all 16 cases): 9 match, 7 differ:
  `conflict`, `detached`, `modified-spaces`, `quoted-nonascii`,
  `rename-spaces`, `rename-staged`, `rename-then-modified`.
- **Pins** (tests asserting today's behaviour, found by reading every test in
  `test/` against the reference's output):
  - `test/parse.test.js:33-37` "rename shows up as a staged change": asserts
    `staged === 1` and `renamed === 0` for a rename. The reference says
    `staged 0, renamed 1`. Its input is hand-written and separates the two paths
    with a **space**; real git separates them with a **tab** (see
    `legacy/cases/rename-staged.porcelain`). The pin asserts the bug, and its
    input format is wrong too.
  - `test/parse.test.js:39-42` "detached head keeps the marker as the branch
    name": asserts `branch === '(detached)'`. The reference says `branch null,
    detached true`. Also asserts the bug.
  - The other four tests agree with the reference.
- **Live surface:** the CLI runs real `git status --porcelain=v2 --branch`
  (`src/cli.js:14`). Safe live check: build a throwaway repo in a temp dir. No
  script does that today.

## Findings

| # | Finding | Category | Impact | Effort | Confidence | Route | Reference | Evidence |
|---|---------|----------|--------|--------|------------|-------|-----------|----------|
| 1 | No parity check: the recorded cases and the reference are unused, so nobody can see that 7 of 16 cases differ | tests | HIGH | S | HIGH | PLAN | `legacy/glance.py` on `legacy/cases/` | `README.md:5-12`, `test/parse.test.js` |
| 2 | Rename entries counted as staged, `renamed` stays 0, path taken from the score field; any path with a space is cut at the first space. Cases: `rename-staged`, `rename-then-modified`, `rename-spaces`, `modified-spaces` | correctness | HIGH | S | HIGH | PLAN | same | `src/parse.js:22-27`; pin `test/parse.test.js:33-37` |
| 3 | Unmerged entries ignored, conflicts never shown. Case: `conflict` | correctness | HIGH | S | HIGH | PLAN | same | `src/parse.js` has no `u ` branch |
| 4 | Detached HEAD reported as branch `(detached)`. Case: `detached` | correctness | MED | S | HIGH | PLAN | same | `src/parse.js:12-13`; pin `test/parse.test.js:39-42` |
| 5 | Quoted paths (non-ASCII names) not unquoted. Case: `quoted-nonascii` | correctness | MED | S | HIGH | PLAN | same | `src/parse.js:30` |
| 6 | CLI exits 0 when git fails (e.g. outside a repo) | dx | LOW | S | HIGH | DIRECT | real git | `src/cli.js:16-18`; seen: `exit outside repo=0` |

Planned: 1 (baseline, first) and 2. Plans for 3–5 follow the same shape as
2 and are left as index rows in this example.

## Do directly

**6. Exit code on git failure.** Not worth a plan: two lines in one file.

- In `src/cli.js`, inside the `catch` (line 16), add `process.exitCode = 1;`.
- Check: `cd "$(mktemp -d)" && node <repo>/src/cli.js; echo $?` prints the
  error and `1`. Inside a repo, `node src/cli.js; echo $?` still prints `0`.

## Considered and rejected

- Non-ASCII arrows in `formatLine`: by design; the Python original printed the same.
- No lint or typecheck: 60 lines of untyped JS; not worth a plan yet.

## Not audited

Performance (input is a few KB of text), dependencies (none), docs beyond README.
