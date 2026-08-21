function B = mapBoundary(crs, lonBreaks, latBreaks, options)
%GEO.INTERNAL.MAPBOUNDARY  Where the map is: one ring, one authority.
%
%   SYNTAX
%     B = GEO.INTERNAL.MAPBOUNDARY(CRS, LONBREAKS, LATBREAKS)
%     B = GEO.INTERNAL.MAPBOUNDARY(..., Densify = 12)
%
%   DESCRIPTION
%     Traces the extent once round in longitude and latitude, projects
%     it, and hands back both the vertex ring the frame bands are built
%     on and the densified polygon everything else is clipped against.
%
%     WHY IT IS ONE FUNCTION. v1 kept the map's outline in its frame
%     routine and a second copy wherever anything needed to know what was
%     on the map; the two drifted, which is defect F12. A boundary is a
%     single fact about a figure. Two consumers reading two traversals is
%     the same defect waiting, however carefully the second is written.
%
%     COINCIDENT VERTICES ARE COLLAPSED FIRST. mollweide, hammer and
%     sinusoidal map the pole to a POINT, and so does a conic at its
%     apex: every vertex of that edge projects to the same place. Left
%     in, a run of them hands a mitre calculation zero-length segments,
%     the band offsets by nothing and the frame tapers away - reported
%     from GettingStarted as a frame collapsing to a triangle (PV-135).
%     The survivor is the LAST of each run, because its outgoing edge is
%     the real one. Keeping the first would leave an edge running from
%     the pole across every longitude; edges are densified in lon/lat, so
%     that edge would draw a sweep which is not part of the boundary.
%
%     THE TOLERANCE IS RELATIVE. cos(pi/2) evaluates to 6.1e-17 rather
%     than 0, so a pole does not project to a bitwise-identical point -
%     the images are merely very close, and how close scales with the
%     map. Measured across mollweide, hammer, sinusoidal and a conic
%     apex, degenerate separations sit at 5e-18 of the map diagonal and
%     the smallest legitimate edge at 2.8e-2, sixteen orders apart. 1e-9
%     sits in the middle with seven orders of headroom each side, and is
%     3.6 cm on a 36 000 km map.
%
%     AN INCOMPLETE RING SAYS SO. Where part of the extent leaves the
%     projection's domain, GEO.PROJECT returns NaN and those points are
%     dropped from the polygon - which would close it with a chord across
%     the gap. Complete is returned false in that case, and a caller
%     clipping against the ring is expected to decline rather than clip
%     against a chord it invented. A gap beats a wrong half.
%
%   INPUTS
%     crs        (1,1) struct  A GEO.CRS.
%     lonBreaks  (1,:) double  Degrees East, ascending. The traversal
%                              turns at each one, so the frame's bands
%                              and the ring share their corners.
%     latBreaks  (1,:) double  Degrees North, ascending.
%
%   OPTIONS
%     Densify  (1,1) double  12  Samples per boundary edge for RingX and
%                                RingY. Not used for the vertex ring.
%
%   OUTPUTS
%     B  (1,1) struct
%          Lon        (:,1) double   Vertex ring, degrees East, runs
%                                    collapsed.
%          Lat        (:,1) double   Degrees North, same size.
%          X          (1,:) double   Projected Lon/Lat.
%          Y          (1,:) double
%          ColourIdx  (:,1) double   Break interval each outgoing edge
%                                    spans, for a banded frame.
%          RingX      (1,:) double   Densified projected polygon, not
%                                    closed - MATLAB's INPOLYGON closes
%                                    it - and finite throughout.
%          RingY      (1,:) double
%          Complete   (1,1) logical  False when any boundary sample left
%                                    the domain.
%          Tolerance  (1,1) double   Projected units; two points closer
%                                    than this are the same point.
%
%   ERRORS
%     geo:mapBoundary:Degenerate - fewer than three distinct vertices
%                                  survive, so the extent has no interior
%
%   EXAMPLE
%     B = geo.internal.mapBoundary(geo.crs("mollweide"), ...
%             -180:60:180, -90:30:90);
%     in = inpolygon(x, y, B.RingX, B.RingY);
%
%   See also GEO.FRAME, GEO.COASTLINE, GEO.INTERNAL.CLIPTOBOUNDARY.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    crs (1,1) struct
    lonBreaks (1,:) double
    latBreaks (1,:) double
    options.Densify (1,1) double {mustBePositive} = 12
end

[V, colourIdx] = traceExtent(lonBreaks, latBreaks);
[xv, yv] = geo.project(V(:, 1).', V(:, 2).', crs);
ok = isfinite(xv) & isfinite(yv);
if nnz(ok) < 3
    error('geo:mapBoundary:Degenerate', ...
        ['Fewer than three boundary vertices of this extent project ' ...
         'inside %s''s domain, so it has no interior to bound.'], crs.Name);
end

