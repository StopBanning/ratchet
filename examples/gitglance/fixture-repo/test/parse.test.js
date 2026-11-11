import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parse, formatLine } from '../src/parse.js';

const OID = '# branch.oid 4a1f13f32ae78e03b0b926a7a09f12e0d5f9764d';
const H = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

test('clean repo on main', () => {
  const s = parse(`${OID}\n# branch.head main\n`);
  assert.equal(s.branch, 'main');
  assert.equal(formatLine(s), 'main clean');
});

test('ahead and behind come from branch.ab', () => {
  const s = parse(`${OID}\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +2 -1\n`);
  assert.deepEqual([s.ahead, s.behind], [2, 1]);
  assert.equal(formatLine(s), 'main ↑2 ↓1 clean');
});

test('staged and unstaged edits are counted separately', () => {
  const s = parse(`# branch.head main\n1 MM N... 100644 100644 100644 ${H} ${H} a.txt\n`);
  assert.equal(s.staged, 1);
  assert.equal(s.modified, 1);
  assert.deepEqual(s.paths, ['a.txt']);
});

test('untracked files are listed', () => {
  const s = parse(`# branch.head main\n? notes.md\n`);
  assert.equal(s.untracked, 1);
  assert.deepEqual(s.paths, ['notes.md']);
});

test('rename shows up as a staged change', () => {
  const s = parse(`# branch.head main\n2 R. N... 100644 100644 100644 ${H} ${H} R100 new.txt old.txt\n`);
  assert.equal(s.staged, 1);
  assert.equal(s.renamed, 0);
});

test('detached head keeps the marker as the branch name', () => {
  const s = parse(`${OID}\n# branch.head (detached)\n`);
  assert.equal(s.branch, '(detached)');
});
