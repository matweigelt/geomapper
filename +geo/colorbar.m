function H = colorbar(axH, options)
%GEO.COLORBAR  One colour scale, in four styles.
%
%   SYNTAX
%     H = GEO.COLORBAR(AX)
%     H = GEO.COLORBAR(AX, Name, Value)
%
%   DESCRIPTION
%     Replaces FOUR near-identical implementations in v1: the native
%     path, `geoGmtColorbar`, two byte-identical copies of
%     `localAddHalfColorbar` in different files, and
%     `localAddDualScaleColorbar`. They shared the plotted-box
%     computation verbatim, the redraw-callback skeleton verbatim, the
%     colour-strip loop, the box outline, the tick loop and the centred
%     label - and differed in about a dozen constants, several of which
%     were three different estimates of the same text line height.
%
%     THE STRIP IS ONE SURFACE, NOT 256 PATCHES. v1 drew one `patch` per
%     colour, capped at 256, plus two objects per tick: a continuous GMT
%     bar came to about 283 handles. Here the strip is a single truecolor
%     `surface`, every tick mark is one NaN-separated `line`, and a
%     five-tick bar is eleven objects. v1's comment says `image` was
%     rejected because its two-element XData denotes pixel CENTRES and
%     leaves a half-pixel overhang; that is true of `image` and not of a
%     `surface`, whose XData are the cell EDGES, so the ambiguity that
%     motivated the patch loop does not arise.
%
%     THE RETURNED HANDLES DO NOT GO STALE, which all three of v1's
%     custom bars did. They captured the handles created by the first
%     draw and then deleted and recreated them on every resize, so
%     `H.Colorbar` was entirely invalid handles after the user touched
%     the window once. Here the live handles live in the layout registry
%     and the struct is refreshed with them.
%
%     AN END CAP MEANS "THE DATA CONTINUES", which is what the GMT
%     convention it was copied from means and what v1 did not do. v1 drew
%     both triangles whenever Arrows was on and only varied their COLOUR
%     by whether data actually exceeded the limits - so a bar with no
%     out-of-range data still grew two arrowheads announcing that there
%     was some. With Arrows = "auto" a cap appears on an end only where
%     data really lies beyond it.
%
%     THE LAYOUT IS DERIVED FROM THE CONTENT, not from a flat constant.
%     v1's half colorbar reserved 34 points below the bar and drew the
%     tick numbers and the axis label into overlapping bands - about 14
%     points of overlap whenever a label was set - while leaving 15
%     points of dead space above the bar that nothing was ever drawn in.
%     Its dual-scale sibling had already been rewritten to measure, and
%     that is the version kept.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%
%   OPTIONS
%     Style      "gmt"     "gmt" | "native" | "half" | "dual".
%     Location   "southoutside"  Also north/east/westoutside.
%     Label      ""
%     LabelSide  "far"     "far" | "near" - which side of the bar the
%                          label sits on. NOT "left"/"right": on a
%                          vertical bar those named the wrong axis in v1
%                          and meant bottom and top.
%     Arrows     "auto"    "auto" | "on" | "off". See DESCRIPTION.
%     Subticks   "auto"    Count per interval, or "auto" (3 continuous,
%                          0 discrete).
%     Length     0.6       Bar length, as a fraction of the map's side.
%     Thickness  12        Bar thickness, in points.
%     CLim       []        Defaults to the basemap's.
%     Colormap   []        Defaults to the basemap's.
%     DiscreteLevels NaN   Draw N blocks with separators.
%     SecondCLim  []       "dual" only: the second field's limits.
%     SecondLabel ""       "dual" only.
%     FontName   "Helvetica"
%     FontSize   9
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Axes      the colorbar's own axes, or the native ColorBar
%          Strip     (1,1) Surface, or empty for "native"
%          Ticks     (1,1) Line, NaN-separated; empty for "native"
%          Labels    (1,:) Text
%          Caps      (1,:) Patch  0, 1 or 2 of them
%          CLim      (1,2) double
%          Style     (1,1) string
%          All       (1,:)
%
%   ACCURACY
%     One geometric claim, and it is asserted: the position along the bar
%     of the tick for value v is (v - CLim(1))/diff(CLim) exactly, in the
%     bar's own coordinates. Everything else here is layout, which has no
%     correct answer to be accurate about.
%
%   ERRORS
%     geo:colorbar:NoBasemap    - the axes carries no basemap, and no
%                                 CLim and Colormap were given either
%     geo:colorbar:NoSecondCLim - Style = "dual" without SecondCLim
%     geo:colorbar:BadLocation  - a location that is not one of the four
%
%   EXAMPLE
%     G = geo.readGrid("data/etopo_10min_surface.mat", Units = "m");
%     [~, ax] = geo.basemap(G, geo.crs("robinson"));
%     H = geo.colorbar(ax, Label = "elevation (m)");
%
%   LIMITATIONS
%     The four "inside" locations v1's validator accepted are not
%     accepted here. v1 took them and then ignored them - its reposition
%     callback returned early unless the name ended in "outside" - so
%     they were a documented option that did nothing. Rejecting them is
%     the smaller lie.
%
%   See also GEO.BASEMAP, GEO.COLORMAPS, GEO.INTERNAL.LAYOUT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    options.Style (1,1) string {mustBeMember(options.Style, ["gmt" "native" "half" "dual"])} = "gmt"
    options.Location (1,1) string = "southoutside"
    options.Label (1,1) string = ""
    options.LabelSide (1,1) string {mustBeMember(options.LabelSide, ["far" "near"])} = "far"
    options.Arrows (1,1) string {mustBeMember(options.Arrows, ["auto" "on" "off"])} = "auto"
    options.Subticks = "auto"
    options.Length (1,1) double {mustBePositive} = 0.6
    options.Thickness (1,1) double {mustBePositive} = 12
    options.CLim double = []
    options.Colormap double = []
    options.DiscreteLevels (1,1) double = NaN
    options.SecondCLim double = []
    options.SecondLabel (1,1) string = ""
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 9
end

