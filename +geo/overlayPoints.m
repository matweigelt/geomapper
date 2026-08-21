function H = overlayPoints(axH, P, crs, options)
%GEO.OVERLAYPOINTS  Scattered locations, coloured and optionally sized.
%
%   SYNTAX
%     H = GEO.OVERLAYPOINTS(AX, P)
%     H = GEO.OVERLAYPOINTS(AX, P, CRS)
%     H = GEO.OVERLAYPOINTS(AX, P, CRS, Name, Value)
%
%   DESCRIPTION
%     Draws a GEO.POINTS at z = 5. Colour comes from Obs and size from
%     SizeData, which are two fields of the value struct precisely so
%     that a caller can have both - v1 overloaded one vector for the two
%     and a user who wanted size by magnitude and colour by sign could
%     not have it.
%
%     THE SIZE LEGEND DECODES THE MARKERS IT SITS BESIDE, which v1's did
%     not. It drew its reference circles at radius sqrt(area/pi), the
%     radius of a circle of that AREA - but MATLAB's scatter treats
%     SizeData as the area of the marker's BOUNDING BOX, so its markers
%     have radius sqrt(area)/2. The legend was therefore drawn a factor
%     of sqrt(pi)/2 too small, about 11%, and a reader measuring a bubble
%     against it read the wrong number. Here both use the same rule.
%
%     A MISSING SIZE IS NOT THE SMALLEST SIZE. v1 mapped a NaN in
%     SizeData to fraction zero, so a point with no measurement was drawn
%     identical to the smallest real one. Here such points are drawn at
%     the default MarkerSize and reported separately, because "we did not
%     measure this" and "this is the minimum" are different statements.
%
%     SCATTER3 CLEARS THE AXES, and in a composable toolbox that is a
%     landmine. It is a high-level plotting call, so unless HOLD is on it
%     resets the axes first - measured: a map carrying fifty objects came
%     back with five, the basemap and every element drawn before it gone.
%     v1 never met this because it drew everything inside one function in
%     a fixed order; here any element may be called at any time, so the
%     hold state is saved, forced on, and restored.
%
%     THE LEGEND AVOIDS THE OTHER CORNER FURNITURE. It registers its
%     footprint with the layout manager and is pushed clear of the scale
%     bar, north arrow and inset. v1's said in its own comments that it
%     had nothing to avoid, in a file whose scale bar and north arrow
%     both default to on and whose automatic corners are two of the four
%     the legend can occupy.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     P    (1,1) struct  A GEO.POINTS. Obs gives colour, SizeData gives
%                        size, Labels are drawn beside the markers.
%     crs  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     Marker          "o"
%     MarkerSize      36        Points squared, when there is no SizeData.
%     SizeRange       [16 400]  [min max] marker area, points squared.
%     SizeScale       "area"    "area" | "radius". "area" makes the AREA
%                               affine in the value; "radius" makes the
%                               radius affine, so area goes as the square.
%     Colormap        []        Defaults to the basemap's.
%     CLim            []        Defaults to the basemap's.
%     EdgeColor       [0 0 0]
%     EdgeWidth       0.5       Zero is accepted and means no edge, which
%                               v1 documented and then passed to a
%                               property that rejects it.
%     FaceAlpha       1
%     Legend          true      Draw the size legend, if there is SizeData.
%     LegendValues    []        Reference values; empty picks nice ones.
%     LegendLabel     ""
%     LegendLocation  "southeast"
%     LabelColor      [0 0 0]
%     FontName        "Helvetica"
%     FontSize        9
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Markers      (1,1) Scatter
%          Labels       (1,:) Text
%          Legend       struct or []  Axes, Circles, Labels.
%          NumDrawn     (1,1) double  Points with a finite position.
%          NumNoSize    (1,1) double  Points whose SizeData was missing.
%          CLim         (1,2) double
%          All          (1,:)
%
%   ACCURACY
%     One claim, and it is the one that makes the legend usable: a legend
%     circle for value v has the same drawn radius as a marker whose
%     SizeData is v. Asserted directly.
%
%   ERRORS
%     geo:overlayPoints:NoBasemap  - no crs and no basemap
%     geo:overlayPoints:NothingToDraw - no point has a finite position
%
%   EXAMPLE
%     P = geo.points(lon, lat, Obs = trend, SizeData = uncertainty);
%     H = geo.overlayPoints(ax, P, LegendLabel = "sigma (cm)");
%
%   LIMITATIONS
%     One scatter object for every point, so per-point marker shapes are
%     not possible. Labels are drawn where the point is and are not moved
%     out of each other's way.
%
%   See also GEO.POINTS, GEO.OVERLAYTRACK, GEO.INTERNAL.AVOIDRECTCOLLISIONS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    P
    crs = []
    options.Marker (1,1) string = "o"
    options.MarkerSize (1,1) double {mustBePositive} = 36
    options.SizeRange (1,2) double {mustBePositive} = [16 400]
    options.SizeScale (1,1) string {mustBeMember(options.SizeScale, ["area" "radius"])} = "area"
    options.Colormap double = []
    options.CLim double = []
    options.EdgeColor (1,3) double {mustBeInRange(options.EdgeColor, 0, 1)} = [0 0 0]
    options.EdgeWidth (1,1) double {mustBeNonnegative} = 0.5
    options.FaceAlpha (1,1) double {mustBeInRange(options.FaceAlpha, 0, 1)} = 1
    options.Legend (1,1) logical = true
    options.LegendValues double = []
    options.LegendLabel (1,1) string = ""
    options.LegendLocation (1,1) string = "southeast"
    options.LabelColor (1,3) double {mustBeInRange(options.LabelColor, 0, 1)} = [0 0 0]
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 9
end

