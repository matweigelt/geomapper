"""geomap_mirror.references — measure every number the handover asserts.

Handover rev 2.0, debt V1: every number in that document is model-derived
and unmeasured.  This module measures them and writes
out/reference_values.json, which the MATLAB tests then load.  A disagreement
with the handover's quoted value is a FINDING, reported before any MATLAB is
written — not a value to be quietly adopted.

Run:  python -m geomap_mirror.references

geoMap v2.0 mirror | 13-Aug-2026 | Claude Opus 5 (Anthropic)
"""

from __future__ import annotations

import json
import pathlib

import numpy as np

from . import gdal_oracle as GD
from . import hillshade as H
from . import kernels as K
from . import oracle as O
from . import regrid as RG
from . import stage_a as SA

OUT = pathlib.Path(__file__).parent / "out"
OUT.mkdir(exist_ok=True)

findings = []
values = {}


def claim(label, measured, quoted, tol, note=""):
    """Record a measured value against the handover's quoted claim."""
    ok = quoted is None or abs(measured - quoted) <= tol
    values[label] = {"measured": float(measured),
                     "handover_quoted": quoted,
                     "tolerance": tol,
                     "agrees": bool(ok),
                     "note": note}
    if quoted is not None and not ok:
        findings.append({
            "label": label,
            "quoted": quoted,
            "measured": float(measured),
            "abs_error": float(abs(measured - quoted)),
            "tolerance": tol,
            "note": note,
        })
    return ok


# ---------------------------------------------------------------------------
# 1. Cone constant, LCC standard parallels 33 / 45
# ---------------------------------------------------------------------------
def check_cone_constant():
    n = K.cone_constant("lambertconformal", 33.0, 45.0)
    # 0.6304962 is the handover's quoted value and is REFUTED: it is the
    # ellipsoidal Clarke-1866 constant, matching to 2.6e-7, for a model
    # geoMap does not use. The spherical value is 0.6304776973. It stays
    # here as the comparison target because this function's job is to
    # report the disagreement, not to adopt either side (finding PV-011).
    claim("lcc_33_45_cone_constant", n, 0.6304962, 1e-6,
          "Snyder 1987 p.296 example; handover Part 7.3 / accuracy table")
    n_alb = K.cone_constant("albers", 29.5, 45.5)
    claim("albers_29p5_45p5_cone_constant", n_alb, None, 0.0,
          "no handover claim; recorded for Stage B")
    return n


# ---------------------------------------------------------------------------
# 2. Mercator y at 35 degrees
# ---------------------------------------------------------------------------
def check_mercator():
    crs = K.Crs("mercator")
    _, y = K.project(0.0, 35.0, crs)
    claim("mercator_y_at_lat35", float(y), 0.6528366, 1e-6,
          "y = ln(tan(45 + 17.5 deg))")
    xo, yo = O.project(0.0, 35.0, crs)
    claim("mercator_y_at_lat35_PROJ", float(yo), float(y), 1e-12,
          "oracle O4 cross-check of the mirror kernel")
    # F3 regression: the domain limit must return NaN, not the value at 85.
    _, y87 = K.project(0.0, 87.0, crs)
    values["mercator_y_at_lat87_is_nan"] = {
        "measured": bool(np.isnan(y87)), "handover_quoted": True,
        "tolerance": 0, "agrees": bool(np.isnan(y87)),
        "note": "F3: v1 clamped to +/-85 and drew data at the wrong place"}
    return float(y)