known = ["southoutside" "northoutside" "eastoutside" "westoutside"];
if ~any(options.Location == known)
    error('geo:colorbar:BadLocation', ...
        ['"%s" is not a colorbar location. Known: %s. v1 also accepted ' ...
         'four "inside" names and then ignored them, which is why they ' ...
         'are not accepted here.'], options.Location, strjoin(known, ", "));
end
if options.Style == "dual" && isempty(options.SecondCLim)
    error('geo:colorbar:NoSecondCLim', ...
        ['Style = "dual" draws two scales on one bar and needs ' ...
         'SecondCLim to know what the second one is.']);
end

[cLim, cmap] = colourFrom(axH, options);
prior = geo.internal.layout("data", axH, "colorbar");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

if options.Style == "native"
    H = drawNative(axH, cLim, options);
else
    H = drawBar(axH, cLim, cmap, options);
end
H.CLim = cLim;
H.Style = options.Style;

geo.internal.layout("register", axH, "colorbar", ...
    @(a) reposition(a, options));
geo.internal.layout("setData", axH, "colorbar", H);
end

% ======================================================================
function [cLim, cmap] = colourFrom(axH, options)
%COLOURFROM  The basemap's colour scale, unless told otherwise.
%   One source of truth: a colorbar that disagreed with the map it sits
%   beside would be worse than no colorbar.
cLim = options.CLim;
cmap = options.Colormap;
if isempty(cLim) || isempty(cmap)
    base = geo.internal.layout("data", axH, "basemap");
    if isempty(base)
        error('geo:colorbar:NoBasemap', ...
            ['These axes carry no basemap, so there is no colour scale ' ...
             'to describe. Call geo.basemap first, or pass CLim and ' ...
             'Colormap.']);
    end
    if isempty(cLim), cLim = base.CLim; end
    if isempty(cmap), cmap = base.Colormap; end
end
if ~isnan(options.DiscreteLevels)
    cmap = geo.colormaps("discretize", cmap, options.DiscreteLevels);
end
end

