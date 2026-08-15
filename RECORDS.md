# geoMap v2 — RECORDS

**Archived round-by-round evidence for completed work.**

**This file holds evidence. It holds no status.** Status lives in `HANDOVER.md` Part 1 and nowhere else. If you find yourself writing "done", "in progress" or "blocked" here, it belongs in the handover; if you find yourself writing a measurement in the handover, it belongs here.

**Do not read this file as background.** It is for when you need the evidence behind a decision. Reading it up front costs every fresh session its token budget for no benefit — which is the measurement that produced the split (BEST_PRACTICE §6.1: narrative records reached 50% of one source handover, growing ~4600 tokens per package, projecting ~190 000 tokens paid in full by every session).

**Entry template** — copy for each stage at its green gate:

```markdown
## R-00n — Stage <X>, <date>, tier <A|B>

**Confirming run.** Runner invocation, machine tag, wall time, predicted
vs executed point count reconciled three ways, warning inventory.

**Pre-validation findings.** Each with its measurement, and whether it
changed the specification, the code, or nothing.

**Findings from the run.** Each with the log excerpt that showed it.

**Numbers measured this round.** The table later stages cite.

**Superseded scripts.** Frozen verbatim, as the record of their own round.
A superseded verification script is left as the record of its own round;
rewriting a record is not the same as keeping it.

**Binding items a later stage could be wrong for not reading.** Short.
This is the section the next session actually reads.
```

**Shrinking rule (BEST_PRACTICE §6.1).** When a defect recorded here has been encoded as a check whose self-test reproduces it, the narrative paragraph shrinks to one sentence and a pointer at the check. The check's docstring tells the story to a script that enforces it; a paragraph tells it to a reader who may not be looking. Duplication is what goes stale. Existing paragraphs are grandfathered and shrink when next edited.

---

## R-001 — v1 review, 23-Jul-2026, tier B (no execution)

*Moved here from handover revision 1.1 Part I, per Change Log C-012. The eighteen findings are now one table row each in `HANDOVER.md` Part 5, pointing at the check that replaces them. This entry keeps only what a row cannot carry.*

**Verification mode: reading only.** The v1 tree was unpacked, all 37 files (~12 000 lines) were read, and the findings were derived by static reading and grep. **No line of v1 was executed.** Handover debt V4 exists because of this, and Stage 0's `records/v1_defect_probes.m` is what discharges it. Until those probes run, every F-number in Part 5 is a reading, not a measurement.

**Method.** Full read of `geoProject.m`, `geoImagesc.m` (3413 lines), the four coastline readers, the five plumbing functions, the frame/scalebar/northarrow/colorbar elements, `geoResampleGrid.m`, `geoSplitTracks.m`, `geoPercentileRange.m`, `geoNiceGraticuleStep.m`, `test_geoImagesc.m`, `Contents.m`, `README.md`. Grep sweeps for: removed/deprecated MATLAB functions; toolbox-only functions; `eval` family; array growth; `appdata`; shadowed builtins; version guards.

**The one finding with a measurement attached.** `range()` (F1) was located at 15 call sites across 5 files by grep, and `range` is a Statistics and Machine Learning Toolbox function. This makes v1's shipped claim "no toolboxes required (Mapping Toolbox, Image Processing Toolbox, etc. are **not** needed)" false on a stats-free installation. This is the finding most likely to survive its probe, and the one that most directly justified a v2 rather than a v1.3.

**The three findings weakest without execution**, flagged for the probes to settle first:

- **F4** (regrid seam) — inferred from reading `griddedInterpolant`'s construction without the wrapped padding column. The extrapolation *mode* is set to `'nearest'`, so the failure is silent rather than NaN, which is what makes it worth a probe: a silent wrong value is F1's plausible wrong answer.
- **F9** (renderer dependence) — inferred from `light` + `shading interp` + `FaceAlpha` co-occurring on one surface. The bad interaction is documented in earlier sessions of this project rather than measured here.
- **F12** (magic thresholds) — the literals are certainly present (`cosc < -0.9`, `cosc < 0.1`, `cosc < -0.9994`, `sind(89.5)`); what is *inferred* is that they serve simultaneously as mathematical guard and cosmetic clip, which is a reading of intent.

**What the review did not do, and should have.** It named no oracle. Sixteen projections were assessed by reading their formulae against remembered Snyder forms — precisely the F2 failure mode (a value recalled rather than read). Handover debt V2 records this; oracle O4 (`pyproj`) is the repair, and it should have been named before the first formula was assessed rather than three weeks later.

