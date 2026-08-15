# Working agreement

How a change gets from a chat into `main`. Modelled on the shAnalysis
process, which has run this way through many releases.

**The division of authority is the point.** Claude proposes, builds and
proves. Only Matthias advances `main`.

---

## The loop

| # | Who | Step |
|---|---|---|
| 1 | Claude | Builds in its own sandbox and runs every runnable gate there to **zero findings**. |
| 2 | Claude | Places the files into the working copy on Matthias's machine (Filesystem connector), or hands them over as a bundle if that connector is not available. |
| 3 | **Matthias** | `git checkout -b claude/<version>-<topic>`, commit, push. |
| 4 | **Matthias** | Opens the pull request. The template fills itself in. |
| 5 | CI | Static gates, then the mirror, then MATLAB. |
| 6 | **Matthias** | Pastes the failing output back — verbatim, as a file if long. |
| 7 | Claude | Diagnoses, fixes, returns to step 1. |
| 8 | **Matthias** | Merges. Never Claude. |

Claude has no GitHub credentials and does not handle tokens. That is not a
limitation to work around; the division above is the reason the loop is
trustworthy.

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

| | available | consequence |
|---|---|---|
| Read/write Matthias's files | **yes** — Filesystem connector, `C:\Users\matth\Documents\MATLAB` | Claude places files directly into the working copy; no download, no unpacking |
| Run anything on Matthias's machine | **no** | MATLAB is never executed by Claude. Every MATLAB deliverable ships **PROVISIONAL** until Matthias's run |
| Push, open PRs, poll CI | **no** | Steps 3–6 above are Matthias's |
| Network from the sandbox | yes, unauthenticated | the Python mirror runs for real, against a real PROJ |

**A MATLAB deliverable Claude has written is a hypothesis.** The
attribution audit lists every `PROVISIONAL` file on every run so the debt
stays visible until a green run clears it.

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
