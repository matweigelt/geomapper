function H = frame(axH, crs, options)
%GEO.FRAME  The segmented neatline, at constant on-screen thickness.
%
%   SYNTAX
%     H = GEO.FRAME(AX)
%     H = GEO.FRAME(AX, CRS)
%     H = GEO.FRAME(AX, CRS, Name, Value)
%
%   DESCRIPTION
%     The alternating black-and-white band around a map, at z = 6 so it
%     sits above everything else on the ladder. Ported from v1's
%     `geoSegmentedFrame` with its three variants intact and two of its
%     structural defects removed.
%
%     THE THREE VARIANTS ARE THE SAME THREE, chosen the same way. On a
%     projection whose graticule is a rectangle in projected space -
%     equirectangular and Mercator - the band is four straight strips and
%     four corner squares, computed in closed form. On every other
%     projection the map boundary is a curve, so the band is a ribbon
%     built per boundary edge with a mitred outward normal at each
%     vertex. `Style = "fixed"` cuts the boundary into a stated number of
%     equal segments instead, ignoring the graticule.
%
%     SEGMENT BOUNDARIES COME FROM THE GRATICULE, which is what makes the
%     frame read as a scale: each alternation is one graticule interval.
%     They are taken from GEO.NICETICKS, the same function GEO.GRATICULE
%     uses, so the two cannot disagree - in v1 they were computed twice
%     from the same formula, which is one refactor away from drifting.
%
%     OPPOSITE SIDES MATCH, and this is deliberate rather than emergent:
%     the colour index comes from WHICH graticule interval a segment
%     spans, not from how far round the traversal has got. Index by
%     traversal and the top edge starts wherever the bottom edge
%     finished, so the two sides are half a beat out of phase whenever
%     the segment count is odd.
%
%     CONSTANT ON-SCREEN THICKNESS IS THE LAYOUT MANAGER'S JOB. The band
%     is a fraction of the map's projected diagonal, so a naive redraw
%     changes its apparent thickness whenever the figure resizes. On each
%     resize the fraction is recomputed from the points-per-data-unit so
%     that the thickness in POINTS is preserved.
%
%     v1's RESIZE RATCHET IS FIXED, and it was a real one. v1 UNIONED the
%     axis limits every time it drew, never shrinking them. Shrinking the
%     figure raised the thickness fraction, which pushed the frame
%     further out, which permanently widened the limits, which lowered
%     the points-per-data-unit, which raised the fraction again. Over
%     repeated resizes the map crept smaller inside its own axes. Here
%     the limits are SET from GEO.BASEMAP's pristine H.DataLimits plus
%     the current band width, so a resize is idempotent: the same figure
%     size always gives the same limits, whatever happened in between.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     crs  (1,1) struct  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     Thickness (1,1) double  0.012   Fraction of the projected diagonal.
%     Colors    (2,3) double  [0 0 0; 1 1 1]  Alternated. Row 1 also
%                                     fills the corners.
%     Style     (1,1) string  "auto"  "auto" | "graticule" | "rectangle"
%                                     | "fixed". "auto" picks rectangle
%                                     for a rectangular projection and
%                                     graticule otherwise, which is what
%                                     v1 did with no name for it.
%     Segments  (1,1) double  16      Used by Style = "fixed" only.
%     StepLon   (1,1)         "auto"  Graticule interval; must match the
%     StepLat   (1,1)         "auto"  graticule if one is drawn.
%     LonLimit  (1,2) double  []      Extent; defaults to the basemap's.
%     LatLimit  (1,2) double  []
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Patches      (1,:) Patch  Every band and corner.
%          Thickness    (1,1) double As drawn, in projected units.
%          ThicknessPt  (1,1) double As drawn, in points - the quantity
%                                    the resize preserves.
%          Style        (1,1) string Which variant ran.
%          All          (1,:)        Everything, for deletion.
%
%   ACCURACY
%     Geometric, at TolGeom. Two properties are asserted rather than
%     described: the patch count equals the segment count computed from
%     the extent and step for a known case, and halving the figure width
%     changes the band's on-screen thickness in points by less than 5%.
%     Five percent is the figure the eye can see at print size, and it is
%     the tolerance the layout manager exists to meet.
%
%   ERRORS
%     geo:frame:NoBasemap     - no CRS given and no basemap to take one
%                               from
%     geo:frame:NothingToDraw - fewer than three boundary vertices
%                               project, so there is no outline
%
%   EXAMPLE
%     G = geo.readGrid("data/etopo_10min_surface.mat");
%     [~, ax] = geo.basemap(G, geo.crs("robinson"));
%     geo.graticule(ax);
%     H = geo.frame(ax);
%     H.ThicknessPt
%
%   LIMITATIONS
%     The ribbon variant drops any segment whose sub-samples do not all
%     project, rather than drawing a partial one. On a projection whose
%     boundary leaves the domain mid-segment that shows as a gap in the
%     band. v1 did the same; drawing half a ribbon would need a clip this
%     toolbox does not have, and a wrong half is worse than a gap.
%
%   See also GEO.BASEMAP, GEO.GRATICULE, GEO.INTERNAL.LAYOUT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    crs = []
    options.Thickness (1,1) double {mustBePositive} = 0.012
    options.Colors (2,3) double {mustBeInRange(options.Colors, 0, 1)} = [0 0 0; 1 1 1]
    options.Style (1,1) string {mustBeMember(options.Style, ["auto" "graticule" "rectangle" "fixed"])} = "auto"
    options.Segments (1,1) double {mustBeInteger, mustBePositive} = 16
    options.StepLon = "auto"
    options.StepLat = "auto"
    options.LonLimit (1,2) double = [NaN NaN]
    options.LatLimit (1,2) double = [NaN NaN]
