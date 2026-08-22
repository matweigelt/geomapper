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

**PV-132 — the mass-closure floor is environment-dependent, and the
checked-in reference file was nearly overwritten without a machine tag.**
Re-running the mirror here rewrote
`mirror/geomap_mirror/out/reference_values.json`. Two things moved:

| | recorded baseline | this sandbox |
|---|---|---|
| GDAL | 3.10.3 | **3.12.4** |
| regrid mass-closure floor, pairwise | 2.150e-14 | **3.936e-14** |
| two sphere-area totals | — | last 1–2 ULP |

`TolMass` = 1e-13 survives either way, with 2.5× headroom here against
4.7× on the baseline. **The floor is not a constant of the algorithm; it
is a constant of the algorithm *and* the summation blocking of the numpy
build underneath it.** V7 is still discharged — the tolerance was set one
decade above a measured floor and both measurements sit under it — but
the margin is smaller than the baseline number suggests, and a future
environment that widens it further would be a finding rather than a
surprise.

**The regenerated file was reverted, not committed.** It is the record of
a specific run on a specific machine; replacing its contents from an
unrecorded environment would substitute one measurement for another with
nothing saying so, which is debt V1's failure mode with extra steps. CI
uploads its own copy as an artefact rather than committing one, and that
is the right shape.

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

## R-005 — Stage 0, checkpoint 0.3, 15-Aug-2026, tier A

**Scope.** The instruments Stage 0 still owed: the static audit with a
fault-injection fixture per check, the mirror modules that fill oracle
rows O7 and O8, and the two v1 measurement scripts that discharge V4 and
V9. Delivered: `tools/{geoMapAudit,geoMapAuditFixtures}.m`,
`tests/TestStage03_audit.m`, `records/{v1_defect_probes,
v1_option_inventory}.m` and their two reports,
`mirror/geomap_mirror/{gdal_oracle,regrid,hillshade}.py`, `Contents.m`,
`.gitattributes`.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`.
**Predicted 36 points before the run; suite size 36, per-class sum 36,
36 passed + 0 failed + 0 incomplete.** Green gate on all six conditions —
zero failures, manifest verified (42 files), warning inventory empty,
speed budgets met, category coverage clean, **static audit 0 findings**.
Total 5.30 s. Python gates: `mcheck` 17 files 0 problems, `provenance_audit`
0 problems, mirror **65 frozen criteria, 0 breaches**.

The two tests filtered in R-004 for want of the mirror JSON now run.

**Numbers measured this round.**

| quantity | measured | consequence |
|---|---|---|
| Conservative-regrid mass closure, 2161×4321 → 181×361, worst of three summation orders | **2.150e-14** | **V7 discharged.** `TolMass` = **1e-13**, one decade above the floor — *tighter* than the handover's 1e-12 guess, not looser |
| … by order: pairwise / naive / `fsum` | 2.15e-14 / 1.65e-14 / 6.48e-15 | the tolerance is set from the worst realistic order, never the best |
| Conservative remap vs the analytic affine-field mean | 7.105e-15 | the weights are certified against closed-form integration, not against a second copy of themselves |
| The same remap with latitude weighted in **degrees** | 4.098e-3 | the analytic check is *shown to discriminate*, by twelve orders of magnitude |
| Horn hillshade vs `gdaldem hillshade` (uint8), interior | **0 DN over 18 094 px** | exact reproduction of GDAL's byte output |
| … vs `gdaldem slope` / `aspect` (Float32) | 4.196e-5° / 8.188e-4° | the gradient itself, certified where the instrument has resolution |
| Flat-terrain shade vs `Ambient + (1−Ambient)·sin(elev)` | 1.11e-16 | analytically exact |
| Metric ratio, same E–W ramp at lat 60 vs lat 0 | 1.9999878 (6.1e-6 rel.) | the test that catches a missing `cos(lat)`; no oracle supplies it |
| `gdalwarp -r average` vs conservative, ±10° band | RMS 5.5e-4 on a field of RMS 0.98 | corroboration only |
| … globally | **RMS 0.207 on a field of RMS 1.00** | **21% of the signal.** O7 as the register names it is not an authority |
| v1 defect probes | **17 reproduced, 0 refuted, 1 blocked** | **V4 discharged.** F17 blocked on O6 |
| v1 option inventory | **177 options: 159 carried, 15 renamed, 3 dropped, 0 unmapped** | **V9 discharged** |

**Findings — thirteen. Ten came from running code that had already passed
every static check in the project.**

| id | Finding | Why nothing else could see it |
|---|---|---|
| PV-022 | **The v1 tree was not installed anywhere on the machine**, breaching OB-7 and leaving O12 unreachable. Supplied mid-session as `maptoolbox.zip`; now at `Documents/MATLAB/maptoolbox_v1`. | Requires looking, which no gate did |
| PV-023 | **O7 and O8 are fillable after all.** The sandbox has no root, so `apt-get install gdal-bin cdo` fails and PyPI's `gdal` sdist cannot build — but the `rasterio` wheel bundles **libgdal 3.10.3**, and `GDALDEMProcessing` and `GDALWarp` are the exact C entry points `gdaldem` and `gdalwarp` call. Both register rows now filled for real. | Requires trying the third option after two failed |
| PV-024 | **MATLAB's `regexp` does not implement `\b` as a word boundary** — it is the backspace escape. `'^\s*function\b'` matches *nothing*, silently. Every help block was reported absent, including on the healthy control. Use `(?![\w])`. | The pattern is valid; only its meaning is wrong |
| PV-025 | **`for id = setdiff(a,b)` runs once when the result is an empty COLUMN vector**, because a for-loop iterates over columns and a 0×1 array has one. Two findings were raised against a file with no identifiers at all. | Requires the empty case, on the healthy control |
| PV-026 | **The one-line form `if cond, continue, end` broke the block-depth counter.** The first parser read only each line's leading keyword, so the trailing `end` was never counted, depth drifted upward, and `GeoMapTestCase.seedRandom` — four lines long — was reported at **404**, over the 400-line rule. A length rule fed by a counter that never returns is not strict, it is random. | Requires executing the parser on real source |
| PV-027 | **The comment stripper handled single-quoted strings only.** `geoMapAuditFixtures.m` writes MATLAB source as *double-quoted string data*, so its literals contain `"function"`, `"if"` and `"end"`; the depth counter read them as code and reported a 25-line function at 407. | Requires a file that contains code about code |
| PV-028 | **GDAL's `aspect` is the direction of steepest DESCENT.** The expectation first written here was `atan2(3,4)` = 36.87°; the self-test returned an error of exactly **180.0000059°** — a residual that names its own cause. An oracle convention recalled rather than checked is F1's plausible wrong answer. | The self-test on an analytically known plane |
| PV-029 | **`tools/gates.sh` cannot run from a Windows working copy.** Git for Windows defaults `core.autocrlf` to true, so the LF-committed script is checked out with CRLF and bash fails on `set: pipefail: invalid option name` — naming neither the file nor the cause. **The local gate WORKFLOW.md tells every contributor to run before pushing had never been runnable locally.** It ran in CI, so the failure was invisible from the side that matters least. Fixed by `.gitattributes`. | Requires running it on Windows, which CI never does |
| PV-030 | **Two of eighteen v1 probes initially REFUTED their own claim, and both probes were wrong.** F4 queried lon −0.5, the obvious seam, which v1's rewrap puts comfortably *inside* the interpolation hull; the hull's real upper edge is 179, and a query at 179.5 returns the value *at* 179 — nearest extrapolation, silently. F16 tested span 120, where nearest-snap and the ceiling policy happen to agree exactly; over a ladder of 13 spans they differ at 4, worst 10 lines against a target of 6. **The probe point is part of the probe** — the same lesson as C-026, in a new place. Diagnosis order (configuration → criterion → code) is what caught both. | Requires distrusting a refutation as much as a confirmation |
| PV-031 | **`[f.check]` on an empty struct array is a 0×0 double, not a string array**, so `strjoin` errors. Both of this suite's diagnostic messages therefore errored **on a clean tree**, while the assertions they carried were true. A diagnostic that can only fail when everything is fine is worse than no diagnostic. | Requires the passing case |
| PV-032 | **`gdalwarp -r average` is not a conservative remap.** It is an unweighted mean of source pixels whose centres fall in the target pixel — no spherical area weighting, no partial cells. Measured 21% of signal RMS globally. O7's row is **annotated, not ticked**, and the weights are certified analytically instead. Limit L11. | Requires measuring the oracle rather than adopting it |
| PV-033 | `references.py::scale_factors` carries a dead assignment (`area = cross / coslat * coslat` immediately overwritten by `area = cross`). Harmless — the surviving line is correct — but recorded rather than silently tidied, since §6.6 forbids mixing an unrelated repair into this round. | Reading, not running |
| PV-034 | **Operator error: `git rm --cached -r . && git reset --hard`, run to renormalise line endings, destroyed every uncommitted edit to tracked files.** Eleven files' changes were lost and had to be redone from the session record; the ~3 600 lines of *new* files survived only because `reset --hard` does not touch untracked ones. **Rule earned: commit before any command that rewrites the index.** The safety commit that should have come first came second. | Nothing in the project could have caught this; it is recorded because a process defect that goes unrecorded recurs |

**Confirming run, CI.** Four rounds were needed and all four failures are
recorded below rather than squashed away. Final state, both twin triggers
green on `94b53bd`:

| job | result |
|---|---|
| static gates | `mcheck` 17 files 0 problems; `provenance_audit` 0 problems |
| mirror + frozen acceptance | 65 criteria, 0 breaches, on **GDAL 3.8.4 via the CLI** |
| MATLAB suite | `glnxa64 \| R2026a \| 1 threads`: 34 passed, 0 failed, **2 filtered loudly** (the v1 tests, where the tree is deliberately absent). Green gate on all six conditions |

**The cross-route certification worked, and is the strongest single result
here.** The sandbox reaches GDAL **3.10.3 through `ctypes`** on a wheel's
bundled libgdal; CI reaches GDAL **3.8.4 through the command line**.
Different version, different call path, and both reproduce the analytic
plane's slope to **3.57997724620418e-06** and aspect to
**5.918609105037831e-06** — the same digits. An oracle agreeing with
itself across two implementations of itself is evidence; one route alone
would have been an assumption (limit L12).

**Findings from CI — three more, none visible from the desk.**

| id | Finding | Why the local run could not see it |
|---|---|---|
| PV-035 | **The growth fixture compared two different arrays**, 4N elements against N, which is two memory regimes as soon as one leaves cache — the first thing §3.4.3 says to check. On a 1-core runner the constructed 4.0 read **5.536** (band 4.70..6.03) and, on a re-run of the *identical commit*, **4.885**, against 3.84 (band 3.67..4.15) on the 16-thread box. **The twin CI triggers disagreed on the same commit**, which is precisely the comparison they exist to make. Repaired by changing the fixture's shape to one array, four passes against one — true ratio exactly 4 by construction, one memory regime by construction. Measured after: 3.929 / 3.955 / 3.955 locally, **4.07 (band 3.49..4.36)** on the runner. **The tolerance never moved.** | A 16-thread machine keeps both arrays fast enough that the regime split does not show |
| PV-036 | **Calibrating around the fixed term does not work: `f` is a difference of two nearly equal times, so its relative size is badly conditioned.** It read **+0.98%** locally and **−70.3%** on the runner. Worse, the first calibration *selected* the −70.3% rung, because it minimised the **signed** fraction and negative is smaller than small — while a large negative `f` is not a small fixed cost but the regime violation itself. Modelling the confound failed; removing it worked. | Requires a machine where the regime actually splits |
| PV-037 | **`tools/mcheck.py` reported "unmatched `end`" 228 lines away from the cause, in a function that is correct.** Its comment stripper chose transpose-or-string by the last **non-space** character, so `err.identifier '].  Run the Python mirror first.']);` read as a transpose after `identifier`; the `]` inside the string literal was counted as a real bracket; the file's bracket depth ran at −1 from that line onward; and with depth negative the guard that ignores `end` inside brackets stopped firing, so every `x(end+1)` after it was counted as a block terminator. Repaired by testing the **immediately preceding** character — a transpose never has a space before it, which is how MATLAB itself disambiguates. Two fixtures added, and **the pre-fix parser was shown to fire on the new one**: a fixture that passes before and after a change proves nothing. | Latent since Stage 0.2; exposed only when a later function used `x(end+1)` past line 251 |

**Instrument integrity.** `geoMapAudit` refuses to report a clean tree
unless its self-test has passed in the same invocation: **13 fixtures, one
planted defect per check plus a healthy control on which nothing may
fire.** Four of the findings above (PV-024, PV-025, PV-026, PV-027) were
caught *by that control* rather than by the defect fixtures — the half of
the discipline that is usually skipped is the half that paid.

**Binding items a later stage could be wrong for not reading:**

1. **`\b` is not a word boundary in MATLAB `regexp`.** Use `(?![\w])` or
   `(?<![\w.])`. It fails silently and looks like a data problem.
2. **Never `for x = setdiff(...)`.** Index with `1:numel(...)`.
3. **`TolMass` reads `.tolerance` from the mirror JSON, not `.measured`.**
   They are deliberately different numbers: 1e-13 asserted, 2.15e-14
   measured.
4. **O7 is annotated, not filled.** `gdalwarp -r average` corroborates in
   a near-constant-area band and is wrong globally. Stage B's conservative
   regrid is certified against the **analytic** affine-field oracle, and
   that check must keep its degree-weighted counterfactual, which is what
   proves it discriminates.
5. **O8 certifies the Horn kernel on a constant-spacing tile only.** The
   spherical `cos(lat)` metric has no oracle and is checked analytically
   by the lat-0 vs lat-60 slope ratio. Do not delete that test as
   redundant; nothing else covers the metric.
6. **The v1 tree lives at `Documents/MATLAB/maptoolbox_v1/maptoolbox`**
   and must stay there until Stage F (OB-7). It is deliberately outside
   the repository.
7. **Stage E reads `records/v1_option_inventory.md`, not its
   recollection.** 177 options, 0 unmapped.
8. **Handover Part 5's F16 wording is wrong and should be corrected**:
   the illustration "3 or 11 lines for a 6 target" does not reproduce; the
   measured worst is **10 lines at span 45°**. The defect is real, the
   illustration is not.
9. `Contents.m` now exists and is the **version authority**
   (`2.0.0-alpha.0`). `README`, `CHANGELOG`, `CITATION.cff`, `geoMap.prj`
   and `info.xml` are checked against it and never independently
   maintained.
10. **A constructed speed fixture must compare two sides doing the same
    work on the SAME array.** Different array sizes are different memory
    regimes, and the difference shows on a small machine and hides on a
    large one. Stage A's four speed budgets should be read against this
    before they are written.
11. **The baseline machine is `win64 | R2026a | 16 threads`; CI is
    `glnxa64 | R2026a | 1 threads`.** They are different instruments. A
    budget that must hold on both has to be constructed so that it is
    machine-independent, not tuned until both happen to pass.
12. **Do not run a command that rewrites the git index without committing
    first.** See PV-034.

---

## R-006 — Stage A, 15-Aug-2026, tier A

**Scope.** L0 data model and longitude topology, in three checkpoints, each
with its own confirming run. Delivered `+geo/{crs,wrapLongitude,
splitAntimeridian,grid,track,points,region,greatCircle,splitTracks}.m` and
`+geo/+internal/{projectionNames,mustBeCrs,mustBeIdentity,mustBeSeries,
countGaps}.m`, with `TestA1_crs`, `TestA2_structs`, `TestA3_region`.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`.
**Predicted 113 before the run; suite size 113, per-class sum 113, 113
passed, 0 failed, 0 incomplete.** Green gate on all six conditions.
Mirror 74 frozen criteria, 0 breaches; `mcheck` and `provenance_audit`
clean. Checkpoint counts along the way: A.1 → 63, A.2 → 88, A.3 → 113,
each predicted correctly before its run.

**Numbers measured this round.**

| quantity | measured | bound |
|---|---|---|
| LCC 33/45 cone constant vs mirror | **0** (exact) | 1e-12 |
| Albers 29.5/45.5 cone constant vs mirror | **0** (exact) | 1e-12 |
| Paris–NY spherical distance vs mirror | **0** (exact) | 1e-6 km |
| Paris–NY initial bearing vs mirror | **0** (exact) | 1e-9° |
| Spherical vs WGS84 geodesic, Paris–NY | **0.268%** | 0.3% (D-001) |
| `greatCircle` destination round-trip | 1.14e-13° | 1e-9° |
| Antimeridian crossing latitude error | **0** | 1e-12° |
| `wrapLongitude` / `mod(x,360)`, N=1e7 | 1.03 | 5 |
| `splitAntimeridian` / scan, N=1e6, 15 crossings | 11.3 | 15 |
| `splitTracks` / scan, N=1e6, 100 passes | 12.8 | 20 |
| `geo.grid` / one pass over Z, 2161×4321 | 0.071 | 0.1 |

**D-001 now rests on a measurement.** Its "at most about 0.3%" is asserted
as **0.268%** against oracle O4's WGS84 geodesic, in a test, on every run.

**Pre-validation findings — six, before any code.**

| id | Finding |
|---|---|
| PV-038 | **The declared projection domains are v1's magic literals with the decimals shaved off.** v1's `cosc` thresholds mean 154.158°, 84.261°, 178.015° and 90.000°; the handover declared 154, 84, 178, 90, each rounded INWARD. And only **orthographic** is a real limit: gnomonic diverges at 90 not 84, stereographic at 180 not 154, and azimuthal equidistant has no forward singularity at all. F12's complaint was that v1's literals served as mathematical guard AND cosmetic clip with nothing saying which; declaring the same numbers in a tidier struct reproduces that with better manners. **`Domain` now carries `MaxAngularDistanceDeg`, `SingularityDeg` and `ClipIsCosmetic`** (D-017). The clip values stay v1's so no existing figure silently changes. |
| PV-039 | **Conic degeneracy is EXACT, not approximate.** `p1 = -p2` gives identically zero for both conics at every pair measured; LCC returns negative zero, so the guard reads `abs(n)`. |
| PV-040 | **The wrap formulation is load-bearing.** `mod(lon-lon0+180,360)-180+lon0` is bitwise exact at every point tested; the tidier form folding the offset into one term returns **0.09999999999999432** for `lon = lon0 = 0.1`. Pinned as a frozen criterion so a later tidy-up cannot reintroduce it. |
| PV-041 | **The crossing parameter must use the WRAPPED longitude delta.** The naive delta puts the 179→−179 crossing at latitude **9.97** instead of 15.0 — barely off the start, and entirely plausible on a plot. |
| PV-042 | **The handover's `geo.greatCircle(lon1,lat1,lon2,lat2)` breaks the toolbox's own arity rule.** Four positional arguments against a cap of three, written because v1's `geoNorthArrow` took fifteen (F7). Resolved by pairing coordinates as Nx2 (D-018) rather than exempting the first function to find the rule inconvenient. |
| PV-043 | **A DISABLED WARNING STILL SETS `lastwarn`.** Measured. The runner's warning inventory reads `lastwarn` around each method, so a test that provokes a documented warning and suppresses it *exactly as handover §2.5 prescribes* still fails the warning gate with the identifier reported as new. §2.5 names `geo:splitTracks:TracksDropped` as one such identifier, so the situation was anticipated and the prescribed mechanism did not cover it. `suppressWarning` now restores `lastwarn` as well as the enable flags. **Found the first time any geoMap code raised a warning at all.** |

**Findings from the run — ten, and eight of them were caught by this
project's own instruments on their first contact with real library code.**

