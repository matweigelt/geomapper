# geoMap v2 — HANDOVER

**Revision 3.0 · 16-Aug-2026 · supersedes revision 1.1 (23-Jul-2026) in full. Revision 2.0 amended by Stage 0 pre-validation (13-Aug); revision 2.2 amended by the first EXECUTED run of the harness (14/15-Aug).**

**What this file is.** The single source of truth for the revision of `geoImagescToolbox` v1.1/1.2 → `geoMap` v2.0. It holds the rules, the design and the ledger. **It is the only place a status lives.** Per BEST_PRACTICE §6.1 it holds no round-by-round narrative evidence; that goes to `RECORDS.md`.

**Binding documents, in precedence order.**

| # | Document | Authority |
|---|---|---|
| 1 | `BEST_PRACTICE_v4.md` (Weigelt, 06-Aug-2026) | Cross-project rules. Binding without exception. Where this handover appears to relax a rule in it, this handover is wrong. |
| 2 | This file (`HANDOVER.md`) | Project rules, design, ledger, stage prompts. |
| 3 | `RECORDS.md` | Archived evidence. Read when you need the evidence behind a decision, **not** as background. |

**Adoption note.** Revision 2.0 adopts BEST_PRACTICE_v4 unanimously. Six of its rules contradicted revision 1.1 outright; each contradiction and its repair is recorded in the Change Log (Part 10) rather than silently absorbed. Two of them changed the *architecture*, not merely the prose: the test harness moved ahead of the first function (§3.4.2, one shared timing helper before the first budget), and a Python mirror became a shipped deliverable rather than an ad-hoc fallback (§2.3).

**Target platform.** MATLAB R2026a, base MATLAB only. Parallel Computing Toolbox is optional and never required.

---

## Part 0 — Verification debt

*Per BEST_PRACTICE §6.13, this table opens the document, before any statement of design or progress. A handover that lists only what works is an advertisement, not an instrument. Every row is a claim currently unverified; each names what would discharge it.*

| # | Debt | Why it is unverified | Discharged by | Severity |
|---|---|---|---|---|
| V1 | ~~Every number in this document is model-derived.~~ **PARTIALLY DISCHARGED 13-Aug-2026.** 37 values measured by the mirror; 4 handover claims refuted, 33 confirmed. Corrections applied to Part 7.4. **Remaining:** the speed ratios (see V5) and the tolerances for Stages C–F, which no mirror can reach. | Mirror run, `mirror/geomap_mirror/out/reference_values.json`. | V5 for speed; Stage C–F numbers measured at their own stages. **Standing rule survives: no stage asserts a number this document supplies until it has been measured.** | Medium |
| V2 | ~~v1's 16 projections were never checked against an independent implementation.~~ **DISCHARGED for the mathematics 13-Aug-2026.** All 16 spherical kernels now agree with PROJ 9.5.1 to ≤ 6e-13 (Robinson ≤ 8.9e-4, see L5), and all 16 round-trip to ≤ 4.6e-9. ~~**Remaining:** the MATLAB implementations are still unwritten and unchecked; the oracle now exists to check them.~~ **FULLY DISCHARGED 15-Aug-2026.** All sixteen are written and checked. Published point values reproduce to **0** (LCC Snyder p.296, polar stereographic ρ(70), Robinson table nodes) and 1.1e-16 (Mercator y(35)); round trips measure ≤ 4.5e-12° for thirteen of sixteen, 1.63e-11° for orthographic and 2.07e-09° for Lambert azimuthal — the last inside its own 1e-8 exception and better than the mirror's 4.6e-9. The analytic invariants hold at 5.0e-9 … 3.9e-8 against 1e-6 tolerances. R-007. | Mirror vs oracle O4; MATLAB vs mirror. | — closed | — |
| V3 | ~~The GSHHG reader has never seen a real GSHHG file.~~ **DISCHARGED 15-Aug-2026, and it was the oldest debt in the project.** Real GSHHG binaries and Natural Earth shapefiles arrived at `E:\DATAPOOL\Borders`. Measured: `gshhs_c.b` L1 gives 7 286 pts / 746 parts, `gshhs_i.b` L1 gives 340 364 pts / 32 835 parts, and the L5/6 Antarctic pole closure lands at **exactly −90** (defect F17). `ne_10m_coastline.shp` gives 410 957 pts / 4 133 parts with coordinates exact as IEEE doubles. **Oracles O5 and O6 both filled.** `Provenance` now reads `"verified"` per format. R-008. | Real files, checked. | — closed | — |
| V4 | **The v1 defect list F1–F18 is a reading, not a measurement.** F1 (`range()` is a Statistics Toolbox function) and F2 (Robinson wrap) are near-certain; F4 (regrid seam), F9 (renderer dependence) and F12 (magic thresholds) were inferred from source without executing v1. | v1 was never run during the review. | Stage 0 delivers `records/v1_defect_probes.m`, one runnable probe per finding, run against the v1 tree. Findings that fail to reproduce are **removed from the design rationale**, not quietly kept. | **Medium** |
| V5 | ~~No baseline machine is recorded, and the entire MATLAB harness is unexecuted.~~ **DISCHARGED 15-Aug-2026.** Baseline machine: `win64 | R2026a | 16 threads`. The harness ran: 20 points, 18 pass, 2 filtered loudly, green gate on all five conditions. Every `PROVISIONAL` stamp in the eleven shipped files is now false and must be removed in the next commit. **Remaining:** the Stage A–F speed budgets in §2.4.3 are still predictions; only the three harness self-test ratios are measured. Every speed budget in Part 7 is a predicted ratio with no measurement behind it. | Nothing has run. | Stage 0's first green run records the machine and the baseline operation timings in `RECORDS.md`; Stage B onward asserts against them. Until then every speed budget is marked *predicted* in its own test. | **Medium** |
| V6 | ~~Execution tier is undeclared.~~ **DISCHARGED 14-Aug-2026.** Tier A confirmed by use: live R2026a via MCP, filesystem access, working `git` with credential manager. `gh` absent, so PR creation stays manual. | Bridge exercised end to end. | — closed | — |
| V7 | **The conservative-regrid mass-closure guarantee (≤1e-12 relative) is an assertion about an algorithm not yet written.** First-order area-weighted remap conserves exactly in exact arithmetic; the achievable floor in double precision over a 2161×4321 grid is a summation-order question and has not been measured. | No implementation. | Stage 0 mirror measures the achievable floor on the real grid size and **the tolerance is set from that measurement**, not from this document's guess. If it is worse than 1e-12, that is a finding (BEST_PRACTICE §4.6 — never loosen to pass; record and re-derive). | **Medium** |
| V8 | ~~`geo.scalebar`'s 5% scale-variation gate is an invented threshold.~~ **DISCHARGED 13-Aug-2026.** Measured across 14 projections × 4 extents. At a 1.05 threshold a *refusing* gate would refuse on 6 of 14 projections even for a 10°×10° regional map, and 12 of 14 at continental scale — confirming D-006's draw-and-report decision on evidence rather than judgement. Threshold retained as a **warning** trigger only. Two method corrections: the gate must read **linear** scale (h, k), not area scale (PV-009), and must sample strictly inside the extent (PV-008/L7). | Mirror `check_scale_variation`. | — closed | — |
| V9 | **Whether the v1 option surface can be preserved 1:1 is untested.** Stage E promises v1 option names carry over "wherever the feature survived"; nobody has enumerated v1's options against v2's function set. | Not done. | Stage 0 delivers `records/v1_option_inventory.md`, a mechanical extraction of every `options.` field from v1's five fronts, mapped to its v2 destination or marked dropped with a reason. | **Low** |

**Standing rule.** A debt is discharged only when a number exists end to end (BEST_PRACTICE §F5). "The mirror now computes it" is not discharge; "the mirror computes it, MATLAB reproduces it, and both are in `RECORDS.md`" is.

---

## Part 1 — Ledger

*The only place a status lives. `RECORDS.md` holds the evidence; it holds no status.*

### 1.1 Stage ledger

| Stage | Deliverable | Depends on | Tier | Status | Green gate date | Records entry |
|---|---|---|---|---|---|---|
| **0** | Harness, mirror, audit, runner, oracle register seeding, v1 probes | — | **A** (bridge) | **◐ in progress** — 0.1 (mirror) executed; **0.2 (MATLAB harness) EXECUTED AND GREEN on the target machine, pushed to `claude/v2000-stage0-harness`**; 0.3 (audit, v1 probes) open | 0.2 green 15-Aug-2026 | R-002, R-003, R-004 |
| **A** | L0 data model + longitude topology (14 files) | 0 | **A** (bridge) | **☑ done** — three checkpoints, each with its own confirming run (63 → 88 → 113 points, every count predicted correctly before its run) | **15-Aug-2026** | R-006 |
| **B** | L1 core math (12 files) | 0, A | **A** (bridge) | **☑ done** — three checkpoints, each with its own confirming run (138 → 164 → 182 points, every count predicted correctly before its run) | **15-Aug-2026** | R-007 |
| **C** | L2 I/O and caching (4 files + edit) | 0, A, B | **A** (bridge) | **☑ done** — 205 points predicted, 205 run, 205 passed. **V3 discharged**, O5 and O6 filled against real data. GeoTIFF/worldfile deferred with its identifier and contract test in place | **15-Aug-2026** | R-008 |
| **D** | L3 cartographic elements (14 files) | 0, A–C | B | ☐ not started | — | — |
| **E** | L4 fronts (6 files) | 0, A–D | B | ☐ not started | — | — |
| **F** | Docs, packaging, release, independent audit | 0, A–E | B | ☐ not started | — | — |

Status values, and nothing else: `☐ not started` · `◐ in progress` · `◐ provisional (code shipped, not executed)` · `☑ done`.

**`☑ done` means a green gate on the real runner, with its date and its counts** (BEST_PRACTICE §6.2). Not a green subset. Not the stage's own suite passing while the gate is red. A stage whose code shipped but was never executed is **provisional**, and provisional is not done.

### 1.2 Checkpoint ledger

Stages B and D are delivered in checkpoints — consecutive turns within one chat, each with its own confirming run.

| Stage | Checkpoint | Contents | Status |
|---|---|---|---|
| B | B.1 | `project`, `unproject`, `scaleFactors` | ☑ 138 points |
| B | B.2 | `quantile`, `symmetricLimits`, `niceTicks`, `regrid`, `hillshade` | ☑ 164 points |
| B | B.3 | `colormaps` | ☑ 182 points |
| D | D.1 | `internal.layout`, `basemap`, `graticule`, `frame` | ☐ |
| D | D.2 | `coastline`, `scalebar`, `northarrow`, `colorbar`, `inset` | ☐ |
| D | D.3 | overlays: `track`, `points`, `contours`, `polygons`, `stipple` | ☐ |

### 1.3 Obligations register

*Standing rules with an owner and a closing condition (BEST_PRACTICE §6.4). Kept here because this is the file a later reader will actually open.*

| # | Obligation | Owner | Closes when |
|---|---|---|---|
| OB-1 | Every stage declares its execution tier in its first line. | implementing chat | never — standing |
| OB-2 | No number from this document is asserted in a test until the mirror has reproduced it. | implementing chat | never — standing |
| OB-3 | The GSHHG reader carries `provenance = "unverified"` in its metadata and its help note. | Stage C | V3 discharged |
| OB-4 | Every speed budget carries the tag *predicted* until measured on the recorded baseline machine. | all stages | V5 discharged |
| OB-5 | Exemption register (Part 2.3.2) is re-read at each stage boundary; an exemption that has become false is a finding. | implementing chat | release |
| OB-6 | Decision log re-read triggers (Part 4) checked at each stage boundary. | implementing chat | release |
| OB-7 | v1 remains installed and runnable until Stage F, so defect probes stay reproducible. | Matthias | Stage F green |

---

## Part 2 — Binding rules

BEST_PRACTICE_v4 applies in full and is not restated here. This part records only the **geoMap-specific instantiation**: where the general rule needs a project-specific number, name or mechanism to be actionable.

### 2.1 Execution tier (BEST_PRACTICE §2.0)

**Declared in the first line of every session, never assumed.**

- **Tier A** — a live MATLAB session is reachable from the authoring chat (MCP), **and it runs over the very folder the deliverable is built from**. If the run is over a copy, it is Tier B with extra steps (§2.0). Under Tier A the in-session run is ground truth.
- **Tier B** — no interpreter in the authoring sandbox. Development is mirrored in Python, every asserted number pre-validated there, and **Matthias's run is the gate**.

**Tier A is available and was used on 14/15-Aug-2026.** The MATLAB MCP bridge reaches a live R2026a Update 4 session on the target machine (win64, Windows 11, 16 threads), and a Filesystem connector reaches `C:\Users\matth\Documents\MATLAB`. Together with `git` 2.55 and Git Credential Manager at system scope, that is the full loop: place, branch, commit, push. Debt **V6 discharged**.

**What Tier A does NOT give**, measured rather than assumed: `gh` is not installed, so a pull request cannot be opened through the API from here. A push prints the create-PR URL and a human clicks it. Extracting the credential-manager token to do it unattended is not an option — a credential is not Claude's to handle. The gap is one click per round.

**The mirror survives promotion to Tier A** (§2.3). It found four wrong numbers in this document before any MATLAB existed; it keeps that job.

**The mirror survives promotion to Tier A** (§2.3). It is the pre-validation instrument, not a fallback. Under Tier A it keeps that role and loses only its role as the last word.

### 2.2 The mirror (BEST_PRACTICE §2.2, §2.3)

The mirror is a **shipped deliverable**, not a scratch pad. It lives at `mirror/geomap_mirror/` as a Python package, with the same documentation discipline as MATLAB code.

| Rule | geoMap form |
|---|---|
| One owner per kernel | Exactly one Python implementation of each kernel. `mirror/geomap_mirror/projections.py` owns all 16 forward and inverse; nothing else re-derives them. A stage that needs a projection **imports** it. |
| Import, never re-derive | Stage prompts say "import from the mirror"; a stage that re-derives a mirrored kernel has introduced drift and the review rejects it. |
| Arithmetic changes in the same round | A change to shipped MATLAB arithmetic or operation order changes the mirror in the same round. A standing mirror test checks the mirror still reproduces the properties its originating work measured. |
| Target is right by definition | Where MATLAB and the mirror disagree, MATLAB is right. The mirror's job is to find the disagreement, not to win it. |
| Record what the mirror cannot see | `mirror/LIMITS.md`, maintained per stage. Known entries seeded in Stage 0: MATLAB drops trailing singleton dimensions where NumPy does not; graphics behaviour is entirely invisible to the mirror; `griddedInterpolant` extrapolation semantics differ from `scipy`'s; speed ratios transfer only when both sides scale alike (§3.4.8). |
| Target-only measurements documented at the site | Where a number can only be measured in MATLAB (graphics timings, `timeit` overhead, renderer behaviour), say so **in the help text of the thing it justifies**, with the numbers, the bands and the approaches that failed — plus the procedure for re-deriving it. |
| Scratch probes are not kept | A probe duplicating a shipped fixture is deleted the day it is written. What gets kept is the procedure. |
| Superseded scripts are frozen, not rewritten | A superseded verification script stays as the record of its own round. |

**Transfer manifest (§2.2.3).** Every Tier-B round ships the whole tree as one artefact with `MANIFEST.txt`: every path, its line count, its SHA-256. `rungeoMapTests` verifies the tree against the manifest **before running anything** and reports missing, truncated or altered files in its own words at the top of the log. Under Tier A the manifest is still generated; it then guards only the download.

### 2.3 Test categories (BEST_PRACTICE §3.3)

Revision 1.1's three tiers (`contract` / `numeric` / `speed`) are **withdrawn**. They collapsed four distinct categories into `numeric` and had no category at all for vectorisation or metamorphic properties — the two cheapest reference tests in an array language, and the two most often assumed.

#### 2.3.1 The seven categories

| Tag | Asserts | geoMap examples |
|---|---|---|
| `contract` | The promises in the help text: output shapes and types, argument rejection with the **documented** identifier and only that one, determinism where promised, error messages naming the offending field. | Every documented `geo:*:*` identifier fires; NaN-as-gap propagates; row/column orientation preserved. |
| `reference` | Agreement with an outside authority — see the oracle register (Part 3). | `geo.project` against `pyproj`; the shapefile reader against a real Natural Earth file; conservative regrid against `cdo remapcon`. |
| `precision` | The numerical claim, with an explicit tolerance **and a comment saying where the tolerance came from**. | Round-trip ≤ 1e-9°; equal-area integral ≤ 1e-3 relative; mass closure at the floor V7 measures. |
| `speed` | A **relative** budget against a recorded baseline on the same machine (§2.4). | `cost(mollweide)/cost(equirectangular)`; `cost(unproject)/cost(project)`; `cost(geo.map)/cost(geo.basemap)`. |
| `robustness` | Behaviour at and beyond the edge of validity: degeneracy **constructed from the algebra**, conditioning, boundary and empty inputs, non-finite propagation, reproducibility under worker count. | Conic with `p1 = -p2` (cone constant exactly 0); azimuthal at the exact antipode; single-row grid; all-NaN source; regrid identical under 1, 2, 4 workers. |
| `vectorisation` | A batched call equals the same inputs one at a time. | `geo.project` on a 1000-element array equals 1000 scalar calls, bitwise. Same for `hillshade` rows, `quantile`, `colormaps("truecolor")`. |
| `metamorphic` | Invariance and equivariance **through the public API**, each stating whether the expectation is bitwise or eps-level and why. | `project(lon+Δ, lat, crs(lon0+Δ)) == project(lon, lat, crs(lon0))`; regrid split/merge; `quantile` permutation invariance; `hillshade` E–W mirror symmetry; `splitAntimeridian` idempotence. |

Two **cross-cutting tags**, not categories: `diagnostics` (does every measured number reach the report — §5.3) and `provenance` (does every result carry the metadata saying where it came from — §4.2).

#### 2.3.2 Counting and exemptions

**Count them mechanically, per unit.** The Stage 0 audit reports, for every public function, which of the seven categories its suite ships. An audit that asked this question for the first time in one source project found 46 of 81 functions short of at least one category **after nine green runs** — the count is not optional bookkeeping.

**An exemption is a claim that the test is impossible, not that it is inconvenient.** Exemptions live in `tests/EXEMPTIONS.md`, one row per function per category, each with a reason. Mechanically enforced: **`contract` may not be exempted for any function that validates its arguments** — argument validation runs before the body, so a rejected call is refutable in microseconds no matter how expensive a successful one is.

Exemptions expected to be legitimate, seeded in Stage 0 and re-read at every stage boundary (OB-5):

| Function class | Category | Reason |
|---|---|---|
| L3 graphics elements | `vectorisation` | There is no batched form; each call draws into one axes. |
| L3/L4 graphics | `precision` | The claim is geometric, asserted under `contract` with `TolGeom`; there is no numerical claim of its own. |
| `geo.cache` | `metamorphic` | Its observable is a hit/miss, which has no invariance to state. |
| `geo.export` | `reference` | No external authority certifies a PDF's byte content; the page-box measurement is the contract. |

Anything not in that table and not shipped is a gap, not an exemption.

### 2.4 Speed doctrine (BEST_PRACTICE §3.4) — geoMap instantiation

Revision 1.1's 19 absolute budgets (`≤ 150 ms`, `≤ 3 s`, …) are **withdrawn in full**. §3.4.1: an absolute figure with no baseline cannot detect the change it was written for; one source project shipped a **1.30× regression** behind an absolute benchmark, and a sub-millisecond absolute row swung **6.8× across three runs on untouched code**.

#### 2.4.1 The shared timing helper — before the first budget

`GeoMapTestCase.assertRatioBudget(fcnA, fcnB, budget, expected, label)` is **the only** timing instrument in the project. Eleven near-copies of a local median helper in one source project meant thirteen places for the next repair to be applied twelve times. This is why the harness is Stage 0 and not Stage F: **no budget may be written before its instrument exists.**

It does all of this, and nothing in a test does any of it by hand:

1. One untimed warm-up call per point.
2. **Both points timed inside one repeat**, never point A to completion then point B — that puts them in different windows and everything that drifts across a window lands entirely on the later one. Measured in a source project: a ratio read **8.298 inside the full runner against 4.81 / 5.11 / 5.34 / 5.43 / 5.54 for the same binary run alone, five times out of five**, against a budget of 8.
3. **Rotation** of which point is timed first, because a fixed order leaves a small, always-identically-signed bias. Repeat count is a multiple of the number of points.
4. **15 repeats** (measured spread over 10 trials: 5 → 31.2%, 9 → 14.0%, 15 → 10.2%, 21 → 4.4%).
5. The statistic formed **per repeat**, then the **median of those** — never a ratio of medians.
6. Failure message quotes the per-repeat `min .. max` band, so the next reader can tell a regression from a machine having a bad minute.
7. Returns a report record (§2.6.3) carrying the ratio, the band, both absolutes, and the machine tag — **so an assertion cannot exist without something to log.**

**A threshold does not move as part of an instrument repair.** If the honest instrument reads differently, that difference is a finding recorded with its measurement, never absorbed by widening the budget.

#### 2.4.2 Choosing the pair

The stable shape is **two sides doing the same work on the same arrays** (§3.4.3) — a dispatch layer against the kernel it dispatches to. Those sit in one memory regime by construction. Checks before any budget is written:

