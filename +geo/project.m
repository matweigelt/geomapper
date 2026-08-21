function [x, y] = project(lon, lat, crs, options)
%GEO.PROJECT  Forward projection, sixteen ways, NaN outside the domain.
%
%   SYNTAX
%     [X, Y] = GEO.PROJECT(LON, LAT, CRS)
%
%   DESCRIPTION
%     Ported from v1's geoProject with four mandatory repairs and one
%     addition. Output is in EARTH RADII: multiply by CRS.Radius for km.
%
%     F2, ROBINSON. The longitude difference is wrapped BEFORE the table
%     is read. v1 passed a raw LON - lon0, so longitude 359 with lon0 = 0
%     landed at x = +5.29 instead of -0.0148 - measured on the installed
%     v1, roughly two map widths out. Every other branch wrapped; the one
%     that did not was the one nobody tested at the seam.
%
%     F3, MERCATOR. Latitudes outside CRS.Domain.LatLimit return NaN. v1
%     clamped to +/-85 and drew the data at the wrong place: measured,
%     y(87) and y(85) were bit-identical, so data 222 km apart was
%     rendered on the same parallel. NaN is the toolbox-wide out-of-domain
%     contract and Mercator is not exempt from it.
%
%     F12, DOMAINS. Every clip reads CRS.Domain. There is no bare cosc
%     literal anywhere in this file, and the static audit enforces that.
%     Because Domain distinguishes the cosmetic clip from the mathematical
%     singularity (D-017), a reader can now tell which limits are physics
%     and which are taste - which was F12's actual complaint.
%
%     CONICS use CRS.ConeConstant. v1 recomputed n inside each conic
%     branch, so a change had to be made twice and was made once.
%
%     HAMMER is added as the sixteenth: the Aitoff construction with the
%     equal-area modification. It shares no code with Winkel Tripel
%     despite the family resemblance, because Aitoff-with-sqrt-2 and
%     Aitoff-averaged-with-equirectangular are different projections and
%     merging them would save four lines at the price of a subtle bug.
%
%     PORTED FAITHFULLY because the review found them correct: polar
%     stereographic in Snyder's 21-8/21-9 form with its hemisphere-
%     dependent Y sign, the shared conic scaffolding and its tangent-case
%     limit, Mollweide's Newton scheme, Winkel Tripel's phi1 = acos(2/pi)
%     and its sinc guard near alpha = 0, and NaN-as-gap throughout.
%
%   INPUTS
%     lon  double        Degrees East. A ROW vector paired with a COLUMN
%                        lat is auto-meshgridded, so a whole grid needs no
%                        NDGRID at the call site.
%     lat  double        Degrees North.
%     crs  (1,1) struct  From GEO.CRS.
%
%   OUTPUTS
%     x  double  Earth radii. NaN outside the projection's domain.
%     y  double  Earth radii. Same size as x.
%
%   ACCURACY
%     Oracle O4 (pyproj / PROJ 9.5.1) over dense in-domain samples, via
%     the mirror. Measured: 15 of 16 projections agree to <= 6e-13 in
%     projected units; Robinson agrees only to 8.9e-4 because PROJ uses a
%     different interpolant for the same table, which is recorded as
%     mirror limit L5 and is corroboration rather than a tolerance.
%     Robinson is instead asserted against its own table NODES, exactly.
%
%     Published point values, oracle O1 (Snyder 1987):
%       Mercator y(35 deg)            0.6528366
%       LCC 33/45 at (35N, 75W)       x 0.2966785, y 0.2462112
%     And the value the handover got wrong, oracle O4 (finding PV-002):
%       Polar stereographic rho(70), SP 71   0.3430474163
%     NOT 0.6116372, which matches no evaluation of any formula in either
%     the spherical or the ellipsoidal model.
%
%   ERRORS
%     Input geometry:
%       geo:project:SizeMismatch  - lon and lat are neither the same size
%                                   nor a row/column pair to meshgrid
%
%   EXAMPLE
%     crs = geo.crs("mollweide");
%     [x, y] = geo.project(-180:180, (-90:90).', crs);   % auto-meshgrid
%
%   LIMITATIONS
%     Spherical (D-001). Output is in Earth radii and carries no false
%     easting, false northing or unit scaling: this is a visualisation
%     projection, not a coordinate reference system for survey work.
%
%   See also GEO.UNPROJECT, GEO.SCALEFACTORS, GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon double {mustBeReal}
    lat double {mustBeReal}
    crs (1,1) struct {geo.internal.mustBeCrs}
    options.Window (1,1) string ...
        {mustBeMember(options.Window, ["halfopen" "closed"])} = "halfopen"
end

[lon, lat] = geo.internal.pairCoordinates(lon, lat, 'geo:project:SizeMismatch');

% F2: wrap FIRST, always, for every projection including Robinson.
% Window = "closed" is for MAP EDGES, not for data: it keeps +180 at
% +180 so a global grid's eastern rim lands on the right of the page
% rather than folding onto the left. Data keeps the half-open default,
% which is F2's fix (PV-140).
lam = geo.wrapLongitude(lon - crs.CenterLongitude, 0, ...
    Window = options.Window) * pi / 180;
phi = lat * pi / 180;
phi0 = crs.CenterLatitude * pi / 180;
D = crs.Domain;

switch crs.Name
    case "equirectangular"
        x = lam;                 y = phi;

    case "mercator"
        x = lam;                 y = log(tan(pi/4 + phi/2));

    case "transversemercator"
        B = min(max(cos(phi) .* sin(lam), -1 + 1e-15), 1 - 1e-15);
        x = 0.5 * log((1 + B) ./ (1 - B));
        y = atan2(tan(phi), cos(lam)) - phi0;
        % The singularity is a LINE, 90 degrees from the central meridian
        % along the equator - which is why Domain records the reference.
        bad = abs(B) > sin(D.MaxAngularDistanceDeg * pi / 180);
        x(bad) = NaN;            y(bad) = NaN;

    case "robinson"
        a = abs(lat);
        x = 0.8487 * lam .* geo.internal.robinson("x", a);
        y = 1.3523 * geo.internal.robinson("y", a) .* sign(lat);

    case "mollweide"
        th = geo.internal.mollweideTheta(phi);
        x = (2 * sqrt(2) / pi) * lam .* cos(th);
        y = sqrt(2) * sin(th);

    case "hammer"
        d = sqrt(1 + cos(phi) .* cos(lam / 2));
        x = 2 * sqrt(2) * cos(phi) .* sin(lam / 2) ./ d;
        y = sqrt(2) * sin(phi) ./ d;

    case "winkeltripel"
        p1 = acos(2 / pi);
        alph = acos(min(max(cos(phi) .* cos(lam / 2), -1), 1));
        sc = ones(size(alph));
        far = abs(alph) >= 1e-12;
        sc(far) = sin(alph(far)) ./ alph(far);
        x = 0.5 * (lam * cos(p1) + 2 * cos(phi) .* sin(lam / 2) ./ sc);
        y = 0.5 * (phi + sin(phi) ./ sc);

    case "sinusoidal"
        x = lam .* cos(phi);     y = phi;

    case {"lambert", "stereographic", "orthographic", ...
          "azimuthalequidistant", "gnomonic"}
        [x, y] = azimuthal(lam, phi, phi0, crs.Name, D);

    case "polarstereographic"
        k0 = polarK0(crs);
        if crs.Hemisphere == "south"
            rho = 2 * k0 * tan(pi/4 + phi/2);
            x = rho .* sin(lam);     y = rho .* cos(lam);
        else
            rho = 2 * k0 * tan(pi/4 - phi/2);
            x = rho .* sin(lam);     y = -rho .* cos(lam);
        end

    case "lambertconformal"
        n = crs.ConeConstant;
        F = coneF(crs);
        rho = F ./ tan(pi/4 + phi/2).^n;
        rho0 = F ./ tan(pi/4 + phi0/2).^n;
        x = rho .* sin(n * lam);
        y = rho0 - rho .* cos(n * lam);

    otherwise                       % albers
        n = crs.ConeConstant;
        C = coneC(crs);
        rho = sqrt(max(C - 2 * n * sin(phi), 0)) / n;
        rho0 = sqrt(max(C - 2 * n * sin(phi0), 0)) / n;
        x = rho .* sin(n * lam);
        y = rho0 - rho .* cos(n * lam);
end

% F3: the latitude limit is the domain's, and it applies to every
% projection. Mercator is the one that has one; it is not special-cased.
outside = lat < D.LatLimit(1) | lat > D.LatLimit(2);
x(outside) = NaN;
y(outside) = NaN;

% NaN IN, NaN OUT, IN BOTH COORDINATES. Two reasons this is explicit
% rather than left to the arithmetic.
%
% First, MATLAB's MIN and MAX with a scalar bound IGNORE NaN:
% max(NaN, 0) returns 0. Every clamp in this file - the conic radicands,
% the azimuthal denominators, the acos guards - therefore launders a NaN
% into a finite number, and the projection would return a plausible
% coordinate for a point that does not exist. That is the exact failure
% class this project is built against.
%
% Second, several projections make one coordinate independent of one
% input: Mollweide's y and Robinson's y depend only on latitude, so a NaN
% LONGITUDE would otherwise yield a finite y beside a NaN x. Half a point
% is not a gap, and a consumer that tests only one coordinate would draw
% it. NaN-as-gap means both.
gap = isnan(lon) | isnan(lat);
x(gap) = NaN;
y(gap) = NaN;
end

% ======================================================================
function [x, y] = azimuthal(lam, phi, phi1, name, D)
%AZIMUTHAL  The five oblique azimuthals share everything but their radius.
cosc = min(max(sin(phi1) .* sin(phi) + ...
               cos(phi1) .* cos(phi) .* cos(lam), -1), 1);
switch name
    case "lambert"
        kp = sqrt(2 ./ max(1 + cosc, 1e-15));
    case "stereographic"
        kp = 2 ./ max(1 + cosc, 1e-15);
    case "orthographic"
        kp = ones(size(cosc));
    case "azimuthalequidistant"
        c = acos(cosc);
        kp = ones(size(c));
        far = abs(sin(c)) >= 1e-15;
        kp(far) = c(far) ./ sin(c(far));
    otherwise                       % gnomonic
        kp = 1 ./ cosc;
        kp(abs(cosc) < 1e-15) = NaN;
end
x = kp .* cos(phi) .* sin(lam);
y = kp .* (cos(phi1) .* sin(phi) - sin(phi1) .* cos(phi) .* cos(lam));

% F12: the clip is read from the declared domain, never from a literal.
if ~isnan(D.MaxAngularDistanceDeg)
    bad = acos(cosc) * 180 / pi > D.MaxAngularDistanceDeg;
    x(bad) = NaN;
    y(bad) = NaN;
end
end

function k0 = polarK0(crs)
%POLARK0  Snyder 21-8: scale at the pole for a given true-scale parallel.
sp = crs.StandardParallel;
if isnan(sp)
    sp = 90;
end
k0 = 0.5 * (1 + sin(abs(sp) * pi / 180));
end

function F = coneF(crs)
%CONEF  Lambert conformal conic constant of the cone, Snyder 15-2.
p1 = crs.StandardParallel * pi / 180;
n = crs.ConeConstant;
F = cos(p1) * tan(pi/4 + p1/2)^n / n;
end

function C = coneC(crs)
%CONEC  Albers constant of the cone, Snyder 14-3.
p1 = crs.StandardParallel * pi / 180;
n = crs.ConeConstant;
C = cos(p1)^2 + 2 * n * sin(p1);
end
