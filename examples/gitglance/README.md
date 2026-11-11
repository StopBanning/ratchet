# Worked example: gitglance

A small port with a reference. It shows the ratchet, the pins and the live
tier working on one plan series.

- `fixture-repo/`: the repo as audited. `./make-repo.sh <empty dir>` rebuilds it
  as a git repo at commit `26c40fa`, the commit the plans were written against.
- `findings.md`: recon, the findings table with routes, the DIRECT recipe,
  and what was rejected.
- `plans/`: the index (with Built / Checked / Live marks) and plans 001 and 002.
- `run-log.md`: a trial execution of both plans, the review, and two plan bugs
  that only showed up when the plans were executed.
- `model-run.md`: both plans executed by Claude Haiku, each in a fresh
  subagent, and the review of what it did.

## The setup

`gitglance` prints a one-line `git status` summary. The Node version in
`src/` is a port of the Python original in `legacy/glance.py`, and the README
says the Python version is the source of truth until they agree. The Python
project's test inputs, 16 `git status --porcelain=v2 --branch` outputs
recorded from real git, sit in `legacy/cases/`, unused by the Node tests.

Three things make this a good test of a planning skill:

1. **A reference exists.** So "done" can mean "agrees with `legacy/glance.py`
   on these cases", which the executor cannot edit.
2. **A test asserts the bug.** `test/parse.test.js:33-37` checks that a rename
   counts as a staged change, and its hand-written input separates the two
   paths with a space. Real git uses a tab. A fix modelled on that test passes
   it and fails on real output.
3. **The code talks to a real system.** The CLI runs real `git`, so a live
   check is cheap: build a throwaway repo, run both versions on its status.

## The ratchet, in numbers

| Moment | Not-yet list | `npm test` |
|---|---|---|
| Before plan 001 | (no list; 7 cases differ unseen) | 6 pass, including the bug-asserting test |
| After plan 001 | 7 names | 23 pass |
| Plan 002, step 1 (fix applied) | 7 names | 5 fail: four "now matches: remove it", one pin |
| Plan 002, step 2 | 3 names | 1 fails: the pin |
| After plan 002 | `conflict`, `detached`, `quoted-nonascii` | 26 pass; live: 0 differences |

The list only moved one way, and every move was forced by a failing test. Plan
002's done criterion is "these 4 lines leave, these 3 remain, none added",
checked by exact content. The ratchet test is frozen, the expected outputs
are regenerated from the reference, and the plan carries an independent
loop that uses none of the files the executor may edit.

For what happens when an executor tries to shortcut this, see
`notes/COMPARISON.md`.

## What the live tier added here

The recorded cases come from real git, so they are good evidence. They are
also all the executor can see. Every recorded rename has similarity score
`R100`, because `git mv` without an edit always scores 100. A fix that reads
the path as "whatever follows `R100`" passes all 16 cases, the ratchet, the
independent loop and the revert check.

The live check builds a repo the recordings do not contain: one renamed file
is edited and staged, and real git reports it as `R87`. On the overfitted fix
it prints:

```
cli: main ~1 R2 ?1
live: 1 difference
reference: ... "paths": ["keep me.txt", "new.txt", "now spaced.txt", "untracked.txt"] ...
port:      ... "paths": ["keep me.txt", "new.txt\told.txt", "now spaced.txt", "untracked.txt"] ...
```

Nothing at the `checked` tier could have caught that. It is the same shape as
the live findings this skill was built on: recordings and mocks hold only what
someone thought to record. The live check also confirms the recordings still
match git as installed today (re-recorded byte for byte, git 2.54.0), and
that the CLI's own path, which runs git itself, works. The follow-up the
skill asks for is to record an `R87` case, so the hole stays closed.
