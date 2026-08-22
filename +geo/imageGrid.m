function IG = imageGrid(lon, lat, RGB, options)
%GEO.IMAGEGRID  A true-colour raster on a geographic axes pair.
%
%   SYNTAX
%     IG = GEO.IMAGEGRID(LON, LAT, RGB)
%     IG = GEO.IMAGEGRID(..., Name, Value)
%
%   DESCRIPTION
%     Wraps an RGB raster and its geographic axes into the struct the
%     drawing layer consumes, validating the pairing that a caller
%     otherwise discovers as a picture in the wrong place.
%
%     WHY THIS IS NOT A THREE-BAND GEO.GRID (decision D-024). A
%     GEO.GRID carries a colour scale: CLim, a colormap, a colorbar, a
%     hillshade, a NaN colour. An image carries none of those - its
%     colours ARE the data - and it must never consume the colour scale
%     that the field drawn on top of it owns. Sharing one kind would put
%     an `if ndims(Z) == 3` branch in every consumer of every grid, and
%     each of those branches would be a place for a backdrop to steal a
%     colorbar.
%
%     WHAT IT IS FOR. A photographic backdrop under sparse data - a
%     ground track, a set of stations, a basin outline - where a
%     shaded-relief base says less than an image does. NASA's Blue
%     Marble is the case this was built for; any georeferenced raster
%     with a regular axes pair works.
%
%     ROW ORDER IS MEASURED, NEVER ASSUMED (R3). Image files conventionally
%     run north to south and grids conventionally run south to north, so a
%     rule based on the source would be right about half the time and
%     silently upside down the other half. LAT is read: if it descends,
%     the raster and the vector are flipped together so the returned
%     struct always ascends. `Flipped` records whether that happened,
%     because a caller comparing against the file on disk needs to know.
%
%   INPUTS
%     lon  (1,:) double         Degrees east, monotonic, equally spaced.
%     lat  (1,:) double         Degrees north, monotonic, equally spaced.
%     RGB  (:,:,3) uint8|double The raster. numel(lat) rows by numel(lon)
%                               columns. double is taken as 0..1 and
%                               converted to uint8 once, here, so no
%                               consumer has to ask which it holds.
%
%   OPTIONS
%     Registration (1,1) string  ["cell"]  "cell" when LON and LAT give
%                               cell centres, "posting" when they give
%                               node positions. Not measurable from the
%                               axes - a vector of centres and a vector
%                               of nodes look identical - so it is an
%                               option with a documented default and not
%                               a guess.
%     Source       (1,1) string  [""]      Where the raster came from.
%     Alpha        (:,:) double  []        Per-pixel opacity in 0..1,
%                               same size as one band. Empty means opaque.
%
%   OUTPUTS
%     IG  (1,1) struct  Fields:
%          Identity     (1,1) string   Always "geo.imageGrid".
%          Lon          (1,:) double   Ascending.
%          Lat          (1,:) double   Ascending.
%          RGB          (:,:,3) uint8
%          Alpha        (:,:) double   Empty when opaque.
%          LonStep      (1,1) double   Signed step, always positive here.
%          LatStep      (1,1) double
%          IsGlobalLon  (1,1) logical  Measured: does the span plus one
%                                      step close 360 degrees?
%          Registration (1,1) string
%          Flipped      (1,1) logical  True when LAT descended on input.
%          Source       (1,1) string
%
%   ACCURACY
%     No numerical claim of its own: it validates and rearranges. The
%     one derived quantity is the step, taken as the mean difference and
%     asserted equal to every difference within 1e-9 of a step - the same
%     tolerance and the same reasoning as GEO.GRID, so that a raster and
%     a field on the same axes cannot disagree about whether they are
%     regular.
%
%   ERRORS
%     Input geometry:
%       geo:imageGrid:SizeMismatch   - RGB is not numel(lat) x numel(lon) x 3
%       geo:imageGrid:NonMonotonic   - lon or lat does not increase or
%                                      decrease throughout
%       geo:imageGrid:UnevenStep     - a step differs from the mean by
%                                      more than 1e-9 of it
%       geo:imageGrid:AlphaMismatch  - Alpha is not the size of one band
%     Domain:
%       geo:imageGrid:BadRange       - a double RGB outside 0..1
%
%   EXAMPLE
%     lon = -180:0.5:179.5;
%     lat = -89.75:0.5:89.75;
%     IG  = geo.imageGrid(lon, lat, blueMarble, Source = "NASA BMNG");
%     IG.IsGlobalLon
%
%   LIMITATIONS
%     Regular axes only. A rotated or affine raster - a GeoTIFF with a
%     sheared geotransform - is not representable here and is rejected by
%     the reader rather than silently squared up.
%
%     It does not reproject. The raster is assumed to be on a plain
%     geographic axes pair; a raster in a projected CRS must be warped
%     before it arrives.
%
%   See also GEO.GRID, GEO.BASEMAP, GEO.READGRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon (1,:) double {mustBeReal, mustBeFinite}
    lat (1,:) double {mustBeReal, mustBeFinite}
    RGB {mustBeNumeric}
    options.Registration (1,1) string {mustBeMember(options.Registration, ...
        ["cell" "posting"])} = "cell"
    options.Source (1,1) string = ""
    options.Alpha double = []
