function H = overlayContours(axH, G, crs, options)
%GEO.OVERLAYCONTOURS  Contour lines of a field, projected and broken.
%
%   SYNTAX
%     H = GEO.OVERLAYCONTOURS(AX, G)
%     H = GEO.OVERLAYCONTOURS(AX, G, CRS)
%     H = GEO.OVERLAYCONTOURS(AX, G, CRS, Name, Value)
%
%   DESCRIPTION
%     Contours are computed by MATLAB's own CONTOURC on the lon/lat grid,
%     so the vertices come back in degrees, and are then projected like
%     every other polyline in the toolbox. At z = 1: above the raster,
%     below everything else, because a contour describes the field it is
%     drawn on rather than annotating the map.
%
%     THE JUMP HEURISTICS ARE GONE, and there were two of them. v1 broke
%     a contour first on a longitude difference above 180 and then again
%     on a projected-distance threshold of `min(0.5*diag, max(30*medSeg,
%     0.02*diag))` - three tuned constants and a median, described in its
%     own comments as "belt-and-suspenders". Both passes existed to catch
%     the same class of error: a segment drawn straight across the map
%     because its two ends are on opposite sides of a seam or a
%     singularity. GEO.INTERNAL.PROJECTPOLYLINE catches it with no
%     constants at all - a segment that will not shrink under bisection
%     is a cut, not a curve - and catches cases neither heuristic did.
%
%     NEGATIVE CONTOURS CAN BE DASHED, which v1 could not do and which
%     anomaly maps need: on a field of change, the sign is the first
%     thing a reader looks for, and a solid line at -2 and a solid line
%     at +2 are indistinguishable without reading the labels.
%
%     LABELSPACING IS NEW TOO. v1 labelled every contour at one point
%     per line, so a long contour carried one number and a short one
%     carried the same number twice as densely.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     G    (1,1) struct  A GEO.GRID.
%     crs  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     Levels        []       Explicit levels. Empty uses GEO.NICETICKS
%                            over the field's range, which gives round
%                            numbers rather than v1's linspace of eight.
%     Color         [0 0 0]
%     LineWidth     0.75
%     DashNegative  true     Negative levels dashed. NEW in v2.
%     Labels        false
%     LabelSpacing  0.35     Distance between labels on one contour, as a
%                            fraction of the map diagonal. NEW in v2.
%     FontName      "Helvetica"
%     FontSize      8
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Lines       (1,:) Line    One per level, NaN-separated within.
%          Labels      (1,:) Text
%          Levels      (1,:) double  As drawn.
%          NumCuts     (1,1) double  Branch cuts broken across all levels.
%          All         (1,:)
%
%   ACCURACY
%     Contour vertices are CONTOURC's, on the grid as given, and are not
%     re-interpolated: a contour is a statement about the data and
%     smoothing it here would be a statement about nothing. The
%     projection is GEO.PROJECT's.
%
%   ERRORS
%     geo:overlayContours:NoBasemap  - no crs and no basemap
%     geo:overlayContours:FlatField  - the field has no range, so there
%                                      is no contour to draw
%
%   EXAMPLE
%     H = geo.overlayContours(ax, G, Levels = -5:1:5, Labels = true);
%
%   LIMITATIONS
%     Labels are placed at points along the contour and are not rotated
%     to it, and nothing moves them out of each other's way. A dense
%     contour set with labels on will overlap; that is what LabelSpacing
%     and turning them off are for.
%
%   See also GEO.BASEMAP, GEO.NICETICKS, GEO.INTERNAL.PROJECTPOLYLINE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    G
    crs = []
    options.Levels double = []
    options.Color (1,3) double {mustBeInRange(options.Color, 0, 1)} = [0 0 0]
    options.LineWidth (1,1) double {mustBePositive} = 0.75
    options.DashNegative (1,1) logical = true
    options.Labels (1,1) logical = false
    options.LabelSpacing (1,1) double {mustBePositive} = 0.35
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 8
end

G = geo.grid(G);
[crs, ~, ~, ~, ~, ~, diag] = geo.internal.elementExtent(axH, crs, ...
    ErrorId = "geo:overlayContours:NoBasemap");

levels = options.Levels;
if isempty(levels)
    lo = min(G.Z(:), [], 'omitnan');
    hi = max(G.Z(:), [], 'omitnan');
    if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
        error('geo:overlayContours:FlatField', ...
            ['The field ranges from %g to %g, so it has no contours. ' ...
             'A constant field is not an error, but drawing nothing for ' ...
             'it silently would look like one.'], lo, hi);
    end
    levels = geo.niceTicks(lo, hi);
    levels = levels(levels > lo & levels < hi);