| id | Finding |
|---|---|
| PV-044 | **MATLAB's `switch` takes a CELL of alternatives, not a string array.** `case ["a" "b"]` matches nothing and falls silently to `otherwise`, so every conic was classified azimuthal, its cone constant was never computed, and `geo.crs("lambertconformal", ...)` returned `ConeConstant = NaN` without complaint. |
| PV-045 | **Jump DETECTION uses the raw step; only the interpolation uses the wrapped one.** The first draft wrapped first, which makes every crossing a small step by construction, so nothing was ever split. PV-041 and this are the same distinction read in opposite directions. |
| PV-046 | **`geoMapAudit` rejected my own `%#ok<AGROW>` inside `+geo`** — F13, in the first function of the stage. Fixed by preallocating, not by silencing. It then fired on the COMMENT explaining the ban, so the check now requires code on the line and ships a fixture for that false positive. |
| PV-047 | **`provenance_audit` rejected a test file for citing the refuted cone constant without its correction beside it.** Correct, and fixed. |
| PV-048 | **`check_acceptance`'s dotted paths split keys in the middle of a number**, reporting seven present criteria as absent. Stage A criteria use LIST paths: §2.7 forbids parsing a composed value back apart, and this is that rule earning its place inside the instrument that enforces it. |
| PV-049 | **A composed error identifier is invisible to every static reader.** `mustBeSeries` built `[prefix ':NotAVector']`, so the identifier existed nowhere in the source as a literal and the audit reported it as documented-but-never-raised while it worked perfectly. Callers now pass the complete identifier. Generalises D-011: a value assembled out of sight is not a documented contract. |
| PV-050 | **`identifierAgreement` could only see literals handed to `error()`.** Two legitimate patterns break that — a shared validator raising on its caller's behalf, and an identifier arriving through a variable. Now package-wide over the two sets; the superseded per-file form is frozen in place. |
| PV-051 | **The rewritten identifier scan read the comment-stripped code, which blanks string literals too** — and an error identifier IS a string literal, so it found nothing. Caught by the healthy control within seconds. `codeKeepingStrings` is the complement of `stripComments`; both are needed. |
| PV-052 | **`error()` rejects a non-scalar formatted argument**, so `geo.region`'s invalid-box rejection raised `MATLAB:error:nonScalarInput` instead of its own identifier — the rejection path failing to reject. Found by the contract test on its first run, which is the entire reason error branches get tests rather than a reading. |
| PV-053 | **The handover's `geo.grid` speed budget is refuted.** §2.4.3 specifies "at 4× elements / at 1×", expected ~1.0, budget 1.5, claiming validation cost must not depend on `numel(Z)`. The claim is right and the experiment cannot test it: `numel(Z) = nLon·nLat`, so quadrupling Z means doubling BOTH axes, and validation is O(nLon + nLat). Measured **1.82** — a correct implementation reading what the specified comparison actually measures. Replaced by `geo.grid` against **one pass over Z**, which reads 0.071 against 0.1. Corroborated: `struct()` assembly costs 1.54e-06 s at both 18.7 MB and 74.7 MB, ratio 0.99. |

**Binding items a later stage could be wrong for not reading:**

1. **`crs.Domain` has three fields, not one.** `MaxAngularDistanceDeg` is
   what Stage B's `geo.project` must clip at; `SingularityDeg` is where
   the mathematics fails; `ClipIsCosmetic` says whether they differ.
   `MaxAngularDistanceFrom` is `"centre"` for the azimuthals and
   **`"centralMeridian"` for transverse Mercator**, whose limit is a
   distance from a LINE.
2. **`geo.greatCircle` takes Nx2 pairs**, and the destination form takes
   `Bearing` and `Distance` by name. Stage D's scalebar calls it that way.
3. **`geo.splitTracks`' `SpatialJumpThreshold` is in KILOMETRES**, via
   `geo.greatCircle`, not v1's degree-space `hypot`. A degree of longitude
   at 70 N is a third of one at the equator, so v1's option needed a
   different value per latitude band. **This changes the meaning of a
   carried-over option name** and is D-019.
4. **`geo.region` refuses filenames with `geo:region:FileInputNotYetAvailable`.**
   Stage C **converts** that contract test into a success test; it does
   not delete it and write a new one.
5. **`suppressWarning` restores `lastwarn`.** Any future test that
   provokes a documented warning must use it, and must not simply call
   `warning('off',...)` — that silences the display and still fails the
   gate.
6. **Grid orientation is canonicalised** (Lon row, Lat column); tracks and
   point sets preserve theirs. That asymmetry is deliberate and is the
   only place in the toolbox where an input's shape is not returned.
7. **`IsGlobalLon`'s 1.5-step allowance separates one-cell-short from
   two-cells-short**, for every step size. That is why it is 1.5 and not
   1 or 2.

---

## R-007 — Stage B, 15-Aug-2026, tier A

**Scope.** L1 core math, in three checkpoints. `geo.{project, unproject,
scaleFactors, quantile, symmetricLimits, niceTicks, regrid, hillshade,
colormaps}` plus `geo.internal.{robinson, mollweideTheta,
pairCoordinates}`, with `TestB1_projection`, `TestB2_fields`,
`TestB3_colormaps`.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
182; suite size 182, per-class sum 182, 182 passed, 0 failed.** Green gate
on all six conditions. Checkpoints 138 → 164 → 182, each predicted
correctly before its run. **61 value records and 12 ratio records** left
behind by passing assertions.

**The numbers this stage exists to produce.**

| claim | measured | bound | oracle |
|---|---|---|---|
| Mercator y(35°) | 1.1e-16 | 1e-12 | O1 via mirror |
| LCC at (35N, 75W), Snyder p.296 | **0** | 1e-12 | O1 |
| Polar stereographic ρ(70°), SP 71 | **0** | 1e-12 | O4 (the value PV-002 refuted) |
| Robinson PCHIP vs its own table nodes | **0** | 1e-12 | O2 |
| Round trip, 13 of 16 projections | ≤ 4.5e-12° | 1e-9° | O3 |
| Round trip, orthographic | 1.63e-11° | 1e-9° | O3 |
| Round trip, Lambert azimuthal | 2.07e-09° | **1e-8°** | PV-010's exception, and better than the mirror's 4.6e-9 |
| Mercator k = sec φ | 5.0e-9 | 1e-6 | O3 |
| Equal-area AreaScale = 1, worst of five | 1.86e-8 | 1e-6 | O3 |
| Conformal h = k, worst of three | 3.91e-8 | 1e-6 | O3 |
| LCC k = 1 on both standard parallels | 2.52e-9 | 1e-6 | O3 |
| Conservative regrid mass closure | 2.60e-14 | 1e-13 | V7's measured floor |
| F4 seam, longitudes −0.5 **and 179.5** | **0** | 1e-12 | analytic |
| Flat-terrain shade | **0** | 1e-14 | analytic |
| Hillshade metric ratio, lat 60 / lat 0 | 6.09e-6 relative | 1e-5 | analytic (no oracle exists — L10) |
| truecolor Shade = 0.5 composition | **0** | **0** | exact by specification |

**Pinned v1 regressions, all three measured on the installed v1 first.**
F2: `project(359, 10, robinson)` gives −0.0147 where v1 gave **+5.29**.
F3: `project(0, 87, mercator)` is NaN where v1 returned the value for 85°.
F10: `quantile([1 2], 50)` is **1.5** where v1 gave 1.
F16: the ceiling policy at span 45°, where v1's nearest-snap gives ten
lines against a target of six.
F4: the seam, exact at **both** ends.
F5: an inverse exists at all, which is why the round-trip table above can
be written.

**Findings — twelve, and the important ones are about MATLAB itself.**

| id | Finding |
|---|---|
| PV-054 | **MATLAB's MIN and MAX with a scalar bound IGNORE NaN.** `max(NaN, 0)` returns 0. Every guard written the obvious way therefore converts a missing value into a plausible one, silently. **Five sites in one checkpoint**: the conic radicands, the azimuthal denominators, the Tissot sine and both Tissot semi-axes. Repaired with an explicit NaN-in-NaN-out contract at the end of `project` and `unproject`, and a named `clampKeepingNaN` in `scaleFactors`. Every instance was found by a test; none by reading. |
| PV-055 | **The Mollweide early exit the handover asks for breaks the vectorisation contract.** A break on `max(|step|)` over the array makes each element's ITERATION COUNT depend on its neighbours, so a batched result differs from a scalar one in the last ulp. Fifteen unconditional iterations instead — deterministic, and independent of how the caller batched their data. §7.4's instruction is reversed, deliberately. |
| PV-056 | **`geo.scaleFactors` on a domain boundary is HALF defined**, more precisely than mirror limit L7 recorded: `h` is NaN because its central difference steps outside the limit, `k` is finite because its difference does not. A caller testing only `k` sees nothing wrong. This is why `geo.scalebar` must sample strictly INSIDE its extent rather than test for NaN. |
| PV-057 | **`TolMass` was computed as 1e-12, not the 1e-13 documented everywhere.** The mirror used `10^ceil(log10(worst)+1)`, which for a floor of 2.15e-14 returns 1e-12 with 46× headroom — **equal to the handover's guess**, not tighter than it. `regrid.py`'s own comment, debt row V7, change-log C-031 and `geo.regrid`'s ACCURACY block all said 1e-13. **No check could have found this**: every check was comparing the measurement against the wrong tolerance and passing comfortably. It was caught by reading the bound printed beside the measurement in a GREEN run. This is debt V1's failure mode committed inside the instrument built to prevent it. Formula corrected to `10^(floor(log10(worst))+1)`. |
| PV-058 | **MATLAB's `switch` takes a CELL of alternatives, not a string array** (carried from Stage A, and it recurred here in the projection dispatch draft). |
| PV-059 | `griddedInterpolant` calls bilinear interpolation `'linear'`. The public option stays `"bilinear"`, which is what it is called on a 2-D grid and what v1's users will look for; the translation happens once, inside `geo.regrid`. |
| PV-060 | **Three of v1's six colormap presets are not ported.** `viridis`, `magma` and `cividis` exist only as third-party tabulated data, and reproducing those tables here would be copying somebody else's work into this repository — which the handover forbids in the same breath as it asks for an original ramp. `parula`, `jet`, `turbo` and `gray` are delegated to base MATLAB, so this toolbox neither copies nor maintains them. The error message names the three and says to pass an Nx3 array instead. **A change to v1's option surface**, recorded rather than slipped in. |
| PV-061 | The audit flagged four more documented-but-never-raised identifiers across the stage, each one an `arguments`-block validator whose real identifier is MATLAB's. Documented as MATLAB identifiers instead of coining `geo:*` twins — a deprecated alias for an error is still an alias. |
| PV-062 | `geo.region`'s invalid-box rejection raised `MATLAB:error:nonScalarInput` because `error()` refuses a non-scalar formatted argument: the rejection path failing to reject. Carried from Stage A; noted here because the same shape recurs wherever a message quotes a vector. |

**Binding items a later stage could be wrong for not reading:**

1. **Never write `min(max(x, lo), hi)` on data that may contain NaN.** Use
   `clampKeepingNaN` or restore the mask afterwards. Stage D's mask
   handling and Stage C's readers are both full of clamps.
2. **`geo.project` and `geo.unproject` guarantee NaN in BOTH coordinates**
   when either input is NaN. Consumers may test one.
3. **`geo.scaleFactors` returns a half-defined result on a boundary**, so
   `geo.scalebar` samples strictly inside its extent (D-006, L7, PV-056).
4. **`geo.colormaps` accepts an Nx3 array anywhere it accepts a name**,
   which is the migration path for the three dropped presets.
5. **Shade composition is exactly `rgb .* Shade`** with no gamma and no
   clamp. The Ambient floor that stops shadows going black lives in
   `geo.hillshade`, and Stage D must not add a second one.
6. **`geo.regrid`'s conservative path requires uniform axes** and says so
   with its own identifier; Stage C's readers must not hand it a
   non-uniform grid silently.

---

## R-008 — Stage C, 15-Aug-2026, tier A

**Scope.** L2 I/O and caching, plus the CVD colormap reinstatement.
`geo.{readCoastline, readGrid, cache}`, `geo.internal.cvdColormap`,
`data/cvd_colormaps.txt`, `tools/extract_cvd_colormaps.py`, the closed
`geo.region` file hook, and `TestC1_io`.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
205; suite size 205, per-class sum 205, 205 passed, 0 failed.** Green gate
on all six conditions. **68 value records and 13 ratio records.**

**DEBT V3 IS DISCHARGED, and it is the oldest debt in the project.** The
GSHHG reader was inherited from v1 with an honest CONFIDENCE NOTE saying
it had never seen a real GSHHG file. That note was four years old. Real
files arrived at `E:\DATAPOOL\Borders` and the reader was checked against
them:

| oracle | file | result |
|---|---|---|
| **O6** | `gshhs_c.b` L1 | 7 286 pts / 746 parts, lon within ±180, lat −55.67..83.53 |
| **O6** | `gshhs_i.b` L1 | 340 364 pts / 32 835 parts |
| **O6** | `gshhs_c.b` L5/6 | southernmost vertex at **exactly −90** — defect F17 |
| **O5** | `ne_10m_coastline.shp` | 410 957 pts / 4 133 parts |
| **O5** | `ne_10m_ocean.shp` | 446 789 pts / 6 822 parts |

Shapefile coordinates are exact doubles (residual **0**, asserted with
ISEQUAL rather than a tolerance, because anything looser would hide an
endianness error). GSHHG quantisation residual 2.98e-8 microdegrees
against the format's own 1e-6 floor. `Provenance` is now PER FORMAT and
reads `"verified"` for both paths — one claim per code path, because the
GSHHG and shapefile readers share no code and were verified by different
files.

**Cache: cold read / warm cache measures 665× against a budget of ≥10.**
Direction reversed, because this budget asserts a speedup. Defect F14 was
that v1 re-read and re-projected on every call and had no cache at all —
"persistent" appears zero times in its 36 files.

**The Stage A hook is CONVERTED, not deleted.** `geo.region` on a filename
raised its own "not yet available" identifier from Stage A with a contract
test already written against it; Stage C routed the path to
`geo.readCoastline` and turned that failing test into a passing one. The
identifier is now gone entirely.

**Findings — five.**

| id | Finding |
|---|---|
| PV-063 | **The three CVD colormaps should never have been dropped.** B.3 reasoned that reproducing third-party tables is copying. Half right: copying WITHOUT PERMISSION would be, but viridis and magma are CC0 via BIDS/colormap and cividis is CC0 via PLOS open access, so no restriction exists. The stronger point is the opposite of the original one: a GENERATED substitute would have been a lie, because these ramps encode a measured perceptual property and this project has no instrument that measures perception. Reinstated with attribution in LICENSE. |
| PV-064 | **viridis is NOT monotone in Rec.601 luma** — measured maximum decrease 1.70e-3, and the first version of the test failed correctly. Rec.601 is a broadcast approximation of luminance; these ramps are uniform in CIELAB L\*, a different quantity. Asserting the right one was the repair. Measured in L\*: all three strictly monotone (max decrease −0.28, −0.076, −0.20, i.e. no decrease anywhere). |
| PV-065 | The audit rejected `%#ok<AGROW>` in the GSHHG pole-closure branch — F13 again, for two vertices. A ban with an exception for small cases is not a ban; restructured to assign into new variables. |
| PV-066 | **Naming a retired identifier in a help block brings it back to life.** The audit reported `geo:region:FileInputNotYetAvailable` as documented-but-never-raised after the hook closed — because the prose EXPLAINING its retirement quoted it in full. The check cannot tell a documented identifier from a described one, and that is a real limit of a text-scanning gate. Repaired by describing the retired identifier without spelling it. |
| PV-067 | `geo.readGrid`'s GeoTIFF and worldfile paths are DEFERRED to their own round, with a named identifier and a contract test shipped now, on the §6.6 grounds that a binary TIFF tag parser does not belong rushed in beside three other readers. Same pattern the region hook just closed. |

**Binding items a later stage could be wrong for not reading:**

1. **`Provenance` is per format, not per function.** Stage D's coastline
   element should surface it, and a text-file coastline still reads
   `"unverified"` because no canonical real file of that kind exists.
2. **Nothing is cached until the value exists.** A reader that throws
   half way must leave no entry, and the test that proves it is
   `aFailedParseLeavesNoPoisonedEntry`.
3. **Cache keys are structs, hashed whole.** Never compose a key string
   and split it back apart.
4. **GeoTIFF/worldfile remains open**, with its identifier and test in
   place for the round that closes it.

---

## R-009 — Stage D, checkpoint D.0, 16-Aug-2026, tier A

**Scope.** Windowed and strided reading in `geo.readGrid`, the shipped
10-arc-minute topography sample and its builder, oracles **O9 and O10
filled**. A Stage C reader amended in Stage D's branch, because Stage D's
basemap is what needs it and the alternative was a graphics checkpoint
quietly containing a reader change.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
227; suite size 227, per-class sum 227, 227 passed, 0 failed.** Green gate
on all six conditions. **71 value records and 14 ratio records.**

**Why it was needed at all.** ETOPO 2022 arrived at `E:\DATAPOOL\Borders`
in both variants and both resolutions. `ncread` returns double, so the
60-arc-second global field is **1.74 GB** resident and the 30-arc-second
one is **6.95 GB**, before `orientZ`'s transpose doubles the peak. A
regional basemap needs a few thousand cells of that. `geo.readGrid` had no
way to ask for them.

**What the file itself settled — four facts, none of them assumed.**

| fact | measured |
|---|---|
| `z` is stored **(lon, lat)** | dimension names read from the file, not inferred from size |
| **Cell-centred** (`node_offset = 1`) | `lon(1) = −180 + half step` to **0**; span vs 360 − step to **0** |
| Latitude **ascends** in the `.nc` | but the embedded `GeoTransform` says north-up with a negative step — NCO flipped it, so **`.nc` and `.tif` of the same tile disagree on row order** |
| Vertical datum is **EGM2008**, not the ellipsoid | recorded in provenance rather than assumed |

The cell-centred result matters beyond ETOPO: this is the first real
global file to exercise `geo.grid`'s 1.5-step allowance, and `topo.mat`
exercises the other storage convention (0–360, span 359 of 360). Both
measure as global, which is what the allowance was written for.

**Oracles O9 and O10 filled.** O9 by both ETOPO variants; O10 by MATLAB's
own `topo.mat`, which carries no coordinate vectors at all — only
`topolatlim`, `topolonlim` and `topolegend`. The axes are derived from the
**limits and the array size**, two facts that cannot disagree with each
other, rather than from the legend's corner convention, which requires
knowing which corner. Checked against four named places (Himalaya 2850 m,
Mariana −6578 m, Sahara 1036 m, mid-Atlantic −4283 m) so that an axis
derived upside down fails rather than passes.

**`coast.mat` is absent from R2026a base MATLAB**, so that half of O10
cannot be filled and is not pretended otherwise.

**Findings — five.**