function H = drawNative(axH, cLim, options)
%DRAWNATIVE  MATLAB's own colorbar, with the ticks we asked for.
cb = colorbar(axH, char(options.Location));
cb.Label.String = options.Label;
cb.FontName = options.FontName;
cb.FontSize = options.FontSize;
if ~isnan(options.DiscreteLevels)
    cb.Ticks = linspace(cLim(1), cLim(2), round(options.DiscreteLevels) + 1);
end
H = struct('Axes', cb, 'Strip', gobjects(1, 0), 'Ticks', gobjects(1, 0), ...
    'Labels', gobjects(1, 0), 'Caps', gobjects(1, 0), 'All', cb);
end

function H = drawBar(axH, cLim, cmap, options)
%DRAWBAR  The custom bar, in its own axes measured in points.
geom = layoutOf(axH, options);
cbAx = axes('Parent', ancestor(axH, 'figure'), 'Units', 'points', ...
    'Position', geom.Position, 'Color', 'none', 'XColor', 'none', ...
    'YColor', 'none', 'XLim', [0 geom.Width], 'YLim', [0 geom.Height], ...
    'XTick', [], 'YTick', []);
hold(cbAx, 'on');

strip = drawStrip(cbAx, geom, cmap);
box = line('Parent', cbAx, 'Color', [0 0 0], 'LineWidth', 1, ...
    'XData', geom.BarX([1 2 2 1 1]), 'YData', geom.BarY([1 1 2 2 1]));

[ticks, labels] = drawTicks(cbAx, geom, cLim, options, "primary");
caps = drawCaps(cbAx, axH, geom, cmap, cLim, options);

extra = gobjects(1, 0);
if options.Style == "dual"
    [t2, l2] = drawTicks(cbAx, geom, options.SecondCLim, options, "secondary");
    extra = [t2, l2];
end
if options.Label ~= ""
    labels(end + 1) = axisLabel(cbAx, geom, options.Label, "primary", options);
end
if options.Style == "dual" && options.SecondLabel ~= ""
    labels(end + 1) = axisLabel(cbAx, geom, options.SecondLabel, ...
        "secondary", options);
end

H = struct('Axes', cbAx, 'Strip', strip, 'Ticks', ticks, ...
    'Labels', labels, 'Caps', caps, ...
    'All', [cbAx, strip, box, ticks, labels, caps, extra]);
end

function geom = layoutOf(axH, options)
%LAYOUTOF  Every position this bar needs, in points, derived from content.
%   v1 reserved a flat 34 points below the bar and then drew tick numbers
%   and the axis label into overlapping bands. Here each row of content
%   contributes its own height and they are stacked.
box = geo.internal.plottedBox(axH);
% PV-152: the plotted box is the MAP, and the graticule's labels sit
% outside it. Anchoring to the box alone put this bar's tick numbers
% through the longitude label row on the toolbox's own showcase call.
over = geo.internal.labelOverhang(axH);
isHoriz = any(options.Location == ["southoutside" "northoutside"]);
% MEASURED, NOT DERIVED (R3, and the third time this rule has been
% paid for in one round). FontSize * 1.4 is an ESTIMATE of a line's
% height, and it is font-dependent: it was adequate for Helvetica on
% Windows and it under-reports on the CI runner's default font, where
% the number band and the label band then overlapped by 21.2 points.
% The estimate cannot be tuned - a factor that fits two fonts will miss
% a third - so the height is read from a real text object instead.
lineH = measuredLineHeight(axH, options.FontName, options.FontSize);
tickLen = 5;
tickGap = 3;

numberBand = tickLen + tickGap + lineH;
labelBand = 0;
if options.Label ~= "" || options.SecondLabel ~= ""
    labelBand = lineH + 3;
end
secondBand = 0;
if options.Style == "dual"
    secondBand = numberBand + labelBand;
end

if isHoriz
    barLen = options.Length * box(3);
else
    barLen = options.Length * box(4);
end
across = options.Thickness + numberBand + labelBand + secondBand;

