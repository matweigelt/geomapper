function R = region(spec, options)
%GEO.REGION  Resolve an area of interest into a padded box and outline.
%
%   SYNTAX
%     R = GEO.REGION(SPEC)
%     R = GEO.REGION(SPEC, Padding = P)
%     R = GEO.REGION(R)                     % idempotent: passes through
%
%   DESCRIPTION
%     Ported from v1's geoAreaOfInterest. Accepts a named preset, an
%     explicit bounding box, a polygon outline, or empty, and resolves all
%     of them to one struct so that every consumer - GEO.SPLITTRACKS,
%     Stage D's coastline outline, Stage E's extent logic - reads the same
%     two fields instead of re-deriving a box.
%
%     THE PRESETS ARE CONVENTIONAL APPROXIMATE BOXES, NOT BOUNDARIES, and
%     v1's caveat is carried over deliberately rather than quietly
%     dropped. "Europe" here is a rectangle somebody found convenient; it
%     is not a political or physical border, and anyone who needs one
%     should pass an explicit box or a polygon. A preset that pretends to
%     authority it does not have is worse than no preset.
%
%     CONTAINERS.MAP IS GONE, replaced by a plain struct array. It is
%     discouraged in R2026a, and DICTIONARY was rejected as its
%     replacement too: thirteen fixed rows that are written once and read
%     by name need no hashing, and a struct array is the simplest thing
%     that works. Handover §7.3 deliverable 6 asked for exactly this.
%
%     FILE INPUT WORKS FROM STAGE C. It routes to GEO.READCOASTLINE and
%     then through the SAME padding path a hand-passed outline takes, so
%     the two cannot drift apart. Between Stage A and Stage C this raised
%     a named "not yet available" error with a contract test already
%     written against it, so closing the hook converted a failing test
%     into a passing one rather than inventing the behaviour.
%
%   INPUTS
%     spec  one of:
%             (1,1) string   a preset name, case- and space-insensitive
%             (1,4) double   [lonMin lonMax latMin latMax]
%             (N,2) double   [lon lat] outline, NaN-separated parts allowed
%             []             no region; limits are NaN and the caller
%                            falls back to its own extent logic
%             (1,1) struct   a geo.region, for the idempotent form
%
%   OPTIONS
%     Padding  (1,1) double  [0.05]  APPLIES TO AN OUTLINE ONLY - an Nx2
%              spec or a coordinate file. A 1x4 box and a preset name are
%              STATED EXTENTS and are used as given; the returned Padding
%              is then 0, because it reports what was applied and not what
%              was asked for. Fraction of the outline's own span
%                                    added on each side. Applied to
%                                    OUTLINE and FILE specs only: a box
%                                    the caller wrote out is taken as
%                                    meant, and a preset is already
%                                    approximate.
%
%   OUTPUTS
%     R  (1,1) struct  Fields:
%          Identity  (1,1) string   Always "geo.region".
%          Name      (1,1) string   Preset name, or "" for the others.
%          LonLim    (1,2) double   [min max], NaN NaN for an empty spec.
%          LatLim    (1,2) double   [min max], clamped to [-90, 90].
%          Outline   (N,2) double   The polygon if one was given, else
%                                   0x2 empty. Presets and boxes have no
%                                   outline, and an empty one is how a
%                                   consumer knows to draw a rectangle.
%          Padding   (1,1) double   As applied.
%          IsEmpty   (1,1) logical  True for the no-region case.
%
%   ACCURACY
%     No numerical claim and no oracle: the presets are conventions, not
%     measurements. The padding arithmetic is exact by construction, and
%     the latitude clamp is asserted at the pole rather than assumed.
%
%   ERRORS
%     Specification:
%       geo:region:UnknownPreset       - a name that is neither a preset
%                                        nor a filename with an extension
%       geo:region:InvalidBoundingBox  - a 1x4 with max <= min
%       geo:region:InvalidSpec         - none of the accepted forms
%       geo:region:EmptyOutline        - an outline with no finite points
%     A filename is now read by GEO.READCOASTLINE, so it raises that
%     function's identifiers rather than one of its own. Between Stage A
%     and Stage C this path raised a "file input not yet available"
%     identifier of its own - a deferred capability with a date rather
%     than a limitation. The date arrived and that identifier is gone
%     entirely, which is what retiring a name means: it is not spelled
%     out here, because naming it in a help block is how a dead
%     identifier comes back to life as documentation.
%     Identity:
%       geo:region:NotARegion          - the idempotent form was given a
%                                        struct that is not a geo.region
%
%   EXAMPLE
%     R = geo.region("Europe");
%     R = geo.region([-25 45 34 72]);
%     R = geo.region(basinOutline, Padding = 0.1);
%
%   LIMITATIONS
%     Boxes do not wrap the antimeridian: [170 -170 -10 10] is rejected as
%     an inverted box rather than read as a 20-degree strip across the
%     seam. Pass [170 190 -10 10] instead. Making the wrap implicit would
%     mean guessing which of two readings a caller meant, and guessing
%     wrong silently draws half the world.
%
%   See also GEO.SPLITTRACKS, GEO.GRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    spec = []
    options.Padding (1,1) double {mustBeReal, mustBeNonnegative} = 0.05
