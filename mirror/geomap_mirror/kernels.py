"""geomap_mirror.kernels — the OWNER of all 16 projection kernels.

Sole authority for the projection mathematics on the Python side.  Nothing
else in this package re-derives a formula; consumers import from here.  A
drifted mirror makes the evidence quietly wrong rather than merely
repetitive, which is worse than no mirror at all.

Model: sphere of unit radius.  All outputs are in Earth radii
(dimensionless); multiply by crs.Radius for physical distance.  Angles in
degrees at the public boundary, radians internally.

Out-of-domain points return NaN.  They are never clamped or relocated —
this is the toolbox-wide contract that geoMap v2 enforces and that v1
violated for Mercator (finding F3).

These are Snyder's SPHERICAL formulas, deliberately mirroring what the
MATLAB will compute, so that a disagreement localises a defect.  They are
NOT the independent oracle: that is oracle.py (pyproj/PROJ).  Keeping the
two apart is what makes agreement between them evidence.

geoMap v2.0 mirror | 13-Aug-2026 | Claude Opus 5 (Anthropic)
"""

from __future__ import annotations

import numpy as np
from scipy.interpolate import PchipInterpolator

D2R = np.pi / 180.0
R2D = 180.0 / np.pi

# Authalic Earth radius, km.  One authority for this fact.
AUTHALIC_RADIUS_KM = 6371.0072

PROJECTIONS = (
    "equirectangular", "mercator", "transversemercator", "robinson",
    "mollweide", "hammer", "winkeltripel", "sinusoidal", "lambert",
    "stereographic", "orthographic", "azimuthalequidistant", "gnomonic",
    "polarstereographic", "lambertconformal", "albers",
)

# Declared domains — the single source of every projection limit.
# max angular distance from the centre, degrees; NaN = unlimited.
MAX_ANGULAR_DISTANCE_DEG = {
    "stereographic": 154.0,
    "gnomonic": 84.0,
    "azimuthalequidistant": 178.0,
    "orthographic": 90.0,
}
LAT_LIMIT_DEG = {
    "mercator": (-85.0, 85.0),
}

# ---------------------------------------------------------------------------
# Robinson tabulated coefficients (Snyder 1987 Table 27; Snyder 1993).
# Latitude 0..90 in steps of 5 degrees.  X scales longitude, Y scales
# latitude; the projection IS this table, so the only freedom is the
# interpolant (PCHIP, matching the MATLAB side).
# ---------------------------------------------------------------------------
ROBINSON_LAT = np.arange(0.0, 95.0, 5.0)
ROBINSON_X = np.array([
    1.0000, 0.9986, 0.9954, 0.9900, 0.9822, 0.9730, 0.9600, 0.9427,
    0.9216, 0.8962, 0.8679, 0.8350, 0.7986, 0.7597, 0.7186, 0.6732,
    0.6213, 0.5722, 0.5322,
])
ROBINSON_Y = np.array([
    0.0000, 0.0620, 0.1240, 0.1860, 0.2480, 0.3100, 0.3720, 0.4340,
    0.4958, 0.5571, 0.6176, 0.6769, 0.7346, 0.7903, 0.8435, 0.8936,
    0.9394, 0.9761, 1.0000,
])
ROBINSON_X_SCALE = 0.8487
ROBINSON_Y_SCALE = 1.3523

_ROB_X = PchipInterpolator(ROBINSON_LAT, ROBINSON_X)
_ROB_Y = PchipInterpolator(ROBINSON_LAT, ROBINSON_Y)
# Inverse: the Y table is strictly monotone, so it can be swapped.
_ROB_LAT_FROM_Y = PchipInterpolator(ROBINSON_Y, ROBINSON_LAT)


def wrap_longitude(lon, lon0=0.0):
    """Wrap into the half-open window [lon0-180, lon0+180).  NaN propagates."""
    lon = np.asarray(lon, dtype=float)
    return np.mod(lon - lon0 + 180.0, 360.0) - 180.0 + lon0


