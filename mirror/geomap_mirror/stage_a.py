"""geomap_mirror.stage_a — pre-validation for Stage A (L0 + longitude topology).

Handover §7.3 names the numbers Stage A will assert. Debt V1's standing rule
says none of them may be asserted until the mirror has reproduced it, so
this module reproduces them and reports the disagreements BEFORE any MATLAB
is written.

Four groups:

  1. THE DECLARED DOMAINS. `crs.Domain` is meant to be "the single
     authority for every projection limit in the toolbox", replacing v1's
     scattered `cosc <` literals (F12). But the four numbers the handover
     declares — stereographic 154, gnomonic 84, azimuthalequidistant 178,
     orthographic 90 — are v1's literals ROUNDED, not limits derived from
     anything. Replacing a magic number with the same magic number in a
     nicer struct is not what F12 asked for. This measures what each
     literal actually corresponds to and what the mathematics actually
     requires, so the declared value can be a decision with a reason
     rather than an inheritance.

  2. THE DEGENERATE CONIC. `|n| < 1e-12 -> geo:crs:DegenerateConic`. The
     handover's robustness test says "LCC with p1 = -p2 gives n exactly 0
     (not roughly zero)". Exactness is a claim about floating-point
     arithmetic and is checked here rather than assumed.

  3. THE WRAP. `wrapLongitude(180,0) == -180` and `wrapLongitude(-180,0)
     == -180` EXACTLY, bitwise. The chosen formula must be checked for
     that, because a formula that is right to 1e-12 fails the stated
     criterion and every downstream seam test inherits the error.

  4. THE GREAT CIRCLE. Already measured at Stage 0 (5837.2 km spherical,
     -0.268% against the WGS84 geodesic); re-checked here so Stage A's
     assertion cites a number this module reproduced.

geoMap v2.0 mirror | 15-Aug-2026 | Claude Opus 5 (Anthropic)
"""

from __future__ import annotations

import numpy as np

from . import kernels as K
from . import oracle as O

D2R = K.D2R


# ---------------------------------------------------------------------------
# 1. What v1's magic literals actually mean
# ---------------------------------------------------------------------------
def check_declared_domains():
    """Map each v1 `cosc <` literal to the angle it really is.

    v1 clipped on cos(c), where c is angular distance from the projection
    centre. The handover then declared a domain in DEGREES. The two are
    only the same statement if the degree figure is acos of the literal,
    and it is not: every one of them is rounded, and the rounding is
    always inward.
    """
    lits = {
        "stereographic": -0.9,
        "gnomonic": 0.1,
        "azimuthalequidistant": -0.9994,
        "orthographic": 0.0,
    }
    out = {}
    for name, lit in lits.items():
        exact = float(np.degrees(np.arccos(lit)))
        declared = K.MAX_ANGULAR_DISTANCE_DEG[name]
        out[name] = {
            "v1_literal_cosc": lit,
            "exact_acos_deg": exact,
            "handover_declared_deg": declared,
            "declared_minus_exact_deg": float(declared - exact),
            "declared_is_inside_exact": bool(declared <= exact + 1e-12),
        }

    # What the MATHEMATICS requires, as against what v1 chose for looks.
    # Only two of the four have a real singularity.
    out["_mathematical_limits"] = {
        "orthographic": {
            "hard_limit_deg": 90.0,
            "why": ("the far hemisphere is not visible at all; beyond 90 "
                    "deg the point is behind the globe. A true limit."),
        },
        "gnomonic": {
            "hard_limit_deg": 90.0,
            "why": ("tan(c) diverges at exactly 90 deg. The declared 84 "
                    "deg is a COSMETIC clip well inside the singularity, "
                    "chosen because the projection is unusable long "
                    "before it."),
        },
        "stereographic": {
            "hard_limit_deg": 180.0,
            "why": ("only the antipode itself is singular. The declared "
                    "154 deg is cosmetic."),
        },
        "azimuthalequidistant": {
            "hard_limit_deg": 180.0,
            "why": ("the antipode is a whole circle, so the inverse is "
                    "ill-posed there, but the forward is finite. The "
                    "declared 178 deg is a conditioning guard."),
        },
    }
    return out


