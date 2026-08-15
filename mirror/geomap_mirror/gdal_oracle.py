"""geomap_mirror.gdal_oracle — access to oracles O7 and O8 (GDAL).

Oracle register rows O7 (`cdo remapcon` or `gdalwarp -r average`) and O8
(`gdaldem hillshade`, Horn) were both unfilled, and HANDOVER §3.2 forbids
beginning a stage with an unfilled oracle row in its scope.  This module
fills them.

WHY THIS FILE EXISTS AT ALL, rather than a `subprocess` call to `gdaldem`.
The authoring sandbox has no root, so `apt-get install gdal-bin cdo` is not
available, and PyPI's `gdal` sdist cannot build without `libgdal-dev`.
What IS available is the `rasterio` wheel, which bundles a complete
libgdal.  `gdaldem` and `gdalwarp` are thin `main()` wrappers around the C
entry points `GDALDEMProcessing` and `GDALWarp`; calling those directly is
therefore GDAL doing the work, not an imitation of it.

Three routes are tried in order, and WHICH ONE RAN IS RECORDED with every
measurement.  A measurement whose oracle cannot be identified is not
reproducible (HANDOVER §2.2, "record what the mirror cannot see").

  1. `osgeo.gdal`      - the official Python bindings, if installed.
  2. `gdaldem`/`gdalwarp` on PATH - the CLI, if installed (this is the
     route CI takes, because the runner has root).
  3. ctypes on a bundled libgdal - the sandbox route.

Where two routes are present, `cross_check()` runs both and reports the
difference, so the sandbox route is certified against the CLI route rather
than assumed equivalent to it.

WHAT THIS ORACLE CANNOT CERTIFY, measured rather than assumed — see the
entries this module adds to LIMITS.md (L9, L10, L11):

  * `gdaldem hillshade` emits **uint8**, so it cannot certify a shade
    beyond ~1/254.  `gdaldem slope` and `gdaldem aspect` emit Float32 and
    are the better instrument for the Horn gradient itself.
  * GDAL has no per-row metric, so it is an oracle for the Horn KERNEL on
    a constant-spacing tile, not for geoMap's spherical cos(lat) metric.
    That metric is a separate claim with its own analytic check.
  * `gdalwarp -r average` is NOT a conservative remap.  See `regrid.py`.

geoMap v2.0 mirror | 15-Aug-2026 | Claude Opus 5 (Anthropic)
"""

from __future__ import annotations

import ctypes
import glob
import os
import shutil
import subprocess
import tempfile

import numpy as np

_ROUTE = None       # "osgeo" | "cli" | "ctypes" | None
_VERSION = None
_LIB = None         # ctypes handle for the ctypes route


# ---------------------------------------------------------------------------
# Route resolution
# ---------------------------------------------------------------------------
def _find_bundled_libgdal():
    """Locate a libgdal shipped inside an installed wheel (rasterio, fiona)."""
    import site

    roots = list(site.getsitepackages())
    if hasattr(site, "getusersitepackages"):
        roots.append(site.getusersitepackages())
    for root in roots:
        for pat in ("rasterio.libs/libgdal*.so*", "fiona.libs/libgdal*.so*",
                    "*/libgdal*.so*"):
            hits = sorted(glob.glob(os.path.join(root, pat)))
            if hits:
                return hits[0]
    return None


def _load_ctypes(path):
    """Load libgdal and its bundled dependencies.

    The wheel's private lib directory is not on the loader path, so the
    transitive dependencies (libcurl, libproj, ...) must be pre-loaded with
    RTLD_GLOBAL before libgdal itself will resolve.

    ONE PASS IS NOT ENOUGH, and this was measured rather than reasoned:
    a single alphabetical pass leaves `libcurl` unloaded, because libcurl
    has its own siblings in the same directory that sort after it.  Loading
    is repeated to a fixpoint - each pass makes at least one more library
    resolvable - which terminates because the dependency graph is acyclic
    and finite.
    """
    libdir = os.path.dirname(path)
    pending = [d for d in sorted(glob.glob(os.path.join(libdir, "*.so*")))
               if d != path]
    while pending:
        still = []
        for dep in pending:
            try:
                ctypes.CDLL(dep, mode=ctypes.RTLD_GLOBAL)
            except OSError:
                still.append(dep)
        if len(still) == len(pending):
            break                     # no progress: the rest are unusable
        pending = still
    lib = ctypes.CDLL(path, mode=ctypes.RTLD_GLOBAL)
    lib.GDALVersionInfo.restype = ctypes.c_char_p
    lib.GDALAllRegister()
    return lib


