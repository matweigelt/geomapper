function H = graticule(axH, crs, options)
%GEO.GRATICULE  Meridians, parallels and their labels.
%
%   SYNTAX
%     H = GEO.GRATICULE(AX)
%     H = GEO.GRATICULE(AX, CRS)
%     H = GEO.GRATICULE(AX, CRS, Name, Value)
%
%   DESCRIPTION
%     Draws the graticule on an axes that already carries a GEO.BASEMAP,
%     at z = 3 on the documented ladder. With no CRS given it takes the
%     one the basemap used, so the two cannot disagree.
%
%     DENSIFICATION IS MEASURED, NOT ASSUMED. v1 sampled every graticule
%     line at exactly 200 points regardless of projection or extent,
%     which is far too many for a 5-degree regional map and visibly too
%     few for a meridian near the rim of an azimuthal projection, where
%     the projected curvature is greatest. Here each line is projected
%     once at a coarse sampling, the longest resulting SEGMENT is
%     measured against 1/200 of the map diagonal, and the line is
%     re-sampled only if it misses. The criterion is a property of the
%     drawn result rather than of the input.
%
%     NOTHING CLIPS HERE EITHER. GEO.PROJECT returns NaN outside
%     CRS.Domain and MATLAB breaks a line at NaN, so the clip and the
%     gap convention are the same mechanism. v1 re-derived the visible
%     radius in three places and they drifted (F12).
%
%     LABELS ARE PLACED ANALYTICALLY, AND THIS REPLACES v1's HEURISTICS.
%     v1 estimated a label's direction from a finite-difference tangent,
%     then corrected it with a chain of special cases: an "edge bias", a
%     search for the boundary point farthest from the projection origin,
%     a frame-circle radius capped against a reference point computed by
%     a spherical destination formula, and a 1.05 snap tolerance deciding
%     whether a label belonged to the circle at all. Those interacted:
%     the azimuthal label defects in the v1 review were not one bug but
%     several, each of which had been repaired by adding another case.
%     Here a label sits at the LAST FINITE PROJECTED POINT of the line it
%     names - which is by construction where that line meets the edge of
%     the map, for every projection, with no table and no search - and is
%     pushed outward along the normal to the local boundary direction,
%     obtained from a central difference of GEO.PROJECT along the edge.
%
%     WHY GEO.UNPROJECT IS NOT IN THE PLACEMENT PATH. The handover
%     suggested placing labels through it. It is used in the TESTS
%     instead, to check that the anchor of the label reading "60E" really
%     does unproject to longitude 60. A placement computed with
%     GEO.UNPROJECT and then checked with GEO.UNPROJECT would be checked
%     against itself; used this way the two directions are independent,
%     which is the whole point of an inverse.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     crs  (1,1) struct  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     StepLon     (1,1)         "auto"  Degrees, or "auto" for GEO.NICETICKS.
%     StepLat     (1,1)         "auto"
%     LonLimit    (1,2) double  []      Extent; defaults to the basemap's.
%     LatLimit    (1,2) double  []
%     Color       (1,3) double  [0.35 0.35 0.35]
%     LineStyle   (1,1) string  "--"
%     LineWidth   (1,1) double  0.5
%     Labels      (1,1) logical true
%     LonLabelEdge (1,1) string "bottom"  "bottom" | "top".
%     LatLabelEdge (1,1) string "left"    "left" | "right".
%     LabelGap    (1,1) double  0.034   Fraction of the map diagonal.
%                                       Matches v1's default, which was
%                                       FrameThickness 0.012 + 0.022.
%     FontName    (1,1) string  "Helvetica"
%     FontSize    (1,1) double  9
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Meridians  (1,:) Line   One object per meridian.
%          Parallels  (1,:) Line
%          Labels     (1,:) Text   Empty if Labels = false.
%          LonTicks   (1,:) double The degrees actually drawn.
%          LatTicks   (1,:) double
%          MaxSegment (1,1) double Longest projected segment, as a
%                                  fraction of the map diagonal. The
%                                  densification criterion, measured on
%                                  the result rather than promised.
%
%   ACCURACY
%     Geometric, at TolGeom. On equirectangular the 0-degree meridian
%     projects to x = 0 exactly and its label anchor with it; that is
%     asserted at 1e-9 rather than at a drawing tolerance, because it is
%     arithmetic and not appearance. MaxSegment is asserted at or below
%     1/200 of the diagonal for fifteen of the sixteen projections;
%     transverse Mercator is the exception, for the reason given at
%     TRACELINE, and its measured value is recorded rather than bounded.
%
%   ERRORS
%     geo:graticule:NoBasemap  - no CRS was given and the axes carries no
%                                basemap to take one from
%     geo:graticule:BadStep    - a step that is not positive and finite
%
%   EXAMPLE
%     G = geo.readGrid("data/etopo_10min_surface.mat");
%     [~, ax] = geo.basemap(G, geo.crs("mollweide"));
%     H = geo.graticule(ax, StepLon = 30, StepLat = 15);
%     H.MaxSegment
%
%   LIMITATIONS
%     Labels go on one edge each, chosen by option, and are not moved out
%     of each other's way - the layout manager's collision avoidance is
%     for the corner annotations, not for a row of tick labels. On a
%     projection whose meridians converge to a point, labels at that edge
%     will crowd; put them on the equator instead by setting LatLimit,
%     or turn them off and place your own.
%
%   See also GEO.BASEMAP, GEO.FRAME, GEO.NICETICKS, GEO.UNPROJECT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    crs = []
    options.StepLon = "auto"
    options.StepLat = "auto"
    options.LonLimit (1,2) double = [NaN NaN]
    options.LatLimit (1,2) double = [NaN NaN]
    options.Color (1,3) double {mustBeInRange(options.Color, 0, 1)} = [0.35 0.35 0.35]
    options.LineStyle (1,1) string = "--"
    options.LineWidth (1,1) double {mustBePositive} = 0.5
    options.Labels (1,1) logical = true
    options.LonLabelEdge (1,1) string {mustBeMember(options.LonLabelEdge, ["bottom" "top"])} = "bottom"
    options.LatLabelEdge (1,1) string {mustBeMember(options.LatLabelEdge, ["left" "right"])} = "left"
    options.LabelGap (1,1) double {mustBeNonnegative} = 0.034
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 9
end

