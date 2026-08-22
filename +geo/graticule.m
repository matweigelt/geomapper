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
%     DENSIFICATION IS MEASURED, NOT ASSUMED, AND ADAPTIVE. v1 sampled
%     every graticule line at exactly 200 points regardless of projection
%     or extent, which is far too many for a 5-degree regional map and
%     visibly too few for a meridian near the rim of an azimuthal
%     projection, where the projected curvature is greatest. Here a line
%     is bisected only where its PROJECTED segments exceed 1/200 of the
%     map diagonal, so points land where the projection bends and nowhere
%     else. The criterion is a property of the drawn result rather than
%     of the input, and it is met by all sixteen projections at about
%     1 800 points for a whole graticule.
%
%     A SEGMENT THAT WILL NOT SHRINK UNDER BISECTION IS A BRANCH CUT, and
%     is broken with a NaN rather than drawn across. That is what stops a
%     transverse Mercator meridian on the back of the cylinder - where
%     the atan2 giving y flips by exactly 2*pi - from being drawn as a
%     straight line across the whole map. See TRACELINE.
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
%          LabelsOmitted (1,:) string  The labels NOT drawn because they
%                                would have overlapped one already
%                                placed. Empty on a projection where
%                                nothing collides. Meridian labels are
%                                kept and a colliding parallel label is
%                                dropped: at the pole of a
%                                pseudocylindrical projection the "left
%                                edge" is not an edge but the point the
%                                parallel has collapsed to, so that label
%                                has the least claim to the corner
%                                (PV-152).
%          LonTicks   (1,:) double The degrees actually drawn.
%          LatTicks   (1,:) double
%          MaxSegment (1,1) double Longest projected segment, as a
%                                  fraction of the map diagonal. The
%                                  densification criterion, measured on
%                                  the result rather than promised.
%                                  Segments broken as branch cuts are
%                                  excluded, because a gap is not a
%                                  segment.
%
%   ACCURACY
%     Geometric, at TolGeom. On equirectangular the 0-degree meridian
%     projects to x = 0 exactly and its label anchor with it; that is
%     asserted at 1e-9 rather than at a drawing tolerance, because it is
%     arithmetic and not appearance. MaxSegment is asserted at or below
%     1/200 of the diagonal for ALL SIXTEEN projections. An earlier
%     version of this function excluded transverse Mercator from that
%     claim; the exclusion was wrong and is recorded in RECORDS.md
%     R-011 rather than quietly dropped.
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
dropped = strings(1, 0);
if options.Labels
    [labels, dropped] = placeLabels(axH, crs, lonTicks, latTicks, lonLim, latLim, ...
        diag, options);
end