P = geo.points(P);
[crs, lonLim, latLim, base] = geo.internal.elementExtent(axH, crs, ...
    ErrorId = "geo:overlayPoints:NoBasemap");

[x, y] = geo.project(P.Lon(:).', P.Lat(:).', crs);

% A MARKER CANNOT BE CUT. It is inside the frame or it is not, so the
% extent is applied as a mask rather than as a clip - the same rule the
% coastline is cut by, asked as a yes or no (PV-142). Before this, points
% outside the map were drawn beyond the frame, in the margin GEO.FRAME
% opens for its band.
B = geo.internal.mapBoundary(crs, [lonLim(1) lonLim(2)], ...
    [latLim(1) latLim(2)]);
keep = geo.internal.insideExtent(P.Lon(:).', P.Lat(:).', B);
if ~any(keep)
    error('geo:overlayPoints:NothingToDraw', ...
        ['None of the %d points falls inside the map. The extent is ' ...
         'longitude %g to %g, latitude %g to %g on %s; the map and the ' ...
         'points may be of different places.'], ...
        P.NumPoints, lonLim(1), lonLim(2), latLim(1), latLim(2), crs.Name);
end

obs = valueOrZero(P.Obs, P.NumPoints);
[cLim, cmap] = geo.internal.colourScale(base, obs(keep), ...
    Colormap = options.Colormap, CLim = options.CLim);
[areas, nNoSize, haveSize] = markerAreas(P.SizeData, keep, options);

prior = geo.internal.layout("data", axH, "points");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

rgb = reshape(geo.colormaps("truecolor", obs(keep), cmap, CLim = cLim), [], 3);
wasHeld = ishold(axH);
hold(axH, 'on');
markers = scatter3(axH, x(keep), y(keep), 5 * ones(1, nnz(keep)), ...
    areas, rgb, 'filled');
if ~wasHeld
    hold(axH, 'off');
end
markers.Marker = char(options.Marker);
markers.MarkerFaceAlpha = options.FaceAlpha;
if options.EdgeWidth > 0
    markers.MarkerEdgeColor = options.EdgeColor;
    markers.LineWidth = options.EdgeWidth;
else
    markers.MarkerEdgeColor = 'none';
end

labels = drawLabels(axH, x, y, keep, P.Labels, options);
legend = gobjects(1, 0);
legendStruct = [];
if options.Legend && haveSize
    legendStruct = drawLegend(axH, P.SizeData, options);
    legend = legendStruct.All;
end

H = struct('Markers', markers, 'Labels', labels, 'Legend', legendStruct, ...
    'NumDrawn', nnz(keep), 'NumNoSize', nNoSize, 'CLim', cLim, ...
    'All', [markers, labels, legend]);
geo.internal.layout("register", axH, "points", ...
    @(a) repositionLegend(a, options));
geo.internal.layout("setData", axH, "points", H);
repositionLegend(axH, options);
end

% ======================================================================
function v = valueOrZero(v, n)
if isempty(v)
    v = zeros(1, n);
else
    v = v(:).';
end
end

function [areas, nNoSize, haveSize] = markerAreas(sizeData, keep, options)
%MARKERAREAS  Value to marker area, with missing values kept distinct.
haveSize = ~isempty(sizeData);
if ~haveSize
    areas = options.MarkerSize * ones(1, nnz(keep));
    nNoSize = 0;
    return
end
sd = sizeData(:).';
sd = sd(keep);
nNoSize = nnz(~isfinite(sd));
areas = areaFor(sd, sizeData, options);
% A MISSING SIZE IS NOT THE SMALLEST SIZE. v1 mapped it to fraction zero.
areas(~isfinite(sd)) = options.MarkerSize;
end

function areas = areaFor(values, allSizeData, options)
%AREAFOR  The one place value becomes area. Used by markers AND legend.
lo = min(allSizeData(:), [], 'omitnan');
hi = max(allSizeData(:), [], 'omitnan');
if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
    areas = mean(options.SizeRange) * ones(size(values));
    return
end
frac = (values - lo) / (hi - lo);
frac = min(max(frac, 0), 1);
if options.SizeScale == "radius"
    r0 = sqrt(options.SizeRange(1));
    r1 = sqrt(options.SizeRange(2));
    areas = (r0 + frac * (r1 - r0)) .^ 2;
