function H = coastline(axH, crs, options)
%GEO.COASTLINE  Shorelines, rivers or an outline, cut at the frame.
%
%   SYNTAX
%     H = GEO.COASTLINE(AX)
%     H = GEO.COASTLINE(AX, CRS)
%     H = GEO.COASTLINE(AX, CRS, Name, Value)
%
%   DESCRIPTION
%     Draws vector geography over a basemap at z = 4 on the documented
%     ladder - above the raster and the graticule, below the overlays and
%     the frame.
%
%     ONE PATH, NOT THREE. v1 had `geoCoastlineFromGSHHG`,
%     `geoCoastlineFromShapefile`, `geoCoastlineFromNetCDF` and
%     `geoCoastlineFromText`, and then three near-identical DRAWING paths
%     on top of them - one for coastlines, one for rivers, one for the
%     area-of-interest outline - differing only in colour, width and
%     which reader they called. Reading is GEO.READCOASTLINE's job now,
%     and Kind selects a set of defaults rather than a separate code
%     path. Three copies of a drawing loop is where F6 came from.
%
%     THE CLIP IS THE PROJECTION'S. v1 carried `localVisibleRadiusDeg`,
%     a private table of per-projection visible radii, and kept a second
%     copy of it inside its frame function; the two drifted, which is
%     defect F12. Here GEO.PROJECT returns NaN outside CRS.Domain and
%     MATLAB breaks a line at NaN, so the clip, the gap convention and
%     the data's own part separators are all the same mechanism.
%
%     BRANCH CUTS ARE BROKEN, NOT DRAWN. A coastline crossing the
%     antimeridian on a cylindrical projection produces a segment that
%     spans the whole map. GEO.INTERNAL.PROJECTPOLYLINE identifies it -
%     a segment that will not shrink under bisection is a cut, not a
%     curve - and breaks it. NOTHING IS DENSIFIED: a coastline's
%     vertices are survey data, and inventing points between two of them
%     invents shoreline.
%
%     PROVENANCE TRAVELS AND IS PER FORMAT. GEO.READCOASTLINE reports
%     whether the reader that produced these points has been checked
%     against a real file of that kind, and that word is carried into the
%     handle struct rather than dropped at the drawing boundary. A text
%     coastline still reads "unverified", because no canonical real file
%     of that kind exists to check against.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     crs  (1,1) struct  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     Source     "builtin"  Anything GEO.READCOASTLINE accepts: a
%                           filename, an Nx2 array, or "builtin".
%     Kind       "coastline"  "coastline" | "river" | "outline". Selects
%                           the default colour and width, and the GSHHG
%                           levels asked for. Nothing else.
%     Levels     []         GSHHG levels; defaults per Kind.
%     Color      []         Overrides the Kind default.
%     LineWidth  NaN        Overrides the Kind default.
%     LineStyle  "-"
%     Resolution "c"        GSHHG resolution letter, when Source is a
%                           GSHHG directory rather than a file.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Line        (1,1) Line    One object; parts are NaN-separated.
%          Provenance  (1,1) string  From GEO.READCOASTLINE.
%          NumParts    (1,1) double  Parts after clipping and cutting.
%          NumCuts     (1,1) double  Branch cuts broken - antimeridian
%                                    and projection jumps, NOT the
%                                    extent. See ExtentCuts.
%          ClippedToExtent (1,1) logical  False when the boundary ring
%                                    could not be closed inside the
%                                    projection's domain, in which case
%                                    nothing was cut and the whole
%                                    shoreline is drawn.
%          ExtentCuts  (1,1) double  Segments cut AT the frame. Rises
%                                    from zero the moment the extent is
%                                    smaller than the world, and each
%                                    cut adds a part.
%          MaxSegment  (1,1) double  Longest drawn segment, projected.
%          All         (1,:)         Everything, for deletion.
%
%   ACCURACY
%     No numerical claim of its own. The coordinates are exactly what
%     GEO.READCOASTLINE returned - asserted exact for shapefiles and to
%     the microdegree floor for GSHHG in Stage C - passed through
%     GEO.PROJECT, which is certified against PROJ. This function adds
%     no arithmetic beyond the projection and the cut detection.
%
%   ERRORS
%     geo:coastline:NoBasemap  - no CRS was given and the axes carries no
%                                basemap to take one from
%     Reader errors keep GEO.READCOASTLINE's own identifiers rather than
%     being re-raised here, because a user reads the name of the thing
%     that could not be opened.
%
%   EXAMPLE
%     G = geo.readGrid("data/etopo_10min_surface.mat");
%     [~, ax] = geo.basemap(G, geo.crs("robinson"));
%     H = geo.coastline(ax);
%     H.Provenance
%
%   LIMITATIONS
%     Lines only. Filled land is GEO.OVERLAYPOLYGONS' job, and a filled
%     coastline needs closed rings, which the clip does not guarantee -
%     a polygon cut by the projection's domain is no longer a polygon.
%
%   See also GEO.READCOASTLINE, GEO.BASEMAP, GEO.INTERNAL.PROJECTPOLYLINE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    crs = []
    options.Source = "builtin"
    options.Kind (1,1) string {mustBeMember(options.Kind, ["coastline" "river" "outline"])} = "coastline"
    options.Levels double = []
    options.Color double = []
    options.LineWidth (1,1) double = NaN
    options.LineStyle (1,1) string = "-"
    options.Resolution (1,1) string = "c"
