# Plan template

Write each plan for the weakest executor you might hand it to: a model that
follows explicit instructions well, fills gaps badly, and does not know when to
give up. It has never seen this repo or this session. Everything it needs is in
the file, every step ends in a check it can run, and every way the plan can
go wrong has a named STOP.

Name each file `plans/NNN-slug.md`, where NNN is the recommended run order.

Sections marked **(new)** are the ones this skill adds to the usual handoff
plan. Do not drop them because they feel heavy: an empty Pins section that says
"searched `test/` and `fixtures/` for `rename`, none found" is useful; a missing
one is not.

---

````markdown
# NNN: <what will be true when this is done>

> **For the executor.** Work through the steps in order. After each step, run
> its check and compare with the expected result before going on. If a STOP
> condition happens, stop and report; do not work around it. Files under
> "Frozen" must not change at all. Report the evidence tier of each done
> criterion using the words built / checked / live.
>
> **Drift check, before anything else:**
> `git diff --stat <base>..HEAD -- <every in-scope and frozen path>`
> (`<base>` is the planned-at commit in the header.)
> Empty output: go ahead. Any output: compare the excerpts below with the live
> files; if they differ, that is a STOP.

## Header

- Route: PLAN | PROBE
- Size S/M/L · fix risk low/medium/high · priority 1/2/3
- Needs first: the plans that must be DONE before this one, or nothing
- Planned at: `<short sha>`, <YYYY-MM-DD>
- Reference: <what the done criteria are checked against, or "none: criteria are self-referential">
- Evidence target: built | checked | live (and why not higher, if not live)
- Issue: <url, only with --issues>

## Why

Two to five sentences: the problem, what it costs, and what is better after.
The executor uses this to make small judgement calls correctly, so state the
intent, not just the mechanics.

## Current state

- Files involved, one line each on their role and the relevant line range.
- Short excerpts of the code as it is today, with `path:line` markers, taken
  from your own reads.
- Conventions to follow, with one exemplar file and line range ("errors are
  returned as `Result`, see `src/lib/result.ts:10-40`").
- Vocabulary or decisions from intent docs that apply, quoted.

## Reference and ratchet (new)

Omit only when the header says "Reference: none".

- The reference and how to run it read-only:
  `python3 legacy/tool.py < cases/<name>.in`
- Where the cases live and how many there are; how they were recorded.
- The ratchet: the test file, the not-yet list file, the expected-output
  generator. If they do not exist yet, step 1 creates them (see ratchet.md).
- **Not-yet list today** (from your run at the planned-at commit), exactly.
- **Not-yet list when done**, exactly. Name the lines that leave. State that
  none may be added.
- The independent check, a loop the reviewer can paste, that touches no file
  the executor may edit:
  ```
  for f in cases/*.in; do n=$(basename "$f" .in); \
    cmp -s <(python3 legacy/tool.py < "$f") <(node src/cli.js --json < "$f") || echo "$n"; done
  ```
  Expected output when done: exactly the not-yet-when-done names.

## Pins: tests that assert today's behaviour (new)

Every existing test, fixture, fake, mock or snapshot that asserts the behaviour
this plan changes. For each: the path and line, what it asserts, why that is
wrong (or right), and exactly how it must change. Then:

- "Do not use these as a model for new tests."
- If a pin is a hand-written fake of an external system, say whether its
  format was compared with a real recording and what the difference is.
- Pins for behaviour this plan does *not* change, which a careless fix might
  break: name them and say they must keep passing unchanged.

If the search found none, write what was searched and how.

## Commands

| Purpose | Command | Expected | Seen at planning time |
|---------|---------|----------|-----------------------|
| Tests | `npm test` | exit 0 | exit 0, 22 pass |
| Reference | `python3 legacy/tool.py < cases/x.in` | one JSON line | yes |
| Live check | `scripts/live-check.sh` | `0 differences` | not run (needs executor worktree) |

Only commands from this repo, each one run during recon unless marked.

## Scope

**May change:** exact paths.

**Frozen** (must not change at all; checked by `git diff --exit-code`): the
reference, recorded cases, expected outputs, and the ratchet test once step 1
has created it.

**Out of scope** (looks related, leave it): paths or behaviours, each with the
reason.

## Git

- Branch name: `advisor/NNN-slug` unless the repo has its own pattern.
- Commit after each step, message in the repo's style (quote one from
  `git log`). The commit that finishes creating the reference tooling (ratchet
  test, list, generator, live script) is the "judge commit"; later frozen
  checks compare against it. If those files are created over several steps,
  it is the last of them, not the first.
- No push, no PR, unless the operator said so.

## Steps

### Step 1: <imperative>

Exactly what to do, with files and symbols. Show the target shape of the code
when it matters.

**Check:** `<command>` → `<expected output>`

