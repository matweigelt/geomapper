function H = inset(axH, crs, options)
%GEO.INSET  A locator globe showing where the map is.
%
%   SYNTAX
%     H = GEO.INSET(AX)
%     H = GEO.INSET(AX, CRS)
%     H = GEO.INSET(AX, CRS, Name, Value)
%
%   DESCRIPTION
%     A small globe in a corner of the map, with the mapped extent drawn
%     on it. Ported from v1's `localAddMapInset`, which was 190 lines
%     inside a 3413-line function.
%
%     IT IS REPOSITIONED ON RESIZE, NEVER REDRAWN, and that was v1's one
%     genuinely good idea in this area. The locator lives in its own
%     axes with its own `axis equal`, so its contents are fixed in its
%     own coordinates and a resize moves one Position. Everything else in
%     v1 that responded to a resize deleted and rebuilt every handle it
%     owned; this did not, and that is why it is the only v1 element
%     whose returned handle was still valid afterwards.
%
%     THE OUTLINE IS COMPUTED FROM THE DECLARED DOMAIN, not from a hull.
%     v1 sampled a 180x90 mesh, projected it, and ran `boundary(...,0.9)`
%     over the surviving points, falling back to `convhull` on error - a
%     shrink factor of 0.9 on a point cloud, chosen by eye, to recover a
%     shape the projection already knows. Here an azimuthal projection's
%     outline is the circle at CRS.Domain.MaxAngularDistanceDeg, computed
%     exactly with GEO.GREATCIRCLE, and every other projection's is its
%     projected lon/lat boundary. Two cases, both exact, no tuning
%     constant.
%
%     THE LOCATOR IS CENTRED ON THE MAPPED EXTENT, not on the main map's
%     projection centre. v1 inherited lon0 and lat0, which for a regional
%     map with a global-convention centre put the region at the edge of
%     the locator or off it entirely. The point of a locator is to show
%     where the extent is; centring it anywhere else is answering a
%     different question.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     crs  The locator's own projection - a GEO.CRS or a name.
%          Defaults to an orthographic centred on the mapped extent.
%
%   OPTIONS
%     Size        0.3     Footprint, as a fraction of the map's short side.
%     Location    "southeast"  Any of the four inside corners.
%     Ocean       [0.85 0.92 0.97]  Globe fill.
%     Land        []      Fill for land; empty draws coastlines as lines.
%     Coast       [0.3 0.3 0.3]
%     Border      [0 0 0]
%     BorderWidth 1
%     ExtentColor [0.85 0.1 0.1]
%     ExtentWidth 1.5
%     Source      "builtin"  Coastline, as GEO.COASTLINE takes it.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Axes    the locator's own axes
%          Globe   (1,1) Patch  The outline.
%          Coast   (1,1) Line
%          Extent  (1,1) Line   The mapped rectangle.
%          Crs     (1,1) struct The locator's projection.
%          All     (1,:)
%
%   ACCURACY
%     Geometric, at TolGeom. The one claim worth asserting is that the
%     extent rectangle closes: its first and last projected vertices are
%     the same point, so the outline cannot be drawn open by a rounding
%     difference in the trace.
%
%   ERRORS
%     geo:inset:NoBasemap  - the axes carries no basemap, so there is no
%                            extent to locate
%     geo:inset:Degenerate - the locator projection maps the whole world
%                            to fewer than three points
%
%   EXAMPLE
%     G = geo.readGrid("data/etopo_10min_surface.mat");
%     [~, ax] = geo.basemap(G, geo.crs("equirectangular"));
%     H = geo.inset(ax);
%
%   LIMITATIONS
%     The extent drawn is the lon/lat RECTANGLE of the mapped grid, not
%     the projected outline of the map. On a strongly curved projection
%     those differ; the rectangle is what a reader of a locator expects,
%     and it is what v1 drew.
%
%   See also GEO.BASEMAP, GEO.COASTLINE, GEO.INTERNAL.LAYOUT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    crs = []
    options.Size (1,1) double {mustBeInRange(options.Size, 0.05, 0.6)} = 0.3
    options.Location (1,1) string = "southeast"
    options.Ocean (1,3) double {mustBeInRange(options.Ocean, 0, 1)} = [0.85 0.92 0.97]
    options.Land double = []
    options.Coast (1,3) double {mustBeInRange(options.Coast, 0, 1)} = [0.3 0.3 0.3]
    options.Border (1,3) double {mustBeInRange(options.Border, 0, 1)} = [0 0 0]
    options.BorderWidth (1,1) double {mustBePositive} = 1
    options.ExtentColor (1,3) double {mustBeInRange(options.ExtentColor, 0, 1)} = [0.85 0.1 0.1]
    options.ExtentWidth (1,1) double {mustBePositive} = 1.5
    options.Source = "builtin"
end

base = geo.internal.layout("data", axH, "basemap");
if isempty(base)
    error('geo:inset:NoBasemap', ...
        ['These axes carry no basemap, so there is no extent for a ' ...
         'locator to locate. Call geo.basemap first.']);
end
locator = locatorCrs(crs, base);

prior = geo.internal.layout("data", axH, "inset");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

[gx, gy] = globeOutline(locator);
if numel(gx) < 3
    error('geo:inset:Degenerate', ...
        ['Projection "%s" maps the whole world to fewer than three ' ...
         'points, so there is no globe to draw.'], locator.Name);
end

insetAx = axes('Parent', ancestor(axH, 'figure'), 'Units', 'points', ...
    'Position', [0 0 100 100], 'Color', 'none', ...
    'XColor', 'none', 'YColor', 'none', 'XTick', [], 'YTick', []);