# ---------------------------------------------------------------------------
# 2. Degenerate conic
# ---------------------------------------------------------------------------
def check_degenerate_conic():
    """Is n EXACTLY zero when p1 = -p2, or merely close?"""
    out = {}
    for p in (10.0, 30.0, 33.0, 45.0, 60.0):
        n_lcc = _lcc_raw(p, -p)
        n_alb = 0.5 * (np.sin(p * D2R) + np.sin(-p * D2R))
        out[f"p1={p}, p2={-p}"] = {
            "lcc_n": float(n_lcc),
            "lcc_exactly_zero": bool(n_lcc == 0.0),
            "albers_n": float(n_alb),
            "albers_exactly_zero": bool(n_alb == 0.0),
        }
    # The tangent case must NOT be degenerate: p1 == p2 gives n = sin(p1).
    out["tangent_case_p1_equals_p2"] = {
        "n_at_45": float(K.cone_constant("lambertconformal", 45.0, 45.0)),
        "expected_sin45": float(np.sin(45.0 * D2R)),
    }
    # Where does |n| < 1e-12 actually bite? A near-symmetric pair.
    eps_deg = []
    for d in (1e-6, 1e-8, 1e-10, 1e-12):
        n = _lcc_raw(45.0, -45.0 + d)
        eps_deg.append({"asymmetry_deg": d, "n": float(n),
                        "would_be_rejected": bool(abs(n) < 1e-12)})
    out["near_degenerate_ladder"] = eps_deg
    return out


def _lcc_raw(sp1, sp2):
    """Cone constant WITHOUT the degeneracy guard, so zero is visible."""
    p1, p2 = sp1 * D2R, sp2 * D2R
    if abs(p1 - p2) < 1e-9:
        return np.sin(p1)
    return (np.log(np.cos(p1) / np.cos(p2))
            / np.log(np.tan(0.25 * np.pi + 0.5 * p2)
                     / np.tan(0.25 * np.pi + 0.5 * p1)))


# ---------------------------------------------------------------------------
# 3. The wrap, and whether the stated exactness is achievable
# ---------------------------------------------------------------------------
def check_wrap_exactness():
    """The handover demands bitwise results at the seam. Check the formula.

    Two candidate formulations, because they are NOT equivalent in floating
    point and the difference lands exactly on the values the handover names:

        A:  mod(lon - lon0 + 180, 360) - 180 + lon0
        B:  mod(lon - (lon0 - 180), 360) + (lon0 - 180)

    Both are exact for lon0 = 0. They part company for a shifted window,
    where A adds and subtracts lon0 around a mod and B folds it into one
    offset.
    """
    def wrap_a(lon, lon0):
        return np.mod(lon - lon0 + 180.0, 360.0) - 180.0 + lon0

    def wrap_b(lon, lon0):
        return np.mod(lon - (lon0 - 180.0), 360.0) + (lon0 - 180.0)

    out = {}
    named = [(180.0, 0.0, -180.0), (-180.0, 0.0, -180.0),
             (539.5, 0.0, 179.5), (0.0, 0.0, 0.0), (-0.0, 0.0, 0.0)]
    for lon, lon0, want in named:
        a = float(wrap_a(lon, lon0))
        b = float(wrap_b(lon, lon0))
        out[f"lon={lon}, lon0={lon0}"] = {
            "expected": want,
            "formula_A": a, "A_bitwise": bool(a == want),
            "formula_B": b, "B_bitwise": bool(b == want),
        }

    # Shifted window, where the two formulations diverge. The window
    # [lon0-180, lon0+180) must be half-open at BOTH ends: lon0+180 wraps
    # to lon0-180, and lon0-180 stays put.
    shifted = {}
    for lon0 in (40.0, -96.0, 180.0, 0.1):
        rows = {}
        for lon in (lon0 + 180.0, lon0 - 180.0, lon0):
            a = float(wrap_a(lon, lon0))
            b = float(wrap_b(lon, lon0))
            want = lon0 - 180.0 if lon != lon0 else lon0
            rows[f"lon={lon}"] = {
                "expected": want,
                "A": a, "A_bitwise": bool(a == want),
                "B": b, "B_bitwise": bool(b == want),
            }
        shifted[f"lon0={lon0}"] = rows
    out["_shifted_windows"] = shifted

    # Idempotence, which is a metamorphic property Stage A asserts.
    rng = np.random.default_rng(42)
    lon = rng.uniform(-1e4, 1e4, 100000)
    for tag, fn in (("A", wrap_a), ("B", wrap_b)):
        for lon0 in (0.0, 40.0, -96.0):
            once = fn(lon, lon0)
            twice = fn(once, lon0)
            out[f"idempotent_{tag}_lon0={lon0}"] = {
                "max_abs_diff": float(np.max(np.abs(twice - once))),
                "bitwise": bool(np.array_equal(twice, once)),
            }
    # In-window check: every result must satisfy lon0-180 <= x < lon0+180.
    for tag, fn in (("A", wrap_a), ("B", wrap_b)):
        for lon0 in (0.0, 40.0, -96.0):
            w = fn(lon, lon0)
            out[f"inwindow_{tag}_lon0={lon0}"] = {
                "min": float(np.min(w)), "max": float(np.max(w)),
                "all_in_half_open": bool(np.all(w >= lon0 - 180.0)
                                         and np.all(w < lon0 + 180.0)),
            }
    return out


