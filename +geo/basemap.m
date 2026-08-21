function [figH, axH, H] = basemap(G, crs, options)
%GEO.BASEMAP  Draw a projected raster: one surface, no lights.
%
%   SYNTAX
%     [figH, axH, H] = GEO.BASEMAP(G, CRS)
%     [figH, axH, H] = GEO.BASEMAP(G, CRS, Name, Value)
%
%   DESCRIPTION
%     The one raster engine. v1 had three near-copies of it inside a
%     3413-line function and its two clones (defect F8); every element in
%     Stage D composes with this one instead.
%
%     THE SHADING IS COMPUTED, NOT LIT, and this is the largest single
%     departure from v1. v1 drew a genuine three-dimensional surface
%     whose ZData was exaggerated topography, then called `light`,
%     `material` and `shading interp` and let OpenGL shade it. The result
%     depended on the renderer, the graphics driver and the view, which
%     is defect F9: two machines produced different figures from the same
%     data and neither was reproducible in a test. Here GEO.HILLSHADE
%     computes an intensity array, GEO.COLORMAPS composites it into
%     truecolor, and the surface is flat at z = 0 with `FaceColor` flat.
%     The output is a deterministic array of numbers, which is why the
%     shading can be asserted at all. D-009, and the static audit rejects
%     `light`, `material` and `shading` anywhere in +geo.
%
%     ONE SURFACE, DRAWN FLAT AT z = 0. Everything else in the toolbox
%     stacks above it on the documented z-ladder: contours and polygons
%     at 2, graticule 3, coastline 4, overlays 5, frame 6. With `view(2)`
%     that ladder is what decides occlusion, so an element's z is part of
%     its contract rather than a drawing-order accident.
%
%     NOTHING HERE CLIPS. Every out-of-domain point is already NaN when
%     GEO.PROJECT returns it, because CRS.Domain declares the limit and
%     GEO.PROJECT reads it. v1 carried a private `localVisibleRadiusDeg`
%     table that had to be kept in step with a second copy inside its
%     frame function, and the two drifted - defect F12. There is one
%     table now and it is in GEO.CRS.
%
%     NaN IS TRANSPARENT, NOT COLOURED. Missing cells get `FaceAlpha`
%     flat with zero alpha and the axes background shows through, so
%     NaNColor is the axes colour. This was unsafe in v1 because
%     `shading interp` interpolated colour across the boundary of a
%     transparent cell; with flat faces it is exact - a cell is either
%     drawn or it is not.
%
%     IDEMPOTENT. A second call on the same axes REPLACES the surface
%     rather than drawing a second one over it. The previous handle comes
%     from the layout registry, not from a tag search: §2.7 bans
%     `findobj`, because a tag search finds whatever else carries that
%     tag. Asserted by a constant handle count, not described.
%
%   INPUTS
%     G    (1,1) struct  A GEO.GRID. A bare matrix is rejected by
%                        GEO.GRID rather than guessed at.
%     crs  (1,1) struct  A GEO.CRS, or a projection name.
%
%   OPTIONS
%     Colormap        (:,3) double  []      Explicit RGB; overrides the
%                                           name when non-empty.
%     ColormapName    (1,1) string  "viridis"
%     CLim            (1,2) double  [NaN NaN]  Explicit colour limits.
%     CLimMode        (1,1) string  "auto"  "auto" | "percentile".
%     CLimPercentile  (1,2) double  [2 98]
%     DiscreteLevels  (1,1) double  NaN     Quantise into N blocks.
%     Divergent       (1,1) logical false   Symmetric limits about zero,
%                                           via GEO.SYMMETRICLIMITS. NEW
%                                           in v2: v1 had no such option,
%                                           only a diverging colormap
%                                           name, so a signed anomaly
%                                           field got asymmetric limits
%                                           and a false zero.
%     Hillshade       (1,1) string  "single"  "single" | "multi" | "off".
%     Azimuth         (1,1) double  315     Light direction, deg cw of N.
%     Elevation       (1,1) double  45      Light height above horizon.
%     Ambient         (1,1) double  0.35    Shade floor.
%     NaNColor        (1,3) double  [1 1 1] Axes background.
%     Mask            logical       []      True where MaskColor applies.
%     MaskMethod      (1,1) string  "explicit"  "explicit" | "threshold"
%                                           | "polygon".
%     MaskThreshold   (1,1) double  NaN     Mask where Z < this.
%     MaskPolygon     (:,2) double  []      Lon/lat outline.
%     MaskPolygonSide (1,1) string  "outside"  Which side is masked.
%     MaskColor       (1,3) double  [0.7 0.7 0.7]
%     Parent          []            Axes to draw into; a new figure
%                                   otherwise.
%
%   OUTPUTS
%     figH  (1,1) matlab.ui.Figure
%     axH   (1,1) matlab.graphics.axis.Axes
%     H     (1,1) struct  Named handles and the numbers behind them:
%             Surface      the one Surface object
%             CLim         (1,2) double  as used, after every rule
%             Colormap     (:,3) double  as used, after discretising
%             Shade        (M,N) double  the intensity array, or []
%             DataLimits   (1,1) struct  XLim/YLim of the projected data
%                                        BEFORE any element widened them.
%                                        The frame sets rather than
%                                        unions from these - see
%                                        LIMITATIONS.
%             LonLimit     (1,2) double  Geographic extent actually
%             LatLimit     (1,2) double  drawn, AFTER the longitude roll.
%                                    back to the first, so the extent is
%                                    a full turn even though LonLimit
%                                    spans 360 minus one step (PV-138).
%                                        GEO.GRATICULE and GEO.FRAME read
%                                        these rather than asking the
%                                        axes, because the axes knows
%                                        only projected units by then.
%             HasUnder     (1,1) logical  Data lies below CLim(1), and
%             HasOver      (1,1) logical  above CLim(2). GEO.COLORBAR
%                                        draws an end cap only where one
%                                        of these is true, because a cap
%                                        MEANS the data continues.
%             Crs          (1,1) struct
%
%   ACCURACY
%     No numerical claim of its own beyond arithmetic already asserted
%     elsewhere: the projection is Stage B's and is certified against
%     PROJ, the shading is Stage B's and is certified against
%     `gdaldem hillshade`, and the colour mapping is Stage B's. What this
%     function adds is composition, and the property asserted for it is
%     exact: with Hillshade = "off" the CData equals
%     GEO.COLORMAPS("truecolor", ...) called without Shade, bit for bit.
%
%   ERRORS
%     Input:
%       geo:basemap:MaskSizeMismatch    - Mask is not the size of Z
%       geo:basemap:MaskMethodMismatch  - the MaskMethod given needs an
%                                         input that was not supplied
%       geo:basemap:NothingToDraw       - every cell projected to NaN, so
%                                         the extent lies wholly outside
%                                         the projection's domain
%     A bare matrix, a non-monotone axis or a transposed Z is rejected by
%     GEO.GRID, and an unknown projection by GEO.CRS; neither is
%     re-checked here.
%
%   WARNINGS
%     geo:basemap:MaskCoversEverything  - the mask is true everywhere, so
%                                         the map is one flat colour
%     geo:basemap:MaskCoversNothing     - the mask is false everywhere,
%                                         so it had no effect at all
%
%   EXAMPLE
%     G = geo.readGrid("data/etopo_10min_surface.mat", Units = "m");
%     [f, ax, H] = geo.basemap(G, geo.crs("robinson"), ...
%                              ColormapName = "cividis");
%     H.CLim
%
%   LIMITATIONS
%     THE AXIS LIMITS THIS FUNCTION SETS ARE THE DATA LIMITS, and later
%     elements may widen them - a frame is drawn outside the map. They
%     are therefore recorded in H.DataLimits and every element that
%     redraws on resize must recompute from THOSE rather than from the
%     current limits. v1 unioned the current limits on every redraw, so
%     shrinking a window widened the limits, which lowered the
%     points-per-data-unit, which widened them again: the map ratcheted
%     smaller inside its own axes over repeated resizes.
%
%     One grid per call. A mosaic of several is Stage E's job.
%
%   See also GEO.GRID, GEO.CRS, GEO.HILLSHADE, GEO.COLORMAPS, GEO.FRAME.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    G
    crs = "equirectangular"
    options.Colormap (:,3) double {mustBeInRange(options.Colormap, 0, 1)} = double.empty(0, 3)
    options.ColormapName (1,1) string = "viridis"
    options.CLim (1,2) double = [NaN NaN]
    options.CLimMode (1,1) string {mustBeMember(options.CLimMode, ["auto" "percentile"])} = "auto"
    options.CLimPercentile (1,2) double {mustBeInRange(options.CLimPercentile, 0, 100)} = [2 98]
    options.DiscreteLevels (1,1) double = NaN
    options.Divergent (1,1) logical = false
    options.Hillshade (1,1) string {mustBeMember(options.Hillshade, ["single" "multi" "off"])} = "single"
    options.Azimuth (1,1) double = 315
    options.Elevation (1,1) double = 45
    options.Ambient (1,1) double {mustBeInRange(options.Ambient, 0, 1)} = 0.35
    options.NaNColor (1,3) double {mustBeInRange(options.NaNColor, 0, 1)} = [1 1 1]
    options.Mask = []
    options.MaskMethod (1,1) string {mustBeMember(options.MaskMethod, ["explicit" "threshold" "polygon"])} = "explicit"
    options.MaskThreshold (1,1) double = NaN
    options.MaskPolygon (:,2) double = double.empty(0, 2)
    options.MaskPolygonSide (1,1) string {mustBeMember(options.MaskPolygonSide, ["inside" "outside"])} = "outside"
    options.MaskColor (1,3) double {mustBeInRange(options.MaskColor, 0, 1)} = [0.7 0.7 0.7]
    options.Parent = []
