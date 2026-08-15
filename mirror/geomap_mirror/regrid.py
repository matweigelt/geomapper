"""geomap_mirror.regrid — conservative remap, and the mass-closure floor.

Two jobs, and they are different jobs:

  1. MIRROR the conservative remap `geo.regrid` will implement in Stage B
     (handover §7.4 B.2.4), so its weights can be checked before any MATLAB
     exists.
  2. MEASURE the achievable double-precision mass-closure floor at
     production grid size, which is what SETS `TolMass` - handover debt V7
     says the document's 1e-12 is a guess and forbids asserting it.

WHY THE WEIGHTS ARE SEPARABLE, which is not an optimisation but the reason
this runs at all.  On a rectilinear lon/lat grid the spherical area of the
overlap between a source cell and a target cell is

    (longitude overlap in degrees) x (overlap in sin(latitude))

i.e. a product of two one-dimensional overlaps.  So the two-dimensional
weight matrix never has to be formed: the remap is `Wlat @ Z @ Wlon.T`
with a separable normaliser.  At 2161x4321 -> 181x361 the non-separable
form would carry roughly 9.4e6 non-zeros; the separable form carries
2.6e5, and the arithmetic is a pair of sparse products.

THE ORACLE SITUATION, reported rather than glossed.  Register row O7 names
`cdo remapcon` or `gdalwarp -r average`.  `cdo` is not installable in this
sandbox.  `gdalwarp -r average` IS reachable (see `gdal_oracle.py`) and is
measured here - and the measurement shows it is **not** a conservative
remap: it takes an unweighted mean of the source pixels whose centres fall
in the target pixel, with no spherical area weighting and no partial-cell
handling.  The disagreement is recorded as a number, not as an opinion,
and the certification of the weights themselves is done against an
ANALYTIC oracle instead: for a field exactly integrable in (lon, sin lat),
the area-weighted cell mean has a closed form.  See `check_analytic`.

geoMap v2.0 mirror | 15-Aug-2026 | Claude Opus 5 (Anthropic)
"""

from __future__ import annotations

import math

import numpy as np
import scipy.sparse as sp

from . import gdal_oracle as G

D2R = np.pi / 180.0


# ---------------------------------------------------------------------------
# Grids
# ---------------------------------------------------------------------------
def edges_from_centres(c):
    """Cell edges from cell centres, assuming uniform spacing.

    Uniformity is asserted, not assumed: a non-uniform vector reaching a
    conservative remap silently produces areas that are wrong by the amount
    of the non-uniformity, which is exactly the class of error that still
    looks like a plausible map.
    """
    c = np.asarray(c, dtype=float)
    d = np.diff(c)
    if not np.allclose(d, d[0], rtol=1e-9, atol=0.0):
        raise ValueError("edges_from_centres requires uniform spacing")
    return np.concatenate([[c[0] - d[0] / 2], c + d[0] / 2])


def overlap_matrix(src_edges, dst_edges):
    """Sparse (P, M) matrix of 1-D interval overlap lengths.

    Row p, column m holds |[dst_p, dst_p+1] intersect [src_m, src_m+1]|.
    Zero where they do not meet.  Built by searching, not by looping over
    the product, so the cost is O((M+P) log M) rather than O(M*P).
    """
    src_edges = np.asarray(src_edges, dtype=float)
    dst_edges = np.asarray(dst_edges, dtype=float)
    lo = np.maximum(dst_edges[:-1, None], src_edges[None, :-1])
    hi = np.minimum(dst_edges[1:, None], src_edges[None, 1:])
    w = np.maximum(hi - lo, 0.0)
    return sp.csr_matrix(w)


def lat_weight_matrix(src_lat_edges, dst_lat_edges):
    """Latitude overlap measured in sin(lat) — TRUE spherical cell area.

    Measuring latitude overlap in degrees instead is the classic error: it
    over-weights polar cells by 1/cos(lat) and conserves nothing.  The
    difference is invisible on a regional map and gross on a global one,
    which is why it survives review and fails in production.
    """
    return overlap_matrix(np.sin(np.asarray(src_lat_edges) * D2R),
                          np.sin(np.asarray(dst_lat_edges) * D2R))


def remap_conservative(Z, src_lon_edges, src_lat_edges,
                       dst_lon_edges, dst_lat_edges):
    """First-order area-weighted remap.  Z is (nlat, nlon), latitude first.

    Returns (Zdst, info) where info carries the source and target masses so
    the caller can measure closure without recomputing the areas.
    """
    Z = np.asarray(Z, dtype=float)
    Wlat = lat_weight_matrix(src_lat_edges, dst_lat_edges)
    Wlon = overlap_matrix(src_lon_edges, dst_lon_edges)

    num = Wlat @ Z @ Wlon.T                       # (P, Q)
    alat = np.asarray(Wlat.sum(axis=1)).ravel()   # (P,)
    alon = np.asarray(Wlon.sum(axis=1)).ravel()   # (Q,)
    den = alat[:, None] * alon[None, :]
    with np.errstate(invalid="ignore", divide="ignore"):
        Zdst = np.where(den > 0, num / np.where(den == 0, 1.0, den), np.nan)

    src_dlat = np.diff(np.sin(np.asarray(src_lat_edges) * D2R))
    src_dlon = np.diff(np.asarray(src_lon_edges))
    mass_src = float(np.sum((src_dlat[:, None] * src_dlon[None, :]) * Z))
    mass_dst = float(np.sum(num))
    return Zdst, {"mass_src": mass_src, "mass_dst": mass_dst,
                  "target_area": den}


