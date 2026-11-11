# 002: Rename entries and paths with spaces match legacy/glance.py

> **For the executor.** Work through the steps in order. After each step, run
> its check and compare with the expected result before going on. If a STOP
> condition happens, stop and report; do not work around it. Files under
> "Frozen" must not change at all. Report the evidence tier of each done
> criterion using the words built / checked / live.
>
> **Drift check, before anything else:**
> `git diff --stat 26c40fa..HEAD -- src/ test/parse.test.js legacy/ package.json`
> Empty output: go ahead. Any output: compare the excerpts below with the live
> files; if they differ, that is a STOP. (Plan 001's new files are expected to
> exist; they are not in this check.)

## Header

- Route: PLAN
- Size S · fix risk low · priority 1
- Needs first: `plans/001-parity-baseline.md` (DONE; it creates the ratchet)
- Planned at: `26c40fa`, 2026-11-11; judge commit = plan 001's last commit
- Reference: `legacy/glance.py` on `legacy/cases/*.porcelain`
- Evidence target: live (`scripts/live-check.sh` on fresh real git output)

## Why

After `git mv`, gitglance shows the file as a staged edit (`+1`) instead of a
rename (`R1`), and lists the similarity score `R100` as if it were a file
name. Any path containing a space is cut at the first space. One branch in
`parse()` treats rename lines like ordinary lines and splits every line on
single spaces. The Python original handles both; this plan brings the port in
line for those four cases and no others.

## Current state

`src/parse.js:22-27`:

```js
    } else if (line.startsWith('1 ') || line.startsWith('2 ')) {
      const parts = line.split(' ');
      const xy = parts[1];
      if (xy[0] !== '.') s.staged += 1;
      if (xy[1] !== '.') s.modified += 1;
      s.paths.push(parts[8]);
```

Reference, `legacy/glance.py` (the behaviour to reproduce):

```python
        elif line.startswith('1 '):
            parts = line.split(' ', 8)          # at most 9 fields: the path keeps its spaces
            xy = parts[1]
            if xy[0] != '.':
                s['staged'] += 1
            if xy[1] != '.':
                s['modified'] += 1
            s['paths'].append(unquote(parts[8]))
        elif line.startswith('2 '):
            parts = line.split(' ', 9)          # at most 10 fields
            xy = parts[1]
            s['renamed'] += 1                   # a rename is counted as renamed, not staged
            if xy[1] != '.':
                s['modified'] += 1
            new_path = parts[9].split('\t', 1)[0]   # "<new path>\t<old path>"
            s['paths'].append(unquote(new_path))
```

`unquote` (non-ASCII names) is plan 005's job. Do not port it here.

Real rename line, `legacy/cases/rename-spaces.porcelain` line 3 (`→` is a tab):

```
2 R. N... 100644 100644 100644 b478...00fc b478...00fc R100 now spaced.txt→has space.txt
```