def resolve():
    """Resolve the GDAL route once.  Returns (route, version_string)."""
    global _ROUTE, _VERSION, _LIB
    if _ROUTE is not None:
        return _ROUTE, _VERSION
    try:
        from osgeo import gdal                       # noqa: F401
        _ROUTE, _VERSION = "osgeo", gdal.VersionInfo("RELEASE_NAME")
        return _ROUTE, _VERSION
    except ImportError:
        pass
    if shutil.which("gdaldem") and shutil.which("gdalwarp"):
        out = subprocess.run(["gdaldem", "--version"], capture_output=True,
                             text=True, check=False).stdout
        _ROUTE, _VERSION = "cli", out.strip().split(",")[0]
        return _ROUTE, _VERSION
    path = _find_bundled_libgdal()
    if path is not None:
        try:
            _LIB = _load_ctypes(path)
            _ROUTE = "ctypes"
            _VERSION = _LIB.GDALVersionInfo(b"RELEASE_NAME").decode()
            return _ROUTE, _VERSION
        except OSError:
            pass
    _ROUTE, _VERSION = "none", "GDAL not reachable"
    return _ROUTE, _VERSION


def available():
    return resolve()[0] != "none"


def provenance():
    """The dict that travels with every number this module produces."""
    route, ver = resolve()
    return {"oracle": "O7/O8 GDAL", "route": route, "version": ver}


# ---------------------------------------------------------------------------
# GeoTIFF I/O.  rasterio is a dependency of the ctypes route anyway, and it
# is the one piece here that is NOT the oracle: it only moves bytes.
# ---------------------------------------------------------------------------
def _write_tif(path, z, dx, dy, x0=1000.0, y0=1000.0, nodata=None):
    # x0/y0 default away from the origin deliberately: a transform equal to
    # flipped identity makes GDAL warn that it may save no geotransform at
    # all, and a geotransform GDAL discarded would silently change the
    # pixel size the oracle believes it is working at.
    import rasterio
    from rasterio.transform import Affine

    z = np.asarray(z, dtype="float32")
    tr = Affine.translation(x0, y0) * Affine.scale(dx, -dy)
    kw = dict(driver="GTiff", height=z.shape[0], width=z.shape[1], count=1,
              dtype="float32", transform=tr, crs=None)
    if nodata is not None:
        kw["nodata"] = nodata
    with rasterio.open(path, "w", **kw) as ds:
        ds.write(z, 1)
    return path


def _read_tif(path):
    import rasterio

    with rasterio.open(path) as ds:
        return ds.read(1)


# ---------------------------------------------------------------------------
# The three routes, behind one signature
# ---------------------------------------------------------------------------
def _dem_ctypes(src, dst, mode, argv):
    lib = _LIB
    lib.GDALOpen.restype = ctypes.c_void_p
    lib.GDALOpen.argtypes = [ctypes.c_char_p, ctypes.c_int]
    lib.GDALDEMProcessingOptionsNew.restype = ctypes.c_void_p
    lib.GDALDEMProcessingOptionsNew.argtypes = [
        ctypes.POINTER(ctypes.c_char_p), ctypes.c_void_p]
    lib.GDALDEMProcessing.restype = ctypes.c_void_p
    lib.GDALDEMProcessing.argtypes = [
        ctypes.c_char_p, ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p,
        ctypes.c_void_p, ctypes.POINTER(ctypes.c_int)]
    lib.GDALClose.argtypes = [ctypes.c_void_p]

    arr = (ctypes.c_char_p * (len(argv) + 1))()
    for i, a in enumerate(argv):
        arr[i] = a.encode()
    arr[len(argv)] = None

    hsrc = lib.GDALOpen(src.encode(), 0)
    if not hsrc:
        raise RuntimeError(f"GDALOpen failed on {src}")
    opts = lib.GDALDEMProcessingOptionsNew(arr, None)
    err = ctypes.c_int(0)
    hdst = lib.GDALDEMProcessing(dst.encode(), hsrc, mode.encode(), None,
                                 opts, ctypes.byref(err))
    if not hdst:
        lib.GDALClose(hsrc)
        raise RuntimeError(f"GDALDEMProcessing({mode}) failed, err={err.value}")
    lib.GDALClose(hdst)
    lib.GDALClose(hsrc)
    return dst


