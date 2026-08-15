"""geomap_mirror.oracle — oracle O4: pyproj / PROJ, an INDEPENDENT authority.

Deliberately separate from kernels.py.  The handover (rev 2.0 §2.2) said the
mirror should be "thin wrappers over pyproj where PROJ has the projection".
Pre-validation finding PV-001 rejects that: it collapses two jobs that must
stay apart.

  kernels.py  mirrors what the MATLAB will compute (Snyder spherical
              formulas, same algorithm), so a MATLAB disagreement localises
              a defect in the MATLAB.
  oracle.py   is an independent implementation (PROJ's own code paths), so
              agreement with it is EVIDENCE rather than tautology.

If the mirror were the oracle, a MATLAB/mirror disagreement could not
distinguish "MATLAB's Newton iteration is wrong" from "the two use
different algorithms", and the round-trip suite would be checking PROJ
against itself.

PROJ is configured with a SPHERE of the authalic Earth radius, and the
SOURCE CRS is geographic ON THAT SAME SPHERE -- not EPSG:4326.  Both
choices are load-bearing and were found by pre-validation:

  * +R=1 is rejected by PROJ 9.5 as a non-Earth celestial body.  Using the
    authalic radius in metres and dividing the result avoids overriding a
    safety check with PROJ_IGNORE_CELESTIAL_BODY.
  * Transforming from EPSG:4326 would make PROJ insert an ellipsoid->sphere
    datum shift, so the comparison would measure that conversion (tens of
    kilometres at mid-latitude) instead of the projection.  Finding PV-002.

Where PROJ's parameterisation differs from Snyder's, the difference is
recorded in LIMITS.md rather than absorbed silently.

geoMap v2.0 mirror | 13-Aug-2026 | Claude Opus 5 (Anthropic)
"""

from __future__ import annotations

import numpy as np
import pyproj

# Authalic Earth radius in metres.  PROJ works on this sphere; outputs are
# divided by it to return Earth radii, matching the mirror kernels.
SPHERE_R_M = 6371007.2

# Geographic CRS on the SAME sphere -- see the module docstring, PV-002.
_LONLAT_SPHERE = f"+proj=longlat +R={SPHERE_R_M} +no_defs +type=crs"

# PROJ names for the projections it supports on a sphere.  Entries that are
# None are NOT available as an independent oracle and must fall back to
# published values plus the round-trip; that gap is recorded in LIMITS.md.
PROJ_NAME = {
    "equirectangular": "eqc",
    "mercator": "merc",
    "transversemercator": "tmerc",
    "robinson": "robin",
    "mollweide": "moll",
    "hammer": "hammer",
    "winkeltripel": "wintri",
    "sinusoidal": "sinu",
    "lambert": "laea",
    "stereographic": "stere",
    "orthographic": "ortho",
    "azimuthalequidistant": "aeqd",
    "gnomonic": "gnom",
    "polarstereographic": "stere",
    "lambertconformal": "lcc",
    "albers": "aea",
}


def proj_string(crs):
    """Build a PROJ string for a mirror Crs, on a unit sphere."""
    name = PROJ_NAME.get(crs.name)
    if name is None:
        return None
    parts = [f"+proj={name}", f"+R={SPHERE_R_M}", "+no_defs", "+type=crs"]
    parts.append(f"+lon_0={crs.lon0}")
    if crs.name == "polarstereographic":
        lat0 = 90.0 if crs.hemisphere == "north" else -90.0
        parts.append(f"+lat_0={lat0}")
        if not np.isnan(crs.sp1):
            parts.append(f"+lat_ts={abs(crs.sp1) * (1 if lat0 > 0 else -1)}")
    elif crs.name in ("lambertconformal", "albers"):
        parts.append(f"+lat_0={crs.lat0}")
        parts.append(f"+lat_1={crs.sp1}")
        sp2 = crs.sp1 if np.isnan(crs.sp2) else crs.sp2
        parts.append(f"+lat_2={sp2}")
    elif crs.name in ("lambert", "stereographic", "orthographic",
                      "azimuthalequidistant", "gnomonic",
                      "transversemercator"):
        parts.append(f"+lat_0={crs.lat0}")
    if crs.name == "winkeltripel":
        # PROJ defaults +lat_1 to 0 when absent from the string, which makes
        # wintri a DIFFERENT projection (the lambda term gains a factor
        # 1/cos(phi1)).  Finding PV-003: an oracle silently mis-parameterised
        # is worse than no oracle, because its disagreement looks like a
        # defect in the code under test.
        parts.append(f"+lat_1={np.degrees(np.arccos(2.0 / np.pi))}")
    return " ".join(parts)


def available(crs):
    return proj_string(crs) is not None


def project(lon, lat, crs):
    """Forward through PROJ.  Returns (x, y) in Earth radii."""
    ps = proj_string(crs)
    if ps is None:
        raise ValueError(f"PROJ has no oracle for {crs.name}")
    tr = pyproj.Transformer.from_crs(pyproj.CRS.from_proj4(_LONLAT_SPHERE),
                                     pyproj.CRS.from_proj4(ps),
                                     always_xy=True)
    x, y = tr.transform(np.asarray(lon, dtype=float),
                        np.asarray(lat, dtype=float),
                        errcheck=False)
    x = np.where(np.isinf(x), np.nan, x) / SPHERE_R_M
    y = np.where(np.isinf(y), np.nan, y) / SPHERE_R_M
    return x, y


def unproject(x, y, crs):
    """Inverse through PROJ.  Returns (lon, lat) in degrees."""
    ps = proj_string(crs)
    if ps is None:
        raise ValueError(f"PROJ has no oracle for {crs.name}")
    tr = pyproj.Transformer.from_crs(pyproj.CRS.from_proj4(ps),
                                     pyproj.CRS.from_proj4(_LONLAT_SPHERE),
                                     always_xy=True)
    lon, lat = tr.transform(np.asarray(x, dtype=float) * SPHERE_R_M,
                            np.asarray(y, dtype=float) * SPHERE_R_M,
                            errcheck=False)
    lon = np.where(np.isinf(lon), np.nan, lon)
    lat = np.where(np.isinf(lat), np.nan, lat)
    return lon, lat


def geodesic_distance_km(lon1, lat1, lon2, lat2):
    """WGS84 geodesic distance — the authority for quantifying the spherical
    approximation's error, rather than hand-waving it."""
    g = pyproj.Geod(ellps="WGS84")
    _, _, d = g.inv(lon1, lat1, lon2, lat2)
    return d / 1000.0


def spherical_distance_km(lon1, lat1, lon2, lat2, radius_km):
    """Haversine on a sphere — what geoMap will actually compute."""
    p1, p2 = np.radians(lat1), np.radians(lat2)
    dp = p2 - p1
    dl = np.radians(lon2 - lon1)
    a = np.sin(dp / 2) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(dl / 2) ** 2
    return 2 * radius_km * np.arcsin(np.sqrt(a))
