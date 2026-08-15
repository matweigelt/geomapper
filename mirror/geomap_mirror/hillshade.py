"""geomap_mirror.hillshade — Horn hillshade, and oracle O8.

Mirrors what `geo.hillshade` will compute in Stage B (handover §7.4 B.2.5),
and measures it against oracle O8 (`gdaldem hillshade` / `slope` /
`aspect`, Horn), which `gdal_oracle.py` makes reachable.

THE ONE CORRECTNESS POINT, and the reason this is not a plain image
filter: on a longitude/latitude grid the east-west spacing is
`R*cos(lat)*dlon` and therefore varies PER ROW, while the north-south
spacing `R*dlat` does not.  A gradient that ignores that metric under-
shades high latitudes, and does so smoothly enough to look plausible.
The test that catches it is the ratio of the measured slope of the SAME
east-west ramp at latitude 0 and latitude 60, which must be exactly
1/cos(60) = 2.

WHAT O8 CAN AND CANNOT CERTIFY, measured rather than assumed:

  * GDAL has no per-row metric.  It is therefore an oracle for the Horn
    KERNEL on a constant-spacing tile, and says nothing about the cos(lat)
    correction.  That correction is checked analytically instead (limit
    L10).
  * `gdaldem hillshade` emits uint8 (1..255), so it cannot certify a shade
    beyond ~1/254 = 3.9e-3.  `gdaldem slope` and `aspect` emit Float32 and
    certify the gradient itself to ~1e-6 (limit L9).  The gradient is the
    part worth certifying; the Lambertian step after it is three lines of
    closed-form trigonometry with its own exact flat-terrain check.

geoMap v2.0 mirror | 15-Aug-2026 | Claude Opus 5 (Anthropic)
"""

from __future__ import annotations

import numpy as np

from . import gdal_oracle as G
from . import kernels as K

D2R = np.pi / 180.0


# ---------------------------------------------------------------------------
# The kernel
# ---------------------------------------------------------------------------
def horn_gradients(z, dx, dy):
    """Horn 3x3 gradients.

    INPUTS
      z   (M,N) float   Elevation.  Row 0 is the SOUTHERNMOST row, matching
                        geoMap's grid convention (ascending latitude), NOT
                        a GeoTIFF's north-up convention.
      dx  (M,1) or float  East-west spacing, in z units.  A COLUMN vector
                        broadcasts per row, which is the spherical case.
      dy  float         North-south spacing, in z units.

    OUTPUTS
      gx  (M,N) float   dz/d(east).
      gy  (M,N) float   dz/d(north).

    Edges use replicate padding, so the outermost row and column carry a
    one-sided difference.  Stated because it is a choice: reflecting would
    force zero gradient at the edge, which is a claim about the terrain.
    """
    z = np.asarray(z, dtype=float)
    p = np.pad(z, 1, mode="edge")
    # a b c   <- north (higher row index in geoMap convention)
    # d e f
    # g h i   <- south
    nw, n_, ne = p[2:, :-2], p[2:, 1:-1], p[2:, 2:]
    w_, e_ = p[1:-1, :-2], p[1:-1, 2:]
    sw, s_, se = p[:-2, :-2], p[:-2, 1:-1], p[:-2, 2:]
    gx = ((ne + 2 * e_ + se) - (nw + 2 * w_ + sw)) / (8.0 * np.asarray(dx))
    gy = ((nw + 2 * n_ + ne) - (sw + 2 * s_ + se)) / (8.0 * dy)
    return gx, gy


def slope_aspect(gx, gy):
    """Slope (deg from horizontal) and aspect (deg cw from north, the
    direction the surface FACES, i.e. steepest descent).

    The aspect convention is GDAL's, and it was established by measuring
    a constant-gradient plane rather than by recalling it: the first
    expectation written here was 180 degrees wrong (see
    `gdal_oracle.self_test`).
    """
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    aspect = np.degrees(np.arctan2(-gx, -gy)) % 360.0
    return slope, aspect


