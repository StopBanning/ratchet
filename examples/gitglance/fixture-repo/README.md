# gitglance

Prints a one-line summary of `git status`, e.g. `main ↑1 ↓0 +2 ~1 R1 ?3`.

This is a Node port of the original Python tool, kept in `legacy/glance.py`.
Until the port reaches parity, the Python version is the source of truth: for
the same `git status --porcelain=v2 --branch` input, both must print the same
JSON (`python3 legacy/glance.py < input` vs `node src/cli.js --json < input`).

`legacy/cases/` holds porcelain output recorded from real git by
`scripts/record-cases.sh` (the Python version's own test inputs). The Node
tests in `test/` don't use them yet.

## Develop

    npm test
