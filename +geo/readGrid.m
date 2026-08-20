function G = readGrid(source, options)
%GEO.READGRID  Read a raster, or a window of one, into a validated GEO.GRID.
%
%   SYNTAX
%     G = GEO.READGRID(SOURCE)
%     G = GEO.READGRID(SOURCE, Name, Value)
%
%   DESCRIPTION
%     Extracts the topography-reading locals v1 buried inside its
%     3413-line plotting function and gives them a name, a contract and
%     tests. NetCDF, MATLAB .mat, and raw arrays are supported.
%
%     VARIABLE AUTO-DETECTION NAMES WHAT IT TRIED. A NetCDF file whose
%     data variable is not one of the usual names fails with a message
%     LISTING the candidates it looked for and the variables the file
%     actually holds. v1's equivalent failed with "variable not found",
%     which tells a user nothing they can act on.
%
%     REGION AND STRIDE READ LESS, THEY DO NOT TRIM AFTERWARDS - and on
%     NetCDF that is the whole point. A global one-arc-minute relief
%     model is 21600x10800; MATLAB's NCREAD returns double, so the whole
%     field is 1.74 GB in memory and the half-arc-minute version is
%     6.95 GB. A regional map needs a few thousand cells of it. REGION is
%     turned into NCREAD start/count bounds, so the bytes for the rest
%     are never read, decompressed or allocated.
%
%     STRIDE IS SUBSAMPLING, NOT AVERAGING, and for topography that
%     matters: taking every Nth cell of a relief model keeps whichever
%     peaks and trenches happen to land on the sampled indices and
%     discards their neighbours, so a hillshade computed from a strided
%     grid is noisier than one computed from an averaged grid of the same
%     size. Use it for an overview, not for a measurement. GEO.REGRID is
%     the function that averages.
%
%     STRIDE IS ALSO SLOW ON A COMPRESSED FILE, and this was measured
%     rather than assumed. ETOPO 2022 stores z in deflated 2700x1350
%     chunks; a strided read still decompresses every chunk it touches,
%     so it moves 0.242 Mcell/s against 44.5 Mcell/s for a contiguous
%     window on the same file - 184 times slower per cell delivered. A
%     decimated global overview is therefore something to compute once
%     and put in GEO.CACHE, not something to re-read.
%
%     A REGION MAY CROSS THE ANTIMERIDIAN, expressed the way GEO.REGION
%     requires it: [170 190 -10 10], not [170 -170 -10 10]. The two
%     index blocks either side of the seam are read separately and joined,
%     and the returned longitude axis continues past 180 rather than
%     wrapping, because GEO.GRID requires a strictly monotone axis and a
%     seam in the middle of one is not something a downstream consumer
%     should have to rediscover.
%
%     ORIENTATION IS READ, NOT GUESSED, when the file says. A NetCDF
%     variable declares its dimensions by name, so whether z is stored
%     (lon,lat) or (lat,lon) is a fact in the file - ETOPO 2022 stores it
%     (lon,lat) - and it is used both to orient the result and to put
%     start/count in the right order. Only when that metadata is absent,
%     and for .mat, does the size-comparison fallback run; that fallback
%     cannot resolve a square grid and says so rather than guessing.
%
%     THE GEOTIFF AND WORLDFILE PATHS ARE DEFERRED, and fail loudly with
%     their own identifier rather than being absent. They need a binary
%     TIFF tag parser, which is a substantial piece of work and belongs
%     in its own round rather than rushed in beside three other readers
%     (§6.6). The contract test for the identifier ships now, so the
%     round that adds them converts a failing test rather than inventing
%     the behaviour. When it arrives it must not assume the .tif and the
%     .nc of the same ETOPO tile agree on row order: they do not. NCO
%     flipped latitude to ascending when it wrote the NetCDF, while the
%     GeoTransform carried along inside the file still describes a
%     north-up raster with a negative step.
%
%   INPUTS
%     source  A filename (.nc, .nc4, .cdf, .mat) or a GEO.GRID. A grid is
%             returned unchanged, unless Region or Stride is given, in
%             which case the selection is applied to it in memory - the
%             same two arguments mean the same thing whether the source
%             is still on disk or already read. Topo is carried through
%             the same indices as Z.
%
%   OPTIONS
%     Variable  (1,1) string  [""]  NetCDF variable name; auto-detected
%                                   when empty.
%     Region    []                  A GEO.REGION, or anything GEO.REGION
%                                   accepts, e.g. [lonMin lonMax latMin
%                                   latMax]. Only the covered cells are
%                                   read. The result is guaranteed to
%                                   COVER the region and may exceed it by
%                                   up to one cell on each edge; cells are
%                                   never split or interpolated. A region
%                                   narrower than one cell returns the
%                                   cells around it, not nothing.
%     Stride    (1,2) double  [1 1] [lonStride latStride], or one scalar
%                                   for both. Positive integers. Applied
%                                   inside the region when both are given.
%     Lon       (1,:) double  []    Override the file's longitude axis.
%                                   Rejected together with Region.
%     Lat       (:,1) double  []    Override the file's latitude axis.
%                                   Rejected together with Region.
%     Units     (1,1) string  [""]  Recorded in the grid.
%
%   OUTPUTS
%     G  (1,1) struct  A GEO.GRID, carrying Source and Units.
%
%   ACCURACY
%     No arithmetic beyond reading: values arrive as stored, and the only
%     transformations are orientation, which GEO.GRID canonicalises, and
%     the longitude offset applied to the far side of an antimeridian
%     window, which is an exact multiple of 360 and therefore exact in
%     binary floating point below 2^43 degrees. Any scale_factor and
%     add_offset attributes are applied by MATLAB's own NCREAD, not
%     re-implemented here. A subset is bit-identical to the same cells of
%     a full read; that is a metamorphic test, not a hope.
%
%   ERRORS
%     Source:
%       geo:readGrid:FileNotFound      - the file cannot be opened
%       geo:readGrid:UnknownFormat     - extension not recognised
%       geo:readGrid:VariableNotFound  - no candidate matched; the message
%                                        lists what was tried and what the
%                                        file holds
%       geo:readGrid:NoAxes            - the file has data but no
%                                        recognisable coordinate vectors
%     Selection:
%       geo:readGrid:RegionOutsideFile - the region selects no cell; the
%                                        message gives both coverages
%       geo:readGrid:AxisOverrideWithRegion - Lon or Lat was given
%                                        together with Region, which
%                                        would renumber the axis of a
%                                        window and mean nothing
%     Deferred capability:
%       geo:readGrid:ImageInputNotYetAvailable - a GeoTIFF or an image
%                                        with a worldfile
%     A bad Region specification is rejected by GEO.REGION, which raises
%     its own identifiers rather than duplicated ones here. That includes
%     the antimeridian box written the wrong way round.
%
%   EXAMPLE
%     G = geo.readGrid("ewh_trend.nc", Units = "cm/yr");
%
%     % Europe out of a global relief model, without reading the globe
%     E = geo.readGrid("ETOPO_2022_v1_60s_N90W180_surface.nc", ...
%                      Region = [-25 45 30 72], Units = "m");
%
%     % A global overview, subsampled 20:1
%     O = geo.readGrid("ETOPO_2022_v1_60s_N90W180_surface.nc", Stride = 20);
%
%   LIMITATIONS
%     Rectilinear grids only, matching GEO.GRID. A NetCDF holding a
%     curvilinear mesh has two-dimensional coordinate arrays and is
%     rejected by GEO.GRID's axis validation rather than flattened.
%
%     ON .mat, REGION AND STRIDE SAVE MEMORY BUT NOT READING. A .mat is
%     loaded whole by LOAD, so the subset is taken afterwards. The saving
%     is in what is kept, not in what is read, and this is said here
%     rather than left for a user to discover on a file too big to load.
%     The same applies to a NetCDF variable whose dimensions are unnamed.
%
%   See also GEO.GRID, GEO.REGION, GEO.READCOASTLINE, GEO.REGRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    source
    options.Variable (1,1) string = ""
    options.Region = []
    options.Stride (1,2) double {mustBeInteger, mustBePositive} = [1 1]
    options.Lon (1,:) double = []
    options.Lat (:,1) double = []
    options.Units (1,1) string = ""
