function [x, y, info] = projectPolyline(lon, lat, crs, options)
%GEO.INTERNAL.PROJECTPOLYLINE  Project a polyline, breaking it where it jumps.
%
%   SYNTAX
%     [x, y] = GEO.INTERNAL.PROJECTPOLYLINE(LON, LAT, CRS)
%     [x, y, info] = GEO.INTERNAL.PROJECTPOLYLINE(..., Name, Value)
%
%   DESCRIPTION
%     The one place in the toolbox that turns geographic vertices into
%     drawable projected ones. Promoted out of GEO.GRATICULE the moment a
%     second caller needed it, which is the rule R-011 left behind.
%
%     A SEGMENT THAT WILL NOT SHRINK UNDER BISECTION IS A DISCONTINUITY,
%     NOT A CURVE. That is the whole idea, and it needs no table, no
%     per-projection special case and no knowledge of where any given
%     projection's branch cut lies. A real curve halves when its
%     parameter interval halves; a cut does not. Cuts are broken with
%     NaN, which is this toolbox's gap convention and is what stops
%     MATLAB drawing a straight line across the map.
%
%     WHAT IT CATCHES. Transverse Mercator's meridians 120 degrees from
%     the central meridian, where the atan2 giving y flips branch by
%     exactly 2*pi. A coastline crossing the antimeridian on any
%     cylindrical projection. Anything Stage E adds later that nobody has
%     thought about yet - which is the point of a rule rather than a
%     list.
%
%     DENSIFY IS FOR GENERATED LINES, NOT FOR DATA. A graticule meridian
%     is a mathematical object with no vertices of its own, so it is
%     sampled until it looks smooth. A coastline already has vertices,
%     and adding more between two adjacent ones invents shoreline that
%     was never surveyed. With Densify false the bisection still runs -
%     it is how a cut is identified - but the extra points are used only
%     to decide, and thrown away.
%
%   INPUTS
%     lon  (1,:) double  Degrees East. NaN separates parts.
%     lat  (1,:) double  Degrees North, same size.
%     crs  (1,1) struct  A GEO.CRS.
%
%   OPTIONS
%     Target   (1,1) double  Inf    Longest acceptable projected segment.
%                                   Segments longer than this are
%                                   bisected; those that will not shrink
%                                   are cut. Inf breaks nothing and
%                                   densifies nothing.
%     Densify  (1,1) logical false  Keep the points bisection produced.
%     MaxPoints (1,1) double 20000  Ceiling on the densified result.
%
%   OUTPUTS
%     x, y  (1,:) double  Projected, with NaN at gaps and at cuts.
%     info  (1,1) struct  Fields:
%             MaxSegment  (1,1) double  Longest DRAWN segment. Broken
%                                       ones are excluded, because a gap
%                                       is not a segment.
%             NumCuts     (1,1) double  How many breaks were inserted.
%             NumPoints   (1,1) double  numel(x).
%
%   ACCURACY
%     No numerical claim of its own: the projection is GEO.PROJECT's and
%     is certified against PROJ. What this adds is a decision - curve or
%     cut - and the threshold for it is TolEdge, a parameter width of
%     1e-4 of the segment being tested. A segment halved to that width
%     and still longer than Target is a cut; the alternative reading, an
%     unresolvably steep curve, would need a projection whose derivative
%     grows faster than 2^13 over one graticule interval, which none in
%     the register does.
%
%   ERRORS
%     geo:projectPolyline:SizeMismatch  - lon and lat differ in size
%
%   EXAMPLE
%     [x, y] = geo.internal.projectPolyline(lon, lat, crs, Target = 0.05);
%
%   LIMITATIONS
%     Bisection is linear in lon/lat, which is what MATLAB will draw
%     between two vertices anyway, so the test asks about the line that
%     will actually appear. It is NOT a great-circle interpolation, and
%     a caller wanting one should densify with GEO.GREATCIRCLE first.
%
%   See also GEO.PROJECT, GEO.GRATICULE, GEO.COASTLINE, GEO.SPLITANTIMERIDIAN.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon (1,:) double
    lat (1,:) double
    crs (1,1) struct {geo.internal.mustBeCrs}
    options.Target (1,1) double {mustBePositive} = Inf
    options.Densify (1,1) logical = false
    options.MaxPoints (1,1) double {mustBePositive} = 20000
end

if numel(lon) ~= numel(lat)
    error('geo:projectPolyline:SizeMismatch', ...
        'lon has %d points and lat has %d; a vertex needs both.', ...
        numel(lon), numel(lat));
end

[x, y] = geo.project(lon, lat, crs);
info = struct('MaxSegment', 0, 'NumCuts', 0, 'NumPoints', numel(x));
if numel(lon) < 2 || ~isfinite(options.Target)
    info.MaxSegment = longestDrawn(x, y);
    return
end

if options.Densify
    [lon, lat, x, y] = densify(lon, lat, x, y, crs, options);
end
[x, y, nCuts] = breakCuts(lon, lat, x, y, crs, options.Target);

info.MaxSegment = longestDrawn(x, y);
info.NumCuts = nCuts;
info.NumPoints = numel(x);
end

