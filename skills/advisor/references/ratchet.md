# References and ratchets

"All tests pass" is a criterion the executor can satisfy by writing weak tests,
loosening a comparison, or editing an expected value. A count of cases that
agree with a reference the executor cannot touch is much harder to satisfy
without doing the work. This file explains how to build that count and how
to keep it honest.

## 1. Finding the reference

Ask: what, outside the code being changed, already knows the right answer?

| Kind | Examples | How to run it |
|------|----------|---------------|
| Older implementation | the code being ported, a `v1` package, `legacy/` | run it on the same inputs, read its output |
| Real external system | the CLI the code wraps, a service's sandbox, a device | run it, record the output with its version and date |
| Recordings | golden files, VCR/cassette folders, captured protocol logs | already on disk; note who recorded them, when, and from what |
| Spec with examples | an RFC's test vectors, a format spec's sample files, a conformance suite | parse the examples into cases |
| Another view of the same truth | `git diff --name-status` as a check on a `git status` parser | run both, compare |

Prefer what is closest to reality. A recording made by hand is not a
reference; it is a pin (see plan-format.md) until it has been compared with
a real run.

If nothing qualifies, say so in the finding's Reference column ("none"). The
plan then falls back to ordinary tests, and its Done criteria section says the
criteria are self-referential.

## 2. Cases

A case is one named input that both the reference and the code under test can
be run on. Cases live in files, one per case, with stable names
(`rename-spaces.porcelain`, `cmd-list-sessions.json`), so that a not-yet list
can name them one per line.

- Reuse cases that already exist (the reference's own test inputs are ideal).
- When you add cases, record them from the real system with a script checked
  into the repo, pinned so reruns give identical bytes (fixed dates, fixed
  identities, no machine paths). Run the recorder twice and diff the outputs to
  prove it.
- Group cases into families named after the behaviour they exercise
  (`rename-*`, `conflict-*`). Plans fix families, not individual cases.

## 3. Expected outputs

Generate expected outputs by running the reference, never by running the code
under test, and never by hand. The generator is a script in the repo
(`scripts/gen-expected.sh` or similar) so that review can re-run it and get no
diff. Normalise in the generator (sort keys, strip timestamps), not in the
test, so normalisation cannot be loosened in the test.

## 4. The ratchet test

One test per case, plus one sanity test, in the repo's own test framework:

1. Every name on the not-yet list must be a real case. (Stops typos and stale
   entries.)
2. For a case **not** on the list: actual must equal expected.
3. For a case **on** the list: actual must **differ** from expected. If it now
   matches, the test fails with "remove <name> from the not-yet list".

Rule 3 is the ratchet. Without it, a skip list only grows: cases that start
passing stay skipped, and nobody notices when they break again.

The not-yet list is a plain file, one case name per line, sorted, `#` for
comments. It is not inside the test file, so editing the list and editing the
judge are separate, visible changes.

### Node (`node:test`)

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { isDeepStrictEqual } from 'node:util';
import { parse } from '../src/parse.js';

const read = (rel) => readFileSync(new URL(rel, import.meta.url), 'utf8');
const cases = readdirSync(new URL('../cases/', import.meta.url))
  .filter((f) => f.endsWith('.in')).map((f) => f.slice(0, -3)).sort();
const notYet = new Set(read('./not-yet.txt').split('\n')
  .map((l) => l.trim()).filter((l) => l && !l.startsWith('#')));

test('not-yet list names only real cases', () => {
  for (const name of notYet) assert.ok(cases.includes(name), `unknown case on not-yet list: ${name}`);
});

for (const name of cases) {
  test(`parity: ${name}`, () => {
    const actual = parse(read(`../cases/${name}.in`));
    const expected = JSON.parse(read(`./expected/${name}.json`));
    if (notYet.has(name)) {
      assert.ok(!isDeepStrictEqual(actual, expected),
        `${name} now matches the reference: remove it from test/not-yet.txt`);
    } else {
      assert.deepStrictEqual(actual, expected);
    }
  });
}
```

### Python (pytest)

```python
import json, pathlib, pytest
from mypkg import parse

ROOT = pathlib.Path(__file__).parent
CASES = sorted(p.stem for p in (ROOT / "cases").glob("*.in"))
NOT_YET = {l.strip() for l in (ROOT / "not_yet.txt").read_text().splitlines()
           if l.strip() and not l.startswith("#")}

def test_not_yet_names_real_cases():
    assert NOT_YET <= set(CASES), NOT_YET - set(CASES)

@pytest.mark.parametrize("name", CASES)
def test_parity(name):
    actual = parse((ROOT / "cases" / f"{name}.in").read_text())
    expected = json.loads((ROOT / "expected" / f"{name}.json").read_text())
    if name in NOT_YET:
        assert actual != expected, f"{name} now matches: remove it from not_yet.txt"
    else:
        assert actual == expected
```

### Rust

Same shape with one `#[test]` that loops over `cases/` and collects failures
into a `Vec<String>`, so one run reports every case. Use
`include_str!("not_yet.txt")` for the list. A per-case test needs a build
script or a macro; the single looping test is fine if its failure message
names each case.

## 5. Done criteria built on the ratchet

At planning time you ran the reference and the code, so you know the current
list. Write the criteria as exact content, not as "shorter":

```
- [ ] `diff <(grep -v '^#' test/not-yet.txt | sort) <(printf '%s\n' conflict detached quoted-nonascii)`
      prints nothing (4 names left the list; none were added)
- [ ] `scripts/gen-expected.sh && git diff --exit-code test/expected/` exits 0
      (expected outputs still come from the reference)
- [ ] `git diff --exit-code <step-1 commit> -- test/parity.test.js legacy/` exits 0
      (the judge and the reference were not edited after step 1)
```

Add an independent check that does not use any file the executor can edit:
a one-line loop in the plan itself that runs the reference and the code on
every case and prints the names that differ. The reviewer runs it from the
plan text. If the repo's test and the plan's loop disagree, the test has been
tampered with or is wrong.

## 6. Ways an executor games a parity effort, and what catches each

| Move | Caught by |
|------|-----------|
| Edit an expected file to match the code | regenerate from the reference, `git diff --exit-code` |
| Add a case to the not-yet list | exact-content check on the list |
| Leave a fixed case on the list | ratchet rule 3 |
| Loosen the comparison (drop a field, sort differently, compare counts only) | judge frozen after step 1; the plan's independent loop |
| Delete or rename a case file | sanity test plus `git diff --exit-code` on the cases folder |
| Write new unit tests that pass with or without the fix | revert-the-fix check: new tests must fail when the source change is reverted |
| Model a fix on a hand-written fake that has the wrong format | pins section names the fake; live check runs the real thing |

## 7. When the reference is wrong

References have bugs too. If the plan's work shows the reference disagrees
with the real system (for example, a live check shows real CLI output the old
implementation mishandles), that is a STOP condition, not a licence to edit
expected files. The advisor decides, with the user, whether the case leaves the
parity set (recorded in the index as a deliberate divergence, with the reason)
or the reference is patched in a separate, reviewed change.