# ---------------------------------------------------------------------------
# 3. Polar stereographic rho(70)/R with standard parallel 71
# ---------------------------------------------------------------------------
def check_polar_stereographic():
    crs = K.Crs("polarstereographic", lon0=0.0, hemisphere="north", sp1=71.0)
    x, y = K.project(0.0, 70.0, crs)
    rho = float(np.hypot(x, y))
    # 0.6116372 is the handover's quoted value and is REFUTED: it matches
    # no evaluation of any formula in either model. The measured value is
    # 0.3430474163, confirmed by PROJ to 1e-10 (finding PV-002).
    claim("polarstereo_rho_lat70_sp71", rho, 0.6116372, 2e-6,
          "Snyder 1987 eq. 21-8 spherical, k0 = (1 + sin 71)/2")
    xo, yo = O.project(0.0, 70.0, crs)
    rho_proj = float(np.hypot(xo, yo))
    claim("polarstereo_rho_lat70_sp71_PROJ", rho_proj, rho, 1e-9,
          "oracle O4 cross-check")
    # What the handover's number might have been: record candidates so the
    # finding is diagnosable rather than merely negative.
    cand = {
        "2*tan(45-phi/2), no k0": float(2 * np.tan(np.radians(45 - 35))),
        "(1+sin71)*tan(45-phi/2)": rho,
        "2*k0*tan(45-phi/2) at phi=55": float(
            (1 + np.sin(np.radians(71))) * np.tan(np.radians(45 - 27.5))),
        "rho at phi=-75 south, sp=-71": None,
    }
    crs_s = K.Crs("polarstereographic", hemisphere="south", sp1=-71.0)
    xs, ys = K.project(150.0, -75.0, crs_s)
    cand["rho at phi=-75 south, sp=-71"] = float(np.hypot(xs, ys))
    values["polarstereo_candidates"] = cand
    return rho


# ---------------------------------------------------------------------------
# 4. Lambert conformal conic, Snyder p.296 worked example
# ---------------------------------------------------------------------------
def check_lcc_point():
    crs = K.Crs("lambertconformal", lon0=-96.0, lat0=23.0, sp1=33.0, sp2=45.0)
    x, y = K.project(-75.0, 35.0, crs)
    claim("lcc_x_at_35N_75W", float(x), 0.2966785, 5e-6,
          "Snyder 1987 p.296 worked example, R = 1")
    claim("lcc_y_at_35N_75W", float(y), 0.2462112, 5e-6,
          "Snyder 1987 p.296 worked example, R = 1")
    xo, yo = O.project(-75.0, 35.0, crs)
    claim("lcc_x_at_35N_75W_PROJ", float(xo), float(x), 1e-9,
          "oracle O4 cross-check")
    claim("lcc_y_at_35N_75W_PROJ", float(yo), float(y), 1e-9,
          "oracle O4 cross-check")
    return float(x), float(y)


# ---------------------------------------------------------------------------
# 5. Robinson table nodes at latitude 50
# ---------------------------------------------------------------------------
def check_robinson():
    i50 = int(np.argmin(np.abs(K.ROBINSON_LAT - 50.0)))
    x_tab = float(K.ROBINSON_X[i50])
    y_tab = float(K.ROBINSON_Y[i50])
    claim("robinson_X_at_lat50", x_tab, 0.9427, 1e-12,
          "handover quotes 0.9427 as the X scale at lat 50")
    claim("robinson_Y_at_lat50", y_tab, 0.5722, 1e-12,
          "handover quotes 0.5722 as the Y value at lat 50")
    # Where do the handover's two numbers actually live in the table?
    where = {}
    for tgt, nm in ((0.9427, "0.9427"), (0.5722, "0.5722")):
        hits = []
        for tbl, tname in ((K.ROBINSON_X, "X"), (K.ROBINSON_Y, "Y")):
            j = np.where(np.abs(tbl - tgt) < 1e-9)[0]
            for jj in j:
                hits.append(f"{tname} table at lat {K.ROBINSON_LAT[jj]:.0f}")
        where[nm] = hits
    values["robinson_where_quoted_numbers_live"] = where
    # PCHIP must reproduce its own nodes exactly.
    crs = K.Crs("robinson")
    node_err = 0.0
    for lat in K.ROBINSON_LAT:
        xs = float(K._ROB_X(lat))
        ys = float(K._ROB_Y(lat))
        k = int(np.argmin(np.abs(K.ROBINSON_LAT - lat)))
        node_err = max(node_err, abs(xs - K.ROBINSON_X[k]),
                       abs(ys - K.ROBINSON_Y[k]))
    claim("robinson_pchip_node_reproduction", node_err, 0.0, 1e-12,
          "PCHIP must reproduce its own table nodes exactly")
    # y at lat 50 in Earth radii, as the MATLAB will compute it.
    _, y50 = K.project(0.0, 50.0, crs)
    values["robinson_y_earth_radii_at_lat50"] = {
        "measured": float(y50), "handover_quoted": None, "tolerance": 0,
        "agrees": True,
        "note": "= 1.3523 * Y(50); the correct form of the handover claim"}
    # F2 regression: wrapped longitude.
    x359, _ = K.project(359.0, 10.0, crs)
    values["robinson_x_at_lon359"] = {
        "measured": float(x359), "handover_quoted": None, "tolerance": 0,
        "agrees": bool(x359 < 0 and abs(x359) < 0.02),
        "note": "F2: must be negative and small; v1 returned about +3.0"}
    return x_tab, y_tab


