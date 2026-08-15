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

*Entries R-007 onward are written at each stage's green gate.*