| id | Finding |
|---|---|
| PV-068 | **Selecting cells by centre-in-region is wrong twice over, and the second way is invisible.** A region narrower than one cell selects nothing; every other region comes back inset by up to half a cell. Worse, the comparison `centre >= lo − h` puts the same real number on both sides computed two different ways, so a region boundary landing exactly on a cell edge is decided by the last bit. Measured: asking for latitude 30–72 of a one-arc-minute grid returned an axis starting at **30.008**, one cell short, because `30 − 1/120` came out a half-ulp above the centre it should have equalled. **No epsilon was added.** The rule changed: bracket by centres, then step one cell outwards in INDEX space. Coverage is now guaranteed by construction at a cost of at most one surplus cell per edge. Regression test `aRegionBoundaryOnACellEdgeStillCovers`. |
| PV-069 | **A speed fixture too small to see the property it asserts is worse than no fixture.** The windowed-read budget of ≥5 failed at 1.67 — and investigation showed **no implementation could have passed it**: on a 2000×1000 uncompressed file the fixed cost (`ncinfo` plus two axis reads, 8.0 ms) exceeded the data cost (5.9 ms), capping the achievable ratio at **1.26**. A correct reader and one that read everything and trimmed afterwards scored the same. The budget was not loosened. The fixture was made representative — deflate-5 in 250×250 chunks, as ETOPO itself is stored — after which the reader measures **7.91** and a deliberate trim-after-full-read regression measures **1.07**. §4.6 says never loosen a tolerance to pass; it is equally true that a tolerance no fixture can discriminate is not a test. |
| PV-070 | **`verifyError` cannot be used to capture the exception it checks.** `err = tc.verifyError(fh, id)` invokes `fh` with `nargout` matching its own output list, so the call dies with `MATLAB:maxlhs` before the real error is raised — and the test then fails for the right-looking wrong reason. Replaced by an explicit `errorFrom` helper built on try/catch. |
| PV-071 | **Reading one output row at a time did not finish.** The sample builder first read 10 source rows per iteration; ETOPO's 2700×1350 deflate chunks mean a ten-row request decompresses the full width of the file, about 29 Mcell of work to deliver 0.2 Mcell, 1080 times over. Reading roughly a chunk's height at once builds the sample in **6.1 s**. The same arithmetic explains the reader's own measured 184× penalty for strided over contiguous reads. |
| PV-072 | **`readGrid(G, Region=…)` silently ignored the selection** when given a grid rather than a filename, so two arguments meant something on a path and nothing on the grid that path produced. Now applied in memory, with `Topo` carried through the same indices as `Z` — a hillshade built from a window of one and the whole of the other is wrong everywhere and looks right in the middle. |

**The shipped sample averages rather than subsamples, and the difference
was measured, not asserted:** mean |∂z/∂λ| is **91.95 m** for the block
mean against **124.55 m** for a stride of 10 — subsampled terrain is
**35% rougher**, and hillshade is a derivative. Cost of averaging, stated
in LICENSE rather than hidden: the global range narrows from
−10251..6344 m to −10082..6259 m, and a block straddling a coast averages
land and sea, so small islands vanish. Nothing derives a land mask from
this file.

**Ice surface, not bedrock, and the reason is measurable.** At 80°S,
100°W — inside the GSHHG coastline — the surface is **+2 080 m** and the
bed is **−1 158 m**; median ice thickness over the sampled degree square
is 2 213 m. A bedrock basemap paints the interior of the coastline as
ocean. Both variants are supported; only the default is chosen.

**Binding items a later stage could be wrong for not reading:**

1. **A window is guaranteed to COVER the region and may exceed it by one
   cell per edge.** Anything that assumes an exact extent is wrong.
2. **A seam-crossing window returns longitude continuing past 180**
   (e.g. 169.99..190.01), monotone, never wrapped. `geo.grid` requires
   monotonicity and `geo.project` wraps internally, so this is safe —
   but a consumer that assumes ±180 is not.
3. **`Stride` subsamples and is 184× slower per cell than a contiguous
   window on a compressed file.** A decimated global overview belongs in
   `geo.cache`, computed once.
4. **When the GeoTIFF round arrives it must not assume the `.tif` and
   the `.nc` of the same tile agree on row order.** They do not.

---

## R-010 — Stage D, checkpoint D.1, 16-Aug-2026, tier A

**Scope.** The L3 cartographic frame: `geo.internal.layout`,
`geo.internal.avoidRectCollisions`, `geo.internal.elementExtent`,
`geo.basemap`, `geo.graticule`, `geo.frame`, and `TestD1_elements`. Five
of v1's plumbing functions absorbed; its 3413-line monolith replaced for
the raster path.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
262; suite size 262, per-class sum 262, 262 passed, 0 failed.** Green gate
on all six conditions. **77 value records and 15 ratio records, one of
them weak.**

**The largest departure from v1 is that the shading is computed, not
lit.** v1 drew a real three-dimensional surface whose ZData was
exaggerated topography and let OpenGL shade it with `light`, `material`
and `shading interp`. That is defect F9 — the output depended on the
renderer, the driver and the view, so no two machines agreed and nothing
was assertable. `geo.hillshade` computes an intensity array, and the
surface is flat at z = 0 with `FaceColor` flat. **The shading is now a
deterministic array of numbers, which is the only reason any of it can be
tested.**

**Three properties are asserted rather than described:**

| property | measured |
|---|---|
| `Hillshade = "off"` equals `truecolor` without `Shade` | **bit for bit**, `isequal` |
| equirectangular 0° meridian x | **0**, exactly |
| Mollweide global span vs 4√2 | 5.56e-4 relative, bound 1e-3 |
| worst graticule segment, 15 of 16 projections | 0.0049 of the map diagonal, bound 1/200 |
| label anchor unprojected to its own longitude | 2.84e-14° |
| axis-limit drift over ten resize cycles | **0** |
| frame resize / frame draw | 1.009 |

**Findings — seven.**

| id | Finding |
|---|---|
| PV-073 | **`geo.crs`'s domain table was keyed on the projection NAME, but three domains depend on a parameter.** Polar stereographic diverges at the pole opposite its own, so north and south are mirror images; a conformal conic diverges at whichever pole its cone does not wrap, decided by the sign of the cone constant and therefore by the caller's standard parallels. The table could not express any of that and silently returned [−90 90]. **Measured cost:** `geo.project(0, −90, polarstereographic north)` returned **3.266e+16** — not NaN, not an error, a finite number that set the axis limits and made the map one pixel. Lambert conformal was worse because it was subtler: its longest projected graticule segment GREW with sampling, 7.1 at 64 points to 98.6 at 4096, so any refinement loop would never terminate. Fixed by giving `domainOf` the hemisphere and the cone constant, and clipping five degrees short of the divergence — the margin Mercator already used for the same reason. Albers is deliberately NOT clipped: it is an equal-area conic, its ρ is bounded at both poles, and adding a clip would remove map for no reason. **No existing test changed**, which is itself informative: nothing had ever asserted anything at those poles. |
| PV-074 | **An invisible figure does not emit `SizeChanged` when its Position is set.** Measured, not assumed — the first layout probe reported zero listener hits and looked like a broken listener. It fires when the figure becomes visible and on every resize thereafter. Every figure in the harness is invisible so the suite can run headless, so the resize tests raise the real event with `notify(fig, 'SizeChanged')`, which exercises the listener, the registry and every element's update exactly as a drag would. |
| PV-075 | **v1's resize ratchet, reproduced and then solved in closed form.** v1 UNIONED the axis limits on every redraw, so shrinking the figure widened them, which lowered the points-per-data-unit, which widened them again: the map crept smaller inside its own axes. Setting the limits from `geo.basemap`'s pristine `DataLimits` fixed the direction but still left the thickness converging rather than fixed, because drawing the band widens the limits the band is measured in — measured drift 0.0022 units over ten cycles. The relation has an exact solution, `t = target·(D + 0.04·diag)/(W − 2·target)`, and with it the drift is **0** and the thickness change on halving the figure width is **0.00%** against a 5% budget. Converging is not the same as correct. |
| PV-076 | **A speed budget that asserted the wrong relation.** The first Stage D budget required a frame resize to be cheaper than a basemap redraw, reasoning that a resize does less work. Measured: basemap **5.2 ms**, frame draw **12.5 ms** — one `Surface` is cheaper than 28 `Patch` objects, so the premise was false and nothing could have passed. Replaced with the property that actually matters, that a resize costs ONE frame redraw and nothing more, which is what would break if the resize path ever started rebuilding the raster too. Measures 1.009 against a budget of 1.5. Same lesson as PV-069 from D.0, arrived at from the opposite direction. |
| PV-077 | **`verifyEqual(a, b, AbsTol = t, 'diagnostic')` is a syntax error** — name-value arguments must follow every positional one, and the diagnostic is positional. Cost two suite loads, because MATLAB reports it as "unsupported use of the '=' operator" from inside the test framework's file scanner rather than at the line. |
| PV-078 | **The audit caught F6 before it shipped.** `geo.graticule` and `geo.frame` were written with an identical `resolveCrs` and `resolveExtent` each, and the duplicate-local-function check rejected both. That is exactly v1's defect — six locals duplicated across its plotters — caught this time in the same round rather than four years later. Promoted to `geo.internal.elementExtent`. |
| PV-079 | **Transverse Mercator's clip is 0.5° inside its singularity where Mercator's is 5° inside the same kind.** It is the one projection whose graticule cannot meet the smoothness criterion: its equator runs to a real singularity 90° from the central meridian, and at the 89.5° clip the scale factor is **115**. Uniform sampling in longitude needs about **262 000 points on that one line** to get under 1/200 of the diagonal — measured by refining until it did (4096 → 0.147, 32768 → 0.021, 262144 → 0.0027), so it converges and is a resolution limit, not a mathematical one. **Left as an open question rather than repaired**, because widening the clip changes what a v2 figure covers relative to the v1 figure it replaces, which the handover deliberately preserved. Pinned by its own test so that answering the question shows up as a change. |

**Binding items a later stage could be wrong for not reading:**

1. **Nothing rediscovers a handle.** An element's own objects live in the
   layout registry under its kind, so a redraw deletes what it drew.
   `findobj` is banned and there is now no reason to want it.
2. **`H.DataLimits` is pristine and every resize must recompute from it**,
   never from the current axis limits. That is the ratchet fix and it is
   one line away from being undone.
3. **The z-ladder is a contract**: basemap 0, contours and polygons 2,
   graticule 3, coastline 4, overlays 5, frame 6. Asserted, not assumed.
4. **`geo.internal.elementExtent` is where an element gets its projection
   and extent.** D.2 and D.3 must call it rather than growing a fourth
   copy of the same twelve lines.

---

## R-011 — Stage D, checkpoint D.1b, 16-Aug-2026, tier A

**Scope.** One function, `geo.graticule`'s line sampler. **This entry
exists to correct PV-079 in R-010, which was wrong twice over**, and the
wrong versions are left standing above rather than edited away, because
the order in which a thing was understood is part of the evidence.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
263; suite size 263, per-class sum 263, 263 passed, 0 failed.** Green gate
on all six conditions.

**The question that started it, from Matthias: "Is it necessary to fix the
Mercator projections?"** The answer was no, and finding out why exposed a
defect that would have shipped.

**Wrong diagnosis 1 — under-sampling.** D.1 measured that transverse
Mercator's graticule needed about 262 000 uniformly-spaced points to get
every segment under 1/200 of the map diagonal, and concluded the criterion
was out of reach there. The arithmetic was right and the question was
wrong: **the same line's projected arc length is 28.0 against a target
segment of 0.0466, so 601 segments was all it ever needed** — a factor of
**436** wasted by sampling uniformly in degrees, which spends its points
in the middle of the line where the curve barely moves.

**Wrong diagnosis 2 — the projection's clip.** D.1 then reasoned that
transverse Mercator is clipped 0.5° inside its singularity where Mercator
is clipped 5° inside the same kind, and wrote the difference up as an open
question about whether to narrow the strip. That is a real inconsistency
and it is **not what was causing this**.

**What it actually was.** The offending segment measures **6.2832 —
exactly 2π** — and it lies on the meridians **120° from the central
meridian**, on the back of the transverse cylinder, where `cos(Δλ)`
changes sign and the `atan2` giving y flips branch. It is a branch cut,
not a curve. **Bisection cannot shrink it**, which is precisely how it can
be told apart from a curve: a real curve halves when you halve its
parameter interval; a cut does not.

**Without this, every transverse Mercator map would have carried a
spurious straight line across it** — defect F2's cousin. F2 was Robinson's
wrap; this is the same class of error on a different projection, and v2
came within one merged PR of shipping it.

**What changed.**

| | before | after |
|---|---|---|
| sampling | uniform in degrees, resampled whole | bisect only over-long segments |
| points, whole graticule, worst projection | 4 096 **per line** | ~1 800 **for all lines** |
| worst segment, all 16 projections | 0.674 (TM excluded from the claim) | **0.005, none excluded** |
| orthographic horizon shortfall | not measured | **1.5e-9** Earth radii |
| branch cuts | drawn across | broken with NaN |

Three pieces of machinery went with the wrong diagnosis: the 8192-point
cap, the "refining made it worse" guard, and the transverse Mercator
exclusion in the test. **All three were scar tissue around a mis-reading
and all three are gone.** The guard in particular is now unnecessary by
construction — bisection can only shorten a segment.

**Lines now reach the map edge.** A segment with one endpoint inside the
domain and one outside is bisected too, so a meridian arrives AT the
boundary instead of stopping at whichever sample happened to be the last
finite one. Measured on orthographic, whose horizon is at radius 1
exactly: the graticule reaches **1.000000**, short by 1.5e-9.

**Findings — one.**

| id | Finding |
|---|---|
| PV-080 | **A segment that will not shrink under bisection is a discontinuity, not a curve**, and that is a projection-agnostic test requiring no table, no per-projection special case and no knowledge of where a given projection's branch cut lies. It is the general form of the rule `geo.splitAntimeridian` applies to tracks, and it caught a 2π jump in transverse Mercator that two rounds of reasoning about clips and sampling densities had both missed. **PV-079 is superseded**: transverse Mercator's clip needs no change, and the criterion is met by all sixteen projections. The 0.5°-versus-5° margin inconsistency noted there is real but is a separate and much smaller matter, and is no longer blocking anything. |

**Binding items a later stage could be wrong for not reading:**

1. **D.2's coastline and overlays project polylines too**, and every one
   of them can carry a branch cut. They must break the same way — the
   rule lives in `geo.graticule`'s `traceLine` today and should be
   promoted to `geo.internal` the moment a second caller needs it.
2. **`MaxSegment` excludes broken segments**, because a gap is not a
   segment. Anything reading it should know that.

---

## R-012 — Stage D, checkpoint D.2a, 16-Aug-2026, tier A

**Scope.** `geo.internal.projectPolyline`, `geo.coastline`,
`geo.scalebar`, `geo.northarrow`, the shipped Natural Earth coastline and
its builder. **D.2 is split**: the colorbar and the map inset are D.2b.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
285; suite size 285, per-class sum 285, 285 passed, 0 failed.** Green gate
on all six conditions. **79 value records and 16 ratio records, two weak.**

**v1's SCALE BAR DID NOT MEASURE WHAT IT SAID, and that is the largest
defect found in this project so far.** It drew a bar of FIXED width - 90
points, always - then computed the ground distance those 90 points
happened to span and printed the nearest entry of a hard-coded ladder
beside it. **The bar was never resized to match.** A bar spanning 3 km was
labelled "2 km"; one spanning 750 km was labelled "500 km". Errors
approaching 50%, on the one element of a map whose entire purpose is to be
measured against. Three further faults compounded it: the calibration was
taken along a MERIDIAN and applied to a HORIZONTAL bar; the ladder clamped
at 1 km and 5000 km, mislabelling every regional and every planetary map;
and the nice value was chosen nearest in linear space, biasing to the
smaller neighbour across every decade.

v2 chooses the ground distance first and draws the bar exactly that long.
**Asserted by walking it**: 16 000 points unprojected across the drawn bar
and the great-circle steps summed, which accumulates a different quantity
from the single derivative the bar was built from. Agreement **7.75e-10
relative**.

**Getting that right took two corrections of my own, both measured.**

| what | measured error |
|---|---|
| calibrated at the map centre, drawn at the corner | **59%** |
| calibrated at the bar's baseline, not its centre | **9.3%** |
| final | **7.75e-10** |

The second is the instructive one: a half-thickness offset, invisible
reading the code, worth 9% because cos(66°) and cos(63.5°) are not the
same number and the bar sat between them.

**Findings — five.**

| id | Finding |
|---|---|
| PV-081 | **`geo.readCoastline("builtin")` could not work on R2026a.** It loaded `coastlines.mat`, which shipped with base MATLAB for years and now ships only with the Mapping Toolbox - whose absence is the point of F1. Stage C shipped it, Stage C's tests passed, and nothing caught it because no test had ever asked for the builtin coastline: the reference tests used real GSHHG and Natural Earth files and the contract tests used arrays. **A path with no caller is a path with no test, whatever the coverage table says.** Repaired by shipping a Natural Earth 110m coastline, which is public domain and therefore redistributable where GSHHG is not. |
| PV-082 | **A scale bar must be calibrated where it is DRAWN, not where the map is centred** - and the difference on a global map is 59%. Then, having fixed that, the calibration must be taken at the bar's vertical CENTRE and not its baseline, which is another 9.3%. Both were found by walking the drawn bar rather than by reading the code, which is what that instrument is for. |
| PV-083 | **The calibration step is a secant and its error is O(step²).** Measured against the closed form R·cos(lat): 1.3e-6 at width/1e3, 1.3e-8 at 1e4, 1.3e-10 at 1e5, **5.3e-12 at 1e6**, then DEGRADING to 2.9e-10 at 1e7 as floating-point cancellation in the unprojection takes over. The step is set at the floor of that curve, which is a measurement and not a preference. |
| PV-084 | **A third Stage D speed fixture was too small to ask its own question.** The coastline budget failed at 3.29 against a toy 36×72 basemap; against the shipped 10-arc-minute grid it measures **0.139**. Nobody draws a coastline over 2 592 cells. With PV-069 and PV-076 this is now a named pattern rather than three accidents: **a graphics speed fixture must be the size of the thing it is about.** |
| PV-085 | **The audit caught F6 for the third time**, `mapBox` duplicated between `geo.scalebar` and `geo.northarrow`. Absorbed into `geo.internal.elementExtent`, which now answers the whole of "what am I drawing over" - projection, geographic extent, projected box and its diagonal. Each catch has been within the same round; v1 shipped its six for four years. |

**North is measured AT the arrow.** v1 computed one bearing at the
projection's reference point and used it wherever the arrow sat. On a
Lambert conformal conic the two upper corners differ by **205.7 degrees**
of convergence between them; an arrow drawn with the centre's bearing
points somewhere that is not north. Asserted both ways: exactly 0 at every
corner on equirectangular, and provably different between corners on the
conic.

**Binding items a later stage could be wrong for not reading:**

1. **`geo.internal.projectPolyline` is where a polyline becomes drawable.**
   D.2b and D.3 must call it. `Densify` is TRUE only for generated lines;
   a data polyline gets `false`, because inventing vertices between two
   survey points invents geography.
2. **`geo.internal.elementExtent` returns the projected box and diagonal.**
   Nothing may recompute them; that is what F6 keeps being.
3. **The shipped coastline is a fallback, not a recommendation.** Anything
   that cares about the shoreline should take a GSHHG path.

---

## R-013 — Stage D, checkpoint D.2b, 16-Aug-2026, tier A

**WRITTEN LATE, AND THAT IS ITSELF THE FIRST FINDING.** This entry should
have shipped with PR #10 and did not: the shell command that wrote it was
chained after an `rm` with `&&`, the `rm` failed on a read-only mount, and
the Python that wrote the record never ran. The commit went out with the
code and without its evidence, and nothing caught it — the gates check the
tree, not whether the tree was described. Recorded as **PV-094**.

**Scope.** `geo.colorbar`, `geo.inset`, `geo.internal.plottedBox`.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
305; suite size 305, per-class sum 305, 305 passed, 0 failed.** Green gate
on all six conditions.

**Four implementations become one.** v1 had the native path,
`geoGmtColorbar`, TWO byte-identical copies of `localAddHalfColorbar` in
different files, and `localAddDualScaleColorbar`.