- **Same memory regime.** One source budget moved 6.751 → 9.380 between two runs of byte-identical code because its points were 3.1 MiB and 12.5 MiB, straddling L3. Check the footprint first.
- **Fixed cost must not dominate a growth budget.** Solve `f + v` and `f + 4v` from two points; if `f` is larger, the ratio is measuring call overhead. One ladder *passed* at 0.95× and 1.08× where linear predicts 2.00×, because 99% of the small point was the call.
- **Below ~1 ms you are timing the timer** — inner batch, not more repeats.
- **The measurement point is part of the budget** (§3.4.9). State N beside the budget, with the expected value, so the margin is visible without re-derivation.
- **Cross-language ratios transfer only when both sides scale alike** (§3.4.8), and the direction is not predictable. Mirror-measured ratios set MATLAB budgets **several times away in whichever direction failure would hurt**, and the mirror figure is quoted in the test as prediction, not as authority.

#### 2.4.3 The geoMap budget table

Every budget is a ratio. `N` is stated; `expected` is the mirror's prediction (or, after V5 is discharged, the recorded baseline); `budget` sits several times clear of it in the direction failure would hurt.

| Stage | Ratio asserted | N | Expected | Budget | Note |
|---|---|---|---|---|---|
| A | `wrapLongitude` / `mod(x,360)` | 1e7 | ~2 | 5 | Same array, same regime; it *is* a mod plus an offset. |
| A | `splitAntimeridian` / `diff`+`find` scan | 1e6 | ~6 | 15 | |
| A | `geo.grid` at 4× elements / at 1× | 4321×2161 | ~1.0 | 1.5 | The claim is that validation cost does **not** depend on `numel(Z)`; fixed-cost dominance is the assertion, not a flaw. Inner batch. |
| A | `splitTracks` / `diff`+`find` scan | 1e6 | ~8 | 20 | |
| B | `project(P)` / `project(equirectangular)` | 1e6 | mercator ~3, mollweide ~30, winkeltripel ~15, conic ~6 | 3× expected, per projection | One table row per projection, each written out in the test. |
| B | `unproject(P)` / `project(P)` | 1e6 | closed forms ~2 | 6 | Same arrays both sides — the stable shape. |
| B | `unproject(winkeltripel)` / `project(winkeltripel)` | 1e6 | ~8 (2-D Newton) | 25 | Separate row: different algorithm class. |
| B | `unproject(robinson)` / `project(robinson)` | 1e6 | ~1.5 | 5 | Both are table interpolations. |
| B | `regrid` conservative / bilinear | 2161×4321 → 181×361 | ~20 | 60 | |
| B | `regrid` bilinear at 4× target / at 1× | ditto | ~4 | 6 | Growth budget: measure and subtract the fixed term first. |
| B | `hillshade` / one `conv2` 3×3 on the same array | 2161×4321 | ~8 | 20 | |
| B | `hillshade` multi / single | ditto | ~4 | 6 | Guards the 4-azimuth blend, not the kernel. |
| B | `quantile` / `sort` on the same array | 1e7 | ~1.3 | 2.5 | It *is* a sort plus indexing; a ratio far above 2.5 means a copy was introduced. |
| B | `colormaps("truecolor")` with `Shade` / without | 2161×4321 | ~1.4 | 2.5 | §5.5: the claim is that shading is marginal — assert against what it is marginal to. |
| C | reader / bare `fread` of the same byte count | fixture | ~4 | 12 | |
| C | cache cold / warm | fixture | ≥ 50 | **≥ 10** | Direction reversed: this budget asserts a *speedup*. |
| D | `basemap` / bare `surf` of the same grid | 181×361 | ~4 | 12 | Graphics — weaker evidence, see below. |
| D | each element / `basemap` | ditto | ≤ 0.15 | 0.4 | Marginal cost of an element against the map it decorates. |
| E | `geo.map` / `geo.basemap` | ditto | ~2.5 | 5 | §5.5 again: the front's orchestration overhead against the engine. |

**Graphics budgets are weaker evidence and are marked so in their own tests.** Rendering timings depend on renderer, display, and figure visibility. They are tagged `speed` and additionally `weak`; the runner reports them separately; a red graphics budget opens an investigation, it does not block a release on its own.

**Do not compare per-suite seconds across rounds of different colour** (§3.4 closing note). A failing verification makes the framework build a diagnostic, resolve a stack and format links, which is not free.

### 2.5 Warnings are a gate (BEST_PRACTICE §4.8)

**Exactly one warning identifier may appear in a clean run's inventory: `geo:internal:testProbe`.** Any other identifier is new and fails the gate. This needs no allow-list to maintain, which is the point.

Consequences for geoMap, all of which bite immediately because v1 warned liberally:

- Tests that provoke `geo:basemap:MaskCoversEverythingOrNothing`, `geo:basemap:MaskThresholdOutOfRange`, `geo:scalebar:ScaleVaries`, `geo:splitTracks:TracksDropped` or `geo:readCoastline:TruncatedFile` **turn that identifier off for the duration with a cleanup-based restore**, so a failing assertion cannot leave warning state altered for later suites.
- Do **not** silence an identifier where it cannot fire; an unnecessary suppression teaches the next reader that the identifier is unavoidable.
- Reuse a documented identifier rather than coining a test-only one. `geo:internal:testProbe` is the single exception and exists precisely so the gate has something to see.
- **A warning-free assertion is about all warnings, not the one you mean.** Silence the neighbours explicitly, then assert.
- **State-changing REPL experiments carry the same cleanup obligation as tests.** A snippet that disables warnings and crashes before its restore leaves the interpreter's warning state off globally; in one source project six unrelated suites then failed their warning assertions at once. Diagnostic rule earned there: *a cluster of unrelated failures sharing one symptom is session state, not code* — check the state before reading a single diff.

### 2.6 The green gate

#### 2.6.1 Definition

**A green gate means: zero failures AND every suite loaded AND no new warning identifier AND no speed budget exceeded AND the manifest verified AND the static audit exited zero.** Not "the number went up."

#### 2.6.2 The runner

One project runner, `tests/rungeoMapTests.m`, and **its count is authoritative**. Never MATLAB's directory-discovery entry point directly. Its log records: manifest verification result; which files loaded; pass / fail / incomplete per suite; per-suite seconds; the warning inventory by identifier; every speed record with its ratio and band; the category-coverage table.

**Read the log, not the pass count.**

#### 2.6.3 A passing test must leave the number it checked (§5.3)

An assertion that passes leaves no trace, so a report goes silent about exactly the measurements that went well. `GeoMapTestCase` provides `verifyAndRecord(actual, bound, label, units)`, which **qualifies the bound and returns the report record**, so an assertion cannot exist without something to log. A new record type is not a diagnostic until the report has a **section** for it.

#### 2.6.4 Predicted test count (§5.2)

Every round states its predicted point count **before** the run, reconciled three ways: tag sums, per-class sums, and pass-plus-skip. Per suite, **declared vs executed**: a grep for the test-function pattern minus the entry point must equal the executed count exactly.

The prediction exists because **a suite that silently fails to load is indistinguishable from a green run by the pass count alone.**

> **The prediction is a disposable per-round instrument. It is never written into this document and no test asserts a hardcoded total.**

### 2.7 Code rules

BEST_PRACTICE Part 4 applies in full. geoMap-specific instantiation:

| Rule | geoMap form |
|---|---|
| One authority per fact | Version string: `Contents.m` only; `README`, `geoMap.prj`, `CHANGELOG`, the HTML landing page and `info.xml` are **checked against it** by the audit, never independently maintained. The z-stack: `geo.internal.zstack` only. Projection domains: `crs.Domain` only. Colormap tables: `geo.colormaps` only. |
| One name per thing, no aliases | A renamed function has one name; the old one is deleted and the rename declared breaking. **Error identifiers are names and are not exempt** — no identifier may have a deprecated twin. |
| Consumers read fields | Nothing recovers a fact by taking a substring of a composed value. Cache keys are structs, not concatenated strings parsed back apart. |
| Metadata travels with the data | `geo.grid` carries its source and units; `geo.readCoastline` returns `meta` with source, format and **`provenance`** (`verified` \| `unverified`); `crs` carries `Radius` and model. Test for this: *if two objects from different sources were combined by mistake, would anything notice?* |
| Measured, never declared | `IsGlobalLon` is measured from the coordinate vector, never inferred from a name. A diagnostic message is a claim about the world too: derive skip and warning text from what the run actually holds. |
| Refuse / report / proceed — never degrade silently | See D-006 for the scalebar case, which this rule changed. |
| Argument validation | MATLAB `arguments` blocks only, never an ad-hoc parser object. Public name/value options resolve case-insensitively with **partial matching off**; internal struct field access is case-sensitive. |
| No printing from library code | All diagnostics through `geo.internal.log`; verbosity through `geo.internal.verbosity`. No bare `disp`/`fprintf` in `+geo`. |
| Function length | No function over ~400 lines without a written justification **in this handover**. See D-003. |
| Error identifiers | `geo:<function>:<Reason>`. **The documented identifier must equal the raised one, enforced statically by the audit**, not only by tests. |
| Validated defaults | A default changes only the allowed way: measured, then decided, then frozen — with the old behaviour left reachable and every acceptance criterion rebaselined **in the same change**. |
| Guards | A guard is not a fix (§F4). Where a cycle or a defect can be removed, remove it; a guard that hides it is worse than the failure it replaces because it looks like progress. |

### 2.8 Documentation (BEST_PRACTICE §6.8)

**Documentation is a deliverable and is verified like one. Write it in the same prompt as the code.**

#### 2.8.1 Help-text template — binding, and machine-parsed

Revision 1.1's template is superseded: it lacked the ACCURACY block and did not group identifiers by cause.

```matlab
function [out1, out2] = name(in1, in2, options)
%GEO.NAME  One-sentence purpose line, ending in a period.
%
%   SYNTAX
%     OUT1 = GEO.NAME(IN1, IN2)
%     [OUT1, OUT2] = GEO.NAME(..., Name, Value)
%
%   DESCRIPTION
%     Motivated: why this exists and why it works this way, with the
%     measured numbers backing any claim it makes. Not a restatement of
%     the syntax.
%
%   INPUTS
%     in1   (1,:) double   Degrees East. Description.
%     in2   (1,1) struct   geo.crs struct (see GEO.CRS).
%
%   OUTPUTS
%     out1  (M,N) double   Earth radii. Description.
%     out2  (1,1) struct   Fields: Alpha (1,1) double, ...; every field
%                          named, typed, dimensioned, described.
%
%   OPTIONS
%     Option1   (1,1) double   [default]   Description.
%
%   ACCURACY
%     What this function's numerical claim is, what it was measured
%     against, and the tolerance achieved. Name the oracle by its
%     register id (Part 3 of the handover). Where a measurement could
%     only be taken in MATLAB, say so and give the procedure for
%     re-deriving it.
%
%   ERRORS
%     Grouped by cause, not listed flat:
%     Input geometry:
%       geo:name:SizeMismatch      - when ...
%       geo:name:NonMonotonic      - when ...
%     Projection domain:
%       geo:name:OutOfDomain       - when ...
%
%   EXAMPLE
%     crs = geo.crs("mollweide");
%     ...runnable lines, which the doc build extracts and lints...
%
%   LIMITATIONS
%     Model assumptions, known quirks, what this function cannot do.
%
%   See also GEO.CRS, GEO.PROJECT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | <dd-Mmm-yyyy HH:MM local> | <model name/version>
%   Reviewed by a human before release. Updates append below this line.
```

The section headers are fixed because the Stage F doc builder parses them. The audit reads **the whole block**, not the first line — one source project's two gates shared a blind spot for different reasons, one because its pattern disallowed a dot and one because it read only the first line.

#### 2.8.2 Documentation sync gate

**Every change ships its documentation in the same change — all surfaces, every time.** The audit cross-reads help text, the generated HTML, the guide, `README`, `CHANGELOG` and `Contents.m`, and fails on any disagreement. It runs on a **fresh mirror after the documentation rebuild**, never before it: a gate that reads yesterday's build approves yesterday's docs.

**Count completeness in the built artefact, not in the pipeline that feeds it** (§F1). One source project parsed input descriptions into its data model for years while the renderer never read the field, and every audit stayed green because there was no text to disagree with. The Stage F builder therefore reports *arguments documented / arguments rendered*, counted in the emitted HTML.

**Every example in the help and the guide is code**: extracted and linted at build time. An example that stops running fails the build, not the reader.

**A generated manual is verified by rasterising it and looking**, never by the absence of an exception.

### 2.9 Instruments (BEST_PRACTICE §F3, §5.8)

- **No count, structure or coverage claim from an instrument written in the same session as the change it checks** — unless the instrument has been shown to fail on a known defect. Otherwise mark the claim provisional **in writing**.
- **Every audit check ships a fault-injection self-test in the same round**: it fires on a broken tree and is silent on a healthy one. A check without a fixture proving it fires is not a check.
- **The second gate must read something the first does not.**
- **Prove a mutator on a scratch copy and read the applied diff before pointing it at the tree.** A help-text migration over 94 files in one source project produced three defects, every one found by reading the diff and none by any check. One case form is not enough: a lowercase-only rename pass left the old name in every uppercase header and in one camel-case hook.
- **A one-shot mutator is not shipped.**
- **An "independent" check copied from the code under test is not independent.**

### 2.10 Diagnosis order (BEST_PRACTICE §5.45)

When a number is wrong: **configuration, then criterion, then code** — cheapest repair first.

1. **Configuration**: replay the exact frozen script, never a recollection of it. In one source project a paraphrased mask halved a validated trend (+0.71 against +1.41) and an hour went into hunting a code regression that did not exist.
2. **Criterion**: re-derive it against an external authority. A criterion is *corrected*, never widened until it passes — a criterion loosened until green is an instrument destroyed in place.
3. **Code**: last.

And **never loosen a tolerance to make a test pass — that is a finding** (§4.6). Decompose the residual into its physical contributors first.

### 2.11 Data-derived numbers carry their span (BEST_PRACTICE §3.05)

Any number derived from a dataset is written **with the span of the data it came from**, and the derivation is re-run when the span grows. For geoMap this binds: colormap percentile defaults derived from example fields; the hillshade `ZFactor="auto"` median-slope rule; any acceptance figure in the Stage F GRACE scenario.

---

## Part 3 — Oracle register (BEST_PRACTICE §3.2)

> **If you cannot name what this will be checked against that was not built here, the prompt is not ready.**

Gaps show as empty rows rather than as an absence nobody notices. **A stage may not begin with an unfilled oracle row in its scope.**

| id | Oracle | Type | Certifies | Consumed by | Status |
|---|---|---|---|---|---|
| **O1** | Snyder (1987), *Map Projections — A Working Manual*, USGS PP1395, numerical examples appendix | Published worked examples | Forward projection point values for mercator, polar stereographic, LCC, albers, azimuthal family | Stage B `reference` | ☑ **13-Aug-2026**: LCC point (0.2966785 / 0.2462112) and Mercator y(35°) confirmed exactly; polar stereographic and the LCC cone constant refuted (C-017, C-019) |
| **O2** | Snyder (1993), *Flattening the Earth* | Published table / formula | The Robinson table itself; the Hammer equal-area modification | Stage B `reference` | ☐ |
| **O3** | Analytic limits and invariants | Mathematics | Equal-area: projected area integral = 4π. Conformal: h = k, ω = 0. Conic: k = 1 on both standard parallels. Mercator: k = sec φ. | Stage B `precision`, `metamorphic` | ☑ **13-Aug-2026**: all confirmed at 5e-9 … 9.4e-8 against the handover's 1e-6 tolerances — safe, with ~10× headroom |
| **O4** | `pyproj` **3.7.2** / PROJ **9.5.1** (independent implementation, in the mirror) | Second toolkit | **All 16 projections, forward and inverse**, over dense in-domain samples | Stage 0 pre-validation, Stage B `reference` | ☑ **13-Aug-2026, live.** 15 of 16 agree to ≤ 6e-13; Robinson to 8.9e-4 only (limit L5). Configured on an authalic-radius sphere with a same-sphere geographic source CRS — **not** EPSG:4326, which would insert an ellipsoid→sphere datum shift (PV-002 method note) |
| **O5** | Natural Earth `.shp` (real third-party file) | Real data file | Shapefile reader against a file this project did not write | Stage C `reference` | ☑ **15-Aug-2026.** `ne_10m_coastline.shp` 410 957 pts / 4 133 parts; `ne_10m_ocean.shp` 446 789 / 6 822. Coordinates exact as IEEE doubles (ISEQUAL, not a tolerance) |
| **O6** | GSHHG binary `.b`, any resolution (real file) | Real data file | GSHHG reader — **the only thing that can discharge V3** | Stage C `reference` | ☑ **15-Aug-2026, V3 DISCHARGED.** Five resolutions available; crude and intermediate checked. F17 pole closure exact at −90. Microdegree residual 2.98e-8 |
| **O7** | `cdo remapcon` or `gdalwarp -r average` | Second toolkit | Conservative regrid weights and mass closure | Stage 0 mirror, Stage B `reference` | ☐ |
| **O8** | `gdaldem hillshade` (Horn) | Second toolkit | Horn gradient hillshade on a known DEM tile | Stage 0 mirror, Stage B `reference` | ☐ |
| **O9** | ETOPO 2022, 60 and 30 arc-second, BOTH the ice-surface and bedrock variants | Real data | `geo.readGrid` NetCDF path, window and stride selection; regrid at production size | Stage C `reference`, Stage D.0 | ☑ **16-Aug-2026, FILLED.** Dimension order (lon,lat) read from the file; cell-centred origin and span exact to **0**; EGM2008 vertical datum recorded. `.nc` and `.tif` of one tile disagree on row order — NCO flipped latitude |
| **O10** | MATLAB built-in `topo.mat` (`coast.mat` **absent from R2026a**) | Shipped reference data | Builtin grid path; the 0–359 longitude convention case | Stage C `reference`, Stage D.0 | ☑ **16-Aug-2026, FILLED for `topo.mat`.** Axes derived from `topolatlim`/`topolonlim` and the array size, not the legend's corner; four named places land correctly. `coast.mat` does not ship with R2026a, so that half stays open rather than pretended |
| **O11** | A published GRACE mascon EWH trend map (e.g. JPL RL06 mascon, any release) | Real scientific product | End-to-end figure sanity: sign, magnitude and pattern of a known signal (Greenland, West Antarctica, north India) | Stage F acceptance | ☐ Matthias to name the release |
| **O12** | v1 `geoImagescToolbox` itself, as installed | Prior implementation | **Only** the F1–F18 defect probes (V4). Not an authority on correctness — it is the thing being replaced. | Stage 0 probes | ☐ |

**O11 carries a span (§2.11).** When the release is named, the span of the data behind it is written next to the expected numbers, and the expectation is re-derived when a newer release supersedes it.

---

## Part 4 — Decision log (BEST_PRACTICE §6.4)

*What was chosen, what was rejected, the number or reason that decided it — **and the condition whose change invalidates it**. The trigger field is what makes this a log rather than a memoir: in one source project three decisions were reversed, all three correct when taken and wrong later, and nothing prompted the re-read.*

**Checked at every stage boundary (OB-6).**