**Binding items a later stage could be wrong for not reading:**

1. v1's shapefile reader traverses records **by declared content length**, not by parsing each shape type. This is why it survives Z/M payloads. Port it; do not "simplify" it.
2. v1 deliberately omits an `isfile` pre-check before `fopen`, with a comment saying why: `fopen` searches the MATLAB path and `isfile` does not, so a pre-check rejects files reachable only via the path. Keep both the behaviour and the comment.
3. v1's GSHHG reader carries an honest CONFIDENCE NOTE stating it has never been verified against a real GSHHG file. That note is four years old and still true. It ships unchanged until oracle O6 exists.
4. `set(ax,'Position',…)` is blocked under `tiledlayout`; `PlotBoxAspectRatio` is the equal-height mechanism that works. This was established by execution in an earlier session of this project and is the one v1 behaviour here that *does* carry a measurement.
5. v1's mask warnings (`MaskThresholdOutOfRange`, `MaskCoversEverythingOrNothing`) are genuinely useful and diagnose a real user error — pixel values that are not elevation. Port them; they become the reason Stage D needs `suppressWarning` under the §2.5 gate.

---

## R-002 — Stage 0, checkpoint 0.1 (mirror), 13-Aug-2026, tier B

**Scope.** Pre-validation only. No MATLAB was written; per BEST_PRACTICE
§3.1 the specification is run against the mathematics first, and this
checkpoint is that run. Delivered: `mirror/geomap_mirror/{kernels,oracle,
references}.py`, `LIMITS.md`, `README.md`, `out/reference_values.json`.

**Confirming run.** `python -m geomap_mirror.references`, pyproj 3.7.2 /
PROJ 9.5.1, numpy 2.4.4, scipy 1.17.1. 37 values recorded, 4 handover
claims refuted. Round trips: 10 000 quasi-random in-domain points per
projection, seed 42.

**Findings.** Eleven, of which four refute a handover number and four are
defects in the instrument itself — recorded because an instrument's own
defects are the ones that make its numbers untrustworthy (§F3).

| id | Finding | Evidence | Disposition |
|---|---|---|---|
| PV-001 | Handover §2.2 said the mirror should be "thin wrappers over pyproj". That collapses two jobs: mirroring the MATLAB algorithm, and being an independent oracle. Wrapped, a MATLAB disagreement cannot distinguish an implementation defect from an algorithm difference, and the round-trip suite checks PROJ against itself. | Design | Rejected. Two modules. **D-010** |
| PV-002 | **Polar stereographic ρ(70°)/R at SP=71 is not 0.6116372.** Mirror and PROJ both give **0.3430474163** = (1+sin 71°)·tan(10°), agreeing to 1e-10. A search over spherical and ellipsoidal evaluations at every integer latitude found no natural quantity equal to the quoted figure; the nearest, 0.6114614, is the spherical ρ at lat 56° with ts=90°, a coincidence. | `check_polar_stereographic` | Handover corrected. **C-017** |
| PV-003 | **PROJ defaults `+lat_1` to 0 for `+proj=wintri` when it is absent**, silently making it a different projection. Symptom: a clean `0.18169·λ` offset in x at every point, with y matching to 0.00e+00 — which looks exactly like a kernel bug. | Forward comparison at 6 points | Oracle fixed; **D-011**, limit L6 |
| PV-004 | **The handover's prescribed Robinson inversion cannot meet the handover's prescribed tolerance.** PCHIP on the swapped table gives 0.30° round-trip error against a budgeted 5e-4°, because near the pole `dY/dlat ≈ 0.0048/deg`. Root-finding on the *forward* PCHIP gives **1.4e-13**. | `check_round_trips` | Method and tolerance changed. **C-020** |
| PV-005 | **The Robinson node claim is wrong twice over.** 0.9427 is the X-table entry at lat **35**, and 0.5722 is the X-table entry at lat **85**; neither is a Y value and neither is at lat 50. Correct at lat 50: X = 0.8679, Y = 0.6176, y = 0.8351805 R. | `check_robinson` | Handover corrected. **C-018** |
| PV-006 | Equal-area integral fixture double-counted the seam column: `wrap_longitude` maps +180 to −180, so the final quad spanned the whole map. Measured 99.4% error before the fix, 2.5e-5 … 9.8e-5 after. **A fixture defect, found only because the number was absurd rather than merely wrong.** | `check_equal_area` | Fixture fixed |
| PV-007 | The global quad-integral test is invalid for Lambert azimuthal and Albers: the antipodal rim and conic apex are singular, so it measures discretisation. `AreaScale` passes for all five at ≤ 2.4e-8 and is the right instrument. | ditto | Test scope narrowed. **C-021** |
| PV-008 | `geo.scaleFactors` returns NaN when evaluated exactly on a domain boundary, because the central difference steps outside. Seen at Mercator lat = ±85. | `check_scale_variation` | Limit L7; binds `geo.scalebar` |
| PV-009 | **The scalebar validity gate must read linear scale (h, k), not area scale.** An equal-area projection has area scale 1 everywhere by construction, so an area-based gate passes global Mollweide — the exact case the gate exists to catch. | ditto | **C-022** |
| PV-010 | The Winkel Tripel inverse must verify convergence by re-evaluating the forward, not trust the loop. Without that check the mirror returned errors up to **174°** near the antimeridian while looking like a successful inverse. ~0.8% of a uniform in-domain sample. | `check_round_trips` | Fixed; handover prescription strengthened |
| PV-011 | **The LCC cone constant 0.6304962 is the ellipsoidal Clarke-1866 value**, matching to 2.6e-7. The spherical value geoMap needs is **0.6304776973**. The *point* values from the same example (0.2966785, 0.2462112) are spherical and confirmed exactly — so the handover took two numbers from one worked example and one of them from the wrong model. | `check_cone_constant` | Handover annotated. **C-019** |