# ---------------------------------------------------------------------------
# 6. Equal-area integral, and Hammer's limit
# ---------------------------------------------------------------------------
def check_equal_area(step=1.0):
    """Sum shoelace areas of projected 1-degree quads; expect 4*pi."""
    # The seam column must not be duplicated: wrap_longitude maps +180 to
    # -180, so a mesh with both edges makes the last quad span the whole map
    # and roughly doubles the total.  Finding PV-006 (fixture defect).
    lat_e = np.arange(-90.0, 90.0 + step, step)
    lon_e = np.linspace(-180.0 + 1e-9, 180.0 - 1e-9,
                        int(round(360.0 / step)) + 1)
    LON, LAT = np.meshgrid(lon_e, lat_e)
    out = {}
    # Only the pseudocylindricals admit a global quad integral: the
    # azimuthal rim and the conic apex are singular, so a 1-degree mesh
    # there measures the discretisation, not the projection.  Finding
    # PV-007: the handover's global-integral row overreaches for lambert
    # and albers; AreaScale (measured at ~1e-8) is the right instrument.
    for name in ("mollweide", "hammer", "sinusoidal"):
        if name == "lambert":
            crs = K.Crs("lambert", lat0=0.0)
        elif name == "albers":
            crs = K.Crs("albers", lat0=40.0, sp1=20.0, sp2=60.0)
        else:
            crs = K.Crs(name)
        X, Y = K.project(LON, LAT, crs)
        x1, x2 = X[:-1, :-1], X[:-1, 1:]
        x3, x4 = X[1:, 1:], X[1:, :-1]
        y1, y2 = Y[:-1, :-1], Y[:-1, 1:]
        y3, y4 = Y[1:, 1:], Y[1:, :-1]
        a = 0.5 * np.abs((x1 * y2 - x2 * y1) + (x2 * y3 - x3 * y2)
                         + (x3 * y4 - x4 * y3) + (x4 * y1 - x1 * y4))
        total = float(np.nansum(a))
        rel = abs(total - 4 * np.pi) / (4 * np.pi)
        out[name] = {"total": total, "rel_error_vs_4pi": rel}
    values["equal_area_integral"] = out
    worst = max(v["rel_error_vs_4pi"] for v in out.values())
    claim("equal_area_worst_relative_error", worst, None, 0.0,
          "handover asserts 1e-3; this measures what is achievable at "
          f"{step} deg quad discretisation")
    # Hammer's equatorial limit.
    xh, _ = K.project(179.999, 0.0, K.Crs("hammer"))
    claim("hammer_x_limit_at_equator", float(xh), 2 * np.sqrt(2), 1e-4,
          "x -> 2*sqrt(2) as lon -> 180 at the equator")
    return out


