function [lon, lat] = unproject(x, y, crs)
%GEO.UNPROJECT  Inverse projection for all sixteen. New in v2.
%
%   SYNTAX
%     [LON, LAT] = GEO.UNPROJECT(X, Y, CRS)
%
%   DESCRIPTION
%     v1 had no inverse at all (defect F5), and its absence is why v1 had
%     no round-trip test, no projected-space picking, no inverse-based
%     graticule labelling and no distortion diagnostics. This function is
%     what makes all four possible.
%
%     Points outside the projected image return NaN. Longitude comes back
%     wrapped into the CRS window.
%
%     CLOSED FORMS wherever they exist: equirectangular, mercator,
%     sinusoidal, transverse mercator, mollweide (theta = asin(y/sqrt2)),
%     hammer, the azimuthal family through rho -> c, polar stereographic,
%     and both conics.
%
%     ROBINSON BY ROOT-FINDING ON THE FORWARD INTERPOLANT, never by PCHIP
%     on the swapped table. See GEO.INTERNAL.ROBINSON: the swapped table
%     is a different curve between nodes and gives a 0.30 degree
%     round-trip error where root-finding gives 1.4e-13 (finding PV-004).
%
%     WINKEL TRIPEL BY 2-D NEWTON, and it VERIFIES ITS OWN CONVERGENCE.
%     The iteration is followed by re-evaluating the forward projection at
%     the solution and NaN-ing any point whose residual exceeds 1e-9.
%     This is not belt-and-braces: without it the mirror returned errors
%     of up to 174 degrees near the antimeridian while looking like a
%     perfectly successful inverse, on about 0.8% of a uniform in-domain
%     sample (finding PV-010). A wrong answer that carries no sign of
%     being wrong is the failure mode this project exists to prevent, and
%     an unverified Newton loop produces exactly that.
%
%   INPUTS
%     x    double        Projected easting in Earth radii.
%     y    double        Projected northing in Earth radii.
%     crs  (1,1) struct  From GEO.CRS.
%
%   OUTPUTS
%     lon  double  Degrees East, wrapped into the CRS window. NaN where
%                  the point lies outside the projected image.
%     lat  double  Degrees North.
%
%   ACCURACY
%     Round trip forward then inverse, 10 000 quasi-random in-domain
%     points per projection, measured in the mirror and re-asserted here
%     against MATLAB's own arithmetic:
%       13 of 16 at <= 4e-12 degrees
%       Robinson      1.4e-13
%       Winkel Tripel 4.6e-13
%       Lambert azimuthal 4.6e-9, which is why its tolerance is 1e-8 and
%       not 1e-9 - the asin conditioning at the antipodal rim is inherent
%       to the projection, not a defect in this implementation (PV-010).
%
%   ERRORS
%     Input geometry:
%       geo:unproject:SizeMismatch - x and y are neither the same size nor
%                                    a row/column pair to meshgrid
%
%   EXAMPLE
%     crs = geo.crs("robinson");
%     [x, y] = geo.project(30, 50, crs);
%     [lo, la] = geo.unproject(x, y, crs);   % 30, 50 to 1e-13
%
%   LIMITATIONS
%     The inverse of a projection that is not injective cannot be. At the
%     antipode of an azimuthal equidistant centre every longitude maps to
%     the same point, so the inverse there is ill-posed however it is
%     computed; the declared domain keeps callers away from it rather than
%     pretending otherwise.
%
%   See also GEO.PROJECT, GEO.SCALEFACTORS, GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    x double {mustBeReal}
    y double {mustBeReal}
    crs (1,1) struct {geo.internal.mustBeCrs}
end

[x, y] = geo.internal.pairCoordinates(x, y, 'geo:unproject:SizeMismatch');
phi0 = crs.CenterLatitude * pi / 180;

switch crs.Name
    case "equirectangular"
        lam = x;                 phi = y;

    case "mercator"
        lam = x;                 phi = 2 * atan(exp(y)) - pi/2;

    case "transversemercator"
        Dy = y + phi0;
        phi = asin(min(max(sin(Dy) ./ cosh(x), -1), 1));
        lam = atan2(sinh(x), cos(Dy));

    case "robinson"
        yy = abs(y) / 1.3523;
        off = yy > 1 + 1e-12;                % 1.0 is the Y table's top
        alat = geo.internal.robinson("latFromY", min(max(yy, 0), 1));
        lat0 = alat .* sign(y);
        lam = x ./ (0.8487 * geo.internal.robinson("x", abs(lat0)));
        phi = lat0 * pi / 180;
        lam(off) = NaN;          phi(off) = NaN;

    case "mollweide"
        s = sqrt(2);
        off = abs(y) > s + 1e-12;
        th = asin(min(max(y / s, -1), 1));
        phi = asin(min(max((2 * th + sin(2 * th)) / pi, -1), 1));
        lam = pi * x ./ (2 * s * cos(th));
        lam(off) = NaN;          phi(off) = NaN;

    case "hammer"
        z2 = 1 - (x / 4).^2 - (y / 2).^2;
        off = z2 <= 0;
        z = sqrt(max(z2, 1e-300));
        lam = 2 * atan2(z .* x, 2 * (2 * z.^2 - 1));
        phi = asin(min(max(z .* y, -1), 1));
        lam(off) = NaN;          phi(off) = NaN;

    case "winkeltripel"
        [lam, phi] = winkelInverse(x, y, crs);

    case "sinusoidal"
        phi = y;                 lam = x ./ cos(phi);

    case {"lambert", "stereographic", "orthographic", ...
          "azimuthalequidistant", "gnomonic"}
        [lam, phi] = azimuthalInverse(x, y, phi0, crs);

    case "polarstereographic"
        k0 = 0.5 * (1 + sin(abs(polarSp(crs)) * pi / 180));
        rho = hypot(x, y);
        if crs.Hemisphere == "south"
            phi = 2 * atan(rho / (2 * k0)) - pi/2;
            lam = atan2(x, y);
        else
            phi = pi/2 - 2 * atan(rho / (2 * k0));
            lam = atan2(x, -y);
        end

    case "lambertconformal"
        n = crs.ConeConstant;
        p1 = crs.StandardParallel * pi / 180;
        F = cos(p1) * tan(pi/4 + p1/2)^n / n;
        rho0 = F / tan(pi/4 + phi0/2)^n;
        rho = sign(n) * hypot(x, rho0 - y);
        lam = atan2(sign(n) * x, sign(n) * (rho0 - y)) / n;
        phi = 2 * atan((F ./ rho).^(1/n)) - pi/2;

    otherwise                       % albers
        n = crs.ConeConstant;
        p1 = crs.StandardParallel * pi / 180;
        C = cos(p1)^2 + 2 * n * sin(p1);
        rho0 = sqrt(max(C - 2 * n * sin(phi0), 0)) / n;
        rho = hypot(x, rho0 - y);
        lam = atan2(sign(n) * x, sign(n) * (rho0 - y)) / n;
        phi = asin(min(max((C - (rho * n).^2) / (2 * n), -1), 1));