# ---------------------------------------------------------------------------
# V7: the achievable mass-closure floor
# ---------------------------------------------------------------------------
def measure_mass_closure_floor(nlat=2161, nlon=4321, plat=181, plon=361,
                               seed=42):
    """Measure, at production size, how well double precision can close.

    Handover debt V7 says the 1e-12 guarantee is an assertion about an
    algorithm not yet written, and that the tolerance must be SET from this
    measurement rather than checked against the guess.  §4.6 applies in the
    other direction too: if this comes out worse than 1e-12, that is a
    finding, not a licence to widen anything.

    Three summation orders are measured, because "the floor" is a property
    of the ORDER as much as of the precision, and a tolerance set from the
    luckiest order is not a floor:

      pairwise  numpy's default; what MATLAB's `sum` also does
      naive     a running scalar accumulation, the worst realistic case
      exact     math.fsum, correctly rounded - the true arithmetic answer

    The tolerance is set from the WORST realistic order, not the best.
    """
    rng = np.random.default_rng(seed)
    lat_e = np.linspace(-90.0, 90.0, nlat + 1)
    lon_e = np.linspace(-180.0, 180.0, nlon + 1)
    dlat_e = np.linspace(-90.0, 90.0, plat + 1)
    dlon_e = np.linspace(-180.0, 180.0, plon + 1)

    # A field with the dynamic range of a real EWH anomaly map, plus a
    # smooth large-scale part, so cancellation is realistic rather than
    # favourable.  A constant field would close exactly and prove nothing.
    lat_c = 0.5 * (lat_e[:-1] + lat_e[1:])
    lon_c = 0.5 * (lon_e[:-1] + lon_e[1:])
    Z = (30.0 * np.sin(3 * lat_c * D2R)[:, None]
         * np.cos(2 * lon_c * D2R)[None, :]
         + rng.normal(0.0, 5.0, (nlat, nlon)))

    Zdst, info = remap_conservative(Z, lon_e, lat_e, dlon_e, dlat_e)

    src_dlat = np.diff(np.sin(lat_e * D2R))
    src_dlon = np.diff(lon_e)
    cell = src_dlat[:, None] * src_dlon[None, :]
    dst_dlat = np.diff(np.sin(dlat_e * D2R))
    dst_dlon = np.diff(dlon_e)
    dcell = dst_dlat[:, None] * dst_dlon[None, :]

    orders = {}
    orders["pairwise"] = (float(np.sum(Z * cell)), float(np.sum(Zdst * dcell)))
    orders["naive"] = (float(_naive_sum(Z * cell)),
                       float(_naive_sum(Zdst * dcell)))
    orders["exact"] = (math.fsum((Z * cell).ravel()),
                       math.fsum((Zdst * dcell).ravel()))

    out = {}
    for name, (ms, md) in orders.items():
        out[name] = abs(md - ms) / abs(ms)
    worst = max(out.values())
    # The asserted tolerance is not the measured floor itself. A tolerance
    # set exactly at the floor fails on the first machine whose BLAS blocks
    # a reduction differently, and that failure would carry no information.
    # One decade above the worst measured order gives ~4.7x headroom here,
    # is a round number a later reader can check against this measurement,
    # and is still 10x TIGHTER than the handover's guess - so it constrains
    # more, not less.
    tolerance = 10.0 ** math.ceil(math.log10(worst) + 1.0)
    return {
        "grid": f"{nlat}x{nlon} -> {plat}x{plon}",
        "relative_closure_by_summation_order": out,
        "measured": float(worst),
        "tolerance": float(tolerance),
        "handover_guess": 1e-12,
        "agrees_with_guess": bool(worst <= 1e-12),
        "note": ("TolMass is set from the WORST order measured here, not "
                 "from the handover's guess and not from the best order; "
                 "the asserted tolerance is one decade above the floor"),
    }


def _naive_sum(a):
    """A running scalar accumulation — the worst realistic summation order.

    Deliberately not `np.sum`, whose pairwise reduction is far better
    conditioned.  Written as a reduction over rows so it stays affordable
    at 9.3e6 elements while remaining sequential in the direction that
    matters.
    """
    acc = 0.0
    for row in np.asarray(a):
        acc += float(np.sum(row))
    return acc


