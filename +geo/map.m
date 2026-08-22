function H = map(G, crs, Z, options)
%GEO.MAP  A finished map in one call.
%
%   L4-FRONT
%
%   SYNTAX
%     H = GEO.MAP(G)
%     H = GEO.MAP(G, CRS)
%     H = GEO.MAP(LON, LAT, Z, CRS = ...)
%     H = GEO.MAP(..., Name, Value)
%
%   DESCRIPTION
%     The one-call front. It draws the whole z-ladder in the documented
%     order and returns every handle it made.
%
%     IT IS ORCHESTRATION AND NOTHING ELSE, and that is enforced rather
%     than promised. This file declares L4-FRONT on the line above, and
%     the audit's ORCHESTRATIONPURITY check then holds it to zero
%     drawing primitives - no surf, patch, line, text, scatter, plot,
%     colorbar, annotation, title - and at most 200 executable lines.
%     It replaces v1's geoImagesc, which was 3413 lines and had grown
%     that way one inlined primitive at a time (F8). A rule enforced by
%     review erodes; this one is decided by a gate that runs before
%     every push, and it has already bitten once: GEO.MAP needs a title,
%     there was no element for one, and rather than inline a TEXT call
%     the missing capability became GEO.TITLE.
%
%     THE ORDER IS THE CONTRACT. basemap, contours, polygons, stipple,
%     graticule, coastline, region outline, track, points, frame,
%     colorbar, title, scale bar, north arrow, inset, export. Anything
%     drawn later sits on top, and the z values the elements use
%     encode the same ladder independently, so the two agree by
%     construction rather than by care.
%
%     EVERY ELEMENT IS ON, OFF, OR CONFIGURED, through one option each.
%     FALSE omits the element; TRUE draws it with its own defaults; a
%     STRUCT draws it and is forwarded as name-value pairs to the
%     element that owns them. So Graticule = false, Graticule = true and
%     Graticule = struct(Color = [0 0 0], StepLon = 30) are the three
%     things a caller ever wants, and GEO.MAP does not restate a
%     hundred and twenty option names that the elements already define -
%     which is also how it stays inside its line budget. v1's flat
%     spellings (GraticuleColor, CoastlineWidth, ...) are handled by the
%     compatibility layer, separately, so that this file carries no
%     option table.
%
%     THE PROJECTION OPTIONS ARE GONE, deliberately. v1 took Projection,
%     CenterLongitude, CenterLatitude, Hemisphere, StandardParallel and
%     StandardParallel2 as six loose front options that had to agree
%     with each other; v2 takes one GEO.CRS, which validates them
%     together and can be reused by every overlay so a track lands in
%     the same coordinate system as the map beneath it. Passing
%     Projection raises geo:map:ProjectionOption, which names the
%     replacement rather than reporting an unrecognised argument.
%
%   INPUTS
%     G    A GEO.GRID, or anything GEO.GRID accepts. In the raw-triplet
%          form the three positional arguments are LON, LAT and Z, and
%          the projection then comes from CRS = ... - three positional
%          arguments is D-003's limit and the projection is the one that
%          gives way, because it has a name.
%     crs  A GEO.CRS or a projection name. Defaults to equirectangular.
%     Z    Present only in the raw-triplet form; see above.
%
%   OPTIONS
%     Each of these takes false, true, or a struct of the owning
%     element's name-value pairs.
%
%     Basemap     true    GEO.BASEMAP. Cannot be false; there is no map
%                         without one.
%     Contours    false   GEO.OVERLAYCONTOURS
%     Polygons    false   GEO.OVERLAYPOLYGONS. Struct must carry P.
%     Stipple     false   GEO.STIPPLE. Struct must carry G.
%     Graticule   true    GEO.GRATICULE
%     Coastline   true    GEO.COASTLINE
%     Rivers      false   GEO.COASTLINE with Kind = "river"
%     Region      false   GEO.COASTLINE with Kind = "outline", drawing a
%                         GEO.REGION's own vertices. v1's AreaOfInterest.
%                         The struct's R field is the region, and takes
%                         anything GEO.REGION takes.
%     Track       false   GEO.OVERLAYTRACK. Struct must carry T.
%     Points      false   GEO.OVERLAYPOINTS. Struct must carry P.
%     Frame       true    GEO.FRAME
%     Colorbar    true    GEO.COLORBAR
%     Title       ""      GEO.TITLE. A string draws it; a struct
%                         configures it and must carry Text.
%     ScaleBar    false   GEO.SCALEBAR
%     NorthArrow  false   GEO.NORTHARROW
%     Inset       false   GEO.INSET
%     Export      ""      A path. GEO.EXPORT, which owns the page size.
%
%     And four of its own:
%
%     FontName    "Helvetica"  Given to every element that draws text,
%     FontSize    9            unless that element's own struct says
%                              otherwise. One typeface per figure was
%                              v1's Style preset and is now the default
%                              behaviour rather than a bundle.
%     Parent      []           An axes to draw into.
%     ExportOptions struct()   Forwarded to GEO.EXPORT.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Figure   (1,1) matlab.ui.Figure
%          Axes     (1,1) matlab.graphics.axis.Axes
%          CRS      (1,1) struct  The GEO.CRS actually used.
%          Basemap  (1,1) struct  and one field per element drawn, named
%                                 for its option, holding that element's
%                                 own return value. An element that was
%                                 off is absent, so ISFIELD answers what
%                                 the map contains.
%          Order    (1,:) string  The elements drawn, in the order drawn.
%
%   ACCURACY
%     No numerical claim of its own, and that is the point of a front:
%     every number on the figure is an element's, asserted where the
%     element is. What IS asserted here is composition - that the same
%     map built element by element and built in one call give identical
%     CData, identical colour limits and the same z-ladder.
%
%   ERRORS
%     geo:map:ProjectionOption - the v1 Projection option; use a geo.crs
%     geo:map:NoBasemap        - Basemap = false
%     geo:map:MissingField     - an element's struct lacks its data field
%
%   EXAMPLE
%     H = geo.map(G, geo.crs("mollweide"), ...
%         Title = "Mass trend 2003-2016", ...
%         Colorbar = struct(Label = "cm/yr", Style = "gmt"), ...
%         ScaleBar = true, Export = "figure3.pdf");
%
%   LIMITATIONS
%     One grid, one axes. Several maps side by side are GEO.PANEL's job.
%     An element drawn here cannot be given a z of its own; the ladder
%     is fixed, which is what makes two maps comparable.
%
%   See also GEO.BASEMAP, GEO.TITLE, GEO.EXPORT, GEO.PANEL, GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    G
    crs = []
    Z = []
    options.CRS = []
    options.Basemap = true
    options.Contours = false
    options.Polygons = false
    options.Stipple = false
    options.Graticule = true
    options.Coastline = true
    options.Rivers = false
    options.Region = false
    options.Track = false
    options.Points = false
    options.Frame = true
    options.Colorbar = true
    options.Title = ""
    options.ScaleBar = false
    options.NorthArrow = false
    options.Inset = false
    options.Export (1,1) string = ""
    options.ExportOptions struct = struct()
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 9
    options.Parent = []
    options.Projection = missing
