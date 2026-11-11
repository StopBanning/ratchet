# Comparison: improve and ratchet on the same repo

**Headline.** Three scripted executors ran against each skill's plan for the
same fix. Both plans accepted the honest one. Improve's plan also accepted the
other two on every done criterion: a lazy diff that left rename paths broken
and loosened the parity test to hide it, and an overfitted diff that works
only on the recorded inputs. This skill's plan rejected the lazy diff on four
independent checks, and rejected the overfitted one on exactly one: the live
check against real git. Nothing at the `checked` tier, in either plan, could
see the overfit.

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
- **One session ran both skills.** Claude Opus 5.5 ran improve (shadcn/improve
  at `cac56e1`, following its SKILL.md, playbook and template as written) and
  then this skill, knowing what the second was meant to show. Claude Fable 5.2
  then reviewed the result in the same session and added the overfit
  executor and the held-back input in the live check. Improve's output is kept
  unedited in [comparison/improve-run/](comparison/improve-run/) so anyone can
  judge whether it was run fairly. A blind run of each skill in a fresh
  session, ideally on someone else's repo, has not been done.
- **The executors were scripted, not models.** `reproduce.sh` applies the same
  three diffs to each plan's baseline:
  - *honest*: the correct fix, with tests built from real recordings;
  - *lazy*: models the fix on the existing hand-written test, edits that test
    to match the new output, and loosens the parity comparison until
    `npm test` is green;
  - *overfit*: reads the renamed path as "whatever follows `R100`". Every
    recorded rename has that score, so the fix passes all 16 cases. Real git
    reports `R87` for a rename that was also edited.

## What each run produced