end

nLon = numel(lon);
nLat = numel(lat);
if ndims(RGB) ~= 3 || size(RGB, 3) ~= 3 || size(RGB, 1) ~= nLat || ...
        size(RGB, 2) ~= nLon
    error("geo:imageGrid:SizeMismatch", ...
        "RGB is %s; %d lat by %d lon by 3 was required.", ...
        mat2str(size(RGB)), nLat, nLon);
end
if ~isempty(options.Alpha) && ~isequal(size(options.Alpha), [nLat nLon])
    error("geo:imageGrid:AlphaMismatch", ...
        "Alpha is %s; %d by %d was required.", ...
        mat2str(size(options.Alpha)), nLat, nLon);
end

lonStep = uniformStep(lon, "lon");
latStep = uniformStep(lat, "lat");

if isa(RGB, 'double')
    if any(RGB(:) < 0) || any(RGB(:) > 1)
        error("geo:imageGrid:BadRange", ...
            "A double RGB is taken as 0..1; this one spans %g to %g.", ...
            min(RGB(:)), max(RGB(:)));
    end
    RGB = uint8(round(RGB * 255));
else
    RGB = uint8(RGB);
end

% R3: the row order is READ. Flipping here means every consumer can
% assume ascending, instead of each one asking and half of them forgetting.
flipped = latStep < 0;
if flipped
    lat = fliplr(lat);
    RGB = flipud(RGB);
    if ~isempty(options.Alpha)
        options.Alpha = flipud(options.Alpha);
    end
    latStep = -latStep;
end
if lonStep < 0
    lon = fliplr(lon);
    RGB = fliplr(RGB);
    if ~isempty(options.Alpha)
        options.Alpha = fliplr(options.Alpha);
    end
    lonStep = -lonStep;
end

% Measured, not declared: does this raster close the globe? A cell-
% registered world image spans 360 minus one step; a posted one spans a
% full 360 with a repeated seam column.
if options.Registration == "cell"
    span = (lon(end) - lon(1)) + lonStep;
else
    span = lon(end) - lon(1);
end
isGlobal = nLon > 1 && abs(span - 360) < 1e-9 * 360;

IG = struct( ...
    'Identity', "geo.imageGrid", ...
    'Lon', lon, 'Lat', lat, 'RGB', RGB, 'Alpha', options.Alpha, ...
    'LonStep', lonStep, 'LatStep', latStep, ...
    'IsGlobalLon', isGlobal, 'Registration', options.Registration, ...
    'Flipped', flipped, 'Source', options.Source);
end

% ======================================================================
function step = uniformStep(v, name)
%UNIFORMSTEP  The step, refusing a vector that does not have one.
if numel(v) < 2
    step = 1;
    return
end
d = diff(v);
step = mean(d);
if any(sign(d) ~= sign(step)) || step == 0
    error("geo:imageGrid:NonMonotonic", ...
        "%s must increase or decrease throughout.", name);
end
if any(abs(d - step) > 1e-9 * abs(step))
    error("geo:imageGrid:UnevenStep", ...
        "%s steps span %g to %g; a regular axis was required.", ...
        name, min(d), max(d));
end
end
