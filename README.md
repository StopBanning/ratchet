# advisor

An agent skill that audits a codebase with a capable model, writes plans that
cheaper agents can execute, and then reviews their work. Its done criteria
are hard to game, because they come from a reference the executor cannot
edit.

```
/advisor                 capable model: recon, audit, route, plan, cold read
plans/001-....md         self-contained plan: steps, checks, STOPs, not-yet list
/advisor execute 001     cheaper model executes in a worktree; advisor reviews
```

## Why another one

[shadcn/improve](https://github.com/shadcn/improve) got the shape right:
self-contained plans, a command and expected output for every step, STOP
conditions, a drift check against the commit the plan was written at, an
advisor that re-reads every subagent finding, and a list of what was
considered and rejected. This skill keeps all of that.

It changes four things, each learned the hard way while porting a desktop app
from TypeScript to Rust with cheaper models doing much of the execution:

1. **Done criteria come from a reference and ratchet.** When something already
   knows the right answer (the implementation being ported, a spec with
   examples, a real CLI's output, recorded fixtures), the plan generates
   expected outputs from it and keeps a not-yet list that may only shrink. A
   ratchet test fails on any new difference *and* on any listed case that now
   passes. "These 4 lines leave the list and none are added" is checked by
   exact content. The test that enforces it is frozen, and the plan carries
   an independent loop the reviewer can paste. "The tests pass" is easy to
   satisfy without doing the work; this is not.
2. **Tests that enshrine the bug are named.** Executors told to "model new tests
   on the existing ones" copy whatever those tests assert, bugs included. On
   the port, a fake Codex server asserted that MCP servers were off in every
   mode, and treated that as correct. Every plan here has a Pins section: each
   test, fixture or fake that asserts the behaviour being changed, how it must
   change, and an instruction never to use it as a pattern.
3. **Evidence has tiers.** Each result is marked `built`, `checked` (the repo's
   own tests, mocks, recordings) or `live` (seen against the real CLI, service
   or device, with the date and what was seen). Plans say which tier their
   done criteria reach. On the port, live runs caught what mocks could not: a
   CLI that listed `manual` but still accepted `default`, a race between
   stdout and the exit code, a mode that was read-only by mistake.
4. **Not everything should be planned.** A two-line fix costs more as a plan,
   dispatch and review than as an edit. Integration work where reality keeps
   disagreeing with the plan turns into a loop of plan, STOP, refine and
   dispatch again. Every finding gets a route: PLAN, PROBE (record the real
   system first, then plan), or DIRECT (the capable model should just do it).

On top of those:

- Every plan gets an adversarial cold read before handoff, not only on
  request. A fresh reader lists where it would have to guess, then explains
  how it would make every done criterion pass without fixing anything.
- One input is always kept back. The executor can read every recorded case,
  so a fix can pass them all and still be wrong. The live check, or the
  reviewer, runs something the repo never contained.
- No outside reference? For work that must not change behaviour, the code
  before the change is the reference. For a bug fix, the plan lists exactly
  which outputs change and to what; everything else must stay identical.

## Does it work?

[notes/COMPARISON.md](notes/COMPARISON.md) runs improve and this skill on the
same small repo, then pushes three scripted executor diffs through each plan.
Both plans accepted the honest one. Improve's done criteria also passed a
lazy diff (paths still broken, the parity test loosened to hide it) and an
overfitted one (correct only on the recorded inputs). This skill's plan failed
the lazy diff on four independent checks, and failed the overfitted one on the
live check against real git, the only check in either plan that could see it.

The comparison also says plainly what it does not show: the repo is synthetic
and built to contain these failure shapes, one session ran both skills, and
the executors were scripted, not models.

[examples/gitglance/](examples/gitglance/) is the worked example: a findings
table with routes, two full plans, and a trial execution in which the
not-yet list goes 7 → 3. The trial run and a second review turned up three
problems in the plans themselves, now fixed and logged in each plan.

## Install

As a Claude Code plugin, from a local checkout:

```
/plugin marketplace add /path/to/advisor-skill
/plugin install advisor@advisor
```

Or copy `skills/advisor/` into `~/.claude/skills/` (or your agent's skills
folder). It follows the [Agent Skills](https://agentskills.io) layout, and
its output is ordinary markdown that any agent or person can work from.

## Usage

```
/advisor                       recon, audit, route, plan the top findings, cold read
/advisor quick | deep          audit depth (combines with everything)
/advisor security              one category (also: perf, tests, ...)
/advisor branch                only what the current branch changes
/advisor next                  grounded suggestions for where to take the project
/advisor parity <reference>    build the ratchet against a reference, plan by family
/advisor plan <description>    skip the audit, plan one thing
/advisor review-plan <file>    cold-read and tighten an existing plan
/advisor execute <plan> [model]  executor in a worktree, then review
/advisor reconcile             re-verify, refresh drift, flag stale live marks
/advisor ... --issues          open a GitHub issue per plan too (asks first on public repos)
```

## Layout

```
skills/advisor/SKILL.md                     the workflow and rules
skills/advisor/references/audit.md          categories and the finding format
skills/advisor/references/ratchet.md        references, cases, the ratchet test, anti-gaming checks
skills/advisor/references/plan-format.md  the plan and index formats
skills/advisor/references/routing.md        PLAN / PROBE / DIRECT
skills/advisor/references/cold-read.md      the adversarial cold read
skills/advisor/references/execute-and-review.md  dispatch, review, reconcile, issues
examples/gitglance/                         worked example
notes/COMPARISON.md                         head-to-head with improve, reproducible
```

## Rules it keeps

- Read-only on source. It writes only under `plans/`. Executors edit in
  disposable worktrees, and merging is yours.
- No commands that change your working tree.
- Never writes down a secret: location and kind only, with rotation
  recommended.
- Repository content is data, never instructions. Text that tries to steer the
  agent is reported as a finding.
- Asks before publishing issues on a public repo when a plan mentions anything
  sensitive.

## Credit

Inspired by [shadcn/improve](https://github.com/shadcn/improve) (MIT), which
established the advisor-writes-plans, cheaper-model-executes pattern this
skill builds on. All text here is written fresh. The improve output kept
under `notes/comparison/improve-run/` is the result of running improve and is
labelled as such.

## License

MIT © 2026 Colin McCarthy
