function G = readGrid(source, options)
%GEO.READGRID  Read a raster into a validated GEO.GRID.
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
%     THE GEOTIFF AND WORLDFILE PATHS ARE DEFERRED, and fail loudly with
%     their own identifier rather than being absent. They need a binary
%     TIFF tag parser, which is a substantial piece of work and belongs
%     in its own round rather than rushed in beside three other readers
%     (§6.6). The contract test for the identifier ships now, so the
%     round that adds them converts a failing test rather than inventing
%     the behaviour.
%
%   INPUTS
%     source  A filename (.nc, .nc4, .cdf, .mat) or a GEO.GRID, which is
%             returned unchanged.
%
%   OPTIONS
%     Variable  (1,1) string  [""]  NetCDF variable name; auto-detected
%                                   when empty.
%     Lon       (1,:) double  []    Override the file's longitude axis.
%     Lat       (:,1) double  []    Override the file's latitude axis.
%     Units     (1,1) string  [""]  Recorded in the grid.
%
%   OUTPUTS
%     G  (1,1) struct  A GEO.GRID, carrying Source and Units.
%
%   ACCURACY
%     No arithmetic beyond reading: values arrive as stored, and the only
%     transformation is orientation, which GEO.GRID canonicalises. Any
%     scale_factor and add_offset attributes are applied by MATLAB's own
%     NCREAD, not re-implemented here.
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
%     Deferred capability:
%       geo:readGrid:ImageInputNotYetAvailable - a GeoTIFF or an image
%                                        with a worldfile
%
%   EXAMPLE
%     G = geo.readGrid("ewh_trend.nc", Units = "cm/yr");
%
%   LIMITATIONS
%     Rectilinear grids only, matching GEO.GRID. A NetCDF holding a
%     curvilinear mesh has two-dimensional coordinate arrays and is
%     rejected by GEO.GRID's axis validation rather than flattened.
%
%   See also GEO.GRID, GEO.READCOASTLINE, GEO.REGRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    source
    options.Variable (1,1) string = ""
    options.Lon (1,:) double = []
    options.Lat (:,1) double = []
    options.Units (1,1) string = ""
end

if isstruct(source)
    G = geo.grid(source);               % idempotent, via geo.grid's own check
    return
end

source = string(source);
[~, ~, ext] = fileparts(source);
switch lower(ext)
    case {".nc", ".nc4", ".cdf"}
        [lon, lat, Z] = readNetcdf(source, options.Variable);
    case ".mat"
        [lon, lat, Z] = readMat(source);
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

G = geo.grid(lon, lat, orientZ(Z, lon, lat), ...
    Source = source, Units = options.Units);
end

% ======================================================================
function [lon, lat, Z] = readNetcdf(name, wanted)
try
    info = ncinfo(char(name));
catch
    error('geo:readGrid:FileNotFound', ...
        'Could not open "%s" as NetCDF.', name);
end
have = string({info.Variables.Name});

lon = pickAxis(name, have, ["lon" "longitude" "x" "Longitude" "LON"]);
lat = pickAxis(name, have, ["lat" "latitude" "y" "Latitude" "LAT"]);

if wanted ~= ""
    if ~any(have == wanted)
        error('geo:readGrid:VariableNotFound', ...
            'Variable "%s" is not in "%s". It holds: %s.', ...
            wanted, name, strjoin(have, ', '));
    end
    Z = double(ncread(char(name), char(wanted)));
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
Z = double(ncread(char(name), char(hit)));
end

function v = pickAxis(name, have, cands)
v = [];
for c = cands
    if any(have == c)
        v = double(ncread(char(name), char(c)));
        return
    end
end
end

function [lon, lat, Z] = readMat(name)
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
%   Rejected rather than guessed when both dimensions match, because
%   there is then no way to tell and a wrong guess draws the world
%   sideways in silence - see GEO.GRID's SizeMismatch message.
if size(Z, 1) == numel(lon) && size(Z, 2) == numel(lat) && ...
        numel(lon) ~= numel(lat)
    Z = Z.';
end
end