# ---------------------------------------------------------------------------
# 7. Round trips, all 16, mirror-internal and against PROJ
# ---------------------------------------------------------------------------
def check_round_trips(n=10000, seed=42):
    rng = np.random.default_rng(seed)
    res = {}
    cfg = {
        "equirectangular": dict(), "mercator": dict(),
        "transversemercator": dict(lat0=0.0), "robinson": dict(),
        "mollweide": dict(), "hammer": dict(), "winkeltripel": dict(),
        "sinusoidal": dict(), "lambert": dict(lat0=40.0),
        "stereographic": dict(lat0=40.0), "orthographic": dict(lat0=40.0),
        "azimuthalequidistant": dict(lat0=40.0), "gnomonic": dict(lat0=40.0),
        "polarstereographic": dict(sp1=71.0),
        "lambertconformal": dict(lon0=-96.0, lat0=23.0, sp1=33.0, sp2=45.0),
        "albers": dict(lon0=-96.0, lat0=23.0, sp1=29.5, sp2=45.5),
    }
    for name, kw in cfg.items():
        crs = K.Crs(name, **kw)
        lon = rng.uniform(-179.0, 179.0, n)
        lat = rng.uniform(-89.0, 89.0, n)
        if name == "mercator":
            lat = rng.uniform(-84.0, 84.0, n)
        if name == "polarstereographic":
            lat = rng.uniform(10.0, 89.0, n)
        x, y = K.project(lon, lat, crs)
        lon2, lat2 = K.unproject(x, y, crs)
        ok = np.isfinite(x) & np.isfinite(y) & np.isfinite(lon2)
        dlon = np.abs(K.wrap_longitude(lon2 - lon, 0.0))
        dlat = np.abs(lat2 - lat)
        err = float(np.nanmax(np.maximum(dlon[ok], dlat[ok]))) if ok.any() \
            else float("nan")
        entry = {"n_in_domain": int(ok.sum()), "max_deg_error": err}
        # Independent oracle comparison, forward.
        if O.available(crs):
            try:
                xo, yo = O.project(lon, lat, crs)
                m = np.isfinite(x) & np.isfinite(xo)
                if m.any():
                    entry["proj_max_abs_diff"] = float(np.nanmax(
                        np.maximum(np.abs(x[m] - xo[m]),
                                   np.abs(y[m] - yo[m]))))
                    entry["proj_n_compared"] = int(m.sum())
            except Exception as exc:                      # noqa: BLE001
                entry["proj_error"] = str(exc)
        else:
            entry["proj_error"] = "no PROJ oracle"
        res[name] = entry
    values["round_trips"] = res
    return res


# ---------------------------------------------------------------------------
# 8. Great-circle reference, Paris to New York
# ---------------------------------------------------------------------------
def check_great_circle():
    lon1, lat1 = 2.3522, 48.8566
    lon2, lat2 = -74.0060, 40.7128
    sph = O.spherical_distance_km(lon1, lat1, lon2, lat2,
                                  K.AUTHALIC_RADIUS_KM)
    geo = O.geodesic_distance_km(lon1, lat1, lon2, lat2)
    claim("paris_nyc_spherical_km", float(sph), 5837.0, 15.0,
          "handover quotes 5837 km +/- 15 with the authalic radius")
    values["paris_nyc_geodesic_wgs84_km"] = {
        "measured": float(geo), "handover_quoted": None, "tolerance": 0,
        "agrees": True,
        "note": "oracle O4 pyproj.Geod; quantifies the spherical error"}
    values["paris_nyc_spherical_vs_geodesic_pct"] = {
        "measured": float(100 * (sph - geo) / geo),
        "handover_quoted": None, "tolerance": 0, "agrees": True,
        "note": "handover D-001 claims the spherical model costs <= 0.3%"}
    return float(sph), float(geo)


