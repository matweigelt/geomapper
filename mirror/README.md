# geoMap v2 — Python mirror

Pre-validation instrument for the MATLAB toolbox. **Not** a port, and not a
fallback: it is where every number the MATLAB will assert gets measured
first, and it keeps that job under Tier A.

## One owner per kernel

- `kernels.py` — **sole owner** of the projection mathematics. Snyder
  spherical formulas, deliberately mirroring what the MATLAB computes, so a
  MATLAB disagreement localises a defect in the MATLAB.
- `oracle.py` — **oracle O4**, pyproj/PROJ. An *independent* implementation.
  Kept separate from `kernels.py` on purpose (finding PV-001): if the mirror
  were the oracle, agreement would be tautology and the round-trip suite
  would be checking PROJ against itself.
- `references.py` — measures every value the handover asserts, writes
  `out/reference_values.json`, and reports disagreements as findings.

Nothing else re-derives a formula. Import from `kernels`; do not copy.

Where MATLAB and the mirror disagree, **MATLAB is right by definition.**

## Run

    pip install pyproj numpy scipy
    python -m geomap_mirror.references

Exit prints the finding count. `out/reference_values.json` is consumed by
the MATLAB test suite via `GeoMapTestCase.loadMirrorReference`.

## Limits

See `LIMITS.md`. Read it before trusting a mirror number.
