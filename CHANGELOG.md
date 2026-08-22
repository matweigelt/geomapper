# Changelog

All notable changes to geoMap. The version authority is
[`Contents.m`](Contents.m); this file is checked against it and never
maintained beside it.

The patch component of the version **is the verified test-point count**.
It moves when the evidence moves.

---

## 2.0.518 — 2026-08-22

**PV-149 — a green run left four figures open, and nothing could see them.**
`geo.basemap` creates the figure; `geo.map` then climbs a fourteen-rung
ladder into it. Any rung may raise, and until now nothing owned the
figure while it was climbed: a front that failed left a visible,
half-drawn map on screen. Four survived every 516-point green run. Two
of them showed only the basemap surface, because `Polygons` and
`Stipple` sit below `Graticule` on the ladder — the "unfinished plot" a
reader sees is not unfinished, it is abandoned.

- `geo.internal.discardOnFailure` is the one authority for the rule:
  delete a figure this toolbox created and did not finish, never one the
  caller supplied.
- `geo.basemap` returns `H.CreatedFigure`; `geo.map` reads it rather than
  testing `Parent` a second time.
- The basemap body, the draw ladder and the export step are each inside
  the guard.
- `FigureCensusPlugin` counts figures around every test method, and the
  green gate now includes it. It reports and never closes: cleaning up
  here would make the gate green by destroying its own evidence.
- Two `robustness` points in `TestE1_map` assert both halves of the
  rule — a failing front leaves no figure, and never deletes the
  caller's.

**Why no instrument caught it.** Every gate the runner applies reads
results, warning identifiers, filter reasons, speed records, category
coverage or source files. Not one read the graphics root. The leak was
found by a human noticing windows on a desktop, which is not an
instrument.

**CI no longer runs everything twice.** `on: push` was unrestricted and
paired with `on: pull_request`, so every push to a branch with an open
PR bought two identical runs. The duplicate was defended in a comment as
a hang-diagnosis instrument; the step-level timeout on the MATLAB setup
step already does that job for eight minutes instead of for a permanent
doubling of every job. Now `push` on `main` only, plus `pull_request` —
which still fires on every push to an open PR.

**Stale prose behind a correct stamp.** `Contents.m` and `README.md` both
said "491 test points" while the version had moved to 516. The
`versionAgreement` check compares version *declarations*; a count written
into prose is not one.

## 2.0.516 — 2026-08-22

**First release.** 516 test points, reconciled three ways, green on both
hosts. The patch component is the verified test-point count; it moves
when the evidence moves.

### Verified for this release

- `rungeoMapTests("all")` on the target machine: **516 passed, 0 failed,
  0 filtered**, green gate on all six conditions.
- The same commit on CI: 500 passed, 16 filtered, every filter carrying a
  registered reason. Neither host runs the whole suite alone; the union
  does.
- A **fresh clone with only the repository root on the path**: `geo.map`
  resolves, `tools/` does not, `GettingStarted` runs end to end, and
  `info.xml` points `doc geoMap` at a `docs/html` that is there.
- The rendered manual rasterised and read by a human. There is no
  automated oracle for "the figure is right".

### Fixed since the last entry

- **The frame is drawn all the way round.** On mollweide, hammer,
  robinson, sinusoidal, equirectangular and winkeltripel a global map's
  frame was drawn on the western half only: a boundary ring is a map
  edge, and it was being projected in the window meant for data, so its
  eastern meridian folded onto its western one (PV-145).
- **A frame band no longer collapses at a point pole.** mollweide, hammer
  and sinusoidal map the pole to a single point, and the band tapered to
  nothing there — the frame read as a triangle (PV-135).
- **Overlays are cut at the frame.** The coastline, contours, polygons,
  points, stipple and tracks were clipped to the projection's domain and
  never to the map's extent: on a regional map, 92% of the coastline
  drawn lay outside the frame (PV-136, PV-142, PV-144).
- **A grid says whether its values sit at points or over areas.**
  Registration — gridline versus pixel, in GMT's terms — is inferred from
  the axes and decides the region a map covers. Without it a global grid
  was one cell short of the world and every cell sat half a step from
  where its value belonged (PV-140).