end

[crs, lonLim, latLim, ~, ~, ~, diag] = geo.internal.elementExtent(axH, ...
    crs, ErrorId = "geo:coastline:NoBasemap");

style = styleFor(options);
[xy, meta] = readThrough(options, style);

% PV-136. The extent was fetched and thrown away here - outputs two and
% three were discarded - so every call drew the whole world and let the
% axes box hide the rest. On the GettingStarted track map that is 486 029
% of 529 498 km outside the frame, 91.8%, and GEO.FRAME widens the axes
% past its own band, which is the margin the spill shows in. GEO.GRATICULE
% five files away has kept its limits since Stage D.
%
% The clip is against the SAME ring the frame is drawn from
% (GEO.INTERNAL.MAPBOUNDARY), not a second traversal to the same recipe:
% two copies of the map's outline is defect F12, and it drifted.
[xy, clip] = clipToExtent(xy, crs, lonLim, latLim);

prior = geo.internal.layout("data", axH, "coastline");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

target = diag / 200;
[x, y, info] = geo.internal.projectPolyline(xy(:, 1).', xy(:, 2).', crs, ...
    Target = target, Densify = false);

h = line('Parent', axH, 'XData', x, 'YData', y, ...
    'ZData', 4 * ones(size(x)), ...
    'Color', style.Color, 'LineWidth', style.LineWidth, ...
    'LineStyle', options.LineStyle);

H = struct('Line', h, 'Provenance', meta.Provenance, ...
    'NumParts', countParts(x), 'NumCuts', info.NumCuts, ...
    'MaxSegment', info.MaxSegment, ...
    'ClippedToExtent', clip.ClippedToExtent, ...
    'ExtentCuts', clip.ExtentCuts, 'All', h);

geo.internal.layout("register", axH, "coastline", @(~) []);
geo.internal.layout("setData", axH, "coastline", H);
end

% ======================================================================
function s = styleFor(options)
%STYLEFOR  What Kind actually selects: three numbers, not three functions.
switch options.Kind
    case "river"
        s = struct('Color', [0.25 0.45 0.75], 'LineWidth', 0.5, ...
            'Levels', 0);
    case "outline"
        s = struct('Color', [0.85 0.20 0.20], 'LineWidth', 1.2, ...
            'Levels', []);
    otherwise
        s = struct('Color', [0 0 0], 'LineWidth', 0.75, 'Levels', 1);
end
if ~isempty(options.Color)
    s.Color = options.Color;
end
if ~isnan(options.LineWidth)
    s.LineWidth = options.LineWidth;
end
if ~isempty(options.Levels)
    s.Levels = options.Levels;
end
end

function [xy, meta] = readThrough(options, style)
%READTHROUGH  GEO.CACHE around GEO.READCOASTLINE.
%   Defect F14 was that v1 re-read and re-parsed on every call;
%   "persistent" appears zero times in its 36 files. The key is a struct
%   hashed whole - never a composed string that has to be split apart
%   again - and nothing is stored until the value exists, so a reader
%   that throws leaves no poisoned entry.
key = struct('source', options.Source, 'levels', style.Levels, ...
    'resolution', options.Resolution);
hit = geo.cache("get", key);
if ~isempty(hit)
    xy = hit.xy;
    meta = hit.meta;
    return
end
if isempty(style.Levels)
    [xy, meta] = geo.readCoastline(options.Source);
else
    [xy, meta] = geo.readCoastline(options.Source, Levels = style.Levels);
end
geo.cache("put", key, struct('xy', xy, 'meta', meta));
end

function n = countParts(x)
%COUNTPARTS  Runs of finite values, which is what will be drawn.
finite = isfinite(x);
if ~any(finite)
    n = 0;
    return
end
n = sum(diff([false, finite]) == 1);
end

% ======================================================================
function [xy, clip] = clipToExtent(xy, crs, lonLim, latLim)
%CLIPTOEXTENT  Cut the shoreline at the frame, and say how it was cut.
%   Reports EXTENTCUTS, not NumCuts. NumCuts already means "branch cuts
%   broken" - antimeridian jumps found by GEO.INTERNAL.PROJECTPOLYLINE -
%   and one name carrying two meanings across two files is the aliasing
%   that one-name-per-thing forbids.
%
%   NumParts rises on a regional map, and that is the cut working: a
%   coast that leaves the frame and returns is two parts afterwards.
B = geo.internal.mapBoundary(crs, [lonLim(1) lonLim(2)], ...
    [latLim(1) latLim(2)]);
[lon, lat, info] = geo.internal.clipToBoundary(xy(:, 1).', xy(:, 2).', B);
clip = struct('ClippedToExtent', info.Clipped, 'ExtentCuts', info.NumCuts);
if ~info.Clipped
    return
end
xy = [lon(:), lat(:)];
end