end

if ~ismissing(options.Projection)
    error('geo:map:ProjectionOption', ...
        ['Projection is a geo.crs in v2, not a front option. v1''s six ' ...
         'loose projection options had to agree with each other; one ' ...
         'geo.crs validates them together and can be reused by every ' ...
         'overlay. Write geo.map(G, geo.crs("%s", CenterLongitude = ...)).'], ...
        string(options.Projection));
end
if isequal(options.Basemap, false)
    error('geo:map:NoBasemap', ...
        'Basemap = false leaves nothing to draw on. Every other element is optional.');
end

[G, crs] = resolveInput(G, crs, Z, options.CRS);
[figH, axH, H] = drawLadder(G, crs, options);

if strlength(options.Export) > 0
    % THE EXPORT IS INSIDE THE GUARD TOO. A map that drew perfectly and
    % then could not write its file is still a failed call, and a failed
    % call leaves nothing behind (PV-149). An unwritable path is the
    % likeliest way for a user to meet this.
    try
        nv = namedargs2cell(options.ExportOptions);
        geo.export(figH, options.Export, nv{:});
    catch err
        geo.internal.discardOnFailure(figH, H.Basemap.CreatedFigure);
        rethrow(err);
    end
end
H.Figure = figH;
H.Axes = axH;
H.CRS = crs;
end

