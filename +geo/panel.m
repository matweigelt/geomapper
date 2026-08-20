function H = panel(spec, options)
%GEO.PANEL  Several maps and series in one figure, on one layout.
%
%   L4-FRONT
%
%   SYNTAX
%     H = GEO.PANEL(SPEC)
%     H = GEO.PANEL(SPEC, Name, Value)
%
%   DESCRIPTION
%     Lays out a figure of tiles and fills each one by calling the front
%     that owns it - GEO.MAP, GEO.TRACKMAP, GEO.POINTMAP or
%     GEO.TIMESERIES. It draws nothing itself and knows nothing about
%     maps; what it owns is the layout, the shared colour scale, the
%     linking, and the one geometric correction below.
%
%     THE HEIGHT CORRECTION, AND THE CONSTRAINT THAT FORCED IT. A map
%     axes uses `axis equal`, so its data fills only a centred
%     sub-rectangle of its tile; a series axes fills its whole tile. Two
%     equal tiles therefore look like two different heights, which is
%     the first thing a reader notices and the last thing they can
%     explain.
%
%     The obvious repair - move the series axes - IS NOT AVAILABLE.
%     TILEDLAYOUT forbids setting Position, InnerPosition or
%     OuterPosition on its children: the assignment warns and is
%     IGNORED, so the code appears to work and the figure does not
%     change. v1 found this and worked around it, and the workaround is
%     carried forward here deliberately rather than rediscovered: set
%     the series axes' PLOTBOXASPECTRATIO to [tileWidth, targetHeight, 1],
%     which tiledlayout does allow. The plot box then takes the tile's
%     full width and exactly that height, centred by the layout itself.
%
%     DO NOT "FIX" THIS WITH POSITION. It will look like it works.
%
%     THE TARGET HEIGHT IS THE MAP'S PLOTTED BOX, measured by
%     GEO.INTERNAL.PLOTTEDBOX - the same function the colorbar, the
%     inset, the frame and the title use. v1 carried its own copy of
%     that computation here, one of the five copies the duplicate-local
%     check exists to prevent (F6).
%
%     A SHARED COLOUR SCALE IS THE DEFAULT WHEN THERE IS MORE THAN ONE
%     MAP, because panels that are not comparable are worse than no
%     panels: a reader assumes a shared scale unless told otherwise, and
%     four maps with four silent colour limits invite exactly the wrong
%     conclusion. The limits come from every map's data together.
%
%   INPUTS
%     spec  (1,:) struct  One element per tile, with fields:
%             Type     "map" | "trackmap" | "pointmap" | "series"
%             Data     The grid, track, points or track array.
%             CRS      Optional, for the three map types.
%             Options  Optional cell of name-value pairs for that front.
%
%           Built in one line:
%             spec = struct('Type', {"map","series"}, ...
%                           'Data', {G, T}, ...
%                           'Options', {{'Title',"a"}, {'YLabel',"cm"}});
%
%   OPTIONS
%     Layout       [NaN NaN]  [rows cols]. NaN fills a near-square grid.
%     TileSpacing  "compact"
%     Padding      "compact"
%     SharedCLim   []         Empty means true when more than one tile
%                             is a map. A vector sets the limits.
%     Colorbar     "last"     "last" | "each" | "none". With a shared
%                             scale one bar describes every map, and
%                             "last" is that bar.
%     LinkX        true       Link the x limits of the series tiles.
%     EqualHeights true       The correction above.
%     Title        ""         Written to the layout's own Title.
%     FontName     "Helvetica"
%     FontSize     9
%     Export       ""
%     ExportOptions struct()
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Figure  (1,1) matlab.ui.Figure
%          Layout  (1,1) matlab.graphics.layout.TiledChartLayout
%          Axes    (1,:) matlab.graphics.axis.Axes  One per tile.
%          Tiles   (1,:) cell  Each front's own return value.
%          IsMap   (1,:) logical
%          CLim    (1,2) double  The shared scale, or NaN when not shared.
%
%   ACCURACY
%     One claim, and it is v1's own criterion carried forward
%     deliberately: the plotted heights of the map tiles agree within
%     2%. That is a VISUAL-EQUALITY threshold, not a numerical one - it
%     is the point at which a reader stops seeing two panels as the same
%     size - and it is stated as such rather than tightened to look
%     rigorous.
%
%   ERRORS
%     geo:panel:NoTiles      - an empty spec
%     geo:panel:UnknownType  - a Type that is not one of the four
%     geo:panel:LayoutTooSmall - a Layout with fewer cells than tiles
%
%   EXAMPLE
%     spec = struct('Type', {"map","map","series"}, ...
%                   'Data', {G2003, G2016, stations});
%     H = geo.panel(spec, Layout = [1 3], Title = "Mass change", ...
%                   Export = "figure4.pdf");
%
%   LIMITATIONS
%     NO PANEL LABELS - (a), (b), (c) - and they are left out rather
%     than improvised. A corner annotation is not a title and there is
%     no L3 element that draws one, so the Stage E rule says flag it.
%     Put the letter in each tile's own Title meanwhile.
%
%     The height correction matches a series to the map SHARING ITS ROW,
%     found by nearest tile centre. A layout where that is ambiguous
%     gets no correction rather than a guessed one.
%
%   See also GEO.MAP, GEO.TRACKMAP, GEO.POINTMAP, GEO.TIMESERIES.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    spec struct
    options.Layout (1,2) double = [NaN NaN]
    options.TileSpacing (1,1) string = "compact"
    options.Padding (1,1) string = "compact"
    options.SharedCLim double = []
    options.Colorbar (1,1) string {mustBeMember(options.Colorbar, ["last" "each" "none"])} = "last"
    options.LinkX (1,1) logical = true
    options.EqualHeights (1,1) logical = true
    options.Title (1,1) string = ""
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 9
    options.Export (1,1) string = ""
    options.ExportOptions struct = struct()
