# 001: The port is measured against legacy/glance.py on every recorded case

> **For the executor.** Work through the steps in order. After each step, run
> its check and compare with the expected result before going on. If a STOP
> condition happens, stop and report; do not work around it. Files under
> "Frozen" must not change at all. Report the evidence tier of each done
> criterion using the words built / checked / live.
>
> **Drift check, before anything else:**
> `git diff --stat 26c40fa..HEAD -- src/ test/ legacy/ scripts/ package.json`
> Empty output: go ahead. Any output: compare the excerpts below with the live
> files; if they differ, that is a STOP.

## Header

- Route: PLAN
- Size S · fix risk low · priority 1
- Needs first: nothing
- Planned at: `26c40fa`, 2026-11-11
- Reference: `legacy/glance.py` run on `legacy/cases/*.porcelain` (recorded from real git)
- Evidence target: live (the recordings are re-made from real git and must come out byte-identical; a live script runs the port on fresh real git output)

## Why

The Node code in `src/` is a port of `legacy/glance.py`, and the README makes
the Python version the source of truth until the two agree. Nothing measures
that. The Node tests use hand-written inputs, two of which assert the bugs
(see Pins). This plan adds the measurement and nothing else: after it, the
test suite knows exactly which cases still differ, fails if a new one starts
to differ, and fails if a listed one starts to match. Plans 002–005 then fix
the differences family by family, each one shrinking a list it cannot grow.

## Current state

- `legacy/glance.py`: reads `git status --porcelain=v2 --branch` text on stdin,
  prints one JSON line with sorted keys. Fields: `ahead`, `behind`, `branch`,
  `conflicted`, `detached`, `modified`, `paths`, `renamed`, `staged`,
  `untracked`, `upstream`.
- `legacy/cases/*.porcelain`: 16 recordings, made by `scripts/record-cases.sh`
  (pinned dates, identities and config, so reruns are byte-identical).
- `src/parse.js:3`: `export function parse(text)` returns an object with the
  same eleven fields.
- `src/cli.js:9-11`: `node src/cli.js --json < file` prints `JSON.stringify(parse(input))`.
- `test/parse.test.js`: `node:test` with `assert/strict`, one `test()` per
  behaviour; the style to match.
- `package.json`: `"test": "node --test test/"` runs every `*.test.js` in `test/`.

## Reference and ratchet

- Reference, read-only: `python3 legacy/glance.py < legacy/cases/<name>.porcelain`
- Cases: the 16 files in `legacy/cases/`. Case name = file name without `.porcelain`.
- Ratchet (all created by this plan):
  - `scripts/gen-expected.sh` writes `test/expected/<name>.json` from the reference;
  - `test/not-yet.txt` lists cases that still differ;
  - `test/parity.test.js` enforces the list both ways.
- **Not-yet list today** (both run on all cases at `26c40fa`):
  ```
  conflict
  detached
  modified-spaces
  quoted-nonascii
  rename-spaces
  rename-staged
  rename-then-modified
  ```
- **Not-yet list when this plan is done:** identical. This plan changes no
  source code, so no line may leave and none may be added.
- Independent check (touches nothing this plan creates):
  ```
  norm='import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))'
  for f in legacy/cases/*.porcelain; do n=$(basename "$f" .porcelain); \
    cmp -s <(python3 legacy/glance.py < "$f" | python3 -c "$norm") \
           <(node src/cli.js --json < "$f" | python3 -c "$norm") || echo "$n"; done
  ```
  Expected output: the seven names above, in that order.

## Pins: tests that assert today's behaviour

- `test/parse.test.js:33-37` "rename shows up as a staged change": asserts
  `staged 1, renamed 0` for a rename; the reference says `staged 0, renamed 1`.
  Its hand-written input separates the paths with a space; real git uses a tab.
