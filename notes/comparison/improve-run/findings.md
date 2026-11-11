> Output of a run of shadcn/improve (commit `cac56e1`) against the synthetic
> `gitglance` repo at commit `26c40fa`, 2026-11-11. The host model followed
> improve's SKILL.md, audit playbook and plan template as written. Effort:
> `standard`, non-interactive, so the top findings by leverage were planned.
> Kept verbatim for notes/COMPARISON.md. The text below is improve's output
> format, not this project's.

# /improve: gitglance

## Recon

- Node ESM package, no dependencies. `npm test` runs `node --test test/` (6 tests, all pass).
- No lint, typecheck or formatter configured.
- README: the Node code in `src/` is a port of `legacy/glance.py`; the Python
  version is the source of truth until parity. `legacy/cases/` holds 16
  porcelain v2 recordings from real git (via `scripts/record-cases.sh`); the Node
  tests don't use them.
- Two commits; all port work landed in `26c40fa`.

## Findings

| # | Finding | Category | Impact | Effort | Risk | Evidence |
|---|---------|----------|--------|--------|------|----------|
| 1 | Port has no parity check against the reference; recorded cases unused | tests | HIGH | S | LOW | `README.md:5-12`, `test/parse.test.js` (hand-written inputs only) |
| 2 | Rename entries (`2` lines) counted as staged, `renamed` stays 0, path taken from the score field | correctness | HIGH | S | LOW | `src/parse.js:22-27` |
| 3 | Paths containing spaces truncated at the first space | correctness | HIGH | S | LOW | `src/parse.js:23,27` (`split(' ')`, `parts[8]`) |
| 4 | Unmerged (`u`) entries ignored, so conflicts never show | correctness | HIGH | S | LOW | `src/parse.js` (no `u ` branch) |
| 5 | Detached HEAD reported as branch `(detached)`; `detached` never set | correctness | MED | S | LOW | `src/parse.js:13-14`, `test/parse.test.js:39-42` |
| 6 | Quoted (non-ASCII) paths not unquoted | correctness | MED | S | LOW | `src/parse.js:30` |
| 7 | CLI exits 0 when git fails | dx | LOW | S | LOW | `src/cli.js:16-18` |

Plans written for 1, 2+3 (same code path), 4 and 5 (top by leverage; #1 first
because it is the verification baseline the others depend on).

## Considered and rejected

- `formatLine` uses non-ASCII arrows: by design, matches the legacy output. Not a finding.
- No lint/typecheck: a 60-line package with no types; not worth a plan yet.

## Not audited

Performance, dependencies (there are none), docs beyond README.