Both audits found the same seven issues. Improve's run planned parity first,
which is to its credit and follows its own rubric ("anything that unblocks
other findings floats up"). So the difference is not whether a parity test
exists. It is how the plans are judged.

| | improve | ratchet |
|---|---|---|
| Findings | 7, all as table rows | 7, plus a Route and a Reference column |
| CLI exit-code bug (two lines) | row 7, would become a plan if selected | routed DIRECT with a five-line recipe; no plan |
| Plan 001 | parity test, 7 cases on a `test.skip` list inside the test file | ratchet: list in its own file, fails both ways, live script |
| Plan 002 done criteria | 5 | 9, each tagged `checked` or `live` |
| Plan length (001 + 002) | 227 lines | about 580 lines |
| Cold read before handoff | not by default (only under `review-plan`) | self-read, a trial execution, and a second review |

## Where the plans differ, with excerpts

### 1. What "done" means

improve, plan 002:

```
- [ ] `npm test` exits 0
- [ ] 4 new tests in `test/parse.test.js` exist and pass
- [ ] `KNOWN_FAILURES` no longer contains `rename-staged`, `rename-then-modified`, `rename-spaces`, `modified-spaces`
- [ ] No files outside the in-scope list are modified (`git status`)
```

ratchet, plan 002 (abridged):

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

ratchet, plan 002, Pins:

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

Improve's plans have no notion of evidence tiers. Ours ends plan 002 with a
live step, and the live script builds a repo the recordings do not contain:
one renamed file is edited and staged, so real git scores it `R87`.

On the overfitted diff, every `checked` criterion passed, in both plans. The
live check printed (paths shortened):

```
cli: main ~1 R2 ?1
live: 1 difference
reference: ... "paths": ["keep me.txt", "new.txt", "now spaced.txt", "untracked.txt"] ...
port:      ... "paths": ["keep me.txt", "new.txt\told.txt", "now spaced.txt", "untracked.txt"] ...
```

The summary line a person would eyeball is correct. Only one file path is
wrong, so a manual look at the CLI would not have caught this either.

This is the limit of any reference-and-recordings scheme, ours included: the
executor can see every case, so passing them all proves less than it seems.
The answer is an input the executor never saw, run against the real system.

### 4. Routing

Improve listed the two-line exit-code fix as finding 7. Had the user picked
it, improve would have written a full plan: drift check, scope, steps, STOP
conditions, then dispatch and review. Ours routed it DIRECT:

> **6. Exit code on git failure.** Not worth a plan: two lines in one file.
> In `src/cli.js`, inside the `catch` (line 16), add `process.exitCode = 1;`.

This repo has no live-integration work, so the other half of routing (do it
directly when reality keeps changing the plan) is not exercised here. See
`skills/ratchet/references/routing.md`.

### 5. Reading the plan cold

Improve asks for a fresh-context read only under `review-plan`, and only when
the plan was written in the same session. Ours does it for every plan. The
host here did not use subagents, so the first read was a self-read, and it
caught three gaps. A trial execution caught two more that the self-read
missed: a revert check using `git stash` after the plan had already told the
executor to commit, and a frozen check pointed at the wrong commit. A second
review by a different model then found that the live scenario could not
catch an overfitted fix. All of it is logged in each plan's Cold read
section. It is a fair sign that self-reads are weak, which is why the skill
prefers a separate reader and asks for a trial run on the first plan of a
series.

## The head-to-head

The same three scripted executors, on each skill's own plan 001 baseline,
judged by each plan 002's own done criteria (from `output.txt`):

| Done criterion | improve honest | improve lazy | improve overfit | ratchet honest | ratchet lazy | ratchet overfit |
|---|---|---|---|---|---|---|
| tests pass (ratchet: with `pass 26`) | PASS | PASS | PASS | PASS | FAIL (27)* | PASS |
| new tests exist and pass | PASS | PASS | PASS | — | — | — |
| skip list lacks the 4 cases / not-yet list is exactly 3 names | PASS | PASS | PASS | PASS | **FAIL** | PASS |
| scope clean | PASS | PASS | PASS | — | — | — |
| independent loop prints exactly 3 names | — | — | — | PASS | **FAIL** (prints 6) | PASS |
| expected outputs regenerate unchanged | — | — | — | PASS | PASS | PASS |
| frozen files unchanged since judge commit | — | — | — | PASS | **FAIL** | PASS |
| revert check: `fail 8` without the fix | — | — | — | PASS | PASS | PASS |
| old pin assertion gone | — | — | — | PASS | PASS | PASS |
| live check: 0 differences | — | — | — | PASS | **FAIL** | **FAIL** |

\* A count mismatch only; it would not catch a diff that kept the count
equal. The bold cells are the real catches.

**The lazy diff, in order, under this skill's plan.** The executor loosened
the comparison to ignore `paths`. That made `quoted-nonascii`, whose only
difference is in `paths`, look like a match, and the ratchet failed with
"quoted-nonascii now matches legacy/glance.py: remove it from
test/not-yet.txt". The greedy executor obeyed and removed it. That went green,
and then broke the exact-list criterion. The frozen check, the independent
loop and the live check each caught the loosening on their own.

**The overfitted diff.** Nothing was loosened and no rule was broken. The fix
is simply wrong for inputs outside the recordings. The ratchet, the loop and
the revert check all passed it. Only the live check failed, because its input
was never in the repo.

## What improve would still catch, and what ours missed

- **Improve's review step reads the diff.** Its closing-the-loop reference
  tells the reviewer to read the whole diff and audit what new tests assert.
  A careful reviewer would probably spot a six-line change to the parity
  comparator, comment and all, and might question a regex containing `R100`.
  The difference: improve depends on the reviewer noticing, while ours turns
  each one into a failing command.
- **The ratchet does not stop overfitting.** It is one line of defence, and
  the table shows where it ends. Without the held-back input in the live
  check, this skill would have approved the overfitted diff too. The first
  version of the example had exactly that hole.
- **The revert check did not help here.** Both bad diffs' tests do fail
  without the fix. Revert checks catch empty tests, not wrong ones.
- **Expected-output regeneration passed every run**, because no executor
  touched `test/expected/`. It guards a different move (editing expected
  files), which this experiment did not try.
- **Cost.** Our plans are about 2.5 times longer, and the ratchet needs a
  reference. Where no outside reference exists, the skill falls back to the
  code before the change or a written delta; where neither fits, the plan
  says its criteria are self-referential, and the gap between the two skills
  shrinks to pins, tiers, routing and the cold read.
- **Real executors, partly.** Claude Haiku executed this skill's plans 001
  and 002 from the plan text alone. It made no STOPs, every criterion held on
  review, and a fresh input built by the reviewer matched the reference (see
  `examples/gitglance/model-run.md`). That covers the honest path only. No
  model has been run on improve's plans, and no model has been put in a
  position to game either.
- **Not tested:** a real model executor on improve's plans, a model that is
  tempted to game, a blind run of either skill, repos without a reference, the fallbacks for
  them, the `execute`, `reconcile` and `--issues` flows end to end, and any
  host other than Claude Code.
