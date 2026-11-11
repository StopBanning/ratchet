#!/usr/bin/env node
// gitglance: one-line summary of `git status`.
//   gitglance          run git in the current directory and print a summary line
//   gitglance --json   read porcelain v2 text on stdin and print the JSON summary
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { parse, formatLine } from './parse.js';

if (process.argv.includes('--json')) {
  const input = readFileSync(0, 'utf8');
  process.stdout.write(JSON.stringify(parse(input)) + '\n');
} else {
  try {
    const out = execFileSync('git', ['status', '--porcelain=v2', '--branch'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    console.log(formatLine(parse(out)));
  } catch (err) {
    console.error(`gitglance: ${err.stderr?.toString().trim() || err.message}`);
  }
}