end

if isstruct(spec)
    geo.internal.mustBeIdentity(spec, "geo.region", 'geo:region:NotARegion');
    R = spec;
    return
end

if isempty(spec)
    R = makeRegion("", [NaN NaN], [NaN NaN], double.empty(0, 2), ...
                   options.Padding, true);
    return
end

if ischar(spec) || isstring(spec)
    R = fromName(string(spec), options.Padding);
    return
end

if isnumeric(spec) && isreal(spec) && isequal(size(spec), [1 4])
    if spec(2) <= spec(1) || spec(4) <= spec(3)
        % One scalar per conversion. error() rejects a formatted argument
        % that is not scalar, so passing SPEC whole raised
        % MATLAB:error:nonScalarInput instead of this identifier - the
        % rejection path failing to reject. Found by the contract test on
        % its first run, which is the entire reason error branches get
        % tests rather than a reading.
        error('geo:region:InvalidBoundingBox', ...
            ['A 1x4 spec is [lonMin lonMax latMin latMax] and needs ' ...
             'lonMax > lonMin and latMax > latMin; got ' ...
             '[%g %g %g %g]. A box crossing the antimeridian is ' ...
             'written with lonMax beyond 180, e.g. [170 190 -10 10].'], ...
            spec(1), spec(2), spec(3), spec(4));
    end
    % PADDING IS 0 HERE, NOT options.Padding, and the difference is that
    % this struct now tells the truth. A 1x4 box is a STATED EXTENT, so
    % it is not padded - that is defensible and stays. What was not
    % defensible is that the field documented as "As applied" reported
    % the value that had been ignored, so a caller who asked for a 5%
    % margin was told they had one. Measured: geo.region([-20 40 12.7
    % 50], Padding = 0.05) returned those limits unchanged with Padding
    % = 0.05 (PV-116). Pad an OUTLINE, or widen the box yourself.
    R = makeRegion("", spec(1:2), clampLat(spec(3:4)), ...
                   double.empty(0, 2), 0, false);
    return
end

if isnumeric(spec) && isreal(spec) && size(spec, 2) == 2 && size(spec, 1) >= 1
    [lonLim, latLim] = boxFromOutline(spec, options.Padding);
    R = makeRegion("", lonLim, latLim, double(spec), options.Padding, false);
    return
end

error('geo:region:InvalidSpec', ...
    ['A region spec must be a preset name, a 1x4 [lonMin lonMax latMin ' ...
     'latMax] box, an Nx2 [lon lat] outline, or empty. Got a %s of ' ...
     'size %s.'], class(spec), mat2str(size(spec)));
end

% ======================================================================
function R = fromName(name, padding)
%FROMNAME  A preset, or a filename that Stage C will learn to read.
key = lower(erase(strtrim(name), " "));
P = presetTable();
hit = find([P.name] == key, 1);
if ~isempty(hit)
    % 0, not PADDING: a preset's box is its definition, so it is not
    % padded, and the struct must not claim otherwise (PV-116).
    R = makeRegion(P(hit).name, P(hit).box(1:2), clampLat(P(hit).box(3:4)), ...
                   double.empty(0, 2), 0, false);
    return
