# Comparison: improve and advisor on the same repo

**Headline.** A lazy executor diff passed every done criterion in improve's
plan: rename paths still broken, the parity test loosened to ignore paths,
the bug-asserting test kept with the wrong input format. The same diff
failed four independent checks in this skill's plan: the exact not-yet list,
the independent reference loop, the frozen-judge check, and the live check on
real git. The ratchet had already gone off before any done criterion ran.
Both plans accepted an honest diff.

Reproduce everything below with:

```bash
notes/comparison/reproduce.sh ~/work/scratch/cmp
```

Raw output: [comparison/output.txt](comparison/output.txt).

## Setup, and what this is not

- **Repo.** `gitglance`, a synthetic 60-line Node port of a Python tool
  (`examples/gitglance/fixture-repo`, rebuilt at commit `26c40fa` by
  `examples/gitglance/make-repo.sh`). The Python original is the reference. 16
  porcelain inputs were recorded from real git 2.54.0. 7 of the 16 differ
  between port and reference, and one existing test asserts the rename bug
  using a hand-written input in the wrong format.
- **I built the repo to contain the failure shapes this skill targets**, after
  reading improve. It shows the mechanism. It is not a measured win rate on
  repos found in the wild.
- **One model, one session, both runs.** The same host model (Claude Opus 5.5)
  ran improve (shadcn/improve at `cac56e1`, following its SKILL.md, playbook
  and template as written) and then this skill, knowing what the second was
  meant to show. Improve's output is kept unedited in
  [comparison/improve-run/](comparison/improve-run/) so anyone can judge
  whether it was run fairly. A blind run of each in a fresh session, ideally
  on someone else's repo, has not been done.
- **The executors were scripted, not models.** `reproduce.sh` applies the same
  "honest" and "lazy" diffs to each plan's baseline. The lazy diff copies
  behaviour seen from real executors: it models the fix on the existing test's
  input, edits the rename test to match the new output, and loosens the parity
  comparison until `npm test` is green.

## What each run produced