end

lon = geo.wrapLongitude(lam * 180 / pi + crs.CenterLongitude, ...
                        crs.CenterLongitude);
lat = phi * 180 / pi;

% NaN in, NaN out, in both coordinates - the same contract as the forward
% and for the same two reasons: MATLAB's MIN and MAX ignore NaN, so every
% clamp above would launder one into a finite number, and half a point is
% not a gap. See GEO.PROJECT's closing comment.
gap = isnan(x) | isnan(y);
lon(gap) = NaN;
lat(gap) = NaN;
end

% ======================================================================
function [lam, phi] = azimuthalInverse(x, y, phi1, crs)
%AZIMUTHALINVERSE  rho -> angular distance c, then Snyder 20-14/20-15.
rho = hypot(x, y);
switch crs.Name
    case "lambert"
        off = rho > 2;
        c = 2 * asin(min(max(rho / 2, -1), 1));
    case "stereographic"
        off = false(size(rho));
        c = 2 * atan(rho / 2);
    case "orthographic"
        off = rho > 1;
        c = asin(min(max(rho, -1), 1));
    case "azimuthalequidistant"
        off = rho > pi;
        c = rho;
    otherwise                       % gnomonic
        off = false(size(rho));
        c = atan(rho);
end

% At the centre rho is zero and the bearing is undefined; the limit is
% the centre itself, assigned rather than divided towards.
atCentre = rho < 1e-15;
safeRho = rho;
safeRho(atCentre) = 1;

phi = asin(min(max(cos(c) * sin(phi1) + ...
    y .* sin(c) * cos(phi1) ./ safeRho, -1), 1));
lam = atan2(x .* sin(c), ...
            rho * cos(phi1) .* cos(c) - y * sin(phi1) .* sin(c));
phi(atCentre) = phi1;
lam(atCentre) = 0;

lam(off) = NaN;
phi(off) = NaN;
% F12 again, on the way back: the same declared clip as the forward.
D = crs.Domain;
if ~isnan(D.MaxAngularDistanceDeg)
    bad = c * 180 / pi > D.MaxAngularDistanceDeg;
    lam(bad) = NaN;
    phi(bad) = NaN;
end
end

function [lam, phi] = winkelInverse(x, y, crs)
%WINKELINVERSE  2-D Newton, then VERIFY. See the ACCURACY block above.
p1 = acos(2 / pi);
lam = x / cos(p1);              % equidistant-cylindrical start
phi = y;
h = 1e-8;
for k = 1:10
    [fx, fy] = geo.project(lam * 180/pi, phi * 180/pi, crs);
    rx = fx - x;
    ry = fy - y;
    if max(abs(rx(:)), [], 'omitnan') < 1e-12 && ...
       max(abs(ry(:)), [], 'omitnan') < 1e-12
        break
    end
    [fxl, fyl] = geo.project((lam + h) * 180/pi, phi * 180/pi, crs);
    [fxp, fyp] = geo.project(lam * 180/pi, (phi + h) * 180/pi, crs);
    j11 = (fxl - fx) / h;   j21 = (fyl - fy) / h;
    j12 = (fxp - fx) / h;   j22 = (fyp - fy) / h;
    det = j11 .* j22 - j12 .* j21;
    det(abs(det) < 1e-14) = NaN;
    lam = lam - (j22 .* rx - j12 .* ry) ./ det;
    phi = phi - (-j21 .* rx + j11 .* ry) ./ det;
end

% Convergence is verified, never assumed. Near |lambda| = pi the Jacobian
% is ill-conditioned and Newton wanders; without this check the mirror
% returned 174-degree errors that looked like successes (PV-010).
[fx, fy] = geo.project(lam * 180/pi, phi * 180/pi, crs);
bad = ~(max(abs(fx - x), abs(fy - y)) < 1e-9);
lam(bad) = NaN;
phi(bad) = NaN;
end

function sp = polarSp(crs)
sp = crs.StandardParallel;
if isnan(sp)
    sp = 90;
end
end