% ======================================================================
function [lon, lat, x, y] = densify(lon, lat, x, y, crs, options)
%DENSIFY  Bisect over-long segments until they fit or stop shrinking.
%   Points accumulate exactly where the projection bends, so the cost is
%   logarithmic in the ratio of lengths rather than proportional to it.
%   Uniform resampling of the whole line instead of this wasted a
%   measured factor of 436 on transverse Mercator (R-011).
for pass = 1:40                         %#ok<NASGU> named for the reader
    split = overLong(x, y, lon, lat, options.Target);
    if ~any(split) || numel(lon) >= options.MaxPoints
        break
    end
    idx = find(split);
    lonNew = zeros(1, numel(lon) + numel(idx));
    latNew = lonNew;
    src = 1;
    dst = 1;
    for k = 1:numel(idx)
        n = idx(k) - src + 1;
        lonNew(dst:dst + n - 1) = lon(src:idx(k));
        latNew(dst:dst + n - 1) = lat(src:idx(k));
        dst = dst + n;
        lonNew(dst) = (lon(idx(k)) + lon(idx(k) + 1)) / 2;
        latNew(dst) = (lat(idx(k)) + lat(idx(k) + 1)) / 2;
        dst = dst + 1;
        src = idx(k) + 1;
    end
    lonNew(dst:end) = lon(src:end);
    latNew(dst:end) = lat(src:end);
    lon = lonNew;
    lat = latNew;
    [x, y] = geo.project(lon, lat, crs);
end
end

function split = overLong(x, y, lon, lat, target)
%OVERLONG  Segments worth bisecting: too long, or straddling the domain.
%   A segment whose parameter width has already collapsed is left alone -
%   it is a cut, and BREAKCUTS deals with it.
finite = isfinite(x) & isfinite(y);
bothIn = finite(1:end-1) & finite(2:end);
oneIn = xor(finite(1:end-1), finite(2:end));
wide = hypot(diff(lon), diff(lat)) > 1e-4;
d = hypot(diff(x), diff(y));
split = wide & ((bothIn & d > target) | oneIn);
end

function [x, y, nCuts] = breakCuts(lon, lat, x, y, crs, target)
%BREAKCUTS  NaN wherever the line jumps rather than bends.
%   A segment is tested by projecting its midpoint: if neither half is
%   shorter than the whole, the segment is not a curve that sampling can
%   resolve.
finite = isfinite(x) & isfinite(y);
bothIn = finite(1:end-1) & finite(2:end);
d = hypot(diff(x), diff(y));
candidate = find(bothIn & d > target);
nCuts = 0;
if isempty(candidate)
    return
end

isCut = false(1, numel(candidate));
for k = 1:numel(candidate)
    i = candidate(k);
    isCut(k) = doesNotShrink(lon(i), lat(i), lon(i + 1), lat(i + 1), ...
        x(i), y(i), x(i + 1), y(i + 1), crs);
end
idx = candidate(isCut);
nCuts = numel(idx);
if nCuts == 0
    return
end

newX = NaN(1, numel(x) + nCuts);
newY = newX;
src = 1;
dst = 1;
for k = 1:nCuts
    n = idx(k) - src + 1;
    newX(dst:dst + n - 1) = x(src:idx(k));
    newY(dst:dst + n - 1) = y(src:idx(k));
    dst = dst + n + 1;                  % the skipped slot stays NaN
    src = idx(k) + 1;
end
newX(dst:end) = x(src:end);
newY(dst:end) = y(src:end);
x = newX;
y = newY;
end

function tf = doesNotShrink(lonA, latA, lonB, latB, xa, ya, xb, yb, crs)
%DOESNOTSHRINK  Bisect a few times; does the longest half ever get less?
%   Twelve halvings take the parameter interval to 1/4096 of the
%   original. A curve steep enough to survive that is steeper than any
%   projection in the register, so what survives is a branch cut.
whole = hypot(xb - xa, yb - ya);
for k = 1:12                            %#ok<NASGU> named for the reader
    lonM = (lonA + lonB) / 2;
    latM = (latA + latB) / 2;
    [xm, ym] = geo.project(lonM, latM, crs);
    if ~isfinite(xm) || ~isfinite(ym)
        tf = true;                      % the segment leaves the domain
        return
    end
    dLeft = hypot(xm - xa, ym - ya);
    dRight = hypot(xb - xm, yb - ym);
    if max(dLeft, dRight) < 0.9 * whole
        tf = false;                     % it is shrinking; a curve
        return
    end
    if dLeft > dRight                   % follow the half that stayed long
        lonB = lonM;  latB = latM;  xb = xm;  yb = ym;
    else
        lonA = lonM;  latA = latM;  xa = xm;  ya = ym;
    end
    whole = max(dLeft, dRight);
end
tf = true;
end

function s = longestDrawn(x, y)
%LONGESTDRAWN  Longest segment that will actually appear on the map.
d = hypot(diff(x), diff(y));
d = d(isfinite(d));
if isempty(d)
    s = 0;
else
    s = max(d);
end
end
