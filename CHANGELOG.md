# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: semantic, with one project-specific rule — **the patch
component is the count of verified test points**, so it moves when the
evidence moves and a pure rename correctly bumps nothing.

## [Unreleased]

### Added — Stage 0, checkpoint 0.1 (mirror), 2026-08-13
- Python mirror (`mirror/geomap_mirror/`): all 16 map projections forward
  and inverse on a sphere, plus an independent PROJ oracle kept in a
  separate module so agreement between them is evidence rather than
  tautology.
- Frozen acceptance criteria (`mirror/acceptance.json`) and their checker,
  covering 55 numerical criteria including two pinned regressions for the
  predecessor's Robinson-wrap and Mercator-clamp defects.
- `mirror/LIMITS.md`, recording what the mirror cannot see.

### Added — Stage 0, checkpoint 0.2 (harness), 2026-08-13
- `tests/GeoMapTestCase.m` with the project's single timing instrument,
  `assertRatioBudget`: ratios rather than absolutes, both points timed
  inside one repeat, order rotated, median of per-repeat ratios reported
  with its band.
- `tests/rungeoMapTests.m`, the one runner, gating on manifest, load
  completeness, warning inventory, speed budgets and category coverage.
- Static structural checker and attribution sweep, each with a
  fault-injection self-test that must pass in the same invocation.
- CI workflow: static gates first, runtime second, twin triggers.

### Fixed — in the design, before implementation
Four numerical claims in the project's own design document were refuted by
the first mirror run and corrected. See `RECORDS.md` R-002.
- Polar stereographic ρ(70°) at SP=71: 0.6116372 → **0.3430474163**.
- LCC cone constant for parallels 33/45: the quoted 0.6304962 is the
  *ellipsoidal* value; the spherical value is **0.6304776973**.
- Robinson at lat 50: X **0.8679**, Y **0.6176** (the quoted figures were
  X-table entries from latitudes 35 and 85).
- Robinson round-trip tolerance: the 5e-4° exception was an artefact of
  the prescribed inversion method, not of the projection. Withdrawn;
  measured 1.4e-13° with root-finding on the forward interpolant.

### Added — Stage 0, checkpoint 0.3 (audit, oracles, v1 probes), 2026-08-15
- `tools/geoMapAudit.m`: twelve static checks over the tree, each shipping
  a fault-injection fixture in `tools/geoMapAuditFixtures.m` that plants
  its defect in the form the defect actually takes — plus a healthy
  control on which nothing may fire. The audit refuses to report a clean
  tree unless all thirteen fixtures pass in the same invocation, and it is
  now part of the green gate.
- `mirror/geomap_mirror/gdal_oracle.py`: **oracle rows O7 and O8 filled.**
  Reaches `GDALDEMProcessing` and `GDALWarp` through `osgeo`, the CLI, or
  the libgdal bundled in the `rasterio` wheel, and records which route ran
  with every measurement. Proved on an analytically known plane first.
- `mirror/geomap_mirror/regrid.py`: conservative area-weighted remap, and
  the measurement that **discharges debt V7** — the achievable
  double-precision mass-closure floor at 2161×4321 → 181×361 is
  **2.15e-14** over the worst of three summation orders, so `TolMass` is
  set to 1e-13, tighter than the guess it replaces.
- `mirror/geomap_mirror/hillshade.py`: Horn hillshade with the spherical
  `cos(lat)` metric. Reproduces `gdaldem hillshade`'s uint8 output
  **exactly** over 18 094 interior pixels; slope agrees to 4.2e-5°.
- `records/v1_defect_probes.m`: **discharges debt V4.** One probe per
  defect row, run against the installed predecessor — 17 reproduced,
  0 refuted, 1 blocked on a missing oracle.
- `records/v1_option_inventory.m`: **discharges debt V9.** 177 options
  across five front functions; 159 carried, 15 renamed, 3 dropped,
  **0 unmapped**.
- `Contents.m`, now the single version authority.
- `.gitattributes`, after `tools/gates.sh` was found to be unrunnable from
  a Windows working copy — the local gate had never once run locally.

### Fixed — Stage 0.3
- Every `PROVISIONAL` stamp removed: eleven files, false since the first
  green run on 15-Aug-2026.
- `oracle O7` demoted from authority to corroboration.
  `gdalwarp -r average` is an unweighted pixel-centre mean, not a
  conservative remap, and differs from one by 21% of signal RMS globally.
  The weights are certified against an analytic oracle instead.

### Known debt
- No coastline, grid or projection code exists yet.
- Two oracle rows remain unfilled: a real Natural Earth shapefile (O5) and
  a real GSHHG binary (O6); a GRACE mascon release (O11) is still to be
  named. Defect probe F17 is blocked on O6.
- Every speed budget in the design is still a *prediction*; only the three
  harness self-test ratios are measured.

[Unreleased]: https://github.com/matweigelt/GeoMapper/commits/main
