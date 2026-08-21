function H = overlayPolygons(axH, P, crs, options)
%GEO.OVERLAYPOLYGONS  A value per polygon: mascons, basins, tiles.
%
%   SYNTAX
%     H = GEO.OVERLAYPOLYGONS(AX, P)
%     H = GEO.OVERLAYPOLYGONS(AX, P, CRS)
%     H = GEO.OVERLAYPOLYGONS(AX, P, CRS, Name, Value)
%
%   DESCRIPTION
%     NEW IN v2, AND THE REASON IT EXISTS IS THAT A REGULAR GRID CANNOT
%     REPRESENT A MASCON FIELD AT ALL. A mascon solution is a value per
%     irregular cell; a drainage basin field is a value per basin. Both
%     are piecewise constant over shapes that are not rectangles, and
%     resampling them onto a lon/lat grid to draw them - which is what v1
%     forced, having no other option - invents a boundary that the
%     solution does not have and smooths across the discontinuity that is
%     the whole point of the parameterisation. Here each polygon is one
%     patch with one colour.
%
%     ONE VALUE, POSSIBLY SEVERAL PATCHES. A polygon crossing the
%     antimeridian is CLIPPED to each side of it, so both parts are
%     closed polygons along the seam rather than one shape stretched
%     across the map. Every part of one polygon gets that polygon's
%     colour, and PolygonOf says which parts belong together, because
%     they are one mascon and a reader who recolours "the third polygon"
%     must not recolour half of it.
%
%     THE COLOUR MEANS THE SAME THING AS THE BASEMAP'S. CLim and Colormap
%     default to the basemap's, so a mascon layer over a hillshaded
%     background shares one scale and one GEO.COLORBAR describes both. A
%     second scale on one figure is a figure that has to be read twice.
%
%     IT SITS AT z = 2, under the graticule and the coastline. A mascon
%     field is data about the surface, not an annotation on top of it,
%     and a coastline drawn underneath it would be invisible exactly
%     where a reader needs it to judge the boundary.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     P    Polygons, in either of two forms:
%            - a cell array of Nx2 [lon lat] outlines, one per polygon;
%            - one Nx2 array with NaN rows separating the polygons.
%          The cell form is preferred and is what a mascon file gives.
%     crs  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     Values     []      One per polygon. Empty draws outlines only.
%     CLim       []      Defaults to the basemap's.
%     Colormap   []      Defaults to the basemap's.
%     FaceAlpha  1
%     EdgeColor  "none"  Or an RGB row.
%     LineWidth  0.5
%     NaNColor   []      Colour for a polygon whose value is NaN. Empty
%                        leaves it unfilled, which is the honest default:
%                        a mascon with no solution is not a mascon with a
%                        value of zero.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Patches    (1,:) Patch   One or more per polygon.
%          PolygonOf  (1,:) double  Which polygon each patch belongs to.
%          Values     (1,:) double  As given.
%          CLim       (1,2) double
%          NumSplit   (1,1) double  Polygons that crossed the seam.
%          All        (1,:)
%
%   ACCURACY
%     No numerical claim beyond the projection's. The colour of a polygon
%     is GEO.COLORMAPS' truecolor mapping of its value, identical to the
%     one the basemap uses, and that identity is asserted rather than
%     assumed: a polygon and a raster cell of the same value come out the
%     same colour, exactly.
%
%   ERRORS
%     geo:overlayPolygons:NoBasemap    - no crs and no basemap
%     geo:overlayPolygons:ValueCount   - Values is not one per polygon
%     geo:overlayPolygons:BadPolygons  - P is neither a cell of Nx2 nor
%                                        one Nx2 array
%
%   EXAMPLE
%     M = {[-10 40; 0 40; 0 50; -10 50], [0 40; 10 40; 10 50; 0 50]};
%     [~, ax] = geo.basemap(G, geo.crs("equirectangular"));
%     H = geo.overlayPolygons(ax, M, Values = [-3.2 1.8]);
%
%   LIMITATIONS
%     A polygon leaving the projection's domain is drawn from the
%     vertices that remain, which for a shape straddling the horizon of
%     an azimuthal projection is a different shape. Clipping a polygon to
%     a curved domain boundary needs a polygon clipper this toolbox does
%     not have; the alternative - dropping the polygon entirely - loses
%     more than it saves, and this is stated rather than hidden.
%
%   See also GEO.BASEMAP, GEO.COLORMAPS, GEO.SPLITANTIMERIDIAN, GEO.STIPPLE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    P
    crs = []
    options.Values double = []
    options.CLim double = []
    options.Colormap double = []
    options.FaceAlpha (1,1) double {mustBeInRange(options.FaceAlpha, 0, 1)} = 1
    options.EdgeColor = "none"
    options.LineWidth (1,1) double {mustBePositive} = 0.5
    options.NaNColor double = []