### Step 2: ...

Order steps so the tree builds and the tests pass after each one where
possible. A ratchet step comes before any fix step, and lands with the list
equal to today's differences.

### Step N: Live check (when the evidence target is live)

The exact command against the real system, what output means success, and
what to write in the report: date, version of the real system, the command,
and a one-line summary of what was seen. If the live result disagrees with
the reference or with the recorded cases, STOP.

- The check must be safe: read-only calls, a sandbox, a test account or a
  scratch copy. If it needs a credential, name the environment variable, not
  the value, and say what the executor does without it: report the criterion
  as "not reached", never guess the result.
- Give it at least one input the recorded cases do not contain, and say which.
  That is what shows the fix is not fitted to the recordings.

## Tests

- New tests: file, names, and what each asserts, written against the
  reference's behaviour, not today's output.
- Structural pattern to follow: name an existing test that is *not* a pin.
- **Revert check:** put the pre-fix source back from the planned-at commit,
  run the tests, then restore:
  `git checkout <planned-at sha> -- <source paths> && <test command>; git checkout HEAD -- <source paths>`.
  The new tests must fail; give the expected failure count. (Not `git stash`:
  the executor has already committed the fix, so there is nothing to stash.)
  A test that passes without the fix proves nothing.

## Done criteria

Each line is a command with its expected result, tagged with the tier it
proves.

- [ ] [checked] `<test command>` exits 0
- [ ] [checked] not-yet list equals `<exact names>` (command from the Reference section)
- [ ] [checked] `<regenerate expected> && git diff --exit-code <expected dir>` exits 0
- [ ] [checked] `git diff --exit-code <judge commit> -- <frozen paths>` exits 0
- [ ] [checked] revert check shows the new tests failing without the fix
- [ ] [checked] the independent loop prints exactly the not-yet-when-done names
- [ ] [live] `<live command>` output as stated, with date and version recorded
- [ ] `git diff --name-only <planned-at sha>..HEAD` lists only "May change" paths
      (plus the files step 1 creates)

## STOP conditions

Specific to this plan. Always include:

- Drift check shows a mismatch with the excerpts.
- A frozen file would need to change to make progress.
- A case not on the not-yet list starts to differ, and the fix does not
  obviously belong to this plan.
- A live result disagrees with the reference or the recordings.
- A check fails twice after a reasonable attempt.

Plus the assumptions this plan rests on: "if `X` turns out to be false, stop".

## Cold read (new)

Filled in by the advisor after Phase 5:

- <date>, <cold | self-read>: <what the reader flagged> → <what changed>.

## Maintenance

What future work will touch this; what a reviewer should look at hardest;
what was deliberately left out and why.
````

---

## The index: `plans/README.md`

```markdown
# Plans

Written by the advisor skill on <date> at `<sha>`. Run in the order below
unless the dependencies say otherwise.

## Status

| Plan | Title | Route | Status | Built | Checked | Live | Not-yet |
|------|-------|-------|--------|-------|---------|------|---------|
| 001 | Parity baseline | PLAN | DONE | ✓ | ✓ 2026-11-11 | ✓ 2026-11-11 git 2.54.0, 16/16 recorded = real | 7 |
| 002 | Renames and spaces | PLAN | TODO | | | | 7 → 3 |

- Status: TODO, IN PROGRESS, DONE, BLOCKED (one-line reason), REJECTED (one-line reason).
  Start a BLOCKED reason with `reality:` when the real system behaved
  differently from the plan. Two of those for the same work re-route it DIRECT.
- Built / Checked / Live: a tick and date when reached, with what was seen for
  Live. A blank is honest; a tick without a date is not allowed. A plan whose
  live check could not be run can still be DONE at `checked`, with Live blank
  and the reason in the Status cell.
- Not-yet: the list length now, or "now → target" for a pending plan.

## Do directly (not planned)

- <finding>: <five-line recipe and its check>. Why not planned: <one line>.

## Dependencies

- 002 needs 001: <reason>.

## Considered and rejected

- <finding>: <one-line reason>.

## Deliberate divergences from the reference

- <case>: <why the code intentionally differs; who decided; date>.
```

## Checks before a plan leaves your hands

- Could someone with only this file and the repo do it? If a step needs
  something from this session, put it in the file.
- Is every check a command with an expected result?
- Does each step point at concrete paths and function names?
- Are the not-yet lists, before and after, written out in full?
- Is every pin named with how it changes, or the search recorded?
- Does each done criterion carry a tier, and is the evidence target honest?
- Is the live check safe to run, and does it include an input the cases lack?
- Are the frozen paths in the drift check and in a `git diff --exit-code`?
- Are the STOP conditions about this plan, not boilerplate?
- No secret values anywhere.
- Has the cold read run, and is its line filled in?