geom = struct('IsHoriz', isHoriz, 'TickLen', tickLen, 'TickGap', tickGap, ...
    'LineH', lineH, 'Thickness', options.Thickness, ...
    'NumberBand', numberBand, 'SecondBand', secondBand, ...
    'BarLength', barLen);

% The bar sits at the far edge of its own box, leaving the near side for
% the numbers and label; "dual" leaves a matching band on the other side.
if isHoriz
    geom.Width = barLen;
    geom.Height = across;
    geom.BarX = [0 barLen];
    geom.BarY = [numberBand + labelBand, numberBand + labelBand + options.Thickness];
else
    geom.Width = across;
    geom.Height = barLen;
    geom.BarX = [numberBand + labelBand, numberBand + labelBand + options.Thickness];
    geom.BarY = [0 barLen];
end
geom.Position = anchorBox(box, over, geom, options);
end

function h = measuredLineHeight(axH, fontName, fontSize)
%MEASUREDLINEHEIGHT  A line's height in points, read rather than assumed.
%   The probe carries an ascender, a descender and a bracket, so the
%   answer covers the tallest thing a tick label or an axis caption can
%   contain. It is created invisible, measured, and deleted on every
%   path - a layout computation may not leave anything on the figure.
probe = text('Parent', axH, 'Units', 'points', 'Position', [0 0], ...
    'String', "0123456789 [Ay]", 'FontName', fontName, ...
    'FontSize', fontSize, 'Visible', 'off');
cleanup = onCleanup(@() delete(probe));
e = get(probe, 'Extent');
h = e(4);
end

function pos = anchorBox(box, over, geom, options)
%ANCHORBOX  Where the bar's axes goes, in figure points.
%   OVER is how far the graticule's labels reach past BOX on each side,
%   [left right bottom top]. Only the side this bar is going gets it: a
%   southoutside bar must clear the bottom label row and has no reason to
%   move sideways because a latitude label sticks out on the left.
gap = 8;
switch options.Location
    case "southoutside"
        pos = [box(1) + (box(3) - geom.Width) / 2, ...
               box(2) - gap - over(3) - geom.Height, geom.Width, geom.Height];
    case "northoutside"
        pos = [box(1) + (box(3) - geom.Width) / 2, ...
               box(2) + box(4) + gap + over(4), geom.Width, geom.Height];
    case "westoutside"
        pos = [box(1) - gap - over(1) - geom.Width, ...
               box(2) + (box(4) - geom.Height) / 2, geom.Width, geom.Height];
    otherwise
        pos = [box(1) + box(3) + gap + over(2), ...
               box(2) + (box(4) - geom.Height) / 2, geom.Width, geom.Height];
end
% Keep it on the figure. v1 clamped twice with two different constants
% doing the same job, the first pass entirely superseded by the second.
pos(1) = max(pos(1), 2);
pos(2) = max(pos(2), 2);
end

function s = drawStrip(cbAx, geom, cmap)
%DRAWSTRIP  The colour ramp: ONE surface, not one patch per colour.
n = size(cmap, 1);
rgb = reshape(cmap, [1 n 3]);
edges = linspace(0, geom.BarLength, n + 1);
if geom.IsHoriz
    [X, Y] = meshgrid(edges, geom.BarY);
else
    [Y, X] = meshgrid(edges, geom.BarX);
    rgb = permute(rgb, [2 1 3]);
end
s = surface('Parent', cbAx, 'XData', X, 'YData', Y, ...
    'ZData', zeros(size(X)), 'CData', rgb, ...
    'FaceColor', 'flat', 'EdgeColor', 'none', 'FaceLighting', 'none');
end

function [tickLine, labels] = drawTicks(cbAx, geom, cLim, options, which)
%DRAWTICKS  Every tick as ONE NaN-separated line; one text per number.
[main, sub] = tickValues(cLim, options);
[xa, ya, xb, yb] = tickEnds(geom, which, geom.TickLen);
[xsa, ysa, xsb, ysb] = tickEnds(geom, which, geom.TickLen * 0.6);