[crs, lonLim, latLim, base] = geo.internal.elementExtent(axH, crs, ...
    LonLimit = options.LonLimit, LatLimit = options.LatLimit, ...
    ErrorId = "geo:graticule:NoBasemap");

lonTicks = resolveTicks(options.StepLon, lonLim, "StepLon");
latTicks = resolveTicks(options.StepLat, latLim, "StepLat");

prior = geo.internal.layout("data", axH, "graticule");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

diag = mapDiagonal(axH, base);
target = diag / 200;

nLon = numel(lonTicks);
nLat = numel(latTicks);
meridians = gobjects(1, nLon);
parallels = gobjects(1, nLat);
worst = 0;
for k = 1:nLon
    [x, y, seg] = traceLine(repmat(lonTicks(k), 1, 2), latLim, crs, target);
    worst = max(worst, seg);
    meridians(k) = drawLine(axH, x, y, options);
end
for k = 1:nLat
    [x, y, seg] = traceLine(lonLim, repmat(latTicks(k), 1, 2), crs, target);
    worst = max(worst, seg);
    parallels(k) = drawLine(axH, x, y, options);
end

labels = gobjects(1, 0);
if options.Labels
    labels = placeLabels(axH, crs, lonTicks, latTicks, lonLim, latLim, ...
        diag, options);
end

H = struct('Meridians', meridians, 'Parallels', parallels, ...
    'Labels', labels, 'LonTicks', lonTicks, 'LatTicks', latTicks, ...
    'MaxSegment', worst / max(diag, eps), ...
    'All', [meridians, parallels, labels]);

geo.internal.layout("register", axH, "graticule", @(~) []);
geo.internal.layout("setData", axH, "graticule", H);
end

% ======================================================================
function ticks = resolveTicks(step, lim, what)
%RESOLVETICKS  Multiples of the step inside the extent.
if isstring(step) || ischar(step)
    if string(step) ~= "auto"
        error('geo:graticule:BadStep', ...
            '%s must be a positive number or "auto"; got "%s".', ...
            what, string(step));
    end
    ticks = geo.niceTicks(lim(1), lim(2), Mode = "graticule");
    return
end
if ~isscalar(step) || ~isfinite(step) || step <= 0
    error('geo:graticule:BadStep', ...
        '%s must be a positive finite scalar or "auto".', what);
end
ticks = ceil(lim(1) / step) * step : step : floor(lim(2) / step) * step;
end

function d = mapDiagonal(axH, base)
%MAPDIAGONAL  Bounding-box diagonal of the map, in projected units.
%   Taken from the basemap's PRISTINE limits when there is one, so that a
%   frame drawn earlier - which widens the axes - cannot change the
%   densification criterion and make a redraw disagree with the original.
if isempty(base)
    d = hypot(diff(xlim(axH)), diff(ylim(axH)));
else
    d = hypot(diff(base.DataLimits.XLim), diff(base.DataLimits.YLim));
end
if ~isfinite(d) || d <= 0
    d = 1;
end
end