end

n = numel(spec);
if n == 0
    error('geo:panel:NoTiles', ...
        'The spec is empty. Give one element per tile.');
end
isMap = arrayfun(@(s) typeOf(s) ~= "series", spec);
[rows, cols] = gridFor(n, options.Layout);

figH = figure('Color', 'w');
tl = tiledlayout(figH, rows, cols, ...
    'TileSpacing', char(options.TileSpacing), ...
    'Padding', char(options.Padding));

cLim = sharedLimits(spec, isMap, options);
tiles = cell(1, n);
axList = gobjects(1, n);
for k = 1:n
    axList(k) = nexttile(tl);
    tiles{k} = fillTile(spec(k), axList(k), cLim, ...
        barFor(k, n, isMap, options), options);
end

if options.LinkX && nnz(~isMap) > 1
    linkaxes(axList(~isMap), 'x');
end
if strlength(options.Title) > 0
    tl.Title.String = char(options.Title);
    tl.Title.FontName = char(options.FontName);
end
if options.EqualHeights && any(isMap) && any(~isMap)
    matchHeights(axList, isMap);
    geo.internal.layout("register", axList(find(~isMap, 1)), "panelheights", ...
        @(~) matchHeights(axList, isMap));
end

H = struct('Figure', figH, 'Layout', tl, 'Axes', axList, ...
    'Tiles', {tiles}, 'IsMap', isMap, 'CLim', cLim);

if strlength(options.Export) > 0
    nv = namedargs2cell(options.ExportOptions);
    geo.export(figH, options.Export, nv{:});
end
end

% ======================================================================
function t = typeOf(s)
%TYPEOF  The tile's kind, defaulting to a map.
t = "map";
if isfield(s, 'Type') && strlength(string(s.Type)) > 0
    t = string(s.Type);
end
if ~any(t == ["map" "trackmap" "pointmap" "series"])
    error('geo:panel:UnknownType', ...
        ['"%s" is not a tile type. The four are map, trackmap, ' ...
         'pointmap and series.'], t);
end
end

function [rows, cols] = gridFor(n, wanted)
%GRIDFOR  The caller's layout, or the nearest thing to a square.
if all(isfinite(wanted))
    rows = wanted(1);
    cols = wanted(2);
    if rows * cols < n
        error('geo:panel:LayoutTooSmall', ...
            'A %dx%d layout has %d cells for %d tiles.', ...
            rows, cols, rows * cols, n);
    end
    return
end
cols = ceil(sqrt(n));
rows = ceil(n / cols);
end

function cLim = sharedLimits(spec, isMap, options)
%SHAREDLIMITS  One colour scale across every map, unless told otherwise.
%   Default ON for more than one map: a reader assumes panels are
%   comparable unless told they are not, and four maps with four silent
%   colour limits invite exactly the wrong conclusion.
cLim = [NaN NaN];
if isequal(options.SharedCLim, false) || nnz(isMap) < 2
    if numel(options.SharedCLim) == 2
        cLim = options.SharedCLim(:).';
    end
    return