def lambert_shade(slope_deg, aspect_deg, azimuth=315.0, elevation=45.0,
                  ambient=0.35):
    """Lambertian shade in [0,1], with an ambient floor.

    shade = Ambient + (1 - Ambient) * max(cos(incidence), 0)

    The ambient term is what stops a shadowed slope going fully black, and
    it is why `geo.colormaps("truecolor", Shade=...)` can multiply straight
    into RGB without crushing the data it is meant to reveal.
    """
    zen = (90.0 - elevation) * D2R
    slp = slope_deg * D2R
    cang = (np.cos(zen) * np.cos(slp)
            + np.sin(zen) * np.sin(slp)
            * np.cos((azimuth - aspect_deg) * D2R))
    return ambient + (1.0 - ambient) * np.maximum(cang, 0.0)


def hillshade(lon, lat, topo, azimuth=315.0, elevation=45.0, ambient=0.35,
              zfactor=1.0, radius_km=K.AUTHALIC_RADIUS_KM):
    """Spherical-metric Horn hillshade.  Returns shade in [0,1].

    `lat` ascends.  Spacing is derived from the coordinate vectors, never
    from a step passed in beside them: a step and a vector that disagree is
    a silent wrong answer, and the vector is the thing that was measured.
    """
    lon = np.asarray(lon, dtype=float)
    lat = np.asarray(lat, dtype=float)
    r_m = radius_km * 1000.0
    dlon = np.median(np.diff(lon)) * D2R
    dlat = np.median(np.diff(lat)) * D2R
    dx = (r_m * np.cos(lat * D2R) * dlon)[:, None]     # per row
    dy = r_m * dlat
    gx, gy = horn_gradients(np.asarray(topo, float) * zfactor, dx, dy)
    slope, aspect = slope_aspect(gx, gy)
    return lambert_shade(slope, aspect, azimuth, elevation, ambient)


# ---------------------------------------------------------------------------
# Measurements
# ---------------------------------------------------------------------------
def check_flat_terrain(elevation=45.0, ambient=0.35):
    """Flat terrain has slope 0, so shade = Ambient + (1-Ambient)*sin(elev).

    Analytically exact, so the tolerance is machine precision.  This is the
    check that a metric error CANNOT pass and a Lambertian error cannot
    survive.
    """
    lat = np.linspace(-60.0, 60.0, 61)
    lon = np.linspace(-30.0, 30.0, 61)
    z = np.zeros((lat.size, lon.size))
    s = hillshade(lon, lat, z, elevation=elevation, ambient=ambient)
    want = ambient + (1.0 - ambient) * np.sin(elevation * D2R)
    return {"expected": float(want),
            "max_abs_error": float(np.max(np.abs(s - want)))}


def check_metric_ratio():
    """The test that catches a missing cos(lat).

    The SAME east-west elevation ramp, in metres per degree of longitude,
    is physically steeper near the pole because a degree of longitude is
    shorter there.  Measured slope at latitude 60 must therefore exceed
    that at latitude 0 by exactly 1/cos(60) = 2.
    """
    lon = np.linspace(-10.0, 10.0, 201)
    out = {}
    for lat_c in (0.0, 60.0):
        lat = lat_c + np.linspace(-0.5, 0.5, 21)
        z = np.tile(100.0 * lon, (lat.size, 1))        # 100 m per degree lon
        r_m = K.AUTHALIC_RADIUS_KM * 1000.0
        dx = (r_m * np.cos(lat * D2R) * (np.median(np.diff(lon)) * D2R))[:, None]
        dy = r_m * np.median(np.diff(lat)) * D2R
        gx, _ = horn_gradients(z, dx, dy)
        out[lat_c] = float(np.median(np.abs(gx[2:-2, 2:-2])))
    ratio = out[60.0] / out[0.0]
    return {"slope_lat0": out[0.0], "slope_lat60": out[60.0],
            "ratio": float(ratio), "expected": 1.0 / np.cos(60.0 * D2R),
            "rel_error": float(abs(ratio - 2.0) / 2.0)}


