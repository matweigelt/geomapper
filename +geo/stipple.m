function H = stipple(axH, G, crs, options)
%GEO.STIPPLE  Mark where a field is significant, deterministically.
%
%   SYNTAX
%     H = GEO.STIPPLE(AX, G)
%     H = GEO.STIPPLE(AX, G, CRS)
%     H = GEO.STIPPLE(AX, G, CRS, Name, Value)
%
%   DESCRIPTION
%     NEW IN v2. A trend map without a significance mask invites the
%     reader to believe every pixel, and v1 had no way to draw one, so
%     every published figure from it either overstated its result or
%     carried the mask in a separate panel nobody put side by side.
%
%     THE MASK TRAVELS AS A GEO.GRID, not as a bare logical array, so it
%     carries its own coordinates and cannot be applied to the wrong
%     field. Non-zero means significant. That is deliberately the same
%     convention as MATLAB's own logical indexing rather than a named
%     field, because a mask with a threshold already applied is one
%     number per cell and pretending otherwise adds a step.
%
%     THE SUBSAMPLING IS A REGULAR STRIDE AND NEVER RANDOM. A random
%     thinning would give a different figure every time it ran, which
%     cannot be regression-tested and cannot be reproduced by a reader
%     with the same data. The stride is computed from Density and the
%     number of significant cells, so the pattern is a deterministic
%     function of the inputs alone.
%
%     HATCHING IS ONE OBJECT. The diagonal lines are a single
%     NaN-separated `line`, clipped to the mask cell by cell, rather than
%     one object per stroke. Ten thousand strokes as ten thousand
%     objects is what makes a figure take a minute to export.
%
%     IT SITS AT z = 2, above the raster and below the graticule - the
%     same level as GEO.OVERLAYPOLYGONS, because both are statements
%     about the field rather than annotations over it.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     G    (1,1) struct  A GEO.GRID whose Z is the mask: non-zero and
%                        finite means significant. NaN is NOT significant
%                        - a cell with no test result has not passed one.
%     crs  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     Style      "dots"   "dots" | "hatch".
%     Density    2000     Target number of marks. The stride is derived
%                         from this and the mask, so asking for more than
%                         there are significant cells simply marks them
%                         all.
%     Color      [0 0 0]
%     MarkerSize 2        Points, for "dots".
%     LineWidth  0.4      For "hatch".
%     Angle      45       Hatch direction, degrees anticlockwise from
%                         east, in PROJECTED space.
%     Spacing    6        Hatch line spacing, in points.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Marks       Line object - the dots, or the hatch strokes.
%          Style       (1,1) string
%          NumMasked   (1,1) double  Significant cells in the mask.
%          NumMarks    (1,1) double  Marks actually drawn.
%          Stride      (1,1) double  The subsampling used, 1 = every cell.
%          All         (1,:)
%
%   ACCURACY
%     No numerical claim: the marks sit at cell centres, projected. The
%     property that matters is determinism, and it is asserted rather
%     than described - two calls on the same mask produce bit-identical
%     coordinates.
%
%   ERRORS
%     geo:stipple:NoBasemap  - no crs and no basemap to take one from
%     geo:stipple:EmptyMask  - the mask is significant nowhere, so there
%                              is nothing to draw and silently drawing
%                              nothing would look like a bug in the mask
%
%   EXAMPLE
%     sig = geo.grid(G.Lon, G.Lat, pValues < 0.05);
%     H = geo.stipple(ax, sig, Density = 1500);
%     H.Stride
%
%   LIMITATIONS
%     Hatching is clipped to whole CELLS, not to the mask's outline, so
%     its edge is the resolution of the mask. That is honest - the mask
%     has no sub-cell information - but it means a coarse mask hatches a
%     visibly blocky region, and a reader should be told the resolution
%     rather than left to infer it from the hatching.
%
%   See also GEO.BASEMAP, GEO.OVERLAYPOLYGONS, GEO.GRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    G
    crs = []
    options.Style (1,1) string {mustBeMember(options.Style, ["dots" "hatch"])} = "dots"
    options.Density (1,1) double {mustBePositive} = 2000
    options.Color (1,3) double {mustBeInRange(options.Color, 0, 1)} = [0 0 0]
    options.MarkerSize (1,1) double {mustBePositive} = 2
    options.LineWidth (1,1) double {mustBePositive} = 0.4
    options.Angle (1,1) double = 45
    options.Spacing (1,1) double {mustBePositive} = 6
end

G = geo.grid(G);
[crs, ~, ~, ~, ~, ~, diag] = geo.internal.elementExtent(axH, crs, ...
    ErrorId = "geo:stipple:NoBasemap");

mask = G.Z ~= 0 & ~isnan(G.Z);
nMasked = nnz(mask);
if nMasked == 0
    error('geo:stipple:EmptyMask', ...
        ['The mask is significant nowhere, so there is nothing to ' ...
         'stipple. Drawing nothing silently would be indistinguishable ' ...
         'from a mask built the wrong way round.']);
