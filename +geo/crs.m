function c = crs(name, options)
%GEO.CRS  Validated projection spec with a queryable domain.
%
%   SYNTAX
%     C = GEO.CRS(NAME)
%     C = GEO.CRS(NAME, Name, Value)
%
%   DESCRIPTION
%     Builds the one struct that carries all projection state. Every later
%     layer reads it and nothing re-derives it: forward projection, inverse
%     projection, scale factors, domain clipping and the graticule all take
%     their parameters from here.
%
%     WHY A STRUCT AND NOT A CLASSDEF (decision D-002). Save and load are
%     trivial, arrays of them are idiomatic, and there are no copy-semantics
%     surprises for numerical users. The trade is that nothing stops a caller
%     assigning a field by hand; GEO.INTERNAL.MUSTBECRS exists so that every
%     consumer at least checks it was built here. Revisit if these structs
%     ever acquire behaviour rather than just fields.
%
%     WHY THE CONE CONSTANT IS COMPUTED HERE. v1 recomputed it inside each
%     conic branch of the projection, so a change had to be made twice and
%     was made once. It is computed exactly once, in this function.
%
%     THE DOMAIN, AND WHY IT HAS TWO NUMBERS RATHER THAN ONE. Defect F12
%     was not that v1 clipped - it is that v1's literals (cosc < -0.9,
%     cosc < 0.1, cosc < -0.9994) served simultaneously as a mathematical
%     guard and a cosmetic clip, and nothing said which was which.
%     Declaring the same rounded numbers in a tidier struct would have
%     reproduced that defect with better manners. So DOMAIN carries both:
%
%       MaxAngularDistanceDeg  what geo.project actually clips at
%       SingularityDeg         where the mathematics genuinely fails
%       ClipIsCosmetic         true when the two differ
%
%     Measured (mirror `stage_a.check_declared_domains`, finding PV-038):
%     of the four clipped projections only ORTHOGRAPHIC has a clip that is
%     the singularity. Gnomonic is clipped 6 degrees inside a divergence
%     at 90; stereographic 26 degrees inside a singularity at 180; and
%     azimuthal equidistant has no forward singularity at all - its 178 is
%     a conditioning guard for the inverse, where the antipode maps to a
%     whole circle.
%
%     The clip VALUES are v1's, deliberately: keeping them means a v2
%     figure covers the same extent as the v1 figure it replaces, and no
%     existing plot silently changes. They are inherited cosmetic choices,
%     recorded as such rather than presented as derivations. v1's literals
%     in degrees are 154.158, 84.261, 178.015 and 90.000; the declared
%     values round each one INWARD.
%
%   INPUTS
%     name  (1,1) string  One of the sixteen supported projections:
%                         equirectangular, mercator, transversemercator,
%                         robinson, mollweide, hammer, winkeltripel,
%                         sinusoidal, lambert, stereographic, orthographic,
%                         azimuthalequidistant, gnomonic,
%                         polarstereographic, lambertconformal, albers.
%
%   OPTIONS
%     CenterLongitude    (1,1) double  [0]         Degrees East.
%     CenterLatitude     (1,1) double  [NaN]       Degrees North; NaN
%                                                  resolves per class.
%     Hemisphere         (1,1) string  ["north"]   "north" | "south";
%                                                  polar stereographic only.
%     StandardParallel   (1,1) double  [NaN]       Degrees; conics and
%                                                  polar stereographic.
%     StandardParallel2  (1,1) double  [NaN]       Degrees; conics. NaN
%                                                  means the tangent case.
%     Radius             (1,1) double  [6371.0072] km, authalic (D-001).
%
%   OUTPUTS
%     c  (1,1) struct  Fields:
%          Identity          (1,1) string   Always "geo.crs".
%          Name              (1,1) string   As validated.
%          CenterLongitude   (1,1) double   Degrees East.
%          CenterLatitude    (1,1) double   Degrees North, resolved.
%          Hemisphere        (1,1) string   "north" | "south".
%          StandardParallel  (1,1) double   Degrees, NaN if unused.
%          StandardParallel2 (1,1) double   Degrees, NaN if unused.
%          Radius            (1,1) double   km.
%          ConeConstant      (1,1) double   NaN unless conic.
%          Class             (1,1) string   "cylindrical" |
%                                           "pseudocylindrical" |
%                                           "azimuthal" | "conic".
%          IsWholeWorld      (1,1) logical  True if the whole sphere maps
%                                           to a bounded image.
%          Domain            (1,1) struct   Fields:
%            MaxAngularDistanceDeg   (1,1) double  Clip; NaN unlimited.
%            MaxAngularDistanceFrom  (1,1) string  "centre" |
%                                                  "centralMeridian" |
%                                                  "none".
%            SingularityDeg          (1,1) double  NaN if none.
%            ClipIsCosmetic          (1,1) logical
%            LatLimit                (1,2) double  Degrees, inclusive.
%
%   ACCURACY
%     Cone constants, oracle O4 (pyproj/PROJ) and O3 (analytic), values
%     from mirror/geomap_mirror/out/reference_values.json:
%       LCC 33/45      n = 0.6304776973 (spherical). NOT 0.6304962, which
%                      is the ELLIPSOIDAL Clarke-1866 value for a model
%                      geoMap does not use - finding PV-011, and the purest
%                      example in this project of a real number from the
%                      wrong world.
%       Albers 29.5/45.5 recorded in the same file.
%     Degeneracy is EXACT, not approximate (mirror, finding PV-039):
%     p1 = -p2 gives n identically 0 for both conics, at every pair
%     measured. LCC returns negative zero; -0 == 0 in MATLAB, so the guard
%     below reads |n| and is insensitive to the sign.
%
%   ERRORS
%     Projection identity:
%       geo:crs:UnknownProjection    - name is not one of the sixteen
%     Conic parameters:
%       geo:crs:MissingParallel      - a conic without StandardParallel
%       geo:crs:DegenerateConic      - |cone constant| < 1e-12, i.e. the
%                                      cone has opened into a plane
%     Domain parameters:
%       geo:crs:BadStandardParallel  - a standard parallel outside
%                                      (-90, 90), where cos or tan is
%                                      singular
%       geo:crs:PolarParallelSign    - polar stereographic standard
%                                      parallel in the wrong hemisphere
%
%   EXAMPLE
%     c = geo.crs("mollweide", CenterLongitude = 0);
%     c = geo.crs("lambertconformal", CenterLongitude = -96, ...
%                 CenterLatitude = 23, StandardParallel = 33, ...
%                 StandardParallel2 = 45);
%     c.Domain.ClipIsCosmetic
%
%   LIMITATIONS
%     Spherical only (D-001), authalic radius. Geometric error against a
%     WGS84 ellipsoid is at most about 0.3%, measured at -0.268% on the
%     Paris-New York great circle - invisible at figure scale and quite
%     unsuitable for survey work. This is a visualisation tool.
%
%   See also GEO.WRAPLONGITUDE, GEO.SPLITANTIMERIDIAN,
%   GEO.INTERNAL.MUSTBECRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    name (1,1) string
    options.CenterLongitude (1,1) double {mustBeReal, mustBeFinite} = 0
    options.CenterLatitude (1,1) double {mustBeReal} = NaN
    options.Hemisphere (1,1) string ...
        {mustBeMember(options.Hemisphere, ["north" "south"])} = "north"
    options.StandardParallel (1,1) double {mustBeReal} = NaN
    options.StandardParallel2 (1,1) double {mustBeReal} = NaN
    options.Radius (1,1) double {mustBeReal, mustBePositive} = 6371.0072