% ======================================================================
function [G, crs] = resolveInput(G, crs, Z, crsOption)
%RESOLVEINPUT  Two call shapes, one grid and one crs out.
if ~isempty(Z)
    G = geo.grid(G, crs, Z);      % the raw triplet: lon, lat, Z
    crs = [];
end
G = geo.grid(G);
% CRS = ... FILLS THE POSITIONAL SLOT WHENEVER IT IS EMPTY, not only in
% the triplet form. Written the narrow way first, it worked for
% geo.map(lon, lat, Z, CRS = c) and was SILENTLY IGNORED by
% geo.map(G, CRS = c) - which is the shape the v1 translator produces,
% because v1 spelled the projection as an option and not as an
% argument. The map drew, in the wrong projection, without complaint.
if isempty(crs)
    crs = crsOption;
end
if isempty(crs)
    crs = "equirectangular";
end
% GEO.CRS IS THE ONE CONSTRUCTOR THAT IS NOT IDEMPOTENT. geo.grid,
% geo.track, geo.points and geo.region all accept their own output and
% return it unchanged, so a front can normalise by calling them; geo.crs
% takes a NAME and rejects a crs struct. The guard is here rather than a
% habit of remembering, because a front is exactly where a value of
% unknown provenance arrives.
if ~isstruct(crs)
    crs = geo.crs(crs);
end
end

function [figH, axH, H] = drawLadder(G, crs, options)
%DRAWLADDER  The z-order, once, in one readable place.
%   Every branch is the same three lines, which is what a front should
%   look like: decide whether the element is wanted, hand it the
%   caller's options plus the shared typeface, keep what it returned.
baseNv = nvFor(options.Basemap, options, false);
% PARENT REACHES GEO.BASEMAP, which it did not. The option was declared,
% documented and never read: geo.map(G, crs, Parent = ax) drew a whole
% NEW FIGURE and left the axes it was handed untouched. It surfaced only
% when geo.panel needed to draw into a tile.
%
% The E.1a test that should have caught it PASSED FOR THE WRONG REASON.
% It drew twice with Parent and asserted the first axes' child count had
% not grown - which is trivially true when the second call goes to a
% different figure entirely. An assertion that cannot distinguish
% "reused the axes" from "ignored the argument" tests neither (PV-121).
if ~isempty(options.Parent) && ~any(string(baseNv(1:2:end)) == "Parent")
    baseNv = [baseNv, {'Parent'}, {options.Parent}];
end
[figH, axH, base] = geo.basemap(G, crs, baseNv{:});

% THE LADDER IS THE DANGEROUS PART, and until PV-149 nothing owned the
% figure while it was climbed. Every rung below can raise - a missing
% data field, a bad option, an element refusing its own arguments - and
% the figure GEO.BASEMAP has just built is already on screen. Four such
% figures survived a GREEN 516-point run.
%
% CREATEDFIGURE IS READ, NOT RE-DERIVED. isempty(options.Parent) is the
% same fact stated a second time, and a second statement of one fact is
% the defect this project has spent the most repairs on.
try