**Numbers measured this round** (full set in `out/reference_values.json`):

- Round trips, max degree error: 13 of 16 at ≤ 4e-12; Robinson 1.4e-13,
  Winkel Tripel 4.6e-13, **Lambert azimuthal 4.6e-9** — above the
  handover's blanket 1e-9, inherent to `asin` conditioning at the
  antipodal rim.
- Mirror vs PROJ, max absolute difference in projected units: 15 of 16 at
  ≤ 6e-13; **Robinson 8.9e-4**, because PROJ uses a different interpolant
  for the Robinson table (limit L5).
- Analytic invariants: Mercator k = sec φ to 5.1e-9; equal-area
  `AreaScale` = 1 to ≤ 2.4e-8; conformal h = k to ≤ 9.4e-8; LCC k = 1 on
  both standard parallels to 2.5e-9. **All within the handover's 1e-6
  tolerances with roughly a decade of headroom.**
- Great circle Paris→New York: spherical 5837.2 km (handover's 5837 ± 15
  confirmed), WGS84 geodesic 5852.9 km, difference **−0.268%** — inside
  D-001's ≤0.3% claim, now measured rather than asserted.
- Scale variation (max h,k / min h,k) across extents, 14 projections ×
  4 extents: the table that sets the D-006 threshold.

**Binding items a later stage could be wrong for not reading:**

1. **The mirror is two modules, not one.** Import kernels from
   `kernels.py`; use `oracle.py` only as an authority. Do not merge them.
2. **Write every PROJ parameter explicitly.** A PROJ default is not a
   documented contract (PV-003).
3. **Never build a PROJ transformer from EPSG:4326** for this project: it
   inserts an ellipsoid→sphere datum shift and the comparison then measures
   that shift, not the projection.
4. **Robinson inverts by root-finding on the forward interpolant.** Any
   swapped-table shortcut reintroduces a 0.30° error.
5. **Any Newton inverse verifies its own convergence** by re-evaluating the
   forward and NaN-ing the residual failures. The Winkel Tripel case
   returned 174° errors that looked like successes.
6. **Lambert azimuthal needs a 1e-8 round-trip tolerance, not 1e-9.**
7. Read `mirror/LIMITS.md` before trusting any mirror number.

**Superseded scripts.** None yet; this is the first round.

---

## R-003 — Stage 0, checkpoint 0.2 (MATLAB harness), 13-Aug-2026, tier B

**Scope.** The instruments. Delivered: `tests/GeoMapTestCase.m`,
`geoMapTestRecord.m`, `geoMapMachineTag.m`, `geoMapRoot.m`,
`rungeoMapTests.m`, `WarningInventoryPlugin.m`,
`TestStage0_instruments.m`, `EXEMPTIONS.md`, `tests/README.md`,
`tools/{makeManifest,verifyManifest,sha256OfText}.m`, `tools/mcheck.py`.

**Verification mode: STATIC ONLY. This checkpoint is PROVISIONAL.** No
MATLAB interpreter was available. Every file carries a PROVISIONAL stamp
in its footer, and none may be cited as working until the first green run.
This is a debt entry, not a status.