tol = coincidenceTolerance(xv(ok), yv(ok));
keepIdx = keepLastOfEachRun(xv, yv, tol);
V = V(keepIdx, :);
colourIdx = colourIdx(keepIdx);
xv = xv(keepIdx);
yv = yv(keepIdx);
if numel(xv) < 3
    error('geo:mapBoundary:Degenerate', ...
        ['This extent collapses to fewer than three distinct points on ' ...
         '%s.'], crs.Name);
end

[ringX, ringY, complete] = densifiedRing(V, crs, options.Densify);

B = struct('Lon', V(:, 1), 'Lat', V(:, 2), 'X', xv, 'Y', yv, ...
    'ColourIdx', colourIdx, 'RingX', ringX, 'RingY', ringY, ...
    'Complete', complete, 'Tolerance', tol);
end

% ======================================================================
function [V, colourIdx] = traceExtent(lonBreaks, latBreaks)
%TRACEEXTENT  The extent rectangle in lon/lat, once round.
%   The colour index is the BREAK INTERVAL each edge spans, not the
%   traversal position: indexed by position, opposite sides fall out of
%   phase whenever the top edge starts somewhere the bottom edge did not.
nLon = numel(lonBreaks);
nLat = numel(latBreaks);
bottom = [lonBreaks(:), repmat(latBreaks(1), nLon, 1)];
right = [repmat(lonBreaks(end), nLat - 1, 1), latBreaks(2:end).'];
topLon = fliplr(lonBreaks);
top = [topLon(2:end).', repmat(latBreaks(end), nLon - 1, 1)];
leftLat = fliplr(latBreaks);
left = [repmat(lonBreaks(1), max(nLat - 2, 0), 1), ...
        leftLat(2:max(end - 1, 1)).'];
V = [bottom; right; top; left];

colourIdx = zeros(size(V, 1), 1);
for k = 1:size(V, 1)
    kNext = mod(k, size(V, 1)) + 1;
    if abs(V(k, 2) - V(kNext, 2)) > 1e-9
        j = find(abs(latBreaks - min(V(k, 2), V(kNext, 2))) < 1e-9, 1);
    else
        j = find(abs(lonBreaks - min(V(k, 1), V(kNext, 1))) < 1e-9, 1);
    end
    if isempty(j)
        j = k;
    end
    colourIdx(k) = j;
end
end

% ======================================================================
function tol = coincidenceTolerance(x, y)
%COINCIDENCETOLERANCE  "The same point", relative to the map's own size.
%   An absolute threshold on a projected coordinate is a statement about
%   units, because a projected coordinate carries the sphere's radius.
%   See DESCRIPTION for the two measured populations this sits between.
d = hypot(max(x) - min(x), max(y) - min(y));
if ~isfinite(d) || d <= 0
    d = 1;
end
tol = 1e-9 * d;
end

% ======================================================================
function keepIdx = keepLastOfEachRun(x, y, tol)
%KEEPLASTOFEACHRUN  Drop a vertex whose successor lands on the same point.
%   A NON-FINITE vertex is always kept: GEO.PROJECT returns NaN outside
%   the domain and the frame skips those edges deliberately, so merging
%   across one would join two edges the projection had separated.
n = numel(x);
keep = true(1, n);
for k = 1:n
    kNext = mod(k, n) + 1;
    if all(isfinite([x(k) y(k) x(kNext) y(kNext)])) && ...
            hypot(x(kNext) - x(k), y(kNext) - y(k)) < tol
        keep(k) = false;
    end
end
keepIdx = find(keep);
end

% ======================================================================
function [ringX, ringY, complete] = densifiedRing(V, crs, nSub)
%DENSIFIEDRING  The boundary as a polygon dense enough to clip against.
%   Each edge is sampled in lon/lat and then projected, which is the same
%   order the frame's bands use - sampling after projection would cut the
%   corners of every curved boundary.
nV = size(V, 1);
ringX = zeros(1, nV * (nSub - 1));
ringY = zeros(1, nV * (nSub - 1));
m = 0;
complete = true;
for k = 1:nV
    kNext = mod(k, nV) + 1;
    lonA = V(k, 1);
    lonB = V(kNext, 1);
    if abs(lonA - lonB) > 180
        lonB = lonB - 360 * sign(lonB - lonA);
    end
    lonS = linspace(lonA, lonB, nSub);
    latS = linspace(V(k, 2), V(kNext, 2), nSub);
    [xs, ys] = geo.project(lonS, latS, crs);
    xs = xs(1:end-1);                   % the next edge repeats the corner
    ys = ys(1:end-1);
    good = isfinite(xs) & isfinite(ys);
    complete = complete && all(good);
    n = nnz(good);
    ringX(m + (1:n)) = xs(good);
    ringY(m + (1:n)) = ys(good);
    m = m + n;
end
ringX = ringX(1:m);
ringY = ringY(1:m);
end