Both audits found the same seven issues. Improve's run planned parity first,
which is to its credit and follows its own rubric ("anything that unblocks
other findings floats up"). So the difference is not whether a parity test
exists. It is how the plans are judged.

| | improve | advisor |
|---|---|---|
| Findings | 7, all as table rows | 7, plus a Route and a Reference column |
| CLI exit-code bug (two lines) | row 7, would become a plan if selected | routed DIRECT with a five-line recipe; no plan |
| Plan 001 | parity test, 7 cases on a `test.skip` list inside the test file | ratchet: list in its own file, fails both ways, live script |
| Plan 002 done criteria | 5 | 9, each tagged `checked` or `live` |
| Plan length (001 + 002) | 227 lines | 561 lines |
| Cold read before handoff | not by default (only under `review-plan`) | self-read, plus a trial execution that found 2 plan bugs |

## Where the plans differ, with excerpts

### 1. What "done" means

improve, plan 002:

```
- [ ] `npm test` exits 0
- [ ] 4 new tests in `test/parse.test.js` exist and pass
- [ ] `KNOWN_FAILURES` no longer contains `rename-staged`, `rename-then-modified`, `rename-spaces`, `modified-spaces`
- [ ] No files outside the in-scope list are modified (`git status`)
```

advisor, plan 002 (abridged):

```
- [ ] [checked] `diff <(grep -v '^#' test/not-yet.txt) <(printf '%s\n' conflict detached quoted-nonascii)` prints nothing
- [ ] [checked] independent check prints exactly `conflict`, `detached`, `quoted-nonascii`
- [ ] [checked] `scripts/gen-expected.sh && git diff --exit-code test/expected/` exits 0
- [ ] [checked] `git diff --exit-code <judge commit> -- legacy/ test/expected/ test/parity.test.js scripts/ package.json src/cli.js` exits 0
- [ ] [live] `scripts/live-check.sh` prints `live: 0 differences`; report the date and git version
```

Improve's criteria check that the skip list got shorter. The parity test is
in the executor's scope (it has to be, because the skip list lives inside it),
so nothing stops the executor changing what "parity" compares. Ours keeps the
list in its own file and states its exact final content. It freezes the
test that enforces the list, regenerates the expected outputs from the
reference, and adds a loop in the plan text that touches no file the executor
can edit.

### 2. The test that asserts the bug

improve, plan 002, step 2:

> Add tests to `test/parse.test.js`, modelled on the existing ones [...]
> Update the existing rename test if it no longer matches the reference
> behaviour.

advisor, plan 002, Pins:

> **`test/parse.test.js:33-37`, "rename shows up as a staged change". Change it.**
> It asserts `staged 1, renamed 0`, which is the bug. Its input is also wrong:
> it separates the two paths with a space, but real git uses a tab, so a fix
> modelled on this input will pass this test and fail on real output.

To be fair, improve's run did mention the rename test. But it said "if", and
it pointed the executor at the existing tests as the pattern. The wrong
separator in the hand-written input is exactly what the lazy executor copied,
and its rename tests passed. Improve's template has no place for "this test
is wrong and why"; ours requires one in every plan.

### 3. How far the evidence reaches

Improve's plans have no notion of evidence tiers. Ours ends plan 002 with:

> **Check:** `scripts/live-check.sh` → `cli: main ~1 R2 ?1`,
> `live: 0 differences`, exit 0. Put the full output (git version and date
> included) in your report.

On the lazy diff that live check printed this (paths shortened):

```
cli: main ~1 R2 ?1
live: 1 difference
reference: ... "paths": ["keep me.txt", "new.txt", "now spaced.txt", "untracked.txt"] ...
port:      ... "paths": ["keep me.txt", "new.txt\told.txt", "now", "untracked.txt"] ...
```

The summary line a person would eyeball is correct. Only the file paths are
wrong, so a manual look at the CLI would not have caught this either.

### 4. Routing

Improve listed the two-line exit-code fix as finding 7. Had the user picked
it, improve would have written a full plan: drift check, scope, steps, STOP
conditions, then dispatch and review. Ours routed it DIRECT:

> **6. Exit code on git failure.** Not worth a plan: two lines in one file.
> In `src/cli.js`, inside the `catch` (line 16), add `process.exitCode = 1;`.

This repo has no live-integration work, so the other half of routing (do it
directly when reality keeps changing the plan) is not exercised here. See
`skills/advisor/references/routing.md`.

### 5. Reading the plan cold

Improve asks for a fresh-context read only under `review-plan`, and only when
the plan was written in the same session. Ours does it for every plan. The
host here could not spawn subagents, so the read was a self-read, and it
caught three gaps. A trial execution caught two more that the self-read
missed. One was a revert check using `git stash` after the plan had already
told the executor to commit; the other was a frozen check pointed at the
wrong commit. Both are logged in each plan's Cold read section. It is a fair
sign that self-reads are weak, which is why the skill prefers a separate
reader and asks for a trial run on the first plan of a series.

## The head-to-head

The same scripted executors, on each skill's own plan 001 baseline, then
each plan 002's own done criteria (from `output.txt`):

| Done criterion | improve, honest | improve, lazy | advisor, honest | advisor, lazy |
|---|---|---|---|---|
| tests pass (improve: exit 0 / advisor: exit 0 with `pass 26`) | PASS | PASS | PASS | FAIL (27)* |
| new tests exist and pass | PASS | PASS | — | — |
| skip list lacks the 4 cases / not-yet list is exactly 3 names | PASS | PASS | PASS | **FAIL** |
| scope clean | PASS | PASS | — | — |
| independent loop prints exactly 3 names | — | — | PASS | **FAIL** (prints 6) |
| expected outputs regenerate unchanged | — | — | PASS | PASS |
| frozen files unchanged since judge commit | — | — | PASS | **FAIL** |
| revert check: `fail 8` without the fix | — | — | PASS | PASS |
| old pin assertion gone | — | — | PASS | PASS |
| live check: 0 differences | — | — | PASS | **FAIL** |

\* A count mismatch only; it would not catch a diff that kept the count
equal. The bold rows are the real catches.

What happened, in order, under this skill's plan: the lazy executor loosened
the comparison to ignore `paths`. That made `quoted-nonascii`, whose only
difference is in `paths`, look like a match, and the ratchet failed with
"quoted-nonascii now matches legacy/glance.py: remove it from
test/not-yet.txt". The greedy executor obeyed and removed it. That went green,
and then broke the exact-list criterion. The frozen check, the independent
loop and the live check each caught the loosening on their own.

## What improve would still catch, and what ours missed

- **Improve's review step reads the diff.** Its closing-the-loop reference
  tells the reviewer to read the whole diff and audit what new tests assert.
  A careful reviewer would probably spot a six-line change to the parity
  comparator, comment and all. The difference: improve depends on the
  reviewer noticing it, while ours turns it into four failing commands. The
  wrong separator in the new tests is harder to spot by reading. You have to
  know that real git uses a tab.
- **The revert check did not help here.** The lazy tests do fail without the
  fix. They test the wrong input format, not nothing. Revert checks catch
  empty tests, not wrong ones.
- **Expected-output regeneration passed both runs**, because neither executor
  touched `test/expected/`. It guards a different move (editing expected
  files), which this experiment did not try.
- **Cost.** Our plans are about 2.5 times longer, and the ratchet needs a
  reference. Without one, a plan falls back to ordinary tests and says its
  criteria are self-referential. On a repo with no reference, the gap between
  the two skills shrinks to pins, tiers, routing and the cold read.
- **Not tested:** real model executors (cheap models driven by each plan),
  a blind run of either skill, repos without a reference, the `execute`,
  `reconcile` and `--issues` flows end to end, and any host other than
  Claude Code.