# ---------------------------------------------------------------------------
# 9. Scale factors: analytic invariants (handover Stage B accuracy table)
# ---------------------------------------------------------------------------
def scale_factors(lon, lat, crs, h=1e-6):
    """Central differences on project(), metric-corrected by cos(lat)."""
    lon = np.asarray(lon, dtype=float)
    lat = np.asarray(lat, dtype=float)
    xp, yp = K.project(lon, lat + h, crs)
    xm, ym = K.project(lon, lat - h, crs)
    dxdphi = (xp - xm) / (2 * h * K.D2R)
    dydphi = (yp - ym) / (2 * h * K.D2R)
    xp, yp = K.project(lon + h, lat, crs)
    xm, ym = K.project(lon - h, lat, crs)
    coslat = np.cos(lat * K.D2R)
    dxdlam = (xp - xm) / (2 * h * K.D2R) / coslat
    dydlam = (yp - ym) / (2 * h * K.D2R) / coslat
    hh = np.hypot(dxdphi, dydphi)
    kk = np.hypot(dxdlam, dydlam)
    # sin(theta') from the cross product of the two parametric tangents.
    cross = np.abs(dxdphi * dydlam - dxdlam * dydphi)
    area = cross / coslat * coslat  # = |J| / cos(lat) * cos(lat)
    area = cross
    sin_tp = np.clip(area / (hh * kk), -1.0, 1.0)
    ap = np.sqrt(np.maximum(hh ** 2 + kk ** 2 + 2 * hh * kk * sin_tp, 0.0))
    bp = np.sqrt(np.maximum(hh ** 2 + kk ** 2 - 2 * hh * kk * sin_tp, 0.0))
    a = (ap + bp) / 2
    b = (ap - bp) / 2
    omega = 2 * np.arcsin(np.clip(
        np.where(a + b == 0, 0.0, (a - b) / np.where(a + b == 0, 1.0, a + b)),
        -1.0, 1.0)) * K.R2D
    return {"h": hh, "k": kk, "area": area, "omega_deg": omega}


def check_scale_factors():
    out = {}
    # Mercator k = sec(lat)
    crs = K.Crs("mercator")
    lats = np.array([0.0, 30.0, 60.0])
    sf = scale_factors(np.zeros_like(lats), lats, crs)
    err = float(np.max(np.abs(sf["k"] - 1 / np.cos(lats * K.D2R))))
    claim("mercator_k_equals_sec_lat_maxerr", err, 0.0, 1e-6,
          "handover asserts 1e-6 at lat 0, 30, 60")
    out["mercator_k_err"] = err
    # Equal-area: area scale == 1
    lonS = np.array([-120.0, -30.0, 0.0, 45.0, 100.0])
    latS = np.array([-60.0, -20.0, 0.0, 25.0, 55.0])
    for name, kw in (("mollweide", {}), ("hammer", {}), ("sinusoidal", {}),
                     ("lambert", dict(lat0=0.0)),
                     ("albers", dict(lat0=40.0, sp1=20.0, sp2=60.0))):
        c = K.Crs(name, **kw)
        sf = scale_factors(lonS, latS, c)
        e = float(np.nanmax(np.abs(sf["area"] - 1.0)))
        out[f"{name}_area_scale_err"] = e
        claim(f"{name}_area_scale_err", e, 0.0, 1e-6,
              "handover asserts equal-area projections give AreaScale == 1 "
              "to 1e-6")
    # Conformal: h == k
    for name, kw in (("mercator", {}), ("stereographic", dict(lat0=40.0)),
                     ("lambertconformal",
                      dict(lon0=-96.0, lat0=23.0, sp1=33.0, sp2=45.0))):
        c = K.Crs(name, **kw)
        sf = scale_factors(lonS, latS, c)
        e = float(np.nanmax(np.abs(sf["h"] - sf["k"])))
        out[f"{name}_h_minus_k"] = e
        claim(f"{name}_h_minus_k", e, 0.0, 1e-6,
              "handover asserts conformal projections give h == k to 1e-6")
    # LCC k == 1 on both standard parallels
    c = K.Crs("lambertconformal", lon0=-96.0, lat0=23.0, sp1=33.0, sp2=45.0)
    sf = scale_factors(np.array([-96.0, -96.0]), np.array([33.0, 45.0]), c)
    e = float(np.nanmax(np.abs(sf["k"] - 1.0)))
    out["lcc_k_on_standard_parallels_err"] = e
    claim("lcc_k_on_standard_parallels_err", e, 0.0, 1e-6,
          "handover asserts k == 1 on both standard parallels to 1e-6")
    values["scale_factors"] = out
    return out