else
    areas = options.SizeRange(1) + frac * diff(options.SizeRange);
end
end

function r = radiusPtFor(area)
%RADIUSPTFOR  The drawn radius of a scatter marker of this SizeData.
%   MATLAB's scatter treats SizeData as the area of the marker's BOUNDING
%   BOX, so the radius is sqrt(area)/2 - NOT sqrt(area/pi), which is what
%   v1's legend used and which is 11% too small.
r = sqrt(area) / 2;
end

function labels = drawLabels(axH, x, y, keep, strs, options)
if isempty(strs)
    labels = gobjects(1, 0);
    return
end
strs = strs(:).';
idx = find(keep & strs ~= "");
labels = gobjects(1, numel(idx));
for k = 1:numel(idx)
    labels(k) = text('Parent', axH, ...
        'Position', [x(idx(k)) y(idx(k)) 5], ...
        'String', " " + strs(idx(k)), 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontName', options.FontName, ...
        'FontSize', options.FontSize, 'Color', options.LabelColor);
end
end

function S = drawLegend(axH, sizeData, options)
%DRAWLEGEND  Reference circles, drawn by the SAME rule as the markers.
values = options.LegendValues;
if isempty(values)
    lo = min(sizeData(:), [], 'omitnan');
    hi = max(sizeData(:), [], 'omitnan');
    values = geo.niceTicks(lo, hi);
    values = values(values >= lo & values <= hi);
    if isempty(values)
        values = [lo hi];
    end
    if numel(values) > 3
        values = values(round(linspace(1, numel(values), 3)));
    end
end
values = unique(values(isfinite(values)));
areas = areaFor(values, sizeData, options);
radii = radiusPtFor(areas);

gap = 6;
pad = 10;
textCol = 8 + 7 * max(strlength(compose("%g", values)));
w = 2 * max(radii) + 2 * pad + textCol;
h = sum(2 * radii) + gap * (numel(radii) - 1) + 2 * pad;
if options.LegendLabel ~= ""
    h = h + options.FontSize + gap;
end

lg = axes('Parent', ancestor(axH, 'figure'), 'Units', 'points', ...
    'Position', [0 0 w h], 'Color', 'none', 'XColor', 'none', ...
    'YColor', 'none', 'XLim', [0 w], 'YLim', [0 h], ...
    'XTick', [], 'YTick', []);
hold(lg, 'on');

[radii, order] = sort(radii, 'descend');
values = values(order);
cx = pad + max(radii);
yCursor = pad;
th = linspace(0, 2 * pi, 41);
circles = gobjects(1, numel(radii));
texts = gobjects(1, numel(radii));
for k = 1:numel(radii)
    cy = yCursor + radii(k);
    circles(k) = patch('Parent', lg, ...
        'XData', cx + radii(k) * cos(th), ...
        'YData', cy + radii(k) * sin(th), ...
        'FaceColor', 'none', 'EdgeColor', [0 0 0], 'LineWidth', 1);
    texts(k) = text('Parent', lg, 'Position', [cx + max(radii) + 6, cy], ...
        'String', sprintf('%g', values(k)), 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontName', options.FontName, ...
        'FontSize', options.FontSize);
    yCursor = cy + radii(k) + gap;
end
title = gobjects(1, 0);
if options.LegendLabel ~= ""
    title = text('Parent', lg, 'Position', [w / 2, h - pad / 2], ...
        'String', options.LegendLabel, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', 'FontName', options.FontName, ...
        'FontSize', options.FontSize, 'FontWeight', 'bold');
end

S = struct('Axes', lg, 'Circles', circles, 'Labels', texts, ...
    'Values', values, 'Radii', radii, ...
    'All', [lg, circles, texts, title]);
end

function repositionLegend(axH, options)
%REPOSITIONLEGEND  Keep the legend in its corner and off the furniture.
H = geo.internal.layout("data", axH, "points");
if isempty(H) || isempty(H.Legend) || ~isgraphics(H.Legend.Axes)
    return
end
box = geo.internal.plottedBox(axH);
pos = get(H.Legend.Axes, 'Position');
margin = 10;
if contains(options.LegendLocation, "west")
    x0 = box(1) + margin;
else
    x0 = box(1) + box(3) - margin - pos(3);
end
if contains(options.LegendLocation, "north")
    y0 = box(2) + box(4) - margin - pos(4);
else
    y0 = box(2) + margin;
end
rect = [x0 y0 pos(3) pos(4)];
obstacles = geo.internal.layout("rects", axH, "points");
if contains(options.LegendLocation, "south")
    dir = [0 1];
else
    dir = [0 -1];
end
rect = geo.internal.avoidRectCollisions(rect, obstacles, dir, Bounds = box);
set(H.Legend.Axes, 'Units', 'points', 'Position', rect);
geo.internal.layout("setRect", axH, "points", rect);
end