| | v1 | v2 |
|---|---|---|
| objects, continuous bar | ~283 | **9** |
| colour strip | one `patch` per colour | one truecolor `surface` |
| tick marks | 2 objects each | one NaN-separated `line` |
| handles after a resize | **all invalid** | live |

**Findings.**

| id | Finding |
|---|---|
| PV-086 | **All three of v1's custom colorbars returned handles that went stale on first resize.** Each captured what its first draw created, then deleted and recreated everything on every resize, so `H.Colorbar` held only invalid handles the moment the window was touched. |
| PV-087 | **An end cap meant nothing.** GMT's convention, which v1's own docstring cites, is that a cap means the data CONTINUES past that end. v1 drew both triangles whenever `Arrows` was on and varied only their colour. |
| PV-088 | **v1's half colorbar overlapped its own text** by about 14 points whenever a label was set, while leaving 15 points of dead space above the bar. Its dual-scale sibling had already been fixed; that version was kept. |
| PV-089 | **F6 a fourth time.** `plottedBox` written twice in v2 and rejected in the round; v1 carried the same computation five times, with comments recording two more. |

**A gap the coverage gate could not see.** `geo.internal.plottedBox` was
created without a `CoveredFunctions` entry and the runner reported no
gaps, because the coverage table only checks functions some suite has
DECLARED. PV-081's lesson in a different costume.

---

## R-014 — Stage D, checkpoint D.3a, 16-Aug-2026, tier A

**Scope.** `geo.overlayPolygons`, `geo.stipple`, `geo.overlayContours` —
the three overlays that describe the FIELD and therefore sit under the
graticule. **D.3b** is `overlayTrack` and `overlayPoints`, at z = 5.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
327; suite size 327, per-class sum 327, 327 passed, 0 failed.** Green gate
on all six conditions.

**Two of these are new, and they are why this toolbox is worth rewriting
for this project.** `geo.overlayPolygons` draws a value per irregular
cell, which is what a mascon solution IS; a regular grid cannot represent
one, and v1 forced such a field onto a lon/lat raster, inventing
boundaries the solution does not have and smoothing across the
discontinuity that is the point of the parameterisation. `geo.stipple`
draws a significance mask, which v1 could not do at all — so every figure
it made either overstated its result or carried the mask in a separate
panel nobody put beside it.

**Two exact claims, asserted:**

| | measured |
|---|---|
| polygon colour vs the basemap's for the same value | **0**, bit for bit |
| seam-crossing polygon's parts vs its own width | 5.6e-12 of the map |

**Findings — five.**

| id | Finding |
|---|---|
| PV-090 | **A RING IS NOT A POLYLINE, and treating it as one loses the polygon entirely.** Splitting an open line at its seam crossings leaves the pieces OPEN, and a patch closes whatever it is given by joining its last vertex to its first — straight across the map. Measured on a 20-degree box across the seam: with no split, **one patch spanning 94% of the map width**; with a break-based split, **three fragments of one or two vertices, all discarded, and the mascon gone**. A ring has to be CLIPPED — Sutherland-Hodgman against each 360-degree window — so every part closes along the meridian it was cut on. The two parts then total exactly the polygon's own width. |
| PV-091 | **The projection's longitude window is HALF-OPEN, and a clipped polygon's edge lands on the boundary.** A part correctly clipped to [170, 180] came out spanning **97% of the map**, because its 180-degree vertices wrap to −180 and project to the far edge. Clipping to [lo + 1e-9, hi − 1e-9] leaves no vertex on the seam. A choice of REPRESENTATION, not a tolerance on a measurement: 1e-9 degrees is a tenth of a millimetre on the ground. |
| PV-092 | **v1 broke contours with two heuristic passes and three tuned constants** — a longitude difference above 180, then `min(0.5*diag, max(30*medSeg, 0.02*diag))`, described in its own comments as "belt-and-suspenders". Both caught one class of error. `geo.internal.projectPolyline` catches it with **no constants at all**. Three functions have now been written against that rule and none needed a threshold. |
| PV-093 | **Ten array-growth findings in one round**, the largest batch of the project: six in `overlayContours`, three in `overlayPolygons`, one in `stipple`. Every one was a loop whose iteration count is unknown until it runs — contour runs, polygon parts, hatch strokes — which is exactly the shape F13 describes and exactly the shape that invites `end + 1`. |
| PV-094 | **A record entry was lost to a shell `&&`.** See R-013's header. The lesson is narrow and worth having: a chained shell command that writes evidence must not depend on the success of an unrelated command before it. Separated with `;` since. |

**The stipple is deterministic by construction.** A random thinning would
be prettier and untestable, and a reader with the same data could not
reproduce the figure. The stride is `ceil(masked / Density)` — asserted
both ways: the stride matches the formula, and two calls give
bit-identical coordinates.

**Binding items a later stage could be wrong for not reading:**

1. **A closed ring needs clipping, not breaking.** D.3b's tracks are open
   polylines and may use `geo.internal.projectPolyline` directly; anything
   filled may not.
2. **The seam nudge is in `geo.overlayPolygons` only.** Anything else that
   clips to a longitude window meets the same half-open boundary.

---

## R-015 — Stage D, checkpoint D.3b, 16-Aug-2026, tier A. **STAGE D CLOSES.**

**Scope.** `geo.overlayTrack`, `geo.overlayPoints`,
`geo.internal.colourScale`. **Stage D is complete**: fourteen L3 elements
and five internals, replacing v1's 3413-line plotting function, its two
near-clones and its five plumbing functions.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
347; suite size 347, per-class sum 347, 347 passed, 0 failed.** Green gate
on all six conditions.

**Two exact claims, both of which v1 would have failed:**

| | measured |
|---|---|
| wiggle peak amplitude vs max\|Obs\| × Scale | **2.7e-16** relative |
| legend circle radius vs its own marker's radius | **0** points |

**Findings — five.**

| id | Finding |
|---|---|
| PV-095 | **v1 computed the wiggle's "auto" scale PER RUN.** It lived inside the per-run drawing function and took that run's own maximum, so a track broken by a single missing sample drew two ribbons at two different scales with nothing on the figure to say so. A wiggle is a QUANTITATIVE display whose entire content is the amplitude; two segments of one orbit could not be compared by eye, which is the only way anybody reads them. One scale for the whole track now, asserted by drawing a track and the same track with a gap punched through its quiet half and requiring the two to report the same number. |
| PV-096 | **v1's size legend was 11% wrong and decoded its own markers incorrectly.** It drew reference circles at radius `sqrt(area/pi)` — the radius of a circle of that AREA — while MATLAB's `scatter` treats `SizeData` as the area of the marker's BOUNDING BOX, giving radius `sqrt(area)/2`. The factor is `sqrt(pi)/2 = 0.886`. A reader measuring a bubble against that legend read the wrong number, which is the one thing a legend exists not to allow. |
| PV-097 | **SCATTER3 CLEARS THE AXES, and in a composable toolbox that is a landmine.** It is a high-level plotting call and resets the axes unless `hold` is on. Measured: a map carrying **fifty objects came back with five** — the basemap and every element drawn before it, gone. v1 never met this because it drew everything inside one function in a fixed order; v2's whole design is that any element may be called at any time. The hold state is now saved, forced and restored, and a regression test draws a populated map and requires the count to GROW. |
| PV-098 | **A missing size is not the smallest size.** v1 mapped a NaN in `SizeData` to fraction zero, so a point with no measurement rendered identically to the smallest real one. "We did not measure this" and "this is the minimum" are different statements and now look different. |
| PV-099 | **Adding a method to the shared test base class silently EXCLUDED two existing suites.** `mapAxes` was promoted to `GeoMapTestCase`, and the two suites that already had a private one of that name were dropped by the framework for an access-permission mismatch — reported as a warning, not an error. The suite would have run smaller and still called itself green. **The reconcile-three-ways caught it**, which is exactly the signal that instrument exists to give: the count moved when nothing should have moved it. |

**F6 for the FIFTH time.** `colourFrom` was written identically in
`geo.overlayTrack` and `geo.overlayPoints` and rejected within the round;
promoted to `geo.internal.colourScale`, which `geo.overlayPolygons` now
uses too. v2 has been stopped from committing a duplicated local on five
separate occasions, every one inside the checkpoint that wrote it. v1
shipped six of them for four years.

**PV-077 recurred a THIRD time** — `verifyEqual(a, b, RelTol = t,
'diagnostic')`. Three checkpoints, three occurrences, one suite load lost
each time. Worth a habit rather than a note: the diagnostic goes before
the tolerance.

**Stage D, complete:**

| | |
|---|---|
| elements | basemap, graticule, frame, coastline, scalebar, northarrow, colorbar, inset, overlayPolygons, stipple, overlayContours, overlayTrack, overlayPoints |
| internals | layout, avoidRectCollisions, elementExtent, projectPolyline, plottedBox, colourScale |
| v1 code replaced | one 3413-line function, two near-clones, five plumbing functions, four colorbar implementations |
| suite | 347 points |

---

## R-016 — Stage E, checkpoint E.0, 16-Aug-2026, tier A

**Scope.** `geo.export`, `geo.internal.writeFigureFile`, and the audit's
thirteenth check — `orchestrationPurity`, which is the Stage E hard rule
made mechanical.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
370; suite size 370, per-class sum 370, 370 passed, 0 failed.** Green gate
on all six conditions. Audit: 15 fixtures, every check proved, 0 findings.
Also green on `glnxa64` CI, which for this checkpoint is not a formality:
three of the five findings below are visible only there.

**Four claims, all read off the file the operating system wrote:**

| | measured | bound |
|---|---|---|
| PDF page width vs the requested 17.0 cm | **0.00389 cm** | ≤ 0.05 |
| PNG pixel width vs 17.0 cm at 300 dpi | **0.126 px** | ≤ 1 |
| spread of one page expressed in cm, in and pt | **exactly 0 cm** | ≤ 0.05 |
| bare `exportgraphics` width vs the requested page | **0.2605 relative** | ≥ 0.05 |

The third is the one to notice: 17 cm, 6.69291 in and 481.89 pt produced
**byte-identical page widths**, so nothing in the unit handling rounds in
one path and not another. The fourth is the defect, asserted as a test:
the naive route is 26% off on the same figure.

**Speed.** `geo.export` vs bare `print` on the same paper setup:
**0.988** against a weak budget of 1.6. The sizing, state-saving and
routing cost nothing measurable next to the file write.

**Findings — five, and the fifth was invisible on the development machine.**

| id | Finding |
|---|---|
| PV-100 | **v1 could not be asked for a figure of a given physical size, and neither of MATLAB's two export routes gives one by itself.** v1's entire export path is `exportgraphics(fig, path, 'Resolution', dpi)` over a figure sized in SCREEN PIXELS, so the centimetres delivered are a function of the machine's `ScreenPixelsPerInch`. Worse, `exportgraphics` **ignores `PaperPosition` and crops to content**: a figure set to 17 × 12 cm exported to PNG at 300 dpi came back 1486 × 711 px = **12.58 cm, 26% narrow**; the same figure at its default on-screen size, with a 17 cm page requested, came back 3269 px = **27.7 cm, 63% wide**. Both measured. A journal asks for 17.0 cm. `print`, driven by `PaperPosition` and `PaperSize`, delivers 17.004 cm — so `print` is the primary route here and `exportgraphics` is used only where it is the better instrument (a content crop, and `.gif`, which `print` has no driver for). |
| PV-101 | **`geoImagescMulti` has no export at all.** The one v1 function whose output is most likely to reach a paper — the multi-panel figure — never gained an `ExportPath`. `grep` over the v1 tree finds `exportgraphics` in exactly three of its five front functions. |
| PV-104 | **The first export of a figure is a different image on software OpenGL, and every export after it is identical — and the tests that caught it were asserting the wrong thing.** Windows passed both metamorphic tests; headless Linux CI failed both. The instinct is to call that renderer noise and loosen the claim; §4.6 forbids exactly that, so the test was made to **diagnose** instead — export three times, report 1-vs-2 against 2-vs-3. The answer was unambiguous: **1 vs 2, 42 176 of 134 805 pixels differ (31.29%), max channel delta 254; 2 vs 3, 0 pixels, exactly.** Not an irreproducible renderer — a first render that differs from every later one. It does not reproduce on Windows, interactively **or** under `-batch`, so it belongs to that rasteriser's warm-up and not to anything geoMap decides. **The real finding is what that exposed about the tests.** Both compared each figure's FIRST render against its second, so neither could isolate what it existed to test: the batch test called a warm-up difference an ordering effect. Removing the confound — one discarded export first — is not weakening the claim, it is the only way to make it testable. And what `geo.export` *does* control across a first export is now asserted on its own: same pixel dimensions, same route, same reported page. Somebody who builds a figure and exports it once, which is the entire builder and batch workflow, still gets the size they asked for. **A `drawnow` before the write was tried first and changed nothing — the numbers came back identical to the digit — so it was removed rather than left in looking like a fix.** |
| PV-103 | **A variable named `methods` made the text gate lose its place, and MATLAB did not care.** `methods = strings(1, n)` is legal and ran correctly through every MATLAB test; `tools/mcheck.py` read the assignment as the start of a class block and reported `export.m` **unbalanced by three levels**, with two functions and a phantom `methods` block unclosed. The two gates read the source differently on purpose (§2.9), and that only pays if the disagreement is treated as a finding rather than as a false positive. It was: the variable is now `routes`, and `methods`, `properties`, `events`, `enumeration` and `arguments` joined the `shadowedBuiltins` watch list, which had `clim` and `figure` but no block keyword. **This is the second time the Python gate has caught what the MATLAB gate could not**, in the opposite direction to R-004, where the Code Analyzer caught three stale AGROW pragmas the text checker was blind to. |
| PV-102 | **The new purity check fired on the file that merely EXPLAINS it.** Written as a `contains`, `orchestrationPurity` flagged `+geo/export.m`, which declares no marker and only describes the rule in its help. **This is the third time this project has met the same shape**: `arrayGrowth` fired on the file documenting why `%#ok<AGROW>` is banned, and `checkPrinting` carries a comment about it. Prose about a token is not the token. The marker is now structural — the help line, stripped of its comment character and trimmed, must BE the marker — and the healthy fixture tree carries a compliant front so the control proves the lookbehind on every run. |

**Two things the audit caught inside this checkpoint.** `export.m` came in
at 441 lines, over D-003's 400. The fix was not a justification line but a
split: format routing — which instrument writes which extension, and the
fallback — moved to `geo.internal.writeFigureFile`, which is a better
design independently. And the purity check's own 200-line budget rejected
`export.m` at 233 executable lines, which is how it was established that
**`geo.export` is an L4 *utility* and not an L4 *front*** and carries no
marker. Marking it would have meant a false pass or a raised limit; §4.6
forbids the second.

**The parallel path, measured end to end.** Three builders on a 16-worker
pool wrote three correctly-sized, correctly-coloured PNGs in 2.82 s and
leaked no figure to the client. The first attempt failed with
`Unrecognized function or variable 'localBuild'` — a builder that reached
a local function of the calling script. That message names the symbol and
not the cause, so it is now wrapped as `geo:export:WorkerFailed`, which
names the cause. **A builder must be self-contained**, and that is the
sharp edge of the parallel form.

**One warning suppressed, with its cause named.**
`MATLAB:graphics:HardwareUnavailable` fails the warning gate on CI. It is
a statement about the host — no hardware OpenGL, software rasteriser in
use — and not about anything geoMap does, and it is **the exact condition
behind PV-104**. Suppressed per test method in `TestE0_export`, with that
connection written at the suppression rather than left for someone to
rediscover.

**An exemption withdrawn.** `geo.export | reference` was reserved in
advance as *"no external authority certifies a PDF's byte content"*. True
and irrelevant: nothing certifies the content, but the file's own
`MediaBox` certifies its **size**, and the size is the whole claim.
`geo.export` has four reference tests. Second exemption withdrawn on
inspection, after `geo.cache | metamorphic`.

---

## R-017 — Stage E, checkpoint E.1a, 16-Aug-2026, tier A

**Scope.** `geo.map`, the first L4 front, and `geo.title`, the L3 element
it turned out to need.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
392; suite size 392, per-class sum 392, 392 passed, 0 failed.** Green gate
on all six. Audit: 15 fixtures, every check proved, 0 findings.

**The number this checkpoint is about:**

| | |
|---|---|
| v1's `geoImagesc` | **3413 lines** |
| `geo.map`, executable | **128 lines**, against a 200-line budget |

**Composition is exact.** A map built in one call and the same map built
element by element give identical `CData`, identical `DataLimits`, the
same registered elements and the same object count on the axes. That is
the only claim that makes a front safe to use instead of the elements,
and it is the one asserted.

| | measured | bound |
|---|---|---|
| title clearance above the map vs Gap × diagonal | **2.28e-15** relative | ≤ 1e-9 |
| `geo.map` vs the same four elements by hand | **1.121** | ≤ 1.3, weak |

**The rule bit twice, which is the point of having it.**

| id | Finding |
|---|---|
| PV-105 | **`geo.map` needed a title and there was no element for one.** The Stage E rule says a front that needs a drawing primitive stops and flags the missing L3 capability rather than inlining it, and this is the first time it fired on real code. `GEO.TITLE` was written instead of a `text()` call, and `title`, `xlabel`, `ylabel`, `legend` and `sgtitle` joined the audit's banned list on the same day so that no front can quietly acquire one later. **Writing the element found a defect that inlining would have shipped**: MATLAB's `TITLE` anchors to the AXES box, and under `axis equal` an axes letterboxes — measured on a 2:1 world map in a default axes, the map's top sits **53.03 points** below the axes' top, so a stock title floats three quarters of an inch clear of the map with nothing in between. `GEO.TITLE` anchors to the plotted box. (The horizontal centres *do* agree, because letterboxing is symmetric — checked before it was claimed, and the first draft of the help claimed the opposite.) |
| PV-106 | **There is no element that draws a region outline, and it is flagged rather than improvised.** v1's `AreaOfInterest` drew a dashed outline of a rectangle or polygon. `geo.coastline` draws coastlines; `geo.overlayPolygons` fills. Rather than bend either, `Region` is absent from `geo.map` and named in its LIMITATIONS. Second thing the rule has caught and the first it has not resolved — which is the honest state to be in, and visible rather than papered over. |
| PV-107 | **A front cannot hand every option to every element, because MATLAB's `arguments` block REJECTS an unknown name-value pair rather than ignoring it.** `geo.coastline` draws no text and refused `FontSize` on this file's first run. That is correct on its side — a front that could pass anything to anything would have no contract — so the ladder table carries a column saying which elements draw text, and a regression test asserts the shared typeface reaches the graticule and not the coastline. |
| PV-108 | **`geo.crs` is the one constructor in this toolbox that is not idempotent**, and a front is exactly where that bites. `geo.grid`, `geo.track`, `geo.points` and `geo.region` all accept their own output; `geo.crs` takes a name and rejects a crs struct. `geo.map(G, geo.crs("mollweide"))` — the call every element example in the documentation makes — failed on the first run. Guarded, and asserted rather than remembered. |

**A missed prediction, reported.** The E.1a suite was predicted at 21
points and came in at 22: the contract block has eleven methods, not ten.
The count was miscounted, not the change misunderstood — but the
instrument did what it exists to do, and a miss is worth recording even
when it is benign, because a record of only the alarming ones teaches
that a small miss is not worth checking.

---

## R-018 — Stage E, checkpoint E.1b, 16-Aug-2026, tier A. **A finding withdrawn.**

**Scope.** The region outline, and the instrument that will drive the v1
option compatibility layer.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
394; suite size 394, per-class sum 394, 394 passed, 0 failed.** Green gate
on all six. Audit 0 findings.