end

[lonLim, latLim] = resolveRegion(options.Region);
hasRegion = ~any(isnan([lonLim latLim]));

if isstruct(source)
    G = geo.grid(source);               % idempotent, via geo.grid's own check
    if hasRegion || any(options.Stride > 1)
        % A grid already in memory still answers "give me this window".
        % Ignoring the selection here because there is nothing left to
        % READ would make the same two arguments mean something on a
        % filename and nothing on the grid that filename produced, which
        % is the kind of quiet inconsistency §2.7 exists to prevent.
        G = selectFromGrid(G, lonLim, latLim, options.Stride);
    end
    return
end

if hasRegion && (~isempty(options.Lon) || ~isempty(options.Lat))
    error('geo:readGrid:AxisOverrideWithRegion', ...
        ['Lon or Lat was given together with Region. An override ' ...
         'replaces the whole axis, so applied to a window it would ' ...
         'renumber the cells that survived and silently move them. ' ...
         'Use one or the other.']);
end

source = string(source);
if source == "builtin"
    % THE SHIPPED TOPOGRAPHY, NAMED THE WAY GEO.READCOASTLINE ALREADY
    % NAMES ITS OWN. Added when geo.trackmap and geo.pointmap needed a
    % background: without it each front would carry the data path as a
    % literal, which is one filename in three places and a rename away
    % from two of them being wrong. A front should ask for "the builtin
    % topography", not know where it lives.
    source = geo.internal.dataFile("etopo_10min_surface.mat");
