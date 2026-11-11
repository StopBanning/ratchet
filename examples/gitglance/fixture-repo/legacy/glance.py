#!/usr/bin/env python3
"""gitglance (legacy Python version).

Reads `git status --porcelain=v2 --branch` output on stdin and prints a JSON
summary. This is the reference implementation: the Node port in src/ must
produce identical JSON for every input.
"""
import json
import sys


def unquote(path):
    """Undo git's C-style quoting ("caf\\303\\251.txt" -> "café.txt")."""
    if not (len(path) >= 2 and path[0] == '"' and path[-1] == '"'):
        return path
    body = path[1:-1]
    out = bytearray()
    i = 0
    simple = {'n': 10, 't': 9, '"': 34, '\\': 92, 'a': 7, 'b': 8, 'f': 12, 'r': 13, 'v': 11}
    while i < len(body):
        c = body[i]
        if c == '\\' and i + 1 < len(body):
            nxt = body[i + 1]
            if nxt in simple:
                out.append(simple[nxt])
                i += 2
                continue
            if nxt.isdigit():
                out.append(int(body[i + 1:i + 4], 8))
                i += 4
                continue
        out.extend(c.encode('utf-8'))
        i += 1
    return out.decode('utf-8', errors='replace')


def summarize(text):
    s = {
        'branch': None, 'detached': False, 'upstream': None,
        'ahead': None, 'behind': None,
        'staged': 0, 'modified': 0, 'renamed': 0,
        'untracked': 0, 'conflicted': 0, 'paths': [],
    }
    for line in text.splitlines():
        if not line:
            continue
        if line.startswith('# branch.head '):
            head = line[len('# branch.head '):]
            if head == '(detached)':
                s['detached'] = True
            else:
                s['branch'] = head
        elif line.startswith('# branch.upstream '):
            s['upstream'] = line[len('# branch.upstream '):]
        elif line.startswith('# branch.ab '):
            a, b = line[len('# branch.ab '):].split(' ')
            s['ahead'], s['behind'] = int(a[1:]), int(b[1:])
        elif line.startswith('# '):
            continue
        elif line.startswith('1 '):
            parts = line.split(' ', 8)
            xy = parts[1]
            if xy[0] != '.':
                s['staged'] += 1
            if xy[1] != '.':
                s['modified'] += 1
            s['paths'].append(unquote(parts[8]))
        elif line.startswith('2 '):
            parts = line.split(' ', 9)
            xy = parts[1]
            s['renamed'] += 1
            if xy[1] != '.':
                s['modified'] += 1
            new_path = parts[9].split('\t', 1)[0]
            s['paths'].append(unquote(new_path))
        elif line.startswith('u '):
            parts = line.split(' ', 10)
            s['conflicted'] += 1
            s['paths'].append(unquote(parts[10]))
        elif line.startswith('? '):
            s['untracked'] += 1
            s['paths'].append(unquote(line[2:]))
    s['paths'].sort()
    return s


if __name__ == '__main__':
    print(json.dumps(summarize(sys.stdin.read()), sort_keys=True, ensure_ascii=False))