| id | Date | Decision | Rejected alternative | Deciding reason | **Re-read trigger** |
|---|---|---|---|---|---|
| D-001 | 23-Jul-2026 | Spherical Earth throughout, authalic radius 6371.0072 km | Ellipsoidal projections | ≤0.3% geometric error, invisible at figure scale; ellipsoidal geodesy already lives in `geodesyToolbox` | A user needs survey-accurate output, **or** any consumer starts using projected coordinates for computation rather than display |
| D-002 | 23-Jul-2026 | Value structs (`geo.crs`, `geo.grid`, …), not classdef | Handle or value classes | Save/load simplicity, array-idiomatic, no copy-semantics surprises for numerical users | The structs acquire behaviour (methods, validation on assignment) rather than just fields, **or** struct-field typos become a recurring defect class |
| D-003 | 13-Aug-2026 | `geo.project` / `geo.unproject` stay monolithic **if under 400 lines each**; otherwise split to `+geo/+internal/+proj/<name>.m`, forward and inverse together per projection | Per-projection files from the start | §4.7's 400-line rule; a single dispatch keeps the domain logic in one place while it fits | Either file crosses 400 lines at any checkpoint — the split then happens in that same round, not later |
| D-004 | 13-Aug-2026 | Test harness, mirror and audit ship **before** the first function (Stage 0) | Harness last, as revision 1.1 had it | §3.4.2: one shared timing helper for the whole project, and no budget may be written before its instrument exists. §5.8: every instrument ships its fault-injection self-test in the same round | Never — this is a consequence of a paid-for rule |
| D-005 | 13-Aug-2026 | Python mirror is a **shipped deliverable** with one owner per kernel | Ad-hoc per-stage verification scripts | §2.3: four scripts re-deriving the same three kernels gave four chances to drift, and a drifted mirror makes evidence quietly wrong rather than merely repetitive | Tier A becomes permanent **and** the mirror stops producing findings for three consecutive stages — then it is re-read, not automatically dropped |
| D-006 | 13-Aug-2026 | `geo.scalebar` **draws and reports**: it warns, records the measured scale variation in returned metadata, and draws anyway. **Confirmed on measurement 13-Aug-2026** | Revision 1.1's refusal-unless-`Force` | §4.5, now with a number: at the 1.05 trigger a refusing gate would refuse on **6 of 14 projections for a 10°×10° regional map and 12 of 14 at continental scale**. A gate that refuses the majority of realistic maps is not protecting anyone. The threshold survives as a *warning* trigger | The gate is reported as noise by a user, **or** a projection class is found where the variation figure is meaningless rather than merely large |
| D-007 | 13-Aug-2026 | Three-file split: `HANDOVER.md` / `RECORDS.md` / `BEST_PRACTICE_v4.md` | Single handover, as revision 1.1 | §6.1, measured: narrative records reached 50% of one source handover, growing ~4600 tokens per package, projecting ~190k tokens that every fresh session pays in full | `RECORDS.md` starts carrying status, **or** the handover starts carrying narrative — either means the split has failed and needs re-taking, not patching |
| D-008 | 13-Aug-2026 | One package per confirming run under Tier A; two or three independent leaves under Tier B | Uniform batching | §2.4: batching was justified by the cost of a human round-trip. Tier A removes that cost. Marked **(proposed)** in BEST_PRACTICE — treat as hypothesis | Tier is established (V6). If one-per-round under Tier A has not caught anything a batch would have missed within three stages, that is a finding about the rule |
| D-009 | 13-Aug-2026 | Analytic Horn hillshade replaces MATLAB `light`/`gouraud` | Keeping OpenGL lighting | F9: renderer-dependent output and the `FaceAlpha` × `shading interp` interaction. Deterministic, testable against O8, export-identical | A MATLAB release makes lighting deterministic and export-stable **and** a measured comparison shows the analytic path is materially worse |
| D-010 | 13-Aug-2026 | The mirror keeps **two separate modules**: `kernels.py` (Snyder formulas, mirroring the MATLAB) and `oracle.py` (pyproj/PROJ, independent) | Revision 2.0 §2.2's "thin wrappers over pyproj" | PV-001. Wrapping PROJ collapses two jobs: a MATLAB disagreement could not then distinguish "MATLAB's iteration is wrong" from "the algorithms differ", and the round-trip suite would check PROJ against itself | PROJ gains a documented spherical Snyder-equivalent mode, **or** maintaining two kernels produces a drift defect — either forces a re-read |
| D-011 | 13-Aug-2026 | Every parameter the oracle consumes is **written explicitly** into the PROJ string; no PROJ default is relied upon | Relying on documented defaults | PV-003: `+proj=wintri` silently defaults `+lat_1` to 0, making it a different projection. The symptom was a clean `0.18·λ` offset that looked exactly like a kernel bug | Never — this is a consequence of a paid-for finding |
| D-012 | 15-Aug-2026 | **Files transfer one at a time, verified on arrival by byte count AND byte-sum.** Bulk archive transfer is banned | A base64 tarball in 60 kB chunks | A chunk arrived as 55,317 of 60,000 bytes with a PNG terminator glued on — content never in the payload. Untarred, that would have produced a corrupt tree and a round spent hunting a phantom bug. Byte count alone is insufficient: it cannot see a substitution | The transfer channel changes, **or** a `git` path between the two machines becomes available — which would make transfer verification redundant |
| D-013 | 15-Aug-2026 | **Claude pushes branches; a human opens the PR and merges.** No credential is ever handled by Claude | Extracting the token from Git Credential Manager to call the GitHub API | A credential in a keychain is not Claude's to take out, whatever the convenience. `git push` uses it without exposing it; PR creation does not | ~~`gh` is installed and authenticated by the owner~~ **TRIGGER FIRED 15-Aug-2026, same day.** `gh` 2.97.0 was installed and authenticated by the owner. **Closed, superseded by D-014.** This is the decision log working as designed: the condition was written down, it changed, and the re-read happened because it was written down |
| D-014 | 15-Aug-2026 | **Claude branches, commits, pushes and opens the PR. Only Matthias merges.** | Claude opening nothing (D-013), or Claude merging as well | D-013's own trigger fired. `gh pr create` works through the credential helper with **no token visible to Claude**, which is the thing D-013 was protecting; extracting a credential from a keychain remains out of the question. The merge stays with Matthias because that division is what makes the loop trustworthy, and it is not a consequence of tooling | Claude is ever asked to merge, **or** a change reaches `main` without a human having read it |
| D-015 | 15-Aug-2026 | **Oracle O7 is corroboration, not authority.** Conservative-regrid weights are certified against an analytic affine-field oracle, carrying a degree-weighted counterfactual that proves the check discriminates | Accepting `gdalwarp -r average` as the O7 the register named | Measured: it differs from a conservative remap by **21% of signal RMS globally**. An oracle that disagrees with the truth by a fifth of the signal certifies nothing, and adopting it would have made every later regrid agreement meaningless | `cdo remapcon` becomes installable, **or** a second independent conservative implementation appears |
| D-016 | 15-Aug-2026 | **A constructed speed fixture compares two sides doing the same work on the SAME array**, sized so one pass clears a measured floor | Two array sizes (4N against N), as the harness first had | PV-035: two sizes are two memory regimes as soon as one leaves cache. The identical commit read 5.536 and 4.885 on a 1-core runner against 3.84 on the 16-thread box, and the twin CI triggers disagreed with each other. **Modelling the confound failed** — the fixed term is a difference of two nearly equal times, so its relative size is badly conditioned and read +0.98% here and −70.3% there (PV-036). Removing the confound worked | A budget genuinely needs two different sizes — then the memory regime must be measured and stated, never assumed |
| D-017 | 15-Aug-2026 | **`crs.Domain` carries the cosmetic clip AND the mathematical singularity, with a flag saying whether they differ.** The clip values stay v1's | One number, as §7.3 listed; or dropping the clip and declaring only the singularity | PV-038: three of the four clips are 6° to 26° inside the singularity, and F12's complaint was never that v1 clipped — it was that nothing said which limits were mathematics and which were taste. One number reproduces that defect with better manners. Keeping v1's clip VALUES means a v2 figure covers the same extent as the v1 figure it replaces | A user needs the rim a cosmetic clip hides, **or** Stage B measures a distortion criterion that can replace an inherited number with a derived one |
| D-018 | 15-Aug-2026 | **`geo.greatCircle` takes Nx2 `[lon lat]` pairs**; the destination form takes `Bearing` and `Distance` by name | §7.3's `geo.greatCircle(lon1,lat1,lon2,lat2,…)` | PV-042: four positional arguments breaks the arity cap of three, written because `geoNorthArrow` took fifteen (F7). A rule with an exception written for the first function to find it inconvenient is not a rule. Pairing also makes the two arguments symmetric and unswappable-by-accident, which four loose numbers are not | The arity rule itself is revisited, **or** a caller reports the paired form as awkward in practice |
| D-019 | 15-Aug-2026 | **`geo.splitTracks`' `SpatialJumpThreshold` is in kilometres**, measured with `geo.greatCircle` | v1's `hypot(diff(lon), diff(lat))` in degrees, carried over unchanged with its option name | A degree of longitude at 70 N is a third of one at the equator, so v1's threshold needed a different value per latitude band and silently meant different things at different latitudes. **This changes the meaning of a carried-over option name**, which is exactly the kind of change §2.7 says must be declared rather than slipped in | A user's v1 script is found to depend on the degree-space figure — then the change needs a migration note in the Stage F README, not a reversal |

---

## Part 5 — v1 defect findings, and the checks that replace them

*Per BEST_PRACTICE §6.1: **a trap that has become a check does not stay prose.** Revision 1.1 carried eighteen paragraphs of review narrative. Each is compressed here to one line and a pointer at the check whose self-test reproduces it. The full review narrative moves to `RECORDS.md` §R-001.*

**Every row is a claim, and V4 says most are unmeasured.** Stage 0's `records/v1_defect_probes.m` runs one probe per row against the installed v1 tree. **A finding that does not reproduce is deleted from the design rationale**, not quietly kept — a design justified by a defect that does not exist is a design without a reason.

| id | Defect in v1 | Sev | Probe (Stage 0) | Replaced by check |
|---|---|---|---|---|
| F1 | `range()` is a Statistics Toolbox function, called at ~15 sites; the "no toolboxes required" claim is false |  | grep + `which -all range` on a stats-free path | Stage 0 audit: forbidden-function scan over `+geo`, self-tested by planting a `range()` call |
| F2 | Robinson receives unwrapped `LON - lon0`; lon=359, lon0=0 → x ≈ +3.0 R instead of −0.008 R |  | run v1 `geoProject(359,10,"robinson",0,0)` | Stage B `contract` + `metamorphic`: longitude-shift equivariance |
| F3 | Mercator clamps to ±85° — silently relocating data — where every other projection returns NaN |  | run v1 `geoProject(0,87,"mercator",0,0)`, compare against lat 85 | Stage B `contract`: NaN outside `crs.Domain.LatLimit`, all 16 |
| F4 | `geoResampleGrid` is not longitude-periodic; seam queries hit nearest-neighbour extrapolation |  | v1 resample of a 0:359 grid queried at lon = −0.5 | Stage B `precision`: seam test against the two-column mean |
| F5 | No inverse projection anywhere |  | structural | Stage B: `geo.unproject`, and the round-trip suite that only exists because of it |
| F6 | Six local functions duplicated across the main plotters |  | text comparison of the six | Stage 0 audit: duplicate-local-function detector |
| F7 | Projection state as loose positional args; `geoNorthArrow` takes 15 |  | `nargin` inspection | Stage 0 audit: max positional arity ≤ 3 for public functions |
| F8 | `geoImagesc` is 3413 lines / ~30 locals; Track and Points ~80% identical |  | line counts | Stage 0 audit: 400-line rule (D-003); Stage E orchestration-purity test |
| F9 | Renderer-dependent OpenGL hillshading |  | render + export the same figure two ways, compare | Stage 0 audit: no `light`/`material`/`shading interp` in `+geo`; Stage B `reference` vs O8 |
| F10 | `geoPercentileRange` uses `round(p/100*n)` — biased, non-interpolated |  | v1 `geoPercentileRange([1 2],[50 50])` | Stage B `precision`: type-7 references |
| F11 | Variable `clim` shadows `clim()`, forcing deprecated `caxis` |  | grep | Stage 0 audit: shadowed-builtin scan |
| F12 | Domain clipping by magic numbers, serving as both math guard and cosmetic clip |  | grep for the literals | Stage 0 audit: no bare `cosc <` literals; domains only from `crs.Domain` |
| F13 | Coastline readers grow arrays in the record loop — O(N²) |  | timing ladder at 2 record counts | Stage 0 audit: `%#ok<AGROW>` ban in `+geo`; Stage C `speed` |
| F14 | No caching: coastlines re-read and re-projected every call |  | timing two identical v1 calls | Stage C `speed`: cold/warm ratio ≥ 10 |
| F15 | `appdata` + manual `SizeChangedFcn` chaining — global mutable state |  | structural | Stage 0 audit: no `setappdata`/`getappdata` in `+geo`; Stage D listener-based layout |
| F16 | `geoNiceGraticuleStep` snaps to nearest, overshooting the target. **Measured 15-Aug-2026: differs from the ceiling policy at 4 of 13 spans; worst is 10 lines against a target of 6, at span 45°.** The earlier wording "3 or 11 lines" was an illustration nobody had measured and is withdrawn (C-033) |  | v1 call over a span **ladder**, not one span — at span 120 the two policies happen to agree exactly, and testing only there refuted the defect (PV-030) | Stage B `contract`: ceiling policy, asserting both rejected neighbours |
| F17 | GSHHG Antarctica pole closure unhandled |  | needs O6 | Stage C `reference`, blocked on V3 |
| F18 | Tests are smoke tests: no reference values, no round-trips, no property tests, no budgets |  | read `test_geoImagesc.m` | This entire document's Part 2.3 |

**Deviations from v1 that are kept, and why** (a design rationale, not a defect list): spherical model (D-001); pure-`fread` binary parsers, which are the no-toolbox constraint's whole point; the Robinson table with PCHIP, since Robinson *is* its table; Newton–Raphson Mollweide; NaN-as-gap end to end; figures only, no GUI. **These are not re-litigated per stage.** A stage that proposes to change one raises it as a decision against Part 4.

---
## Part 6 — The v2 design

### 6.1 Design logic

1. **One CRS, defined once.** All projection state in a single validated struct; forward, inverse, scale factors and domain all read from it.
2. **Layers with strictly downward dependencies.** L0 data model → L1 math → L2 I/O → L3 cartographic elements → L4 fronts. No layer calls upward; L1 never touches graphics.
3. **Composability over configuration.** The fronts are conveniences, not the API. Every visual element is a public function `(ax, crs, …) → handles`, safe to call on an existing map, draw-order-independent (z-levels fixed by `geo.internal.zstack`), and removable via its returned handles.
4. **Determinism.** No renderer-dependent appearance (D-009); no unseeded randomness; parallel results equal serial bitwise where floating-point order permits and to 1e-12 otherwise, asserted rather than assumed.
5. **The math is the test surface.** Everything numerical lives in L1 as pure array functions, checked against the oracle register. Graphics tests check object existence, properties and geometry — never pixels.
6. **GRACE-first defaults**: symmetric diverging limits for signed fields, equal-area default for global thematic maps, conservative regridding available, stippling and polygon fields first-class.

### 6.2 The z-stack

Fixed, and defined in exactly one place — `geo.internal.zstack` (§2.7, one authority per fact). No element hard-codes a level.

```
z = 0      raster surface (truecolor, hillshaded)
z = 1      contours
z = 2      polygon fields (mascons/basins), stipple
z = 3      graticule
z = 4      coastline, rivers, AOI outline
z = 5      tracks, points, labels
z = 6      frame (neatline)
z = 7+     scale bar, north arrow, insets, colorbars (separate axes)
```

### 6.3 Function set

30 public functions plus internals, replacing v1's 33.

**L0 — data model**

| Function | Replaces | Contract |
|---|---|---|
| `geo.crs` | the six loose args threaded everywhere | Validated projection spec: name, centre, hemisphere, parallels, radius, cone constant, **queryable domain**. |
| `geo.grid` | loose `(lon,lat,Z[,topo])` | Validated grid struct; monotonicity, size consistency, lat range, wrap convention, provenance. |
| `geo.track` | loose `(t,lon,lat,obs)` | Validated track struct; NaN gaps normalised; optional time. |
| `geo.points` | loose `(lon,lat,obs)` | Validated point set; optional size and label data. |

**L1 — core math (pure, no graphics)**

| Function | Replaces / status | Contract |
|---|---|---|
| `geo.project` | `geoProject`, fixing F2, F3, F12 | NaN outside the declared domain, all projections including Mercator. Robinson wrap fixed. Adds `"hammer"` as the 16th. |
| `geo.unproject` | **new**, F5 | Inverse for all 16. Closed forms where they exist; Robinson by monotone table inversion; Winkel Tripel by 2-D Newton. |
| `geo.scaleFactors` | **new** | Point scale factors h, k, area scale, max angular deformation ω. Powers distortion diagnostics and the scalebar's reported variation (D-006). |
| `geo.wrapLongitude` | `geoUnwrapAntimeridian` (part) | The only wrap in the toolbox. |
| `geo.splitAntimeridian` | `geoUnwrapAntimeridian` + `geoInsertNaNBreaks` + 3 ad-hoc copies | The only split in the toolbox; adds edge-touching interpolation. |
| `geo.regrid` | `geoResampleGrid`, fixing F4 | Periodic bilinear, **conservative** (area-weighted, mass-closing), nearest. Optional thread-parallel tiles. |
| `geo.hillshade` | OpenGL lighting, D-009 | Horn gradients with the spherical `cos(lat)` metric; single or multidirectional; returns shade ∈ [0,1]. |
| `geo.quantile` | `geoPercentileRange`, fixing F10 | Type-7 interpolated quantiles. |
| `geo.symmetricLimits` | **new** | Symmetric-about-zero limits for signed anomaly fields. |
| `geo.niceTicks` | `geoNiceTicks` + `geoNiceGraticuleStep`, fixing F16 | Merged; ceiling-snap policy. |
| `geo.greatCircle` | scattered scale-bar math | Haversine distance, bearing, destination; radius from `crs`. |
| `geo.colormaps` | `geoColormapPreset` + `geoDiscretizeColormap` + `geoMapToTruecolor` | Presets, discretisation, truecolor mapping, shade composition. |

**L2 — I/O and caching**

| Function | Replaces | Contract |
|---|---|---|
| `geo.readCoastline` | the four `geoCoastlineFrom*` | One dispatcher; format auto-detect with override; cell-accumulate (F13); GSHHG Antarctica pole closure (F17); returns NaN-separated Nx2 plus metadata **including provenance**. |
| `geo.readGrid` | topography-reading locals buried in `geoImagesc` | GeoTIFF-worldfile, NetCDF, `.mat`, raw arrays → `geo.grid`. |
| `geo.cache` | **new**, F14 | Session cache of parsed and per-CRS-projected coastlines; LRU-bounded; `geo.cache("clear")`. |

**L3 — cartographic elements**, all `(ax, crs, …) → handles`

| Function | Replaces |
|---|---|
| `geo.basemap` | the raster core of `geoImagesc`/`Track`/`Points` — the shared engine that removes F8's duplication |
| `geo.graticule` | `localAddGraticule` + label module, now inverse-projection based |
| `geo.frame` | `geoSegmentedFrame` + `geoAttachFrameResize` |
| `geo.coastline` | `localAddCoastline` ×3, plus the river and AOI paths, via a `Kind` option |
| `geo.scalebar` | `geoScaleBar` — now draws and reports (D-006) |
| `geo.northarrow` | `geoNorthArrow` (15 positional args → 2) |
| `geo.colorbar` | `geoGmtColorbar` + two half-colorbar clones + the dual-scale variant |
| `geo.inset` | `localAddMapInset` + the registry plumbing |
| `geo.overlayTrack` | track foreground of `geoImagescTrack` |
| `geo.overlayPoints` | point foreground of `geoImagescPoints` |
| `geo.overlayContours` | `localAddContours` |
| `geo.overlayPolygons` | **new** — mascon/basin polygon fields |
| `geo.stipple` | **new** — significance masking |

**L4 — fronts and support**

| Function | Replaces |
|---|---|
| `geo.map` | `geoImagesc` |
| `geo.trackmap` / `geo.pointmap` | `geoImagescTrack` / `geoImagescPoints` |
| `geo.timeseries` | `geoImagescTimeSeries` |
| `geo.panel` | `geoImagescMulti` |
| `geo.splitTracks` | `geoSplitTracks` |
| `geo.region` | `geoAreaOfInterest` |
| `geo.export` | the three export tails, plus batch mode |

**Internals** (`+geo/+internal`, not public API): `layout` (resize and collision manager, replacing five v1 plumbing functions), `zstack`, `log`, `verbosity`, `mustBeCrs`, and — under D-003 if triggered — `+proj/<name>.m`.

### 6.4 Workflow

```matlab
% One call — the common case
crs = geo.crs("mollweide", CenterLongitude=0);
G   = geo.readGrid("ewh_trend.nc");
[fig, ax, H] = geo.map(G, crs, Divergent=true, ...
        Coastline="builtin", Stipple=sigMask, Export="fig3.pdf");

% Composed — the power case, identical machinery (asserted by the
% "composed equals front" integration test)
[fig, ax] = geo.basemap(G, crs, Hillshade="multi");
geo.coastline(ax, crs);
geo.overlayPolygons(ax, crs, masconPolys, masconVals);
geo.graticule(ax, crs); geo.frame(ax, crs);
geo.colorbar(ax, Style="gmt", Label="EWH trend (cm/yr)");
geo.export(fig, "fig4.pdf", Width=17.0, Units="centimeters");
```

Data flow: files → L2 readers → L0 structs (validated once) → L1 math (pure arrays) → L3 elements (graphics) → L4 fronts → `geo.export`. **No function re-validates what a struct already guarantees**, and each documents that it trusts its inputs.

### 6.5 Performance strategy

1. **Algorithmic first**: cell-accumulate readers (F13), cached parsed and projected coastlines (F14), analytic hillshade instead of per-frame lighting, `griddedInterpolant` reuse.
2. **Vectorisation**: all L1 kernels elementwise or array-wide; the `vectorisation` test category exists to keep it true.
3. **Optional parallelism**, never a dependency: tile-parallel conservative regrid; `parfeval` batch export; optional background coastline parsing. `UseParallel="auto"` uses an existing pool and never starts one. **Serial and parallel results are asserted equal** — MATLAB graphics is serial, so the Parallel Computing Toolbox buys nothing for a single figure, and the design says so rather than implying otherwise.
4. **Budgets are ratios** (§2.4), and they are regression tripwires, not benchmarks. A red budget opens an investigation; a threshold is re-baselined only with a Change Log entry and a measurement.

---
## Part 7 — Session tasks

### 7.0 The standing preamble

**Paste this once at the top of every session, with `HANDOVER.md`, `BEST_PRACTICE_v4.md` and the current tree attached.** Then paste the stage task from §7.2 onward.

> **Note on a reversal.** Revision 1.1 made every stage prompt self-contained, restating the conventions in each. BEST_PRACTICE §7.1 forbids exactly that — *"one authority, so a rule is never restated in a prompt where it can drift"* — and §4.1 forbids the duplication it creates. The prompts below therefore **name the binding sections instead of copying them**. This is a deliberate reversal, recorded as Change Log entry C-006.