end

[~, ~, ext] = fileparts(name);
if ext ~= ""
    % CLOSED AT STAGE C, as promised. The outline is read by
    % geo.readCoastline and its box padded exactly as a hand-passed
    % outline's is - the same code path below, not a parallel one, so the
    % two cannot drift.
    outline = geo.readCoastline(name);
    [lonLim, latLim] = boxFromOutline(outline, padding);
    R = makeRegion("", lonLim, latLim, outline, padding, false);
    return
end

error('geo:region:UnknownPreset', ...
    ['"%s" is not a preset and has no file extension to read as a ' ...
     'boundary. The presets are: %s.'], name, strjoin([P.name], ', '));
end

function P = presetTable()
%PRESETTABLE  Conventional approximate boxes. NOT authoritative borders.
%   A plain struct array, not containers.Map (discouraged in R2026a) and
%   not dictionary: thirteen fixed rows written once and read by name need
%   no hashing.
n = {"world", "global", "europe", "africa", "asia", "northamerica", ...
     "southamerica", "oceania", "australia", "middleeast", ...
     "centralamerica", "arctic", "antarctica"};
b = {[-180 180 -90 90], [-180 180 -90 90], [-25 45 34 72], ...
     [-20 55 -35 38], [25 180 -10 82], [-170 -50 5 85], ...
     [-82 -34 -56 13], [110 180 -50 -5], [110 155 -45 -10], ...
     [25 63 12 42], [-95 -75 5 23], [-180 180 60 90], [-180 180 -90 -60]};
P = struct('name', n, 'box', b);
end

function [lonLim, latLim] = boxFromOutline(outline, padding)
%BOXFROMOUTLINE  Padded bounding box of a possibly NaN-separated outline.
ok = isfinite(outline(:, 1)) & isfinite(outline(:, 2));
if ~any(ok)
    error('geo:region:EmptyOutline', ...
        'The outline has no finite points, so it bounds nothing.');
end
lon = outline(ok, 1);
lat = outline(ok, 2);
% max(span, 1e-6) so a single point still gets a visible box rather than
% a zero-width one that every downstream axis limit would reject.
lonPad = padding * max(max(lon) - min(lon), 1e-6);
latPad = padding * max(max(lat) - min(lat), 1e-6);
lonLim = [min(lon) - lonPad, max(lon) + lonPad];
latLim = clampLat([min(lat) - latPad, max(lat) + latPad]);
end

function lim = clampLat(lim)
%CLAMPLAT  Latitude cannot leave the sphere, however much padding asks.
lim = [max(-90, lim(1)), min(90, lim(2))];
end

function R = makeRegion(name, lonLim, latLim, outline, padding, isEmpty)
%MAKEREGION  One constructor, and OUTLINE ALWAYS MEANS THE SAME THING.
%   A box used to arrive here with an empty outline, so Outline meant
%   "the polygon, if this region happened to be given as one" - a field
%   whose meaning depended on how the region was built. Anything wanting
%   to DRAW a region then had to ask which kind it was and derive the
%   rectangle itself, which is how a front ends up doing geometry.
%
%   A box has four corners. They are computed here, once, so Outline
%   means "the vertices of this region" for every region, and
%   geo.coastline(Kind = "outline", Source = R.Outline) works on all of
%   them. Closed with a repeated first vertex, because an outline that
%   does not close draws three sides of a rectangle.
if isempty(outline) && ~isEmpty
    outline = [lonLim(1) latLim(1); lonLim(2) latLim(1); ...
               lonLim(2) latLim(2); lonLim(1) latLim(2); ...
               lonLim(1) latLim(1)];
end
R = struct( ...
    'Identity', "geo.region", ...
    'Name', name, ...
    'LonLim', double(lonLim(:)).', ...
    'LatLim', double(latLim(:)).', ...
    'Outline', outline, ...
    'Padding', padding, ...
    'IsEmpty', isEmpty);
end