- **Lambert azimuthal clips short of its antipode**, where a meridian
  crossing the singularity jumped the full diameter of the disc (PV-141).
- **A coordinate axis is checked for being angular.** A NetCDF on a
  projected grid was read straight through and produced a blank figure
  with no cause attached (A-3).
- **`geo.readGrid` distinguishes an absent file from an unreadable one**,
  and attaches the underlying error as a cause (A-4).
- **The manual ships with the toolbox.** Distribution is git, so an
  ignored `docs/html` was an undelivered manual (PV-146, D-020).

### Instruments added

- **A filter register.** Every point that does not run names a registered
  reason, and an unregistered one fails the gate. Before this, 42 of 491
  points could vanish and the gate still printed PASS (A-1).
- **A reference-sync gate.** The committed mirror reference is checked
  against what the mirror computes, with a register naming which values
  may move between environments and by how much (A-2).
- **A ledger gate.** The handover's status and the records' evidence are
  checked against each other (PV-130).
- **A GSHHG oracle subset ships with the tests**, so the real-data reader
  tier runs on CI and not only on one machine (A-6).

---

---

## Superseded — 2.0.491-alpha.1

### Fixed
- **The toolbox now runs when installed.** `geo.cache` called `sha256OfText`
  from `tools/`, which the `.mltbx` does not ship, so drawing a coastline
  raised `Undefined function 'sha256OfText'` on every installed copy while
  passing every test in the repository (PV-127). The function now lives in
  `+geo/+internal/`, and the harness calls the package's copy rather than the
  reverse.

### Added
- Audit check `packageClosure`: nothing in `+geo` may reference a file the
  toolbox does not ship. It states the rule rather than listing names, which
  is what let the same defect recur after PV-115 (PV-128).
- Two integration tests reading the same closure through MATLAB's dependency
  analyser, and asserting that drawing needs base MATLAB plus at most the
  optional Parallel Computing Toolbox.

## 2.0.0 — unreleased (Stage F in progress)

A complete rewrite. v1 (`geoImagescToolbox`) is replaced, not extended.

### Every claimed defect was measured before it was designed against

Part 5 of the handover listed eighteen defects derived by **reading** v1.
Before any of them was used to justify a design, each was **probed against
the installed v1** — because a design justified by a defect that does not
exist is a design without a reason. Result: **17 reproduced, 0 refuted,
1 blocked**. `blocked` is never reported as a pass.