% LABELSOMITTED IS THE REPORT, AND IT IS DELIBERATELY NOT A WARNING.
% R4 offers three outcomes, and this is the third: proceed, saying what
% was done. A warning was written first and withdrawn, because on a
% pseudocylindrical projection the extreme parallel and the seam meridian
% meet at the same corner on almost every GLOBAL map - so the warning
% would have fired on the toolbox's most ordinary call, taught its users
% to silence the identifier, and put a permanent entry in a warning
% inventory whose whole value is that it is empty.
H = struct('Meridians', meridians, 'Parallels', parallels, ...
    'Labels', labels, 'LonTicks', lonTicks, 'LatTicks', latTicks, ...
    'MaxSegment', worst / max(diag, eps), 'LabelsOmitted', dropped, ...
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
%TRACELINE  A graticule line, densified where it bends, cut where it jumps.
%   The work is GEO.INTERNAL.PROJECTPOLYLINE's; this only says that a
%   generated line may be densified, which a data polyline may not. See
%   that function for why a segment that will not shrink is a cut.
[x, y, info] = geo.internal.projectPolyline(lonEnds, latEnds, crs, ...
    Target = target, Densify = true);
seg = info.MaxSegment;
end

function h = drawLine(axH, x, y, options)
%DRAWLINE  One line object at z = 3. NaN breaks it; that is the clip.
h = line('Parent', axH, 'XData', x, 'YData', y, ...
    'ZData', 3 * ones(size(x)), ...
    'Color', options.Color, 'LineStyle', options.LineStyle, ...
    'LineWidth', options.LineWidth);
end

function [labels, dropped] = placeLabels(axH, crs, lonTicks, latTicks, lonLim, latLim, ...
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
[labels, dropped] = resolveCollisions(labels, numel(lonTicks));
end

function [labels, dropped] = resolveCollisions(labels, nLon)
%RESOLVECOLLISIONS  Delete a label that lands on one already placed.
%   PV-152. PLACELABELS pushed every label outward and compared it to
%   nothing, so on Robinson "90S" and "180" overlapped by 12.4 x 9.6
%   points in the toolbox's own showcase call - and 518 green tests did
%   not see it, because every graphics assertion here measures ONE
%   element against its own claim and none compares two to each other.
%
%   MERIDIAN LABELS WIN. They are placed first and kept; a parallel label
%   that collides is dropped. The asymmetry is deliberate and is what a
%   cartographer does by hand: on a pseudocylindrical projection the
%   "left edge" at the pole is not an edge, it is the point the parallel
%   has collapsed to, so the parallel label there is the one with least
%   claim to the corner. Where nothing collides - equirectangular, where
%   the pole is a full line - nothing is dropped and this pass is a
%   no-op.
%
%   DELETING AND NOT SLIDING. Sliding a parallel label along the edge
%   moves it away from the parallel it names, which is a label that lies
%   rather than a label that is missing.
dropped = strings(1, 0);
if numel(labels) < 2
    return
end
drawnow limitrate                    % extents are not final until laid out
rects = geo.internal.textRects(labels);
keep = true(1, numel(labels));
for k = nLon + 1:numel(labels)       % parallels only; meridians are kept
    if any(isnan(rects(k, :)))
        continue
    end
    for j = find(keep(1:k - 1))
        if any(isnan(rects(j, :)))
            continue
        end
        ox = min(rects(k,1) + rects(k,3), rects(j,1) + rects(j,3)) ...
             - max(rects(k,1), rects(j,1));
        oy = min(rects(k,2) + rects(k,4), rects(j,2) + rects(j,4)) ...
             - max(rects(k,2), rects(j,2));
        if ox > 0 && oy > 0
            keep(k) = false;
            break
        end
    end
end

% F13: nothing grows in a loop inside +geo, and the audit enforces it.
% One pass decides, one reports, one deletes - and the report is taken
% BEFORE the delete, because a deleted handle has no String to read.
gone = find(~keep);
dropped = strings(1, numel(gone));
for i = 1:numel(gone)
    dropped(i) = string(labels(gone(i)).String);
end
delete(labels(gone));
labels = labels(keep);
end

function [px, py] = anchorOnEdge(lonAt, latAt, crs, lonSpan, latSpan, edge)
%ANCHORONEDGE  The point where a graticule line meets the map's edge.
%   Tried directly first. If the nominal edge point is outside the
%   projection's domain - the usual case on an azimuthal projection,
%   where the map ends at a horizon circle and not at a latitude - walk
%   the line and take the LAST FINITE point instead. That is the edge, by
%   construction, without a visible-radius table and without a search for
%   the farthest point from the origin.
% Label anchors and edge tangents are all points ON the boundary, so
% they take the same closed window the ring does. Left on the default
% they fold +180 onto -180 and a label for the eastern rim is placed on
% the western one (PV-145).
[px, py] = geo.project(lonAt, latAt, crs, Window = "closed");
if isfinite(px) && isfinite(py)
    return
end
n = 256;
lonV = linspace(lonSpan(1), lonSpan(2), n);
latV = linspace(latSpan(1), latSpan(2), n);
[x, y] = geo.project(lonV, latV, crs, Window = "closed");
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
[xa, ya] = geo.project(lonA, min(max(latA, -90), 90), crs, ...
    Window = "closed");
[xb, yb] = geo.project(lonB, min(max(latB, -90), 90), crs, ...
    Window = "closed");
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
    [latLim(1) latLim(1) latLim(2) latLim(2)], crs, Window = "closed");
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