end

name = lower(strtrim(name));
if ~any(name == geo.internal.projectionNames())
    error('geo:crs:UnknownProjection', ...
        ['"%s" is not a supported projection. The sixteen are: %s.'], ...
        name, strjoin(geo.internal.projectionNames(), ', '));
end

cls = classOf(name);

% --- standard parallels ---------------------------------------------
sp1 = options.StandardParallel;
sp2 = options.StandardParallel2;
for p = [sp1 sp2]
    if ~isnan(p) && abs(p) >= 90
        error('geo:crs:BadStandardParallel', ...
            ['Standard parallel %g is at or beyond a pole. cos and tan ' ...
             'are singular there, so no cone or scale factor exists. ' ...
             'Use a parallel strictly inside (-90, 90).'], p);
    end
end

if cls == "conic" && isnan(sp1)
    error('geo:crs:MissingParallel', ...
        ['%s is a conic and needs at least StandardParallel. With one ' ...
         'parallel the cone is tangent; with two it is secant.'], name);
end

if name == "polarstereographic"
    if isnan(sp1)
        sp1 = 90 * hemiSign(options.Hemisphere);
    elseif sign(sp1) ~= hemiSign(options.Hemisphere) && sp1 ~= 0
        error('geo:crs:PolarParallelSign', ...
            ['Hemisphere is "%s" but StandardParallel is %g. A polar ' ...
             'stereographic true-scale parallel lies in the hemisphere ' ...
             'being mapped; the mismatch is almost always a dropped ' ...
             'minus sign rather than an intention.'], ...
            options.Hemisphere, sp1);
    end