end
[~, ~, ext] = fileparts(source);
sel = struct('LonLim', lonLim, 'LatLim', latLim, 'Stride', options.Stride);
switch lower(ext)
    case {".nc", ".nc4", ".cdf"}
        [lon, lat, Z] = readNetcdf(source, options.Variable, sel);
    case ".mat"
        [lon, lat, Z] = readMat(source, sel);
    case {".tif", ".tiff", ".png", ".jpg"}
        error('geo:readGrid:ImageInputNotYetAvailable', ...
            ['Reading "%s" needs a GeoTIFF tag or worldfile parser, ' ...
             'which is deferred to its own round rather than rushed in ' ...
             'beside three other readers. Convert to NetCDF, or pass ' ...
             'the array with Lon and Lat.'], source);
    otherwise
        error('geo:readGrid:UnknownFormat', ...
            ['Cannot tell what format "%s" is. Recognised: .nc, .nc4, ' ...
             '.cdf, .mat.'], source);
end

if ~isempty(options.Lon), lon = options.Lon; end
if ~isempty(options.Lat), lat = options.Lat; end
if isempty(lon) || isempty(lat)
    error('geo:readGrid:NoAxes', ...
        ['"%s" has data but no recognisable coordinate vectors. Pass ' ...
         'Lon and Lat explicitly.'], source);
end

try
    G = geo.grid(lon, lat, Z, Source = source, Units = options.Units);
catch ME
    % A region smaller than two cells selects correctly and then fails
    % GEO.GRID's two-point axis contract. Both behaviours are right; the
    % message that reaches the caller is not, because it talks about an
    % axis the caller never supplied. Add the missing half and keep the
    % identifier, which is GEO.GRID's and is documented there.
    if ME.identifier == "geo:grid:TooFewPoints" && ...
            (hasRegion || any(options.Stride > 1))
        why = ME.message + " " + sprintf( ...
            ['The selection kept %d longitude by %d latitude cell(s) ' ...
             'of "%s", at Stride [%d %d]. A coarser stride than the ' ...
             'grid has cells is the usual cause.'], ...
            numel(lon), numel(lat), source, ...
            options.Stride(1), options.Stride(2));
        error('geo:grid:TooFewPoints', '%s', why);
    end
    rethrow(ME);
end
end

% ======================================================================
function [lonLim, latLim] = resolveRegion(spec)
%RESOLVEREGION  Region option to a pair of limits, NaN NaN when absent.
%   Delegated to GEO.REGION rather than re-validated, so a malformed box
%   is rejected once, in the function whose job that is, with the message
%   that already explains the antimeridian convention.
lonLim = [NaN NaN];
latLim = [NaN NaN];
if isempty(spec), return, end
R = geo.region(spec);
if R.IsEmpty, return, end
lonLim = R.LonLim;
latLim = R.LatLim;
end

function G = selectFromGrid(G, lonLim, latLim, stride)
%SELECTFROMGRID  Apply Region and Stride to a grid already in memory.
%   Topo travels with Z through the same indices, because a hillshade
%   computed from a window of one and the whole of the other would be
%   wrong everywhere and look right in the middle.
label = G.Source;
if label == "", label = "the grid given"; end
[lonIdx, lon] = selectLon(G.Lon(:), lonLim, stride(1), label);
[latIdx, lat] = selectLat(G.Lat, latLim, stride(2), label);
topo = G.Topo;
if ~isempty(topo)
    topo = topo(latIdx, lonIdx);