n = numel(main);
xs = NaN(1, 3 * n);
ys = xs;
for k = 1:n
    f = frac(main(k), cLim);
    p = f * geom.BarLength;
    [x1, y1] = along(geom, p, xa, ya);
    [x2, y2] = along(geom, p, xb, yb);
    xs(3 * k - 2:3 * k - 1) = [x1 x2];
    ys(3 * k - 2:3 * k - 1) = [y1 y2];
end
m = numel(sub);
xs2 = NaN(1, 3 * m);
ys2 = xs2;
for k = 1:m
    p = frac(sub(k), cLim) * geom.BarLength;
    [x1, y1] = along(geom, p, xsa, ysa);
    [x2, y2] = along(geom, p, xsb, ysb);
    xs2(3 * k - 2:3 * k - 1) = [x1 x2];
    ys2(3 * k - 2:3 * k - 1) = [y1 y2];
end
tickLine = line('Parent', cbAx, 'XData', [xs xs2], 'YData', [ys ys2], ...
    'Color', [0 0 0], 'LineWidth', 0.75);

labels = gobjects(1, n);
for k = 1:n
    p = frac(main(k), cLim) * geom.BarLength;
    [x2, y2] = along(geom, p, xb, yb);
    [ha, va] = numberAlignment(geom, which);
    off = geom.TickGap * signOf(which);
    if geom.IsHoriz
        labels(k) = text('Parent', cbAx, 'Position', [x2, y2 + off, 0], ...
            'String', sprintf('%g', main(k)), 'HorizontalAlignment', ha, ...
            'VerticalAlignment', va, 'FontName', options.FontName, ...
            'FontSize', options.FontSize, 'Clipping', 'off');
    else
        labels(k) = text('Parent', cbAx, 'Position', [x2 + off, y2, 0], ...
            'String', sprintf('%g', main(k)), 'HorizontalAlignment', ha, ...
            'VerticalAlignment', va, 'FontName', options.FontName, ...
            'FontSize', options.FontSize, 'Clipping', 'off');
    end
end
end

function [main, sub] = tickValues(cLim, options)
%TICKVALUES  Nice ticks, or block boundaries when discrete.
if ~isnan(options.DiscreteLevels)
    main = linspace(cLim(1), cLim(2), round(options.DiscreteLevels) + 1);
    nSub = 0;
else
    main = geo.niceTicks(cLim(1), cLim(2));
    nSub = 3;
end
if ~(isstring(options.Subticks) || ischar(options.Subticks))
    nSub = round(options.Subticks);
end
nGap = max(numel(main) - 1, 0);
sub = zeros(1, nSub * nGap);
for k = 1:nGap
    step = (main(k + 1) - main(k)) / (nSub + 1);
    sub((k - 1) * nSub + (1:nSub)) = main(k) + step * (1:nSub);
end
main = main(main >= cLim(1) - eps & main <= cLim(2) + eps);
end

function f = frac(v, cLim)
%FRAC  Where a value sits along the bar. THE one geometric claim.
f = (v - cLim(1)) / (cLim(2) - cLim(1));
end

function [xa, ya, xb, yb] = tickEnds(geom, which, len)
%TICKENDS  The two cross-bar coordinates a tick runs between.
s = signOf(which);
if s < 0
    base = geom.BarY(1);
    if ~geom.IsHoriz, base = geom.BarX(1); end
    a = base;
    b = base - len;
else
    base = geom.BarY(2);
    if ~geom.IsHoriz, base = geom.BarX(2); end
    a = base;
    b = base + len;
end
xa = a;  ya = a;  xb = b;  yb = b;
end

function [x, y] = along(geom, p, crossA, crossB) %#ok<INUSD>
%ALONG  A point at distance P along the bar, at cross-coordinate CROSSA.
if geom.IsHoriz
    x = p;
    y = crossA;
else
    x = crossA;
    y = p;
end
end

function s = signOf(which)
%SIGNOF  Primary ticks below/left of the bar, secondary above/right.
if which == "secondary"
    s = 1;
else
    s = -1;
end
end