def cone_constant(kind, sp1, sp2=None):
    """Cone constant n for the two conic projections.

    Computed once, here, and reused; the MATLAB geo.crs does the same.
    Returns NaN for a degenerate cone (|n| < 1e-12).
    """
    p1 = sp1 * D2R
    p2 = (sp1 if sp2 is None or np.isnan(sp2) else sp2) * D2R
    if kind == "lambertconformal":
        if abs(p1 - p2) < 1e-9:
            n = np.sin(p1)
        else:
            n = (np.log(np.cos(p1) / np.cos(p2))
                 / np.log(np.tan(0.25 * np.pi + 0.5 * p2)
                          / np.tan(0.25 * np.pi + 0.5 * p1)))
    elif kind == "albers":
        n = 0.5 * (np.sin(p1) + np.sin(p2))
    else:
        raise ValueError(f"not a conic: {kind}")
    return np.nan if abs(n) < 1e-12 else n


class Crs:
    """Mirror of the MATLAB geo.crs value struct."""

    def __init__(self, name, lon0=0.0, lat0=np.nan, hemisphere="north",
                 sp1=np.nan, sp2=np.nan, radius_km=AUTHALIC_RADIUS_KM):
        if name not in PROJECTIONS:
            raise ValueError(f"unknown projection {name!r}")
        self.name = name
        self.lon0 = float(lon0)
        self.hemisphere = hemisphere
        self.sp1 = float(sp1)
        self.sp2 = float(sp2)
        self.radius_km = float(radius_km)

        if name in ("lambertconformal", "albers"):
            if np.isnan(sp1):
                raise ValueError(f"{name} requires a standard parallel")
            self.cone = cone_constant(name, sp1, sp2)
            if np.isnan(self.cone):
                raise ValueError(f"{name}: degenerate cone")
        else:
            self.cone = np.nan

        if np.isnan(lat0):
            lat0 = 0.0
        self.lat0 = float(lat0)
        self.max_c_deg = MAX_ANGULAR_DISTANCE_DEG.get(name, np.nan)
        self.lat_limit = LAT_LIMIT_DEG.get(name, (-90.0, 90.0))

    def __repr__(self):
        return (f"Crs({self.name!r}, lon0={self.lon0}, lat0={self.lat0}, "
                f"sp1={self.sp1}, sp2={self.sp2})")


def _oblique_terms(lam, phi, phi1):
    """cos c and the shared oblique-azimuthal building blocks."""
    cosc = np.sin(phi1) * np.sin(phi) + np.cos(phi1) * np.cos(phi) * np.cos(lam)
    return cosc