end

% --- cone constant, computed exactly once ----------------------------
n = NaN;
if cls == "conic"
    n = coneConstant(name, sp1, sp2);
    if abs(n) < 1e-12
        error('geo:crs:DegenerateConic', ...
            ['Standard parallels %g and %g give a cone constant of %g. ' ...
             'Symmetric parallels open the cone into a plane, where the ' ...
             'projection is undefined. This is exact rather than ' ...
             'approximate: p1 = -p2 gives identically zero.'], ...
            sp1, sp2, n);
    end
end

% --- centre latitude, resolved per class -----------------------------
lat0 = options.CenterLatitude;
if isnan(lat0)
    switch name
        case "polarstereographic"
            lat0 = 90 * hemiSign(options.Hemisphere);
        otherwise
            % Cylindrical, pseudocylindrical, azimuthal and conic all
            % default to the equator. Stated rather than assumed: an
            % azimuthal centred on the equator is a legitimate default,
            % not a placeholder.
            lat0 = 0;
    end
end

c = struct( ...
    'Identity', "geo.crs", ...
    'Name', name, ...
    'CenterLongitude', options.CenterLongitude, ...
    'CenterLatitude', lat0, ...
    'Hemisphere', options.Hemisphere, ...
    'StandardParallel', sp1, ...
    'StandardParallel2', sp2, ...
    'Radius', options.Radius, ...
    'ConeConstant', n, ...
    'Class', cls, ...
    'IsWholeWorld', isWholeWorld(name), ...
    'Domain', domainOf(name, options.Hemisphere, n));
end

% ======================================================================
function cls = classOf(name)
%CLASSOF  The four families, one authority.
%   Hammer and Winkel Tripel are modified azimuthals by construction and
%   pseudocylindrical in use and in shape; they are filed with the
%   pseudocylindricals because that is the grouping every consumer needs
%   (the global equal-area integral, the whole-world flag, the graticule
%   densification), and the handover's Stage B accuracy table groups them
%   the same way.
%
%   CELL arrays in the case labels, not string arrays. MATLAB's SWITCH
%   treats a cell as a list of alternatives and a string ARRAY as a single
%   value to compare against, so `case ["a" "b"]` matches nothing and
%   falls silently through to OTHERWISE. Measured on the first run: every
%   conic was classified "azimuthal", its cone constant was therefore
%   never computed, and geo.crs("lambertconformal", ...) returned
%   ConeConstant = NaN without complaint.
switch name
    case {"equirectangular", "mercator", "transversemercator"}
        cls = "cylindrical";
    case {"robinson", "mollweide", "hammer", "winkeltripel", "sinusoidal"}
        cls = "pseudocylindrical";
    case {"lambertconformal", "albers"}
        cls = "conic";
    otherwise
        cls = "azimuthal";
end
end

function tf = isWholeWorld(name)
%ISWHOLEWORLD  Does the entire sphere map to a bounded image?
%   Mercator is excluded although it is a whole-world projection in
%   common speech: its poles are at infinity, which is why it needs a
%   latitude limit at all.
tf = any(name == ["equirectangular" "robinson" "mollweide" "hammer" ...
                  "winkeltripel" "sinusoidal"]);
end

