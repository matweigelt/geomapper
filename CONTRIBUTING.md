# Contributing to GeoMapper

**How a change reaches `main` is in [`WORKFLOW.md`](WORKFLOW.md).** Read
that first; this file is about the content of a change, not its route.

## The short version

1. `HANDOVER.md` is the single source of truth. Read it before the code.
2. Run `./tools/gates.sh` to zero before pushing. CI confirms; it does not discover.
3. A tolerance is never widened to make a test pass. That is a finding.
4. Every number is measured before it is asserted, against something not built here.

## Where things live

| File | Holds | Never holds |
|---|---|---|
| `HANDOVER.md` | rules, design, ledger, decisions | round-by-round narrative |
| `RECORDS.md` | archived evidence, one entry per stage | status of any kind |
| `docs/BEST_PRACTICE_v4.md` | cross-project rules, binding | anything project-specific |

If you find yourself writing a status in `RECORDS.md`, or a measurement in
`HANDOVER.md`, the split has failed and needs re-taking rather than patching.

## Before you write code

**Validate the specification first.** If the mathematics, tolerance,
reference value or acceptance criterion you were handed is wrong, that is
a finding — report it with its measurement *before* writing the code. The
first pre-validation run on this project refuted four numbers in its own
design document. A stage that reports no findings has probably not looked.

**Name the oracle.** If you cannot say what your work will be checked
against that was not built here, the task is not ready. The register is
`HANDOVER.md` Part 3.

## Tests

Seven categories: `contract`, `reference`, `precision`, `speed`,
`robustness`, `vectorisation`, `metamorphic`. Declare which your suite
ships. Anything missing and not in `tests/EXEMPTIONS.md` is a gap, not an
exemption — and an exemption is a claim that the test is *impossible*, not
that it is inconvenient.

Derive from `GeoMapTestCase`. Declare `CoveredFunctions` so the coverage
report can see your suite.

Speed assertions go through `GeoMapTestCase.assertRatioBudget` and nothing
else. Ratios, never absolutes; both points timed inside one repeat; the
order rotated. If you want a local median helper, you want the shared one.

## Warnings

Exactly one identifier may appear in a clean run: `geo:internal:testProbe`.
A test that deliberately provokes a warning calls
`tc.suppressWarning(id)`, which restores on teardown. Do not silence an
identifier where it cannot fire — an unnecessary suppression teaches the
next reader that the identifier is unavoidable.

## Documentation

Ships in the same change as the code, on every surface. The help-text
template is `HANDOVER.md` §2.8.1 and is machine-parsed, so the section
headers are fixed. Every function carries an `ACCURACY` block naming its
oracle, and errors grouped by cause.

## Branching

- Branch from the remote head **immediately before pushing**, never earlier.
  Three pull requests collided on duplicate version bumps in a reference
  project because each branched from a main that was current at session
  start and stale at push.
- Read the pull-request state through the API before every push. A push
  onto a branch whose PR is already merged or closed is work delivered to
  a graveyard, and the check costs one call.
- A superseded pull request is closed, not left open, with one sentence
  saying why.
- Only a human advances `main`.

## Diagnosing a failure

In this order, cheapest repair first:

1. **Configuration** — replay the exact frozen script, never a recollection.
2. **Criterion** — re-derive against an external authority. Correct it; never widen it.
3. **Code** — last.

A cluster of unrelated failures sharing one symptom is session state, not
code. Check the state before reading a single diff.
