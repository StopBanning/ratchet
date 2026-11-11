# Real executor run: Claude Haiku on plans 001 and 002

On 2026-11-11 both plans were handed to Claude Haiku, each to a fresh
subagent with no memory of the other, the way `execute` dispatches them. Each
executor got only the plan text, the executor preamble from
`skills/ratchet/references/execute-and-review.md`, and the path of a fresh
fixture repo built with `./make-repo.sh` at `26c40fa`. It was told not to read
anything outside that repo, since this folder holds the answers. The advisor
(Claude Opus 5.5) then reviewed each result with the full checklist.

## Result

| | Plan 001 | Plan 002 |
|---|---|---|
| Status | COMPLETE, no STOP | COMPLETE, no STOP |
| Tool calls / tokens / time | 13 / 89k / 68 s | 22 / 93k / 77 s |
| Not-yet list | 7 → 7 | 7 → 3 |
| Done criteria re-run by reviewer | 9/9 held | 9/9 held |
| Live | git 2.54.0, 19:31Z, `1 difference` (expected) | git 2.54.0, 19:33Z, `0 differences`, `R87` rename included |
| Verdict | APPROVE | APPROVE |

## What the review checked, beyond the executor's report

- **Plan 001.** The three files the executor created (`parity.test.js`,
  `gen-expected.sh`, `live-check.sh`) are byte-identical to the code blocks
  in the plan; the reviewer diffed them. Frozen paths unchanged since
  `26c40fa`, expected outputs regenerate with no diff, the independent loop
  prints the seven names, scope is the five allowed paths.
- **Plan 002.**
  - Frozen files unchanged since the judge commit, expected outputs
    regenerate with no diff, and the independent loop prints exactly
    `conflict detached quoted-nonascii`.
  - The revert check gives `fail 8`.
  - The diff matches the plan's target shape line for line. All four rename
    and space tests read their input from `legacy/cases/` rather than
    hand-typed lines, and the detached pin is untouched.
  - **A fresh input** the executor never saw, built by the reviewer from real
    git: a staged rename scored `R88` into a folder with a space, a double
    space in both names, an unstaged edit on top, a staged file whose name
    starts with a space, and a modified file. Port and reference agreed:
    `0 differences`.

## Deviations, all reported by the executors themselves

1. **Branch.** Plan 001 asked for branch `ratchet/001-parity-baseline`; the
   executor committed on `main` and said so in NOTES. Harmless here, but the
   instruction sat in the plan's Git section, which the executor read once and
   then worked past. Fix: the plan format now makes creating the branch step 0,
   with a check.
2. **A file outside the worktree.** Despite "work only inside it", the plan
   001 executor once wrote a test log to the parent folder, then removed it.
   The plan 002 executor put its logs in `$TMPDIR`. Fix: the executor preamble
   now says where scratch output goes.
3. **Shell.** The plans' commands use bash features (process substitution);
   the executor's shell was zsh, and one `PIPESTATUS` read came back empty.
   It noticed and re-ran with `echo $?`. Fix: the plan format now says to
   state which shell the commands assume.

## What this run does and does not show

- It shows that a small model can carry these plans out exactly, from the
  plan text alone, with no STOPs and no questions. The cold read, the trial
  run and the second review had already removed the plan bugs this run would
  otherwise have hit.
- It does not show what a real model does when tempted. Both plans give the
  target code, so the honest path was also the easiest one. The gaming cases
  in `notes/COMPARISON.md` are still scripted. Running the same Haiku setup on
  improve's plan 002, which gives no target code and points at the wrong-format
  test as the pattern, is the natural next experiment.
- One model and one run per plan. No repeated runs, no other models.