```
You are an expert MATLAB programmer and a specialist in cartographic
visualisation and GRACE-like satellite gravimetry, working on geoMap v2 —
a pure-MATLAB (R2026a, base MATLAB only) toolbox succeeding
geoImagescToolbox v1. Think step by step and motivate every answer: why,
not just what.

READ HANDOVER.md FIRST. Its rules, ledger, design, oracle register and
decision log are binding. The task below names the sections that matter.
BEST_PRACTICE_v4.md sits above it and is binding without exception; where
the handover appears to relax one of its rules, the handover is wrong.
Do NOT read RECORDS.md up front — it is evidence for when you need it,
not background.

EXECUTION TIER FOR THIS SESSION: <A: a live MATLAB session is reachable
over the very folder the deliverable is built from — its run is ground
truth> / <B: no interpreter here — pre-validate every asserted number in
the Python mirror, Matthias's run is the gate>. Declare it in your first
line; do not assume it.
  Under A: static-check every changed file (codeIssues), then run the one
  project runner over that same folder, long suites through a background
  call with a status file, and read the log rather than the pass count.
  Under B: pre-validate in mirror/geomap_mirror/ against exact or
  independent formulae, validate structurally and with the static audit,
  and ship the whole tree as one artefact with a regenerated MANIFEST.txt.

REUSE THE MIRROR rather than re-deriving anything a previous stage already
mirrored; add to it what yours mirrors; record in mirror/LIMITS.md what it
cannot see. Where the two disagree, MATLAB is right by definition.

VALIDATE THE SPECIFICATION BEFORE IMPLEMENTING IT. If this task's
mathematics, tolerance, reference value or acceptance test is wrong, that
is a finding: report it with its measurement BEFORE writing code. Handover
debt V1 says every number in that document is model-derived and unmeasured
— treat them all as claims to check, not values to trust.

DELIVER TOGETHER: the code, its tests, and its documentation. Tests cover
contract, reference, precision, speed, robustness, vectorisation and
metamorphic properties as applicable (HANDOVER §2.3); name any category you
do not ship and why it is impossible rather than inconvenient. Speed
budgets are relative, paired inside each repeat, rotated, and reported as
a median of per-repeat ratios with the measured band (HANDOVER §2.4) —
through the one shared helper, never by hand.

BINDING ON EVERY TASK: one authority per fact, one name per thing, no
aliases (error identifiers included); full help text to the HANDOVER §2.8.1
template, with the ACCURACY block and errors grouped by cause; identifiers
geo:<function>:<Reason>, documented equal to raised; arguments declared in
MATLAB arguments blocks, never an ad-hoc parser; full vectorisation; no
printing from library code; nothing degrades silently.

STATE EVERY ASSUMPTION YOU HAD TO MAKE. Where a deliverable says "port
from v1", START FROM THAT FILE and adapt it to the new contract — do not
rewrite verified code from scratch.

SATISFY THE DEFINITION OF DONE written at the head of the task before
declaring it complete. A task is done on a green gate, not a green subset.

END WITH A WRAP: what changed and what it was measured against; the
predicted test-point count FOR THIS ROUND (per-round instrument, never
written into the handover); every pre-validation finding with its
measurement; every assumption; and anything not done, with the reason.
Give me the ledger row and any decision-log or debt-table edits as text I
can paste into HANDOVER.md.
```

### 7.1 Running a session

1. Paste the preamble, then the stage task. Attach `HANDOVER.md`, `BEST_PRACTICE_v4.md`, the current tree, and the v1 reference files the task names.
2. **Pre-validation comes back before code.** Expect findings; a stage that reports none has probably not looked.
3. Run locally; paste the log back **as an uploaded file** for long output (large pastes are lost in transit).
4. Iterate on failures without re-explaining the design.
5. Update the ledger, debt table and decision log from the wrap. **This document is the only place status lives.**

**Batching (D-008):** one stage per session. Stages B and D use their internal checkpoints — consecutive turns in one chat, each with its own confirming run, so a red run points at one checkpoint rather than nine functions.

**Do not mix a substantial change with unrelated repairs** (§6.6). A stretch of one source project reads: real work, fix what the real work broke, fix the fix, fix the instrument added to check the fix. Give a substantial change its own session.

---

### 7.2 STAGE 0 — Harness, mirror, audit, runner

*New in revision 2.0. Revision 1.1 put this last; §3.4.2 and §5.8 require it first — no speed budget may be written before its shared timing helper exists, and no audit check may ship without a fault-injection self-test in the same round. Recorded as D-004.*

**1. What is being built.** The instruments: the test base class with the project's single timing helper, the project runner, the static audit with its self-tests, the Python mirror skeleton, the manifest generator, and the probes that measure whether the v1 defects this whole design rests on are real.

**2. Depends on.** Nothing. It depends on *this document* and BEST_PRACTICE_v4.

**3. Deliverables.**

1. `tests/GeoMapTestCase.m` — base class providing:
   - figure factory (`'Visible','off'`) with teardown-based close;
   - tolerance constants as properties: `TolRoundTrip = 1e-9`, `TolArea = 1e-3`, `TolMass` (**set from the mirror measurement in deliverable 6, not from this document — see V7**), `TolGeom = 1e-6`, `TolRef` (per-oracle, table-driven);
   - `rng(42,'twister')` fixture before every test;
   - shared CRS fixtures: `crsEq`, `crsMercator`, `crsMollweide`, `crsLcc3345`, `crsPolarNorth`, `crsRobinson`, `crsHammer`;
   - `canUseParallelPool()` — true only if a pool **already exists**; it must never start one;
   - `assumeSpeedTestsEnabled()` reading `GEOMAP_SKIP_SPEED`;
   - `suppressWarning(id)` — disables an identifier with a cleanup-based restore, for §2.5;
   - `verifyAndRecord(actual, bound, label, units)` — qualifies the bound **and returns the report record**, so an assertion cannot exist without something to log (§2.6.3).
2. **`GeoMapTestCase.assertRatioBudget(fcnA, fcnB, budget, expected, label, opts)`** — the project's only timing instrument, implementing §2.4.1 exactly: untimed warm-up per point; both points timed inside one repeat; **rotation** of which is timed first; repeat count a multiple of the number of points, default 15; statistic formed per repeat, median of those; failure message quoting the per-repeat `min .. max` band; returns a record carrying ratio, band, both absolute times and a machine tag. Options: `Repeats`, `InnerBatch` (for points under ~1 ms), `Weak` (tags a budget as weak evidence — graphics).
3. `tests/rungeoMapTests.m` — the one runner. `rungeoMapTests()` = contract + reference + precision + robustness + vectorisation + metamorphic; `("all")` adds speed; `("speed")` speed only; `("StageB")` name filter. **Verifies `MANIFEST.txt` before running anything** and reports missing, truncated or altered files at the top of the log. Log records: manifest result, which files loaded, pass/fail/incomplete per suite, per-suite seconds, warning inventory by identifier, every speed record with ratio and band, and the per-function category-coverage table. Returns a logical pass flag.
4. `tools/geoMapAudit.m` — the static audit. Exits zero before any ship; it is a gate, not a report. Checks, each shipping a fault-injection fixture that proves it fires on a broken tree and is silent on a healthy one:
   - forbidden functions in `+geo`: `range`, `prctile`, `caxis`, `eval`, `evalin`, `assignin`, `setappdata`, `getappdata`, `findobj`, `light`, `material`, `shading` (F1, F9, F11, F15);
   - shadowed builtins as variable names, `clim` specifically (F11);
   - `%#ok<AGROW>` and array growth in loops (F13);
   - bare `disp`/`fprintf`/`warning`/`error` outside `geo.internal.log` and the documented identifier scheme;
   - **documented identifier equals raised identifier**, parsed from the ERRORS block of the help and from the `error(...)` calls (§2.7);
   - help block completeness against the §2.8.1 template, **reading the whole block, not the first line**;
   - function length > 400 lines without a handover justification (D-003);
   - public positional arity ≤ 3 (F7);
   - duplicate local functions across files (F6);
   - version-string agreement between `Contents.m` (the authority) and every file repeating it;
   - per-function test-category coverage against `tests/EXEMPTIONS.md`, enforcing that `contract` is never exempted for a function with an `arguments` block.
