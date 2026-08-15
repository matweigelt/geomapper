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

### Known debt
- The entire MATLAB harness is **written and never executed**. Every
  MATLAB file carries a `PROVISIONAL` stamp until its first green run.
- No coastline, grid or projection code exists yet.
- Three oracle rows are unfilled: a real Natural Earth shapefile, a real
  GSHHG binary, and a named GRACE mascon release.

[Unreleased]: https://github.com/matweigelt/GeoMapper/commits/main