def project(lon, lat, crs):
    """Forward projection.  Returns (x, y) in Earth radii, NaN out of domain."""
    lon = np.asarray(lon, dtype=float)
    lat = np.asarray(lat, dtype=float)
    lam = wrap_longitude(lon - crs.lon0, 0.0) * D2R
    phi = lat * D2R
    phi0 = crs.lat0 * D2R
    n = crs.name

    lo, hi = crs.lat_limit
    outside_lat = (lat < lo) | (lat > hi)

    if n == "equirectangular":
        x, y = lam.copy(), phi.copy()

    elif n == "mercator":
        x = lam.copy()
        with np.errstate(divide="ignore", invalid="ignore"):
            y = np.log(np.tan(0.25 * np.pi + 0.5 * phi))

    elif n == "transversemercator":
        B = np.cos(phi) * np.sin(lam)
        B = np.clip(B, -1 + 1e-15, 1 - 1e-15)
        x = 0.5 * np.log((1 + B) / (1 - B))
        y = np.arctan2(np.tan(phi), np.cos(lam)) - phi0
        # Great-circle guard: the projection is singular 90 deg from the
        # central meridian along the equator.
        bad = np.abs(B) > np.sin(89.5 * D2R)
        x = np.where(bad, np.nan, x)
        y = np.where(bad, np.nan, y)

    elif n == "robinson":
        alat = np.abs(lat)
        xs = _ROB_X(np.clip(alat, 0.0, 90.0))
        ys = _ROB_Y(np.clip(alat, 0.0, 90.0))
        x = ROBINSON_X_SCALE * lam * xs
        y = ROBINSON_Y_SCALE * ys * np.sign(lat)

    elif n == "mollweide":
        theta = _mollweide_theta(phi)
        x = (2.0 * np.sqrt(2.0) / np.pi) * lam * np.cos(theta)
        y = np.sqrt(2.0) * np.sin(theta)

    elif n == "hammer":
        d = np.sqrt(1.0 + np.cos(phi) * np.cos(0.5 * lam))
        x = 2.0 * np.sqrt(2.0) * np.cos(phi) * np.sin(0.5 * lam) / d
        y = np.sqrt(2.0) * np.sin(phi) / d

    elif n == "winkeltripel":
        phi1 = np.arccos(2.0 / np.pi)
        cosa = np.clip(np.cos(phi) * np.cos(0.5 * lam), -1.0, 1.0)
        alpha = np.arccos(cosa)
        sinc = np.where(np.abs(alpha) < 1e-12, 1.0,
                        np.sin(alpha) / np.where(alpha == 0, 1.0, alpha))
        xa = 2.0 * np.cos(phi) * np.sin(0.5 * lam) / sinc
        ya = np.sin(phi) / sinc
        x = 0.5 * (lam * np.cos(phi1) + xa)
        y = 0.5 * (phi + ya)

    elif n == "sinusoidal":
        x = lam * np.cos(phi)
        y = phi.copy()

    elif n in ("lambert", "stereographic", "orthographic",
               "azimuthalequidistant", "gnomonic"):
        phi1 = phi0
        cosc = _oblique_terms(lam, phi, phi1)
        cosc = np.clip(cosc, -1.0, 1.0)
        if n == "lambert":                      # azimuthal equal-area
            kp = np.sqrt(2.0 / np.maximum(1.0 + cosc, 1e-15))
        elif n == "stereographic":
            kp = 2.0 / np.maximum(1.0 + cosc, 1e-15)
        elif n == "orthographic":
            kp = np.ones_like(cosc)
        elif n == "azimuthalequidistant":
            c = np.arccos(cosc)
            kp = np.where(np.abs(np.sin(c)) < 1e-15, 1.0,
                          c / np.where(np.sin(c) == 0, 1.0, np.sin(c)))
        else:                                    # gnomonic
            kp = 1.0 / np.where(np.abs(cosc) < 1e-15, np.nan, cosc)
        x = kp * np.cos(phi) * np.sin(lam)
        y = kp * (np.cos(phi1) * np.sin(phi)
                  - np.sin(phi1) * np.cos(phi) * np.cos(lam))
        if not np.isnan(crs.max_c_deg):
            c_deg = np.arccos(cosc) * R2D
            bad = c_deg > crs.max_c_deg
            x = np.where(bad, np.nan, x)
            y = np.where(bad, np.nan, y)

    elif n == "polarstereographic":
        south = crs.hemisphere == "south"
        sp = crs.sp1 if not np.isnan(crs.sp1) else 90.0
        k0 = 0.5 * (1.0 + np.sin(abs(sp) * D2R))
        if south:
            rho = 2.0 * k0 * np.tan(0.25 * np.pi + 0.5 * phi)
            x = rho * np.sin(lam)
            y = rho * np.cos(lam)
        else:
            rho = 2.0 * k0 * np.tan(0.25 * np.pi - 0.5 * phi)
            x = rho * np.sin(lam)
            y = -rho * np.cos(lam)

    elif n == "lambertconformal":
        nn = crs.cone
        p1 = crs.sp1 * D2R
        F = (np.cos(p1) * np.tan(0.25 * np.pi + 0.5 * p1) ** nn) / nn
        with np.errstate(divide="ignore", invalid="ignore"):
            rho = F / np.tan(0.25 * np.pi + 0.5 * phi) ** nn
            rho0 = F / np.tan(0.25 * np.pi + 0.5 * phi0) ** nn
        theta = nn * lam
        x = rho * np.sin(theta)
        y = rho0 - rho * np.cos(theta)

    elif n == "albers":
        nn = crs.cone
        p1 = crs.sp1 * D2R
        C = np.cos(p1) ** 2 + 2.0 * nn * np.sin(p1)
        rho = np.sqrt(np.maximum(C - 2.0 * nn * np.sin(phi), 0.0)) / nn
        rho0 = np.sqrt(np.maximum(C - 2.0 * nn * np.sin(phi0), 0.0)) / nn
        theta = nn * lam
        x = rho * np.sin(theta)
        y = rho0 - rho * np.cos(theta)

    else:  # pragma: no cover
        raise ValueError(n)

    x = np.where(outside_lat, np.nan, x)
    y = np.where(outside_lat, np.nan, y)
    return x, y