end

prior = geo.internal.layout("data", axH, "stipple");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

if options.Style == "dots"
    [marks, stride, nMarks] = drawDots(axH, G, mask, crs, nMasked, options);
else
    [marks, stride, nMarks] = drawHatch(axH, G, mask, crs, diag, options);
end

H = struct('Marks', marks, 'Style', options.Style, ...
    'NumMasked', nMasked, 'NumMarks', nMarks, 'Stride', stride, ...
    'All', marks);
geo.internal.layout("register", axH, "stipple", @(~) []);
geo.internal.layout("setData", axH, "stipple", H);
end

% ======================================================================
function [h, stride, n] = drawDots(axH, G, mask, crs, nMasked, options)
%DRAWDOTS  Every STRIDE-th significant cell, in the mask's own order.
%   The stride is ceil(nMasked / Density), so the count lands at or just
%   under the target and the same mask always gives the same dots. A
%   random thinning would be prettier and untestable.
stride = max(1, ceil(nMasked / options.Density));
idx = find(mask);
idx = idx(1:stride:end);
[row, col] = ind2sub(size(mask), idx);
lon = G.Lon(col);
lat = G.Lat(row);
[x, y] = geo.project(lon(:).', lat(:).', crs);
ok = isfinite(x) & isfinite(y);
n = nnz(ok);
h = line('Parent', axH, 'XData', x(ok), 'YData', y(ok), ...
    'ZData', 2 * ones(1, n), 'LineStyle', 'none', 'Marker', '.', ...
    'MarkerSize', options.MarkerSize * 3, 'Color', options.Color);
end

function [h, stride, n] = drawHatch(axH, G, mask, crs, diag, options)
%DRAWHATCH  Diagonal strokes, one object, clipped to whole cells.
%   Drawn in PROJECTED space, because a hatch that followed the graticule
%   would rotate with the projection and stop reading as texture. Each
%   stroke is cut to the cells whose centres are masked, and the cuts are
%   joined into one NaN-separated line.
stride = 1;
[row, col] = find(mask);
lon = G.Lon(col);
lat = G.Lat(row);
[cx, cy] = geo.project(lon(:).', lat(:).', crs);
ok = isfinite(cx) & isfinite(cy);
cx = cx(ok);
cy = cy(ok);
if isempty(cx)
    h = line('Parent', axH, 'XData', [], 'YData', []);
    n = 0;
    return
end

% Cell half-size in projected units, from the median spacing of the
% masked cells themselves rather than from the grid step: on a curved
% projection those differ, and the drawn cell is what must be covered.
step = medianSpacing(cx, cy, G);
c = cosd(options.Angle);
s = sind(options.Angle);
u = cx * c + cy * s;                    % along the hatch direction
v = -cx * s + cy * c;                   % across it
spacing = options.Spacing / 72 * diag / axesInches(axH);
if ~isfinite(spacing) || spacing <= 0
    spacing = diag / 60;
end

% Preallocated to the only bound that always holds: one masked cell can
% start at most one run, so there are never more runs than cells. Trimmed
% after. Growing this inside the loop is F13, and a global mask makes it
% a loop over hundreds of thousands.
lines = round((v - min(v)) / spacing);
maxRuns = numel(u);
xs = NaN(1, 3 * maxRuns);
ys = xs;
n = 0;
for k = unique(lines(:)).'
    on = lines == k;
    uu = sort(u(on));
    vSeg = min(v) + k * spacing;
    breaks = [0, find(diff(uu) > 1.5 * step), numel(uu)];
    for j = 1:numel(breaks) - 1
        a = uu(breaks(j) + 1) - step / 2;
        b = uu(breaks(j + 1)) + step / 2;
        n = n + 1;
        xs(3 * n - 2:3 * n - 1) = [a, b] * c - vSeg * s;
        ys(3 * n - 2:3 * n - 1) = [a, b] * s + vSeg * c;
    end
end
xs = xs(1:3 * n);
ys = ys(1:3 * n);
h = line('Parent', axH, 'XData', xs, 'YData', ys, ...
    'ZData', 2 * ones(size(xs)), 'Color', options.Color, ...
    'LineWidth', options.LineWidth);
end

function step = medianSpacing(cx, cy, G)
%MEDIANSPACING  Typical projected size of one masked cell.
if numel(cx) < 2
    step = hypot(G.LonStep, G.LatStep);
    return
end
d = hypot(diff(cx), diff(cy));
d = d(isfinite(d) & d > 0);
if isempty(d)
    step = hypot(G.LonStep, G.LatStep);
else
    step = median(d);
end
end

function inches = axesInches(axH)
%AXESINCHES  The axes width in inches, for a points-to-data conversion.
u = get(axH, 'Units');
set(axH, 'Units', 'inches');
pos = get(axH, 'Position');
set(axH, 'Units', u);
inches = pos(3);
if ~isfinite(inches) || inches <= 0
    inches = 6;
end
end
