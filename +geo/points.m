function P = points(lon, lat, options)
%GEO.POINTS  Validated scattered point set, with optional size and labels.
%
%   SYNTAX
%     P = GEO.POINTS(LON, LAT)
%     P = GEO.POINTS(LON, LAT, Name, Value)
%     P = GEO.POINTS(P)                     % idempotent: passes through
%
%   DESCRIPTION
%     The value struct a scattered set of locations travels in - stations,
%     epicentres, mascon centres - replacing v1's loose (lon, lat, obs)
%     triple.
%
%     WHY THIS IS NOT A TRACK WITH THE TIME REMOVED. A track is ordered
%     and its NaNs mean gaps in a path; a point set is unordered and its
%     NaNs mean a point with no location, which is a different thing and
%     is dropped rather than drawn around. Sharing one struct for both
%     would make the NaN convention ambiguous, and the two would
%     substitute for each other silently - which is why each carries its
%     own Identity.
%
%     SIZEDATA AND OBS ARE SEPARATE ON PURPOSE. v1 overloaded one vector
%     for both colour and marker size, so a caller who wanted size by
%     magnitude and colour by sign could not have both. They are two
%     questions about a point and they get two fields.
%
%   INPUTS
%     lon  (:,1) or (1,:) double  Degrees East. Or a geo.points struct,
%                                 for the idempotent form.
%     lat  same size as lon       Degrees North.
%
%   OPTIONS
%     Obs       same size as lon  []  Value at each point, for colour.
%     SizeData  same size as lon  []  Value at each point, for marker
%                                     size. Must be non-negative where
%                                     finite: a negative area is not a
%                                     small marker, it is a mistake.
%     Labels    same size as lon  []  String array, one per point.
%     Source    (1,1) string      ""  Where the data came from.
%     Units     (1,1) string      ""  Units of Obs.
%
%   OUTPUTS
%     P  (1,1) struct  Fields:
%          Identity   (1,1) string   Always "geo.points".
%          Lon        same shape as given
%          Lat        same shape as given
%          Obs        as given, or empty
%          SizeData   as given, or empty
%          Labels     as given, or empty
%          NumPoints  (1,1) double   numel(Lon), including unlocated ones.
%          NumLocated (1,1) double   Points with finite lon AND lat.
%          Source     (1,1) string
%          Units      (1,1) string
%
%   ACCURACY
%     No numerical claim. NumLocated requires BOTH coordinates finite,
%     because a point with a longitude and no latitude cannot be drawn
%     and counting it as located would make the two numbers agree while
%     the map showed fewer markers than either.
%
%   ERRORS
%     Input geometry:
%       geo:points:SizeMismatch    - an optional vector is not the same
%                                    size as lon
%       geo:points:NotAVector      - an input is not a vector
%     Value validity:
%       geo:points:NegativeSize    - SizeData has a negative entry
%     Identity:
%       geo:points:NotAPoints      - the idempotent form was given a
%                                    struct that is not a geo.points
%
%   EXAMPLE
%     P = geo.points([10 20 30], [50 51 52], ...
%                    Obs = [-2 0 3], SizeData = [1 4 9], ...
%                    Labels = ["Bonn" "Kiel" "Jena"]);
%     P.NumLocated    % 3
%
%   LIMITATIONS
%     No de-duplication and no spatial index. Two points at the same
%     location are two points, because deciding they are one is a
%     modelling choice this constructor has no business making.
%
%   See also GEO.TRACK, GEO.GRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon
    lat = []
    options.Obs = []
    options.SizeData = []
    options.Labels string = string.empty
    options.Source (1,1) string = ""
    options.Units (1,1) string = ""
end

if isstruct(lon)
    geo.internal.mustBeIdentity(lon, "geo.points", 'geo:points:NotAPoints');
    P = lon;
    return
end

geo.internal.mustBeSeries(lon, "lon", 'geo:points:NotAVector');
geo.internal.mustBeSeries(lat, "lat", 'geo:points:NotAVector');
n = numel(lon);
if numel(lat) ~= n
    error('geo:points:SizeMismatch', ...
        'lat has %d elements; lon has %d.', numel(lat), n);
end

for f = ["Obs" "SizeData"]
    v = options.(f);
    if isempty(v), continue, end
    geo.internal.mustBeSeries(v, f, 'geo:points:NotAVector');
    if numel(v) ~= n
        error('geo:points:SizeMismatch', ...
            '%s has %d elements; lon has %d.', f, numel(v), n);
    end
end
if ~isempty(options.Labels) && numel(options.Labels) ~= n
    error('geo:points:SizeMismatch', ...
        'Labels has %d elements; lon has %d.', ...
        numel(options.Labels), n);
end

if ~isempty(options.SizeData) && any(options.SizeData < 0)
    error('geo:points:NegativeSize', ...
        ['SizeData has %d negative entry/entries. A negative marker ' ...
         'area is not a small marker; it is a sign error upstream, and ' ...
         'silently taking its absolute value would hide that.'], ...
        sum(options.SizeData < 0));
end

P = struct( ...
    'Identity', "geo.points", ...
    'Lon', double(lon), ...
    'Lat', double(lat), ...
    'Obs', double(options.Obs), ...
    'SizeData', double(options.SizeData), ...
    'Labels', options.Labels, ...
    'NumPoints', n, ...
    'NumLocated', sum(isfinite(lon(:)) & isfinite(lat(:))), ...
    'Source', options.Source, ...
    'Units', options.Units);
end