Conventions: `node:test` + `assert/strict`, one `test()` per behaviour. Follow
the structure of `test/parse.test.js:20-25` ("staged and unstaged edits are
counted separately"), which is not a pin.

## Reference and ratchet

- Ratchet from plan 001: `test/parity.test.js`, `test/not-yet.txt`,
  `test/expected/`, `scripts/gen-expected.sh`.
- **Not-yet list today:**
  ```
  conflict
  detached
  modified-spaces
  quoted-nonascii
  rename-spaces
  rename-staged
  rename-then-modified
  ```
- **Not-yet list when done:**
  ```
  conflict
  detached
  quoted-nonascii
  ```
  `modified-spaces`, `rename-spaces`, `rename-staged`, `rename-then-modified`
  leave. **None may be added.** If your change makes any other case differ,
  that is a STOP, not a reason to list it.
- Independent check (paste as is; uses no file this plan may edit):
  ```
  norm='import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))'
  for f in legacy/cases/*.porcelain; do n=$(basename "$f" .porcelain); \
    cmp -s <(python3 legacy/glance.py < "$f" | python3 -c "$norm") \
           <(node src/cli.js --json < "$f" | python3 -c "$norm") || echo "$n"; done
  ```
  Expected when done: `conflict`, `detached`, `quoted-nonascii`, one per line.

## Pins: tests that assert today's behaviour

- **`test/parse.test.js:33-37`, "rename shows up as a staged change". Change it.**
  It asserts `staged 1, renamed 0`, which is the bug. Its input is also wrong:
  it separates the two paths with a space, but real git uses a tab, so a fix
  modelled on this input will pass this test and fail on real output. Rewrite
  it as:
  - name: `rename counts as renamed, not staged`
  - input: `# branch.head main\n` followed by line 3 of
    `legacy/cases/rename-staged.porcelain`, copied byte for byte (tab included).
    Read it from the file in the test if you prefer:
    `readFileSync(new URL('../legacy/cases/rename-staged.porcelain', import.meta.url), 'utf8')`.
  - asserts: `renamed === 1`, `staged === 0`, `paths` deep-equals `['new.txt']`.
- **`test/parse.test.js:39-42`, "detached head ...". Do not change it.** It also
  asserts a bug, but that is plan 004's. It must still pass after this plan.
- **Do not use either pin as a model** for new tests, and do not hand-type
  porcelain lines for renames: take them from `legacy/cases/`.

## Commands

| Purpose | Command | Expected | Seen at planning time |
|---------|---------|----------|-----------------------|
| Tests | `npm test` | exit 0 | exit 0, 23 pass (after plan 001) |
| Independent check | loop above | three names when done | seven names today |
| Expected outputs | `scripts/gen-expected.sh && git diff --exit-code test/expected/` | exit 0 | yes |
| Live check | `scripts/live-check.sh` | `live: 0 differences` when done | `live: 1 difference` today |

## Scope

**May change:** `src/parse.js`, `test/parse.test.js`, `test/not-yet.txt`
(delete lines only).

**Frozen** (checked against the judge commit): `legacy/`, `test/expected/`,
`test/parity.test.js`, `scripts/`, `package.json`, `src/cli.js`.

**Out of scope:** `u` lines (plan 003), detached HEAD (plan 004), quoted
paths and `unquote` (plan 005), `formatLine`.

## Git

- Branch `advisor/002-renames-and-spaces` from plan 001's branch.
- One commit per step, `fix: ...` / `test: ...`.
- No push, no PR.

## Steps

### Step 1: Split ordinary and rename lines

Replace `src/parse.js:22-27` with two branches. Target shape:

```js
    } else if (line.startsWith('1 ')) {
      const parts = line.split(' ');
      const xy = parts[1];
      if (xy[0] !== '.') s.staged += 1;
      if (xy[1] !== '.') s.modified += 1;
      s.paths.push(parts.slice(8).join(' '));
    } else if (line.startsWith('2 ')) {
      const parts = line.split(' ');
      const xy = parts[1];
      s.renamed += 1;
      if (xy[1] !== '.') s.modified += 1;
      s.paths.push(parts.slice(9).join(' ').split('\t')[0]);
```

**Check:** the independent check prints exactly `conflict`, `detached`,
`quoted-nonascii`. `npm test` now **fails** in exactly five tests: the four
`parity:` tests for the fixed cases (each says "now matches legacy/glance.py:
remove it from test/not-yet.txt") and the pin at `test/parse.test.js:33`.
That is expected.

### Step 2: Shrink the list

Delete `modified-spaces`, `rename-spaces`, `rename-staged`,
`rename-then-modified` from `test/not-yet.txt`. Delete nothing else; add nothing.

**Check:** `npm test` fails in exactly one test, the rename pin.

### Step 3: Fix the pin and add tests

Rewrite the pin as described under Pins. Add three tests, inputs copied from
the named case files (line 3 of each, prefixed with `# branch.head main\n`):

- `rename then edit counts renamed and modified`: from
  `rename-then-modified.porcelain`; asserts `renamed 1`, `modified 1`,
  `staged 0`, `paths ['new.txt']`.
- `rename keeps spaces in the new path`: from `rename-spaces.porcelain`;
  asserts `paths ['now spaced.txt']`.
- `modified path keeps its spaces`: from `modified-spaces.porcelain`; asserts
  `modified 1`, `paths ['has space.txt']`.

**Check:** `npm test` → exit 0, `pass 26` (23 + 3 new; the pin was rewritten,
not added).

**Revert check:** put back the pre-fix source, run the tests, restore:
`git checkout 26c40fa -- src/parse.js && npm test; git checkout HEAD -- src/parse.js`
→ `fail 8`: the four fixed `parity:` cases, the three new tests and the
rewritten pin. After the restore, `git status --porcelain` prints nothing and
`npm test` → exit 0.

### Step 4: Live check

**Check:** `scripts/live-check.sh` → `cli: main ~1 R2 ?1`,
`live: 0 differences`, exit 0. Put the full output (git version and date
included) in your report. The script feeds the port a rename line no recorded
case has (score `R87`), so it also shows the fix is not tied to the recordings.

## Tests

- 3 new tests and 1 rewritten pin in `test/parse.test.js`, all with inputs
  from real recordings.
- Revert check as in Step 3.

## Done criteria

- [ ] [checked] `npm test` exits 0 with `pass 26`
- [ ] [checked] `diff <(grep -v '^#' test/not-yet.txt) <(printf '%s\n' conflict detached quoted-nonascii)` prints nothing
- [ ] [checked] independent check prints exactly `conflict`, `detached`, `quoted-nonascii`
- [ ] [checked] `scripts/gen-expected.sh && git diff --exit-code test/expected/` exits 0
- [ ] [checked] `git diff --exit-code <judge commit> -- legacy/ test/expected/ test/parity.test.js scripts/ package.json src/cli.js` exits 0
- [ ] [checked] revert check gives `fail 8`, including the 3 new tests and the rewritten pin
- [ ] [checked] `grep -n "assert.equal(s.renamed, 0)" test/parse.test.js` prints nothing
- [ ] [live] `scripts/live-check.sh` prints `live: 0 differences`; report the date and git version
- [ ] `git diff --name-only <plan 001 head>..HEAD` lists only `src/parse.js`, `test/parse.test.js`, `test/not-yet.txt`

## STOP conditions

- Drift check mismatch.
- After Step 1 the independent check prints any name not in the today list,
  or still prints one of the four target names.
- Any test other than the five named in Step 1 fails at any point.
- Making a check pass seems to need a change to a frozen file.
- `scripts/live-check.sh` still reports a difference after Step 3. Report its
  output; do not change the script.

## Cold read

- 2026-11-11, dry run (advisor executed the plan in a scratch worktree):
  the revert check used `git stash push -- src/parse.js`, which does nothing
  once the fix is committed, as Step 1 tells the executor to do. It now checks
  out the pre-fix file from the planned-at commit. The frozen check pointed at
  the wrong judge commit (see plan 001). Both fixed; every other expected
  output matched exactly.
- 2026-11-11, self-read (no subagents on this host): flagged that "update the
  rename test" would let an executor keep the space-separated input, so the
  pin section now dictates the input source and the assertions; flagged that
  a lazy executor could re-add a fixed case to the list "to be safe", so the
  list check is exact content and re-adding is a named STOP; flagged that
  `src/cli.js` could be edited to post-process JSON, so it is frozen.

## Maintenance

- Plan 003 adds a `u ` branch next to the new `2 ` branch, and plan 005 wraps
  each pushed path in `unquote`.
- Copies (`C` in the X column of a `2` line) take the same branch. No case
  covers them; if one is recorded, it joins the parity set automatically.
- Reviewer: confirm the rename path is split on the tab, not on a space, and
  that nothing in the new branch depends on a value only the recorded cases
  share (every recorded rename has score `R100`).
