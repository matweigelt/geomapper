# GeoMapper — geoMap v2

Publication-quality cartographic visualisation for MATLAB, built for
GRACE-like satellite gravimetry: equivalent water height, mascon
solutions, trend maps, and the along-track and time-series products that
go beside them.

**Base MATLAB only.** No Mapping Toolbox, no Image Processing Toolbox, no
Statistics Toolbox. That is a hard architectural constraint, enforced by a
static gate rather than by good intentions — its predecessor shipped a
"no toolboxes required" claim while calling a Statistics Toolbox function
at fifteen sites.

---

## Status: Stage F. Every stage green; the release checklist is open.

| Stage | Contents | State |
|---|---|---|
| **0** | Test harness, Python mirror, static audit, runner | **green** |
| **A** | Data model, CRS, longitude topology | **green** |
| **B** | 16 projections forward and inverse, regrid, hillshade | **green** |
| **C** | Coastline and grid readers, caching | **green** |
| **D** | Basemap, graticule, frame, overlays | **green** |
| **E** | One-call fronts, export | **green** |
| F | Documentation, packaging, release, independent audit | **in progress** |

**532 test points**, reconciled three ways on every run, across seven
categories. Fourteen static checks, each proved against a planted defect
before it reports. The version's patch component IS the test-point count,
so the number above and the one in [`Contents.m`](Contents.m) cannot
drift apart.

The authoritative status lives in [`HANDOVER.md`](HANDOVER.md) Part 1 and
nowhere else. **This table is a courtesy and may lag.**

---

## Coming from v1

Every option name that survived kept its exact spelling, and the ones
that did not **raise with the replacement named** rather than being
silently ignored. All 120 of `geoImagesc`'s options are accounted for:
**92 translate, 28 raise**, none is dropped in silence. The mapping is
machine-checked against v1's own source, not against recollection.

| v1 | v2 |
|---|---|
| ``geoImagesc(lon, lat, Z, ...)`` | ``geo.map(geo.grid(lon, lat, Z), crs, ...)`` |
| ``geoImagescTrack(T, ...)`` | ``geo.trackmap(T, crs, ...)`` |
| ``geoImagescPoints(P, ...)`` | ``geo.pointmap(P, crs, ...)`` |
| ``geoImagescTimeSeries(T, ...)`` | ``geo.timeseries(T, ...)`` |
| ``geoImagescMulti(panels, ...)`` | ``geo.panel(spec, ...)`` |
| ``geoProject(lon, lat, name, lon0, lat0)`` | ``geo.project(lon, lat, geo.crs(name, CenterLongitude = lon0))`` |

**The one change that is not a rename.** v1 took `Projection`,
`CenterLongitude`, `CenterLatitude`, `Hemisphere`, `StandardParallel`
and `StandardParallel2` as six loose options that had to agree with each
other and were checked nowhere. v2 takes one `geo.crs`, which validates
them together and can be handed to every overlay so a track lands in the
same coordinate system as the map beneath it. Passing `Projection`
raises `geo:map:ProjectionOption`, which names the replacement.

To run a v1 script with one edit, change the function name:

```matlab
geo.v1.imagesc(lon, lat, Z, 'Projection', 'mollweide', ...  % v1 spelling
    'ShowColorbar', true, 'GraticuleStepLon', 60);
```

It is not called `geoImagesc` on purpose: v1 stays installed until this
release ships, and a file of that name would shadow it or be shadowed by
it depending on path order — which would make the toolbox that drew your
figure depend on something nobody set deliberately.

---

## Why this project keeps a verification-debt table

The predecessor toolbox passed its own test suite. Those tests asserted
that functions ran without erroring; none compared a projection against a
published value or an independent implementation. Sixteen projections
shipped for four years without once being checked against something not
built here.

So the first thing this repository built was not a map. It was the
instrument that measures whether the maps are right — and the first thing
that instrument did was refute four numbers in the project's own design
document:

| Claim in the design document | Measured | Cause |
|---|---|---|
| Polar stereographic ρ(70°), SP=71 = 0.6116372 | **0.3430474163** | Matched no evaluation of any formula in either model |
| LCC cone constant, parallels 33/45 = 0.6304962 | **0.6304776973** | The quoted figure is the *ellipsoidal* Clarke-1866 value, for a model this toolbox does not use |
| Robinson at lat 50: X 0.9427, Y 0.5722 | **X 0.8679, Y 0.6176** | Those are X-table entries, from latitudes 35 and 85 |
| Robinson round trip achievable to 5e-4° | **1.4e-13°** | The prescribed inversion method, not the projection, was the limit |

