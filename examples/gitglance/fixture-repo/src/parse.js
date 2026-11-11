// Node port of legacy/glance.py. Parses `git status --porcelain=v2 --branch`.

export function parse(text) {
  const s = {
    branch: null, detached: false, upstream: null,
    ahead: null, behind: null,
    staged: 0, modified: 0, renamed: 0,
    untracked: 0, conflicted: 0, paths: [],
  };
  for (const line of text.split('\n')) {
    if (!line) continue;
    if (line.startsWith('# branch.head ')) {
      s.branch = line.slice('# branch.head '.length);
    } else if (line.startsWith('# branch.upstream ')) {
      s.upstream = line.slice('# branch.upstream '.length);
    } else if (line.startsWith('# branch.ab ')) {
      const [a, b] = line.slice('# branch.ab '.length).split(' ');
      s.ahead = Number(a.slice(1));
      s.behind = Number(b.slice(1));
    } else if (line.startsWith('# ')) {
      continue;
    } else if (line.startsWith('1 ') || line.startsWith('2 ')) {
      const parts = line.split(' ');
      const xy = parts[1];
      if (xy[0] !== '.') s.staged += 1;
      if (xy[1] !== '.') s.modified += 1;
      s.paths.push(parts[8]);
    } else if (line.startsWith('? ')) {
      s.untracked += 1;
      s.paths.push(line.slice(2));
    }
  }
  s.paths.sort();
  return s;
}

export function formatLine(s) {
  const head = s.detached ? 'HEAD' : (s.branch ?? '?');
  const ab = s.upstream ? ` ↑${s.ahead} ↓${s.behind}` : '';
  const counts = [
    ['+', s.staged], ['~', s.modified], ['R', s.renamed],
    ['?', s.untracked], ['!', s.conflicted],
  ].filter(([, n]) => n > 0).map(([k, n]) => `${k}${n}`).join(' ');
  return `${head}${ab}${counts ? ' ' + counts : ' clean'}`;
}