end

prior = geo.internal.layout("data", axH, "contours");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

C = contourc(G.Lon(:).', G.Lat(:).', G.Z, sort(levels(:)).');
[byLevel, drawn] = groupByLevel(C);

target = diag / 200;
lines = gobjects(1, numel(drawn));
labels = gobjects(1, 0);
perLevel = cell(1, numel(drawn));
nCuts = 0;
for k = 1:numel(drawn)
    [x, y, cuts] = projectRuns(byLevel{k}, crs, target);
    nCuts = nCuts + cuts;
    lines(k) = line('Parent', axH, 'XData', x, 'YData', y, ...
        'ZData', ones(size(x)), 'Color', options.Color, ...
        'LineWidth', options.LineWidth, ...
        'LineStyle', styleFor(drawn(k), options));
    if options.Labels
        perLevel{k} = placeLabels(axH, x, y, drawn(k), diag, options);
    end
end
if options.Labels
    labels = [perLevel{:}];
end

H = struct('Lines', lines, 'Labels', labels, 'Levels', drawn, ...
    'NumCuts', nCuts, 'All', [lines, labels]);
geo.internal.layout("register", axH, "contours", @(~) []);
geo.internal.layout("setData", axH, "contours", H);
end

% ======================================================================
function [byLevel, drawn] = groupByLevel(C)
%GROUPBYLEVEL  CONTOURC's packed output into one run list per level.
%   Its format is a header column [level; count] followed by that many
%   vertex columns, repeated. One level can appear many times.
% Two passes: count the runs, then fill. CONTOURC's output is a packed
% stream whose length is known but whose run count is not, and growing an
% array inside the walk is exactly F13.
nRuns = 0;
idx = 1;
while idx < size(C, 2)
    n = C(2, idx);
    if idx + n > size(C, 2)
        break
    end
    nRuns = nRuns + 1;
    idx = idx + n + 1;
end
runs = cell(1, nRuns);
levelOf = zeros(1, nRuns);
idx = 1;
for k = 1:nRuns
    n = C(2, idx);
    runs{k} = C(:, idx + 1 : idx + n);
    levelOf(k) = C(1, idx);
    idx = idx + n + 1;
end
drawn = unique(levelOf);
byLevel = cell(1, numel(drawn));
for k = 1:numel(drawn)
    byLevel{k} = runs(levelOf == drawn(k));
end
end

function [x, y, nCuts] = projectRuns(runs, crs, target)
%PROJECTRUNS  Every run of one level, NaN-joined into one polyline.
% Collected into cells and concatenated once, rather than grown per run.
xs = cell(1, 2 * numel(runs));
ys = xs;
nCuts = 0;
for k = 1:numel(runs)
    [xk, yk, info] = geo.internal.projectPolyline(runs{k}(1, :), ...
        runs{k}(2, :), crs, Target = target, Densify = false);
    nCuts = nCuts + info.NumCuts;
    if k > 1
        xs{2 * k - 1} = NaN;
        ys{2 * k - 1} = NaN;
    end
    xs{2 * k} = xk;
    ys{2 * k} = yk;
end
x = [xs{:}];
y = [ys{:}];
end

function s = styleFor(level, options)
%STYLEFOR  Dashed below zero, so the sign reads without the label.
if options.DashNegative && level < 0
    s = '--';
else
    s = '-';
end
end

function h = placeLabels(axH, x, y, level, diag, options)
%PLACELABELS  Numbers along the contour, at most one per LabelSpacing.
%   Placed by accumulated arc length rather than one per run, so a long
%   contour gets several and a short one gets one.
gap = options.LabelSpacing * diag;
d = hypot(diff(x), diff(y));
% A run must be at least one spacing long before it earns a label, so a
% field of small closed loops does not get a number printed inside every
% one of them.
travelled = 0;
h = gobjects(1, numel(x));
m = 0;
for k = 1:numel(x)
    if k > 1
        if ~isfinite(d(k - 1))
            travelled = 0;              % a new run starts fresh
        else
            travelled = travelled + d(k - 1);
        end
    end
    if travelled < gap || ~isfinite(x(k))
        continue
    end
    travelled = 0;
    m = m + 1;
    h(m) = text('Parent', axH, 'Position', [x(k) y(k) 1], ...
        'String', sprintf('%g', level), 'FontName', options.FontName, ...
        'FontSize', options.FontSize, 'Color', options.Color, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'Clipping', 'on');
end
h = h(1:m);
end