end
if numel(options.SharedCLim) == 2
    cLim = options.SharedCLim(:).';
    return
end
% Collected and joined once (F13).
parts = cell(1, numel(spec));
for k = 1:numel(spec)
    if ~isMap(k), continue, end
    parts{k} = valuesOf(spec(k));
end
v = vertcat(parts{:});
v = v(isfinite(v));
if isempty(v)
    return
end
cLim = geo.quantile(v, [2 98]);
if cLim(1) == cLim(2)
    cLim = cLim + [-1 1];
end
end

function v = valuesOf(s)
%VALUESOF  The field a map tile will colour by, as a column.
d = s.Data;
if isstruct(d) && isfield(d, 'Z')
    v = double(d.Z(:));
elseif isstruct(d) && isfield(d, 'Obs')
    v = double(d.Obs(:));
else
    v = [];
end
end

function bar = barFor(k, n, isMap, options)
%BARFOR  Which tiles get a colorbar, given the shared scale.
switch options.Colorbar
    case "each",  bar = isMap(k);
    case "none",  bar = false;
    otherwise,    bar = isMap(k) && k == find(isMap, 1, 'last');
end
if ~isMap(k)
    bar = false;
end
end

function out = fillTile(s, axH, cLim, bar, options)
%FILLTILE  Hand the tile to the front that owns it, and nothing more.
nv = tileOptions(s);
nv = [nv, {'Parent'}, {axH}, {'FontName'}, {char(options.FontName)}, ...
      {'FontSize'}, {options.FontSize}];
t = typeOf(s);
if t == "series"
    out = geo.timeseries(s.Data, nv{:});
    return
end
nv = [nv, {'Colorbar'}, {bar}];
if all(isfinite(cLim))
    nv = geo.internal.withData(nv, "Basemap", struct('CLim', cLim));
end
crs = [];
if isfield(s, 'CRS')
    crs = s.CRS;
end
switch t
    case "map",       out = geo.map(s.Data, crs, nv{:});
    case "trackmap",  out = geo.trackmap(s.Data, crs, nv{:});
    otherwise,        out = geo.pointmap(s.Data, crs, nv{:});
end
end

function nv = tileOptions(s)
%TILEOPTIONS  The caller's own options for this tile.
nv = {};
if isfield(s, 'Options') && ~isempty(s.Options)
    nv = s.Options;
    if ~iscell(nv)
        nv = {nv};
    end
end
end

function matchHeights(axList, isMap)
%MATCHHEIGHTS  v1's mechanism, carried forward with its constraint.
%   TILEDLAYOUT IGNORES Position on its children - the assignment warns
%   and does nothing - so the series axes is reshaped instead, by giving
%   it a plot-box aspect of [tileWidth, targetHeight, 1]. See this
%   file's help; do not replace this with Position.
drawnow;
maps = axList(isMap);
series = axList(~isMap);
if isempty(maps) || isempty(series)
    return
end
[midY, contentH] = mapGeometry(maps);
for a = series(:).'
    if ~isvalid(a), continue, end
    tile = inPoints(a);
    [dY, hit] = min(abs(midY - (tile(2) + tile(4) / 2)));
    if dY > 0.5 * tile(4) || ~isfinite(contentH(hit)) || tile(3) <= 0
        continue        % no map shares this row; leave it alone
    end
    target = min(contentH(hit), tile(4));
    if target > 0
        a.PlotBoxAspectRatioMode = 'manual';
        a.PlotBoxAspectRatio = [tile(3), target, 1];
    end
end
end

function [midY, contentH] = mapGeometry(maps)
%MAPGEOMETRY  Each map's tile centre and its PLOTTED height.
%   GEO.INTERNAL.PLOTTEDBOX, not a local copy: v1 carried its own here,
%   one of the five the duplicate-local check exists to prevent (F6).
midY = nan(1, numel(maps));
contentH = nan(1, numel(maps));
for k = 1:numel(maps)
    if ~isvalid(maps(k)), continue, end
    tile = inPoints(maps(k));
    box = geo.internal.plottedBox(maps(k));
    midY(k) = tile(2) + tile(4) / 2;
    contentH(k) = box(4);
end
end

function p = inPoints(axH)
%INPOINTS  The axes rectangle in points, read and put back.
u = axH.Units;
axH.Units = 'points';
p = axH.Position;
axH.Units = u;
end