% Name, the field its data arrives in, whether it draws text, and the
% call. One row per rung of the ladder, in the order the ladder is
% climbed - so the order is READ off this table rather than inferred
% from fourteen if-blocks.
%
% THE TEXT COLUMN IS NOT DECORATION. The shared typeface may only be
% handed to elements that have FontName and FontSize, because MATLAB's
% arguments block rejects an unknown name-value pair rather than
% ignoring it - geo.coastline draws no text and refused FontSize on the
% first run of this file. That is the correct behaviour on its side: a
% front that could pass anything to anything would have no contract.
step = { ...
    "Contours",   "",     true,  @(d, nv) geo.overlayContours(axH, G, crs, nv{:}); ...
    "Polygons",   "P",    false, @(d, nv) geo.overlayPolygons(axH, d, crs, nv{:}); ...
    "Stipple",    "G",    false, @(d, nv) geo.stipple(axH, d, crs, nv{:}); ...
    "Graticule",  "",     true,  @(d, nv) geo.graticule(axH, crs, nv{:}); ...
    "Coastline",  "",     false, @(d, nv) geo.coastline(axH, crs, nv{:}); ...
    "Rivers",     "",     false, @(d, nv) geo.coastline(axH, crs, nv{:}, Kind = "river"); ...
    "Region",     "R",    false, @(d, nv) geo.coastline(axH, crs, nv{:}, ...
                                     Kind = "outline", Source = geo.region(d).Outline); ...
    "Track",      "T",    false, @(d, nv) geo.overlayTrack(axH, d, crs, nv{:}); ...
    "Points",     "P",    true,  @(d, nv) geo.overlayPoints(axH, d, crs, nv{:}); ...
    "Frame",      "",     false, @(d, nv) geo.frame(axH, crs, nv{:}); ...
    "Colorbar",   "",     true,  @(d, nv) geo.colorbar(axH, nv{:}); ...
    "Title",      "Text", true,  @(d, nv) geo.title(axH, d, nv{:}); ...
    "ScaleBar",   "",     true,  @(d, nv) geo.scalebar(axH, crs, nv{:}); ...
    "NorthArrow", "",     true,  @(d, nv) geo.northarrow(axH, crs, nv{:}); ...
    "Inset",      "",     false, @(d, nv) geo.inset(axH, crs, nv{:})};

H = struct('Basemap', base);
% Collected and joined once: how many rungs are climbed is not known
% until the loop has run (F13).
drawn = cell(1, 0);
for k = 1:size(step, 1)
    name = step{k, 1};
    want = options.(name);
    if isOff(want)
        continue
    end
    nv = nvFor(want, options, step{k, 3});
    [data, nv] = takeField(nv, step{k, 2}, name);
    H.(name) = step{k, 4}(data, nv);
    drawn{end + 1} = name;
end
H.Order = ["Basemap", string(drawn)];
catch err
    geo.internal.discardOnFailure(figH, base.CreatedFigure);
    rethrow(err);
end
end

function tf = isOff(want)
%ISOFF  false, or an empty string. Everything else is a request to draw.
tf = isequal(want, false) || ...
    ((isstring(want) || ischar(want)) && all(strlength(string(want)) == 0));
end

function nv = nvFor(want, options, wantsFont)
%NVFOR  One element's name-value list: its struct, plus the typeface.
%   A struct field always wins over the shared font, because a caller
%   who named it meant it.
if isstruct(want)
    s = want;
elseif isstring(want) || ischar(want)
    s = struct('Text', string(want));       % Title = "..." is sugar
else
    s = struct();
end
if wantsFont
    if ~isfield(s, 'FontName'), s.FontName = options.FontName; end
    if ~isfield(s, 'FontSize'), s.FontSize = options.FontSize; end
end
nv = namedargs2cell(s);
end

function [data, nv] = takeField(nv, field, name)
%TAKEFIELD  Lift an element's DATA out of its option list.
%   It has to come out, not just be read: the elements take their data
%   positionally and would reject it a second time as an unknown
%   name-value pair. That is the correct behaviour on their side and the
%   reason this is a move rather than a copy.
data = [];
if strlength(field) == 0
    return
end
idx = find(string(nv(1:2:end)) == field, 1);
if isempty(idx)
    error('geo:map:MissingField', ...
        ['%s needs a %s field carrying the data to draw. Write ' ...
         '%s = struct(%s = ..., ...).'], name, field, name, field);
end
data = nv{2 * idx};
nv([2 * idx - 1, 2 * idx]) = [];
end
