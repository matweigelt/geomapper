function s = scaleFactors(lon, lat, crs)
%GEO.SCALEFACTORS  Point distortion: h, k, area scale, max angular error.
%
%   SYNTAX
%     S = GEO.SCALEFACTORS(LON, LAT, CRS)
%
%   DESCRIPTION
%     Tissot's indicatrix, numerically. Powers the distortion diagnostics,
%     GEO.SCALEBAR's reported scale variation (D-006), and the equal-area
%     and conformality checks that certify GEO.PROJECT.
%
%     ONE CODE PATH FOR ALL SIXTEEN, by central differences on
%     GEO.PROJECT, rather than sixteen analytic derivations. The choice is
%     deliberate and the trade is stated: analytic derivatives would be
%     exact but would be sixteen more things to get wrong, each needing
%     its own oracle, and each silently wrong if the projection it
%     differentiates is ever changed without it. Differencing the actual
%     forward projection cannot drift from it - it IS it. Measured
%     accuracy about 1e-8, which is four decades better than any claim
%     this toolbox makes with it.
%
%     THE METRIC CORRECTION IS THE WHOLE POINT. On a sphere a degree of
%     longitude subtends cos(lat) times the distance a degree of latitude
%     does, so the longitudinal derivative is divided by cos(lat). Without
%     that division h and k are not scale factors at all; they are
%     coordinate derivatives, and every equal-area check built on them
%     would pass for the wrong reason.
%
%     h IS THE MERIDIAN SCALE and k THE PARALLEL SCALE, in Snyder's
%     notation, which is the opposite of what half the literature uses.
%
%   INPUTS
%     lon  double        Degrees East. Row/column pairs auto-meshgrid.
%     lat  double        Degrees North.
%     crs  (1,1) struct  From GEO.CRS.
%
%   OUTPUTS
%     s  (1,1) struct  Fields, each the size of the broadcast inputs:
%          h          double  Scale along the meridian.
%          k          double  Scale along the parallel.
%          AreaScale  double  Areal magnification, h*k*sin(theta').
%          OmegaDeg   double  Maximum angular deformation, degrees.
%
%   ACCURACY
%     Central differences at a step of 1e-6 degrees. Oracle O3, analytic
%     invariants, measured in the mirror and asserted in
%     TestB1_projection:
%       Mercator k = sec(lat)                  5.1e-9
%       Equal-area AreaScale = 1               <= 2.4e-8
%       Conformal h = k                        <= 9.4e-8
%       LCC k = 1 on both standard parallels   2.5e-9
%     All four sit about a decade inside the handover's 1e-6 tolerances.
%
%     TARGET-ONLY MEASUREMENT, recorded here as the rule requires: the
%     step of 1e-6 degrees was chosen by measuring the error at 1e-4,
%     1e-5, 1e-6, 1e-7 and 1e-8 on Mercator, where the truth is sec(lat)
%     in closed form. Larger steps carry truncation error; smaller ones
%     lose to cancellation in the subtraction. To re-derive it, run that
%     ladder again - do not assume this number transfers to a different
%     projection family or a different machine's arithmetic.
%
%   ERRORS
%     Input geometry:
%       geo:scaleFactors:SizeMismatch - lon and lat are neither the same
%                                       size nor a row/column pair
%
%   EXAMPLE
%     s = geo.scaleFactors(0, [0 30 60].', geo.crs("mercator"));
%     s.k ./ secd([0 30 60].')     % 1, 1, 1
%
%   LIMITATIONS
%     RETURNS NaN ON A DOMAIN BOUNDARY, and this is a design consequence
%     rather than a bug: a central difference at the edge steps outside
%     the domain, GEO.PROJECT returns NaN there, and NaN propagates. Seen
%     at Mercator lat = +/-85 (mirror limit L7). GEO.SCALEBAR's validity
%     gate therefore samples strictly INSIDE its extent and tolerates NaN
%     corners; anything that samples the boundary must do the same.
%
%   See also GEO.PROJECT, GEO.UNPROJECT, GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon double {mustBeReal}
    lat double {mustBeReal}
    crs (1,1) struct {geo.internal.mustBeCrs}
end

[lon, lat] = geo.internal.pairCoordinates(lon, lat, ...
    'geo:scaleFactors:SizeMismatch');

hStep = 1e-6;                       % degrees; see ACCURACY
d2r = pi / 180;

[xp, yp] = geo.project(lon, lat + hStep, crs);
[xm, ym] = geo.project(lon, lat - hStep, crs);
dxdphi = (xp - xm) / (2 * hStep * d2r);
dydphi = (yp - ym) / (2 * hStep * d2r);

[xp, yp] = geo.project(lon + hStep, lat, crs);
[xm, ym] = geo.project(lon - hStep, lat, crs);
coslat = cos(lat * d2r);
dxdlam = (xp - xm) / (2 * hStep * d2r) ./ coslat;
dydlam = (yp - ym) / (2 * hStep * d2r) ./ coslat;

h = hypot(dxdphi, dydphi);
k = hypot(dxdlam, dydlam);

% Area scale is the Jacobian determinant corrected by the same cos(lat)
% metric already folded into the longitudinal derivatives.
area = abs(dxdphi .* dydlam - dxdlam .* dydphi);

% Tissot: a and b are the semi-axes of the indicatrix, and omega is the
% maximum angular deformation. sin(theta') is the sine of the angle
% between the projected parametric directions.
% clampKeepingNaN, not min(max(...)). MATLAB's MIN and MAX with a scalar
% bound IGNORE NaN, so max(NaN, -1) returns -1 - and a boundary point
% whose h is already NaN would come back with a finite, entirely
% plausible OmegaDeg. Caught by the boundary test on its first run; the
% third instance of this same trap in one stage, which is why it now has
% a named helper rather than a comment.
sinTheta = clampKeepingNaN(area ./ (h .* k), -1, 1);
% Same helper again, and this is the FIFTH site in one stage where a
% clamp would otherwise turn a missing value into a plausible one. The
% radicands are clamped at zero only to absorb rounding just below it;
% they must not absorb a NaN, which is a different thing entirely.
ap = sqrt(clampKeepingNaN(h.^2 + k.^2 + 2 * h .* k .* sinTheta, 0, Inf));
bp = sqrt(clampKeepingNaN(h.^2 + k.^2 - 2 * h .* k .* sinTheta, 0, Inf));
a = (ap + bp) / 2;
b = (ap - bp) / 2;
denom = a + b;
ratio = zeros(size(a));
nz = denom ~= 0;
ratio(nz) = (a(nz) - b(nz)) ./ denom(nz);
omega = 2 * asin(clampKeepingNaN(ratio, -1, 1)) * 180 / pi;

s = struct('h', h, 'k', k, 'AreaScale', area, 'OmegaDeg', omega);
end

% ======================================================================
function v = clampKeepingNaN(v, lo, hi)
%CLAMPKEEPINGNAN  min/max that does NOT launder NaN into a bound.
%   MATLAB's MIN and MAX ignore NaN when the other argument is a scalar,
%   so max(NaN, -1) is -1. Every guard written the obvious way therefore
%   converts a missing value into a plausible one, silently. This is the
%   same trap that reached geo.project's conic radicands and its
%   azimuthal denominators in this same stage.
bad = isnan(v);
v = min(max(v, lo), hi);
v(bad) = NaN;
end