| # | Defect | Probe | What was measured | Fixed by |
|---|---|---|---|---|
| F1 | Statistics Toolbox called while claiming none | counted | **32** call sites of `range()` across 5 files — the handover said ~15 | `geo.quantile`, base MATLAB only, enforced by the audit's banned list |
| F2 | Robinson used unwrapped longitude | executed | `geoProject(359, 10, "robinson")` returned x = **5.293**; correct is ≈ −0.0148. Wrong by about 200 map widths | `geo.wrapLongitude`, asserted exactly |
| F3 | Mercator clamped where others return NaN | executed | y(87°) − y(85°) = **0.000e+00** — data at 87° drawn on the parallel of 85°, 222 km out of place, silently | domain table returns NaN outside; clip is declared and queryable |
| F4 | `regrid` not longitude-periodic | executed | at lon 179.5 returned the **hull-edge value to 0.0e+00** — extrapolation, not interpolation. Control at lon −0.5 exact, so the probe measures the seam | periodic wrap, mass closure asserted at 2.6e-14 |
| F5 | No inverse projection anywhere | counted | 36 files, **none** named for an inverse | `geo.unproject` for all sixteen |
| F6 | Local functions duplicated across plotters | counted | **3 bodies** in more than one file | duplicate-local check — has now rejected **seven** copies, every one inside the round that wrote it |
| F7 | 15 positional arguments | counted | `geoNorthArrow`, **15** | D-003: three, enforced |
| F8 | One 3413-line function, two near-clones | counted | `geoImagesc` **3414**, Track 1159, Points 1320 | `geo.map` **128** executable lines; `trackmap`/`pointmap` **17** each |
| F9 | Renderer-dependent OpenGL hillshading | counted | `light` + `shading interp` + `FaceAlpha` co-occur in **3 files**. *The co-occurrence is measured; the renderer dependence it implies is inferred, and Stage B settles it against oracle O8* | `geo.hillshade`, analytic, no lights anywhere in `+geo` |
| F10 | Percentile by index rounding | executed | `geoPercentileRange([1 2], 50)` → **1.0**; the type-7 quantile is **1.5**. An index rule cannot return a value between two samples | `geo.quantile`, type 7 |
| F11 | Variable `clim` shadowed `clim()` | counted | **7** assignments across 2 files, forcing deprecated `caxis` | banned; `clim` and four block keywords watched |
| F12 | Domain clipping by magic literals | counted | **7** bare `cosc` thresholds in one file, each both a guard and a cosmetic clip with nothing saying which | one domain table, three arguments, queryable |
| F13 | Array growth in the record loop | counted | **5** growth pragmas across three readers; full GSHHG is ~180 MB | banned in `+geo`; accumulate and join once |
| F14 | No caching | counted | `persistent` appears **0** times in 36 files | `geo.cache`; cold/warm ratio measured at **629×** |
| F15 | appdata and manual callback chaining | counted | **3** appdata calls; any other toolbox setting the same property breaks the chain | one listener per figure, `geo.internal.layout` |
| F16 | Graticule step snapped to nearest | executed | over 13 spans it differs at 4; worst **10 lines against a target of 6**. *The handover illustrated this as "3 or 11"; the measured worst is 10, so the defect reproduces and the illustration does not* | ceiling policy, never overshoots |
| F17 | GSHHG pole closure unhandled | **blocked** | needs oracle O6, a real GSHHG `.b` file, still unfilled. **Reported as blocked, never as passed**; the reader ships with provenance `unverified` | debt V3 stays open |
| F18 | Tests were smoke tests | counted | `test_geoImagesc.m`: **0** assert/verify calls, **0** round-trip mentions | 487 points, seven categories, reconciled three ways |

### Added

- Sixteen projections **forward and inverse**, with a queryable domain per
  projection: singularities, clip limits, and whether the clip is
  cosmetic or mathematical.
- Value structs validated once — `geo.crs`, `geo.grid`, `geo.track`,
  `geo.points`, `geo.region` — so nothing downstream re-checks them.
- Fifteen composable elements, each drawing one thing into an axes on a
  documented z-ladder.
- Six one-call fronts: `map`, `trackmap`, `pointmap`, `timeseries`,
  `panel`, `export`.
- `geo.export`, which delivers a page in **centimetres**. `exportgraphics`
  ignores `PaperPosition` and crops to content: a 17.0 cm request measured
  **12.58 cm** in one configuration and **27.7 cm** in another. `print`
  with an explicit page gives **17.004 cm**.
- CVD-safe colormaps with provenance, and truecolor mapping in one place.
- A documentation build that counts completeness **in the written HTML**:
  43 functions, **398 of 398** arguments rendered, 0 broken links.
- `geo.v1.imagesc`, so a v1 script runs with one edit.

### Changed

- The six loose projection options become one `geo.crs`. Passing
  `Projection` raises `geo:map:ProjectionOption`, naming the replacement.
- Topography reading leaves the plotter's locals and becomes
  `geo.readGrid`.
- Colour limits, gap detection and the plotted-box computation each have
  **one** owner instead of five.

### Removed

- `Material` and `SpecularStrength` — renderer-dependent (D-009).
- v1's `Style` preset bundle: three options are set as three options,
  because a preset that silently moved settings a caller had not named
  was worth losing.

### Known gaps, carried openly

- **O11 unfilled.** No published GRACE mascon product is checked against.
  The integration scenario uses a field labelled *synthetic in the code*.
  An invented number here would be indistinguishable from a real one.
- **O6 unfilled**, so F17 stays blocked and the GSHHG reader ships
  `unverified`.
- **No panel labels** — (a), (b), (c). A corner annotation is not a title
  and no element draws one; flagged rather than improvised.
- **Export pixel content is not reproducible on software OpenGL.** Four
  renders came back A, A, B, B, differing by exactly 42 176 pixels every
  time. Page size, route and dimensions are asserted exactly; the pixel
  content is the rasteriser's and has been measured not to be stable.

---

## 1.x

See the v1 repository. Not maintained.
