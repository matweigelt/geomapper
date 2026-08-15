# Working agreement

How a change gets from a chat into `main`. Modelled on the shAnalysis
process, which has run this way through many releases.

**The division of authority is the point.** Claude proposes, builds and
proves. Only Matthias advances `main`.

---

## The loop

| # | Who | Step |
|---|---|---|
| 1 | Claude | Builds directly in the working copy and runs **every** gate there to zero findings — including the MATLAB suite, over the very folder the deliverable is built from. |
| 2 | Claude | `git checkout -b claude/<version>-<topic>`, commit, push. |
| 3 | Claude | Opens the pull request. The template fills itself in. |
| 4 | CI | Static gates, then the mirror, then MATLAB. |
| 5 | Claude | Reads the run, diagnoses, fixes, returns to step 1. |
| 6 | **Matthias** | Reviews and merges. **Never Claude.** |

**Updated 15-Aug-2026.** Steps 2 and 3 moved from Matthias to Claude when
`gh` was installed and authenticated, which is exactly the re-read trigger
decision **D-013** wrote for itself. `gh pr create` works through the
credential helper with **no token ever visible to Claude**, which is what
D-013 was protecting; extracting a credential from a keychain remains out
of the question and always will be.

**What did NOT move: the merge.** Claude proposes, builds and proves; only
Matthias advances `main`. That division is the reason the loop is
trustworthy, and it is not a consequence of tooling.

**What else changed.** Under Tier A the MATLAB gate runs in the authoring
session, so a deliverable is no longer PROVISIONAL on arrival — the table
at the foot of this file recorded the opposite and is corrected there.

### Branch naming

`claude/<version>-<topic>` — e.g. `claude/v2000-stage0-harness`,
matching `claude/v3160-fetch-layout` in shAnalysis. Version without dots,
topic in two or three words.

### Before every push

Branch from the remote head **immediately before pushing**, never earlier.
In a prior project three pull requests collided on duplicate version bumps
because each branched from a `main` that was current at session start and
stale at push.

---

## Gates: zero findings before a PR

Run `./tools/gates.sh`. It runs each gate and reports a skipped one
**loudly** rather than as a pass.

| Gate | Runs where | Checks |
|---|---|---|
| structural check | sandbox + CI | block balance, help-block presence, forbidden functions in `+geo` |
| attribution audit | sandbox + CI | provenance stamp on every deliverable; no source cites a refuted value without its correction |
| mirror + frozen acceptance | sandbox + CI | every asserted number, against published values, PROJ and analytic invariants |
| MATLAB suite | Matthias's machine + CI | the green gate |

The first three need no MATLAB and therefore run before the runtime step,
so a defect in them fails in seconds rather than after minutes of
provisioning.

---

## What Claude cannot do here, and what follows

*Table corrected 15-Aug-2026. Three of its four rows had become false.*

| | available | consequence |
|---|---|---|
| Read/write Matthias's files | **yes** — `C:\Users\matth\Documents\MATLAB` | Claude works directly in the working copy; no download, no unpacking |
| Run MATLAB on Matthias's machine | **yes** — MCP bridge to a live R2026a, over that same folder | **Tier A.** The in-session run is ground truth. A deliverable is proved before it is committed, not after |
| Push, open PRs, read CI | **yes** — `gh` 2.97, authenticated by the owner | Claude closes its own loop up to the merge (D-013's re-read trigger) |
| Network from the sandbox | yes, unauthenticated | the mirror runs for real, against a real PROJ and a real GDAL |

**PROVISIONAL is now the exception, not the default.** It marks a file
that shipped without ever being executed, which under Tier A should not
happen; the provenance audit lists every one on every run so the debt
stays visible until a green run clears it. As of 15-Aug-2026 there are
none.

**What Claude still cannot do, and it is deliberate:** merge. See the
loop above.

---

## Relationship to shAnalysis

`shAnalysis` is the upstream of this way of working, and in two places it
is the upstream of the tooling itself.

- **`tools/dev/mlint_lite.py`** is a more capable MATLAB-lint-without-MATLAB
  than this repository's structural checker: it adds the
  `(expression).method` parse error and the package-function-dot runtime
  error. It should be adopted here rather than re-derived. Recorded as a
  finding; not yet done.
- **`tools/dev/attribution_sweep.py`** in shAnalysis *appends* the
  provenance stamp. This repository briefly had a different tool under the
  same name that *checks* provenance. Two different jobs under one name
  across sibling projects is exactly the aliasing that §4.1 forbids, so
  the checker here is now `tools/provenance_audit.py`.

House provenance stamp, as used in shAnalysis:

> Developed by Matthias Weigelt with the help of Claude.

---

## Diagnosing a red CI run

Cheapest repair first: **configuration, then criterion, then code.**

1. **Configuration** — did the workflow run where it thinks it did? The
   MATLAB job asserts its own repo layout before the suite for this
   reason. Replay the exact frozen script, never a recollection of it.
2. **Criterion** — re-derive against an external authority. A criterion is
   *corrected*, never widened until it passes.
3. **Code** — last.

A cluster of unrelated failures sharing one symptom is session state, not
code.

**Distinguish platform lag from a genuine hang before cancelling.** A run
reporting completed while the check shows pending is bookkeeping and
resolves itself; a job step far past nominal is a hang. The MATLAB setup
step is capped at eight minutes because in shAnalysis it hung four times
in one session at 5–10 minutes against a nominal 1.2.

**Poll on the suite's own cadence** — one sleep of roughly the suite
duration, then one status call. The check-run record lags the workflow
record by design.