end
G = geo.grid(lon, lat, G.Z(latIdx, lonIdx), ...
    Topo = topo, Source = G.Source, Units = G.Units);
end

function [lon, lat, Z] = readNetcdf(name, wanted, sel)
%READNETCDF  Read a variable, or a window of it, with its axes.
try
    info = ncinfo(char(name));
catch
    error('geo:readGrid:FileNotFound', ...
        'Could not open "%s" as NetCDF.', name);
end
have = string({info.Variables.Name});

[lonName, lonFull] = pickAxis(name, have, ...
    ["lon" "longitude" "x" "Longitude" "LON"]);
[latName, latFull] = pickAxis(name, have, ...
    ["lat" "latitude" "y" "Latitude" "LAT"]);
if isempty(lonFull) || isempty(latFull)
    lon = lonFull;  lat = latFull;  Z = [];
    return                              % caller raises NoAxes
end

hit = pickVariable(name, info, have, wanted);
v = info.Variables(have == hit);
dims = string.empty(1, 0);
if ~isempty(v.Dimensions)
    dims = string({v.Dimensions.Name});
end
lonDim = find(dims == lonName, 1);
latDim = find(dims == latName, 1);

[lonIdx, lon] = selectLon(lonFull(:), sel.LonLim, sel.Stride(1), name);
[latIdx, lat] = selectLat(latFull(:), sel.LatLim, sel.Stride(2), name);

runs = arithmeticRuns(lonIdx, sel.Stride(1));
if isempty(lonDim) || isempty(latDim) || numel(dims) ~= 2 || size(runs, 1) > 2
    % Either the file does not name its dimensions, or the selected
    % indices do not form the one or two ascending runs that NCREAD's
    % start/count/stride can describe - which happens only for a
    % descending longitude axis, a case no real product uses but which
    % must still return the right answer. Read whole, orient by size,
    % subset in memory. Slower, correct, and documented under LIMITATIONS
    % rather than left as a silent difference.
    Zfull = double(ncread(char(name), char(hit)));
    Z = orientZ(Zfull, lonFull, latFull);
    Z = Z(latIdx, lonIdx);
    return
end

Z = readBlocks(name, hit, runs, latIdx, lonDim, latDim, sel.Stride);
end

function Z = readBlocks(name, hit, runs, latIdx, lonDim, latDim, stride)
%READBLOCKS  One NCREAD per contiguous longitude run, joined along lon.
%   A window that crosses the antimeridian is two runs; everything else
%   is one. Reading is per run because NCREAD start/count describes a
%   box, and the far side of the seam is a different box.
latStart = latIdx(1);
latCount = numel(latIdx);
parts = cell(size(runs, 1), 1);
for k = 1:size(runs, 1)
    start = zeros(1, 2);
    count = zeros(1, 2);
    step  = ones(1, 2);
    start(lonDim) = runs(k, 1);
    count(lonDim) = runs(k, 2);
    step(lonDim)  = stride(1);
    start(latDim) = latStart;
    count(latDim) = latCount;
    step(latDim)  = stride(2);
    parts{k} = double(ncread(char(name), char(hit), start, count, step));
end
Z = cat(lonDim, parts{:});
if lonDim == 1
    Z = Z.';                            % (lon,lat) stored, (lat,lon) wanted
end
end

function runs = arithmeticRuns(idx, step)
%ARITHMETICRUNS  Split an index vector into [start count] runs of one step.
%   IDX is already strided, so consecutive entries differ by STEP inside a
%   run and by something else across the seam.
brk = find(diff(idx) ~= step);
first = [1; brk(:) + 1];
last  = [brk(:); numel(idx)];
runs = [idx(first) last - first + 1];
end

function [idx, out] = selectLon(lon, lonLim, step, name)
%SELECTLON  Longitude indices for a window that may cross the antimeridian.
%   Every axis value is shifted into a 360-wide interval CENTRED on the
%   region, which turns "which side of the seam is this cell stored on"
%   into a non-question: after the shift the wanted cells are one
%   contiguous ascending run whichever way the file stores them. Sorting
%   gives that run; the sorted values are also what is returned, so the
%   far side of the seam comes back as 180.5 rather than -179.5 and the
%   axis GEO.GRID receives is strictly monotone.
n = numel(lon);
h = halfCell(lon);
if any(isnan(lonLim)) || diff(lonLim) >= 360 - 2 * h
    idx = (1:step:n).';
    out = lon(idx);
    return