end

[crs, lonLim, latLim, base] = geo.internal.elementExtent(axH, crs, ...
    ErrorId = "geo:overlayPolygons:NoBasemap");
rings = ringsOf(P);
values = options.Values;
if ~isempty(values) && numel(values) ~= numel(rings)
    error('geo:overlayPolygons:ValueCount', ...
        ['Values has %d entries and there are %d polygons. One value ' ...
         'per polygon: a mascon field is a value per cell, and a ' ...
         'mismatch means the two came from different files.'], ...
        numel(values), numel(rings));
end
[cLim, cmap] = geo.internal.colourScale(base, values, ...
    Colormap = options.Colormap, CLim = options.CLim);

prior = geo.internal.layout("data", axH, "polygons");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

% Split first, then draw: the number of patches is not known until every
% ring has been clipped, and growing the handle array inside the loop is
% F13. Two passes cost one traversal of a list of polygons.
allParts = cell(1, numel(rings));
nSplit = 0;
nParts = 0;
for k = 1:numel(rings)
    allParts{k} = splitRing(rings{k}, crs);
    if numel(allParts{k}) > 1
        nSplit = nSplit + 1;
    end
    nParts = nParts + numel(allParts{k});
end

% One boundary for every ring, built once.
B = geo.internal.mapBoundary(crs, [lonLim(1) lonLim(2)], ...
    [latLim(1) latLim(2)]);


patches = gobjects(1, nParts);
polygonOf = zeros(1, nParts);
m = 0;
for k = 1:numel(rings)
    colour = colourOf(values, k, cLim, cmap, options);
    for j = 1:numel(allParts{k})
        h = onePatch(axH, allParts{k}{j}, crs, colour, B, options);
        if isempty(h)
            continue
        end
        m = m + 1;
        patches(m) = h;
        polygonOf(m) = k;
    end
end
patches = patches(1:m);
polygonOf = polygonOf(1:m);

H = struct('Patches', patches, 'PolygonOf', polygonOf, ...
    'Values', values, 'CLim', cLim, 'NumSplit', nSplit, 'All', patches);
geo.internal.layout("register", axH, "polygons", @(~) []);
geo.internal.layout("setData", axH, "polygons", H);
end

% ======================================================================
function rings = ringsOf(P)
%RINGSOF  Both accepted forms to one cell array of Nx2 outlines.
if iscell(P)
    rings = P(:).';
    for k = 1:numel(rings)
        if size(rings{k}, 2) ~= 2
            error('geo:overlayPolygons:BadPolygons', ...
                'Polygon %d is %dx%d; each must be Nx2 [lon lat].', ...
                k, size(rings{k}, 1), size(rings{k}, 2));
        end
    end
    return
end
if ~isnumeric(P) || size(P, 2) ~= 2
    error('geo:overlayPolygons:BadPolygons', ...
        ['P must be a cell array of Nx2 outlines or one Nx2 array with ' ...
         'NaN rows between polygons.']);
end
finite = all(isfinite(P), 2).';
starts = find(diff([false, finite]) == 1);
stops = find(diff([finite, false]) == -1);
rings = cell(1, numel(starts));
for k = 1:numel(starts)
    rings{k} = P(starts(k):stops(k), :);
end
end