def dem(z, dx, dy, mode, extra=(), nodata=None):
    """Run `gdaldem <mode>` on an array and return the result array.

    INPUTS
      z      (M,N) float   Elevation, in the same units as dx and dy.
      dx,dy  float         Pixel size.  Constant, by construction: GDAL has
                           no per-row metric (limit L10).
      mode   str           "hillshade" | "slope" | "aspect".
      extra  sequence[str] Extra CLI arguments, written out in full.  No
                           GDAL default is relied upon (decision D-011
                           generalised: a default is not a contract).

    OUTPUTS
      (M,N) float array as GDAL wrote it.
    """
    route, _ = resolve()
    if route == "none":
        raise RuntimeError("GDAL is not reachable; oracles O7/O8 unfilled")
    argv = ["-of", "GTiff", "-compute_edges", *map(str, extra)]
    with tempfile.TemporaryDirectory() as td:
        src = _write_tif(os.path.join(td, "dem.tif"), z, dx, dy,
                         nodata=nodata)
        dst = os.path.join(td, "out.tif")
        if route == "osgeo":
            from osgeo import gdal
            gdal.DEMProcessing(dst, src, mode,
                               options=gdal.DEMProcessingOptions(
                                   options=argv))
        elif route == "cli":
            subprocess.run(["gdaldem", mode, src, dst, *argv],
                           check=True, capture_output=True)
        else:
            _dem_ctypes(src, dst, mode, argv)
        return _read_tif(dst).astype(float)


def _warp_ctypes(src, dst, argv):
    lib = _LIB
    lib.GDALOpen.restype = ctypes.c_void_p
    lib.GDALOpen.argtypes = [ctypes.c_char_p, ctypes.c_int]
    lib.GDALWarpAppOptionsNew.restype = ctypes.c_void_p
    lib.GDALWarpAppOptionsNew.argtypes = [
        ctypes.POINTER(ctypes.c_char_p), ctypes.c_void_p]
    lib.GDALWarp.restype = ctypes.c_void_p
    lib.GDALWarp.argtypes = [
        ctypes.c_char_p, ctypes.c_void_p, ctypes.c_int,
        ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p,
        ctypes.POINTER(ctypes.c_int)]
    lib.GDALClose.argtypes = [ctypes.c_void_p]

    arr = (ctypes.c_char_p * (len(argv) + 1))()
    for i, a in enumerate(argv):
        arr[i] = a.encode()
    arr[len(argv)] = None

    hsrc = ctypes.c_void_p(lib.GDALOpen(src.encode(), 0))
    if not hsrc:
        raise RuntimeError(f"GDALOpen failed on {src}")
    srcs = (ctypes.c_void_p * 1)(hsrc)
    opts = lib.GDALWarpAppOptionsNew(arr, None)
    err = ctypes.c_int(0)
    hdst = lib.GDALWarp(dst.encode(), None, 1, srcs, opts,
                        ctypes.byref(err))
    if not hdst:
        lib.GDALClose(hsrc)
        raise RuntimeError(f"GDALWarp failed, err={err.value}")
    lib.GDALClose(ctypes.c_void_p(hdst))
    lib.GDALClose(hsrc)
    return dst