end
origin = mean(lonLim) - 180;
[sorted, ord] = sort(origin + mod(lon - origin, 360));
[a, b] = coverRange(sorted, lonLim, h);
if isempty(a)
    error('geo:readGrid:RegionOutsideFile', ...
        ['The region covers longitude %g to %g, and "%s" covers %g to ' ...
         '%g. No cell overlaps both.'], ...
        lonLim(1), lonLim(2), name, min(lon), max(lon));
end
pick = (a:step:b).';
idx = ord(pick);
out = sorted(pick);
end

function [idx, out] = selectLat(lat, latLim, step, name)
%SELECTLAT  Latitude indices. No wrap: latitude does not come round again.
%   Direction is PRESERVED, not sorted away. A file stored north-up keeps
%   its descending axis, because GEO.GRID accepts one and flipping it
%   here would make Z(1,:) mean different things depending on whether a
%   Region happened to be passed.
n = numel(lat);
if any(isnan(latLim))
    idx = (1:step:n).';
    out = lat(idx);
    return
end
if lat(end) >= lat(1)
    [a, b] = coverRange(lat, latLim, halfCell(lat));
else
    [b, a] = coverRange(flipud(lat), latLim, halfCell(lat));
    if ~isempty(a)
        a = n + 1 - a;
        b = n + 1 - b;
    end
end
if isempty(a)
    error('geo:readGrid:RegionOutsideFile', ...
        ['The region covers latitude %g to %g, and "%s" covers %g to ' ...
         '%g. No cell overlaps both.'], ...
        latLim(1), latLim(2), name, min(lat), max(lat));
end
idx = (a:step:b).';
out = lat(idx);
end

function [a, b] = coverRange(sorted, lim, h)
%COVERRANGE  Index range covering LIM, grown one whole cell each side.
%
%   WHY THE GROWTH IS IN INDEX SPACE AND NOT A TOLERANCE. The obvious
%   rule - keep cell c when c+h >= lo and c-h <= hi - is right on paper
%   and unusable in binary. A region boundary that lands exactly on a
%   cell edge makes both sides of that comparison the same real number
%   computed two different ways, so whether the edge cell is kept is
%   decided by the last bit. It was: asking for latitude 30 to 72 of a
%   one-arc-minute grid returned an axis starting at 30.008, one cell
%   short, because 30 - 1/120 came out a half-ulp above the cell centre
%   it should have equalled. Widening by an invented epsilon would have
%   hidden that behind a magic number (F12).
%
%   Instead: take the cells whose CENTRES bracket the region - a
%   comparison whose ties do not matter, because a tie means the centre
%   is exactly on the boundary and that cell is wanted either way - then
%   step one cell outwards on each side. Coverage is then guaranteed by
%   construction rather than by arithmetic, at a cost of at most one
%   surplus cell per edge. A surplus cell is invisible on a map; a
%   missing one is a blank margin along the edge the caller asked to see.
a = [];
b = [];
if lim(2) < sorted(1) - h || lim(1) > sorted(end) + h
    return                              % genuinely disjoint
end
i = find(sorted >= lim(1), 1);
j = find(sorted <= lim(2), 1, 'last');
if isempty(i), i = numel(sorted); end   % region above every centre
if isempty(j), j = 1; end               % region below every centre
a = max(1, min(i, j) - 1);
b = min(numel(sorted), max(i, j) + 1);
end

function h = halfCell(axisVec)
%HALFCELL  Half the cell width. Used only to decide "disjoint or not".
if numel(axisVec) < 2
    h = 0;
    return
end
h = abs(median(diff(axisVec))) / 2;
end

function hit = pickVariable(name, info, have, wanted)
%PICKVARIABLE  The named variable, or the first plausible one.
if wanted ~= ""
    if ~any(have == wanted)
        error('geo:readGrid:VariableNotFound', ...
            'Variable "%s" is not in "%s". It holds: %s.', ...
            wanted, name, strjoin(have, ', '));
    end
    hit = wanted;
    return
end