**PV-106 IS WITHDRAWN. It was wrong, and it shipped.** E.1a reported that
no L3 element draws a region outline and left `Region` out of `geo.map`
on that basis. `geo.coastline` has taken **`Kind = "outline"`** since D.2,
with its own colour and width, and its own H1 line reads *"Shorelines,
rivers or an outline"*. The claim was made after reading the function's
`arguments` block out of a bulk grep and never reading its help. It went
into `geo.map`'s LIMITATIONS, into R-017, and into a merged PR.

| id | Finding |
|---|---|
| PV-109 | **The gap was real but in a different place, and one layer down.** `geo.region` left `Outline` **empty for a box** and filled it only when the caller happened to pass a polygon — so `Outline` meant *"the polygon, if this region was given as one"*, a field whose meaning depended on how the value was built. There were no vertices for the outline element to draw, and the element got the blame. A box has four corners; they are now computed once in `geo.region`, closed with a repeated first vertex, and `Outline` means *the vertices of this region* for every region. `geo.map(Region = ...)` is then a pure forward to `geo.coastline(Kind = "outline")` with no geometry in the front. |

**The old assertion is worth reading.** `TestA3_region` required
`isempty(named.Outline)`, with the diagnostic *"a preset is a box; an
empty outline is how a caller knows"*. The test did not fail to catch
this — **it specified it**. That is the sharper lesson than the missed
help text: a test can lock in a shape that no single function is wrong
about and that nothing downstream can use. It was replaced with the
corrected contract and the reason written at the assertion.

**What the false flag cost, and what it did not.** It cost a wrong
sentence in three places and one merged PR. It did not cost a wrong
*figure*: the Stage E rule says flag rather than inline, so the response
to the supposed gap was to leave `Region` out and say so, not to
improvise a rectangle inside `geo.map`. **A rule that makes being wrong
cheap is worth more than one that makes being wrong unlikely** — the
inlined version would have been silently wrong for as long as it lived,
and this was found the moment someone read the element properly.

**Also delivered: `records/v1_option_resolution.m`**, an instrument that
proposes a v2 destination for each v1 option and **checks it against the
target's real `arguments` block** rather than asserting it. First pass
over the 114 options reaching `geoImagesc`: **54 resolve mechanically, 60
do not** — and the 60 fall into four classes, of which only the last
needs a decision:

| class | examples | needs |
|---|---|---|
| on/off booleans | `Coastlines`, `ShowColorbar`, `NorthArrow`, `MapInset` | map to the `geo.map` option itself as true/false |
| prefix gaps | `AmbientStrength`→`Ambient`, `PointSizeData`→`SizeData` | more strip rules |
| **collapsed pairs** | `NorthArrowColor1` + `Color2` → one `Colors` | the layer must MERGE, so a rename table cannot express it |
| genuinely absent | `LatitudeLabelRotation`, `MapInsetStyle`, `MaskThresholdSide`, `VerticalExaggeration` | a decision each, and none is guessed here |

The instrument is committed rather than a table, deliberately: the
inventory's own rule is *"an option no rule matched is unmapped, never
guessed"*, and this is what enforces it.

---

## R-019 — Stage E, checkpoint E.1c, 16-Aug-2026, tier A. **V9 discharged.**

**Scope.** `geo.internal.v1OptionTable`, `geo.internal.v1Options`,
`geo.v1.imagesc`. Every one of v1 `geoImagesc`'s options is accounted
for.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
410; suite size 410, per-class sum 410, 410 passed, 0 failed.** Green gate
on all six. Audit 0 findings, mcheck 0, provenance 0.

**The claim, and it is exact.** Every option `geoImagesc` declares either
translates to a v2 option **that exists**, or raises with the replacement
named. There is no third outcome — in particular **no v1 option is
silently ignored**, which is the failure a migration layer exists to
prevent. Both sides are read from source in the test: the v1 names out of
`geoImagesc.m`'s own `arguments` block, the v2 names out of each
element's, so neither list can drift from the code it describes.

| | |
|---|---|
| options `geoImagesc` declares | **120** |
| rows in the table | **120**, and `setdiff` is empty both ways |
| translate to an option that exists | **92** |
| raise `NoEquivalent`, replacement named | **28** |

**Findings — four, and the first is about the instrument itself.**

| id | Finding |
|---|---|
| PV-110 | **The instrument read the wrong authority, and was wrong in both directions.** `records/v1_option_resolution.m` took its v1 names from the Stage 0 inventory's "fronts" column with a **prefix match**, so `geoImagescPoints` and `geoImagescTrack` counted as `geoImagesc`. It reported 114 options, including `SizeData`, `ShowLegend`, `GridOn` and `SharedColorbar`, which `geoImagesc` has never had — and being a summary, the inventory could equally have omitted ones it does. The authority on a function's option names is that function's source. Read that way, the count is **120 exactly**. The instrument had the right principle on the v2 side from the first line and the wrong one on the v1 side. |
| PV-111 | **`geo.map` read `CRS = ...` only in the raw-triplet form.** Written narrow, it worked for `geo.map(lon, lat, Z, CRS = c)` and was **silently ignored** by `geo.map(G, CRS = c)` — which is exactly the shape the translator produces, because v1 spelled the projection as an option and not as an argument. The map drew, in the default projection, without complaint. Found by the first end-to-end `geo.v1.imagesc` call, not by any unit test: the two-argument form had always been given its crs positionally. |
| PV-112 | **Nine v1 names are also v2 names, and that broke idempotence.** `Graticule`, `Rivers`, `Points`, `NorthArrow`, `ScaleBar`, `Title`, `Parent`, `FontName` and `FontSize` are spelled identically in both — not an accident, v1 got them right and v2 kept them. But a *translated* list therefore still contains names the table recognises, so `Graticule = struct(StepLon = 60)` came back through as a toggle and was asked to evaluate a struct as a logical. A struct is already v2 spelling and now passes through. Asserted: translating twice changes nothing. |
| PV-113 | **A `for` over a column runs once, with the whole column.** The V9 test wrote `for name = declared'` and MATLAB dutifully bound all 120 names to `name` in a single iteration, so `[T.V1] == name` broadcast to 120×120 and the test errored instead of checking anything. It failed loudly, which is the only reason it was caught — the same transpose in a loop that merely *accumulates* would have passed while testing one thing instead of 120. |

**What a rename table could not have done.** Three of the six kinds are
not substitutions. `NorthArrowColor1` and `NorthArrowColor2` are rows 1
and 2 of one `Colors` matrix, so the layer **accumulates** and setting one
leaves the other at the element's default rather than at zero. v1's six
loose projection settings — which had to agree with each other and were
checked nowhere — are gathered into one `geo.crs` that validates them
together, so a conic without a standard parallel now fails at
translation. And 28 have no equivalent at all, each raising with an
instruction rather than "unrecognised argument".

**`geo.v1.imagesc`, not `geoImagesc`.** OB-7 keeps v1 installed until
Stage F, and a file of that name would shadow it or be shadowed by it
depending on path order — the worst failure available, because which
toolbox drew the figure would depend on something nobody set
deliberately. The name changes; no option does.

---

## PV-114 — **REOPENED AND RE-CLOSED 20-Aug-2026. The hypothesis below was WRONG, and its own diagnostic refuted it.**

The four-figure diagnostic fired at E.4 and reported, for figure **2 of
4**:

| pair | pixels differing |
|---|---|
| warm vs export 1 | **0** |
| warm vs export 2 | 42 176 (31.29%), max delta 254 |
| export 1 vs 2 | 42 176 |
| export 2 vs 3 | **0** |

**A, A, B, B.** The first two renders agree; the rasteriser switches
once, part way through, at a point that is *not* the beginning. So it is
not a cold first render, and — since it struck the second figure of four
— it is not per-process-first either. **Both readings recorded below are
wrong.**

What survives every observation: the magnitude is **exactly 42 176
pixels** on every occurrence across eight CI runs. A noisy renderer does
not repeat a number, so two specific renderings exist and the process
moves from one to the other exactly once. What triggers the move is
**not known**, and it does not reproduce on Windows, interactively or
under `-batch`.

**The bit-identity assertion is withdrawn**, and this is the paragraph
that has to justify it. §4.6 forbids weakening a bound to make a test
pass. It does not require asserting something the platform has been
*measured not to do*. `geo.export` controls the pixel dimensions, the
route and the page it reports; those are asserted in full and exactly,
on all three exports of four separate figures. The pixel content belongs
to MATLAB's software rasteriser. **If bit-identity is ever wanted back,
it needs an explanation for the A,A,B,B first** — that sentence is in
the test as well as here.

**What this cost, and what it bought.** Eight CI cycles and no
production change at all. What it bought is a characterised platform
behaviour instead of an intermittent red square, and one more instance
of the pattern this project keeps meeting: the instrument that was built
to confirm a hypothesis is the instrument that killed it.

---

### The superseded reading, kept because the reasoning is the record

## PV-114 — closed 20-Aug-2026 (SUPERSEDED, see above). PV-104 was right about the effect and wrong about its scope.

**Resolution.** The cold render is the **process's** first rasterisation,
not each figure's. One discarded export now runs in `TestClassSetup`,
before any test in the class measures anything.

**How that was reached, and every step was a measurement.**

| step | what it showed |
|---|---|
| PV-104: 3 exports, one figure | 1v2 differs 31.29%, 2v3 exactly 0 → read as *per figure* |
| per-figure warm-up added | passed 3 checkpoints, then failed **with byte-identical numbers** |
| both pairs reported | 1v2 = 42 176 px, 2v3 = 0 — *with* the warm-up in place |
| warm-up file compared too | run went green; no diagnostic |
| **4 independent figures × 3 exports** | **all clean in one run** |

The last row is the one that decided it. If the difference were each
figure's second render, four chances would have caught it. It caught
none — so it is not per figure, and the only scope left that fits an
occurrence which is intermittent across runs while **exactly
reproducible in magnitude** (42 176 pixels, every time, on both CI
triggers) is once per process: the software GL context is built lazily
on first use, and whether that lands inside a measured comparison
depends on which suite happens to rasterise first. That is scheduling,
not geoMap.

**A noisy rasteriser does not repeat a number.** That observation is what
kept this from being written off as flakiness and tolerated with a
loosened comparison, which §4.6 forbids and which would have quietly
destroyed the determinism claim `geo.export` rests on.

**Honest residual, recorded at the fix.** This is the hypothesis that
survives the evidence, not one isolated directly — the effect has never
reproduced on Windows, interactively or under `-batch`, so it cannot be
stepped through. If the assertion fails again the hypothesis is wrong,
and the four-figure diagnostic will say how. That sentence is in the
test, not only here.

**Cost:** six CI cycles and no change to `geo.export` whatsoever. The
`drawnow` tried at PV-104 was removed when it changed nothing; nothing
replaced it.

---

### The original entry, kept because the reasoning is the record

**Status when written: OPEN, and the E.1c PR was red on it.**

`TestE0_export/repeatedExportsOfARealisedFigureAreIdentical` discards one
export to settle the figure and then compares the next two. It passed on
CI for three checkpoints and then failed with numbers **byte-identical**
to the original PV-104 measurement — which says the warm-up did not take,
not that the renderer became noisy. Rather than guess, the test was made
to report both pairs. One CI run, and the answer is unambiguous:

| pair | pixels differing |
|---|---|
| 1 v 2 | 42 176 of 134 805 — **31.2867%**, max channel delta 254 |
| 2 v 3 | **0**, exactly |

**With a discarded warm-up export already performed.** So the renders in
this test are the figure's second, third and fourth, and the *second*
still differs from the third while the third and fourth agree. PV-104
concluded the first render differs and every later one is identical; that
cannot both be true and produce this.

Two readings fit, and they are distinguishable:

1. **It takes more than one export to settle**, and PV-104's original
   "2 v 3 identical" was itself an intermittent pass.
2. **The warm-up is not running as intended** — the discarded export
   does something different from the asserted ones, or is not reaching
   the figure under test at all.

The same commit passed on the push trigger and failed on the
pull_request trigger, so it is **intermittent in occurrence while exactly
deterministic in magnitude** — the same 42 176 pixels every time it
appears. That pattern is itself evidence: a genuinely noisy rasteriser
would not repeat a number.

**Next step, and it is one cycle:** instrument the warm-up itself —
assert the discarded file exists and compare it against r1 — which
separates reading 1 from reading 2 without changing any behaviour.
Nothing about `geo.export` is being altered until that answer is in.

---

## R-020 — Stage E, checkpoint E.2, 20-Aug-2026, tier A

**Scope.** `geo.trackmap`, `geo.pointmap`, and the five internals they
share.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
431 after correcting a first prediction of 430; suite size 431,
per-class sum 431, 431 passed, 0 failed.** Green gate on all six.

| | |
|---|---|
| v1 `geoImagescTrack` | 75 options, a near-clone of a 3413-line function |
| v1 `geoImagescPoints` | 82 options, the other near-clone |
| `geo.trackmap`, executable | **17 lines** |
| `geo.pointmap`, executable | **17 lines** |
| auto-extent margin vs Pad × span | **5.55e-17** relative, bound 1e-12 |

The two fronts differ by one word. Everything they share — the extent
precedence, the background, the option split — is in one internal each,
which is the entire difference from v1: there, the same extent logic
existed twice **and the two copies disagreed about the pad.**

**Findings — three, and two are defects that would have shipped.**