# ---------------------------------------------------------------------------
# 10. Scale variation across map extents — settles handover debt V8 / D-006
# ---------------------------------------------------------------------------
def check_scale_variation():
    out = {}
    extents = {
        # Keep off the antimeridian: a central difference across the seam
        # straddles a wrap discontinuity and returns garbage (PV-008).
        "global": (-178.0, 178.0, -85.0, 85.0),
        "regional_10deg": (-5.0, 5.0, 35.0, 45.0),
        "regional_30deg": (-15.0, 15.0, 30.0, 60.0),
        "continental_60deg": (-30.0, 30.0, 20.0, 70.0),
    }
    cfg = {
        "equirectangular": {}, "mercator": {}, "robinson": {},
        "mollweide": {}, "hammer": {}, "winkeltripel": {}, "sinusoidal": {},
        "lambert": dict(lat0=40.0), "stereographic": dict(lat0=40.0),
        "orthographic": dict(lat0=40.0),
        "azimuthalequidistant": dict(lat0=40.0),
        "lambertconformal": dict(lat0=40.0, sp1=33.0, sp2=45.0),
        "albers": dict(lat0=40.0, sp1=29.5, sp2=45.5),
        "transversemercator": dict(lat0=40.0),
    }
    for name, kw in cfg.items():
        crs = K.Crs(name, **kw)
        row = {}
        for ename, (lo1, lo2, la1, la2) in extents.items():
            lons = np.array([lo1, lo2, lo1, lo2, 0.5 * (lo1 + lo2)])
            lats = np.array([la1, la1, la2, la2, 0.5 * (la1 + la2)])
            sf = scale_factors(lons, lats, crs)
            # LINEAR scale, not area scale.  An equal-area projection has
            # area scale 1 everywhere by construction, so an area-based gate
            # would pass global Mollweide -- exactly the case a scale bar is
            # meaningless on.  Finding PV-009: the scalebar validity gate
            # must read h and k.
            hi_ = np.maximum(sf["h"], sf["k"])
            lo_ = np.minimum(sf["h"], sf["k"])
            hi_ = hi_[np.isfinite(hi_) & (hi_ > 0)]
            lo_ = lo_[np.isfinite(lo_) & (lo_ > 0)]
            row[ename] = (float(np.max(hi_) / np.min(lo_))
                          if hi_.size and lo_.size else float("nan"))
        out[name] = row
    values["scale_variation_max_over_min"] = out
    return out


def main():
    print("geoMap v2 mirror — pre-validation of handover revision 2.0")
    print("=" * 66)
    check_cone_constant()
    check_mercator()
    check_polar_stereographic()
    check_lcc_point()
    check_robinson()
    check_equal_area()
    check_round_trips()
    check_great_circle()
    check_scale_factors()
    check_scale_variation()
    # Stage 0.3: the two oracle rows that were still empty. O8 (gdaldem)
    # and O7 (gdalwarp) are reached through gdal_oracle, whose own route
    # is proved on an analytically known plane before anything cites it.
    values.update(RG.measure())
    values.update(H.measure())
    # Stage A pre-validation: the domains, the degenerate conic, the wrap
    # formulation and the crossing parameter. Run in CI so a later change
    # to any of them is caught by the same gate as the rest.
    values.update(SA.measure())

    payload = {
        "generated": "2026-08-15",
        "model": "sphere, R = 1 (authalic 6371.0072 km for distances)",
        "oracle": "pyproj 3.7.2 / PROJ 9.5.1",
        "oracle_gdal": GD.provenance(),
        "oracle_gdal_self_test": GD.self_test(),
        "values": values,
        "findings": findings,
    }
    (OUT / "reference_values.json").write_text(json.dumps(payload, indent=2))

    print(f"\nvalues recorded : {len(values)}")
    print(f"FINDINGS        : {len(findings)}")
    for f in findings:
        print(f"\n  ! {f['label']}")
        print(f"      handover quoted : {f['quoted']}")
        print(f"      measured        : {f['measured']:.10g}")
        print(f"      abs error       : {f['abs_error']:.4g}"
              f"   (tolerance {f['tolerance']:g})")
    print(f"\nwritten: {OUT / 'reference_values.json'}")
    return findings


if __name__ == "__main__":
    main()