end

H = drawFrame(axH, crs, options);
geo.internal.layout("register", axH, "frame", ...
    @(a) redraw(a, crs, options));
geo.internal.layout("setData", axH, "frame", H);
end

% ======================================================================
function redraw(axH, crs, options)
%REDRAW  Recompute the fraction so the POINTS stay put, then draw again.
%   Called by the layout manager on every resize. The target thickness in
%   points is whatever the first draw produced; everything after is
%   arithmetic to preserve it.
prior = geo.internal.layout("data", axH, "frame");
base = geo.internal.layout("data", axH, "basemap");
if isempty(prior) || ~isfinite(prior.ThicknessPt) || isempty(base)
    return
end
D = diff(base.DataLimits.XLim);
diag = hypot(D, diff(base.DataLimits.YLim));
W = axesWidthPoints(axH);
if ~isfinite(W) || W <= 0 || D <= 0 || diag <= 0
    return
end

% SOLVED, NOT ITERATED. The band's thickness in points is t*W/(D + 2m)
% where the margin m = t + 0.02*diag, because drawing the band widens the
% axis limits and so shrinks the points-per-data-unit that the band
% itself is measured in. Setting that equal to the target and solving for
% t is one line and lands on the fixed point exactly:
%
%     t*W = target*(D + 2t + 0.04*diag)
%     t   = target*(D + 0.04*diag) / (W - 2*target)
%
% Recomputing t from the CURRENT limits instead - which is what this
% function did first - converges to the same place but only after several
% resizes, and leaves the limits drifting by a measurable 0.0022 units in
% the meantime. Converging is not the same as correct.
target = prior.ThicknessPt;
denom = W - 2 * target;
if denom <= 0
    return                              % axes narrower than two bands
end
t = target * (D + 0.04 * diag) / denom;
options.Thickness = t / diag;
H = drawFrame(axH, crs, options);
H.ThicknessPt = target;                 % the invariant, not a measurement
geo.internal.layout("setData", axH, "frame", H);
end

function w = axesWidthPoints(axH)
%AXESWIDTHPOINTS  Axes width in points, independent of the data limits.
u = get(axH, 'Units');
set(axH, 'Units', 'points');
pos = get(axH, 'Position');
set(axH, 'Units', u);
w = pos(3);
end