def _mollweide_theta(phi, tol=1e-13, itmax=15):
    """Newton-Raphson for 2*theta + sin(2*theta) = pi*sin(phi)."""
    phi = np.asarray(phi, dtype=float)
    theta = phi.copy()
    target = np.pi * np.sin(phi)
    for _ in range(itmax):
        f = 2.0 * theta + np.sin(2.0 * theta) - target
        dfd = 2.0 + 2.0 * np.cos(2.0 * theta)
        # Guard BEFORE the divide, not after: at the poles dfd vanishes and
        # an eager f/dfd raises 0/0 even inside np.where.
        safe = np.where(np.abs(dfd) < 1e-15, 1.0, dfd)
        step = np.where(np.abs(dfd) < 1e-15, 0.0, f / safe)
        theta = theta - step
        if np.nanmax(np.abs(step)) < tol:
            break
    # Exact assignment at the poles, where the Newton denominator vanishes.
    theta = np.where(np.abs(np.abs(phi) - 0.5 * np.pi) < 1e-12,
                     np.sign(phi) * 0.5 * np.pi, theta)
    return theta


def _robinson_lat_from_y(yy, itmax=60, tol=1e-13):
    """Invert the forward Y PCHIP to machine precision.

    Bisection on [0, 90] -- monotone by construction, so it cannot fail --
    then a few Newton steps using the interpolant's own derivative.
    """
    yy = np.asarray(yy, dtype=float)
    lo = np.zeros_like(yy)
    hi = np.full_like(yy, 90.0)
    for _ in range(itmax):
        mid = 0.5 * (lo + hi)
        f = _ROB_Y(mid) - yy
        lo = np.where(f < 0.0, mid, lo)
        hi = np.where(f < 0.0, hi, mid)
        if np.nanmax(hi - lo) < 1e-9:
            break
    lat = 0.5 * (lo + hi)
    dY = _ROB_Y.derivative()
    for _ in range(5):
        f = _ROB_Y(lat) - yy
        d = dY(lat)
        step = np.where(np.abs(d) < 1e-12, 0.0, f / np.where(d == 0, 1.0, d))
        lat = np.clip(lat - step, 0.0, 90.0)
        if np.nanmax(np.abs(step)) < tol:
            break
    return lat