| id | Finding |
|---|---|
| PV-115 | **The shipped toolbox could not find its own data.** `geo.readCoastline` located the builtin coastline with `fullfile(geoMapRoot(), "data", ...)` — and `geoMapRoot` lives in **tests/**. Measured by restoring the default path and adding only the toolbox root, which is what a user's session looks like: `geo.readCoastline("builtin")` failed with *"Unrecognized function or variable 'geoMapRoot'"*. Every test passed for as long as this existed, because the harness always has `tests/` on the path — **the shape of defect a test suite is structurally blind to unless it looks at the question directly.** `geo.internal.dataFile` now resolves from `mfilename('fullpath')`, the pattern `geo.internal.cvdColormap` already used correctly, and `geoMapRoot` joined the audit's banned list inside `+geo`. Found only because `geo.trackmap` needed a background and the shortest way to give it one was the same broken line. |
| PV-116 | **`geo.region` accepted a `Padding` it did not apply, and reported it as applied.** Padding works on an *outline*; on a 1×4 box or a preset name it was stored and ignored, while the returned field — documented *"As applied"* — carried the value that had been discarded. Measured: `geo.region([-20 40 12.7 50], Padding = 0.05)` returned those limits unchanged with `Padding = 0.05`, so `geo.trackmap`'s pad came out **exactly zero on both axes** on its first run. A box is a stated extent and is still not padded; the struct now says 0, and the help states the rule. `geo.internal.mapBackdrop` passes its two corners as the outline they are, so the toolbox has one padding rule rather than a second one written in a front. |
| PV-117 | **"Prose about a token is not the token" — the fourth occurrence, and this time in my own test.** The PV-115 regression test asserted `~contains(source, "geoMapRoot(")` and failed on `geo.readCoastline`, whose new comment *explains that `geoMapRoot` must not be used there*. PV-102 was the same thing on the `L4-FRONT` marker; `arrayGrowth` met it on the file documenting the AGROW ban; `checkPrinting` carries a comment about it. Four times, in four different instruments, written by someone who had already recorded it three times. **The pattern is not a lesson that can be learned once** — every text-level check needs its comments stripped, structurally, and that is now what this one does. |

**A missed prediction, again, and the same way.** E.2 was predicted at 20
points and came in at 21: the contract block has ten methods, not nine.
That is the second consecutive checkpoint miscounted in the same
direction and in the same block. Counting by reading is the part that
fails; the reconcile is what catches it.

---

## R-021 — Stage E, checkpoint E.3, 20-Aug-2026, tier A

**Scope.** `geo.series`, the L3 element a time series needed, and
`geo.timeseries`, the front that stacks them.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
450; suite size 450, per-class sum 450, 450 passed, 0 failed.** Green
gate on all six. **The prediction was counted mechanically this time and
was right** — after two consecutive misses from counting by reading.

| | measured | bound |
|---|---|---|
| stacked ordinate vs Obs + the reported offset | **0** | ≤ 0 |
| stack spacing vs the reported Spacing | **0** | ≤ 1e-12 |

Both are exact, and the first is the one that matters: a stacked plot is
read by **subtracting the offsets by eye**, so a plot whose offsets were
not exactly what it reported would be wrong in a way no reader could
detect.

**The rule fired a third time, and the answer was the same.**
`geo.timeseries` is a front, a front draws nothing, and nothing drew a
series — so `geo.series` was written rather than the plotting inlined,
exactly as `geo.title` was at E.1a. The **reference lines go through the
same element**, because a horizontal line at a constant value over the
time span *is* a series; treating it as one is why there is no second
line-drawing path in the front.

**Findings — three.**

| id | Finding |
|---|---|
| PV-118 | **Filling `Outline` for boxes made `geo.splitTracks`' fast rectangle test unreachable.** PV-109 gave every region vertices, which is what a drawer needs — and the region filter keys on `Outline` being *empty* to choose between four comparisons and a point-in-polygon. Every rectangle silently started going through `inpolygon`: same answer, more slowly, nothing to say it had happened. `geo.region` now carries `IsBox`, so **`Outline` says what to DRAW and `IsBox` says what to TEST against**. A fix that makes a branch dead is a fix that needs looking at twice. |
| PV-119 | **`geo.quantile` could not do the one thing its help promises.** *"Z any size; treated as a flat collection"* — and `geo.quantile(Z(:), [5 95])`, a matrix and two percentages, **raised** *"number of elements must not change"*. `Z(isfinite(Z))` is a column whenever Z is a matrix or a column; indexing a column with a row index returns a column; so `v(lo)` was (2,1) while `(h - lo)` was (1,2), implicit expansion silently built a **2×2**, and the final reshape failed. It never showed because **every existing caller passes a scalar p**, where the expansion is 1×1 and invisible. A documented contract that held only for the shapes its own callers happened to use. Both sides are forced to columns now and the shape of `p` is restored at the end. |
| PV-120 | **F6 for the SIXTH time**, and PV-099 with it. A four-line `keep` helper was identical in `TestE2_dataMaps` and `TestE3_series`; the duplicate-local check rejected the second copy inside the checkpoint that wrote it. Promoting it to `GeoMapTestCase` required removing **both** private copies, not one — PV-099 recorded that a base-class method colliding with a suite's private one makes the framework **drop that suite** and report it as a warning. Six rejections, every one inside the round that wrote it, against v1's six duplicated locals shipped for four years. |

**Two smaller things worth the ink.** The default stack spacing is the
**median** of the per-station 5–95 ranges, not the maximum: v1 used the
maximum, so one noisy station pushed every trace apart and the quiet ones
became flat lines — asserted here by adding a station ten times noisier
and requiring the spacing not to triple. And the series colours come from
**viridis in stack order** rather than an invented qualitative palette,
because a palette is data and data belongs in `geo.colormaps` with its
provenance, not as a literal inside a front.

**One narrow distinction, stated rather than inferred.**
`geo.timeseries` writes `axH.YLabel.String` and `axH.Title.String`
directly. That is *configuration* of objects the axes already owns — no
graphics object is created, exactly as with `XLim`. Calling `ylabel()`
would create one, which is why `ylabel` is on the audit's banned list and
this is not.

---

## R-022 — Stage E, checkpoint E.4, 20-Aug-2026, tier A. **STAGE E CLOSES.**

**Scope.** `geo.panel`, the last of the six fronts.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
468; suite size 468, per-class sum 468, 468 passed, 0 failed.** Green
gate on all six. Prediction counted mechanically and correct, twice
running.

| | measured | bound |
|---|---|---|
| panel map plotted heights, spread over three tiles | **0** | ≤ 0.02 |
| series plot-box height vs the map's plotted height | **4.86e-16** | ≤ 1e-12 |

The 2% is **v1's own criterion, carried forward deliberately and not
tightened**. It is a visual-equality threshold — the point at which a
reader stops seeing two panels as the same size — and tightening it to
look rigorous would have replaced a meaningful number with a
meaningless one.

**The constraint that shapes this file.** A map axes uses `axis equal`
and fills only a centred sub-rectangle of its tile; a series axes fills
the whole tile, so two equal tiles look like two different heights. The
obvious repair is unavailable: **`tiledlayout` forbids setting
`Position` on its children — the assignment warns and is ignored**, so
the fix appears to work and changes nothing. v1 found this and reshaped
the axes with `PlotBoxAspectRatio` instead. That workaround is carried
forward rather than rediscovered, its constraint is written at the code,
and `TestE4_panel` exists partly to stop someone "fixing" it back.

**Findings — two.**

| id | Finding |
|---|---|
| PV-121 | **`geo.map`'s `Parent` option was declared, documented, and never read.** `geo.map(G, crs, Parent = ax)` drew a whole **new figure** and left the axes it was handed untouched. It surfaced only when `geo.panel` needed to draw into a tile. **The E.1a test that should have caught it passed for the wrong reason**: it drew twice with `Parent` and asserted the first axes' child count had not grown — trivially true when the second call goes to a different figure entirely. An assertion that cannot distinguish "reused the axes" from "ignored the argument" tests neither. The test now asserts the axes identity and the figure count first. |
| PV-122 | **F6 for the SEVENTH time, and the copies had drifted.** The Stage E purity self-check had accumulated four near-copies, one per front suite; the duplicate-local check rejected the fourth. Worse than the duplication: E1's and E2's banned lists were **shorter** than E3's and E4's, so `geo.map`, `geo.trackmap` and `geo.pointmap` were never checked for `ylabel`, `xlabel`, `legend` or `sgtitle`. Promoted to `GeoMapTestCase.verifyIsAPureFront`, one list, every front held to all of it. **A duplicated check does not merely repeat work — it decays into checking different things under the same name.** |

**PV-077 recurred a fourth time** — `verifyEqual(a, b, AbsTol = t,
'diagnostic')`. Four checkpoints, four occurrences, one suite load lost
each time.

**`geo.panel` used 197 of its 200 executable lines**, and that is worth
recording rather than rounding off: it is the only front that came close
to the budget, which is a fair signal that a panel is the most a front
should be asked to do.

**One thing left out rather than improvised.** There are **no panel
labels** — (a), (b), (c). A corner annotation is not a title and no L3
element draws one, so the Stage E rule says flag it, and it is flagged in
`geo.panel`'s LIMITATIONS. The letter goes in each tile's own Title
meanwhile.

---

## Stage E, complete

| | |
|---|---|
| fronts | `map`, `trackmap`, `pointmap`, `timeseries`, `panel`, and `export` as the L4 utility |
| elements added because the rule demanded them | `geo.title`, `geo.series` |
| v1 code replaced | `geoImagesc` 3413 lines, `geoImagescTrack` 75 options, `geoImagescPoints` 82, `geoImagescTimeSeries`, `geoImagescMulti` |
| `geo.map`, executable | **128** lines |
| `geo.trackmap` / `geo.pointmap` | **17** lines each |
| `geo.panel` | **197** lines, the only one near the budget |
| suite | 468 points |
| V9 | discharged at E.1c |

**The rule bit four times and was right four times** — a title, a region
outline (wrongly, and withdrawn), a series, and panel labels (still
open). Not one of them was inlined.

---

## R-023 — Stage F, checkpoint F.1, 20-Aug-2026, tier A

**Scope.** `tests/TestIntegration.m`, `Contents.m` as the version and
catalogue authority, and `tests/TestContentsConsistency.m`.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
477; suite size 477, per-class sum 477, 476 passed, 1 filtered.** Green
gate on all six. Also green on `glnxa64` CI — which for this checkpoint
found something Windows could not.

| id | Finding |
|---|---|
| PV-123 | **The toolbox-presence guard did not guard, on the only configuration it existed for.** `geo.export` decided whether the parallel path was available with `exist('parfeval','file') > 0 && exist('gcp','file') > 0`. On CI, which has **no Parallel Computing Toolbox**, that expression is **true** — MATLAB ships dispatch stubs and help files for toolboxes it does not have, and `exist(name,'file')` answers a question about the file system, not about whether a function can be CALLED. So the short circuit never fired, `gcp` was called, and the run died with *"Undefined function 'gcp' for input arguments of type 'char'"* instead of raising `geo:export:NoParallel` with its explanation. **A guard written to produce a helpful error produced an unhelpful one, precisely where it mattered.** The same expression had been copied into the integration test's `assumeTrue`, so the test errored rather than filtering. Replaced by `geo.internal.hasParallelPool`, which **tries the call** and treats any failure as "no" — the one place where swallowing an error is right, because the question being asked *is* whether the error happens. |

**Why Windows could not find this.** This machine has the toolbox
licensed, so both `exist` calls and the `gcp` call all succeeded and the
guard looked correct for the entire life of `geo.export`. The defect is
only reachable from a machine without PCT, and the project has exactly
one of those: CI. That is the argument for running the gates somewhere
other than the developer's own box, stated as a measurement rather than
as a principle.

**The version now carries the evidence.** `Contents.m` reads
`Version 2.0.476-alpha.1`, and the patch component **is** the verified
test-point count. It moves when the evidence moves: a pure rename bumps
nothing, and a checkpoint bumps it by exactly what its tests added.
`CITATION.cff` is checked against it, never maintained beside it.

**The central guarantee is now a test.** `composedEqualsFront` builds one
map with `geo.map` and the same map by hand from `geo.basemap` plus
elements in z-order, and requires **identical surface CData, identical
`clim`, and the same registered elements**. Without it, "L4 orchestrates
L3" is a diagram rather than a fact — every other suite tests one
function against its own contract and none of them can see this.

**The catalogue is checked character for character.** Every `geo.*` row
in `Contents.m` must equal that function's H1 line exactly. A summary
that paraphrases is a second description of the same thing — F6 applied
to prose — and it drifts invisibly, because both halves read plausibly.
All 42 public functions are listed, grouped by layer, and the grouping
is asserted to cover them.

**The parallel scenario was proved, not merely filtered.** It carries an
`assumeTrue` on a live pool, so it filters on CI and in a plain session —
and a test never seen to pass is not evidence. A pool was started once
by hand: **3 of 3 passed**, with the workers' images byte-identical to
the serial path. Then the pool was closed so the confirming run matches
CI.

**Two things labelled rather than dressed up.**

The GRACE-style export scenario is a **smoke test** and says so in its
own comments: it proves the whole stack runs together and writes a real
17 cm PDF over 10 kB with every expected element present. It does not
prove the figure is right. There is no automated oracle for "the figure
is right" and pretending otherwise would be worse than saying so.

**O11 is carried, not faked.** Checking sign, magnitude and pattern over
Greenland, West Antarctica and north India against a published GRACE
mascon product needs a named release and its data file. The scenario uses
a clearly synthetic anomaly field, labelled as synthetic in the code, and
the debt stays open. A plausible-looking number invented here would be
indistinguishable from a real one, which is exactly the failure the
oracle register exists to prevent.

---

## R-024 — Stage F, checkpoint F.2, 20-Aug-2026, tier A

**Scope.** `docbuild/build_help.m`, `info.xml`, the generated
`helptoc.xml`, `geoMapSetup.m`, and `tests/TestF2_docbuild.m`.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
487; suite size 487, per-class sum 487, 486 passed, 1 filtered.** Green
gate on all six. Version moved to `2.0.487-alpha.1` in the same edit.

**The manual, counted in the artefact:**

| | |
|---|---|
| functions rendered | **43** |
| arguments documented | **398** |
| arguments **found in the written HTML** | **398** |
| completeness | **100%** |
| broken See-also links | **0** |
| examples that do not parse | **0** |
| required headers missing | **0** |
| pages | 46, 284 kB |

**Rendered is the number that can be wrong**, and that is the whole
design. A reference project parsed argument descriptions into its
documentation model for years while the renderer never read the field;
every audit stayed green because there was no text anywhere to disagree
with (F1). So each page is **read back off disk** and every documented
name is counted where it actually appears, inside a table cell. A
builder reporting 398 of 398 from its own parse tree would be reporting
on its parser.

**Findings — three, and all three were in the instrument.**

| id | Finding |
|---|---|
| PV-124 | **The See-also resolver deleted the dot inside every package name.** Written as `erase(txt, ".")` to strip the trailing full stop, it turned `GEO.COASTLINE` into `GEOCOASTLINE` — so the first clean build reported **117 broken cross-references**, every one of them a link that was fine. A link checker whose first act is to corrupt the link it is checking will report a catastrophe and be believed, because 117 looks like a real problem. Only the trailing stop is stripped now. |
| PV-125 | **A parser with no terminator reads until it runs out, and what it reads last is whatever happens to be there.** The `See also` section had no end marker, so it swallowed the version footer, and the resolver then handed `"Claude Opus 5 (Anthropic)"` to `which` — which tries *command syntax* on anything that is not a valid name and **raises**. The build died. Two fixes, both needed: the `%   ------` separator now ends the help block, and `resolvesToAFunction` validates the name before asking. **A resolver that can be made to throw by the text it is resolving is not a resolver.** |
| PV-126 | **The path list existed in SIX places, and adding a folder broke the seventh.** `.github/workflows/ci.yml` once, `tools/gates.sh` twice, `buildfile.m` three times. Adding `docbuild/` made the new tests pass locally and they would have failed on CI, because the copies have no way of learning about each other — **F6 in the one part of the project the duplicate-local check cannot see, since two of the copies are not MATLAB**. `geoMapSetup.m` is now the one list. The scratch runner used for every confirming run in this project turned out to be a seventh copy, and it failed on the very next run — which is how the count came back 476 + 10 + 11 against a suite of 487 and the reconcile refused to add up. |
| PV-127 | **`geo.cache` called `sha256OfText` out of `tools/`, so every installed copy of the toolbox raised `Undefined function 'sha256OfText'` the first time it drew a coastline.** Reported by the user running `GettingStarted` in his own MATLAB; reproduced here in one command by `restoredefaultpath; addpath(root)`. **The severity is not the missing file, it is that no gate in this project could see it.** `geoMapSetup` puts `tools/` on the path, so all 489 points passed, the audit was clean and both CI legs were green — while the `.mltbx` ships `+geo`, `data` and `docs/html` and nothing else. **Green CI was never evidence about the thing that ships, because CI never runs the thing that ships.** |
| PV-128 | **PV-115's fix is why PV-127 survived eleven checkpoints.** PV-115 was the same defect — `geo.readGrid` reaching for `geoMapRoot` — and I fixed it by adding one name to the audit's `banned` list. A name-list can only forbid the instances somebody already thought of, and it reads as protection against the whole class while covering one member of it. `sha256OfText` sat one line below in the same package for eleven checkpoints underneath that "fix". **A check that enumerates instances of a rule should be read as an admission that the rule was never stated.** `geoMapRoot` has been removed from `banned` and the rule is now stated once, in `packageClosure`. |
| PV-129 | **The v1 tree is gone from disk.** `C:\Users\matth\Documents\MATLAB\maptoolbox_v1` no longer exists, so oracle O12 is permanently unreachable on this machine and four tests that passed on 20-Aug-2026 now filter loudly. Not a defect — OB-7 released v1 at Stage F, and the tests report filtered rather than passed, which is the behaviour they were built for. Recorded because the **evidence base changed**: the v1 defect register F1–F18 and the option inventory are now frozen as previously-measured results and cannot be re-measured here. Any future claim about what v1 did must cite the recorded measurement, not a fresh probe. **Five filtered is the new normal count**, not one. |

**The reconcile earned its place again.** An errored test counts as both
failed and incomplete, so the sum **exceeded** the suite size — 497
against 487. That inequality is itself a signal: it says "these tests did
not merely fail, they did not run", which is a different diagnosis and
points at the environment rather than the assertions.

**What the manual contains.** Per-function pages with typed input,
option and output tables, a highlighted ACCURACY block, errors as a
definition list, a linted example and resolved links; an index grouped by
layer; a projection guide; and a GRACE workflow. The index, the Help
browser TOC and `Contents.m` all come from **one grouping**, read out of
`Contents.m`, so no two of them can disagree.

**The guide says the thing that matters.** Asserted by test: the
projection guide must contain the word `SPHERE`, the figure `0.3%`, and
the phrase `not a survey tool`. A projection guide that omitted those
would invite someone to survey with a visualisation tool.

---

## R-025 — Stage F, checkpoint F.3, 20-Aug-2026, tier A

**Scope.** The documentation sync gate, `GettingStarted.m`, the README
migration table, `geoMap.prj` and the v2.0.0 `CHANGELOG`.

**Confirming run.** `win64 | R2026a Update 4 | 16 threads`. **Predicted
489; suite size 489, per-class sum 489, 488 passed, 1 filtered.** Green
gate on all six. Audit: **14 checks, 16 fixtures, every check proved.**
Version `2.0.489-alpha.1` across `Contents.m`, `CITATION.cff`,
`geoMap.prj` and the README in one edit.

**A documentation page does not rot loudly.** It was correct when it was
built, it still renders, it still reads well, and it describes a function
that has since changed. Nothing in a test suite notices, because the page
is not code and the help is not executed. The only thing that can notice
is a comparison between the page and the source it came from — and prose
cannot be compared to prose.

So `build_help` embeds the **SHA-256 of the help block each page was
built from**, whitespace-normalised so reflowing a paragraph is not a
content change, and the audit's fourteenth check recomputes it. Proved by
direct fault injection: corrupting one page's hash produced *"geo.title's
help has changed since its page was built"*, and restoring it returned
the tree to clean.

**The absence of the manual is not a finding**, and that is deliberate.
`docs/html` is a build artefact; a fresh clone that has not run the
builder has no pages to be stale. Reporting that as a defect would train
people to ignore the check. It reports only **disagreement**.

**The changelog cites a probe result for every defect it claims to fix.**
All eighteen F-numbers, each with the measurement: 32 `range()` sites not
~15; Robinson returning 5.293 where ≈ −0.0148 was correct; Mercator's
y(87°) − y(85°) = exactly 0; the type-7 quantile of `[1 2]` being 1.5
where v1 gave 1.0. **F17 is listed as `blocked`, not fixed** — it needs
oracle O6, a real GSHHG binary, and a defect claimed fixed that never
reproduced is not a fix. **F16's illustration is corrected against its
own measurement**: the handover said "3 or 11 lines"; the measured worst
is 10, so the defect reproduces and the illustration does not.

**Known gaps are in the changelog, not only in the records** — O11 and O6
unfilled, no panel labels, and the export pixel content measured not to
be reproducible on software OpenGL. A release note that lists only what
works is an advertisement.

**`geoMap.prj` excludes everything that verifies the toolbox** and
nothing it needs to run: `tests/`, `tools/`, `records/`, `mirror/`,
`docbuild/`, the handover and the records. A user installing this gets
the code, its data and its manual.

---

## R-026 — Stage F, checkpoint F.4, 21-Aug-2026, tier B (sandbox) + CI

**Scope.** No cartography. One finding about the document set, the check
that now catches it, and the re-synchronisation of `HANDOVER.md`
Parts 0 and 1 with the evidence already sitting in this file.

**Execution tier, declared first (OB-1).** **Tier B in the authoring
session** — no MATLAB bridge and no filesystem access to the target
machine were available this round. What the session *did* have was `git`
and the GitHub API, so gates 1–3 ran here and gate 4 was delegated to CI,
which provisions R2026a on a hosted runner. **That is a tier refinement
worth recording: the MATLAB leg does not require Matthias's desktop.** An
authoring session with only network access can still execute the suite,
by pushing a branch and reading the run. The desktop bridge remains the
faster loop; it is no longer the only one.

**What ran, and what did not.**

| gate | where | result |
|---|---|---|
| 1 `mcheck` | sandbox | self-test PASS, **111 files, 0 problems** |
| 2 `provenance_audit` | sandbox | self-test PASS, **0 problems**, 0 PROVISIONAL stamps |
| 3 mirror + frozen acceptance | sandbox | **74 criteria, 0 breaches**; PROJ **9.5.1** via pyproj 3.7.2, numpy 2.4.4, scipy 1.17.1 — the same PROJ the measurements were taken against, so O4 is reproducible off the target machine |
| 3a `gdal_oracle` | sandbox | ctypes route, GDAL 3.12.4, slope error **3.58e-06°**, aspect **5.92e-06°** |
| 4 MATLAB suite + audit | **CI** | see the run linked from the PR |

**PV-130 — the status file had no status in it.** Between 16-Aug and
20-Aug, Stages D, E and F.1–F.3 were built, executed and merged.
Fourteen entries were added to this file and seventy rows to the change
log. **Part 1 of the handover was not touched.** Opening `HANDOVER.md`
this morning, a fresh session read: Stage 0 *in progress*, Stages D, E
and F *not started*.

Measured, by the check written below, against the tree at `3bdfb87`:

**seven disagreements** — three stages carrying records entries while
the ledger called them not started; one checkpoint likewise; and debts
**V4, V7 and V9** printed as open in Part 0 while this file declared all
three discharged.

Nothing was red. Every gate in the project looks at code, and no gate
looked at the document set. The failure is BEST_PRACTICE §6.1 **run
backwards**: the split exists so that narrative evidence does not crowd
out status, and what happened instead is that the evidence file grew a
status and the status file kept none. The cost is not cosmetic — a debt
recorded as open is re-discharged by the next reader, and V4, V7 and V9
were each discharged with a real measurement that would have been paid
for twice.

**PV-131 — a round closed without an entry here.** The PV-127/128/129
round (commit `3bdfb87`, 20-Aug) reports its green gate in the **commit
message**: 491 points reconciled three ways, 486 passed, 5 filtered, 0
failures, 0 audit findings, manifest verified. There is no entry in this
file for it. **No entry is fabricated here**, because the run was not
witnessed by this session; the numbers above are cited as the commit's
own claim and marked as such. If the next bridge session re-runs the
suite on the target machine, that run gets the entry.

**The instrument: `tools/ledger_sync.py`.** Five rules, stated as rules
rather than as a list of stage names — PV-128's lesson, that a name-list
forbids only the instances somebody thought of:

1. a stage with a records entry is not "not started";
2. a debt the records call discharged is not left un-annotated in Part 0;
3. a checkpoint with a records entry is not left unticked;
4. a stage marked done cites a records entry;
5. a records entry the ledger cites exists.

It is **static and runtime-free**, and that is the point rather than a
convenience: it is a check on the documents, and the documents drift
hardest in exactly the sessions where MATLAB is not reachable. It joins
the first CI job and `tools/gates.sh`, and like `mcheck` and
`provenance_audit` it refuses to report a clean tree unless its own
fault-injection self-test passes in the same invocation — six fixtures,
one per rule plus a false-positive fixture on an agreeing pair.

**Rule 5 was added because this round needed it.** Revision 3.1's first
draft cited `R-026` in the ledger before this entry existed. Rules 1–4
all read from records to ledger; none of them can see a citation pointing
at nothing. The check caught its author within the same hour it was
written, which is the only kind of evidence a new check has to offer.

**What Part 1 says now.** Stage 0 ☑ (36 points, 15-Aug), A ☑ (113), B ☑
(182), C ☑ (205), D ☑ (**347**, 16-Aug, seven checkpoints), E ☑
(**468**, 20-Aug, seven checkpoints), F ◐ — deliverables 1–9 executed,
**10 (release checklist), 11 (this file's final state) and 12 (the
independent audit) open**. The planned checkpoint names are replaced by
the delivered ones: D ran as seven where three were planned, E as seven
where one was. A checkpoint was cut whenever a confirming run was owed,
which is the rule working, not drift to be tidied away.

**Obligations moved.** OB-3 closes with V3. **OB-7 is broken and is not
quietly dropped**: the v1 tree is gone from the target machine, so oracle
O12 is unreachable and four tests now filter loudly rather than pass
(PV-129, five filtered is the new normal). Restoring v1 before the
independent audit would return them; leaving it broken is a decision that
belongs to Matthias, not to this session.

**Binding items a later stage could be wrong for not reading.**

- **The independent audit (deliverable 12) has not run, and this round is
  not it.** Its rules say: its own session, findings only, no deference to
  a green gate, fix nothing until agreed. This round fixed things, which
  disqualifies it as the audit by construction.
- **Release checklist items that need a human and a live MATLAB remain
  open**: `.mltbx` installs in a fresh MATLAB with `doc geoMap`
  resolving, and the rendered manual rasterised and *looked at*. There is
  no automated oracle for "the figure is right".
- **O11 is still unfilled.** The GRACE integration scenario uses a field
  labelled synthetic in the code, deliberately.
- The version did not move this round, and correctly so: the patch
  component is the verified test-point count, and no MATLAB test point
  was added.

---

## R-027 — Stage F, checkpoint F.5, 21-Aug-2026, tier B (sandbox) + CI

**Scope.** Two defects reported from `GettingStarted.m` — a frame that
collapsed to a triangle, and a coastline outside the frame — and the
three findings that came out from under them.

**Execution tier.** Tier B in the authoring session; every MATLAB claim
below was executed on CI. Confirming run **32524023441**: predicted 504,
suite size 504, per-class sum 504, **480 passed, 0 failed, 24 filtered**,
green gate on all six, audit 0 findings. The 24 are A-6 and unrelated.

**PV-135 — the frame band had no width at a point pole.** mollweide,
hammer and sinusoidal map the pole to a POINT, so all thirteen vertices
of the boundary's top edge project to one place, `outwardNormals` hit
its coincident-vertex guard, and the ribbon offset by zero.

| projection | distinct images of the +90 edge | zero mitres |
|---|---|---|
| mollweide | **1** | 26 |
| hammer | **1** | 26 |
| sinusoidal | **1** | 26 |
| robinson | 13 | 0 |
| winkeltripel | 13 | 0 |

Coincident runs are collapsed to their LAST member before the normals
are taken — the survivor's outgoing edge is the real one. Visible band
count identical in every case, zero skipped edges, colour phase kept.
The old coincidence guard was an absolute `1e-12` on a projected
coordinate, which is a claim about units; measured, degenerate
separations sit at **5e-18** of the map diagonal and the smallest
legitimate edge at **2.8e-2**, sixteen orders apart, so the tolerance is
now `1e-9 x diagonal`.

**PV-136 — the coastline was clipped to the domain, never to the
extent.** `geo.coastline` discarded `elementExtent`'s second and third
outputs while `geo.graticule`, four lines away, kept them. On the
`GettingStarted` track map, **486 029 km of 529 498 — 91.8% — of the
drawn coastline lay outside the frame**. Ten crossing segments in the
whole figure; a naive vertex mask UNDERSHOOTS, leaving a 108 km ≈ 12 px
gap, so each crossing is bisected in lon/lat: 0.256 km at n=8,
**0.0016 km — 0.0002 px — at n=16**.

**PV-137 — membership belongs in lon/lat, not in a projected ring.**
`inpolygon` against the boundary ring has no answer where the ring does
not exist, and an orthographic hemisphere shows a global extent every
time. It threw, and took fourteen `TestE1_map` tests with it. The extent
test moved to lon/lat plus domain-finiteness: the two agree wherever the
projection is continuous and injective, and only one of them can fail to
exist. `mapBoundary` reports `Complete = false` rather than raising.

**PV-140 — registration, and it is not this project's invention.** GMT
calls it gridline versus pixel and defaults to gridline; MATLAB's
Mapping Toolbox calls it postings versus cells; GDAL carries it in the
geotransform. **GMT's own maintainers considered and rejected the repair
this project was heading for** — adding a repeating column per module —
as messy and not a good solution (GMT issue 4440). The concept was
missing here and its absence was the antimeridian wedge.

Measured before anything was written:

| | |
|---|---|
| flat shading, one face, four candidate colours | `CData(1,1)` **100%**, the other three **0** |
| edge-drawn, 2×2 cells on 3×3 vertices | four quarters, 24.7 / 24.7 / 25.8 / 24.7% |

So the last row and column were never painted and every cell sat half a
step from where its value belonged.

| axis | nodes | inferred | region span |
|---|---|---|---|
| `-180:20:180` | 19 | posting | 360.0000 |
| `-170:20:170` | 18 | cell | 360.0000 |
| `0:20:340` | 18 | cell | 360.0000 |
| `-179.5:1:179.5` | 360 | cell | 360.0000 |
| `0:2:40` | 21 | posting | 40.0000 |

**A wrong claim, withdrawn and then re-established, and the middle step
is the one worth keeping.** The lost column was first asserted from
memory. A differential probe then appeared to REFUTE it — 57 600 pixels
changed when the last element moved — and it was withdrawn to Matthias
as refuted. Both steps were wrong: those pixels were the HILLSHADE of
the neighbouring cells, not the cell. **A green measurement gave a false
clear**, and it was reported as fact before a probe isolated the face
from its shading.

**PV-141 — defined is not drawable.** Lambert azimuthal equal-area's
forward projection is defined at the antipode; the antipode maps to the
whole BOUNDARY CIRCLE, so a line crossing it lands a full diameter
apart and densification converges on a diameter rather than on zero.
Named by probe rather than left as a max over sixteen:

| projection | worst graticule segment |
|---|---|
| equirectangular | 0.003494 |
| thirteen others | ≤ 0.005 |
| **lambert** | **0.707959** |

Clipped at 179.5°, the azimuthal branch cut — the exact analogue of the
antimeridian on a cylinder, and the reason azimuthal equidistant already
stops at 178. **Not a regression from PV-140**: the toolbox has never
been able to draw that meridian, and no graticule tick had landed on it
because the extent stopped one cell short of the world.

**Findings the CHECKS caught, not a human.**

| check | what it caught |
|---|---|
| `identifierAgreement` | `geo:mapBoundary:Degenerate` still documented after its throw became a report; `geo:grid:RegistrationAmbiguous` raised and documented nowhere |
| `codeAnalyzer` FVSOR | `options.Window` declared without `options` on the function line, twice |
| `codeAnalyzer` FVAPN | name=value before a positional argument, twice, in two files |
| `packageClosure`, `ledger_sync` | clean throughout |

**FVAPN cost two round trips, so it became a check.** `mcheck` now
carries it. Written three times: 11 false positives (a comparison read
as a pair), then 3 (a braced value split on its own comma), then none —
and each failure mode is a self-test fixture, because a check that cries
on valid source teaches people to ignore it.

**Tests re-derived, never loosened.** Six: the densification invariant
(a clip both drops and inserts points, so the old identity became false
for an honest reason, and is now asserted where it still holds
unchanged); the hillshade bit-identity (made against the part of `CData`
that holds values, with the pad's size asserted separately); the tick
count (`worldGrid`'s region always ran −180…180; now the extent says
so); the two `LonClosesTurn` assertions; and the domain probe point,
which chose `clip + 1` and so assumed the clip was a degree short of the
antipode.

**Two fixtures were wrong, not the code.** `registrationIsInferredFrom
TheAxisItself` paired four longitude axes with one latitude axis, so
three legitimately raised `RegistrationAmbiguous` — the check working.
`smallGrid` stops at 80° and `demoGrid` at 87.5°, so neither could reach
PV-135 at all; `poleToPoleGrid` was added because a fixture that cannot
reach a defect is a test that cannot see it.

**Binding items a later stage could be wrong for not reading.**

- **`geo.overlayContours`, `overlayTrack`, `overlayPoints` and `stipple`
  all discard the extent exactly as `geo.coastline` did.** They are not
  fixed here. The coastline is simply the element that always covers the
  whole world, which is why it is where the defect surfaced.
- **`overlayPolygons` needs more than a cut**: a filled polygon clipped
  without closing along the boundary renders wrongly, and closing it
  needs the ring PV-137 showed does not always exist.
- The worst graticule segment reads **0.00499838 against 0.005**. That
  margin is the densifier stopping exactly at target, by design, not a
  budget nearly missed.
- `NumParts` rises on a regional map. Approved 21-Aug-2026.
**Scope.** Audit finding **A-1** only. A-2 to A-5 are untouched and remain open.

**Execution tier.** Tier B in the authoring session; the confirming run is CI.

**The remedy was pre-validated before it was written.** The design routes
an unregistered filter reason through `warning` and lets the existing
warning inventory carry the alarm, which rests on one mechanism nobody
had tested: `WarningInventoryPlugin` clears `lastwarn`, runs the test and
reads `lastwarn` afterwards, and whether a warning raised immediately
*before* `assumeFail` survives the framework catching the
`AssumptionFailedException` is a claim about MATLAB, not about this code.
**Probe A-1b, CI run 32494985310:** the inventory held both
`geo:probe:UnregisteredFilter` (filtered test) and `geo:probe:PlainWarning`
(passing test). The design holds. Had it not, the warning would have been
cosmetic and the remedy would have had to read the incomplete results
directly.

**Why the reason and not the count.** A bound (`nInc <= 5`) is an
absolute figure with no baseline — the thing BEST_PRACTICE §3.4.1 threw
out for all nineteen speed budgets — and it permits silent drift up to
itself, with the cheapest repair on red being to raise it. The count is
reported in the reconciliation block and predicted before the run, like
every other count here. **The reasons are gated**, through the alarm that
already existed: nothing was added to the six gate conditions.

**Measured this round, and invisible before it:**

| | filtered |
|---|---|
| CI (`ubuntu-latest`, R2026a) | **24** of 491 |
| bridge (`win64`, R2026a Update 4) | **5** of 491 |

**Nineteen points run on one machine and not on the other**, in a tree
that is green on both. That number had never been compared, because
nothing reported it per reason.

**Delivered.** `tests/FILTERS.md` (nine reasons, each with what closes
it); `GeoMapTestCase.filterBecause`; eleven filter sites migrated so that
`assumeFail` and `assumeTrue` no longer appear outside the base class;
`readFilterRegistry` and `reportFilters` in the runner; `speedOk`
three-state, read from the suite rather than from the records it happened
to leave; the banner reserving *green gate* for `rungeoMapTests("all")`.

**Predicted before the run: 491 points, unchanged.** No test was added or
removed — the change is to the instrument, not to what it measures. If
the number moves, the change was not the change intended.

**Binding items a later stage could be wrong for not reading.**

- **`geo:filter:v1TreeAbsent` is registered as expected on CI and as a
  breach of OB-7 on the bridge.** The registry records the difference; it
  does not resolve it. Restoring v1 is still Matthias's decision.
- **A-2 is not closed and touches this work.** `geo:filter:mirrorUnavailable`
  guards a reference that is a committed artefact rather than the live
  oracle. Registering the filter reason says nothing about that.
- The version does not move: the patch component is the verified
  test-point count and the count is unchanged.

---

## R-028 — Stage F, checkpoint F.5b, 21/22-Aug-2026, tier B (sandbox) + CI

**Scope.** The independent audit's six findings, discharged. Deliverable
12 ran at F.4 and produced A-1 … A-6; this entry records what closing
them cost and what closing them found.

**Execution tier.** Tier B authoring, every MATLAB claim executed on CI.

| finding | severity | closed by | confirming run |
|---|---|---|---|
| A-6 the suite that runs is host-dependent | High | #32 | 32531236585, 492 + 0 + 17 |
| A-1 the gate does not bound how much ran | High | #33 | 32532648516, 492 + 0 + 17 |
| A-3 no layer range-checks latitude | Med-High | #34 | 32535991602, 496 + 0 + 17 |
| A-2 the reference tier asserts against an artefact | Med-High | #35 | green, 4 registered drifts |
| A-4 / A-5 the audit's tail | Low / Low | #36 | 32540976617, 497 + 0 + 17 |

**A-6 first, and the order mattered.** The fixtures change seven of the
answers A-1's register records, so a registry written before them would
have been stale on arrival. **The finding under the finding: the "not
redistributable" claim that had kept eighteen CI points filtered for
four rounds was READ, NOT CHECKED, and is false** — GSHHG has been LGPL
since v2.2.2 and Natural Earth is public domain. That is debt V1's
failure mode in prose rather than in a number. 908 kB ships; two of the
three files are byte-exact prefixes cut at a record boundary and
re-parsed to prove the cut is clean, and `dataFile` prefers the pool
because a whole-product count asserted against a prefix measures the
fixture rather than the reader.

**A-1 was closed by adding nothing to the gate.** `filterBecause` raises
a warning carrying a registered id and then filters; the warning
inventory, which already fails on any unregistered identifier, does the
rest. Measured before: `GEOMAP_SKIP_SPEED` set, **42 of 491 points did
not run and the gate printed PASS**. The count is reported and the
REASON is gated, because the correct count is a property of the host —
CI filtered 24 where the bridge filtered 5, with no instrument saying so.

**A-1's pre-validation refuted its own design.** A `QualifyingPlugin`
subclass overriding `assumptionFailed` captured **zero events** over a
full suite — the obvious analogy to `WarningInventoryPlugin`, and dead.
Written from that analogy the inventory would have shipped capturing
nothing and calling every run clean.

**A-3 found a defect in the suite on its first run.**
`validationNeverTouchesTheData` built its 2161×4321 grid from
`lat = 1:2161` — indices standing in for coordinates. A latitude cannot
be 2161. The guard refused it, correctly, in a test that had been green
for weeks.

**A-2's gate found two classes the sandbox could not show.** `/values/*/route`
moving `ctypes` → `cli`, and two round-trip maxima moving at 1e-16 and
1e-13. Neither is reachable where the route never changes and the libm
is the one the committed file was written on. A **register**, not a
tolerance: one global tolerance would have to be as loose as the
mass-closure floor's 8.3e-1 and would then wave through a projection
value that had moved by a factor of two.

**A-5's first repair refused a legitimate answer.** It went red on
`TestIntegration`, and `TestIntegration` was right: an integration
scenario covers no single function, and claiming one would promise all
seven categories for it in the wrong suite. The finding stood — an
omission and a decision were indistinguishable — but forbidding the
omission without letting the decision be stated just moves the error. An
empty `CoveredFunctions` is now a reported decision; an absent one is a
finding.

**Binding items a later stage could be wrong for not reading.**

- **A-6 is reduced, not closed.** Sixteen points still run on one host
  and not the other. The gap is now named per reason rather than being a
  fact about a drive letter.
- **Nothing forbids a bare `assume*` outside `filterBecause`.** The
  registry can be bypassed by the next test written, which is PV-128's
  lesson pointed at A-1's own fix. It wants an audit check.
- **`mcheck` gained Code Analyzer's FVAPN rule** after the same slip cost
  two CI round trips. Three false-positive classes on the way to zero;
  each is now a self-test fixture.

---

## R-029 — Stage F, checkpoint F.6, 22-Aug-2026, tier B (sandbox) + CI

**Scope.** `.mltbx` is deprecated and distribution is git (D-020). One
decision, and what it moved.

**Execution tier.** Tier B authoring, CI confirming: run **32542998647**,
515 points, **498 + 0 + 17**, green gate on all six.

**The rule survived and its reason was re-derived.** `+geo` may not call
into `tests/`, `tools/`, `records/` or `docbuild/` — because a **user's
path** omits them, where it used to be because an archive did. That is
not a weakening: PV-127 was reproduced with `restoredefaultpath` +
`addpath`, which is exactly the user's situation and never was the
archive's. The defect was always about the path; the archive was only how
it became visible.

`harnessNames` had justified its folder list by pointing at
`geoMap.prj`'s exclude filter. With the `.prj` withdrawn that file is
`geoMapSetup` — which PV-126 already made the one path authority after
six copies had grown across `ci.yml`, `gates.sh` and `buildfile.m`. The
audit had quietly grown a seventh. It reads the list now, and raises
`geo:audit:FolderListNotFound` rather than falling back to an empty one,
because a check that silently measures nothing is A-1 and A-5 both.

**A latent defect surfaced, and it was not in this change.** The audit's
self-test compared `[f.check]` against a string; on an empty findings
struct that expression is a `double`, so when a check FAILED TO FIRE the
self-test raised a MATLAB error instead of reporting it. Latent since the
self-test was written, in precisely the run where you most need it to
speak. Typed empty now.

**One check withdrawn.** An attempt to teach `mcheck` the
unbracketed-continuation parse error produced **six false positives in
three attempts**, on code that had compiled for weeks: stripping comments
at `%` also truncates a format specifier inside a literal. Doing it
properly needs a MATLAB-grade lexer for something Code Analyzer catches
one job later. A check that cries on valid source teaches people to
ignore it; shipping it because the effort was spent is the sunk cost
talking.

---

## R-030 — Stage F, checkpoint F.7, 22-Aug-2026, **tier A (bridge)**

**Scope.** Four defects, every one of them found by running on the target
machine rather than on CI.

**Execution tier. TIER A, and it is the point of this entry.** Confirming
run on the bridge, R2026a Update 4:

```
passed + failed + incomplete = 516 + 0 + 0 = 516
suite size                   = 516
per-class sum                = 516
GREEN GATE: PASS   (all six)
speed budgets      ok   (24 of 24 speed-tagged points ran)
FILTER INVENTORY   0 point(s) incomplete
```

**The first run in this project with nothing skipped.** CI on the same
commit: **500 + 0 + 16**, run 32567769608, each filter registered. The
union of the two hosts is the whole suite; neither host alone is.

**PV-145 — the frame was drawn on the west side only.** Reported from
`GettingStarted`. Registration made a global extent run −180…180, so the
ring's eastern meridian is at +180, and `geo.project`'s half-open default
folds +180 onto −180: the east side landed on the west and PV-135's
coincident-vertex collapse removed what it correctly saw as duplicates.
Every link behaved as specified. **The ring is a map EDGE and was being
projected with the window meant for DATA.** Measured before: mollweide
frame x −2.9108 … −0.0000 against a surface at ±2.8282. Fourteen call
sites now take `Window = "closed"` — and the first pass fixed
`mapBoundary` and `graticule` and left `frame.m`, which does its own
projecting in seven more places. The option had been applied where the
symptom was, not everywhere the rule holds; then I repeated that inside
the repair.

**PV-146 — an ignored manual is an undelivered one.** `docs/html` was
ignored as a build output, right while the `.mltbx` shipped it and wrong
the moment a clone became the delivery. A user would have run
`doc geoMap` and found `help_location` pointing at a folder they did not
have — the checklist item F.6 had re-derived one round earlier. Found
because the manual exists on the bridge, so `documentationSync` had
something to compare against and reported **five stale help blocks, one
from each of the last five rounds**. On CI the folder is absent, the
check filters, and none of it is visible.

**PV-147 — validation walked each axis four times, and sorted to find a
constant.** Ratio 0.1075 against a budget of 0.1. Registration and the
angular guard had each added an innocuous O(n) pass; together they
crossed a line neither could cross alone. **The budget was not raised.**
Measured: `median` of both axes is 16.3 µs of 59.8, and it sorts. Mean
plus a one-pass uniformity check costs 4 µs, with median kept for
genuinely irregular axes. Ratio **0.0767**, six repeats, band 0.0747…0.0827.

*After sharing the diffs, validation fell 97 → 84 µs and the ratio did
not move, because one pass over Z got faster too. That is why the budget
is a ratio against work the caller already pays for, and it is what sent
me to measure components instead of guessing a third time.*

**PV-148 — the v1 tree was never absent, the path was.** Two copies of
one developer's absolute path, both one folder too deep. **Four points
filtered for four rounds**, and PV-129 recorded the cause as *gone from
disk*. Nobody looked, because the filter came with a reason that sounded
like an explanation: *"normal on CI and a breach of OB-7 anywhere else"*
— both halves true, conclusion false. **That is A-1's finding inside
out: registering the reason made the filter visible, and made it easier
to accept.** One resolver now, searching `GEOMAP_V1_ROOT` and every
sibling of the geoMap root.

Against the real tree: **17 of 18 probes reproduced, 0 refuted, 1
blocked** (F17, on O6), and **177 options, 0 unmapped**. V4 and V9 are
discharged by a run rather than by a record; **OB-7 is met and never was
broken**, and PV-129's diagnosis is withdrawn rather than amended.

**On PV-131, honestly.** The PV-127 round still has no entry of its own,
and none is fabricated here: its green gate is reported only in commit
`3bdfb87` and this session did not witness it. What has changed is that
the claim no longer matters much — the tree it described has been
superseded twenty-five commits over, and the run above is witnessed.

**Binding items a later stage could be wrong for not reading.**

- **O11 is still unfilled.** The GRACE integration scenario uses a field
  labelled synthetic in the code, deliberately.
- **The rendered manual has not been looked at.** There is no automated
  oracle for "the figure is right" and pretending otherwise would be
  worse than saying so. It is the last open item of deliverable 10 and it
  belongs to Matthias.
- **Four of this session's defects were found by a human running the
  toolbox**, not by 516 points. PV-135, PV-136, PV-145 and the stale
  manual all reached daylight through `GettingStarted` or through a
  bridge run. That is the strongest argument in this record for keeping
  the human step in the release checklist.

---

## R-031 — Stage F, checkpoint F.9, 22-Aug-2026, **tier A (bridge)**

**Scope.** The release checklist, verified item by item, and the version
chain moved to **2.0.516**.

**Execution tier. Tier A.** Every item below was executed, and the two
that have no automated oracle were done by the means the checklist names
rather than waved through.

| item | verified by |
|---|---|
| `rungeoMapTests("all")` green | bridge, **516 + 0 + 0**, gate green on all six, `speed budgets ok (24 of 24)` |
| the same commit elsewhere | CI 32568624405, 500 + 0 + 16, every filter registered |
| docs build, zero broken links | `build_help`: 43 functions, **398 arguments documented, 398 rendered**, completeness 1, 0 broken links, 0 bad examples |
| the rendered pages **rasterised and looked at** | Matthias, 22-Aug. No automated oracle exists and none is pretended |
| **a fresh clone, root on the path only** | see below |
| every Part 0 debt discharged or carried | V1 … V9, all annotated with the measurement that closed them |
| the ledger fully ticked | Part 1.1 and 1.2, and `ledger_sync` green |

**The fresh-clone check, which is D-020's whole claim.** Cloned from
GitHub into a temp folder, then run in a **separate MATLAB with
`restoredefaultpath`** so the path is a user's and not a developer's:

```
geo.map resolves      : 1
tools on path         : 0        <- sha256OfText must NOT resolve
GettingStarted        : ran      (wrote geomap_getting_started.pdf)
manual present        : 1        (46 pages)
info.xml help_location: docs/html  (exists)
```

**That is the package-closure rule verified from the user's side rather
than the archive's**, which is exactly the re-derivation F.6 argued for
and had not yet demonstrated. Had `docs/html` still been ignored, the
last line would have read `(MISSING)`, and PV-146 would have shipped.

**Version 2.0.491-alpha.1 → 2.0.516.** The patch component is the
verified test-point count, so it moves because the evidence moved: 491
was the count at PV-127 and twenty-five points have been added since,
each with a defect behind it. The `-alpha.1` is dropped because the
checklist it was waiting on is complete.

**What is NOT closed, and is carried rather than tidied.**

- **O11 is unfilled.** The GRACE integration scenario uses a field
  labelled synthetic in the code. Filling it needs a named mascon release
  and its data file, and the expectation re-derived when a newer release
  supersedes it. Carried openly rather than faked with a
  plausible-looking number.
- **PV-131.** The PV-127 round has no records entry; its gate is reported
  only in commit `3bdfb87` and no session witnessed it. Not fabricated.
- **Sixteen points do not run on CI** — A-6, reduced from twenty-four and
  named per reason. The union of the two hosts is the whole suite.

**The reading this release leaves behind.** Nine defects reached shipped
code across Stages C to F. **Seven were found by a human running the
toolbox or by a run on the target machine; none by CI.** A suite of 516
points is necessary and is not sufficient, because a figure and a host
are both outside what it can see.

---

*Entries R-032 onward are written at each stage's green gate.*

---

## R-032 — Stage F, checkpoint F.10, 22-Aug-2026, **tier A (bridge)**

**Scope.** A three-reviewer examination of the tree at **2.0.516** against the
four guides that became binding on 21-Aug (`CODING_GUIDE`,
`VALIDATION_GUIDE`, `DOCUMENTATION_GUIDE`, `WORKFLOW_GUIDE`), plus the three
defects it closed and the Stage G scope it set. Status lives in `HANDOVER.md`
Parts 0, 1, 3 and 10; this entry holds the evidence and no status.

**Execution tier. Tier A**, over the working tree itself — MATLAB
R2026a Update 4, `win64`, 16 threads, at `C:\Users\matth\Documents\MATLAB\geoMap`,
confirmed by `git rev-parse HEAD` in the same session that ran the suite. Not
a copy. The three Python gates ran in the authoring container.

### Confirming run

`rungeoMapTests("all")` on the bridge, 22-Aug 16:08.

| | |
|---|---|
| predicted, in the commit message before any run | **518** = 516 + 2 new `robustness` points |
| passed + failed + incomplete | 518 + 0 + 0 |
| suite size | 518 |
| per-class sum | 518 |
| wall time | 145.15 s |
| warning inventory | empty |
| filters | none raised; 0 incomplete |
| speed tier | 24 of 24 selected points ran |
| figure census | none — the graphics root ends as it began |
| static audit | 0 findings |
| **green gate** | **PASS** on all seven conditions |

The prediction was hit exactly, three ways. The count reconciled to 519
against a suite size of 518 in the preceding red run, which is not a defect:
an *errored* point is counted both Failed and Incomplete.

### The second tier, and the disagreement is the argument for running both

CI run **#220**, id `32579682725`, on commit `08f7333`, `ubuntu-latest`,
R2026a hosted. All three jobs green: static gates, mirror + frozen
acceptance, MATLAB suite.

| | bridge (`win64`, 16 threads) | CI (`ubuntu-latest`) |
|---|---|---|
| passed + failed + incomplete | **518 + 0 + 0** | **502 + 0 + 16** |
| suite size | 518 | 518 |
| speed points run | 24 of 24 | 23 of 24 |
| figure census | clean | **clean** |
| green gate | PASS | PASS |

**The two tiers differ by exactly 16 points, and every one is a registered
reason:** `geo:filter:oracleDataAbsent` ×10, `geo:filter:v1TreeAbsent` ×4,
`geo:filter:fullProductAbsent` ×1, `geo:filter:noParallelPool` ×1. The hosted
runner has no oracle data files, no installed v1 tree and no Parallel
Computing Toolbox; the bridge has all three. That number *is* the argument
for running both tiers (`VALIDATION_GUIDE` Part 8) — neither tier alone sees
what the other sees.

**The census is clean on a headless runner too**, which the bridge alone
could not have established: `FigureCensusPlugin` reads the graphics root, and
a reasonable worry was that it would read something different under the
action's display handling. It does not.

### PV-150 measured, not merely argued

This branch is the first test of the trigger change, and the measurement is
clean because the branch was pushed four times **before** the pull request
existed:

| | old config | measured now |
|---|---|---|
| runs for 4 pushes + 1 PR open | 4 `push` + 1 `pull_request` = **5** | **1** |

Four pushes to a branch with no pull request produced **zero** runs, which is
exactly what `WORKFLOW_GUIDE` Part 5 warns reads like a queue that has not
started — and is why the draft PR is opened at once rather than at the end.
The one run that exists carries `event=pull_request`.

### Finding PV-149 — four figures survived every green run

**Symptom, and where it came from.** Four figures were open on the target
machine at the start of the session, `Visible='on'`. Two carried a single
`Surface`; two carried 30 children. All four had `XLim` ±π, `YLim` ±π/2.

**How it was attributed — measured, not read.** A `groot` `ChildAdded`
listener was tried first and **did not fire**; that route is recorded here as
not working rather than quietly replaced. `set(groot,'DefaultFigureCreateFcn',…)`
does fire, and `dbstack` inside it carries the creating frames. Over a full
516-point run every figure creation was logged with its stack and matched to
the survivors by figure number. All four:

```
    resolveAxes (line 524)
    basemap (line 243)
    drawLadder (line 246)
    map (line 185)
    @()geo.map(G,args{:}) (line 88)
    Throws.throwsExpectedException (line 187)
    TestE1_map.anElementThatNeedsItsDataSaysWhichField (line 88)