function d = domainOf(name, hemisphere, coneN)
%DOMAINOF  The single authority for every projection limit (F12).
%
%   The four clip values are v1's, in degrees, rounded inward from the
%   angle its cos-threshold actually meant. Kept deliberately so a v2
%   figure covers the same extent as the v1 figure it replaces.
%
%   THREE OF THESE DOMAINS DEPEND ON A PARAMETER, NOT ONLY ON THE NAME,
%   and the first version of this table did not, which is why it takes
%   three arguments now. Polar stereographic diverges at the pole
%   OPPOSITE its own, so north and south have mirror-image domains; a
%   conformal conic diverges at whichever pole its cone does not wrap,
%   which is decided by the SIGN OF THE CONE CONSTANT and therefore by
%   the standard parallels the caller chose. A table keyed on the name
%   alone cannot express any of that, and silently returned [-90 90].
%
%   WHAT THAT COST, MEASURED. `geo.project(0, -90, polarstereographic
%   north)` returned 3.266e+16 - not NaN, not an error, a finite number.
%   Drawn, it set the axis limits to 3e16 and the map became one pixel.
%   Lambert conformal was subtler and worse: its longest projected
%   graticule segment GREW with sampling, 7.1 at 64 points to 98.6 at
%   4096, because a finer sample lands closer to the pole it diverges
%   at. Anything that refines until a length criterion is met would
%   never terminate.
%
%   The clip is set five degrees short of the divergence, which is the
%   margin Mercator already used for the same reason. It is cosmetic:
%   the mathematics is fine right up to the pole, and nobody draws a
%   polar stereographic map of the far hemisphere.
maxDist = NaN;
distFrom = "none";
singular = NaN;
latLim = [-90 90];

switch name
    case "stereographic"
        maxDist = 154;      distFrom = "centre";    singular = 180;
    case "gnomonic"
        maxDist = 84;       distFrom = "centre";    singular = 90;
    case "azimuthalequidistant"
        maxDist = 178;      distFrom = "centre";    singular = NaN;
    case "orthographic"
        maxDist = 90;       distFrom = "centre";    singular = 90;
    case "lambert"
        % Lambert azimuthal equal-area is defined everywhere including
        % the antipode; only the INVERSE is ill-conditioned there, which
        % is why its round-trip tolerance is 1e-8 and not 1e-9 (PV-010).
        maxDist = NaN;      distFrom = "none";      singular = NaN;
    case "transversemercator"
        % Distance from the central meridian's great circle, not from a
        % point: the singularity is a line, 90 degrees away, where the
        % cylinder's seam runs.
        maxDist = 89.5;     distFrom = "centralMeridian";  singular = 90;
    case "mercator"
        latLim = [-85 85];  singular = 90;
    case "polarstereographic"
        singular = 90;
        latLim = farPoleClip(hemisphere == "north");
    case "lambertconformal"
        % Albers is NOT here on purpose: its rho is bounded at both
        % poles - it is an equal-area conic - so it has no singularity
        % to clip and adding one would remove map for no reason.
        singular = 90;
        latLim = farPoleClip(coneN > 0);
end

d = struct( ...
    'MaxAngularDistanceDeg', maxDist, ...
    'MaxAngularDistanceFrom', distFrom, ...
    'SingularityDeg', singular, ...
    'ClipIsCosmetic', ~isnan(maxDist) && ...
                      (isnan(singular) || maxDist < singular), ...
    'LatLimit', latLim);
end

function latLim = farPoleClip(divergesAtSouth)
%FARPOLECLIP  Stop five degrees short of the pole that diverges.
if divergesAtSouth
    latLim = [-85 90];
else
    latLim = [-90 85];
end
end

function n = coneConstant(name, sp1, sp2)
%CONECONSTANT  Snyder's cone constants, computed once for the toolbox.
p1 = deg2rad(sp1);
if isnan(sp2)
    p2 = p1;                    % tangent case
else
    p2 = deg2rad(sp2);
end
if name == "lambertconformal"
    if abs(p1 - p2) < 1e-9
        n = sin(p1);            % the tangent-case limit
    else
        n = log(cos(p1) / cos(p2)) / ...
            log(tan(pi/4 + p2/2) / tan(pi/4 + p1/2));
    end
else
    n = (sin(p1) + sin(p2)) / 2;
end
end

function s = hemiSign(hemisphere)
s = 1;
if hemisphere == "south"
    s = -1;
end
end
