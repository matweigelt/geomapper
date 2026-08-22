# geoMap v2 — filter registry

**Every reason a test point may be filtered, and what closes it.**

A filtered point is neither a pass nor a failure. It is a point that **did
not run**, and the only honest way to carry one is to name why. Audit
finding **A-1** measured what happens without this file: with
`GEOMAP_SKIP_SPEED` set, **42 of 491 points did not run and the runner
printed `GREEN GATE: PASS` and returned `ok = 1`** (CI run 32492682068).
Separately, and until this file existed unmeasured: **CI filters 24 and
the bridge filters 5** — nineteen points that run on one machine and not
on the other, with no instrument saying so.

**How this file is enforced.** `GeoMapTestCase.filterBecause` raises a
warning carrying the reason id, then filters. `WarningInventoryPlugin`
already fails the gate on any identifier not on its allow-list;
`rungeoMapTests` extends that list with the ids registered below. **An
unregistered reason is red on arrival.** Nothing was added to the gate —
the alarm that was already there was pointed at one more thing.

**What is deliberately not enforced: a count.** A bound (`nInc <= 5`)
would be an absolute figure with no baseline, which BEST_PRACTICE §3.4.1
threw out for all nineteen speed budgets, and it would permit silent
drift up to itself. The count is **reported** in the reconciliation block
and predicted before the run, like every other count here. The *reasons*
are what is gated.

**Adding a row is a decision, not a formality.** If a reason is worth
filtering for, it is worth a line saying what would make it stop.

---

| id | Why the point cannot run | Expected on | Closes when |
|---|---|---|---|
| `geo:filter:speedTierOff` | `GEOMAP_SKIP_SPEED` is set, so the budget was not measured. Use `rungeoMapTests("default")` to run the correctness tiers alone; `"all"` with the switch set asks for the speed tier and then refuses to run it — and the gate now says so. | neither, in a normal run | never — it is a developer switch, and it is registered so that using it is visible rather than silent |
| `geo:filter:v1TreeAbsent` | The v1 tree is not reachable, so oracle **O12** is unreachable. The resolver searches `GEOMAP_V1_ROOT`, then every sibling of the geoMap root and each sibling's `maptoolbox` subfolder, for `geoProject.m`; the message names how many candidates it tried and where. **It used to hold one absolute path and reported *absent* when the tree had merely moved (PV-148)** — four points filtered for four rounds behind a message that sounded like an explanation. | CI always; **the bridge never**, since 22-Aug | v1 is reachable, **or** the probes are retired with a reason |
| `geo:filter:fullProductAbsent` | A reference number that belongs to a WHOLE published product is asserted, and only the shipped subset is present. Two of the three shipped GSHHG files are prefixes, so a whole-product count checked against one measures the fixture rather than the reader (A-6). | The full product is mirrored into CI, or the assertion is re-derived against the subset. |
| `geo:filter:parallelPoolWouldNotStart` | The Parallel Computing Toolbox is installed and `parpool` refused. A cluster profile can fail at connection time and no probe foresees it. **Deliberately distinct from `noParallelPool`**: one id for both would hide a broken profile behind an expected filter. | Never — it is a host fault, and it must stay separable from an absent toolbox. |
| `geo:filter:oracleDataAbsent` | Real GSHHG and Natural Earth files are third-party and not redistributable, so they are not in this repository. Oracles **O5**, **O6**. | CI always | never on CI. On the bridge it fires only if `E:\DATAPOOL\Borders` has moved, which is a finding. |
| `geo:filter:shippedSampleMissing` | `data/etopo_10min_surface.mat` is absent from the tree. | **neither** | never. This file ships; if it fires anywhere, the package is incomplete. |
| `geo:filter:manualNotBuilt` | `docs/html` has not been built in this tree, so there is nothing for the staleness check to find. | a fresh clone that has not run `build_help` | the doc build runs before the suite in that environment |
| `geo:filter:noParallelPool` | No Parallel Computing Toolbox, or no pool. geoMap needs base MATLAB only and the pool is an option, never a requirement (PV-123). | CI | never — this is the supported configuration, not a gap |
| `geo:filter:noJvm` | No JVM, so the Java `MessageDigest` path is unavailable and the NIST hash vectors cannot be checked. | `-nojvm` sessions | never |
| `geo:filter:mirrorUnavailable` | `mirror/geomap_mirror/out/reference_values.json` is absent or lacks the key. | a tree where the Python mirror has not run | the mirror runs before the suite. **Related to audit finding A-2**: what this reference *is* — a committed artefact rather than the live oracle — is a separate open finding. |
| `geo:filter:machineTooFast` | No array size up to 3.2e7 elements makes one pass reach the timing floor, so `assertRatioBudget`'s 10% accuracy claim cannot be asserted here. A property of the machine, not a defect — and the tolerance was **not** widened to make it pass. | very fast machines | never |

---

*geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)*