# ---------------------------------------------------------------------------
# 4. splitAntimeridian's interpolated crossing
# ---------------------------------------------------------------------------
def check_crossing_interpolation():
    """The inserted crossing point must be at exactly +/-180, lat to 1e-12.

    Linear interpolation of a two-point segment has no truncation error, so
    anything looser than machine precision would be hiding a defect. What
    IS worth measuring is the parameter t: computed from wrapped or
    unwrapped longitudes, it differs, and only one of them is right.
    """
    # A segment crossing the antimeridian eastward: 179 -> -179, i.e. a
    # 2-degree step, NOT a 358-degree one.
    lon1, lat1 = 179.0, 10.0
    lon2, lat2 = -179.0, 20.0
    d_wrapped = float(K.wrap_longitude(lon2 - lon1, 0.0))     # -> +2
    d_naive = lon2 - lon1                                     # -> -358
    t_wrapped = (180.0 - lon1) / d_wrapped
    t_naive = (180.0 - lon1) / d_naive
    return {
        "delta_wrapped": d_wrapped,
        "delta_naive": d_naive,
        "t_wrapped": float(t_wrapped),
        "t_naive": float(t_naive),
        "lat_at_crossing_wrapped": float(lat1 + t_wrapped * (lat2 - lat1)),
        "lat_at_crossing_naive": float(lat1 + t_naive * (lat2 - lat1)),
        "note": ("the wrapped delta gives lat 15.0 at the crossing, which "
                 "is the midpoint of a 2-degree step and obviously right. "
                 "The naive delta gives a latitude barely moved from the "
                 "start, and would look plausible on a plot"),
    }


# ---------------------------------------------------------------------------
# 5. Great circle, re-measured so Stage A cites this module
# ---------------------------------------------------------------------------
def check_great_circle():
    lon1, lat1 = 2.3522, 48.8566          # Paris
    lon2, lat2 = -74.0060, 40.7128        # New York
    sph = float(O.spherical_distance_km(lon1, lat1, lon2, lat2,
                                        K.AUTHALIC_RADIUS_KM))
    geo = float(O.geodesic_distance_km(lon1, lat1, lon2, lat2))
    # Initial bearing, spherical.
    p1, p2 = np.radians([lat1, lat2])
    dl = np.radians(lon2 - lon1)
    brg = float(np.degrees(np.arctan2(
        np.sin(dl) * np.cos(p2),
        np.cos(p1) * np.sin(p2) - np.sin(p1) * np.cos(p2) * np.cos(dl))) % 360)
    az12, _, _ = O.pyproj.Geod(ellps="WGS84").inv(lon1, lat1, lon2, lat2)
    return {
        "spherical_km": sph,
        "geodesic_wgs84_km": geo,
        "difference_pct": float(100 * (sph - geo) / geo),
        "initial_bearing_spherical_deg": brg,
        "initial_bearing_geodesic_deg": float(az12 % 360),
        "bearing_difference_deg": float((brg - az12 % 360)),
    }


def measure():
    return {
        "stage_a_declared_domains": check_declared_domains(),
        "stage_a_degenerate_conic": check_degenerate_conic(),
        "stage_a_wrap_exactness": check_wrap_exactness(),
        "stage_a_crossing_interpolation": check_crossing_interpolation(),
        "stage_a_great_circle": check_great_circle(),
    }


if __name__ == "__main__":
    import json

    print(json.dumps(measure(), indent=2))