- `test/parse.test.js:39-42` "detached head keeps the marker as the branch
  name": asserts `branch '(detached)'`; the reference says `branch null,
  detached true`.

**This plan does not change either pin.** Leave both tests exactly as they
are; plans 002 and 004 fix them along with the code. Do not use either as a
model for anything.

## Commands

| Purpose | Command | Expected | Seen at planning time |
|---------|---------|----------|-----------------------|
| Tests | `npm test` | exit 0 | exit 0, 6 pass |
| Reference | `python3 legacy/glance.py < legacy/cases/clean.porcelain` | one JSON line, `"branch": "main"` | yes |
| Recorder | `scripts/record-cases.sh` | `recorded 16 cases with git version ...` | yes, twice, identical |
| Independent check | the loop above | the seven names | yes |

## Scope

**May change (create):** `scripts/gen-expected.sh`, `scripts/live-check.sh`,
`test/expected/*.json`, `test/not-yet.txt`, `test/parity.test.js`.

**Frozen:** `legacy/` (reference and cases), `src/`, `test/parse.test.js`,
`package.json`.

**Out of scope:** any fix to `src/`; plans 002–005 do those.

## Git

- Branch `advisor/001-parity-baseline`.
- One commit per step. Message style from `git log`: `port: Node version of
  gitglance (WIP, see README)`, so use `test: ...` here.
- No push, no PR.

## Steps

### Step 1: Expected outputs from the reference

Create `scripts/gen-expected.sh`, executable:

```bash
#!/usr/bin/env bash
# Regenerate test/expected/*.json from the reference implementation.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf test/expected && mkdir -p test/expected
for f in legacy/cases/*.porcelain; do
  n=$(basename "$f" .porcelain)
  python3 legacy/glance.py < "$f" > "test/expected/$n.json"
done
```

Run it.

**Check:** `ls test/expected/*.json | wc -l` → `16`, and
`grep -c '"renamed": 1' test/expected/rename-staged.json` → `1`.

### Step 2: The not-yet list and the ratchet test

Create `test/not-yet.txt` containing the seven names from "Not-yet list
today", one per line, sorted, after a comment line:

```
# Cases where src/ still differs from legacy/glance.py. This list may only shrink.
```

Create `test/parity.test.js`:

```js
// Parity with the reference implementation, legacy/glance.py.
// A case not on test/not-yet.txt must match; a case on it must still differ.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { isDeepStrictEqual } from 'node:util';
import { parse } from '../src/parse.js';

const read = (rel) => readFileSync(new URL(rel, import.meta.url), 'utf8');
const cases = readdirSync(new URL('../legacy/cases/', import.meta.url))
  .filter((f) => f.endsWith('.porcelain'))
  .map((f) => f.slice(0, -'.porcelain'.length))
  .sort();
const notYet = new Set(read('./not-yet.txt').split('\n')
  .map((l) => l.trim()).filter((l) => l && !l.startsWith('#')));

test('not-yet list names only real cases', () => {
  for (const name of notYet) assert.ok(cases.includes(name), `unknown case on not-yet list: ${name}`);
});

for (const name of cases) {
  test(`parity: ${name}`, () => {
    const actual = parse(read(`../legacy/cases/${name}.porcelain`));
    const expected = JSON.parse(read(`./expected/${name}.json`));
    if (notYet.has(name)) {
      assert.ok(!isDeepStrictEqual(actual, expected),
        `${name} now matches legacy/glance.py: remove it from test/not-yet.txt`);
    } else {
      assert.deepStrictEqual(actual, expected);
    }
  });
}
```

Commit.

**Check:** `npm test` → exit 0, `pass 23`, `fail 0` (6 existing + 1 sanity + 16 parity).

### Step 3: Prove the ratchet bites, then undo

Three temporary edits, each reverted with `git checkout -- test/not-yet.txt`
before the next:

1. Delete the line `detached` from `test/not-yet.txt`. **Check:** `npm test`
   → fails, and the output contains `parity: detached`.
2. Add a line `clean`. **Check:** `npm test` → fails, output contains
   `clean now matches legacy/glance.py`.
3. Add a line `no-such-case`. **Check:** `npm test` → fails, output contains
   `unknown case on not-yet list: no-such-case`.

**Check after reverting:** `git status --porcelain` prints nothing; `npm test` → exit 0.

### Step 4: Live check against real git

Create `scripts/live-check.sh`, executable:

```bash
#!/usr/bin/env bash
# Live check: run the port on fresh output from real git and compare it with
# the reference. Prints the git version, the date, the CLI's own summary line,
# and the number of differences. Exit 1 on any difference.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
mkdir "$W/repo"; cd "$W/repo"; git init -q -b main
printf 'a\n' > a.txt; printf 's\n' > 'has space.txt'; printf 'x\n' > old.txt; printf 'k\n' > 'keep me.txt'
git add .; git commit -qm init
git mv old.txt new.txt; git mv 'has space.txt' 'now spaced.txt'
printf 'b\n' >> 'keep me.txt'; printf 'u\n' > untracked.txt
git status --porcelain=v2 --branch > "$W/status.txt"
norm='import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))'
echo "git: $(git --version)"
echo "date: $(date -u +%Y-%m-%dT%H:%MZ)"
echo "cli: $(node "$ROOT/src/cli.js")"
ref="$(python3 "$ROOT/legacy/glance.py" < "$W/status.txt" | python3 -c "$norm")"
got="$(node "$ROOT/src/cli.js" --json < "$W/status.txt" | python3 -c "$norm")"
if [ "$ref" = "$got" ]; then echo "live: 0 differences"; else
  echo "live: 1 difference"; echo "reference: $ref"; echo "port:      $got"; exit 1; fi
```

Then re-record the cases from real git and confirm they did not change:
`scripts/record-cases.sh && git diff --exit-code legacy/cases/`.

Commit. **This last commit of the plan is the judge commit**: later plans
check that nothing it created has changed since.

**Check:**
- `scripts/record-cases.sh && git diff --exit-code legacy/cases/` → prints
  `recorded 16 cases with git version <v>`, exit 0.
- `scripts/live-check.sh; echo "exit=$?"` → today this is **expected to
  fail**, because the port still has the rename bug: `cli: main +2 ~1 ?1`,
  `live: 1 difference`, `exit=1`. Record the output. It passes after plan 002.

## Tests

- New: `test/parity.test.js` (1 sanity test + 16 parity tests).
- Revert check: not applicable; this plan changes no source. Step 3 is the
  equivalent: it shows the ratchet fails in each of the three ways it should.

## Done criteria

- [ ] [checked] `npm test` exits 0 with `pass 23`
- [ ] [checked] `diff <(grep -v '^#' test/not-yet.txt) <(printf '%s\n' conflict detached modified-spaces quoted-nonascii rename-spaces rename-staged rename-then-modified)` prints nothing
- [ ] [checked] `scripts/gen-expected.sh && git diff --exit-code test/expected/` exits 0
- [ ] [checked] `git diff --exit-code 26c40fa -- legacy/ src/ test/parse.test.js package.json` exits 0
- [ ] [checked] the independent check prints exactly the seven names
- [ ] [checked] step 3's three temporary edits each made `npm test` fail with the stated message
- [ ] [live] `scripts/record-cases.sh && git diff --exit-code legacy/cases/` exits 0; report the git version and date
- [ ] [live] `scripts/live-check.sh` output recorded (expected: `live: 1 difference` until plan 002)
- [ ] `git diff --name-only 26c40fa..HEAD` lists only the five "May change" paths (expected files count as one path each)

## STOP conditions

- The drift check shows changes and the excerpts no longer match.
- The independent check prints anything other than the seven names.
- `scripts/record-cases.sh` changes any file in `legacy/cases/`: real git now
  behaves differently from the recordings. Do not commit the new recordings;
  report the diff and the git version.
- `scripts/live-check.sh` reports a difference other than the rename one
  (`renamed`/`staged`/`paths`).
- Making the suite pass seems to need a change to `src/` or to `test/parse.test.js`.

## Cold read

- 2026-11-11, dry run (the advisor executed 001 and 002 in a scratch
  worktree before publishing): plan 002's frozen check compared against
  this plan's step 2 commit, but `scripts/live-check.sh` is created in step 4,
  so the check failed on an untouched file. The judge commit is now this
  plan's last commit.
- 2026-11-11, self-read (this run's host could not use subagents): flagged
  that Step 2's pass count depended on the existing six tests, so the count is
  now spelled out as 6 + 1 + 16; flagged that the live script would fail
  before plan 002 and an executor might "fix" that by touching `src/`, so the
  expected failure is now stated in the Step 4 check and in the STOP list.

## Maintenance

- Every fix plan after this one names the not-yet lines it removes and checks
  the final list by exact content.
- If `legacy/cases/` is re-recorded on a newer git and changes, regenerate
  `test/expected/` in the same commit and say so in the message.
- Reviewer: check that `test/parity.test.js` compares the whole object, not a
  subset of fields.
