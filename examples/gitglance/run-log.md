# Trial execution and review, plans 001 and 002

On 2026-11-11 the plans were executed step by step in a scratch worktree of
the fixture repo, then reviewed against this skill's review checklist. The
host session did not use subagents, so the advisor's host played the executor,
following the plan text literally (code blocks were extracted from the plan
files by script, not retyped). The outputs below are copied from that run.

## Plan 001: executor report

```
STATUS: COMPLETE
STEPS:
  drift check            → empty
  1 gen-expected         → 16 files; rename-staged.json has "renamed": 1
  2 ratchet              → npm test: tests 23, pass 23, fail 0        (commit 18148eb)
  3 ratchet bites        → delete 'detached': fail 1, "✖ parity: detached"
                           add 'clean': fail 1, "clean now matches legacy/glance.py: remove it from test/not-yet.txt"
                           add 'no-such-case': fail 1, "unknown case on not-yet list: no-such-case"
                           reverted; git status clean; pass 23
  4 live                 → record-cases: "recorded 16 cases with git version 2.54.0 (Apple Git-157)", git diff --exit-code: 0
                           live-check: "cli: main +2 ~1 ?1", "live: 1 difference", exit 1 (expected before 002)
                           (re-run 19:19Z after the scenario gained an R87 rename; same result)
                                                                         (commit 345fa70 = judge commit)
NOT-YET: before = after = conflict detached modified-spaces quoted-nonascii rename-spaces rename-staged rename-then-modified
EVIDENCE: 23 pass [checked]; list exact [checked]; expected fresh [checked]; frozen [checked];
          independent loop = 7 names [checked]; recordings = real git 2.54.0 on 2026-11-11 [live];
          live-check run 2026-11-11T19:19Z, 1 difference, the rename family [live]
FILES CHANGED: scripts/gen-expected.sh scripts/live-check.sh test/expected/*.json test/not-yet.txt test/parity.test.js
NOTES: none
```

Live check output, before plan 002 (the port's bug on fresh real git output):

```
git: git version 2.54.0 (Apple Git-157)
date: 2026-11-11T19:19Z
cli: main +2 ~1 ?1
live: 1 difference
reference: {... "paths": ["keep me.txt", "new.txt", "now spaced.txt", "untracked.txt"], "renamed": 2, "staged": 0, ...}
port:      {... "paths": ["R100", "R87", "keep", "untracked.txt"], "renamed": 0, "staged": 2, ...}
```

Review: all criteria re-run and held. **APPROVE.**

## Plan 002: executor report

```
STATUS: COMPLETE (after the plan was corrected; see below)
STEPS:
  drift check            → empty
  1 split 1/2 lines      → independent loop: conflict, detached, quoted-nonascii
                           npm test: pass 18, fail 5 (4 parity "now matches", 1 rename pin), as the plan predicts
  2 shrink list          → npm test: pass 22, fail 1 (the rename pin)
  3 pin + 3 tests        → npm test: pass 26, fail 0
     revert check        → git checkout 26c40fa -- src/parse.js: pass 18, fail 8
                           (4 parity, 3 new tests, rewritten pin); restored; pass 26
  4 live                 → "cli: main ~1 R2 ?1", "live: 0 differences", exit 0
NOT-YET: before = 7 names; after = conflict detached quoted-nonascii
EVIDENCE: 26 pass [checked]; list exact [checked]; loop = 3 names [checked]; expected fresh [checked];
          frozen since 345fa70 [checked]; revert fail 8 [checked]; pin assertion gone [checked];
          live-check 2026-11-11T19:19Z, git 2.54.0, 0 differences, R87 rename included [live]
FILES CHANGED: src/parse.js test/not-yet.txt test/parse.test.js
NOTES: two checks in the plan as first written could not pass; see "Plan bugs".
```

### Plan bugs found by executing

1. **Revert check.** The plan said `git stash push -- src/parse.js && npm test; git stash pop`.
   Step 1 had already told the executor to commit the fix, so there was
   nothing to stash, and the check would have passed vacuously. Now:
   `git checkout 26c40fa -- src/parse.js && npm test; git checkout HEAD -- src/parse.js`,
   expecting `fail 8`.
2. **Judge commit.** Plan 001 named its step 2 commit as the judge, but
   `scripts/live-check.sh` is created in step 4. Plan 002's frozen check then
   reported an untouched file as changed. The judge is now plan 001's last
   commit.

Neither bug was caught by the self-read cold pass. Both are now in the plans'
Cold read sections, and the skill and template were changed to match: revert
checks restore from the planned-at commit, and the judge commit is the last
commit that creates reference tooling. The lesson is in SKILL.md too: the
first execution of a plan series tests the plan, and a check that could never
pass as written is the advisor's error, not the executor's.

Review after correction: all nine criteria re-run and held. **APPROVE.**
Not-yet 7 → 3.

## Second review, same day

A second review by a different model found that the live scenario only
repeated shapes the recorded cases already had: every rename in it, as in the
recordings, was scored `R100`. A fix fitted to the recordings would have
passed it. The live script in plan 001 now edits and stages one renamed file,
which real git reports as `R87`. Both plans' checks were re-run through
`notes/comparison/reproduce.sh` with the new script (the "advisor, honest"
block in `notes/comparison/output.txt`): all eight pass. The same script's
"overfit" executor shows what the change buys: its fix passes every `checked`
criterion and fails only the live check.

## Cleanup

The scratch worktree and fixture copies were moved to the Trash after the
run. Rebuild with `./make-repo.sh <dir>`.