None was a typo. Each was smooth, plausible and wrong — which is the only
kind of error that survives a self-consistency check.

Every number this toolbox asserts is measured before it is asserted, and
the measurement is checked against something outside the project:
Snyder's published worked examples, PROJ, analytic invariants, and real
data files. See the oracle register in [`HANDOVER.md`](HANDOVER.md) Part 3.

---

## Repository layout

```
+geo/                 the toolbox (Stages A-E; not yet present)
tests/                matlab.unittest suites and the shared harness
tools/                static audit, manifest, local gate runner
mirror/               Python pre-validation instrument + frozen criteria
docs/                 the cross-project best-practice document
HANDOVER.md           rules, design, ledger. The single source of truth.
RECORDS.md            archived evidence. Read when you need it, not first.
```

### The mirror

`mirror/` is a Python package that computes every number the MATLAB will
assert, *before* the MATLAB is written. It is a shipped deliverable, not a
scratch pad, and it keeps its job when a live MATLAB is available.

Two modules, deliberately kept apart:

- `kernels.py` mirrors what the MATLAB computes (Snyder spherical
  formulas), so a MATLAB disagreement localises a defect in the MATLAB.
- `oracle.py` wraps PROJ, an *independent* implementation, so agreement is
  evidence rather than tautology.

Where MATLAB and the mirror disagree, **MATLAB is right by definition**.
The mirror's job is to find the disagreement, not to win it.

`mirror/LIMITS.md` records what the mirror cannot see. Read it before
trusting a mirror number.

---

## Running the gates

Every gate runs locally, byte-identical to CI. Run them to zero before
pushing; let CI confirm rather than discover.

```bash
python3 -m pip install -r mirror/requirements.txt
./tools/gates.sh
```

The MATLAB gate self-skips when no `matlab` is on the PATH **and says so
loudly**. A silently skipped gate looks exactly like a passing one.

In MATLAB:

```matlab
cd <repository root>
addpath(pwd, fullfile(pwd,'tests'), fullfile(pwd,'tools'))
makeManifest
ok = rungeoMapTests("all")
```

`rungeoMapTests` is **the** runner; its count is authoritative. Do not
call `runtests` directly — a runner that reports what it did is the
instrument, and the directory-discovery entry point reports only a count.

### What "green" means here

Zero failures **and** every suite loaded **and** no new warning identifier
**and** no speed budget exceeded **and** the manifest verified **and** the
category coverage clean. Not "the number went up".

Predict the test-point count before every run. A suite that silently fails
to load is indistinguishable from a green run by the pass count alone.

---

## Test categories

Seven, and each suite declares which it ships:

`contract` · `reference` · `precision` · `speed` · `robustness` ·
`vectorisation` · `metamorphic`

An exemption is a claim that a test is **impossible**, not that it is
inconvenient, and lives in [`tests/EXEMPTIONS.md`](tests/EXEMPTIONS.md)
with a reason. `contract` may never be exempted for a function that
validates its arguments.

### Speed budgets are ratios, never absolutes

Every speed assertion compares two operations doing the same work on the
same arrays, timed inside one repeat with the order rotated, reported as
the median of per-repeat ratios with the measured band. An absolute
figure with no baseline cannot detect the change it was written for.

There is exactly one timing helper in the project. Do not write a second.

---

## Design in one paragraph

A layered namespace package. `geo.crs` holds all projection state in one
validated struct; `geo.project` / `geo.unproject` / `geo.scaleFactors` are
pure array mathematics with no graphics; `geo.basemap` plus a dozen
composable elements each take `(ax, crs, ...)` and return handles; and the
one-call fronts (`geo.map`, `geo.trackmap`, `geo.panel`) are thin
orchestration over those elements — thin enough that a test greps them for
drawing primitives and fails if it finds any.

Out-of-domain points return `NaN`, always, on every projection. They are
never clamped, because a clamped point is drawn confidently in the wrong
place.

---

## Contributing

Route of a change: [`WORKFLOW.md`](WORKFLOW.md). Content of a change: [`CONTRIBUTING.md`](CONTRIBUTING.md). In short: the handover is the
single source of truth, gates run locally before they run in CI, and a
tolerance is never widened to make a test pass — that is a finding.

## Licence

MIT. See [`LICENSE`](LICENSE).

## Citation

See [`CITATION.cff`](CITATION.cff). Please cite the version you used; the
patch component tracks the evidence, not the prose.