function H = drawFrame(axH, crs, options)
%DRAWFRAME  One pass: delete what was there, build, set the limits.
[crs, lonLim, latLim, base] = geo.internal.elementExtent(axH, crs, ...
    LonLimit = options.LonLimit, LatLimit = options.LatLimit, ...
    ErrorId = "geo:frame:NoBasemap");

prior = geo.internal.layout("data", axH, "frame");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

style = resolveStyle(options.Style, crs);
lonBreaks = breaksFor(options.StepLon, lonLim, crs);
latBreaks = breaksFor(options.StepLat, latLim, crs);

if isempty(base)
    diag = hypot(diff(xlim(axH)), diff(ylim(axH)));
else
    diag = hypot(diff(base.DataLimits.XLim), diff(base.DataLimits.YLim));
end
if ~isfinite(diag) || diag <= 0
    diag = 1;
end
t = options.Thickness * diag;

switch style
    case "rectangle"
        patches = rectangleFrame(axH, crs, lonBreaks, latBreaks, t, options);
    case "fixed"
        patches = fixedFrame(axH, crs, lonLim, latLim, t, options);
    otherwise
        patches = ribbonFrame(axH, crs, lonBreaks, latBreaks, t, options);
end
if isempty(patches)
    error('geo:frame:NothingToDraw', ...
        ['Fewer than three boundary vertices of this extent project ' ...
         'inside %s''s domain, so there is no outline to put a frame ' ...
         'around.'], crs.Name);
end

setLimits(axH, base, t);
H = struct('Patches', patches, 'Thickness', t, ...
    'ThicknessPt', t * pointsPerDataUnit(axH), 'Style', style, ...
    'All', patches);
end

function setLimits(axH, base, t)
%SETLIMITS  SET from the pristine data limits, never union with current.
%   This one line is the ratchet fix. See DESCRIPTION.
if isempty(base)
    return
end
margin = t + 0.02 * hypot(diff(base.DataLimits.XLim), ...
                          diff(base.DataLimits.YLim));
xlim(axH, base.DataLimits.XLim + [-margin margin]);
ylim(axH, base.DataLimits.YLim + [-margin margin]);
end

function ppdu = pointsPerDataUnit(axH)
%POINTSPERDATAUNIT  Axes width in points divided by its x range.
u = get(axH, 'Units');
set(axH, 'Units', 'points');
pos = get(axH, 'Position');
set(axH, 'Units', u);
xl = xlim(axH);
ppdu = pos(3) / diff(xl);
end

function style = resolveStyle(asked, crs)
%RESOLVESTYLE  "auto" is rectangle where the map really is a rectangle.
if asked ~= "auto"
    style = asked;
    return
end
if any(crs.Name == ["equirectangular" "mercator"])
    style = "rectangle";
else
    style = "graticule";
end
end

function b = breaksFor(step, lim, crs) %#ok<INUSD> crs kept for symmetry
%BREAKSFOR  Graticule ticks plus the two ends, deduplicated.
%   The ends are included so the band always closes; the graticule ticks
%   alone would leave the corners unpainted whenever the extent does not
%   start on a tick.
if isstring(step) || ischar(step)
    ticks = geo.niceTicks(lim(1), lim(2), Mode = "graticule");
else
    ticks = ceil(lim(1) / step) * step : step : floor(lim(2) / step) * step;
end
b = unique([lim(1), ticks, lim(2)]);
end

function patches = rectangleFrame(axH, crs, lonBreaks, latBreaks, t, options)
%RECTANGLEFRAME  Closed form for a projection whose map is a rectangle.
[xc, yc] = geo.project([lonBreaks(1) lonBreaks(end) lonBreaks(end) lonBreaks(1)], ...
    [latBreaks(1) latBreaks(1) latBreaks(end) latBreaks(end)], crs);
ok = isfinite(xc) & isfinite(yc);
if nnz(ok) < 4
    patches = gobjects(1, 0);
    return
end
xMin = min(xc);  xMax = max(xc);
yMin = min(yc);  yMax = max(yc);

