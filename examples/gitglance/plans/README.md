# Plans

Written by the ratchet skill on 2026-11-11 at `26c40fa`. Run in order.
Status for 001 and 002 is from the trial execution in `../run-log.md`.

## Status

| Plan | Title | Route | Status | Built | Checked | Live | Not-yet |
|------|-------|-------|--------|-------|---------|------|---------|
| 001 | Parity baseline against legacy/glance.py | PLAN | DONE | ✓ 2026-11-11 | ✓ 2026-11-11: 23 pass; ratchet fails all 3 ways | ✓ 2026-11-11, git 2.54.0: 16/16 cases re-recorded byte-identical; live-check `1 difference` (rename, expected) | 7 |
| 002 | Renames and paths with spaces | PLAN | DONE | ✓ 2026-11-11 | ✓ 2026-11-11: 26 pass; revert check fail 8 | ✓ 2026-11-11, git 2.54.0: live-check `cli: main ~1 R2 ?1`, `0 differences`, including a held-back `R87` rename | 3 |
| 003 | Unmerged entries counted as conflicts | PLAN | TODO (not written out in this example) | | | | 3 → 2 |
| 004 | Detached HEAD | PLAN | TODO (not written out in this example) | | | | 2 → 1 |
| 005 | Unquote non-ASCII paths | PLAN | TODO (not written out in this example) | | | | 1 → 0 |

## Do directly (not planned)

- CLI exits 0 when git fails: add `process.exitCode = 1;` in the `catch` at
  `src/cli.js:16`. Check: `node src/cli.js; echo $?` in an empty temp dir
  prints `1`. Why not planned: two lines, one obvious check.

## Dependencies

- 002–005 need 001: each removes lines from the not-yet list 001 creates.
- 003 and 005 touch the branch 002 rewrites; run them after 002.

## Considered and rejected

- Non-ASCII arrows in `formatLine`: by design, same as the Python original.
- No lint or typecheck: not worth a plan at 60 lines.

## Deliberate divergences from the reference

- None.