function [ha, va] = numberAlignment(geom, which)
if geom.IsHoriz
    ha = 'center';
    if signOf(which) < 0, va = 'top'; else, va = 'bottom'; end
else
    va = 'middle';
    if signOf(which) < 0, ha = 'right'; else, ha = 'left'; end
end
end

function h = axisLabel(cbAx, geom, str, which, options)
%AXISLABEL  The bar's own caption, outside its numbers.
s = signOf(which);
off = geom.NumberBand + 2;
if geom.IsHoriz
    if s < 0
        y = geom.BarY(1) - off;
        va = 'top';
    else
        y = geom.BarY(2) + off;
        va = 'bottom';
    end
    h = text('Parent', cbAx, 'Position', [geom.BarLength / 2, y, 0], ...
        'String', str, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', va, 'FontName', options.FontName, ...
        'FontSize', options.FontSize, 'Clipping', 'off');
else
    if s < 0
        x = geom.BarX(1) - off;
        va = 'bottom';
    else
        x = geom.BarX(2) + off;
        va = 'top';
    end
    h = text('Parent', cbAx, 'Position', [x, geom.BarLength / 2, 0], ...
        'String', str, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', va, 'Rotation', 90, ...
        'FontName', options.FontName, 'FontSize', options.FontSize, ...
        'Clipping', 'off');
end
end

function caps = drawCaps(cbAx, axH, geom, cmap, cLim, options)
%DRAWCAPS  A triangle where the data continues past the bar.
%   "auto" is the whole point: a cap MEANS the data goes on beyond this
%   end, which is the GMT convention v1 cited and did not implement - it
%   drew both triangles whenever Arrows was on and only varied their
%   colour. A bar with nothing out of range grew two arrowheads
%   announcing that there was some.
caps = gobjects(1, 0);
if options.Arrows == "off"
    return
end
[lo, hi] = outOfRange(axH, options);
capLen = 10;
mid = mean(geom.BarY);
if ~geom.IsHoriz
    mid = mean(geom.BarX);
end
if lo
    caps(end + 1) = capPatch(cbAx, geom, 0, -capLen, mid, cmap(1, :));
end
if hi
    caps(end + 1) = capPatch(cbAx, geom, geom.BarLength, capLen, mid, ...
        cmap(end, :));
end
end

function [lo, hi] = outOfRange(axH, options)
%OUTOFRANGE  Does the data actually continue past either end?
%   The answer is GEO.BASEMAP's - it computed the limits and it has the
%   field - so it is read from the layout registry rather than recovered
%   from the drawn surface. Nothing searches for anything.
if options.Arrows == "on"
    lo = true;
    hi = true;
    return
end
lo = false;
hi = false;
base = geo.internal.layout("data", axH, "basemap");
if isempty(base)
    return
end
lo = base.HasUnder;
hi = base.HasOver;
end

function h = capPatch(cbAx, geom, atP, len, mid, colour)
%CAPPATCH  One isoceles triangle, apex pointing away from the bar.
if geom.IsHoriz
    x = [atP + len, atP, atP];
    y = [mid, geom.BarY(1), geom.BarY(2)];
else
    x = [mid, geom.BarX(1), geom.BarX(2)];
    y = [atP + len, atP, atP];
end
h = patch('Parent', cbAx, 'XData', x, 'YData', y, ...
    'FaceColor', colour, 'EdgeColor', [0 0 0], 'LineWidth', 1, ...
    'FaceLighting', 'none');
end

function reposition(axH, options)
%REPOSITION  Move the bar with the map, without redrawing its contents.
%   The bar's contents are in points and do not change with the figure,
%   so a resize moves one Position and touches nothing else. v1 deleted
%   and rebuilt every handle on every resize, which is why the handles it
%   returned were stale by the time anybody used them.
H = geo.internal.layout("data", axH, "colorbar");
if isempty(H) || ~isgraphics(H.Axes) || options.Style == "native"
    return
end
geom = layoutOf(axH, options);
set(H.Axes, 'Units', 'points', 'Position', geom.Position);
end
