<!--
This template is a checklist, not a formality. Every line exists because
its absence cost something in a prior project. Delete nothing; answer
"n/a" with a reason where a section does not apply.
-->

## What this changes

<!-- One paragraph. What is now true that was not true before. -->

## Stage and checkpoint

<!-- e.g. Stage B, checkpoint B.1. Link the HANDOVER.md section. -->

## Verification tier

- [ ] **Tier A** — a live MATLAB session ran over the very folder this branch builds from
- [ ] **Tier B** — no interpreter in the authoring session; numbers pre-validated in the mirror, and the reviewer's run is the gate

## Gates

Run `./tools/gates.sh` locally **before** pushing. CI confirms; it does not
discover.

- [ ] structural check — 0 problems
- [ ] attribution sweep — 0 problems
- [ ] mirror + frozen acceptance — 0 breaches
- [ ] MATLAB suite — green gate (or: **skipped**, and said so here)

Green means: zero failures **and** every suite loaded **and** no new
warning identifier **and** no speed budget exceeded **and** the manifest
verified **and** category coverage clean. Not "the number went up".

## Test-point count

| | count |
|---|---|
| predicted before the run | |
| executed | |
| reconciled three ways? | |

<!-- A prediction that misses is the cheapest available signal that the
change was not the change you thought you made. Do NOT write the number
into HANDOVER.md; it is a per-round instrument. -->

## Test categories shipped

- [ ] contract  - [ ] reference  - [ ] precision  - [ ] speed
- [ ] robustness  - [ ] vectorisation  - [ ] metamorphic

Categories not shipped, with the reason each is **impossible** rather than
inconvenient (and added to `tests/EXEMPTIONS.md`):

## Oracle

<!-- What was this checked against that was NOT built here? Name the
register id from HANDOVER.md Part 3. If you cannot name one, the work is
not ready to merge. -->

## Pre-validation findings

<!-- Findings from validating the SPECIFICATION before implementing it,
each with its measurement. A branch that reports none has probably not
looked. State "none, and here is what I checked" rather than silence. -->

## Numbers introduced or changed

<!-- Every asserted number, with where it was measured and against what.
No number may come from a document; it comes from a measurement. -->

## Debt this branch creates or discharges

<!-- Reference the V-rows in HANDOVER.md Part 0. A PROVISIONAL deliverable
- shipped but never executed - is debt and must be listed here. -->

## Documents updated in this same change

- [ ] help text on every changed function (ACCURACY block, errors grouped by cause)
- [ ] `HANDOVER.md` ledger row
- [ ] `HANDOVER.md` decision log / debt table, if either moved
- [ ] `RECORDS.md` entry, if a stage reached its gate
- [ ] `CHANGELOG.md`

## Anything a reviewer could be wrong for not reading

<!-- Short. This is the section that actually gets read. -->