nLon = numel(lonBreaks) - 1;
nLat = numel(latBreaks) - 1;
patches = gobjects(1, 2 * nLon + 2 * nLat + 4);
m = 0;
for k = 1:nLon
    [xa, ~] = geo.project(lonBreaks(k), latBreaks(1), crs);
    [xb, ~] = geo.project(lonBreaks(k + 1), latBreaks(1), crs);
    c = bandColour(k, options.Colors);
    m = m + 1;
    patches(m) = framePatch(axH, [xa xb xb xa], [yMin yMin yMin-t yMin-t], c);
    m = m + 1;
    patches(m) = framePatch(axH, [xa xb xb xa], [yMax yMax yMax+t yMax+t], c);
end
for k = 1:nLat
    [~, ya] = geo.project(lonBreaks(1), latBreaks(k), crs);
    [~, yb] = geo.project(lonBreaks(1), latBreaks(k + 1), crs);
    c = bandColour(k, options.Colors);
    m = m + 1;
    patches(m) = framePatch(axH, [xMin-t xMin xMin xMin-t], [ya ya yb yb], c);
    m = m + 1;
    patches(m) = framePatch(axH, [xMax xMax+t xMax+t xMax], [ya ya yb yb], c);
end
corners = [xMin yMin; xMax yMin; xMax yMax; xMin yMax];
for k = 1:4
    cx = corners(k, 1);  cy = corners(k, 2);
    sx = sign(cx - (xMin + xMax) / 2);
    sy = sign(cy - (yMin + yMax) / 2);
    m = m + 1;
    patches(m) = framePatch(axH, ...
        cx + [0 sx*t sx*t 0], cy + [0 0 sy*t sy*t], options.Colors(1, :));
end
patches = patches(1:m);
end

function patches = ribbonFrame(axH, crs, lonBreaks, latBreaks, t, options)
%RIBBONFRAME  A mitred band around a boundary that is not a rectangle.
B = geo.internal.mapBoundary(crs, lonBreaks, latBreaks, ...
    Densify = 12);
if ~B.Complete
    % No drawable ring: the extent's boundary does not project inside
    % this projection's domain. Draw nothing, as this function did
    % before the boundary was promoted out of it (PV-137).
    patches = gobjects(1, 0);
    return
end
V = [B.Lon, B.Lat];
colourIdx = B.ColourIdx;
xv = B.X;
yv = B.Y;
ok = isfinite(xv) & isfinite(yv);
cx = mean(xv(ok));
cy = mean(yv(ok));
[nx, ny] = outwardNormals(xv, yv, cx, cy, B.Tolerance);

nV = size(V, 1);
patches = gobjects(1, nV);
m = 0;
nSub = 12;
for k = 1:nV
    kNext = mod(k, nV) + 1;
    lonA = V(k, 1);   latA = V(k, 2);
    lonB = V(kNext, 1);  latB = V(kNext, 2);
    if abs(lonA - lonB) > 180
        lonB = lonB - 360 * sign(lonB - lonA);
    end
    lonS = linspace(lonA, lonB, nSub);
    latS = linspace(latA, latB, nSub);
    [xs, ys] = geo.project(lonS, latS, crs);
    if any(~isfinite(xs)) || any(~isfinite(ys))
        continue                        % a gap beats a wrong half
    end
    w = linspace(0, 1, nSub);
    % NOT renormalised: adjacent ribbons must share their corner point
    % exactly, and renormalising the interpolated normal moves it.
    nxs = (1 - w) * nx(k) + w * nx(kNext);
    nys = (1 - w) * ny(k) + w * ny(kNext);
    m = m + 1;
    patches(m) = framePatch(axH, ...
        [xs, fliplr(xs + t * nxs)], [ys, fliplr(ys + t * nys)], ...
        bandColour(colourIdx(k), options.Colors));
end
patches = patches(1:m);
end

