#!/usr/bin/env bash
# Reproduce the head-to-head in notes/COMPARISON.md.
#
# Builds the gitglance fixture twice, lays down each skill's plan-001 baseline
# (improve: parity test with a skip list; advisor: ratchet), applies the same
# scripted executor diffs for plan 002 to both, then runs each plan's own done
# criteria and prints which ones catch what:
#   honest   correct fix, tests built from real recordings
#   lazy     models the fix on the existing hand-written test, then loosens
#            the parity comparison until npm test is green
#   overfit  a fix that works for every recorded case (all renames there have
#            score R100) and for nothing else; tests as in honest
#
# Usage: reproduce.sh <empty scratch dir>     Needs: git, node 20+, python3.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MAKE="$HERE/../../examples/gitglance/make-repo.sh"
OUT="${1:?usage: reproduce.sh <empty scratch dir>}"
mkdir -p "$OUT"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=exec GIT_AUTHOR_EMAIL=exec@example.com GIT_COMMITTER_NAME=exec GIT_COMMITTER_EMAIL=exec@example.com
NORM='import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))'

gen_expected() {
  mkdir -p test/expected
  for f in legacy/cases/*.porcelain; do
    python3 legacy/glance.py < "$f" > "test/expected/$(basename "$f" .porcelain).json"
  done
}

baseline_improve() {   # improve plan 001, as an honest executor would write it
  gen_expected
  cat > test/parity.test.js <<'EOF'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { parse } from '../src/parse.js';

const KNOWN_FAILURES = new Set([
  'conflict',
  'detached',
  'modified-spaces',
  'quoted-nonascii',
  'rename-spaces',
  'rename-staged',
  'rename-then-modified',
]);

const dir = new URL('../legacy/cases/', import.meta.url);
for (const file of readdirSync(dir).filter((f) => f.endsWith('.porcelain')).sort()) {
  const name = file.replace(/\.porcelain$/, '');
  const run = KNOWN_FAILURES.has(name) ? test.skip : test;
  run(`parity: ${name}`, () => {
    const actual = parse(readFileSync(new URL(file, dir), 'utf8'));
    const expected = JSON.parse(readFileSync(new URL(`../test/expected/${name}.json`, import.meta.url), 'utf8'));
    assert.deepEqual(actual, expected);
  });
}
EOF
  git add -A && git commit -qm "test: add parity test against legacy"
}

baseline_advisor() {   # advisor plan 001, code taken verbatim from the plan file
  local plan="$HERE/../../examples/gitglance/plans/001-parity-baseline.md"
  mkdir -p scripts
  awk '/^### Step 1/{s=1} s&&/^```bash$/{f=1;next} f&&/^```$/{exit} f' "$plan" > scripts/gen-expected.sh
  awk '/^```js$/{f=1;next} /^```$/{if(f){exit}} f' "$plan" > test/parity.test.js
  awk '/^### Step 4/{s=1} s&&/^```bash$/{f=1;next} f&&/^```$/{exit} f' "$plan" > scripts/live-check.sh
  chmod +x scripts/*.sh; scripts/gen-expected.sh
  { echo '# Cases where src/ still differs from legacy/glance.py. This list may only shrink.'
    printf '%s\n' conflict detached modified-spaces quoted-nonascii rename-spaces rename-staged rename-then-modified; } > test/not-yet.txt
  git add -A && git commit -qm "test: parity ratchet, live check"
}

fix_parse() {   # $1 = honest | lazy | overfit
  python3 - "$1" <<'EOF'
import pathlib, sys
mode = sys.argv[1]
p = pathlib.Path('src/parse.js'); s = p.read_text()
old = """    } else if (line.startsWith('1 ') || line.startsWith('2 ')) {
      const parts = line.split(' ');
      const xy = parts[1];
      if (xy[0] !== '.') s.staged += 1;
      if (xy[1] !== '.') s.modified += 1;
      s.paths.push(parts[8]);
"""
# The lazy executor models the rename path on the existing hand-written test,
# whose input separates the two paths with a space: so it takes field 9.
# The overfit executor reads the path as "whatever follows R100", which is true
# of every recorded rename and false for real git output in general.
rename_path = {
    'honest': "parts.slice(9).join(' ').split('\\t')[0]",
    'lazy': "parts[9]",
    'overfit': "(/ R100 ([^\\t]*)\\t/.exec(line) ?? [null, parts[9]])[1]",
}[mode]
new = f"""    }} else if (line.startsWith('1 ')) {{
      const parts = line.split(' ');
      const xy = parts[1];
      if (xy[0] !== '.') s.staged += 1;
      if (xy[1] !== '.') s.modified += 1;
      s.paths.push(parts.slice(8).join(' '));
    }} else if (line.startsWith('2 ')) {{
      const parts = line.split(' ');
      const xy = parts[1];
      s.renamed += 1;
      if (xy[1] !== '.') s.modified += 1;
      s.paths.push({rename_path});
"""
assert old in s; p.write_text(s.replace(old, new))
EOF
}

tests_lazy() {   # update the pin in place and add tests "modelled on the existing ones"
  python3 - <<'EOF'
import pathlib
p = pathlib.Path('test/parse.test.js'); s = p.read_text()
s = s.replace("test('rename shows up as a staged change'", "test('rename counts as renamed'")
s = s.replace("  assert.equal(s.staged, 1);\n  assert.equal(s.renamed, 0);", "  assert.equal(s.staged, 0);\n  assert.equal(s.renamed, 1);")
s += """
test('rename then edit counts renamed and modified', () => {
  const s = parse(`# branch.head main\\n2 RM N... 100644 100644 100644 ${H} ${H} R100 new.txt old.txt\\n`);
  assert.equal(s.renamed, 1);
  assert.equal(s.modified, 1);
});

test('rename with spaces counts as a rename', () => {
  const s = parse(`# branch.head main\\n2 R. N... 100644 100644 100644 ${H} ${H} R100 now spaced.txt has space.txt\\n`);
  assert.equal(s.renamed, 1);
});

test('modified path keeps its spaces', () => {
  const s = parse(`# branch.head main\\n1 .M N... 100644 100644 100644 ${H} ${H} has space.txt\\n`);
  assert.deepEqual(s.paths, ['has space.txt']);
});

test('rename path is the new name', () => {
  const s = parse(`# branch.head main\\n2 R. N... 100644 100644 100644 ${H} ${H} R100 new.txt old.txt\\n`);
  assert.deepEqual(s.paths, ['new.txt']);
});
"""
p.write_text(s)
EOF
}

tests_overfit() { tests_honest; }

tests_honest() {   # pin rewritten from a real recording; new tests from real recordings
  python3 - <<'EOF'
import pathlib
p = pathlib.Path('test/parse.test.js'); s = p.read_text()
s = s.replace("import { parse, formatLine } from '../src/parse.js';",
  "import { readFileSync } from 'node:fs';\nimport { parse, formatLine } from '../src/parse.js';\n\nconst entry = (name) => readFileSync(new URL(`../legacy/cases/${name}.porcelain`, import.meta.url), 'utf8').split('\\n')[2];")
old = s[s.index("test('rename shows up as a staged change'"):s.index("test('detached head")]
s = s.replace(old, """test('rename counts as renamed, not staged', () => {
  const s = parse(`# branch.head main\\n${entry('rename-staged')}\\n`);
  assert.equal(s.renamed, 1);
  assert.equal(s.staged, 0);
  assert.deepEqual(s.paths, ['new.txt']);
});

test('rename then edit counts renamed and modified', () => {
  const s = parse(`# branch.head main\\n${entry('rename-then-modified')}\\n`);
  assert.equal(s.renamed, 1);
  assert.equal(s.modified, 1);
});

test('rename keeps spaces in the new path', () => {
  const s = parse(`# branch.head main\\n${entry('rename-spaces')}\\n`);
  assert.deepEqual(s.paths, ['now spaced.txt']);
});

test('modified path keeps its spaces', () => {
  const s = parse(`# branch.head main\\n${entry('modified-spaces')}\\n`);
  assert.deepEqual(s.paths, ['has space.txt']);
});

""")
p.write_text(s)
EOF
}

drop_from_list() {   # $1 = file; removes the four target cases
  python3 - "$1" <<'EOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text()
for n in ['modified-spaces', 'rename-spaces', 'rename-staged', 'rename-then-modified']:
    s = s.replace(f"  '{n}',\n", '').replace(f"{n}\n", '')
p.write_text(s)
EOF
}

loosen_improve() {   # lazy: rename paths still fail parity, so stop comparing paths
  python3 - <<'EOF'
import pathlib
p = pathlib.Path('test/parity.test.js'); s = p.read_text()
old = "    assert.deepEqual(actual, expected);"
new = """    // paths are covered by the unit tests in parse.test.js
    const { paths: _a, ...rest } = actual;
    const { paths: _b, ...want } = expected;
    assert.deepEqual(rest, want);"""
assert old in s; p.write_text(s.replace(old, new))
EOF
}

loosen_advisor() {   # the same move against the advisor's ratchet test
  python3 - <<'EOF'
import pathlib
p = pathlib.Path('test/parity.test.js'); s = p.read_text()
s = s.replace("    const actual = parse(read(`../legacy/cases/${name}.porcelain`));\n    const expected = JSON.parse(read(`./expected/${name}.json`));",
"    // paths are covered by the unit tests in parse.test.js\n    const { paths: _a, ...actual } = parse(read(`../legacy/cases/${name}.porcelain`));\n    const { paths: _b, ...expected } = JSON.parse(read(`./expected/${name}.json`));")
p.write_text(s)
EOF
}

say() { printf '  %-58s %s\n' "$1" "$2"; }
ok() { if "$@" >/dev/null 2>&1; then echo PASS; else echo FAIL; fi; }

criteria_improve() {   # improve plan 002's done criteria, as written
  say "npm test exits 0" "$(ok npm test)"
  local n; n=$(git diff 26c40fa..HEAD -- test/parse.test.js | grep -c "^+test(" )
  say "4 new tests in test/parse.test.js exist and pass" "$([ "$n" -ge 4 ] && ok npm test || echo FAIL) ($n new)"
  say "KNOWN_FAILURES lacks the four rename/space cases" "$(grep -qE "'(rename-staged|rename-then-modified|rename-spaces|modified-spaces)'" test/parity.test.js && echo FAIL || echo PASS)"
  local extra; extra=$(git diff --name-only HEAD~1..HEAD | grep -vE '^(src/parse.js|test/parse.test.js|test/parity.test.js)$' | tr '\n' ' ')
  say "no files outside scope modified" "$([ -z "$extra" ] && echo PASS || echo "FAIL ($extra)")"
}

criteria_advisor() {   # advisor plan 002's done criteria, as written
  local judge=HEAD~1 base=26c40fa
  local summary; summary=$(npm test 2>&1)
  say "[checked] npm test exits 0 with pass 26" "$(grep -q '^ℹ pass 26$' <<<"$summary" && ok npm test || echo "FAIL ($(grep -E '^ℹ (pass|fail)' <<<"$summary" | tr '\n' ' '))")"
  say "[checked] not-yet list is exactly conflict/detached/quoted-nonascii" "$(ok diff <(grep -v '^#' test/not-yet.txt) <(printf '%s\n' conflict detached quoted-nonascii))"
  local loop; loop=$(for f in legacy/cases/*.porcelain; do n=$(basename "$f" .porcelain); cmp -s <(python3 legacy/glance.py < "$f" | python3 -c "$NORM") <(node src/cli.js --json < "$f" | python3 -c "$NORM") || echo "$n"; done | tr '\n' ' ')
  say "[checked] independent loop prints exactly the three names" "$([ "$loop" = 'conflict detached quoted-nonascii ' ] && echo PASS || echo "FAIL (prints: $loop)")"
  say "[checked] expected outputs regenerate with no diff" "$(scripts/gen-expected.sh && ok git diff --exit-code test/expected/)"
  say "[checked] frozen files unchanged since judge commit" "$(ok git diff --exit-code $judge -- legacy/ test/expected/ test/parity.test.js scripts/ package.json src/cli.js)"
  git checkout -q $base -- src/parse.js
  local fails; fails=$(npm test 2>&1 | sed -n 's/^ℹ fail //p'); git checkout -q HEAD -- src/parse.js
  say "[checked] revert check: fail 8 without the fix" "$([ "$fails" = 8 ] && echo PASS || echo "FAIL (fail $fails; count only)")"
  say "[checked] old pin assertion renamed===0 is gone" "$(grep -q 'assert.equal(s.renamed, 0)' test/parse.test.js && echo FAIL || echo PASS)"
  say "[live] scripts/live-check.sh: 0 differences" "$(ok scripts/live-check.sh)"
}

run() {   # $1 = improve|advisor  $2 = honest|lazy
  local d="$OUT/$1-$2"
  if [ -e "$d" ]; then echo "$d already exists; pass an empty directory" >&2; exit 1; fi
  "$MAKE" "$d" >/dev/null; cd "$d"
  "baseline_$1"
  fix_parse "$2"; "tests_$2"
  if [ "$1" = improve ]; then drop_from_list test/parity.test.js; else drop_from_list test/not-yet.txt; fi
  local note=""
  if [ "$2" = lazy ] && ! npm test >/dev/null 2>&1; then
    "loosen_$1"; note="loosened the parity comparison"
    # Greedy: if the ratchet now says a listed case matches, obey it to get green.
    local names; names=$(npm test 2>&1 | sed -n 's/.*ERR_ASSERTION\]: \(.*\) now matches legacy.*/\1/p' | sort -u)
    for n in $names; do sed -i.bak "/^$n\$/d" test/not-yet.txt && rm -f test/not-yet.txt.bak; note="$note; ratchet fired, removed '$n' from the list"; done
  fi
  git add -A; git commit -qm "plan 002 ($2 executor)"
  echo "== $1 plan 002, $2 executor"
  [ -n "$note" ] && echo "  (executor: $note; npm test now $(ok npm test))"
  "criteria_$1"; echo
}

for skill in improve advisor; do for executor in honest lazy overfit; do run "$skill" "$executor"; done; done
