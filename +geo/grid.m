function G = grid(lon, lat, Z, options)
%GEO.GRID  Validated lon/lat grid, checked once so nothing re-checks it.
%
%   SYNTAX
%     G = GEO.GRID(LON, LAT, Z)
%     G = GEO.GRID(LON, LAT, Z, Name, Value)
%     G = GEO.GRID(G)                       % idempotent: passes through
%
%   DESCRIPTION
%     The value struct every raster in the toolbox travels in. It replaces
%     v1's loose (lon, lat, Z[, topo]) quadruple, which every plotting
%     function re-validated in its own way and two of them got wrong in
%     different directions.
%
%     VALIDATED ONCE. Downstream functions trust what this struct
%     guarantees and say so in their own help; none of them re-checks
%     monotonicity or size. That is the point of building it.
%
%     IDEMPOTENT. GEO.GRID(G) on a grid returns it unchanged, so a
%     function can accept "a grid or the loose triple" by calling this on
%     whatever it was handed. Without that, every front would need its own
%     is-it-already-a-grid branch, and they would drift.
%
%     ISGLOBALLON IS MEASURED, NEVER INFERRED. It is true when the
%     longitude span reaches within 1.5 steps of a full circle - a test on
%     the coordinate vector itself, not on a filename, a flag or a
%     convention. The 1.5 allows for the one missing cell of a grid stored
%     0:359 as well as the exact-repeat form 0:360, and rejects a grid
%     that stops at 350. A regional grid that happens to be called
%     "global.nc" is not global, and a global grid whose creator forgot to
%     say so is.
%
%     ORIENTATION IS CANONICALISED, deliberately, and this is the one
%     place in the toolbox where an input's shape is not preserved. LON
%     becomes a row and LAT a column, so that Z(i,j) corresponds to
%     Lat(i), Lon(j) and implicit expansion against either axis works
%     without a transpose. Tracks and point sets preserve orientation;
%     a grid has a canonical one because its Z fixes it.
%
%   INPUTS
%     lon  (1,:) double  Degrees East, strictly monotone, no NaN. Or a
%                        geo.grid struct, for the idempotent form.
%     lat  (:,1) double  Degrees North, strictly monotone, no NaN.
%                        DESCENDING IS ACCEPTED - many products store
%                        north-up - and is preserved rather than flipped,
%                        because flipping silently would make Z(1,:) mean
%                        different things for different callers.
%     Z    (M,N) double  Field values, M = numel(lat), N = numel(lon).
%                        NaN allowed and means "no data" (gap convention).
%
%   OPTIONS
%     Topo   (M,N) double  []   Elevation on the same grid, for hillshade.
%     Source (1,1) string  ""   Where the data came from. Travels with it.
%     Units  (1,1) string  ""   Units of Z, e.g. "cm w.e.".
%
%   OUTPUTS
%     G  (1,1) struct  Fields:
%          Identity      (1,1) string   Always "geo.grid".
%          Lon           (1,:) double   Row, as given.
%          Lat           (:,1) double   Column, as given.
%          Z             (M,N) double
%          Topo          (M,N) double   Empty if not supplied.
%          LonStep       (1,1) double   Median step, signed.
%          LatStep       (1,1) double   Median step, signed.
%          IsGlobalLon   (1,1) logical  Measured, see DESCRIPTION.
%          Source        (1,1) string
%          Units         (1,1) string
%
%   ACCURACY
%     No numerical claim of its own: this function validates and records,
%     it does not compute. LonStep and LatStep are medians of the
%     differences rather than (last-first)/(n-1), so a grid with one
%     duplicated or slightly irregular coordinate still reports the step
%     its neighbours agree on rather than a smeared average.
%
%   ERRORS
%     Input geometry:
%       geo:grid:SizeMismatch     - size(Z) is not [numel(lat) numel(lon)]
%       geo:grid:TopoSizeMismatch - Topo is not the same size as Z
%       geo:grid:NotAVector       - lon or lat is not a vector
%     Coordinate validity:
%       geo:grid:NonMonotonic     - a coordinate vector is not strictly
%                                   monotone
%       geo:grid:NaNCoordinate    - NaN or Inf in a coordinate vector.
%                                   NaN is the gap convention for DATA;
%                                   a gap in an axis is not a gap, it is
%                                   an unanswerable question about where
%                                   the neighbouring cells are
%       geo:grid:TooFewPoints     - fewer than two points on an axis
%
%   EXAMPLE
%     G = geo.grid(-179.5:179.5, (-89.5:89.5)', rand(180, 360), ...
%                  Units = "cm/yr", Source = "JPL RL06 mascon");
%     G.IsGlobalLon    % true, measured from the vector
%
%   LIMITATIONS
%     Rectilinear grids only: one longitude vector and one latitude
%     vector. Curvilinear and unstructured meshes are out of scope for
%     v2 and are not silently accepted - the size check rejects them.
%
%   See also GEO.TRACK, GEO.POINTS, GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon
    lat double = []
    Z double = []
    options.Topo double = []
    options.Source (1,1) string = ""
    options.Units (1,1) string = ""
    options.Registration (1,1) string ...
        {mustBeMember(options.Registration, ...
                      ["auto" "posting" "cell"])} = "auto"
