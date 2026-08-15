# Mirror limits — what this instrument cannot see

Maintained per stage. A mirror trusted beyond its range makes evidence
quietly wrong rather than merely absent, which is worse than no mirror,
because the numbers still look like measurements.

## Seeded at Stage 0

| # | Blind spot | Consequence | Mitigation |
|---|---|---|---|
| L1 | **Graphics are entirely invisible.** No figure, axes, renderer, export or layout behaviour can be reached from Python. | Stages D and E have no mirror at all. Their geometry is checked against Stage B's projected coordinates, which are themselves certified against O4 — an internal reference certified externally one layer down. | Stated at every Stage D/E assertion. Under Tier A these become live-run measurements. |
| L2 | **MATLAB drops trailing singleton dimensions; NumPy does not.** | A shape guard correct in the mirror can make a legitimate array inexpressible in MATLAB. | No mirror assertion about output *shape* is binding on MATLAB; shape is a `contract` test written on the MATLAB side. |
| L3 | **`griddedInterpolant` extrapolation semantics differ from `scipy`'s.** MATLAB's `'nearest'` extrapolation and SciPy's `fill_value` behave differently outside the hull. | The regrid seam test (F4) must be written against MATLAB's own behaviour, not the mirror's. | The mirror measures the *interpolated* value at the seam; the extrapolation contrast is a MATLAB-side test. |
| L4 | **Speed ratios transfer across languages only when both sides scale alike**, and the direction is not predictable. A multi-core dense operation may be ~16× faster in one language while an interpreted loop is only ~3× faster, so a ratio can *fall* by 5× crossing languages. | Every mirror-derived speed expectation is a prediction, never an authority. | Budgets set several times clear of the mirror figure, in the direction failure would hurt. Recorded per budget. |

## Added by pre-validation, 13-Aug-2026

| # | Blind spot | Detail |
|---|---|---|
| L5 | **PROJ is not an authority for Robinson beyond ~1e-3.** Mirror and PROJ agree to 8.9e-4 in projected units, not to machine precision, because PROJ uses its own interpolation of the Robinson table rather than PCHIP. | Robinson's `reference` test asserts against the **table nodes** (exact) and the round trip (1e-13), not against PROJ. The 8.9e-4 PROJ agreement is recorded as corroboration, not as a tolerance. |
| L6 | **PROJ's `+proj=wintri` defaults `+lat_1` to 0 when it is absent from the string**, which silently makes it a different projection. Discovered as a 0.18·λ discrepancy (PV-003). | `oracle.py` always writes `+lat_1` explicitly. Any future projection added to the oracle must have every parameter it consumes written out; a PROJ default is not a documented contract. |
| L7 | **`geo.scaleFactors` returns NaN when evaluated exactly on a domain boundary**, because the central difference steps outside. Seen at Mercator lat = ±85. | `geo.scalebar`'s validity gate must sample strictly inside the extent, and must tolerate NaN corners. This is a MATLAB-side design consequence discovered in the mirror. |
| L8 | **The global-extent scale-variation figures for `mercator` and `transversemercator` are artifacts of L7** (only the centre sample survived), and are excluded from the table used to set the D-006 threshold. | Regional rows are unaffected and are what the threshold is set from. |

## Added at Stage 0.3, 15-Aug-2026 — the GDAL oracles

| # | Blind spot | Detail |
|---|---|---|
| L9 | **`gdaldem hillshade` emits uint8, so O8 cannot certify a shade beyond 1 DN = 1/254 ≈ 3.9e-3.** | The mirror compares against `gdaldem slope` and `gdaldem aspect`, which emit Float32 and certify the Horn gradient itself to ~4e-5° and ~8e-4° respectively. Measured on the byte output the agreement is **exact (0 DN over 18 094 interior pixels)**, which is recorded as the stronger result it is — but the *instrument's* ceiling is still 1 DN, and a future disagreement below that ceiling would be invisible. |
| L10 | **GDAL has no per-row metric.** It is an oracle for the Horn kernel on a **constant-spacing tile only**, and says nothing about geoMap's spherical `R·cos(lat)·dlon` east–west spacing. | The metric is a separate claim with its own analytic check: the same east–west ramp measured at latitude 0 and 60 must differ by exactly `1/cos 60° = 2`. Measured 1.9999878 (6.1e-6 relative, the residual being the variation of `cos(lat)` across the sampling window). This is the test that catches a missing `cos(lat)`, and no oracle supplies it. |
| L11 | **`gdalwarp -r average` is NOT a conservative remap**, so oracle row O7 as the register names it is not an authority for spherical area weighting. It takes an unweighted mean of the source pixels whose centres fall in the target pixel. | Measured against the mirror's conservative remap on the same grids: in a ±10° band, RMS difference **5.5e-4** against a field RMS of 0.98 — corroboration. Globally, RMS difference **0.207** against a field RMS of 1.00, i.e. **21% of the signal**. `cdo remapcon`, the register's first-choice O7, is not installable in this sandbox. The weights are therefore certified against an **analytic** oracle instead: for a field affine in `(lon, sin lat)` the area-weighted cell mean has a closed form, reproduced to 7.1e-15. That check is shown to discriminate — the same remap with latitude weighted in *degrees* misses by 4.1e-3, twelve orders of magnitude worse. |
| L12 | **The GDAL route differs between the sandbox and CI**, and which one ran is recorded with every measurement rather than assumed equivalent. | The sandbox has no root, so it loads the libgdal bundled inside the `rasterio` wheel and calls `GDALDEMProcessing` and `GDALWarp` through `ctypes` — the same C entry points the CLI calls. CI has root and installs `gdal-bin`, so it takes the CLI route. Both are proved on an analytically known plane before anything cites them: slope and aspect of a constant-gradient surface, agreeing to ~6e-6°. |