```

**The defect.** `geo.basemap` creates the figure in `resolveAxes` when no
`Parent` is given. `geo.map` then climbs a fourteen-rung ladder into it. The
test asserts `geo:map:MissingField` for four element specs; the error escapes,
and nothing owned the figure already on screen.

**Why exactly two of the four look "unfinished".** The ladder order is
`Contours, Polygons, Stipple, Graticule, Coastline, …, Track, Points, …`.
`Polygons` and `Stipple` fail **below** `Graticule` and abandon a bare
surface — 1 child. `Track` and `Points` fail **above** it and abandon a map
with graticule and coastline — 30 children. 2 + 2, which is what the live
handles showed. **The "unfinished plot" is not unfinished; it is abandoned.**

**Why the assertion did not catch it.** The point asserted the *identifier*,
and the identifier was always right. A correct error can still leave wreckage
on screen. That is `VALIDATION_GUIDE` Part 3's **proxy**: asserting something
implied by the claim rather than the claim.

**Why no gate caught it.** Every condition the runner applies reads results,
warning identifiers, filter reasons, speed records, category coverage or
source files. **Not one reads the graphics root.** The leak was found by a
human noticing windows on a desktop, which is not an instrument.

**Repair.** `geo.internal.discardOnFailure` is the single authority for the
rule. `geo.basemap` returns `H.CreatedFigure`; `geo.map` **reads** it rather
than testing `isempty(Parent)` a second time — the same fact stated twice is
the defect class this project has spent the most repairs on. The basemap
body, the draw ladder and the export step are each inside the guard. `DELETE`
and not `CLOSE`: `CloseRequestFcn` is user-replaceable and may refuse, and
error unwinding must neither run user code nor be refusable.

### Fault injection of the new check (`VALIDATION_GUIDE` Part 3)

`FigureCensusPlugin` is a new instrument, so it was proved to fire before it
was trusted. The guard's condition was neutered to `if false && …` on a
working copy, `rungeoMapTests("TestE1_map")` was run, and the guard restored
by `git checkout --` with `git status --porcelain` confirmed empty.

| tree | census | figures open | gate |
|---|---|---|---|
| broken | `aFrontThatFailsLeavesNoFigureBehind +4`, `anElementThatNeedsItsDataSaysWhichField +4` | 8 | **FAIL** |
| healthy | none | 0 | clean |

It fires on a broken tree, is silent on a healthy one, **and it named the
original defect independently of the test written for it.**

### Finding PV-150 — CI bought two identical runs of everything

`on: push:` was unrestricted and paired with `on: pull_request:`, which
`WORKFLOW_GUIDE` Part 4 forbids by name. The file defended the duplicate in a
comment as a hang-diagnosis instrument. The defence does not survive costing:
a permanent doubling of every job for the project's life, to make one rare
diagnosis marginally easier, when the step-level 8-minute timeout on the
MATLAB setup step already turns a hang into a named failure. Nothing is lost
by the repair — `pull_request` fires on synchronize, so a branch with an open
PR still gets a run per push. What stops is the run on a branch nobody has
opened a PR for, which Part 5 says should not exist.

### Finding PV-151 — a count stale by twenty-five behind a correct stamp

`Contents.m` line 15 and `README.md` line 28 both read **491 test points**
while the version authority two lines above read **2.0.516**. Every gate
green throughout. `geoMapAudit`'s `versionAgreement` check compares version
**declarations** — `% Version X.Y.Z` and dotted triples declared as versions —
and a count written into prose is not one. Textbook `DOCUMENTATION_GUIDE`
Part 3: *a stamp is not the content*. `Contents.m` no longer restates the
count at all; the Version line is its one home.

Incidentally closed: the `Registration` field has been in `geo.basemap`'s
returned struct since Stage D and was **never documented**. The sync gate
could not see it, because it compares the page against the help block and
both were silent about the field.

### The reviewers' verdict, where it was that nothing needed changing

Recorded explicitly, because a reviewer who reports only problems is not
distinguishable from one who did not check. The sixteen projections are
certified against PROJ **and** against published point values, not against
themselves. The conservative regrid closes mass at **2.60e-14** against a
1e-13 bound derived from measurement rather than guessed. The hillshade
carries the spherical metric — the lat 60 / lat 0 ratio measures 6.09e-06
relative against a 1e-05 bound — and is checked against `gdaldem`. CIELAB L*
monotonicity holds for viridis, magma and cividis. The layering rule is
parsed, not drawn. None of this was changed.

### Oracle register: three rows were wrong, and nothing was watching

| row | was | is |
|---|---|---|
| O7 | `cdo remapcon` **or `gdalwarp -r average`**, certifying conservative weights and mass closure | `gdalwarp -r average` takes an **unweighted** mean of source centres in a target cell. On a geographic grid cell area goes as cos φ, so that is not the cell integral and does not conserve mass away from the equator. `mirror/geomap_mirror/gdal_oracle.py` states this in its own header; Part 3 never absorbed it. Re-specified; debt **V10** raised |
| O8 | ☐ | Filled, and had been for days — `gdal_oracle.py` exists to fill it and CI proves the route against an analytically known plane on every push |
| O12 | ☐ | Filled twice (15-Aug, 22-Aug): 17 of 18 v1 probes reproduced, 0 refuted, 1 blocked |

`tools/ledger_sync.py` compares the **stage ledger** against this file and
reads nothing in Part 3. The oracle register is the one status surface in the
project with no instrument, which is debt **V12** and package **G.0**.

### Binding items a later stage could be wrong for not reading

1. **A front that creates a figure owns it on every exit path.** Any new L4
   front goes inside the same guard, or it reintroduces PV-149.
2. **The green gate has seven conditions now, not six.** The figure census
   reports and never closes; making it green by closing figures would destroy
   its own evidence.
3. **Part 3 is provisional in writing until G.0 ships its gate.** Do not cite
   an oracle row's status without opening the module that implements it.
4. **O7 does not certify mass closure.** Cite the analytic invariant and the
   split/merge property, which are narrower and true.
5. Next action, as a command:
   `rungeoMapTests("all")` after `git checkout claude/g1-figure-leak-and-ci`.

---

## R-033 — Stage G, package G.0, 22-Aug-2026, **tier A (bridge)**

**Scope.** The oracle register's first instrument (G.0a) and PV-152's repair
(G.0b). Status is in `HANDOVER.md` Parts 0, 1, 3, 4 and 10; this holds the
evidence.

**Execution tier. Tier A**, over the working tree at
`C:\Users\matth\Documents\MATLAB\geoMap`. Python gates in the container; the
mirror tier is CI's, because the sandbox has no GDAL — stated rather than
left as an unexplained gap.

### Confirming run

| | |
|---|---|
| predicted, in the commit message before the run | **521** = 518 + 3 |
| passed + failed + incomplete | 521 + 0 + 0 |
| suite size / per-class sum | 521 / 521 |
| warning inventory | empty |
| figure census | clean |
| static audit | 0 findings |
| **green gate** | **PASS**, all seven |

New record: `worst text overlap, robinson, full front [none] — 0 points
(bound <= 0.5)`.

### G.0a — four register rows were wrong, and one gate found them all

`O2` open while `mirror/acceptance.json` cited it as the `source` of two
frozen criteria; `O7` bundling two claims with different evidence; `O8` open
while its module ran on every push; `O12` dated without a year. O7 was
**split** rather than reworded — mass closure is now O13, open, debt V10.
O13–O20 seeded for the Stage G packages.

**The self-test was vacuous for two runs.** Its third planted defect called
`ROW.sub()` without `re.M`, so the anchors bound to the whole string and it
planted nothing. It passed regardless, because `check()` was returning real
findings from a dirty register — **the dirt was hiding the vacuum**. It
surfaced the moment the register came clean. Repaired, and a *silence half*
added: the gate must also be quiet on a repaired register.

**This is a question the other three gates have not been asked.** `mcheck`,
`provenance_audit` and `ledger_sync` all inject a defect and check they fire;
none, as far as this session checked, verifies it is silent on a repaired
tree. Not a claim that they are vacuous — a claim that the question now has a
precedent and has not been put to them. Recorded here so a later session
cannot mistake the omission for a finding of health.

### G.0b — PV-152, and a first repair that was wrong in the way that looks right

Two causes. `geo.colorbar` anchored to `plottedBox`, which is the **map**,
while the graticule's labels sit outside it. And `placeLabels` compared each
label to nothing, so on a projection whose parallels converge the extreme
parallel and the seam meridian met at the same corner.

**The first `labelOverhang` DERIVED the overhang**, mapping data-unit extents
onto `plottedBox` on the assumption that `plottedBox` is the rectangle the
axis limits map onto. It is not, and `geo.frame` widens the limits after the
graticule has drawn:

| | derived | measured |
|---|---|---|
| labels reach below the map | 6.9 pt | **44.8 pt** |
| colliding pairs after "repair" | 5 | — |

The colorbar moved a seventh of what it needed, six pairs became five, and
the vertical overlaps got *worse* (4.3 → 9.8 pt): rearranged, not repaired.
**Had the count been read as progress the defect would have shipped.**
CODING_GUIDE R3 — read the property from the object, never infer it from a
convention about how the object was built. `geo.internal.textRects` now owns
measure-don't-derive and the restoration of the Units it changes.

**`LabelsOmitted` is a returned field and not a warning.** A warning was
written first and withdrawn: that corner collides on almost every *global*
map, so it would have fired on the most ordinary call in the toolbox, taught
its users to silence the identifier, and put a permanent entry in an
inventory whose entire value is being empty.

**Three defects came out of the red run**, all mine: `tc.worldGrid()` is a
local of `TestE1_map` and not a base-class fixture (`demoGrid` is) — the
second time this session a per-suite helper was reached for as if shared;
`%#ok<AGROW>` inside `+geo`, which the audit bans on F13's evidence; and a
stale `geo_graticule.html`. The suite size read **521 in the red run too**,
so the prediction was right and only the outcomes were wrong — which is the
signal the prediction discipline exists to give.

### Binding items a later stage could be wrong for not reading

1. **A graphics assertion that measures one element against its own claim
   proves nothing about the map.** Six pairs overlapped for a whole release
   behind 518 such assertions. New front-level work adds a
   `verifyNoTextOverlap` point.
2. **Ask every instrument whether it is silent on a repaired tree**, not only
   whether it fires on a broken one.
3. **A symptom count going down is not evidence of a repair.** 6 → 5 here was
   a wrong fix.
4. Next action, as a command: `rungeoMapTests("all")` after merge, predicting
   521.