end

% Idempotent form. Checked before anything else so a grid never pays for
% re-validation, which is what makes it safe to call this everywhere.
if isstruct(lon)
    G = passThrough(lon, nargin);
    return
end

mustBeAxis(lon, "lon");
mustBeAxis(lat, "lat");

nLon = numel(lon);
nLat = numel(lat);
if ~isequal(size(Z), [nLat nLon])
    error('geo:grid:SizeMismatch', ...
        ['Z is %dx%d but the axes give %dx%d (numel(lat) by numel(lon)). ' ...
         'A transposed Z is the usual cause, and it is rejected rather ' ...
         'than transposed for you: guessing would put half of all data ' ...
         'sideways without saying so.'], ...
        size(Z, 1), size(Z, 2), nLat, nLon);
end
if ~isempty(options.Topo) && ~isequal(size(options.Topo), size(Z))
    error('geo:grid:TopoSizeMismatch', ...
        'Topo is %dx%d but Z is %dx%d; they must share the grid.', ...
        size(options.Topo, 1), size(options.Topo, 2), ...
        size(Z, 1), size(Z, 2));
end

lonRow = double(lon(:)).';
latCol = double(lat(:));
lonStep = median(diff(lonRow));
latStep = median(diff(latCol));
reg = resolveRegistration(options.Registration, lonRow, lonStep, ...
    latCol(:).', latStep);

G = struct( ...
    'Identity', "geo.grid", ...
    'Lon', lonRow, ...
    'Lat', latCol, ...
    'Z', double(Z), ...
    'Topo', double(options.Topo), ...
    'LonStep', lonStep, ...
    'LatStep', latStep, ...
    'IsGlobalLon', measureGlobalLon(lonRow, lonStep), ...
    'Registration', reg, ...
    'LonRegion', regionOf(lonRow, lonStep, reg), ...
    'LatRegion', regionOf(latCol(:).', latStep, reg), ...
    'Source', options.Source, ...
    'Units', options.Units);
end

% ======================================================================
function reg = resolveRegistration(asked, lon, lonStep, lat, latStep)
%RESOLVEREGISTRATION  Posting or cell, inferred from the axes themselves.
%
%   The distinction is not this toolbox's invention. GMT calls it
%   gridline versus pixel registration and defaults to gridline; MATLAB's
%   Mapping Toolbox calls it 'postings' versus 'cells'; GDAL carries it
%   in the geotransform. A POSTING is a value AT a point; a CELL is a
%   value OVER an area, and its region runs half a step beyond the
%   outermost node on each side.
%
%   Getting this wrong is what produced the antimeridian wedge: a grid
%   written -179.5:1:179.5 covers the world exactly, and reading its NODE
%   limits as its region loses a cell (PV-140).
%
%   INFERENCE, and only from evidence:
%     span == 360 (or 180 in latitude)          -> posting, both rims held
%     span == 360 - step (or 180 - step)        -> cell, rims implied
%     anything else                             -> no evidence
%
%   With no evidence the answer is POSTING, which is what every consumer
%   assumed before this field existed, so a regional grid is unchanged.
%   Longitude and latitude are read separately and must AGREE; a grid
%   that looks cell-registered one way and posting the other is a finding
%   and is raised, not silently resolved in favour of one axis.
if asked ~= "auto"
    reg = asked;
    return
end
byLon = inferAxis(lon, lonStep, 360);
byLat = inferAxis(lat, latStep, 180);
if byLon ~= "unknown" && byLat ~= "unknown" && byLon ~= byLat
    error('geo:grid:RegistrationAmbiguous', ...
        ['Longitude looks %s-registered and latitude looks %s. One ' ...
         'grid cannot be both. Pass Registration explicitly to say ' ...
         'which is meant.'], byLon, byLat);
end
if byLon ~= "unknown"
    reg = byLon;
elseif byLat ~= "unknown"
    reg = byLat;
else
    reg = "posting";
end
end

function r = inferAxis(v, step, full)
%INFERAXIS  What the span of one axis says about registration.
%   The tolerance is a hundredth of a step, not an absolute: a 0.25-degree
%   axis and a 5-arcminute one carry different rounding.
if numel(v) < 2 || ~isfinite(step) || step <= 0
    r = "unknown";
    return
end
span = abs(v(end) - v(1));
tol = 0.01 * step;
if abs(span - full) <= tol
    r = "posting";
elseif abs(span - (full - step)) <= tol
    r = "cell";
else
    r = "unknown";
end
end

function lim = regionOf(v, step, reg)
%REGIONOF  The area a grid COVERS, as against the points it holds.
%   A cell grid's region runs half a step beyond its outermost nodes; a
%   posting grid's region ends on them. Both give exactly 360 for a
%   global longitude axis, from opposite conventions.
if isempty(v)
    lim = [NaN NaN];
    return
end
if reg == "cell" && isfinite(step)
    lim = [min(v) - abs(step) / 2, max(v) + abs(step) / 2];
else
    lim = [min(v), max(v)];
end
end

% ======================================================================
function tf = measureGlobalLon(lon, step)
%MEASUREGLOBALLON  Does the longitude axis reach around the world?
%   Measured from the vector (handover 2.7), with a 1.5-step allowance so
%   that both storage conventions count:
%     0:359    span 359, one cell short of the circle  -> global
%     0:360    span 360, the seam repeated             -> global
%     0:350    span 350, genuinely regional            -> not global
tf = abs(lon(end) - lon(1)) >= 360 - 1.5 * abs(step);
end

function mustBeAxis(v, what)
%MUSTBEAXIS  A coordinate vector: numeric, real, finite, strictly monotone.
if ~isnumeric(v) || ~isreal(v) || ~isvector(v)
    error('geo:grid:NotAVector', ...
        '%s must be a real numeric vector.', what);
end
if numel(v) < 2
    error('geo:grid:TooFewPoints', ...
        ['%s has %d point(s). A grid axis needs at least two, because ' ...
         'a single point has no step and every later function asks for ' ...
         'one.'], what, numel(v));
end
if ~all(isfinite(v))
    error('geo:grid:NaNCoordinate', ...
        ['%s contains NaN or Inf. NaN is this toolbox''s gap convention ' ...
         'for DATA; in an axis it is not a gap but an unanswerable ' ...
         'question about where the neighbouring cells lie.'], what);
end
d = diff(double(v(:)));
if ~(all(d > 0) || all(d < 0))
    error('geo:grid:NonMonotonic', ...
        ['%s is not strictly monotone. Descending is accepted and ' ...
         'preserved; what is rejected is a reversal or a repeat, which ' ...
         'makes interpolation ambiguous rather than merely unusual.'], ...
        what);
end
end

function G = passThrough(G, nIn)
%PASSTHROUGH  The idempotent path: validate identity, return unchanged.
geo.internal.mustBeIdentity(G, "geo.grid", 'geo:grid:NotAGrid');
if nIn > 1
    error('geo:grid:SizeMismatch', ...
        ['A geo.grid was given as the first argument, so the remaining ' ...
         'arguments have nothing to describe. Pass the struct alone, or ' ...
         'the loose triple.']);
end
end