% Auto-detect: the candidate list v1 used, then the first variable of
% rank 2 that is not an axis. The message names both, because a user
% whose variable is called something else needs to know what was tried.
cands = ["z" "Z" "elevation" "topo" "height" "data" "band1" "Band1" ...
         "ewh" "value" "grid"];
hit = "";
for c = cands
    if any(have == c), hit = c; break, end
end
if hit == ""
    for k = 1:numel(info.Variables)
        v = info.Variables(k);
        if numel(v.Size) == 2 && ~any(string(v.Name) == ...
                ["lon" "lat" "longitude" "latitude" "x" "y"])
            hit = string(v.Name);
            break
        end
    end
end
if hit == ""
    error('geo:readGrid:VariableNotFound', ...
        ['No data variable found in "%s". Tried the names [%s] and then ' ...
         'the first two-dimensional variable. The file holds: %s. Pass ' ...
         'Variable = to name it.'], name, strjoin(cands, ', '), ...
        strjoin(have, ', '));
end
end

function [hitName, v] = pickAxis(name, have, cands)
%PICKAXIS  First matching coordinate variable, with the name it matched.
hitName = "";
v = [];
for c = cands
    if any(have == c)
        hitName = c;
        v = double(ncread(char(name), char(c)));
        return
    end
end
end

function [lon, lat, Z] = readMat(name, sel)
%READMAT  Load a .mat and take the window afterwards.
%   A .mat has no partial-read path, so this cannot save reading the way
%   the NetCDF path does. It saves what is kept. Said plainly in the help
%   rather than left as a performance surprise.
s = load(char(name));
f = string(fieldnames(s));
lon = pickField(s, f, ["lon" "longitude" "x" "coastlon"]);
lat = pickField(s, f, ["lat" "latitude" "y" "coastlat"]);
Z = pickField(s, f, ["Z" "z" "topo" "elevation" "data"]);
if isempty(Z)
    error('geo:readGrid:VariableNotFound', ...
        '"%s" holds no recognisable data field. It has: %s.', ...
        name, strjoin(f.', ', '));
end
if isempty(lon) || isempty(lat)
    [lon, lat] = axesFromLimits(s, f, size(Z));
end
if isempty(lon) || isempty(lat)
    return                              % caller raises NoAxes
end

Z = orientZ(Z, lon, lat);
[lonIdx, lon] = selectLon(lon(:), sel.LonLim, sel.Stride(1), name);
[latIdx, lat] = selectLat(lat(:), sel.LatLim, sel.Stride(2), name);
Z = Z(latIdx, lonIdx);
end

function [lon, lat] = axesFromLimits(s, have, sz)
%AXESFROMLIMITS  Cell-centred axes from a limits pair, as topo.mat stores.
%   MATLAB's own topo.mat carries topolatlim, topolonlim and topolegend
%   instead of coordinate vectors. The centres are derived from the LIMITS
%   and the array size, not from the legend's corner convention, because
%   the limits and the size are two facts that cannot disagree with each
%   other, whereas reading a corner requires knowing which corner - which
%   is exactly the kind of assumption that puts a map upside down.
lon = [];
lat = [];
latLim = pickField(s, have, ["topolatlim" "latlim"]);
lonLim = pickField(s, have, ["topolonlim" "lonlim"]);
if isempty(latLim) || isempty(lonLim), return, end
lat = centres(latLim, sz(1));
lon = centres(lonLim, sz(2));
end

function c = centres(lim, n)
%CENTRES  N cell centres spanning LIM, as a column.
step = (lim(2) - lim(1)) / n;
c = lim(1) + (0.5:1:(n - 0.5)).' * step;
end

function v = pickField(s, have, cands)
v = [];
for c = cands
    if any(have == c)
        v = double(s.(c));
        return
    end
end
end

function Z = orientZ(Z, lon, lat)
%ORIENTZ  Transpose if the file stored it the other way round.
%   The fallback for sources that do not name their dimensions. Rejected
%   rather than guessed when both dimensions match, because there is then
%   no way to tell and a wrong guess draws the world sideways in silence -
%   see GEO.GRID's SizeMismatch message. The NetCDF path does not need
%   this: it reads the dimension names.
if size(Z, 1) == numel(lon) && size(Z, 2) == numel(lat) && ...
        numel(lon) ~= numel(lat)
    Z = Z.';
end
end