hold(insetAx, 'on');
axis(insetAx, 'equal');

globe = patch('Parent', insetAx, 'XData', gx, 'YData', gy, ...
    'FaceColor', options.Ocean, 'EdgeColor', options.Border, ...
    'LineWidth', options.BorderWidth, 'FaceLighting', 'none');
coast = drawCoast(insetAx, locator, options);
extent = drawExtent(insetAx, locator, base, options);

xlim(insetAx, [min(gx) max(gx)]);
ylim(insetAx, [min(gy) max(gy)]);

H = struct('Axes', insetAx, 'Globe', globe, 'Coast', coast, ...
    'Extent', extent, 'Crs', locator, ...
    'All', [insetAx, globe, coast, extent]);

geo.internal.layout("register", axH, "inset", @(a) reposition(a, options));
geo.internal.layout("setData", axH, "inset", H);
reposition(axH, options);
end

% ======================================================================
function locator = locatorCrs(crs, base)
%LOCATORCRS  The locator's projection, centred on what is being located.
if isempty(crs)
    locator = geo.crs("orthographic", ...
        CenterLongitude = mean(base.LonLimit), ...
        CenterLatitude = mean(base.LatLimit));
elseif isstruct(crs)
    geo.internal.mustBeCrs(crs);
    locator = crs;
else
    locator = geo.crs(crs, ...
        CenterLongitude = mean(base.LonLimit), ...
        CenterLatitude = mean(base.LatLimit));
end
end

function [x, y] = globeOutline(crs)
%GLOBEOUTLINE  The edge of the visible world, from the declared domain.
%   An azimuthal projection's world is a disc of a stated angular radius,
%   so its outline is that circle - exact, and computed from the same
%   table GEO.PROJECT clips with. Everything else is bounded by the
%   lon/lat rectangle, whose projected image is its outline.
D = crs.Domain;
if D.MaxAngularDistanceFrom == "centre" && ~isnan(D.MaxAngularDistanceDeg)
    bearings = linspace(0, 360, 181);
    to = geo.greatCircle([crs.CenterLongitude crs.CenterLatitude], ...
        Bearing = bearings(:), ...
        Distance = repmat(D.MaxAngularDistanceDeg * pi / 180 * crs.Radius, ...
                          numel(bearings), 1));
    [x, y] = geo.project(to(:, 1).', to(:, 2).', crs);
else
    latLim = D.LatLimit;
    lon = crs.CenterLongitude + [-180 180];
    n = 180;
    lonV = [linspace(lon(1), lon(2), n), repmat(lon(2), 1, n), ...
            linspace(lon(2), lon(1), n), repmat(lon(1), 1, n)];
    latV = [repmat(latLim(1), 1, n), linspace(latLim(1), latLim(2), n), ...
            repmat(latLim(2), 1, n), linspace(latLim(2), latLim(1), n)];
    [x, y] = geo.project(lonV, latV, crs);
end
ok = isfinite(x) & isfinite(y);
x = x(ok);
y = y(ok);
end

function h = drawCoast(insetAx, locator, options)
%DRAWCOAST  The shoreline, through the same projector everything uses.
xy = geo.readCoastline(options.Source);
[x, y] = geo.internal.projectPolyline(xy(:, 1).', xy(:, 2).', locator, ...
    Target = 0.2, Densify = false);
h = line('Parent', insetAx, 'XData', x, 'YData', y, ...
    'Color', options.Coast, 'LineWidth', 0.5);
end

function h = drawExtent(insetAx, locator, base, options)
%DRAWEXTENT  The mapped rectangle, traced in lon/lat and projected.
%   CLOSED BY CONSTRUCTION: the first vertex is repeated as the last, so
%   the outline cannot come out open because two traces of the same
%   corner rounded differently.
n = 100;
lo = base.LonLimit;
la = base.LatLimit;
lonV = [linspace(lo(1), lo(2), n), repmat(lo(2), 1, n), ...
        linspace(lo(2), lo(1), n), repmat(lo(1), 1, n)];
latV = [repmat(la(1), 1, n), linspace(la(1), la(2), n), ...
        repmat(la(2), 1, n), linspace(la(2), la(1), n)];
lonV(end + 1) = lonV(1);
latV(end + 1) = latV(1);
[x, y] = geo.internal.projectPolyline(lonV, latV, locator, ...
    Target = 0.2, Densify = false);
h = line('Parent', insetAx, 'XData', x, 'YData', y, ...
    'Color', options.ExtentColor, 'LineWidth', options.ExtentWidth);
end

function reposition(axH, options)
%REPOSITION  Move the locator, without touching a single vertex.
H = geo.internal.layout("data", axH, "inset");
if isempty(H) || ~isgraphics(H.Axes)
    return
end
box = geo.internal.plottedBox(axH);
sz = options.Size * min(box(3), box(4));
margin = 0.03 * hypot(box(3), box(4));
if contains(options.Location, "west")
    x0 = box(1) + margin;
else
    x0 = box(1) + box(3) - margin - sz;
end
if contains(options.Location, "north")
    y0 = box(2) + box(4) - margin - sz;
else
    y0 = box(2) + margin;
end

rect = [x0 y0 sz sz];
obstacles = geo.internal.layout("rects", axH, "inset");
if contains(options.Location, "south")
    dir = [0 1];
else
    dir = [0 -1];
end
rect = geo.internal.avoidRectCollisions(rect, obstacles, dir, Bounds = box);
set(H.Axes, 'Units', 'points', 'Position', rect);
geo.internal.layout("setRect", axH, "inset", rect);
end