function [x, y, seg] = traceLine(lonEnds, latEnds, crs, target)
%TRACELINE  Project a line in lon/lat, densified until the result is smooth.
%
%   The criterion is on the DRAWN RESULT, so it has to be measured after
%   each attempt rather than predicted before the first. One refinement
%   pass is not enough: the estimate n * seg / target assumes curvature
%   is uniform along the line, and where it is not - Mollweide near the
%   pole, Mercator near its clip - the longest segment simply moves
%   somewhere else and the second pass lands about 1.6 times over budget.
%
%   THE CAP OF 8192 IS REACHED BY EXACTLY ONE PROJECTION and it is worth
%   naming. Transverse Mercator's equator runs to a genuine singularity
%   90 degrees from the central meridian, and the declared clip stops
%   only 0.5 degrees short of it, where the scale factor is 115. Uniform
%   sampling in longitude therefore needs about 262 000 points on that
%   one line to satisfy the criterion - measured, not estimated - which
%   is not a graticule, it is a rendering of a limit. Every other
%   projection in the register meets the criterion below 8192. See the
%   handover's open question on that clip: Mercator's margin for the
%   same kind of singularity is 5 degrees, ten times wider.
%
%   IT STOPS IF REFINING STOPS HELPING, which is not a safety net but the
%   one behaviour that makes a loop admissible here. Where a projection
%   diverges, a finer sample lands closer to the divergence and the
%   longest segment GROWS - measured on Lambert conformal before its
%   domain was declared: 7.1 at 64 points, 98.6 at 4096. A loop that
%   only tested "am I under budget yet" would never return. Domains are
%   declared now and no projection in the register does this, so this
%   guard should never fire; it is here because "should never" is not a
%   termination proof.
n = 64;
[x, y, seg] = sampleLine(lonEnds, latEnds, crs, n);
for pass = 1:4                          %#ok<NASGU> named for the reader
    if ~isfinite(seg) || seg <= target
        return
    end
    nNext = min(ceil(1.3 * n * seg / target), 8192);
    if nNext <= n
        return                          % cannot refine further
    end
    [xNext, yNext, segNext] = sampleLine(lonEnds, latEnds, crs, nNext);
    if segNext >= seg
        return                          % refining made it worse; stop
    end
    n = nNext;
    x = xNext;
    y = yNext;
    seg = segNext;
end
end

function [x, y, seg] = sampleLine(lonEnds, latEnds, crs, n)
%SAMPLELINE  N points along the line, projected, with its longest step.
lonV = linspace(lonEnds(1), lonEnds(2), n);
latV = linspace(latEnds(1), latEnds(2), n);
[x, y] = geo.project(lonV, latV, crs);
d = hypot(diff(x), diff(y));
d = d(isfinite(d));
if isempty(d)
    seg = 0;
else
    seg = max(d);
end
end

function h = drawLine(axH, x, y, options)
%DRAWLINE  One line object at z = 3. NaN breaks it; that is the clip.
h = line('Parent', axH, 'XData', x, 'YData', y, ...
    'ZData', 3 * ones(size(x)), ...
    'Color', options.Color, 'LineStyle', options.LineStyle, ...
    'LineWidth', options.LineWidth);
end

function labels = placeLabels(axH, crs, lonTicks, latTicks, lonLim, latLim, ...
                              diag, options)
%PLACELABELS  One label per tick, on the chosen edge, pushed outward.
gap = options.LabelGap * diag;
if options.LonLabelEdge == "bottom"
    lonEdgeLat = latLim(1);
else
    lonEdgeLat = latLim(2);
end
if options.LatLabelEdge == "left"
    latEdgeLon = lonLim(1);
else
    latEdgeLon = lonLim(2);
end

labels = gobjects(1, numel(lonTicks) + numel(latTicks));
m = 0;
for k = 1:numel(lonTicks)
    % Anchor: where this meridian meets the edge. Direction: along the
    % PARALLEL at that edge, because the label is pushed off the boundary
    % it sits on, not along the line it names.
    [px, py] = anchorOnEdge(lonTicks(k), lonEdgeLat, crs, ...
        [lonTicks(k) lonTicks(k)], [latLim(1) latLim(2)], options.LonLabelEdge);
    if ~isfinite(px)
        continue
    end
    [nx, ny] = outwardNormal(@(u) deal(u, lonEdgeLat), lonTicks(k), ...
        crs, px, py, lonLim, latLim);
    m = m + 1;
    labels(m) = drawLabel(axH, px + gap * nx, py + gap * ny, ...
        formatLon(lonTicks(k)), options);