end

G = geo.grid(G);
crs = resolveCrs(crs);

[lon, lat, Z, topo] = rollToCentre(G, crs.CenterLongitude);

% EVERY VALUE OWNS A CELL, so the surface is drawn on cell EDGES rather
% than on the nodes. Measured: with FaceColor flat MATLAB paints the face
% between vertices (i,j) and (i+1,j+1) entirely from CData(i,j) - 100% of
% one face on a 2x2 mesh, the other three elements contributing no
% pixels. Drawn on nodes, the last row and column are therefore never
% painted and every cell sits half a step from where its value belongs.
% On a global grid the missing column is the seam, which is the
% antimeridian wedge (PV-140).
[lonE, colIdx] = lonEdges(lon, G.Registration, G.IsGlobalLon, ...
    crs.CenterLongitude);
latE = edgesOf(lat(:).', G.Registration);

% Clamp the RIM vertices to what the projection can show. A cell grid at
% -87.5:5:87.5 covers the poles, and its edges therefore land on them -
% where Mercator's y is infinite. Unclamped, that made the axes limits
% non-finite, the map diagonal meaningless, and the graticule's
% densification criterion read 0.708 against a bound of 0.005 on a run
% that had nothing to do with graticules (PV-140). The REGION is what
% the grid covers; the vertices are that region clipped to what can be
% drawn, which is the same rule GEO.INTERNAL.ELEMENTEXTENT already
% applies to every element's extent.
latE = min(max(latE, crs.Domain.LatLimit(1)), crs.Domain.LatLimit(2));
[LONE, LATE] = meshgrid(lonE, latE);

% Window = "closed" for the VERTICES only. A global grid's eastern rim is
% +180 and its western rim -180; the half-open wrap folds the first onto
% the second and collapses the map's right edge onto its left. The DATA
% keeps the half-open default, which is F2's fix.
[X, Y] = geo.project(LONE, LATE, crs, Window = "closed");
[LON, LAT] = meshgrid(lon, lat);
if ~any(isfinite(X(:)) & isfinite(Y(:)))
    error('geo:basemap:NothingToDraw', ...
        ['Every cell of this grid projects outside %s''s domain, so ' ...
         'there is nothing to draw. The grid covers longitude %g to %g ' ...
         'and latitude %g to %g; the projection is centred on %g, %g.'], ...
        crs.Name, min(lon), max(lon), min(lat), max(lat), ...
        crs.CenterLongitude, crs.CenterLatitude);
end

mask = resolveMask(options, Z, LON, LAT);
cLim = resolveCLim(options, Z);
cmap = resolveColormap(options);
shade = resolveShade(options, lon, lat, Z, topo);

CData = geo.colormaps("truecolor", Z, cmap, ...
    CLim = cLim, Mask = mask, MaskColor = options.MaskColor, ...
    NaNColor = options.NaNColor, Shade = shade);

[figH, axH] = resolveAxes(options.Parent, options.NaNColor);
prior = geo.internal.layout("data", axH, "basemap");
if ~isempty(prior) && isgraphics(prior.Surface)
    delete(prior.Surface);              % replace, never accumulate
end

% One row and column larger than the data, because flat shading reads
% CData(i,j) for the face and never reads the last of either. The pad is
% never painted; it exists so the arrays agree in size.
% COLIDX carries the wrap column when the seam cell had to be split, so
% the rim cell is painted from the node it belongs to rather than left
% blank. This is cartopy's add_cyclic, arrived at from the other side.
CData = padLast(CData(:, colIdx, :));
drawable = padLast(~isnan(Z(:, colIdx))) & isfinite(X) & isfinite(Y);

s = surface('Parent', axH, 'XData', X, 'YData', Y, ...
    'ZData', zeros(size(X)), 'CData', CData, ...
    'FaceColor', 'flat', 'EdgeColor', 'none', 'FaceLighting', 'none', ...
    'FaceAlpha', 'flat', 'AlphaDataMapping', 'none', ...
    'AlphaData', double(drawable));

colormap(axH, cmap);
clim(axH, cLim);                        % clim(), never caxis (F11)
styleAxes(axH, X, Y);
dataLimits = struct('XLim', xlim(axH), 'YLim', ylim(axH));

H = struct('Surface', s, 'CLim', cLim, 'Colormap', cmap, ...
    'Shade', shade, 'DataLimits', dataLimits, 'Crs', crs, ...
    'LonLimit', [min(lonE) max(lonE)], 'LatLimit', [min(latE) max(latE)], ...
    'Registration', G.Registration, ...
    'HasUnder', any(Z(:) < cLim(1)), 'HasOver', any(Z(:) > cLim(2)));

geo.internal.layout("register", axH, "basemap", @(~) []);
geo.internal.layout("setData", axH, "basemap", H);
end

% ======================================================================
function crs = resolveCrs(c)
%RESOLVECRS  A GEO.CRS struct, or a name to build one from.
%   GEO.CRS is NOT idempotent - its first argument is declared a string -
%   so the struct case cannot simply be passed through it the way
%   GEO.GRID's is. Rather than change a Stage A contract from Stage D,
%   the two cases are separated here and the struct is validated by the
%   same validator every downstream arguments block uses.
if isstruct(c)
    geo.internal.mustBeCrs(c);
    crs = c;
else
    crs = geo.crs(c);
end
end

function [e, colIdx] = lonEdges(v, reg, isGlobal, lon0)
%LONEDGES  Cell edges around a longitude axis, which is CYCLIC.
%   Returns the edges and, with them, the column each face is painted
%   from. For a bounded axis that is simply 1:n. For a GLOBAL axis the
%   cell that straddles the window edge has to be split in two, and both
%   halves belong to the same node - so the first column is repeated at
%   the end and there are n+1 faces for n nodes.
%
%   That repeat is cartopy's ADD_CYCLIC, arrived at from the other side.
%   GMT reaches the same place through registration: a gridline grid
%   holds both rims and needs no repeat, a pixel grid implies them.
%   Whether a repeat is needed is therefore not a convention question
%   but an arithmetic one - does the seam midpoint fall on the window
%   edge - and it is answered here rather than assumed.
v = double(v(:)).';
if numel(v) < 2
    e = v;
    colIdx = 1:numel(v);
    return
end
v = uniqueSorted(v);
n = numel(v);
if ~isGlobal
    e = edgesOf(v, reg);
    colIdx = 1:n;
    return
end
lo = lon0 - 180;
hi = lon0 + 180;
mid = v(1:end-1) + diff(v) / 2;
seam = (v(end) + v(1) + 360) / 2;
if abs(seam - hi) <= 1e-9 || seam >= hi
    e = [lo, mid, hi];
    colIdx = 1:n;
else
    e = [lo, mid, seam, hi];
    colIdx = [1:n, 1];
end
end

function v = uniqueSorted(v)
%UNIQUESORTED  Drop the duplicate the half-open wrap makes at the rim.
%   A grid written -180:20:180 holds both rims; wrapped, they land on
%   each other. One copy is enough - LONEDGES puts the other back where
%   it belongs, at the far side of the map.
v = sort(v);
v(diff([-Inf, v]) == 0) = [];
end

function e = edgesOf(v, reg)
%EDGESOF  Cell edges for one axis: N nodes give N+1 edges, hence N faces.
%   Interior edges are the midpoints either way. The conventions differ
%   only at the rims: a CELL grid's outermost edges lie half a step
%   beyond its outermost nodes, a POSTING grid's lie on them, so a
%   posting grid's first and last cells are half-width. Both give exactly
%   360 for a global longitude axis, from opposite conventions.
v = double(v(:)).';
if numel(v) < 2
    e = v;
    return
end
d = diff(v);
mid = v(1:end-1) + d / 2;
if reg == "cell"
    e = [v(1) - d(1) / 2, mid, v(end) + d(end) / 2];
else
    e = [v(1), mid, v(end)];
end
end

function A = padLast(A)
%PADLAST  Repeat the last row and column so sizes agree with the edges.
%   Never read by flat shading. It is padding, not a value, and saying so
%   here is cheaper than a reader later wondering whether the rim cells
%   are drawn twice.
A = A([1:end, end], [1:end, end], :);
end

function [lon, lat, Z, topo] = rollToCentre(G, lon0)
%ROLLTOCENTRE  Re-order columns so longitude runs monotonically about lon0.
%   A grid stored 0..360 and a projection centred on 0 disagree about
%   where the map begins. Wrapping the VALUES alone would leave a
%   non-monotone axis and a surface face stretched across the whole map;
%   the columns have to move with them. Sorting the wrapped longitudes
%   does both, and is a no-op for a regional grid that already lies in
%   one window - the permutation comes back as 1:n.
lonW = geo.wrapLongitude(G.Lon, lon0);
[lon, ord] = sort(lonW(:).');
lat = G.Lat;
Z = G.Z(:, ord);
topo = G.Topo;
if ~isempty(topo)
    topo = topo(:, ord);
end

% THE RIM DUPLICATE. A grid written -180:20:180 holds both rims of the
% world, and the half-open wrap lands them on each other - so the rolled
% axis carries the same longitude twice, with two columns of data behind
% it. One copy is dropped here rather than in the drawing, because a
% duplicated node also breaks the step, the midpoints and the mask.
% LONEDGES puts the rim back where it belongs, at the far side of the
% map, by repeating the column rather than the node (PV-140).
dup = [false, diff(lon) == 0];
if any(dup)
    lon(dup) = [];
    Z(:, dup) = [];
    if ~isempty(topo)
        topo(:, dup) = [];
    end
end
end

function mask = resolveMask(options, Z, LON, LAT)
%RESOLVEMASK  One logical mask from whichever of three ways was asked.
mask = [];
switch options.MaskMethod
    case "explicit"
        if isempty(options.Mask)
            return
        end
        mask = logical(options.Mask);
        if ~isequal(size(mask), size(Z))
            error('geo:basemap:MaskSizeMismatch', ...
                ['Mask is %dx%d but Z is %dx%d. A mask that does not ' ...
                 'match the grid cannot be applied to it.'], ...
                size(mask, 1), size(mask, 2), size(Z, 1), size(Z, 2));
        end
    case "threshold"
        if isnan(options.MaskThreshold)
            error('geo:basemap:MaskMethodMismatch', ...
                ['MaskMethod = "threshold" needs MaskThreshold, which ' ...
                 'was not given. Masking nothing silently would look ' ...
                 'exactly like a threshold that happened to catch no ' ...
                 'cells.']);
        end
        mask = Z < options.MaskThreshold;
    case "polygon"
        if isempty(options.MaskPolygon)
            error('geo:basemap:MaskMethodMismatch', ...
                'MaskMethod = "polygon" needs MaskPolygon, which was not given.');
        end
        in = inpolygon(LON, LAT, ...
            options.MaskPolygon(:, 1), options.MaskPolygon(:, 2));
        if options.MaskPolygonSide == "outside"
            mask = ~in;
        else
            mask = in;
        end
end

% v1's two warnings, ported: both cases draw something, and both are
% almost always a mistake upstream rather than an intention here.
if isempty(mask)
    return
end
if all(mask(:))
    warning('geo:basemap:MaskCoversEverything', ...
        ['The mask is true for all %d cells, so the map is one flat ' ...
         'colour. The data is still there; only its colour was ' ...
         'replaced.'], numel(mask));
elseif ~any(mask(:))
    warning('geo:basemap:MaskCoversNothing', ...
        ['The mask is false for all %d cells, so it had no effect. ' ...
         'A threshold on the wrong side is the usual cause.'], numel(mask));
end
end

function cLim = resolveCLim(options, Z)
%RESOLVECLIM  Explicit, symmetric, percentile or plain range - in that order.
if ~any(isnan(options.CLim))
    cLim = options.CLim;
elseif options.Divergent
    % SYMMETRIC EVEN WHEN THE DATA IS ONE-SIDED. An all-positive field
    % with Divergent = true still gets limits about zero, because the
    % colormap's midpoint means zero and moving it would put the neutral
    % colour on a value that is not neutral.
    if options.CLimMode == "percentile"
        cLim = geo.symmetricLimits(Z, max(options.CLimPercentile));
    else
        cLim = geo.symmetricLimits(Z);
    end
elseif options.CLimMode == "percentile"
    cLim = [geo.quantile(Z, options.CLimPercentile(1) / 100), ...
            geo.quantile(Z, options.CLimPercentile(2) / 100)];
else
    cLim = [min(Z(:), [], 'omitnan'), max(Z(:), [], 'omitnan')];
end
if ~all(isfinite(cLim)) || diff(cLim) <= 0
    % A constant or all-NaN field has no range. Widening by half a unit
    % keeps the colour mapping defined; refusing to draw would be worse.
    mid = cLim(1);
    if ~isfinite(mid), mid = 0; end
    cLim = mid + [-0.5 0.5];
end
end

function cmap = resolveColormap(options)
%RESOLVECOLORMAP  Explicit array beats name; discretise last.
if isempty(options.Colormap)
    cmap = geo.colormaps("get", options.ColormapName, 256);
else
    cmap = options.Colormap;
end
if ~isnan(options.DiscreteLevels)
    cmap = geo.colormaps("discretize", cmap, options.DiscreteLevels);
end
end

function shade = resolveShade(options, lon, lat, Z, topo)
%RESOLVESHADE  Hillshade the topography if there is any, else the field.
%   Shading Z itself is what makes a bare anomaly map readable, and it is
%   what v1 did when no topography was supplied. Topo wins when present
%   because terrain is what a reader expects relief to describe.
if options.Hillshade == "off"
    shade = [];
    return
end
source = topo;
if isempty(source)
    source = Z;
end
shade = geo.hillshade(lon, lat, source, ...
    Azimuth = options.Azimuth, Elevation = options.Elevation, ...
    Ambient = options.Ambient, Multi = options.Hillshade == "multi");
end

function [figH, axH] = resolveAxes(parent, nanColor)
%RESOLVEAXES  The axes to draw into, and its background.
if isempty(parent)
    figH = figure('Color', 'w');
    axH = axes('Parent', figH);
else
    axH = parent;
    figH = ancestor(axH, 'figure');
end
set(axH, 'Color', nanColor);
end

function styleAxes(axH, X, Y)
%STYLEAXES  A map has no tick marks and no box.
%   Limits are SET from the projected data, never unioned with whatever
%   is already there - see LIMITATIONS for the ratchet that caused.
set(axH, 'XTick', [], 'YTick', [], 'XColor', 'none', 'YColor', 'none');
box(axH, 'off');
axis(axH, 'equal');
view(axH, 2);
finite = isfinite(X) & isfinite(Y);
xr = [min(X(finite)), max(X(finite))];
yr = [min(Y(finite)), max(Y(finite))];
if diff(xr) <= 0, xr = xr(1) + [-0.5 0.5]; end
if diff(yr) <= 0, yr = yr(1) + [-0.5 0.5]; end
xlim(axH, xr);
ylim(axH, yr);
end
