# Routing: plan it, probe first, or do it directly

A handoff is not free. Each plan costs the advisor a recon pass, writing, a
cold read, a dispatch, and a review. Each STOP costs another round: the
executor reports, the advisor re-reads the plan and the code, rewrites, and
dispatches again. That trade is good when execution is long and predictable,
and bad when the change is tiny or when reality keeps surprising everyone.

Route every vetted finding before writing anything.

## The question to ask

**How many times do you expect this plan to STOP?**

- **0:** PLAN.
- **1, and the surprise is about how an external system behaves:** PROBE. Plan
  a recording step first; plan the change after the recordings exist.
- **2 or more, or you cannot guess:** DIRECT.

Then sanity-check with the signals below.

## PLAN when most of these hold

- The change is mechanical or fully specified: a port to parity, a rename
  across many files, backfilling tests against known behaviour, a dependency
  bump with a clear migration guide, one fix applied in many places.
- You have read every code path the change touches, not inferred it.
- A command you can write today will say whether it worked, ideally a ratchet
  against a reference.
- The real systems involved have already been observed (recorded cases exist),
  or none are involved.
- Execution is long enough that a cheaper model doing it saves real money:
  more than about an hour of a capable model's work, or many similar edits.

## PROBE when

- The plan would depend on how a real CLI, service or device behaves, and
  nobody has recorded it yet.
- The probe is safe and cheap: read-only calls, a sandbox, a scratch repo.

A probe plan's only deliverable is cases: a recording script checked into the
repo, run twice to show it is stable, and the recordings, with credentials
and personal data stripped by the script. No source changes.
Once the cases exist, the follow-up is usually an ordinary PLAN with a
ratchet. Probes turn integration guesswork into plannable work.

## DIRECT when any of these hold

- **Too small.** Roughly under twenty changed lines in one or two files, with
  one obvious check. The plan would be longer than the diff.
- **Too live.** Integration where each real run is likely to change the plan:
  a protocol with undocumented behaviour, a race between processes, a device
  that responds differently than its docs, a CLI whose flags differ by
  version. The capable model should run, look, adjust and run again in one
  session, with the real system in the loop.
- **Already bounced.** Two plans for this work came back BLOCKED because
  reality differed from the plan. A third plan will too.
- **Judgement is the work.** API shape, naming, UX copy, a design trade-off.
  Write a short design note for the user instead of a plan.

For each DIRECT item, give the user a five-to-ten-line recipe: what to change,
where, and the check that proves it. Under this skill you still do not make the
edit (Rule 6). The user does it, or asks a normal session to.

## Examples

| Finding | Route | Why |
|---------|-------|-----|
| CLI exits 0 when the wrapped tool fails; fix is one line plus one test | DIRECT | too small |
| Port 40 command handlers to parity with the old implementation, recorded outputs exist | PLAN | mechanical, ratchet available |
| Support a service's streaming mode, never observed, docs thin | PROBE | record a few real sessions first |
| Make the app survive the CLI's stdout closing before its exit code arrives | DIRECT | race in a live system; iterate with the real CLI |
| Plan for a device mode, BLOCKED twice on "device ignores flag" | DIRECT | already bounced |
| Rename `Session` to `Thread` across 120 files | PLAN | mechanical, compiler is the check |
| Choose between two permission models | DIRECT (design note) | judgement is the work |

## Saying it

In the findings table the Route column carries the decision; for DIRECT items
the recipe follows the table. Be plain: "Not worth a plan: about eight lines in
`src/cli.js`. Do it directly: ... Check: ...". Recommending direct work is not
a failure of the skill; it is the skill doing its job.