def unproject(x, y, crs):
    """Inverse projection.  Returns (lon, lat) in degrees, NaN off-image."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    phi0 = crs.lat0 * D2R
    n = crs.name

    if n == "equirectangular":
        lam, phi = x.copy(), y.copy()

    elif n == "mercator":
        lam = x.copy()
        phi = 2.0 * np.arctan(np.exp(y)) - 0.5 * np.pi

    elif n == "transversemercator":
        D = y + phi0
        phi = np.arcsin(np.clip(np.sin(D) / np.cosh(x), -1.0, 1.0))
        lam = np.arctan2(np.sinh(x), np.cos(D))

    elif n == "robinson":
        yy = np.abs(y) / ROBINSON_Y_SCALE
        off = yy > ROBINSON_Y[-1] + 1e-12
        # Invert the FORWARD PCHIP by bisection+Newton, not by PCHIP on the
        # swapped table.  Finding PV-004: swapping gives a different curve
        # between nodes, and near the pole dY/dlat ~ 0.0048/deg, so a 1e-3
        # interpolation discrepancy becomes a 0.2 deg latitude error.
        alat = _robinson_lat_from_y(np.clip(yy, 0.0, ROBINSON_Y[-1]))
        lat = alat * np.sign(y)
        xs = _ROB_X(np.clip(np.abs(lat), 0.0, 90.0))
        lam = x / (ROBINSON_X_SCALE * xs)
        phi = lat * D2R
        phi = np.where(off, np.nan, phi)
        lam = np.where(off, np.nan, lam)

    elif n == "mollweide":
        s = np.sqrt(2.0)
        off = np.abs(y) > s + 1e-12
        theta = np.arcsin(np.clip(y / s, -1.0, 1.0))
        phi = np.arcsin(np.clip((2.0 * theta + np.sin(2.0 * theta)) / np.pi,
                                -1.0, 1.0))
        lam = np.pi * x / (2.0 * s * np.cos(theta))
        phi = np.where(off, np.nan, phi)
        lam = np.where(off, np.nan, lam)

    elif n == "hammer":
        z2 = 1.0 - (x / 4.0) ** 2 - (y / 2.0) ** 2
        off = z2 <= 0.0
        z = np.sqrt(np.maximum(z2, 1e-300))
        lam = 2.0 * np.arctan2(z * x, 2.0 * (2.0 * z ** 2 - 1.0))
        phi = np.arcsin(np.clip(z * y, -1.0, 1.0))
        phi = np.where(off, np.nan, phi)
        lam = np.where(off, np.nan, lam)

    elif n == "winkeltripel":
        lam, phi = _winkel_inverse(x, y)

    elif n == "sinusoidal":
        phi = y.copy()
        lam = x / np.cos(phi)

    elif n in ("lambert", "stereographic", "orthographic",
               "azimuthalequidistant", "gnomonic"):
        phi1 = phi0
        rho = np.hypot(x, y)
        with np.errstate(divide="ignore", invalid="ignore"):
            if n == "lambert":
                off = rho > 2.0
                c = 2.0 * np.arcsin(np.clip(rho / 2.0, -1.0, 1.0))
            elif n == "stereographic":
                off = np.zeros_like(rho, dtype=bool)
                c = 2.0 * np.arctan(rho / 2.0)
            elif n == "orthographic":
                off = rho > 1.0
                c = np.arcsin(np.clip(rho, -1.0, 1.0))
            elif n == "azimuthalequidistant":
                off = rho > np.pi
                c = rho.copy()
            else:
                off = np.zeros_like(rho, dtype=bool)
                c = np.arctan(rho)
        zero = rho < 1e-15
        sinc_, cosc_ = np.sin(c), np.cos(c)
        phi = np.where(zero, phi1, np.arcsin(np.clip(
            cosc_ * np.sin(phi1) + np.where(zero, 0.0, y * sinc_ * np.cos(phi1)
                                            / np.where(zero, 1.0, rho)),
            -1.0, 1.0)))
        lam = np.where(zero, 0.0, np.arctan2(
            x * sinc_,
            rho * np.cos(phi1) * cosc_ - y * np.sin(phi1) * sinc_))
        phi = np.where(off, np.nan, phi)
        lam = np.where(off, np.nan, lam)
        if not np.isnan(crs.max_c_deg):
            bad = c * R2D > crs.max_c_deg
            phi = np.where(bad, np.nan, phi)
            lam = np.where(bad, np.nan, lam)

    elif n == "polarstereographic":
        south = crs.hemisphere == "south"
        sp = crs.sp1 if not np.isnan(crs.sp1) else 90.0
        k0 = 0.5 * (1.0 + np.sin(abs(sp) * D2R))
        rho = np.hypot(x, y)
        if south:
            phi = 2.0 * np.arctan(rho / (2.0 * k0)) - 0.5 * np.pi
            lam = np.arctan2(x, y)
        else:
            phi = 0.5 * np.pi - 2.0 * np.arctan(rho / (2.0 * k0))
            lam = np.arctan2(x, -y)

    elif n == "lambertconformal":
        nn = crs.cone
        p1 = crs.sp1 * D2R
        F = (np.cos(p1) * np.tan(0.25 * np.pi + 0.5 * p1) ** nn) / nn
        rho0 = F / np.tan(0.25 * np.pi + 0.5 * phi0) ** nn
        rho = np.sign(nn) * np.hypot(x, rho0 - y)
        theta = np.arctan2(np.sign(nn) * x, np.sign(nn) * (rho0 - y))
        lam = theta / nn
        phi = 2.0 * np.arctan((F / rho) ** (1.0 / nn)) - 0.5 * np.pi

    elif n == "albers":
        nn = crs.cone
        p1 = crs.sp1 * D2R
        C = np.cos(p1) ** 2 + 2.0 * nn * np.sin(p1)
        rho0 = np.sqrt(max(C - 2.0 * nn * np.sin(phi0), 0.0)) / nn
        rho = np.hypot(x, rho0 - y)
        theta = np.arctan2(np.sign(nn) * x, np.sign(nn) * (rho0 - y))
        lam = theta / nn
        phi = np.arcsin(np.clip((C - (rho * nn) ** 2) / (2.0 * nn), -1.0, 1.0))

    else:  # pragma: no cover
        raise ValueError(n)

    lon = wrap_longitude(lam * R2D + crs.lon0, crs.lon0)
    return lon, phi * R2D


def _winkel_inverse(x, y, itmax=10, tol=1e-12):
    """2-D Newton on the Winkel Tripel forward equations."""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    phi1 = np.arccos(2.0 / np.pi)
    # Start from the equidistant-cylindrical inverse.
    lam = x / np.cos(phi1)
    phi = y.copy()
    h = 1e-8
    crs = Crs("winkeltripel")
    for _ in range(itmax):
        fx, fy = project(lam * R2D, phi * R2D, crs)
        rx, ry = fx - x, fy - y
        if np.nanmax(np.abs(rx)) < tol and np.nanmax(np.abs(ry)) < tol:
            break
        fx_l, fy_l = project((lam + h) * R2D, phi * R2D, crs)
        fx_p, fy_p = project(lam * R2D, (phi + h) * R2D, crs)
        j11, j21 = (fx_l - fx) / h, (fy_l - fy) / h
        j12, j22 = (fx_p - fx) / h, (fy_p - fy) / h
        det = j11 * j22 - j12 * j21
        det = np.where(np.abs(det) < 1e-14, np.nan, det)
        lam = lam - (j22 * rx - j12 * ry) / det
        phi = phi - (-j21 * rx + j11 * ry) / det
    # Convergence is not optional: near |lambda| = pi the Jacobian is
    # ill-conditioned and Newton wanders.  A diverged point is NaN, never a
    # plausible wrong answer (BEST_PRACTICE F1).
    fx, fy = project(lam * R2D, phi * R2D, crs)
    resid = np.maximum(np.abs(fx - x), np.abs(fy - y))
    bad = ~(resid < 1e-9)
    lam = np.where(bad, np.nan, lam)
    phi = np.where(bad, np.nan, phi)
    return lam, phi