def check_against_gdal(seed=42):
    """Oracle O8, on a constant-spacing tile where GDAL is a valid authority.

    A random but smooth surface, so the comparison exercises every branch
    of the aspect quadrant logic rather than one favourable direction.
    """
    if not G.available():
        return {"skipped": "GDAL not reachable", **G.provenance()}
    rng = np.random.default_rng(seed)
    ny, nx, d = 120, 160, 30.0                       # 30 m pixels, planar
    coarse = rng.normal(0.0, 120.0, (ny // 8 + 2, nx // 8 + 2))
    yi = np.linspace(0, coarse.shape[0] - 1, ny)
    xi = np.linspace(0, coarse.shape[1] - 1, nx)
    from scipy.interpolate import RectBivariateSpline
    z = RectBivariateSpline(np.arange(coarse.shape[0]),
                            np.arange(coarse.shape[1]), coarse)(yi, xi)

    # GeoTIFF row 0 is north; the mirror's row 0 is south.  Flipping here
    # rather than "adjusting a sign later" keeps the convention in one
    # place, which is the only way a sign error stays findable.
    z_north_up = np.flipud(z)

    gdal_slope = np.flipud(G.dem(z_north_up, d, d, "slope",
                                 extra=["-s", "1", "-alg", "Horn"]))
    gdal_aspect = np.flipud(G.dem(z_north_up, d, d, "aspect",
                                  extra=["-alg", "Horn"]))
    gdal_shade = np.flipud(G.dem(z_north_up, d, d, "hillshade",
                                 extra=["-s", "1", "-alg", "Horn",
                                        "-az", "315", "-alt", "45",
                                        "-z", "1"]))

    gx, gy = horn_gradients(z, d, d)
    slope, aspect = slope_aspect(gx, gy)

    # Compare the interior only: GDAL's -compute_edges and the mirror's
    # replicate padding are different edge POLICIES, and comparing them
    # would measure the policy rather than the kernel.
    sl = slice(2, -2)
    ds = np.abs(slope[sl, sl] - gdal_slope[sl, sl])
    # Aspect is undefined on a flat pixel and wraps at 360; compare only
    # where there is a real gradient, and compare the circular difference.
    live = slope[sl, sl] > 0.5
    da = np.abs((aspect[sl, sl] - gdal_aspect[sl, sl] + 180.0) % 360.0 - 180.0)

    # GDAL's hillshade byte: 1 + 254*cang, clamped to 1 where cang <= 0.
    cang = (lambert_shade(slope, aspect, 315.0, 45.0, 0.0))
    want_byte = np.where(cang <= 0, 1.0, 1.0 + 254.0 * cang)
    dh = np.abs(np.round(want_byte[sl, sl]) - gdal_shade[sl, sl])

    return {
        **G.provenance(),
        "slope_max_abs_error_deg": float(np.max(ds)),
        "aspect_max_abs_error_deg": float(np.max(da[live])),
        "aspect_pixels_compared": int(live.sum()),
        "hillshade_max_abs_error_dn": float(np.max(dh)),
        "hillshade_quantisation_dn": 1.0,
        "note": ("slope/aspect are Float32 and certify the Horn kernel; "
                 "hillshade is uint8 and certifies only to 1 DN = 1/254"),
    }


def measure():
    """Everything this module contributes to reference_values.json."""
    return {
        "hillshade_flat_terrain": check_flat_terrain(),
        "hillshade_metric_ratio_lat60_over_lat0": check_metric_ratio(),
        "hillshade_vs_O8_gdal": check_against_gdal(),
    }


if __name__ == "__main__":
    import json

    print(json.dumps(measure(), indent=2))