function parts = splitRing(ring, crs)
%SPLITRING  One outline into the closed parts the seam leaves it in.
%
%   A RING IS NOT A POLYLINE, and that is why the obvious approach does
%   not work. Breaking an open line at its seam crossings leaves the
%   pieces OPEN, and a patch closes whatever it is given by joining its
%   last vertex to its first - straight across the map. Measured on a
%   20-degree box across the seam: breaking gave three fragments of one
%   or two vertices each, all of them discarded, and the mascon vanished.
%   Before that, with no split at all, it was one patch spanning 94% of
%   the map width. A ring has to be CLIPPED, so that each part is closed
%   along the meridian it was cut on.
%
%   HOW. Longitudes are first made continuous - a ring given as
%   [170 .. -170] and one given as [170 .. 190] become the same thing, so
%   the two conventions stop mattering. The ring is then clipped by
%   Sutherland-Hodgman to each 360-degree window it reaches, and each
%   clipped part is shifted back into the projection's own window. A ring
%   inside one window comes back unchanged, so the common case pays only
%   the two half-plane tests.
lon = unwrapLon(ring(:, 1).');
lat = ring(:, 2).';
% A HAIR INSIDE THE SEAM, and the hair is load-bearing. The projection's
% longitude window is HALF-OPEN, so a vertex at exactly lon0+180 wraps to
% lon0-180 and lands at the far edge of the map: measured, a part clipped
% to [170, 180] came out spanning 97% of the map width because its
% 180-degree vertices projected to -180. Clipping to [lo+d, hi-d] leaves
% no vertex on the boundary, so the wrap is unambiguous. At 1e-9 degrees
% the geometric cost is about a tenth of a millimetre on the ground -
% this is a choice of representation, not a tolerance on a measurement.
seamNudge = 1e-9;
lo = crs.CenterLongitude - 180 + seamNudge;
hi = crs.CenterLongitude + 180 - seamNudge;
kFirst = floor((min(lon) - lo) / 360);
kLast = floor((max(lon) - lo) / 360);
parts = cell(1, kLast - kFirst + 1);
m = 0;
for k = kFirst:kLast
    [cx, cy] = clipStrip(lon, lat, lo + 360 * k, hi + 360 * k);
    if numel(cx) >= 3
        m = m + 1;
        parts{m} = [cx(:) - 360 * k, cy(:)];
    end
end
parts = parts(1:m);
end

function lon = unwrapLon(lon)
%UNWRAPLON  Remove the jumps, so both conventions become one.
%   [170 -170] and [170 190] describe the same 20 degrees; after this
%   they are the same numbers.
if numel(lon) < 2
    return
end
d = diff(lon);
d = d - 360 * round(d / 360);
lon = [lon(1), lon(1) + cumsum(d)];
end

function [x, y] = clipStrip(x, y, lo, hi)
%CLIPSTRIP  The part of a closed ring inside a longitude window.
[x, y] = clipHalf(x, y, lo, 1);
[x, y] = clipHalf(x, y, hi, -1);
end

function [ox, oy] = clipHalf(x, y, c, s)
%CLIPHALF  Sutherland-Hodgman against one meridian.
%   S = +1 keeps longitudes at or above C, S = -1 at or below. Latitude
%   is interpolated LINEARLY IN LONGITUDE at the crossing, which is what
%   the polygon's own edge does - a great-circle interpolation here would
%   put the vertex somewhere the outline does not go.
n = numel(x);
ox = zeros(1, 2 * n);
oy = ox;
m = 0;
if n == 0
    ox = ox(1:0);
    oy = oy(1:0);
    return
end
for i = 1:n
    j = mod(i, n) + 1;
    inI = s * (x(i) - c) >= 0;
    inJ = s * (x(j) - c) >= 0;
    if inI
        m = m + 1;
        ox(m) = x(i);
        oy(m) = y(i);
    end
    if inI ~= inJ && x(j) ~= x(i)
        f = (c - x(i)) / (x(j) - x(i));
        m = m + 1;
        ox(m) = c;
        oy(m) = y(i) + f * (y(j) - y(i));
    end
end
ox = ox(1:m);
oy = oy(1:m);
end

function colour = colourOf(values, k, cLim, cmap, options)
%COLOUROF  One value to one RGB, by the SAME mapping the basemap uses.
if isempty(values)
    colour = "none";
    return
end
v = values(k);
if isnan(v)
    if isempty(options.NaNColor)
        colour = "none";                % no solution is not a value of 0
    else
        colour = options.NaNColor;
    end
    return
end
rgb = geo.colormaps("truecolor", v, cmap, CLim = cLim);
colour = reshape(rgb, 1, 3);
end

function h = onePatch(axH, ring, crs, colour, B, options)
%ONEPATCH  Project one closed part and draw it, if it is on the map.
%
%   WHOLLY OUTSIDE IS DROPPED; STRADDLING IS NOT CUT, and the difference
%   is deliberate (PV-142). A filled ring cut at the frame stops being
%   closed, and closing it again means walking the boundary between the
%   exit and the re-entry - which needs the projected ring that PV-137
%   showed does not always exist. Dropping what is entirely off the map
%   is the part that can be done correctly today, and it is the part
%   that matters for a mascon set: the ones outside the region outnumber
%   the ones that straddle it by a wide margin.
%
%   The straddling case is carried openly in tests/EXEMPTIONS.md rather
%   than half-solved, because a ring cut without being closed renders as
%   a wrong shape, and a wrong shape is worse than an honest overhang.
if ~isempty(B) && ~any(geo.internal.insideExtent(ring(:, 1).', ...
        ring(:, 2).', B))
    h = gobjects(1, 0);                 % no vertex of it is on the map
    return
end
[x, y] = geo.project(ring(:, 1).', ring(:, 2).', crs);
ok = isfinite(x) & isfinite(y);
if nnz(ok) < 3
    h = gobjects(1, 0);                 % nothing of it is on the map
    return
end
x = x(ok);
y = y(ok);
h = patch('Parent', axH, 'XData', x, 'YData', y, ...
    'ZData', 2 * ones(size(x)), 'FaceColor', colour, ...
    'FaceAlpha', options.FaceAlpha, 'EdgeColor', options.EdgeColor, ...
    'LineWidth', options.LineWidth, 'FaceLighting', 'none');
end