end
for k = 1:numel(latTicks)
    [px, py] = anchorOnEdge(latEdgeLon, latTicks(k), crs, ...
        [lonLim(1) lonLim(2)], [latTicks(k) latTicks(k)], options.LatLabelEdge);
    if ~isfinite(px)
        continue
    end
    [nx, ny] = outwardNormal(@(u) deal(latEdgeLon, u), latTicks(k), ...
        crs, px, py, lonLim, latLim);
    m = m + 1;
    labels(m) = drawLabel(axH, px + gap * nx, py + gap * ny, ...
        formatLat(latTicks(k)), options);
end
labels = labels(1:m);
end

function [px, py] = anchorOnEdge(lonAt, latAt, crs, lonSpan, latSpan, edge)
%ANCHORONEDGE  The point where a graticule line meets the map's edge.
%   Tried directly first. If the nominal edge point is outside the
%   projection's domain - the usual case on an azimuthal projection,
%   where the map ends at a horizon circle and not at a latitude - walk
%   the line and take the LAST FINITE point instead. That is the edge, by
%   construction, without a visible-radius table and without a search for
%   the farthest point from the origin.
[px, py] = geo.project(lonAt, latAt, crs);
if isfinite(px) && isfinite(py)
    return
end
n = 256;
lonV = linspace(lonSpan(1), lonSpan(2), n);
latV = linspace(latSpan(1), latSpan(2), n);
[x, y] = geo.project(lonV, latV, crs);
ok = find(isfinite(x) & isfinite(y));
if isempty(ok)
    px = NaN;
    py = NaN;
    return
end
if edge == "bottom" || edge == "left"
    pick = ok(1);
else
    pick = ok(end);
end
px = x(pick);
py = y(pick);
end

function [nx, ny] = outwardNormal(edgePoint, u, crs, px, py, lonLim, latLim)
%OUTWARDNORMAL  Unit normal to the boundary at (px,py), pointing outward.
%   The tangent is a CENTRAL difference of GEO.PROJECT along the edge, so
%   it is the projection's true local direction and not an approximation
%   of one. Outward is decided by the sign against the map centroid,
%   which needs no knowledge of which edge this is.
h = 0.25;                               % degrees, half-step
[lonA, latA] = edgePoint(u - h);
[lonB, latB] = edgePoint(u + h);
[xa, ya] = geo.project(lonA, min(max(latA, -90), 90), crs);
[xb, yb] = geo.project(lonB, min(max(latB, -90), 90), crs);
tx = xb - xa;
ty = yb - ya;
if ~isfinite(tx) || ~isfinite(ty) || hypot(tx, ty) < 1e-12
    % Degenerate edge - a meridian converging to a pole, say. Push
    % radially from the centroid, which is always defined.
    [cx, cy] = mapCentroid(crs, lonLim, latLim);
    tx = px - cx;
    ty = py - cy;
    r = hypot(tx, ty);
    if r < 1e-12
        nx = 0;
        ny = -1;
        return
    end
    nx = tx / r;
    ny = ty / r;
    return
end
r = hypot(tx, ty);
nx = -ty / r;
ny = tx / r;
[cx, cy] = mapCentroid(crs, lonLim, latLim);
if nx * (px - cx) + ny * (py - cy) < 0
    nx = -nx;
    ny = -ny;
end
end

function [cx, cy] = mapCentroid(crs, lonLim, latLim)
%MAPCENTROID  Mean of the projected extent corners, NaNs dropped.
[x, y] = geo.project([lonLim(1) lonLim(2) lonLim(2) lonLim(1)], ...
    [latLim(1) latLim(1) latLim(2) latLim(2)], crs);
ok = isfinite(x) & isfinite(y);
if ~any(ok)
    cx = 0;
    cy = 0;
    return
end
cx = mean(x(ok));
cy = mean(y(ok));
end

function h = drawLabel(axH, x, y, str, options)
h = text('Parent', axH, 'Position', [x y 3], 'String', str, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontName', options.FontName, 'FontSize', options.FontSize, ...
    'Color', [0 0 0], 'Clipping', 'off');
end

function s = formatLon(v)
%FORMATLON  Degrees east or west, with the seam written as 180.
w = mod(v + 180, 360) - 180;
if abs(abs(w) - 180) < 1e-9
    s = "180" + char(176);
elseif abs(w) < 1e-9
    s = "0" + char(176);
elseif w > 0
    s = trimNumber(w) + char(176) + "E";
else
    s = trimNumber(-w) + char(176) + "W";
end
end

function s = formatLat(v)
if abs(v) < 1e-9
    s = "0" + char(176);
elseif v > 0
    s = trimNumber(v) + char(176) + "N";
else
    s = trimNumber(-v) + char(176) + "S";
end
end

function s = trimNumber(v)
%TRIMNUMBER  Shortest exact-looking form: 30, not 30.0000.
if abs(v - round(v)) < 1e-9
    s = string(round(v));
else
    s = string(round(v, 4));
end
end