5. `tools/makeManifest.m` — regenerates `MANIFEST.txt` (path, line count, SHA-256) over the whole tree.
6. `mirror/geomap_mirror/` — the Python mirror package, with `README.md` stating the one-owner rule, and `LIMITS.md` seeded with the four known blind spots in §2.2. Stage 0 populates:
   - `projections.py` — **owner of all 16 forward and inverse**, thin wrappers over `pyproj` where PROJ has the projection, plus own implementations where it does not (Robinson's table, Hammer, Winkel Tripel), with the two cross-checked against each other;
   - `references.py` — **computes every reference value this handover asserts** (O1, O2, O3) and writes `mirror/out/reference_values.json`. This discharges V1. Any disagreement with the handover's quoted value is a finding reported before any MATLAB is written;
   - `regrid.py` — conservative weights, and the **measurement of the achievable mass-closure floor** at 2161×4321 → 181×361 in double precision, which sets `TolMass` (V7);
   - `hillshade.py` — Horn reference against O8;
   - `scale.py` — measures scale variation across representative extents for all 16 projections, producing the table that settles D-006 / V8.
7. `records/v1_defect_probes.m` — one runnable probe per row of Part 5, run against the installed v1 tree, writing `records/v1_probe_results.md` (V4).
8. `records/v1_option_inventory.md` — mechanical extraction of every `options.` field from v1's five front functions, mapped to a v2 destination or marked dropped with a reason (V9).
9. `buildfile.m` — `buildtool` tasks: `test`, `testall`, `check` (audit), `mirror` (runs the Python pre-validation and diffs its JSON against the last recorded values), `doc`, `package`; `package` requires `testall`, `check` and `doc`.
10. `tests/EXEMPTIONS.md` seeded with the four rows in §2.3.2.
11. `tests/TestStage0_instruments.m` — the self-tests for deliverables 1–5.

**4. Accuracy requirement.** `assertRatioBudget` must reproduce a known ratio on a synthetic pair whose true ratio is constructed (e.g. a loop of exactly 4× the work) to within **10%** across 15 repeats, and its median-of-per-repeat-ratios must differ from a deliberately wrong ratio-of-medians implementation on a drifting fixture by a **measurable, reported margin** — the instrument must be shown to detect the thing it exists for. 10% is chosen because §3.4.6 measured 10.2% spread at 15 repeats; a tighter figure would be asserting below the instrument's own noise.

**5. The oracle.** O4 (`pyproj`) for the mirror's projections; O7 and O8 for regrid and hillshade; O12 (v1 itself) for the defect probes only. `assertRatioBudget` is checked against a **constructed** ratio — the oracle is arithmetic, not another timer.

**6. Test categories shipped.** `contract` and `robustness` for the harness functions; `precision` for `assertRatioBudget`'s known-ratio recovery; `reference` for the mirror's agreement with O4/O7/O8. Exempt: `speed` for the harness itself (timing the timer — §3.4.5, and it would be circular); `metamorphic` and `vectorisation` for tooling (no batched form, no invariance to state) — recorded in `EXEMPTIONS.md` with these reasons.

**7. Definition of done.**
- `geoMapAudit` exits zero on the tree and **each of its checks has been shown to fire** on its own broken fixture.
- `rungeoMapTests` runs, reports a manifest verification, and its log carries every section listed in deliverable 3.
- `mirror/out/reference_values.json` exists and **every value this handover quotes is either confirmed or reported as a finding.**
- `records/v1_probe_results.md` exists; any Part 5 row that failed to reproduce is reported for deletion.
- `TolMass` and the scale-variation table are **measured**, not assumed.
- Ledger row, debt rows V1/V4/V5/V7/V8/V9 and the decision log updated in the wrap.

---

### 7.3 STAGE A — L0 data model and longitude topology

**1. What is being built.** The validated value structs every later layer trusts, plus the two functions that are the toolbox's only authority on longitude wrapping and antimeridian splitting.

**2. Depends on.** Stage 0 green. `geo.wrapLongitude` and `geo.splitAntimeridian` are nominally L1 but have zero dependencies and are required by the L0 constructors — **this is the only deliberate layer-boundary crossing in the staging**, and it is recorded here rather than discovered later.

**3. Deliverables.**

1. **`geo.crs(name, options)`** — `name` one of the 16: `equirectangular`, `mercator`, `transversemercator`, `robinson`, `mollweide`, `hammer`, `winkeltripel`, `sinusoidal`, `lambert`, `stereographic`, `orthographic`, `azimuthalequidistant`, `gnomonic`, `polarstereographic`, `lambertconformal`, `albers`. Options: `CenterLongitude` `[0]`, `CenterLatitude` `[NaN]` (resolved per projection class), `Hemisphere` `["north"]`, `StandardParallel` `[NaN]`, `StandardParallel2` `[NaN]`, `Radius` `[6371.0072]` km (authalic).
   Output fields: `Identity="geo.crs"`, the resolved parameters, `ConeConstant`, `Class` (`cylindrical`|`pseudocylindrical`|`azimuthal`|`conic`), `IsWholeWorld`, and **`Domain`** — `MaxAngularDistanceDeg` (NaN unlimited; stereographic 154, gnomonic 84, azimuthalequidistant 178, orthographic 90) and `LatLimit` (mercator `[-85 85]`; transversemercator its own great-circle guard at 89.5° from the central meridian's great circle; others `[-90 90]`).
   **`Domain` is the single authority for every projection limit in the toolbox** and replaces v1's scattered magic thresholds (F12). Cone constant computed once here: LCC `n = sin(p1)` if `|p1-p2|<1e-9` else `log(cos p1/cos p2)/log(tan(π/4+p2/2)/tan(π/4+p1/2))`; Albers `n = (sin p1 + sin p2)/2`; `|n|<1e-12` → `geo:crs:DegenerateConic`.
   Value struct, not a class — D-002, and the help says why.
2. **`geo.internal.mustBeCrs`** — the validator every downstream `arguments` block uses.
3. **`geo.wrapLongitude(lon, lon0)`** — elementwise into `[lon0-180, lon0+180)`. NaN and Inf propagate.
4. **`geo.splitAntimeridian(lon, lat, payload…, options)`** — orientation preserved; any number of same-length payload vectors split identically. `JumpThreshold [180]`; `Mode "break"|"interpolate" ["interpolate"]`, where interpolate additionally inserts the two crossing points at ±180 with linearly interpolated lat and payload **before** the NaN, so coastlines touch the map edge rather than stopping one sample short. Existing NaNs are existing breaks: never split across, never double-insert.
5. **`geo.grid` / `geo.track` / `geo.points`** — validated structs, **idempotent** constructors (a struct of their own kind passes through unchanged). `geo.grid`: `lon`/`lat` strictly monotone, NaN forbidden in coordinate vectors, `Z` `[numel(lat) × numel(lon)]`, optional `Topo`; derived `LonStep`, `LatStep`, `IsGlobalLon` (span ≥ 360 − 1.5·step); carries source and units metadata (§2.7). `geo.track`: equal-length vectors, optional monotone `t`, NaN allowed as gaps. `geo.points`: plus optional `SizeData`, `Labels`.
6. **`geo.region(spec, options)`** — port `geoAreaOfInterest`. Named preset, `[lonMin lonMax latMin latMax]`, Nx2 polygon, or filename. `Padding [0.05]`. **Replace `containers.Map` with a plain struct array** (discouraged in R2026a; do not substitute `dictionary` either — a struct array is sufficient and simplest). Preserve v1's honest caveat that the presets are conventional approximate boxes, not authoritative boundaries. **File input is deferred to Stage C**: raise `geo:region:FileInputNotYetAvailable` at a `% TODO(Stage C)` marker and ship the contract test for it now, so Stage C converts it rather than inventing it.
7. **`geo.greatCircle`** — one function, two forms: `out = geo.greatCircle(lon1,lat1,lon2,lat2,options)` → `DistanceKm` (haversine), `InitialBearingDeg`; and `[lon2,lat2] = geo.greatCircle("destination", lon1,lat1,bearingDeg,distanceKm,options)`. `Radius [6371.0072]`. The ACCURACY block states this is spherical and differs from a WGS84 geodesic by up to ~0.5%.
8. **`geo.splitTracks(track, options)`** — port `geoSplitTracks`: `GroupID` override; `TimeGapThreshold "auto"` using the median of strictly positive `dt` with `TimeGapFactor [5]`; `SpatialJumpThreshold [NaN]`; `MaxTrackDuration [NaN]`; `MaxTrackPoints [NaN]`; `MinTrackPoints [2]` with the dropped-sample warning; NaN-separated output; `trackID` at the **original** pre-filter length with NaN for dropped samples. v1's `AreaOfInterest` becomes `Region=`, accepting anything `geo.region` accepts. Removal of samples mid-track still forces a break there.
9. Test classes, one per group, deriving from `GeoMapTestCase`.

**4. Accuracy requirements, with reasons.**
- `wrapLongitude`: exact for representable inputs — `wrapLongitude(180,0) == -180` and `wrapLongitude(-180,0) == -180` **exactly** (bitwise), `wrapLongitude(539.5,0) == 179.5` to 1e-12. Exactness is required because every downstream seam test inherits this function's error.
- `splitAntimeridian` interpolate: inserted points at exactly ±180, lat to 1e-12. Linear interpolation of a 2-point segment has no truncation error, so anything looser would be hiding a bug.
- Cone constant LCC 33/45: **the mirror's value** (V1) — this document says 0.6304962 ± 1e-6 and that number is a claim to check.
- `greatCircle` Paris (2.3522, 48.8566) → New York (−74.0060, 40.7128): the mirror computes the spherical value at the authalic radius; the tolerance is set from the mirror, and the *reason* for any gap to the commonly quoted 5837 km is stated (spherical vs geodesic).

**5. The oracle.** O3 (analytic: haversine has a closed form; wrapping has an exact modular definition), O4 (`pyproj` for the cone constant and the great-circle comparison — `pyproj.Geod` gives the geodesic against which the spherical difference is quantified rather than hand-waved), and v1's own test file for the three `splitTracks` scenarios (O12, for behavioural continuity only, not for correctness).

**6. Test categories.** All seven ship somewhere in this stage:
- `contract` — every documented identifier fires; idempotence; orientation preservation; descending lat accepted; NaN in `Z` accepted but not in coordinate vectors; the deferred region error.
- `reference` — cone constant and great-circle against O4.
- `precision` — the exactness claims above.
- `robustness` — degeneracy **from the algebra**: LCC with `p1 = -p2` gives `n` exactly 0 (not "roughly zero"); a 2-point grid; an all-NaN track; empty region spec; `MinTrackPoints` larger than the whole track.
- `vectorisation` — `wrapLongitude` on a 1000-element array equals 1000 scalar calls **bitwise**.
- `metamorphic` — `splitAntimeridian` idempotence (`isequaln` on re-application); `wrapLongitude` idempotence; `splitTracks` invariance under adding a constant to all times; `greatCircle` destination is the exact inverse of distance+bearing to 1e-9°.
- `speed` — the four ratios in §2.4.3's Stage A rows, through `assertRatioBudget`, tagged *predicted* until V5 is discharged.

**7. Definition of done.** Green gate per §2.6.1. Every deliverable's help carries an ACCURACY block naming its oracle by register id. Category coverage table shows no gap outside `EXEMPTIONS.md`. The deferred region test exists and is documented as Stage C's obligation.

---

### 7.4 STAGE B — L1 core math

**1. What is being built.** The numerical heart: 16 projections forward and inverse, distortion diagnostics, statistics, regridding, hillshading and colour. This is the stage the whole toolbox's credibility rests on, and the one where the oracle register does most of its work.

**2. Depends on.** Stage 0 and Stage A green.

**Checkpoints** — consecutive turns in one chat, each with its own confirming run:
- **B.1** `project`, `unproject`, `scaleFactors`
- **B.2** `quantile`, `symmetricLimits`, `niceTicks`, `regrid`, `hillshade`
- **B.3** `colormaps`

**Reference files to attach:** v1 `geoProject.m`, `geoResampleGrid.m`, `geoPercentileRange.m`, `geoNiceTicks.m`, `geoNiceGraticuleStep.m`, `geoColormapPreset.m`, `geoDiscretizeColormap.m`, `geoMapToTruecolor.m`. **Start from these files where a deliverable says "port"** — do not rewrite verified code.

**3. Deliverables.**

**B.1.1 `geo.project(lon, lat, crs)`** — port v1 `geoProject` with four mandatory repairs and one addition:

- **F2 Robinson**: wrap the longitude difference with `geo.wrapLongitude` **before** the table scaling. v1 passed raw `LON - lon0` while every other case wrapped first.
- **F3 Mercator**: latitudes outside `crs.Domain.LatLimit` return **NaN**. v1 clamped to ±85°, silently drawing data at the wrong place. NaN is the toolbox-wide out-of-domain contract and Mercator is not exempt.
- **F12**: all domain clipping reads `crs.Domain`. **No literal `cosc` threshold may appear in this file.**
- Conics use `crs.ConeConstant` rather than recomputing `n`.
- **Add `"hammer"`**: the Aitoff kernel with the √2 equal-area modification (O2). Reuse the existing Winkel Tripel Aitoff path.

Port faithfully, because the review found them correct: polar stereographic in the Snyder 21-8/21-9 form with its hemisphere-dependent Y sign and far-pole NaN; the shared conic scaffolding and tangent-case limit; Mollweide Newton–Raphson (**add** early exit at `max|δ| < 1e-13`, cap 15 iterations, keep the exact-pole assignment); Winkel Tripel with `φ₁ = acos(2/π)` and the sinc guard near α = 0; sinusoidal, equirectangular and the azimuthal family; NaN-as-gap propagation throughout. Convenience: `lon (1,:)` with `lat (:,1)` auto-meshgrids. Output in Earth radii.

**B.1.2 `geo.unproject(x, y, crs)`** — new; the inverse for all 16. Points outside the image return NaN; `lon` wrapped to the CRS window. Closed forms (O1 inverse formulae) for equirectangular, mercator, sinusoidal, transversemercator, mollweide (`θ = asin(y/√2)`), hammer, the azimuthal family (`ρ → c`, standard oblique inverse), polarstereographic, and the conics (LCC via `tan(π/4+φ/2) = (F/ρ)^(1/n)`). Iterative: **Robinson** by **root-finding on the forward PCHIP** (bisection on [0°, 90°], which is monotone by construction and cannot fail, then Newton using the interpolant's own derivative) — **not** by PCHIP on the swapped table. Measured: swapping gives 0.30° round-trip error, root-finding gives 1.4e-13 (PV-004). Near the pole `dY/dlat ≈ 0.0048/deg`, so a 1e-3 interpolant discrepancy becomes a 0.2° latitude error; **Winkel Tripel** by 2-D Newton with an analytic Jacobian from the equidistant-cylindrical start, ≤10 iterations, convergence 1e-12, **NaN on divergence — verified by re-evaluating the forward at the solution and NaN-ing any point whose residual exceeds 1e-9, not by trusting the loop to have converged.** Without that check the mirror returned errors up to 174° near the antimeridian while looking like a successful inverse (PV-010). About 0.8% of a uniform in-domain sample falls in that region.

This function is why round-trip testing, correct graticule labels, projected-space picking and distortion diagnostics are possible at all — v1 had no inverse.

**B.1.3 `geo.scaleFactors(lon, lat, crs)`** — `h`, `k`, `AreaScale`, `OmegaDeg` (O1 ch. 4). Central differences on `geo.project`, step 1e-6°, metric-corrected by `cos(lat)`. **Document the choice**: one code path for all 16 rather than 16 analytic derivations, accuracy ~1e-8, verified against the analytic values below.

**B.2.1 `geo.quantile(Z, p)`** — type-7 (`h = (n-1)p/100 + 1`) over finite elements. No toolbox `quantile`/`prctile`. Fixes F10: `geo.quantile([1 2], 50)` **must** be 1.5.
**B.2.2 `geo.symmetricLimits(Z, p)`** — `[-a a]` with `a = geo.quantile(abs(Z), p)`, `p` default 98; degenerate → `[-0.5 0.5]`.
**B.2.3 `geo.niceTicks(lo, hi, options)`** — merges v1's two; `Mode "linear"|"graticule"`, `TargetCount [6]`; graticule set `[0.1 0.2 0.25 0.5 1 2 3 5 10 15 20 30 45 60 90]`; **ceiling policy** — smallest nice step ≥ span/TargetCount, fixing F16's nearest-snap.

**B.2.4 `geo.regrid(...)`** — port `geoResampleGrid`, two upgrades. Signatures: `geo.regrid(srcGrid, lonQ, latQ, options)` and the raw six-argument form. Options `Method "bilinear"|"conservative"|"nearest" ["bilinear"]`, `CenterLongitude [0]`, `UseParallel "auto"|"never"|"always" ["never"]`.
- **F4 periodicity**: keep v1's rewrap/sort/dedup, then — if the source spans a full circle (`last - first ≥ 360 − 1.5·median step`) — **pad one wrapped column each side** before building the `griddedInterpolant`.
- **Conservative**: first-order area-weighted remap for rectilinear grids. Weight = (longitude overlap) × (`sin latN − sin latS` overlap), i.e. true spherical cell area; interval overlap in each dimension, sparse weight assembly, no polygon clipping needed. NaN sources excluded with renormalisation; no valid overlap → NaN. Motivation in the help: **bilinear resampling of mass/EWH fields is not mass-conserving.** `UseParallel` tiles target rows when a pool exists and `numel(Zi) > 4e6`.

**B.2.5 `geo.hillshade(lon, lat, topo, options)`** — new; D-009. Horn 3×3 gradients via `conv2`. **The correctness point**: x spacing is `R·cos(lat)·dlon_rad` **per row**, y spacing `R·dlat_rad` — a naive gradient ignores the metric and mis-shades high latitudes. Lambertian `cos(incidence)` clamped at 0; `shade = Ambient + (1-Ambient)·lambert`. Options `Azimuth [315]`, `Elevation [45]`, `ZFactor ["auto"]` (relief scaled so median slope ≈ 30°; formula written out, **and its span recorded per §2.11**), `Method "horn"`, `Multi [false]` (USGS azimuths 225/270/315/360, sin² weights), `Ambient [0.35]`. NaN topo → shade 1; NaN neighbours → one-sided differences.

**B.3.1 `geo.colormaps(cmd, …)`** — merges v1's three. `"get"` (port the preset list; **add an original perceptual blue-white-red diverging ramp for signed anomalies — generate it, do not reproduce a third-party colormap's tabulated values, and say in the help that it is original**), `"discretize"`, `"truecolor"` (port `geoMapToTruecolor` with `UnderColor`/`OverColor`/`MaskColor`/`Mask`, **plus new `Shade=`** — composition `rgb .* Shade` broadcast over the third dimension, stated explicitly in the help and asserted exactly; the `Ambient` term inside `hillshade` is what prevents fully black shadows).

**4. Accuracy requirements, with reasons.**

Every figure below is **a claim from this document, and V1 says it is unmeasured.** The mirror computes each one first; a disagreement is a finding reported before any MATLAB is written.

| Claim | Value | Tolerance | Why this tolerance |
|---|---|---|---|
| Mercator `y(35°)` | `ln(tan(45+17.5°))` = 0.6528366 | 1e-6 | Closed form; 1e-6 is the printed precision of O1's table, not the achievable accuracy |
| Polar stereographic `ρ(70°)/R`, SP=71 | **0.3430474163** ~~0.6116372~~ | 1e-9 vs mirror | **CORRECTED (PV-002).** The old figure matched no evaluation of any formula, spherical or ellipsoidal. Mirror and PROJ agree to 1e-10 on 0.3430474163 = (1+sin 71°)·tan(10°) |
| LCC 33/45, lon0=−96, lat0=23, at (35°, −75°) | x = 0.2966785 R, y = 0.2462112 R | 5e-6 | O1 p.296 worked example |
| Robinson at table nodes, lat=50 | **X = 0.8679, Y = 0.6176**, giving y = **0.8351805** R ~~X 0.9427, Y 0.5722~~ | 1e-12 | **CORRECTED (PV-005).** The old values were X-table entries read as Y and taken from the wrong rows: 0.9427 is X at lat **35**, 0.5722 is X at lat **85**. PCHIP must still reproduce its own nodes exactly |
| Round-trip fwd→inv, 10⁴ in-domain points per projection | — | ≤ 1e-9°, **except Lambert azimuthal ≤ 1e-8°** | Measured: 13 of 16 at ≤ 4e-12; Robinson **1.4e-13** and Winkel Tripel **4.6e-13** once the methods below are used. **The Robinson 5e-4 exception is withdrawn (PV-004)** — it was an artefact of the prescribed inversion method, not of the projection. Lambert measures 4.6e-9, inherent to `asin` conditioning at the antipodal rim (PV-010) |
| Round-trip inv→fwd on the projected image | — | ≤ 1e-9 in x,y | same, same exceptions |
| Equal-area integral, **pseudocylindricals only** (mollweide, hammer, sinusoidal) | 4π | 1e-3 relative | Measured 2.5e-5 … 9.8e-5 at 1° quads — confirmed with 10× headroom. **Lambert and Albers removed (PV-007)**: the azimuthal rim and conic apex are singular, so a global quad integral there measures discretisation, not the projection. `AreaScale` is the right instrument for those and passes at 2.4e-8 |
| `AreaScale` for equal-area projections | 1 | 1e-6 | Central differences at step 1e-6° |
| `h == k`, `ω ≤ 1e-4` for conformal projections | — | 1e-6 | same |
| LCC `k == 1` on both standard parallels | 1 | 1e-6 | same |
| Mercator `k == sec φ` at 0°, 30°, 60° | — | 1e-6 | same |
| Conservative regrid mass closure | — | **`TolMass` as measured in Stage 0** | V7: 1e-12 is a guess; the achievable double-precision floor at production size is what the tolerance must be |
| Seam test: 0:359 source, query at −0.5 | `mean(Z(:,1), Z(:,360))` | 1e-12 | Exact bilinear midpoint; **v1 fails this** — record that in the comment |
| Hillshade of flat terrain | `Ambient + (1-Ambient)·sin(Elevation)` | 1e-12 | Analytically exact |
| Hillshade metric: same ramp at lat 0 vs 60 | slope ratio `cos(60°)` | 1e-6 | **The test that catches a missing `cos(lat)`** |
| `truecolor` with `Shade = 0.5` | every channel halved | 1e-12 | Exact by the documented formula |
| Robinson fix (F2) | `project(359, 10, robinson)` has x < 0, \|x\| < 0.02 | — | v1 returned +3.0 |
| Mercator fix (F3) | `project(0, 87, mercator)` is NaN | — | v1 returned the value for 85° |

**5. The oracle.** **O4 is the primary oracle for this stage and discharges V2**: all 16 projections, forward and inverse, cross-checked against `pyproj` over dense in-domain samples. O1/O2 supply the published point values; O3 the analytic invariants; O7 the conservative weights; O8 the Horn hillshade. Where PROJ lacks a projection (Robinson's exact table variant, the Winkel Tripel inverse), say so and fall back to O1/O2 plus the round-trip — **and record the gap in `mirror/LIMITS.md`**.

**6. Test categories.**
- `contract` — meshgrid expansion; size-mismatch identifiers; NaN propagation; **every projection NaN outside its domain**; out-of-image NaN for `unproject`; `p` outside [0,100] rejected; all-NaN inputs behave as documented.
- `reference` — the table above against O1/O2/O4/O7/O8.
- `precision` — the round-trip suites and the analytic invariants, each with the stated tolerance and a comment naming its source.
- `robustness` — degeneracy **from the algebra**: exact antipode for the azimuthal family; `cosc` exactly 0 for gnomonic; Mollweide exactly at the poles; conic apex; a source grid with one row; an all-NaN source; a query grid entirely outside the source; `Elevation = 90°` (light straight down) in hillshade; a constant field for both regrid methods.
- `vectorisation` — `project`/`unproject`/`quantile`/`hillshade`/`truecolor`: batched equals per-element, **bitwise** for `project` (elementwise arithmetic — §4.6 permits bit-identity only here); eps-level for `regrid` (matrix product, may block differently) with the reason stated.
- `metamorphic` — **longitude-shift equivariance**: `project(lon+Δ, lat, crs(lon0+Δ)) == project(lon, lat, crs(lon0))` to 1e-12 (this is the property F2 violated); regrid **split/merge** (regridding in two steps equals one, eps-level); regrid invariance under source row permutation; `quantile` permutation invariance (bitwise); hillshade E–W mirror symmetry under azimuth reflection; `niceTicks` scale equivariance.
- `speed` — the eleven Stage B ratios in §2.4.3, through `assertRatioBudget`, each stating N and its expected value beside the budget.

**7. Definition of done.** Green gate. Every value in the accuracy table either confirmed by the mirror or reported as a finding with its measurement. The three pinned regression tests (Robinson wrap, Mercator NaN, regrid seam) exist and pass. `mirror/LIMITS.md` updated with everything O4 could not certify. V1 and V2 discharged in the debt table, or explicitly not, with the reason.

---
### 7.5 STAGE C — L2 I/O and caching

**1. What is being built.** One coastline reader replacing four, the topography reader extracted from where v1 buried it, and the cache that stops both being re-run on every plot.

**2. Depends on.** Stages 0, A, B green.

**Reference files to attach:** v1 `geoCoastlineFromShapefile.m`, `geoCoastlineFromGSHHG.m`, `geoCoastlineFromNetCDF.m`, `geoCoastlineFromText.m`, and from `geoImagesc.m` the locals `localReadTopographyFile`, `localReadWorldFile`, `localParseWorldFileContents`, `localReadEmbeddedGeoTIFFTags`, `localReadNetCDFTopography`, `localFindNcVar`, `localLoadBuiltinCoastline`, `localLoadBuiltinRivers`. **Start from these files.**

**3. Deliverables.**

1. **`geo.readCoastline(source, options)`** → `[xy, meta]`. `source`: `"builtin"`, a filename (`.shp`/`.b`/`.nc`/`.nc4`/`.cdf`/`.txt`/`.dat`/`.mat`), or a validated Nx2 array. Options `Format ["auto"]`, `Levels [1:6]` (GSHHG), `Split "break"|"interpolate" ["interpolate"]`. `meta` carries `Source`, `Format`, `NumParts`, `NumPoints` and **`Provenance`** (`"verified"` | `"unverified"`) — §2.7's metadata rule, and the mechanism behind OB-3.
   Port the parsers faithfully. Preserve v1's deliberate absence of an `isfile` pre-check (`fopen` searches the MATLAB path, `isfile` does not) **and its comment saying why**. Preserve the shapefile's record traversal by declared content length, and the GSHHG microdegree scaling with 0–360 → ±180 rewrap. **Preserve v1's CONFIDENCE NOTE verbatim** until O6 discharges V3.
   Three changes: **(a)** cell-accumulate and `vertcat` once (F13 — full-resolution GSHHG is ~180 MB and v1's growth is O(N²)); **(b)** delete each reader's private jump code and call `geo.splitAntimeridian` (§2.7, one authority); **(c)** GSHHG level 5/6 polygons spanning ≥ 359° are closed via the South Pole — append `(lonEnd,-90)`, `(lonStart,-90)` **before** splitting (F17).
2. **`geo.readGrid(source, options)`** → `geo.grid`. NetCDF via `ncread` with variable auto-detection (port `localFindNcVar`'s candidate list), image + worldfile or embedded GeoTIFF tags, `.mat`, or raw arrays. Options `Variable [""]`, `WorldFile [""]`, `Lon`, `Lat`. Port v1's honest warnings about misread pixel ranges (signed ocean depths read as unsigned).
3. **`geo.cache(cmd, …)`** — `"getCoastline"` (key: resolved absolute path + mtime + options hash, **as a struct, never a concatenated string parsed back apart** — §2.7), `"getProjected"` (plus CRS hash), `"clear"`, `"stats"` (entries, approximate bytes, hits, misses). Persistent within session, LRU-bounded at 20 entries, bound documented.
   **F4-class hazard**: a cache is a preserving mechanism, and §F4 says these are exactly the mechanisms that destroy. State explicitly what happens on eviction, on a changed mtime, and on an error mid-parse — and **test that a failed parse leaves no poisoned entry**.
4. **Close the `geo.region` file hook** left by Stage A: route filename specs to `geo.readCoastline`, apply `Padding` to the derived box as the polygon path does, delete the TODO marker, and **convert** Stage A's deferred-error test into a success test rather than deleting it.
5. **`tests/data/makeFixtures.m`** — pure MATLAB generating the binary fixtures, so nothing third-party is shipped and no network is needed: a 2-record shapefile (one PolyLine crossing the antimeridian, one Polygon) written by hand with `fwrite`, big-endian header and little-endian record content with correct content lengths; a deliberately truncated shapefile; a Point-type shapefile for the unsupported-geometry path; a 3-polygon GSHHG file with levels 1, 2 and 5, the level-5 polygon spanning 0–359.9° to exercise pole closure; a text file with a blank-line separated part; a small NetCDF grid via `nccreate`/`ncwrite`.
   **§3.15 applies**: the fixture must share the target's failure surface. One source project validated a reader against a synthetic dimension order no real product file uses, and it failed on first contact with a real file. **Where a fixture's arrangement is a guess, say so in `mirror/LIMITS.md`.**
6. Test class deriving from `GeoMapTestCase`.

**4. Accuracy requirements.** Shapefile coordinates round-trip **exactly** (doubles written equal doubles read — `isequal`, not a tolerance, because the format stores IEEE doubles and anything less would hide an endianness bug). GSHHG to 1e-6° (microdegree quantisation is the format's own floor). The antimeridian polyline returns split with Stage A's interpolated ±180 points. The level-5 polygon returns with two vertices at lat exactly −90.

**5. The oracle.** **O5 (a real Natural Earth `.shp`) and O6 (a real GSHHG `.b`) are the oracles that matter**, and both are currently unfilled. The generated fixtures are a *contract* instrument, not a reference one: a reader validated only against files it wrote itself is checked against a copy of its own assumptions (§F3's corollary). **If O5 and O6 remain unfilled at this stage, the reference tests are deferred with an explicit re-entry criterion, the debt rows stay open, and the shipped `Provenance` field reads `"unverified"`.** That is an acceptable outcome; pretending otherwise is not. O9 (ETOPO) and O10 (`topo.mat`) certify `readGrid`.

**6. Test categories.** `contract` (unsupported extension, truncated file warning, no matching level, no geometry, unrecognisable NetCDF variable naming the candidates it tried); `reference` (O5/O6/O9/O10, deferred if unfilled); `precision` (the round-trip exactness above); `robustness` (**failed parse leaves no cache entry**; zero-length file; a file that is a directory; cache eviction at the LRU bound; mtime change invalidating); `metamorphic` (reading the same file twice through the cache is `isequaln` to reading it twice with the cache cleared between — the cache is *transparent*, which is the property that matters); `speed` (the two Stage C ratios). `vectorisation` exempt with reason.

**7. Definition of done.** Green gate. Stage A's deferred test converted, not deleted. Every cache-hazard case tested. V3 discharged or explicitly still open with the `Provenance` mechanism shipped and OB-3 still standing.

---

### 7.6 STAGE D — L3 cartographic elements

**1. What is being built.** The graphics layer: one shared basemap engine plus twelve composable elements, replacing v1's one 3413-line function and its two near-clones (F8), and one internal layout manager replacing five plumbing functions (F15).

**2. Depends on.** Stages 0, A, B, C green.

**Checkpoints:** **D.2 is split into D.2a** (`coastline`, `scalebar`, `northarrow`, delivered 16-Aug-2026, R-012) **and D.2b** (`colorbar`, `inset`) - five elements in one checkpoint was too much to review at once, and the three delivered share a shared polyline projector that the other two do not need. **D.0** `geo.readGrid` window and stride selection, and the shipped topography sample — *added 16-Aug-2026, see below* · **D.1** `internal.layout`, `basemap`, `graticule`, `frame` · **D.2** `coastline`, `scalebar`, `northarrow`, `colorbar`, `inset` · **D.3a** `overlayPolygons`, `stipple`, `overlayContours` - the field overlays, under the graticule (delivered 16-Aug-2026, R-014) - and **D.3b** `overlayTrack`, `overlayPoints`, over it at z = 5 (delivered 16-Aug-2026, R-015). **STAGE D IS COMPLETE.**

**D.1 delivered 16-Aug-2026, R-010.** `geo.internal.layout`,
`geo.internal.avoidRectCollisions`, `geo.internal.elementExtent`,
`geo.basemap`, `geo.graticule`, `geo.frame`. Four items bind D.2 and D.3:
nothing rediscovers a handle (an element's objects live in the layout
registry under its kind); `H.DataLimits` is pristine and every resize
recomputes from it, never from the current limits; the z-ladder is a
contract and is asserted; and `geo.internal.elementExtent` is where an
element gets its projection and extent, so D.2 must call it rather than
grow a fourth copy of the same twelve lines.

**D.0 — why a Stage C reader is amended in Stage D's branch.** ETOPO 2022 arrived after Stage C merged. `ncread` returns double, so the 60-arc-second global field is 1.74 GB resident and the 30-arc-second one 6.95 GB, and `geo.readGrid` had no way to ask for less. D.1's basemap cannot use the data without it. Put in its own checkpoint rather than folded into D.1, because a graphics checkpoint quietly containing a reader change is exactly what stage attribution exists to prevent. **Delivered 16-Aug-2026, R-009**; oracles O9 and O10 filled in the same round. Three consequences bind D.1 onward: a window COVERS its region and may exceed it by one cell per edge; a seam-crossing window returns longitude continuing past 180 rather than wrapped; and `Stride` subsamples, at 184x the per-cell cost of a contiguous read on a compressed file, so a decimated global overview belongs in `geo.cache` and not in a re-read.

**Reference files to attach:** v1 `geoImagesc.m` (whole), `geoSegmentedFrame.m`, `geoAttachFrameResize.m`, `geoChainCallback.m`, `geoAttachResizeCallback.m`, `geoRegisterInsetRect.m`, `geoGetOtherInsetRects.m`, `geoAvoidRectCollisions.m`, `geoScaleBar.m`, `geoNorthArrow.m`, `geoCompassAnchor.m`, `geoGmtColorbar.m`, `geoImagescTrack.m`, `geoImagescPoints.m`.

**3. Deliverables.**

**D.1.1 `geo.internal.layout`** — one manager per figure, replacing `geoChainCallback`, `geoAttachResizeCallback`, `geoRegisterInsetRect`, `geoGetOtherInsetRects` and the per-element resize callbacks. Stored in **one reserved field**, `fig.UserData.geoMapLayout`, documented as reserved — not `appdata`, and not manual `SizeChangedFcn` chaining, which broke in v1 if any other toolbox touched the property. Mechanism: one `addlistener(fig,'SizeChanged',…)`. API used only by L3: `layout.register(ax, kind, updateFcn)`, `layout.rects(ax)`. **Port `geoAvoidRectCollisions` verbatim** — its geometry was reviewed and is correct.

**D.1.2 `geo.basemap(G, crs, options)`** → `[figH, axH, H]`. Pipeline: wrap → project → `geo.hillshade` on `Topo` (else `Z`, unless `Hillshade="off"`) → `geo.colormaps("truecolor", …, Shade=…)` → **one** `surf` at z=0, `FaceColor` flat truecolor. **No `light`, no `material`, no `shading interp`** — D-009, and the Stage 0 audit enforces it. NaN cells keep flat `FaceAlpha` transparency over the `NaNColor` background (safe now that interp is gone). Use `clim()`; **never `caxis`, and never name a variable `clim`** (F11). Options carry over v1's raster surface: `Colormap`, `ColormapName`, `CLim`, `CLimMode`, `CLimPercentile`, `DiscreteLevels`, **`Divergent [false]`** → `geo.symmetricLimits`, `Hillshade "single"|"multi"|"off"`, `Azimuth`, `Elevation`, `Ambient`, `NaNColor`, `Mask`, `MaskMethod`, `MaskThreshold`, `MaskPolygon`, `MaskPolygonSide`, `MaskColor` (port both of v1's helpful warnings), `Parent`. Registers with the layout manager; returns a named handle struct — **nothing downstream may rediscover handles with `findobj`** (§2.7, audited).

**D.1.3 `geo.graticule(ax, crs, options)`** — port v1's construction; densify so no projected segment exceeds 1/200 of the map diagonal; clip to `crs.Domain`; z=3. **Labels placed via `geo.unproject`** plus the true local meridian/parallel direction from finite differences of `geo.project`, replacing v1's tangent heuristics — record in a comment that those heuristics were the source of several compounding azimuthal label bugs. Label gap maintained by the layout manager.

**D.1.4 `geo.frame(ax, crs, options)`** — port `geoSegmentedFrame` in full: graticule-aligned fishnet, exact-rectangle and fixed-count variants; `Thickness`, `Colors`, `Style`; z=6; resize via the layout manager.

**D.2.1 `geo.coastline(ax, crs, options)`** — `Source` (anything `geo.readCoastline` takes) `["builtin"]`, **`Kind "coastline"|"river"|"outline"`** collapsing v1's three near-identical paths into one, `Color`, `LineWidth`, `LineStyle`. Through `geo.cache("getProjected")`. Clip via `crs.Domain` — **delete `localVisibleRadiusDeg`**; the domain is declared now (F12). z=4.

**D.2.2 `geo.scalebar(ax, crs, options)`** — port the bar construction (alternating segments, km/mi, label placement, thickness, location presets including `"auto"`), calibrated at the map centre via `geo.greatCircle`.
**Behaviour changed by D-006**: evaluate `geo.scaleFactors` at the axes extent corners and centre; **draw the bar, and additionally** warn `geo:scalebar:ScaleVaries` naming the measured percentage, and **record the measured variation in the returned handle struct's metadata**. Do not refuse. §4.5: a library that will not let you do the thing you came to do is not protecting you; scale variation is suspicious, not provably meaningless, and a caller may legitimately want a bar on a regional inset of a global CRS. The threshold above which the warning fires comes from **Stage 0's measured table** (V8), not from a guess.

**D.2.3 `geo.northarrow(ax, crs, options)`** — port the geometry and anchor logic (`geoCompassAnchor` folds in as an internal helper). Orientation from projecting a short northward step at the anchor. **Two positional arguments, not fifteen** (F7).

**D.2.4 `geo.colorbar(ax, options)`** — merge v1's four implementations (native path, `geoGmtColorbar`, two copies of `localAddHalfColorbar`, `localAddDualScaleColorbar`) into `Style "native"|"gmt"|"half"|"dual" ["gmt"]`, preserving discrete level ticks, under/over triangular end caps, the dual topography+data scale, side selection, and resize-aware positioning via the layout manager.

**D.2.5 `geo.inset(ax, crs, options)`** — port `localAddMapInset`: locator globe with the extent rectangle, own axes, content drawn once and only repositioned on resize; collision via `layout.rects`.

**D.3 Overlays** — `geo.overlayTrack` (port v1's line-gradient, wiggle, bicolor wiggle and marker styles on a `geo.track`; runs split by the NaN convention **and** `geo.splitAntimeridian`; per-run truecolor; z=5); `geo.overlayPoints` (scatter/bubble, nice size-legend values, legend registered with the layout manager; z=5); `geo.overlayContours` (port `localAddContours`; **add** `LabelSpacing` and dashed negatives for anomaly maps; z=1); **`geo.overlayPolygons`** (new — mascon and basin fields, which a regular-grid `surf` cannot represent at all: cell array of Nx2 outlines or one NaN-separated array, one value per polygon, projected, split at the antimeridian into patches **sharing one value**, truecolor `FaceColor`, `Colormap`/`CLim` identical in meaning to `basemap`'s so a mascon layer can sit on a hillshaded background, domain-boundary clipping into visible parts; z=2); **`geo.stipple`** (new — significance masking: logical mask on a lon/lat grid, `Style "dots"|"hatch"`, `Density [2000]`, dots subsampled by a **regular stride, never random**, so output is deterministic and testable; hatch as one NaN-separated line object clipped to the mask; z=2).

**4. Accuracy requirements.** Geometric, at `TolGeom` unless stated: mollweide global surface XData spans ±2√2 to 0.1%; equirectangular's 0° meridian label at x = 0 ± 1e-9; frame patch count equals the computed segment count for a known extent and step; north arrow on polarstereographic at anchor longitude 90° rotated 90° ± 0.5°; the resize test — halve the figure width, `drawnow`, frame on-screen thickness in points changed by **< 5%** (this is the layout manager's entire job, and the figure is the tolerance the eye can see at print size).

**5. The oracle.** Weakest stage for oracles, and that is stated rather than glossed: geometry is checked against **closed-form projected coordinates computed by Stage B** (which is itself certified against O4) — an internal reference, but one certified externally one layer down. Nothing outside the project certifies a MATLAB frame's appearance. `geo.scalebar`'s distance calibration is checked against O4's geodesic with the spherical difference quantified.

**6. Test categories.** `contract` (basemap rejects a bare matrix; `Divergent` on all-positive data still gives symmetric `clim`; `Hillshade="off"` yields CData identical to `truecolor` without `Shade`; **idempotence — a second call replaces rather than duplicates**, via tag + delete, asserted by constant handle count); `precision` exempt for graphics per §2.3.2, **except** the geometric assertions above which run under `contract`; `robustness` (zero-span extent; a single-cell grid; an all-NaN grid; an extent entirely outside the projection domain; a figure resized to near-zero; **a mask that is all true and all false**, which is exactly the case v1 warned about); `metamorphic` (**draw-order independence** — elements applied in two different orders produce the same object set and the same z-levels; this is what "composable" means and it is otherwise only an intention); `speed` (the Stage D ratios, tagged **weak**). `vectorisation` exempt with reason.

**7. Definition of done.** Green gate. No `light`/`material`/`shading interp` anywhere in the stage (audited). No `findobj` rediscovery (audited). The five v1 plumbing functions fully absorbed. `geo.scalebar` draws and reports rather than refusing (D-006), with the threshold from Stage 0's table.

---

**RESOLVED 16-Aug-2026 — the transverse Mercator question was the wrong
question.** D.1 raised the 0.5°-versus-5° clip margin as an open
question, on the evidence that transverse Mercator was the one projection
whose graticule could not meet the smoothness criterion. It was not the
clip. The offending segment measures exactly 2π and sits on the meridians
120° from the central meridian, where the `atan2` giving y flips branch:
a **branch cut**, which no amount of sampling resolves and which was
being drawn straight across the map. `geo.graticule` now breaks any
segment that will not shrink under bisection, all sixteen projections
meet the criterion, and **no change to any clip is needed**. The margin
inconsistency is real, much smaller than it looked, and no longer blocks
anything. R-011, PV-080.

---

### 7.7 STAGE E — L4 fronts

**1. What is being built.** Six thin orchestration functions that make the common cases one call, and the export path.

**2. Depends on.** Stages 0, A–D green.

**HARD RULE.** Each front is at most ~200 lines of orchestration calling **only public `geo.*` functions** in the documented z-order. **Zero drawing primitives**: no `surf`, `patch`, `line`, `text`, `scatter`, `colorbar` or `annotation`. If one is needed, the missing capability belongs in an L3 element — **stop and flag it as an open question rather than inlining it**. This is what stops F8's monolith regrowing, and §7.4 of BEST_PRACTICE names "make it robust" as unfalsifiable; this rule is falsifiable, and Stage E ships the test that falsifies it.

**Reference files to attach:** v1 `geoImagesc.m` (for its **option surface and orchestration order only**), `geoImagescTrack.m`, `geoImagescPoints.m`, `geoImagescTimeSeries.m`, `geoImagescMulti.m`; plus `records/v1_option_inventory.md` from Stage 0.

**3. Deliverables.**

1. **`geo.map(G, crs, options)`** — order: `basemap` → `overlayContours` → `overlayPolygons`/`stipple` → `graticule` → `coastline` (coastline, rivers, region outline) → `overlayPoints` → `frame` → `colorbar` → `scalebar` → `northarrow` → `inset` → `export`. Also accepts the raw `(lon, lat, Z, crs)` triplet. **Option names carry over from v1 1:1 wherever the feature survived** — use Stage 0's inventory, not recollection. Three deliberate differences, documented: the projection options are gone (the `crs` argument replaces them) and passing `'Projection'` raises `geo:map:ProjectionOption` telling the user to construct a `geo.crs`; `Divergent`, `Stipple`, `Polygons`, `Region` are new; `Export` delegates.
2. **`geo.trackmap` / `geo.pointmap`** — extent resolution (explicit limits > `Region` > data bbox with `Pad`), then the **background as orchestration, not engine**: `geo.readGrid` builtin topography → `geo.regrid` at `BackgroundResolution` → `geo.basemap` → elements → overlay → colorbars (shared or the two half-bars) → size legend → scalebar, north arrow, export.
3. **`geo.timeseries(T, options)`** — port v1's multi-station series: vertical offsets, gap detection and breaking, uncertainty bands, style presets. Standalone or inside a `geo.panel` tile. **Uses `geo.splitTracks`' gap logic rather than duplicating it** (§4.1).
4. **`geo.panel(spec, options)`** — port `geoImagescMulti` on `tiledlayout`: mixed map and time-series panels, x-limit linking, map-point ↔ series linking. **Preserve the v1-proven equal-height mechanism**: match time-series heights to map plotted height via `PlotBoxAspectRatio`, and **document the constraint that forced it** — under `tiledlayout`, `set(ax,'Position',…)` is blocked. Do not attempt to "fix" this with `Position`.
5. **`geo.export(figs, files, options)`** — `Width`, `Height`, `Units ["centimeters"]`, `Resolution [300]`, `UseParallel ["never"]`. Port v1's proven export tail (`exportgraphics` with `print` fallback, exact centimetre sizing). **Batch mode**: arrays of figures and files; with a pool and more than one figure, dispatch via `parfeval`. **Critical design point, with a worked example in the help**: graphics handles cannot cross worker boundaries, so the parallel path takes a cell array of **builder function handles** (each creating its figure `'Visible','off'` on the worker), not live handles. Show both forms.
6. Test class.

**4. Accuracy requirements.** Panel map plotted heights equal within **2%** (v1's accepted criterion, carried forward deliberately — it is a visual-equality threshold, not a numerical one). Trackmap auto-extent contains every finite track point with the documented pad, asserted on the limits. A 17.0 cm PDF's page width 17.0 ± 0.05 cm; **if reading the produced PDF's page box in pure MATLAB proves impractical, assert `PaperPosition` instead and document the substitution at the assertion** — a substituted measurement that is labelled is evidence; one that is not is a claim.

**5. The oracle.** The composition guarantee is checked against **`geo.basemap` plus manual elements** — an internal reference, but the strongest available and the one that matters: it certifies that the fronts add no hidden behaviour. Export sizing is checked against the file the OS wrote.

**6. Test categories.** `contract` (raw-triplet equals `geo.grid` path — same `clim`, same surface size, `isequal` CData; `'Projection'` raises; malformed panel spec rejected); **the orchestration-purity test**, which `fileread`s the five front files and asserts zero matches for the forbidden primitives outside comments and help — written as a real test so the rule cannot silently erode; `robustness` (a track with one point; a panel with one tile; export to an unwritable path; a figure closed before export); `metamorphic` (calling `geo.map` twice on the same data yields identical CData — determinism through the whole stack); `speed` (the Stage E ratio, tagged weak). `reference` exempt for export with reason; `vectorisation` exempt.

**7. Definition of done.** Green gate. Orchestration-purity test passes. Every surviving v1 option name spelled identically **against the Stage 0 inventory**; every dropped one either mapped or raising a helpful error. V9 discharged.

---

### 7.8 STAGE F — Documentation, packaging, release, independent audit

**1. What is being built.** The release: the doc build and its sync gate, the packaging, the integration scenarios, and — as its own phase — the audit that assumes none of it.

**2. Depends on.** Stages 0, A–E green.

**3. Deliverables.**

1. **`tests/TestIntegration.m`** — three scenarios:
   - **GRACE-style figure**: a synthetic EWH anomaly grid → `geo.map` on mollweide with `Divergent`, a significance `Stipple`, coastline and GMT colorbar, exported to a PDF in `tempdir`. Assert the file exists, exceeds 10 kB, and every expected handle kind is present.
   - **Composed equals front**: the same map built once via `geo.map` and once by hand from `geo.basemap` plus elements in z-order. Assert identical surface CData (`isequal`) and identical `clim`. **This is the test that enforces the architecture's central guarantee.**
   - **Serial equals parallel**: `geo.regrid` conservative under `UseParallel="never"` and `"always"`, `isequal`, skipped via `assumeTrue(canUseParallelPool)`.
2. **`docbuild/build_help.m`** — pure MATLAB. Parses each public function's help into structured HTML, relying on §2.8.1's fixed headers. Emits per-function pages with typed/dimensioned I/O tables, the OPTIONS table, the **ACCURACY block**, the ERRORS block grouped by cause, syntax-highlighted examples, and resolved See-also links; one index grouped by layer; a **"choosing a projection"** guide; a **"GRACE workflow"** tutorial.
   **The builder reports completeness counted in the built artefact**: arguments documented / arguments **rendered** (§F1 — one source project parsed descriptions into its model for years while the renderer never read the field, and every audit stayed green because there was no text to disagree with).
   **Every example is extracted and linted at build time.** The builder verifies and reports zero broken See-also links.
   Projection guide content, written out in full: global anomaly/mass fields → mollweide or hammer (equal-area); global compromise → robinson or winkeltripel; regional mid-latitude → lambertconformal (conformal) or albers (equal-area); polar → polarstereographic; narrow N–S strips and tracks → transversemercator, navigation and small equatorial areas → mercator; hemisphere views → orthographic or lambert. **State prominently that the model is spherical, the resulting geometric error at most ~0.3%, and that this is a visualisation tool, not a survey tool.**
3. **`info.xml` / `helptoc.xml`** — registration under Supplemental Software so `doc geoMap` and the Help browser tree work; toc mirrors the layer grouping.
4. **Documentation sync gate** — added to `geoMapAudit`: cross-reads help, generated HTML, guide, README, CHANGELOG and `Contents.m`; fails on disagreement; **runs on a fresh mirror after the doc rebuild**. Version string authority is `Contents.m`; every other file repeating it is checked against that, never independently maintained.
5. **`GettingStarted.m`** — `%%`-sectioned script that publishes cleanly (quick start, composed workflow, GRACE example, projection-guide link); Matthias converts to `.mlx`.
6. **`Contents.m`** — version line, layer-grouped list whose one-line summaries **exactly match each function's H1**, verified by `TestContentsConsistency`. **The patch component is the test-point count** (§6.7): it moves when the evidence moves, and a pure rename correctly bumps nothing. The document revision is recorded alongside, in the same edit.
7. **`README.md`** — v1's structure updated, plus a **migration table**: old call → new call for the six main functions, and the `Projection` → `geo.crs` change.
8. **`geoMap.prj`** — `matlab.addons.toolbox` spec; version 2.0.0; `+geo`, built `html`, `tests/data` included.
9. **`CHANGELOG.md`** — v2.0.0 entry referencing the F-numbers fixed **and the probe result for each** (a defect claimed fixed that never reproduced is not a fix).
10. **Release checklist** — `rungeoMapTests("all")` green; `buildtool check` clean; docs build with zero broken links **and the rendered pages rasterised and looked at**; `.mltbx` installs in a fresh MATLAB and `doc geoMap` resolves; **every debt row in Part 0 either discharged or explicitly carried with its reason**; the ledger fully ticked.
11. **`RECORDS.md` final state** — one entry per stage, per Appendix D's template.

**4. Accuracy requirements.** Doc completeness counted in the artefact, target 100% of public arguments rendered; zero broken links; the version chain agreeing across all six files that name it.

**5. The oracle.** O11 (a published GRACE mascon EWH product) for the integration scenario's sign, magnitude and pattern over Greenland, West Antarctica and north India — **with the product's span written next to the expected numbers** (§2.11), and the expectation re-derived when a newer release supersedes it. The rendered manual is checked by rasterising and looking; there is no automated oracle for "the figure is right", and pretending otherwise would be worse than saying so.

**6. Test categories.** `contract` (Contents consistency; version chain; link integrity); `reference` (O11); `robustness` (doc build on a function with a deliberately malformed help block — it must fail loudly, not skip); `diagnostics` and `provenance` cross-cutting sweeps across the whole tree.

**7. Definition of done.** Release checklist complete, every item verified. **Then, and separately, deliverable 12:**

12. **The independent audit (BEST_PRACTICE §6.11).** Its own session, whose **only deliverable is findings**. Protocol: scope declared up front (suite integrity, documentation truth, numerical foundations, error handling, science reproduction); **no deference to green CI or a green gate**; every claim backed by an executed command; findings ranked by severity with evidence attached; **fix nothing until agreed**. One such audit of a fully green suite in a source project produced eleven findings, including a reader returning plausibly-shaped wrong values through a silent fallback and twenty-odd tests a single file rename would silently filter out. None is visible from inside the fix-as-you-go loop, because that loop only looks where it is currently working. **An auditor who fixes as they go stops finding.**

---

## Part 8 — Workflow measurement (BEST_PRACTICE §6.9)

*One row per stage, filled from each wrap. Cheap, and the only way to know whether pre-validation is still paying. Marked **(proposed)** in BEST_PRACTICE — if it has not told us anything by Stage C, that is a finding about the rule and it should be dropped rather than kept out of politeness.*

| Stage | Rounds | Findings from pre-validation | Findings from the run | Defects found later in shipped code |
|---|---|---|---|---|
| 0 | 4 | 15 | 21 | 3 (PV-035/036/037 — all in Stage 0.2 code, found at 0.3) |
| A | 3 | 6 | 10 | 1 (PV-043, in the Stage 0.2 harness, found the first time any code raised a warning) |
| B | 3 | 0 | 12 | 1 (PV-057, a documentation/code disagreement in the Stage 0.3 mirror) |
| C | | | | |
| D | | | | |
| E | | | | |
| F | | | | |

**Reading after Stage 0, offered rather than asserted.** Pre-validation is still paying, but the split has moved. At checkpoint 0.1 every finding came from pre-validation; at 0.3 **thirteen of sixteen came from execution**, and three of those came only from CI running on a machine unlike the author's. The instrument that earned its place this round is not the mirror but the **second machine**: a 1-core Linux runner disagreed with a 16-thread Windows box about a constructed ratio, and the twin triggers disagreed with each other on the same commit. If that holds at Stage A, it is an argument for treating CI as a measuring instrument rather than as a gate — and the row above is what will say so.

---

## Part 9 — Change log

*Append-only. Every deviation from this document lands here, including deviations this document made from itself.*

| id | Date | Change | Rationale |
|---|---|---|---|
| C-001 | 23-Jul-2026 | Handover revision 1.0 created: v1 review, v2 design, 19 work-package prompts | Initial review and redesign |
| C-002 | 23-Jul-2026 | Revision 1.1: 19 work packages restructured into six self-contained layer prompts | Reduce handoff friction; 19 chats was too many |
| C-003 | 13-Aug-2026 | **Revision 2.0: `BEST_PRACTICE_v4.md` adopted unanimously.** Document restructured: verification debt first, ledger second, binding rules third | Rules and workflows adopted as instructed |
| C-004 | 13-Aug-2026 | **Test taxonomy replaced.** Three tiers (`contract`/`numeric`/`speed`) → seven categories (§2.3) with an exemption register | §3.3. The old `numeric` tier collapsed `reference`, `precision` and `robustness`, and there was no category at all for `vectorisation` or `metamorphic` |
| C-005 | 13-Aug-2026 | **All 19 absolute speed budgets withdrawn and replaced by ratios** (§2.4.3), with one shared timing helper doing pairing, rotation and median-of-per-repeat-ratios | §3.4.1–3.4.9. An absolute figure cannot detect the change it was written for; one source project shipped a 1.30× regression behind one |
| C-006 | 13-Aug-2026 | **Self-contained stage prompts withdrawn.** Prompts now name binding handover sections instead of restating them | §7.1 and §4.1 — one authority per fact; a rule restated in a prompt drifts. This reverses C-002's central mechanism while keeping its six-stage structure |
| C-007 | 13-Aug-2026 | **Stage 0 created; harness moved from last to first** | §3.4.2 (one shared timing helper, before the first budget) and §5.8 (every instrument ships its fault-injection self-test in the same round). Recorded as D-004 |
| C-008 | 13-Aug-2026 | **Python mirror promoted to a shipped deliverable** with one owner per kernel, `LIMITS.md`, and import-never-re-derive | §2.2, §2.3. Recorded as D-005 |
| C-009 | 13-Aug-2026 | **Verification-debt table added as Part 0**, nine rows | §6.13. A handover that lists only what works is an advertisement |
| C-010 | 13-Aug-2026 | **Oracle register added as Part 3**, twelve rows, three unfilled | §3.2. "If you cannot name what this will be checked against that was not built here, the prompt is not ready" |
| C-011 | 13-Aug-2026 | **`geo.scalebar` changed from refusing to drawing-and-reporting** | §4.5. Recorded as D-006 — the one place adopting the best practices changed a *function's behaviour*, not just its evidence |
| C-012 | 13-Aug-2026 | **F1–F18 compressed from eighteen paragraphs to a table of one-liners**, each pointing at the check that replaces it; narrative moved to `RECORDS.md` | §6.1 — a trap that has become a check does not stay prose |
| C-013 | 13-Aug-2026 | **Every quoted number marked unverified (V1)**; no stage may assert one until the mirror reproduces it | §F2 — seven of ten consecutive failures in one source project were a value recalled rather than read |
| C-014 | 13-Aug-2026 | **Warning gate adopted**: exactly one identifier (`geo:internal:testProbe`) permitted in a clean run | §4.8 |
| C-015 | 13-Aug-2026 | Three-file split adopted: `HANDOVER` / `RECORDS` / `BEST_PRACTICE` | §6.1. Recorded as D-007 |
| C-016 | 13-Aug-2026 | **Revision 2.1: Stage 0 checkpoint 0.1 (mirror) delivered and executed.** 37 values measured; **4 handover claims refuted and corrected**, 33 confirmed | §3.1 — validate the specification before implementing it. Evidence in `RECORDS.md` R-002 |
| C-017 | 13-Aug-2026 | **Polar stereographic reference value corrected**, 0.6116372 → 0.3430474163 | PV-002. The old figure matched no evaluation of any formula in either model; it was invented in revision 1.0 with a note asking for confirmation, and the confirmation refutes it |
| C-018 | 13-Aug-2026 | **Robinson node values corrected**, X 0.9427 → 0.8679 and Y 0.5722 → 0.6176 at lat 50 | PV-005. The old values were X-table entries used as Y, from latitudes 35 and 85 |
| C-019 | 13-Aug-2026 | **LCC cone-constant claim annotated**, not corrected: 0.6304962 is the *ellipsoidal* Clarke-1866 value; the spherical value geoMap needs is 0.6304776973 | PV-011. A real number from a model geoMap does not use — BEST_PRACTICE F1's plausible wrong answer in its purest form |
| C-020 | 13-Aug-2026 | **Robinson round-trip exception (5e-4°) withdrawn**; inversion method changed from swapped-table PCHIP to root-finding on the forward PCHIP | PV-004. The exception was an artefact of the prescribed method, not of the projection: measured 0.30° → 1.4e-13 |
| C-021 | 13-Aug-2026 | **Equal-area global-integral test restricted to the pseudocylindricals**; Lambert and Albers moved to the `AreaScale` instrument | PV-007. The azimuthal rim and conic apex are singular; a global quad integral there measures discretisation |
| C-022 | 13-Aug-2026 | **Scalebar gate must read linear scale (h, k), not area scale**, and must sample strictly inside the extent | PV-009, PV-008. An area-based gate passes every equal-area projection — including global Mollweide, the exact case the gate exists to catch |
| C-023 | 13-Aug-2026 | **Default speed repeat count set to 16, not 15** | PV-012. "Use 15" and "use a multiple of the number of points" conflict for a two-point budget; balanced rotation wins, since an unbalanced order reintroduces the bias rotation exists to remove |
| C-024 | 13-Aug-2026 | Warning-inventory instrument documented as **under-reporting** (last identifier per test method only) | PV-013. Adequate for an emptiness gate, inadequate for counting; no count from it may be quoted |
| C-025 | 15-Aug-2026 | **Revision 2.2: the harness was EXECUTED.** Tier A established; V5 and V6 discharged; six defects found by running code that static analysis had already passed | R-004. The decisive lesson: two of the six passed the *green gate* as well, and only reading the log caught them |
| C-026 | 15-Aug-2026 | **Speed-fixture sizes must be measured, not chosen** | PV-016. A constructed 4× workload read **1.434** at N=2e5 with fixed cost at 85% of the small point and the two arrays straddling L3. The measured ladder (2e5→1.434, 1e6→3.491, 4e6→4.111, 1.6e7→3.942) is now a comment in the test |
| C-027 | 15-Aug-2026 | **No test may reset the record store**; the one test that proves `reset` works saves and restores | PV-020, PV-021. The report read "0 ratio records" while three speed tests passed — the exact silence §5.3 exists to prevent |
| C-028 | 15-Aug-2026 | Three stale `%#ok<AGROW>` pragmas removed | Found by MATLAB's Code Analyzer; the project's own static checker was blind to them. An unnecessary suppression teaches the next reader the pattern is dangerous when it is not |
| C-029 | 15-Aug-2026 | **`mlint_lite.py` from shAnalysis is to be adopted**, not re-derived | It catches `(expression).method` parse errors and package-function-dot runtime errors that `tools/mcheck.py` cannot see. Deferred to its own round rather than mixed into unrelated work (§6.6). **Still open after Stage 0.3** |
| C-030 | 15-Aug-2026 | **Revision 2.3: Stage 0.3 delivered and executed. Stage 0 is DONE.** Static audit with 13 fault-injection fixtures, oracle rows O7/O8, v1 probes, option inventory. Debts V4, V7 and V9 discharged | R-005. Green on the target machine and on CI, both twin triggers |
| C-031 | 15-Aug-2026 | **`TolMass` set to 1e-13 from measurement**, replacing the 1e-12 guess | V7. The measured floor is 2.15e-14, so the new tolerance is *tighter* than the one it replaces — the only direction a measurement is allowed to move a guess |
| C-032 | 15-Aug-2026 | **Oracle O7 demoted from authority to corroboration**; conservative regrid certified analytically instead | D-015, limit L11. Measured 21% of signal RMS globally |
| C-033 | 15-Aug-2026 | **Part 5's F16 illustration corrected**: measured worst is 10 lines at span 45°, not "3 or 11" | PV-030. The defect reproduces; the illustration did not. A rationale carrying a number nobody measured is exactly what V1 exists to prevent, and this one survived three revisions |
| C-034 | 15-Aug-2026 | **Constructed speed fixtures must use one array** (D-016, OB-9); the harness's own accuracy fixture rebuilt on that shape | PV-035, PV-036. **The tolerance never moved** — only the fixture did |
| C-035 | 15-Aug-2026 | **Eleven `PROVISIONAL` stamps removed** | R-004 binding item 1. A debt marker that outlives its debt teaches the next reader to ignore markers |
| C-036 | 15-Aug-2026 | **`.gitattributes` added**; `tools/gates.sh` had never been runnable from a Windows working copy | PV-029. Git for Windows checks an LF script out as CRLF and bash dies on the shebang line. The local gate WORKFLOW.md tells every contributor to run before pushing had never once run locally, and it passed in CI, so the failure was invisible from the side that matters least |
| C-037 | 15-Aug-2026 | **`tools/mcheck.py` transpose rule corrected**: a quote preceded by whitespace is a string, not a transpose | PV-037. It reported "unmatched `end`" **228 lines from the cause**, in a function that was correct. Two fixtures added, and the pre-fix parser was shown to fire on one of them |
| C-038 | 15-Aug-2026 | **`WORKFLOW.md` loop rewritten**: Claude branches, pushes and opens the PR; Matthias merges. Three of the four rows in its capability table had become false | D-014 |
| C-039 | 15-Aug-2026 | **`Contents.m` created as the single version authority** (`2.0.0-alpha.0`), audited against README, CHANGELOG, CITATION.cff, `geoMap.prj` and `info.xml` | §2.7, one authority per fact. Until it existed the audit had to report its own version check as *deferred* — a gate with no subject |
| C-040 | 15-Aug-2026 | **Stage A delivered and executed, in three checkpoints.** 113 points predicted, 113 run, 113 passed; green gate on all six conditions | R-006. `+geo` exists |
| C-041 | 15-Aug-2026 | **`crs.Domain` gains `SingularityDeg` and `ClipIsCosmetic`**, a deviation from §7.3's field list | D-017, PV-038. Declaring v1's rounded literals in a tidier struct would have reproduced F12 rather than fixed it |
| C-042 | 15-Aug-2026 | **`geo.greatCircle` signature changed to Nx2 pairs** | D-018, PV-042. §7.3's four positional arguments break the arity cap the same document sets |
| C-043 | 15-Aug-2026 | **`SpatialJumpThreshold` changed from degrees to kilometres** | D-019. v1's degree-space measure meant different distances at different latitudes |
| C-044 | 15-Aug-2026 | **The `geo.grid` speed budget row in §2.4.3 is refuted and replaced** | PV-053. Quadrupling `numel(Z)` requires doubling both axes, and validation is O(nLon + nLat), so the specified comparison must read ~2. The replacement asserts the actual claim: `geo.grid` against one pass over Z, 0.071 against 0.1 |
| C-045 | 15-Aug-2026 | **`suppressWarning` now restores `lastwarn` as well as the enable flags** | PV-043. A disabled warning still sets `lastwarn`, so §2.5's prescribed mechanism failed the warning gate the first time any code raised a warning |
| C-046 | 15-Aug-2026 | **Error identifiers are passed to shared validators in full, never composed from a prefix** | PV-049. A composed identifier exists nowhere in the source as a literal, so no static reader can find it, and the audit correctly read the help as lying. Generalises D-011 |
| C-047 | 15-Aug-2026 | **`identifierAgreement` is package-wide**; the superseded per-file form is frozen in place | PV-050, PV-051. Per-file precision is unachievable once a shared validator legitimately raises on a caller's behalf |
| C-048 | 15-Aug-2026 | **Frozen acceptance criteria whose keys contain dots use LIST paths** | PV-048. A dotted path split a key in the middle of a number and reported seven present criteria as absent — §2.7 inside the instrument that enforces §2.7 |
| C-049 | 15-Aug-2026 | **Stage B delivered and executed, in three checkpoints.** 182 points predicted, 182 run, 182 passed. **V2 discharged**: all sixteen projections now exist in MATLAB and agree with the mirror and its oracles | R-007 |
| C-050 | 15-Aug-2026 | **`TolMass` corrected from 1e-12 to 1e-13**, the value four documents already claimed | PV-057. The mirror computed `10^ceil(log10(worst)+1)`, which returns a whole decade higher than `10^(floor(log10(worst))+1)`. No check could see it: every check compared the measurement against the wrong tolerance and passed. Debt V1's failure mode, inside the instrument built to prevent it |
| C-051 | 15-Aug-2026 | **The Mollweide early exit in §7.4 is reversed** | PV-055. A break on the array maximum makes each element's iteration count depend on its neighbours, so a batched result differs from a scalar one and the `vectorisation` contract fails. Fifteen unconditional iterations instead |
| C-052 | 15-Aug-2026 | **`crs.Domain` is consumed by `geo.project` exactly as declared**, and no bare `cosc` literal appears in the file | F12 closed in code, and enforced statically by the audit |
| C-053 | 15-Aug-2026 | **Three v1 colormap presets dropped**: `viridis`, `magma`, `cividis` | PV-060. They exist only as third-party tabulated data, and this toolbox generates rather than copies. `parula`, `jet`, `turbo` and `gray` are delegated to base MATLAB. An Nx3 array is accepted anywhere a name is, which is the migration path |
| C-054 | 15-Aug-2026 | **The diverging colormap is ORIGINAL**, generated lightness-monotone on each limb | §7.4 B.3.1 asked for exactly this, and the help says it is original rather than implying provenance it does not have |
| C-055 | 15-Aug-2026 | **C-053 REVERSED: viridis, magma and cividis reinstated** as CC0 tables, attributed in LICENSE | PV-063. All three are CC0 public-domain dedications, so nothing was ever restricted. And a generated substitute would have been a lie: these encode a MEASURED perceptual property this project has no instrument to reproduce |
| C-056 | 15-Aug-2026 | **Stage C delivered and executed.** 205 points, 205 passed. **V3 discharged; O5 and O6 filled** | R-008 |
| C-057 | 15-Aug-2026 | **The `geo.region` file hook is closed**, converting Stage A's deferred contract test into a success test | The pattern worked exactly as designed: the identifier and its test existed before the capability, so Stage C converted rather than invented |
| C-058 | 15-Aug-2026 | **GeoTIFF and worldfile input deferred** to its own round, with a named identifier and contract test shipped now | §6.6. A binary TIFF tag parser does not belong rushed in beside three other readers |
| C-059 | 16-Aug-2026 | **`geo.readGrid` gains `Region` and `Stride`**, turned into NCREAD start/count bounds rather than applied after a full read | A global 60-arc-second field is 1.74 GB resident and the 30-arc-second one 6.95 GB, because NCREAD returns double. A regional basemap needs a few thousand cells of it |
| C-060 | 16-Aug-2026 | **Region selection grows outwards in INDEX space, never by an epsilon** | PV-068. Comparing `centre >= lo - h` decides an exact cell-edge boundary by the last bit, and did: latitude 30–72 came back starting at 30.008. Coverage is now guaranteed by construction, at a cost of at most one surplus cell per edge |
| C-061 | 16-Aug-2026 | **A seam-crossing window is read as two blocks and returned as ONE monotone axis** continuing past 180 | `geo.grid` requires strict monotonicity, and a seam in the middle of an axis is not something a downstream consumer should have to rediscover |
| C-062 | 16-Aug-2026 | **NetCDF orientation is READ from the variable's dimension names**, not inferred by comparing sizes | ETOPO stores z as (lon,lat). Subsetting forces the question anyway — start/count must be in the file's order — and the answer also makes a square grid readable, which the size heuristic could never resolve |
| C-063 | 16-Aug-2026 | **`readGrid(G, Region=…)` now applies the selection to a grid in memory** instead of ignoring it | PV-072. The same two arguments meant something on a filename and nothing on the grid that filename produced |
| C-064 | 16-Aug-2026 | **A 10-arc-minute topography sample ships in `data/`**, block-averaged from ETOPO 2022 ice surface, int16, 4.0 MB | Doc examples and graphics tests need a real basemap without the 478 MB original. Averaged, not subsampled: measured 91.95 m vs 124.55 m mean |∂z/∂λ|, i.e. subsampling is 35% rougher, and hillshade is a derivative |
| C-065 | 16-Aug-2026 | **Ice surface is the basemap default; bedrock is supported, not default** | Coastlines trace the ice front. At 80°S 100°W the surface is +2 080 m and the bed −1 158 m, so a bedrock basemap paints the inside of the coastline as ocean — two layers of one map contradicting each other |
| C-066 | 16-Aug-2026 | **The windowed-read speed fixture is deflate-compressed and chunked like a real product** | PV-069. Uncompressed, fixed cost exceeded data cost and the budget of 5 was unreachable by ANY implementation. The budget did not move; the fixture became able to see the property it asserts |
| C-067 | 16-Aug-2026 | **Stage D checkpoint D.0 delivered and executed.** 227 points, 227 passed. **O9 and O10 filled** | R-009 |
| C-068 | 16-Aug-2026 | **`geo.crs`'s domain table now takes the hemisphere and the cone constant**, not just the name | PV-073. Polar stereographic and Lambert conformal diverge at a pole that DEPENDS on those parameters, and a name-keyed table returned [-90 90] for both. `geo.project(0, -90, polarstereographic north)` returned 3.266e+16 |
| C-069 | 16-Aug-2026 | **v1's five plumbing functions replaced by one listener and one registry**, `fig.UserData.geoMapLayout` | F15. `SizeChangedFcn` chaining could not be enumerated, detached or de-duplicated, swallowed exceptions silently, and left the newest link unprotected. Listeners compose by construction |
| C-070 | 16-Aug-2026 | **The basemap's shading is COMPUTED, not lit.** No `light`, no `material`, no `shading interp` | F9, D-009. v1's output depended on renderer, driver and view. An intensity array can be asserted; an OpenGL frame cannot |
| C-071 | 16-Aug-2026 | **Graticule densification is measured on the drawn result**, not fixed at v1's 200 points per line | The criterion is that no projected segment exceeds 1/200 of the map diagonal. v1's fixed count was far too many for a regional map and too few at an azimuthal rim |
| C-072 | 16-Aug-2026 | **Graticule labels are placed analytically**, replacing v1's tangent heuristics, edge bias, farthest-point search, frame-circle cap and 1.05 snap tolerance | Those five interacted; the azimuthal label defects were not one bug but several, each repaired by adding another case. A label now sits at the last finite projected point of the line it names |
| C-073 | 16-Aug-2026 | **`geo.unproject` is used to CHECK label placement, not to perform it** | Deviation from the handover's D.1.3, argued rather than silent: a placement computed with the inverse and then checked with the inverse would be checked against itself |
| C-074 | 16-Aug-2026 | **The frame's resize is solved in closed form**, not iterated, and the axis limits are SET from pristine data limits | PV-075. v1 unioned them and ratcheted the map smaller over repeated resizes. Drift is now exactly 0 over ten cycles and the thickness change on halving the width is 0.00% |
| C-075 | 16-Aug-2026 | **`geo.internal.layout` uses command dispatch, not the handover's `layout.register(...)` struct-of-handles notation** | Deviation, recorded. `geo.cache` already established command dispatch in this package; identifiers stay statically visible to the audit; and closures over a figure handle are the very failure mode v1's chaining suffered from |
| C-076 | 16-Aug-2026 | **Stage D checkpoint D.1 delivered and executed.** 262 points, 262 passed | R-010 |
| C-077 | 16-Aug-2026 | **`geo.graticule` samples ADAPTIVELY**, bisecting only segments longer than the target, instead of resampling the whole line uniformly in degrees | R-011. Uniform sampling wasted a factor of 436 on transverse Mercator and still could not meet the criterion. A whole graticule now costs about 1 800 points where one line used to cost 4 096 |
| C-078 | 16-Aug-2026 | **A segment that will not shrink under bisection is broken with a NaN**, not drawn | PV-080. It is a branch cut, not a curve, and the test needs no table and no per-projection case. Caught a 2*pi jump on transverse Mercator's back meridians that would otherwise have drawn a straight line across every such map - F2's cousin |
| C-079 | 16-Aug-2026 | **C-071's 8192-point cap, its refinement guard and the transverse Mercator test exclusion all removed** | All three were scar tissue around a mis-diagnosis. Bisection can only shorten a segment, so the guard is unnecessary by construction |
| C-080 | 16-Aug-2026 | **Graticule lines now reach the map edge**, by bisecting the segment that straddles the domain boundary | Measured on orthographic, whose horizon is at radius 1 exactly: shortfall 1.5e-9. Previously a line stopped at whichever sample was last inside |
| C-081 | 16-Aug-2026 | **Stage D checkpoint D.1b delivered and executed.** 263 points, 263 passed | R-011 |
| C-082 | 16-Aug-2026 | **`geo.scalebar` chooses the ground distance FIRST and draws the bar that long** | PV-082. v1 drew a fixed 90-point bar and labelled it with the nearest ladder entry to whatever that spanned - errors near 50% on the one element of a map meant to be measured. Asserted by walking the drawn bar: agreement 7.75e-10 |
| C-083 | 16-Aug-2026 | **The bar is calibrated at its own position and along its own direction** | v1 measured along a meridian at the projection's reference point and applied it to a horizontal bar in the corner. Two separate errors, worth 59% and 9.3% when measured |
| C-084 | 16-Aug-2026 | **The nice-length ladder is generated, not tabulated, and chosen in LOG space** | v1's table clamped at 1 km and 5000 km and picked nearest in linear space, biasing to the smaller neighbour across every decade |
| C-085 | 16-Aug-2026 | **North is measured AT the arrow, not once for the map** | v1 used one bearing from the projection's reference point. On a Lambert conformal conic the two upper corners differ by 205.7 degrees of convergence |
| C-086 | 16-Aug-2026 | **`geo.readCoastline("builtin")` now reads a shipped Natural Earth coastline** | PV-081. It loaded MATLAB's coastlines.mat, which does not ship with R2026a. A path with no caller is a path with no test, whatever the coverage table says |
| C-087 | 16-Aug-2026 | **The branch-cut rule is promoted to `geo.internal.projectPolyline`** | R-011 left this as the condition for promotion: the moment a second caller needs it. `geo.coastline` was that caller |
| C-088 | 16-Aug-2026 | **Stage D checkpoint D.2a delivered and executed.** 285 points, 285 passed. **D.2 split; colorbar and inset are D.2b** | R-012 |
| C-089 | 16-Aug-2026 | **v1's four colorbar implementations become one `geo.colorbar`** with Style native/gmt/half/dual | R-013. Two of the four were byte-identical copies in different files. A continuous bar is 9 objects where v1's was about 283 |
| C-090 | 16-Aug-2026 | **An end cap is drawn only where the data continues** | PV-087. v1 drew both triangles whenever Arrows was on and varied only their colour |
| C-091 | 16-Aug-2026 | **Colorbar and inset handles survive a resize** | PV-086. All three of v1's custom bars returned handles invalid after the first window drag |
| C-092 | 16-Aug-2026 | **`geo.internal.plottedBox` promoted** - the map's rectangle in figure points, in one place | PV-089. v1 had five copies |
| C-093 | 16-Aug-2026 | **Stage D checkpoint D.2b delivered and executed.** 305 points, 305 passed | R-013, written one PR late - PV-094 |
| C-094 | 16-Aug-2026 | **`geo.overlayPolygons` is new**: a value per irregular polygon, for mascon and basin fields | R-014. A regular grid cannot represent a mascon solution; v1 forced one onto a raster |
| C-095 | 16-Aug-2026 | **A seam-crossing ring is CLIPPED, not broken** | PV-090. Breaking leaves open fragments and a patch closes them across the map. No split gave one patch spanning 94% of the map; breaking discarded the polygon entirely |
| C-096 | 16-Aug-2026 | **`geo.stipple` is new**: significance masking, subsampled by a regular stride and never randomly | v1 could not draw a mask at all. Determinism asserted as bit-identical output |
| C-097 | 16-Aug-2026 | **`geo.overlayContours` drops v1's two jump heuristics and their three constants** | PV-092 |
| C-098 | 16-Aug-2026 | **Stage D checkpoint D.3a delivered and executed.** 327 points, 327 passed | R-014 |
| C-099 | 16-Aug-2026 | **The wiggle scale is computed ONCE for the whole track** | PV-095. v1 computed it per run, so a track broken by one missing sample drew two ribbons at two scales - and a wiggle's entire content is its amplitude |
| C-100 | 16-Aug-2026 | **The size legend uses the marker's own radius rule** | PV-096. v1 drew sqrt(area/pi) where scatter uses sqrt(area)/2, so its legend was 11% small and decoded its own markers wrongly |
| C-101 | 16-Aug-2026 | **Every high-level plotting call is guarded by the hold state** | PV-097. scatter3 clears the axes: a map of fifty objects came back with five. v1 never met it because it drew in one fixed order |
| C-102 | 16-Aug-2026 | **`geo.internal.colourScale` promoted** - one colour scale rule for every overlay | F6 for the fifth time, rejected within the round again |
| C-103 | 16-Aug-2026 | **Stage D checkpoint D.3b delivered and executed. STAGE D COMPLETE.** 347 points, 347 passed | R-015. Thirteen elements and six internals replace v1's monolith, its two clones, its five plumbing functions and its four colorbars |
| C-104 | 16-Aug-2026 | **`print` is the primary export route, not `exportgraphics`** — §7.7 deliverable 5 said "exportgraphics with print fallback" | PV-100. Measured: `exportgraphics` ignores `PaperPosition` and crops to content, giving 12.58 cm and 27.7 cm for a page asked for at 17.0 cm in two configurations. `print` gives 17.004 cm. The instrument that keeps the contract leads |
| C-105 | 16-Aug-2026 | **Audit check 13: `orchestrationPurity`** — a file declaring `L4-FRONT` may call no drawing primitive and may not exceed 200 executable lines | §7.7's hard rule. It belongs in the audit, not in a test class: it must apply from the moment the first front is written, and the audit already ships fault injection. Two fixtures added, one per shape of the defect |
| C-106 | 16-Aug-2026 | **The purity marker must be a whole help line, not a substring** | PV-102. Written as a `contains` it fired on the file that only *explains* the rule. Third occurrence of "prose about a token is not the token" in this project |
| C-107 | 16-Aug-2026 | **`geo.export` is an L4 utility, not an L4 front**, and declares no marker | It draws nothing and orchestrates nothing. Marking it would have meant a false pass or a raised 200-line limit, and §4.6 forbids the second |
| C-108 | 16-Aug-2026 | **`geo.internal.writeFigureFile` split out** — one decision on which route writes which extension | D-003: `export.m` reached 441 lines. The audit's answer was a justification line; the right answer was a split |
| C-109 | 16-Aug-2026 | **`geo:export:WorkerFailed` wraps a builder's failure on a worker** | Measured: a builder reaching a local function of the calling script fails with "Unrecognized function or variable", which names the symbol and not the cause |
| C-110 | 16-Aug-2026 | **Exemption withdrawn: `geo.export \| reference`** | Nothing certifies a PDF's content, but its own MediaBox certifies its size, and the size is the claim. Second exemption withdrawn on inspection |
| C-111 | 16-Aug-2026 | **Block keywords joined the `shadowedBuiltins` watch list** — `methods`, `properties`, `events`, `enumeration`, `arguments` | PV-103. A variable named `methods` ran fine in MATLAB and made `tools/mcheck.py` report the file unbalanced by three levels. Two gates that read the source differently only pay if the disagreement is a finding |
| C-112 | 16-Aug-2026 | **A metamorphic test realises its figure before comparing** — one discarded export first | PV-104. On software OpenGL the first export differs from the second in **31.3%** of its pixels and the second and third are identical to the byte. Both tests were comparing first-render against second-render, so neither could isolate what it existed to test: the batch test called a warm-up difference an ordering effect |
| C-113 | 16-Aug-2026 | **What `geo.export` controls across a first export is asserted separately** — same dimensions, same route, same reported page | The renderer's warm-up is not geoMap's to certify; the page size is, and the builder workflow exports every figure exactly once |
| C-114 | 16-Aug-2026 | **A CI-only failure is diagnosed, never tolerated** | The instinct on a platform-specific graphics failure is to weaken the claim. §4.6 forbids it. Making the test discriminate — three exports, 1-vs-2 against 2-vs-3 — cost CI cycles and turned a red square into PV-104. A `drawnow` fix was tried, changed nothing to the digit, and was removed rather than left in looking like one |
| C-115 | 16-Aug-2026 | **Stage E checkpoint E.0 delivered and executed.** 370 points, 370 passed | R-016 |
| C-116 | 16-Aug-2026 | **`geo.title` added as an L3 element**, and `title`, `xlabel`, `ylabel`, `legend`, `sgtitle` added to the audit's banned primitives | PV-105. The Stage E rule fired on real code for the first time: `geo.map` needed a title, no element drew one, so the capability was written rather than inlined. MATLAB's `TITLE` anchors to the axes box, which under `axis equal` is 53.03 pt above the map |
| C-117 | 16-Aug-2026 | **`geo.map`'s element options take `false`, `true` or a struct** rather than restating 120 flat option names | The front stays at 128 executable lines against a 200 budget. v1's flat spellings become a separate compatibility layer (E.1b), so no option table lives in the front |
| C-118 | 16-Aug-2026 | **The raw triplet spends the three positional slots on lon, lat and Z; the projection moves to `CRS =`** | D-003 caps positional arity at 3. The projection gives way because it has a name |
| C-119 | 16-Aug-2026 | **Region outline flagged as a missing L3 capability, not improvised** | PV-106. v1's `AreaOfInterest` has no v2 element. Named in `geo.map`'s LIMITATIONS rather than bent onto `geo.coastline` |
| C-120 | 16-Aug-2026 | **A front may hand its shared typeface only to elements that draw text** | PV-107. MATLAB's `arguments` block rejects an unknown name-value pair rather than ignoring it; `geo.coastline` refused `FontSize` |
| C-121 | 16-Aug-2026 | **Stage E checkpoint E.1a delivered and executed.** 392 points, 392 passed | R-017. `geo.map` is 128 lines against `geoImagesc`'s 3413 |
| C-122 | 16-Aug-2026 | **PV-106 WITHDRAWN.** `geo.coastline` has drawn region outlines via `Kind = "outline"` since D.2; the claim that no element did was made from a bulk grep of its `arguments` block without reading its help | R-018. The false flag reached `geo.map`'s LIMITATIONS, R-017 and a merged PR |
| C-123 | 16-Aug-2026 | **`geo.region` fills `Outline` for a box** — four corners, closed | PV-109. `Outline` meant "the polygon, if this region was given as one"; it now means "the vertices of this region" for every region, so `geo.map(Region = ...)` is a pure forward with no geometry in the front |
| C-124 | 16-Aug-2026 | **A test asserted the defect.** `TestA3_region` required `isempty(named.Outline)` with the diagnostic "an empty outline is how a caller knows" | R-018. The test did not miss the gap, it specified it — a shape no single function was wrong about and nothing downstream could use |
| C-125 | 16-Aug-2026 | **Stage E checkpoint E.1b delivered and executed.** 394 points, 394 passed | R-018 |
| C-126 | 16-Aug-2026 | **V9 DISCHARGED.** All 120 `geoImagesc` options translate to an option that exists or raise with the replacement named; 92 and 28 | R-019. Both lists read from source, so neither can drift from the code |
| C-127 | 16-Aug-2026 | **The option authority is v1's source, not the Stage 0 inventory** | PV-110. The inventory's "fronts" column matched by prefix, so `geoImagescPoints` counted as `geoImagesc`; the count was 114 and is 120 |
| C-128 | 16-Aug-2026 | **`geo.map` honours `CRS =` in every call shape** | PV-111. Written narrow it worked only for the raw triplet and was silently ignored by `geo.map(G, CRS = c)` — the shape the translator produces |
| C-129 | 16-Aug-2026 | **A struct value passes through the translator untouched** | PV-112. Nine v1 names are also v2 names, so a translated list still contains names the table recognises. Translating twice now changes nothing, and that is asserted |
| C-130 | 16-Aug-2026 | **`geo.v1.imagesc`, deliberately not `geoImagesc`** | OB-7 keeps v1 installed until Stage F; a file of that name would shadow it or be shadowed by it depending on path order |
| C-131 | 16-Aug-2026 | **Stage E checkpoint E.1c delivered and executed.** 410 points, 410 passed | R-019 |
| C-132 | 20-Aug-2026 | **PV-114 closed: the cold render is the PROCESS's first rasterisation, not each figure's.** One discarded export in `TestClassSetup` | Four independent figures at three exports each came back clean in one run, which rules out per-figure. Intermittent in occurrence, exactly reproducible in magnitude — 42 176 pixels every time — and a noisy rasteriser does not repeat a number |
| C-133 | 20-Aug-2026 | **No change to `geo.export`.** Six CI cycles, one line of test setup | The `drawnow` tried at PV-104 was removed when it changed nothing and nothing replaced it. A platform-scheduling artefact is absorbed where it arises, not tolerated in an assertion (§4.6) |
| C-134 | 20-Aug-2026 | **`geo.internal.dataFile` locates shipped data from the package, not the path**; `geoMapRoot` banned inside `+geo` | PV-115. `geo.readCoastline("builtin")` failed on an installed toolbox because `geoMapRoot` lives in `tests/`. Every test passed for as long as it existed |
| C-135 | 20-Aug-2026 | **`geo.readGrid("builtin")`** added, matching `geo.readCoastline`'s idiom | A front should ask for the builtin topography, not know where it lives |
| C-136 | 20-Aug-2026 | **`geo.region` reports the padding it APPLIED, not the one it was given** | PV-116. A box and a preset are stated extents and are still not padded; the struct no longer claims otherwise, and the help states the rule |
| C-137 | 20-Aug-2026 | **The data fronts share one option list, one resolver and one merge rule** — `backdropOptions`, `mapBackdrop`, `withData` | v1's two data fronts each carried their own extent logic and the copies disagreed about the pad. `geo.trackmap` and `geo.pointmap` are 17 executable lines each |
| C-138 | 20-Aug-2026 | **Every text-level check strips comments before matching** | PV-117, the fourth occurrence of "prose about a token is not the token" — this time in the test written to catch PV-115 |
| C-139 | 20-Aug-2026 | **Stage E checkpoint E.2 delivered and executed.** 431 points, 431 passed | R-020 |
| C-140 | 20-Aug-2026 | **`geo.series` added as an L3 element**; reference lines are drawn as series | The Stage E rule fired a third time: `geo.timeseries` is a front, a front draws nothing, and nothing drew a series. A horizontal line at a constant value over the time span IS one |
| C-141 | 20-Aug-2026 | **`geo.region` carries `IsBox`** | PV-118. Filling `Outline` for boxes made `geo.splitTracks`' rectangle test unreachable. `Outline` says what to draw, `IsBox` says what to test against |
| C-142 | 20-Aug-2026 | **`geo.quantile` forces both sides to columns and restores the shape of `p`** | PV-119. It documented "Z any size" and raised on a matrix with two percentages; implicit expansion built a 2×2. Invisible because every caller passed a scalar `p` |
| C-143 | 20-Aug-2026 | **Stack spacing is the MEDIAN of the per-station 5–95 ranges, not the maximum** | v1's maximum let one noisy station flatten every other trace. Asserted by adding a station ten times noisier |
| C-144 | 20-Aug-2026 | **A front may write `axH.YLabel.String`; it may not call `ylabel()`** | Configuration of an object the axes already owns creates nothing; the function call creates a Text. The distinction is narrow enough to state rather than infer |
| C-145 | 20-Aug-2026 | **`keep` promoted to `GeoMapTestCase`, both private copies removed** | PV-120. F6 for the sixth time, and PV-099 says a base-class method colliding with a suite's private one makes the framework drop that suite |
| C-146 | 20-Aug-2026 | **Stage E checkpoint E.3 delivered and executed.** 450 points, 450 passed | R-021. Prediction counted mechanically and correct, after two misses |
| C-147 | 20-Aug-2026 | **`geo.map` forwards `Parent` to `geo.basemap`** | PV-121. The option was declared, documented and never read; `geo.map(G, crs, Parent = ax)` drew a new figure. The E.1a test passed for the wrong reason and now asserts the axes identity |
| C-148 | 20-Aug-2026 | **`GeoMapTestCase.verifyIsAPureFront`** — one banned list for every front | PV-122. Four near-copies had drifted: E1's and E2's lists were shorter, so three fronts were never checked for `ylabel`, `xlabel`, `legend`, `sgtitle` |
| C-149 | 20-Aug-2026 | **`geo.panel` uses `PlotBoxAspectRatio`, never `Position`** | `tiledlayout` ignores `Position` on its children — the assignment warns and does nothing. v1's workaround carried forward with its constraint written at the code |
| C-150 | 20-Aug-2026 | **Panel labels flagged, not improvised** | A corner annotation is not a title and no L3 element draws one. Fourth time the Stage E rule has fired; second still open |
| C-151 | 20-Aug-2026 | **STAGE E COMPLETE.** 468 points, 468 passed | R-022. Six fronts, two elements the rule demanded, `geo.map` at 128 lines against `geoImagesc`'s 3413 |

---

## Appendix A — v1 → v2 migration map

| v1 (33 functions) | v2 destination |
|---|---|
| `geoImagesc` | `geo.map` (front) + `geo.basemap`/`graticule`/`frame`/… (elements) |
| `geoImagescTrack` / `geoImagescPoints` | `geo.trackmap` / `geo.pointmap` + `geo.overlayTrack`/`overlayPoints` |
| `geoImagescTimeSeries` / `geoImagescMulti` | `geo.timeseries` / `geo.panel` |
| `geoSplitTracks` | `geo.splitTracks` |
| `geoProject` / `geoProjectionReferencePoint` | `geo.project` + `geo.unproject` + `geo.scaleFactors` (reference point becomes CRS-derived) |
| `geoAreaOfInterest` | `geo.region` |
| `geoColormapPreset` / `geoDiscretizeColormap` / `geoMapToTruecolor` / `geoPercentileRange` | `geo.colormaps` + `geo.quantile` / `geo.symmetricLimits` |
| `geoResampleGrid` | `geo.regrid` |
| `geoNiceTicks` / `geoNiceGraticuleStep` | `geo.niceTicks` |
| `geoUnwrapAntimeridian` / `geoInsertNaNBreaks` | `geo.wrapLongitude` + `geo.splitAntimeridian` |
| `geoCoastlineFrom{Shapefile,GSHHG,NetCDF,Text}` | `geo.readCoastline` (+ `geo.readGrid`, `geo.cache`) |
| `geoSegmentedFrame` / `geoAttachFrameResize` | `geo.frame` + `geo.internal.layout` |
| `geoScaleBar` / `geoNorthArrow` / `geoCompassAnchor` | `geo.scalebar` / `geo.northarrow` (anchor logic internal) |
| `geoGmtColorbar` | `geo.colorbar` (`Style="gmt"`) |
| `geoChainCallback` / `geoAttachResizeCallback` / `geoRegisterInsetRect` / `geoGetOtherInsetRects` / `geoAvoidRectCollisions` | `geo.internal.layout` |
| `demo_geoImagesc` / `test_geoImagesc` | `GettingStarted` (Stage F) / the `matlab.unittest` suite (Stages 0–F) |

## Appendix B — v1 numerical behaviours to preserve (regression anchors)

Each is ported from a verified v1 file, not rewritten, and each acquires a named regression test.

- Polar stereographic in the Snyder 21-8/21-9 form, with hemisphere-dependent Y sign and far-pole NaN.
- LCC and Albers cone-constant formulae and the tangent-case limit.
- Mollweide Newton scheme (early exit added, nothing else changed).
- Winkel Tripel `φ₁ = acos(2/π)`; Aitoff sinc handling near α = 0.
- GSHHG microdegree scaling and the 0–360 → ±180 rewrap.
- Shapefile record traversal by declared content length (robust to Z/M payloads).
- `splitTracks`: median-of-positive-`dt` auto threshold; region removal forces breaks.
- Panel equal-height via `PlotBoxAspectRatio` (`tiledlayout` forbids `Position` sets).
- `geoAvoidRectCollisions` geometry, verbatim.

## Appendix C — Test class skeleton

```matlab
classdef TestB1_projection < GeoMapTestCase
    methods (Test, TestTags = {'contract'})
        function mercatorReturnsNaNOutsideDomain(tc)
            % F3: v1 clamped to +/-85 and drew data at the wrong place.
            [x, y] = geo.project(0, 87, tc.crsMercator);
            tc.verifyTrue(isnan(x) && isnan(y));
        end
    end
    methods (Test, TestTags = {'reference'})
        function agreesWithProj(tc)
            % Oracle O4 (pyproj), values from mirror/out/reference_values.json.
            ref = tc.loadMirrorReference("project_mollweide");
            [x, y] = geo.project(ref.lon, ref.lat, tc.crsMollweide);
            tc.verifyEqual([x y], [ref.x ref.y], 'AbsTol', tc.TolRef.O4);
        end
    end
    methods (Test, TestTags = {'metamorphic'})
        function longitudeShiftEquivariance(tc)
            % The property F2 violated. Bitwise is not expected: the two
            % paths wrap at different points, so eps-level it is.
            a = geo.project(tc.lonS,      tc.latS, geo.crs("robinson"));
            b = geo.project(tc.lonS + 40, tc.latS, geo.crs("robinson", ...
                    CenterLongitude = 40));
            tc.verifyEqual(b, a, 'AbsTol', 1e-12);
        end
    end
    methods (Test, TestTags = {'speed'})
        function mollweideAgainstEquirectangular(tc)
            tc.assumeSpeedTestsEnabled();
            % N = 1e6; expected ~30 (mirror); budget 90. PREDICTED - V5.
            tc.assertRatioBudget( ...
                @() geo.project(tc.lonM, tc.latM, tc.crsMollweide), ...
                @() geo.project(tc.lonM, tc.latM, tc.crsEq), ...
                90, 30, "project mollweide / equirectangular, N=1e6");
        end
    end
end
```

## Appendix D — `RECORDS.md` template

`RECORDS.md` holds evidence and **never holds status**. One entry per stage; a stage's entry is written at its green gate, and superseded scripts are frozen inside it rather than rewritten.

```markdown
## R-00n — Stage <X>, <date>, tier <A|B>

**Confirming run.** Runner invocation, machine tag, wall time, predicted
vs executed point count reconciled three ways, warning inventory.

**Pre-validation findings.** Each with its measurement, and whether it
changed the specification, the code, or nothing.

**Findings from the run.** Each with the log excerpt that showed it.

**Numbers measured this round.** The table that later stages cite.

**Superseded scripts.** Frozen verbatim, as the record of their own round.

**Binding items a later stage could be wrong for not reading.** Short.
This is the section the next session actually reads.
```

---

*geoMap v2 HANDOVER, revision 2.3 · 15-Aug-2026 · prepared with the assistance of Claude Opus 5 (Anthropic). Many numbers in this document are now measured and carry their evidence; the rest are still model-derived — Part 0 says which is which, and debt V1 stays open until the last of them is measured at its own stage. Reviewed by a human before use.*

*Developed by Matthias Weigelt with the help of Claude.*