What *was* verified: `tools/mcheck.py` checked block balance, help-block
presence and the forbidden-function ban across all 10 MATLAB files — 0
problems. The checker was fault-injected two ways: against synthetic
fixtures (unclosed block, extra `end`, missing help, a planted `range()`
call, and a healthy control to catch false positives), and against **the
real files**, by deleting one `end` from each of the four largest and
confirming detection in every case. A checker proved only on synthetic
fixtures can be blind on real ones.

**Findings.**

| id | Finding | Disposition |
|---|---|---|
| PV-012 | **The source guidance conflicts with itself on repeat count.** "Use 15 repeats" (spread 5→31.2%, 9→14.0%, 15→10.2%, 21→4.4%) and "prefer a repeat count that is a multiple of the number of points" cannot both hold for a two-point budget: 15 is odd, so one point is timed first eight times and the other seven, leaving exactly the always-identically-signed bias rotation exists to remove. Resolved in favour of balanced rotation at **16**, the smallest multiple of 2 not below 15. | Implemented and documented at the argument default |
| PV-013 | **The warning inventory under-reports.** MATLAB offers no global warning hook, so the plugin resets and reads `lastwarn` around each test method and captures only the **last** identifier raised per method. A method raising two distinct identifiers reports one. | Recorded in the plugin's LIMITATIONS block. Adequate for the gate it serves — which asserts the inventory is *empty* apart from one probe, so any leak shows regardless of ordering — and **inadequate for counting**. No count from it may be quoted |
| PV-014 | Two instruments were not separately testable as first written: the ratio *statistic* was fused to the *measurement*, and `verifyManifest` was a local function inside the runner. Neither could be fault-injected. | Refactored: `GeoMapTestCase.ratioStatistic` is a static method provable on synthetic timings with no timer involved; `verifyManifest` extracted to `tools/` |
| PV-015 | Three uses of undocumented or fragile MATLAB API in the first draft: `feature('timing','cpucount')` for a scratch directory name, `meta.class.fromName` passed a string rather than char, and a `suppressWarning` test that asserted nothing observable. | Replaced with `tempname`, `char(cls)`, and a proper positive/negative pair (`suppressWarningTurnsTheIdentifierOff` / `restoreIsObservable`) |

**Design notes a later stage could be wrong for not reading:**

1. **`assertRatioBudget` is the only timing instrument.** Do not write a
   local median helper. Eleven near-copies in a reference project meant
   thirteen places for the next repair to be applied twelve times.
2. **`ratioStatistic` is deliberately not `median(tA)/median(tB)`.** The
   self-test `driftIsCaughtByPairedStatistic` constructs a sequence whose
   true ratio is exactly 2 while the machine slows 3× across the run, and
   asserts the paired statistic reads 2 while the unpaired shape is
   visibly wrong. If a refactor makes that test pass trivially, the
   instrument has been broken.
3. **`TolMass` is a method that errors**, not a constant that guesses.
   Debt V7 is open; the mirror has not yet measured the achievable
   double-precision mass-closure floor at production grid size.
4. **CRS fixtures are lazy.** Stage 0 suites must not request one; the
   harness must be usable before `geo.crs` exists.
5. **The category-coverage report requires each test class to declare a
   `CoveredFunctions` constant.** A class without one is skipped with a
   note rather than silently passing.
6. `%#ok<AGROW>` appears in `geoMapTestRecord` and `makeManifest`. This is
   deliberate and confined to tooling: both are cell accumulators, which
   are O(1) amortised. The audit's AGROW ban applies to numeric
   concatenation inside `+geo`, and Stage 0.3 must scope it that way.

**Open for checkpoint 0.3.** The static audit `tools/geoMapAudit.m` with
its per-check fixtures, `records/v1_defect_probes.m`, the v1 option
inventory, and `buildfile.m`.

**What Matthias must run first.**

    >> cd <toolbox root>
    >> addpath(pwd, fullfile(pwd,'tests'), fullfile(pwd,'tools'))
    >> makeManifest
    >> ok = rungeoMapTests("all")

Expected on a first run: this is untested code, so expect failures rather
than a green gate. **Predicted point count for this round: 19** (13
correctness + 3 speed + 3 manifest robustness). Reconcile that against the
three sums the runner prints; a miss is the cheapest available signal that
something did not load.

---

## R-004 — Stage 0, checkpoint 0.2 EXECUTED, 14/15-Aug-2026, tier A