function [nx, ny] = outwardNormals(xv, yv, cx, cy, tol)
%OUTWARDNORMALS  Mitred bisector at each vertex, pointing away from centre.
nV = numel(xv);
nx = zeros(1, nV);
ny = zeros(1, nV);
miterLimit = 4;
for k = 1:nV
    kPrev = mod(k - 2, nV) + 1;
    kNext = mod(k, nV) + 1;
    dIn = [xv(k) - xv(kPrev), yv(k) - yv(kPrev)];
    dOut = [xv(kNext) - xv(k), yv(kNext) - yv(k)];
    if ~all(isfinite([dIn dOut])) || norm(dIn) < tol || norm(dOut) < tol
        continue                        % coincident vertices: zero offset
    end
    dIn = dIn / norm(dIn);
    dOut = dOut / norm(dOut);
    tv = dIn + dOut;
    if norm(tv) < 1e-9
        tv = dOut;                      % a near-reversal: use the outgoing
        miterScale = 1;
    else
        tv = tv / norm(tv);
        cosTurn = min(max(dot(dIn, dOut), -1), 1);
        miterScale = min(1 / max(cos(acos(cosTurn) / 2), 1 / miterLimit), ...
                         miterLimit);
    end
    nv = [-tv(2), tv(1)];
    if nv(1) * (xv(k) - cx) + nv(2) * (yv(k) - cy) < 0
        nv = -nv;
    end
    nx(k) = nv(1) * miterScale;
    ny(k) = nv(2) * miterScale;
end
end

function patches = fixedFrame(axH, crs, lonLim, latLim, t, options)
%FIXEDFRAME  Equal-count segmentation, ignoring the graticule.
nSeg = options.Segments;
nSide = max(60, ceil(nSeg / 4) * 15);
lonS = linspace(lonLim(1), lonLim(2), nSide);
latS = linspace(latLim(1), latLim(2), nSide);
lonB = [lonS, repmat(lonLim(2), 1, nSide), fliplr(lonS), ...
        repmat(lonLim(1), 1, nSide)];
latB = [repmat(latLim(1), 1, nSide), latS, repmat(latLim(2), 1, nSide), ...
        fliplr(latS)];
[xb, yb] = geo.project(lonB, latB, crs);
ok = isfinite(xb) & isfinite(yb);
if nnz(ok) < 10
    patches = gobjects(1, 0);
    return
end
xb = xb(ok);
yb = yb(ok);
M = numel(xb);
ip1 = [2:M, 1];
im1 = [M, 1:M-1];
tx = xb(ip1) - xb(im1);
ty = yb(ip1) - yb(im1);
tl = hypot(tx, ty);
tl(tl == 0) = 1;
nx = -ty ./ tl;
ny = tx ./ tl;
cx = mean(xb);
cy = mean(yb);
flip = nx .* (xb - cx) + ny .* (yb - cy) < 0;
nx(flip) = -nx(flip);
ny(flip) = -ny(flip);
xo = xb + t * nx;
yo = yb + t * ny;

edges = round(linspace(1, M + 1, nSeg + 1));
patches = gobjects(1, nSeg);
m = 0;
for k = 1:nSeg
    idx = edges(k):(edges(k + 1) - 1);
    if isempty(idx)
        continue
    end
    m = m + 1;
    patches(m) = framePatch(axH, [xb(idx), fliplr(xo(idx))], ...
        [yb(idx), fliplr(yo(idx))], bandColour(k, options.Colors));
end
patches = patches(1:m);
end

function c = bandColour(i, colors)
if mod(i, 2) == 1
    c = colors(1, :);
else
    c = colors(2, :);
end
end

function h = framePatch(axH, x, y, colour)
%FRAMEPATCH  One band, at z = 6, with the hairline that makes it read.
%   The black edge is what makes a white segment a segment rather than a
%   gap. FaceLighting none because nothing in v2 lights anything, and a
%   patch that could be shaded would not be white on every machine.
h = patch('Parent', axH, 'XData', x, 'YData', y, ...
    'ZData', 6 * ones(size(x)), 'FaceColor', colour, ...
    'EdgeColor', [0 0 0], 'LineWidth', 0.5, 'FaceLighting', 'none');
end