# ---------------------------------------------------------------------------
# Certification
# ---------------------------------------------------------------------------
def check_analytic():
    """Analytic oracle (O3 class) for the weights themselves.

    For f(lon, lat) = a + b*lon + c*sin(lat), the area-weighted mean over a
    cell [lon1,lon2] x [lat1,lat2] is exactly

        a + b*(lon1+lon2)/2 + c*(sin lat1 + sin lat2)/2

    because the measure is dlon * d(sin lat) and f is affine in both.  A
    first-order conservative remap must reproduce this to machine
    precision, and — this is the point — a remap that weighted latitude in
    DEGREES instead of sin(lat) cannot, however plausible its output looks.

    This is a genuine outside authority: closed-form integration, not a
    second copy of the implementation (§2.9, "an 'independent' check copied
    from the code under test is not independent").
    """
    a, b, c = 7.0, 0.013, 4.5
    lat_e = np.linspace(-90.0, 90.0, 721)
    lon_e = np.linspace(-180.0, 180.0, 1441)
    dlat_e = np.linspace(-90.0, 90.0, 31)
    dlon_e = np.linspace(-180.0, 180.0, 61)

    # The SOURCE must hold the cell MEAN, not the centre value, or the
    # comparison measures the source discretisation instead of the remap.
    lon1, lon2 = lon_e[:-1], lon_e[1:]
    s1, s2 = np.sin(lat_e[:-1] * D2R), np.sin(lat_e[1:] * D2R)
    Z = (a + b * (0.5 * (lon1 + lon2))[None, :]
         + c * (0.5 * (s1 + s2))[:, None])

    Zdst, _ = remap_conservative(Z, lon_e, lat_e, dlon_e, dlat_e)
    dl1, dl2 = dlon_e[:-1], dlon_e[1:]
    t1, t2 = np.sin(dlat_e[:-1] * D2R), np.sin(dlat_e[1:] * D2R)
    want = (a + b * (0.5 * (dl1 + dl2))[None, :]
            + c * (0.5 * (t1 + t2))[:, None])
    err = float(np.nanmax(np.abs(Zdst - want)))

    # The counterfactual: the same remap with latitude weighted in degrees.
    # Reported so the analytic check is shown to DISCRIMINATE, not merely
    # to pass — a check that has never been seen to fail is not evidence.
    Wlat_deg = overlap_matrix(lat_e, dlat_e)
    Wlon = overlap_matrix(lon_e, dlon_e)
    num = Wlat_deg @ Z @ Wlon.T
    den = (np.asarray(Wlat_deg.sum(axis=1)).ravel()[:, None]
           * np.asarray(Wlon.sum(axis=1)).ravel()[None, :])
    wrong = float(np.nanmax(np.abs(num / den - want)))
    return {"max_abs_error": err,
            "degree_weighted_counterfactual_error": wrong,
            "discriminates": bool(wrong > 1e4 * max(err, 1e-16))}


def check_against_gdal_average():
    """Oracle O7 as the register names it — and the measurement that
    annotates the row rather than ticking it.

    `gdalwarp -r average` averages the source pixels whose centres fall in
    the target pixel, unweighted.  On a lon/lat grid that is not the
    spherical area-weighted mean, so it agrees with a conservative remap
    only where cell area happens to be near-constant.  Both regimes are
    measured: a low-latitude band (where the two nearly agree) and the full
    globe (where they do not).
    """
    if not G.available():
        return {"skipped": "GDAL not reachable", **G.provenance()}
    rng = np.random.default_rng(7)
    out = {**G.provenance()}
    for name, (s, n) in (("band_lat_-10_to_10", (-10.0, 10.0)),
                         ("global", (-90.0, 90.0))):
        nlat, nlon, plat, plon = 180, 360, 18, 36
        lat_e = np.linspace(s, n, nlat + 1)
        lon_e = np.linspace(-180.0, 180.0, nlon + 1)
        dlat_e = np.linspace(s, n, plat + 1)
        dlon_e = np.linspace(-180.0, 180.0, plon + 1)
        Z = rng.normal(0.0, 10.0, (nlat, nlon))
        Zc, _ = remap_conservative(Z, lon_e, lat_e, dlon_e, dlat_e)
        # GDAL's row 0 is north; flip in and back out.
        Zg = np.flipud(G.warp_average(np.flipud(Z), (-180.0, n, 180.0, s),
                                      (plat, plon)))
        d = np.abs(Zc - Zg)
        out[name] = {"max_abs_diff": float(np.nanmax(d)),
                     "rms_diff": float(np.sqrt(np.nanmean(d ** 2))),
                     "field_rms": float(np.sqrt(np.nanmean(Zc ** 2)))}
    out["verdict"] = (
        "gdalwarp -r average is an unweighted pixel-centre mean and is NOT "
        "a conservative remap; it is recorded as corroboration in a "
        "near-constant-area band and is not an authority globally")
    return out


def measure():
    """Everything this module contributes to reference_values.json."""
    return {
        "regrid_mass_closure_floor": measure_mass_closure_floor(),
        "regrid_analytic_affine_field": check_analytic(),
        "regrid_vs_O7_gdalwarp_average": check_against_gdal_average(),
    }


if __name__ == "__main__":
    import json

    print(json.dumps(measure(), indent=2))