**The round that made checkpoint 0.2 real.** R-003 shipped eleven files
that had never run. This entry records what happened when they did.

**Confirming run.** `rungeoMapTests("all")` on `win64 | R2026a Update 4 |
16 threads`, Windows 11. **20 points: 18 passed, 0 failed, 2 filtered.**
Green gate on all five conditions — zero failures, manifest verified (11
files), warning inventory empty, speed budgets met, category coverage
clean with no gaps outside `EXEMPTIONS.md`. Total 1.80 s.

The two filtered tests await the Python mirror's `reference_values.json`,
which has not been transferred. They filter **loudly**, naming the reason.

**Measured ratios** (the first real numbers this project owns):

| budget | ratio | band | verdict |
|---|---|---|---|
| sum of 4N squares / N squares, N=4e6 | **4.273** ≤ 6 | 3.70 .. 4.36 | recovers a constructed 4.0 to 6.8% |
| identical tiny workloads | 0.9831 ≤ 3 | 0.930 .. 5.68 | inner batch engaged as designed |
| speedup direction | 3.979 ≥ 2 | 3.67 .. 4.32 | `">="` direction works |

**Findings — six, every one from running code that static analysis had
already passed clean.**

| id | Finding | Why no static check could see it |
|---|---|---|
| PV-016 | **The speed fixture was measuring call overhead.** A constructed 4× workload read **1.434** at N=2e5. Solving `f + v` and `f + 4v` gives fixed cost 0.52 ms — **85% of the small point**. The two arrays were also 1.6 MB and 6.4 MB, straddling L3, so they were not even in one memory regime. Ladder: 2e5→1.434, 1e6→3.491, **4e6→4.111**, 1.6e7→3.942. | Requires timing on real hardware |
| PV-017 | **`sha256OfText` threw `NullPointerException` on empty input.** `uint8('')` is 1×0 and reaches Java as `null`. | Requires executing the Java path |
| PV-018 | **`TolMass` reported `MirrorMissing` where it meant "not measured"**, leaking an implementation detail and making its contract untestable whenever the mirror was absent. | Requires the absent-mirror state |
| PV-019 | **Predicted 19 test points; actual 20.** A miscount of the contract tests. | The prediction *is* the instrument |
| PV-020 | **Tests reset the record store**, erasing what earlier tests recorded. Report read "0 ratio records" while three speed tests passed. | Requires a multi-test run |
| PV-021 | **`recordStoreRoundTrips` is the test that proves `reset` works, so it must reset — and destroyed the run's measurements doing so.** Now saves and restores via `onCleanup`. | Requires a multi-test run |

Plus three stale `%#ok<AGROW>` pragmas caught by **MATLAB's Code
Analyzer**, which `tools/mcheck.py` cannot see.

**The lesson worth carrying forward.** PV-020 and PV-021 both **passed the
green gate**. Zero failures, manifest verified, inventory empty, budgets
met, coverage clean — and the report was silently discarding the numbers
it existed to preserve. *Read the log, not the pass count* stopped being
advice and became a measurement.

**Transfer findings.**

- **Bulk archive transfer is unsafe on this channel.** A 60 kB base64
  chunk arrived as **55,317 bytes with a PNG terminator appended** —
  content never in the payload. Caught by checking the byte count before
  proceeding; untarred it would have produced a corrupt tree. Decision
  D-012: one file at a time, verified by byte count **and byte-sum**.
- The channel **drops one trailing newline**. Immaterial to MATLAB
  parsing, but the verification must expect it.

**Git state.** Branch `claude/v2000-stage0-harness` pushed to origin at
`0d4d254`. `main` untouched at `6400a9b`. PR not opened: `gh` is absent
and a credential-manager token is not Claude's to extract (D-013).

**Binding items a later stage could be wrong for not reading:**

1. **`PROVISIONAL` stamps in all eleven shipped files are now false.**
   Remove them in the next commit; the provenance audit lists them on
   every run precisely so the debt stays visible.
2. **Never call `geoMapTestRecord('reset')` in a test.** The runner resets
   once. Assert on the delta.
3. **`clear classes` clears variables too.** It bit three probes this
   session. Re-establish paths and locals after it.
4. **Measure the fixture before writing a growth budget.** Solve for the
   fixed term and check the memory regime, every time.
5. The commit on the branch does **not** include the mirror, the CI
   workflow, or the documents. CI will not fire until
   `.github/workflows/ci.yml` is pushed.

---

*Entries R-005 onward are written at each stage's green gate.*