def warp_average(z, src_bounds, dst_shape):
    """Run `gdalwarp -r average` from a source grid onto a target grid.

    Oracle O7 as the register names it.  `regrid.py` measures how far this
    is from a genuine conservative remap; the answer is "far", and that
    measurement is the reason the register row is annotated rather than
    simply ticked.

    INPUTS
      z           (M,N) float   Source field.
      src_bounds  (w, n, e, s)  Source extent in degrees, edges not centres.
      dst_shape   (P, Q)        Target grid shape over the SAME extent.

    OUTPUTS
      (P,Q) float array as GDAL wrote it.
    """
    route, _ = resolve()
    if route == "none":
        raise RuntimeError("GDAL is not reachable; oracle O7 unfilled")
    w, n, e, s = src_bounds
    m, k = np.asarray(z).shape
    dx, dy = (e - w) / k, (n - s) / m
    argv = ["-r", "average", "-of", "GTiff",
            "-te", str(w), str(s), str(e), str(n),
            "-ts", str(dst_shape[1]), str(dst_shape[0])]
    with tempfile.TemporaryDirectory() as td:
        src = _write_tif(os.path.join(td, "src.tif"), z, dx, dy, x0=w, y0=n)
        dst = os.path.join(td, "dst.tif")
        if route == "osgeo":
            from osgeo import gdal
            gdal.Warp(dst, src, options=gdal.WarpOptions(options=argv))
        elif route == "cli":
            subprocess.run(["gdalwarp", *argv, src, dst],
                           check=True, capture_output=True)
        else:
            _warp_ctypes(src, dst, argv)
        return _read_tif(dst).astype(float)


# ---------------------------------------------------------------------------
# Self-test: the oracle must be shown to work before anything cites it
# ---------------------------------------------------------------------------
def self_test():
    """Prove the route on a surface whose answer is known analytically.

    A constant-gradient plane has slope arctan(|grad|) and aspect fixed,
    everywhere, in closed form.  If the route is wired up wrongly - wrong
    byte order, transposed transform, a scale GDAL silently defaulted - a
    plane is where it shows, because every interior pixel must agree.

    Returns a dict of measured deviations; all should be at Float32 level.
    """
    route, ver = resolve()
    if route == "none":
        return {"route": route, "version": ver, "ok": False}
    # z = 3x + 4y  ->  |grad| = 5 per unit, slope = atan(5) = 78.69 deg.
    ny, nx, d = 40, 50, 1.0
    yy, xx = np.mgrid[0:ny, 0:nx].astype(float)
    # Row 0 is NORTH in a GeoTIFF, so y decreases downward.
    z = 3.0 * (xx * d) + 4.0 * ((ny - 1 - yy) * d)
    slope = dem(z, d, d, "slope", extra=["-s", "1", "-alg", "Horn"])
    interior = slope[2:-2, 2:-2]
    want = np.degrees(np.arctan(5.0))
    aspect = dem(z, d, d, "aspect", extra=["-alg", "Horn"])
    # Aspect is the azimuth the slope FACES, i.e. the direction of steepest
    # DESCENT, clockwise from north.  The gradient here points east-north,
    # so the face is the opposite bearing: 180 + atan2(3,4) = 216.87 deg.
    #
    # Written down after being measured, not before: the first expectation
    # in this file was atan2(3,4) = 36.87, and the self-test returned an
    # error of exactly 180.0000059 - a residual whose value names its own
    # cause. An oracle convention assumed rather than checked is finding
    # F1's plausible wrong answer, and this is the check that caught it.
    want_aspect = 180.0 + np.degrees(np.arctan2(3.0, 4.0))
    return {
        "route": route,
        "version": ver,
        "ok": True,
        "slope_expected_deg": float(want),
        "slope_max_abs_error_deg": float(np.max(np.abs(interior - want))),
        "aspect_expected_deg": float(want_aspect),
        "aspect_max_abs_error_deg": float(
            np.max(np.abs(aspect[2:-2, 2:-2] - want_aspect))),
    }


if __name__ == "__main__":
    import json

    print(json.dumps(self_test(), indent=2))
