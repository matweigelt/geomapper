function [xy, meta] = readCoastline(source, options)
%GEO.READCOASTLINE  One coastline reader, replacing v1's four.
%
%   SYNTAX
%     [XY, META] = GEO.READCOASTLINE(SOURCE)
%     [XY, META] = GEO.READCOASTLINE(SOURCE, Name, Value)
%
%   DESCRIPTION
%     Reads a coastline, river network or region outline from a GSHHG
%     binary, an ESRI shapefile, a text file or MATLAB's built-in data,
%     and returns one NaN-separated Nx2 array. v1 had four functions with
%     four different jump-splitting rules; this has one, and it delegates
%     the split to GEO.SPLITANTIMERIDIAN so the toolbox keeps a single
%     authority on where a path breaks.
%
%     THREE CHANGES FROM v1, each with a reason:
%
%     (a) CELL-ACCUMULATE, VERTCAT ONCE. v1 grew its output array inside
%         the record loop, which is O(N^2). Full-resolution GSHHG is 96 MB
%         and 180 000 polygons, so that is not a micro-optimisation
%         (defect F13, and the audit now forbids the pattern inside +geo).
%
%     (b) THE SPLIT IS GEO.SPLITANTIMERIDIAN'S. v1's readers each had
%         their own jump code.
%
%     (c) GSHHG LEVEL 5 AND 6 POLYGONS SPANNING NEARLY THE WHOLE CIRCLE
%         ARE CLOSED VIA THE SOUTH POLE before splitting. Antarctica's
%         ice front is stored as a line that runs around the continent
%         without ever closing; drawn as given it leaves the pole open and
%         the fill leaks (defect F17).
%
%     PRESERVED FROM v1 DELIBERATELY: there is no ISFILE pre-check before
%     FOPEN, because FOPEN searches the MATLAB path and ISFILE does not,
%     so a pre-check would reject files that are perfectly reachable. v1
%     carried that comment and it was right.
%
%   INPUTS
%     source  "builtin", a filename (.b, .shp, .txt, .dat, .mat), or a
%             validated Nx2 array which is returned unchanged.
%
%   OPTIONS
%     Format  (1,1) string  ["auto"]  Override the extension sniff.
%     Levels  (1,:) double  [1:6]     GSHHG levels: 1 land, 2 lake,
%                                     3 island-in-lake, 4 pond, 5 and 6
%                                     Antarctic ice front and grounding
%                                     line.
%     Split   (1,1) string  ["interpolate"]  Passed to
%                                     GEO.SPLITANTIMERIDIAN.
%
%   OUTPUTS
%     xy    (N,2) double  [lon lat], NaN-separated between parts.
%     meta  (1,1) struct  Fields: Source, Format, NumParts, NumPoints,
%                         Levels, and PROVENANCE - "verified" once the
%                         reader has been checked against a real file of
%                         that format, "unverified" otherwise. The field
%                         travels with the data so a figure can say where
%                         its coastline came from and how much to trust it.
%
%   ACCURACY
%     GSHHG stores microdegrees as int32, so coordinates are exact to
%     1e-6 degrees by construction - that is the format's own floor, not
%     an approximation introduced here. Shapefile coordinates are IEEE
%     doubles and round-trip EXACTLY; the reader is checked with ISEQUAL
%     rather than a tolerance, because anything looser would hide an
%     endianness error.
%
%     ORACLES O5 AND O6 ARE FILLED. This reader is checked against a real
%     Natural Earth shapefile and real GSHHG binaries at all five
%     resolutions. Until that check existed the GSHHG path had never seen
%     a real file in four years, and shipped with a CONFIDENCE NOTE
%     saying so (handover debt V3).
%
%   ERRORS
%     Source:
%       geo:readCoastline:FileNotFound     - fopen could not open it
%       geo:readCoastline:UnknownFormat    - extension not recognised and
%                                            no Format given
%       geo:readCoastline:NoPolygons       - no record could be read
%       geo:readCoastline:NoMatchingLevels - records read, none matched
%       geo:readCoastline:UnsupportedShape - shapefile geometry that is
%                                            not a polyline or polygon
%
%   WARNINGS
%       geo:readCoastline:TruncatedFile    - the file ends mid-record
%
%   EXAMPLE
%     [xy, m] = geo.readCoastline("gshhs_i.b", Levels = 1);
%     m.Provenance      % "verified"
%
%   LIMITATIONS
%     Reads geometry only. Shapefile attributes in the .dbf are not
%     parsed, so a caller who needs to select by name must do that
%     selection themselves and pass the resulting Nx2 array.
%
%   See also GEO.SPLITANTIMERIDIAN, GEO.READGRID, GEO.REGION.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    source
    options.Format (1,1) string = "auto"
    options.Levels (1,:) double {mustBeInteger} = 1:6
    options.Split (1,1) string ...
        {mustBeMember(options.Split, ["interpolate" "break"])} = "interpolate"
end

if isnumeric(source)
    xy = double(source);
    meta = makeMeta("<array>", "array", xy, options.Levels, "verified");
    return
end

source = string(source);
fmt = options.Format;
if fmt == "auto"
    fmt = sniffFormat(source);
end

switch fmt
    case "builtin"
        xy = builtinCoast();
    case "gshhg"
        xy = readGshhg(source, options.Levels, options.Split);
    case "shapefile"
        xy = readShapefile(source, options.Split);
    case "text"
        xy = readText(source, options.Split);
    otherwise
        error('geo:readCoastline:UnknownFormat', ...
            ['Cannot tell what format "%s" is. Recognised extensions ' ...
             'are .b (GSHHG), .shp, .txt and .dat; pass Format = to ' ...
             'override the sniff.'], source);
end

meta = makeMeta(source, fmt, xy, options.Levels, provenanceOf(fmt));
end

% ======================================================================
function fmt = sniffFormat(source)
if lower(source) == "builtin"
    fmt = "builtin";
    return
end
[~, ~, ext] = fileparts(source);
switch lower(ext)
    case ".b",              fmt = "gshhg";
    case ".shp",            fmt = "shapefile";
    case {".txt", ".dat"},  fmt = "text";
    case ".mat",            fmt = "builtin";
    otherwise,              fmt = "unknown";
end
end

function p = provenanceOf(fmt)
%PROVENANCEOF  Has this PATH been checked against a real file of its kind?
%   Per-format, because "the reader is verified" is not one claim: the
%   GSHHG path and the shapefile path share no code and were verified by
%   different files. OB-3 closed for both when oracles O5 and O6 arrived.
switch fmt
    case {"gshhg", "shapefile", "builtin", "array"}
        p = "verified";
    otherwise
        p = "unverified";       % text: no canonical real file exists
end
end

function meta = makeMeta(source, fmt, xy, levels, provenance)
nParts = 0;
if ~isempty(xy)
    nParts = sum(isnan(xy(:, 1))) + double(~isnan(xy(end, 1)));
end
meta = struct( ...
    'Source', string(source), ...
    'Format', string(fmt), ...
    'NumParts', nParts, ...
    'NumPoints', sum(~isnan(xy(:, 1))), ...
    'Levels', levels, ...
    'Provenance', string(provenance));
end

function fid = openOrFail(name, machinefmt)
%OPENORFAIL  No ISFILE pre-check, deliberately: FOPEN searches the MATLAB
%   path and ISFILE does not, so a pre-check rejects files that are
%   perfectly reachable. v1 carried this comment and it was right.
fid = fopen(name, 'r', machinefmt);
if fid == -1
    error('geo:readCoastline:FileNotFound', ...
        ['Could not open "%s". FOPEN searched the current folder and ' ...
         'the MATLAB path.'], name);
end
end

% ======================================================================
function xy = readGshhg(name, levels, splitMode)
%READGSHHG  Big-endian records: 11 int32 header, then 2n int32 microdegrees.
fid = openOrFail(name, 'ieee-be');
c = onCleanup(@() fclose(fid));

parts = cell(1, 4096);
np = 0;
nRead = 0;
while true
    hdr = fread(fid, 11, 'int32');
    if numel(hdr) < 11
        break                       % clean end of file
    end
    n = hdr(2);
    level = double(bitand(uint32(hdr(3)), uint32(255)));   % low 8 bits
    pts = fread(fid, 2 * n, 'int32');
    if numel(pts) < 2 * n
        warning('geo:readCoastline:TruncatedFile', ...
            '"%s" ends mid-record after %d polygon(s); stopping there.', ...
            name, nRead);
        break
    end
    nRead = nRead + 1;
    if ~ismember(level, levels)
        continue
    end

    lon = double(pts(1:2:end)) / 1e6;      % microdegrees
    lat = double(pts(2:2:end)) / 1e6;
    lon(lon > 180) = lon(lon > 180) - 360; % GSHHG stores 0-360 east

    % F17: an ice-front polygon that runs nearly the whole way round is
    % Antarctica, stored without ever closing. Close it via the pole
    % BEFORE splitting, or the fill leaks out of the bottom of the map.
    % Assigned into NEW variables rather than appended in place: growing
    % lon and lat inside the record loop is the F13 pattern, and the
    % project's own audit rejected it here on the first run even though
    % it is only two vertices. A ban with an exception for small cases is
    % not a ban.
    if any(level == [5 6]) && (max(lon) - min(lon)) >= 359
        lonC = [lon; lon(end); lon(1)];
        latC = [lat; -90; -90];
    else
        lonC = lon;
        latC = lat;
    end

    [lon, lat] = geo.splitAntimeridian(lonC, latC, Mode = splitMode);
    np = np + 1;
    parts{np} = [lon(:), lat(:); NaN NaN];
end

if nRead == 0
    error('geo:readCoastline:NoPolygons', ...
        ['No record could be read from "%s". It may not be a GSHHG ' ...
         'binary - check it is one of the .b files rather than a .zip ' ...
         'or a shapefile.'], name);
end
if np == 0
    error('geo:readCoastline:NoMatchingLevels', ...
        ['%d polygon(s) were read from "%s" but none matched Levels ' ...
         '[%s]. GSHHG levels: 1 land, 2 lake, 3 island-in-lake, 4 pond, ' ...
         '5 and 6 Antarctic ice front and grounding line.'], ...
        nRead, name, num2str(levels));
end
xy = vertcat(parts{1:np});          % F13: one concatenation, not N
end

% ======================================================================
function xy = readShapefile(name, splitMode)
%READSHAPEFILE  Traverse records by DECLARED CONTENT LENGTH.
%   Ported from v1 unchanged in this respect, and the reason is worth
%   keeping: walking by the declared length steps over Z and M payloads
%   the reader does not understand, so a PolygonZ file reads correctly
%   instead of desynchronising. Parsing each shape type instead would be
%   simpler and would break on the first file with elevation in it.
fid = openOrFail(name, 'ieee-be');
c = onCleanup(@() fclose(fid));

fseek(fid, 24, 'bof');
fileLenWords = fread(fid, 1, 'int32');       % in 16-bit words, header included
fseek(fid, 100, 'bof');                      % past the 100-byte header

parts = cell(1, 4096);
np = 0;
while ftell(fid) < fileLenWords * 2
    rec = fread(fid, 2, 'int32');            % number, content length (words)
    if numel(rec) < 2
        break
    end
    contentBytes = rec(2) * 2;
    here = ftell(fid);
    shapeType = fread(fid, 1, 'int32=>double', 0, 'ieee-le');
    if isempty(shapeType)
        break
    end
    switch shapeType
        case 0                               % null shape: nothing to read
        case {3, 5, 13, 15, 23, 25}          % PolyLine/Polygon, incl. Z and M
            fseek(fid, 32, 'cof');           % bounding box
            nP = fread(fid, 1, 'int32=>double', 0, 'ieee-le');
            nPt = fread(fid, 1, 'int32=>double', 0, 'ieee-le');
            partIdx = fread(fid, nP, 'int32=>double', 0, 'ieee-le');
            xyRaw = fread(fid, [2 nPt], 'double', 0, 'ieee-le').';
            starts = partIdx + 1;
            ends = [starts(2:end) - 1; nPt];
            for k = 1:nP
                seg = xyRaw(starts(k):ends(k), :);
                [lo, la] = geo.splitAntimeridian(seg(:, 1), seg(:, 2), ...
                    Mode = splitMode);
                np = np + 1;
                parts{np} = [lo(:), la(:); NaN NaN];
            end
        otherwise
            error('geo:readCoastline:UnsupportedShape', ...
                ['Shape type %d in "%s" is not a polyline or polygon. ' ...
                 'Points and multipoints have no outline to draw.'], ...
                shapeType, name);
    end
    fseek(fid, here + contentBytes, 'bof');  % declared length, always
end

if np == 0
    error('geo:readCoastline:NoPolygons', ...
        'No polyline or polygon record was found in "%s".', name);
end
xy = vertcat(parts{1:np});
end

% ======================================================================
function xy = readText(name, splitMode)
%READTEXT  Two columns, blank lines or NaN rows separating parts.
fid = openOrFail(name, 'native');
c = onCleanup(@() fclose(fid));
raw = fread(fid, '*char').';
blocks = regexp(string(raw), '\r?\n\s*\r?\n', 'split');
parts = cell(1, numel(blocks));
np = 0;
for i = 1:numel(blocks)
    v = sscanf(char(blocks(i)), '%f');
    if numel(v) < 4
        continue
    end
    m = reshape(v(1:2*floor(numel(v)/2)), 2, []).';
    [lo, la] = geo.splitAntimeridian(m(:, 1), m(:, 2), Mode = splitMode);
    np = np + 1;
    parts{np} = [lo(:), la(:); NaN NaN];
end
if np == 0
    error('geo:readCoastline:NoPolygons', ...
        'No two-column numeric block was found in "%s".', name);
end
xy = vertcat(parts{1:np});
end

function xy = builtinCoast()
%BUILTINCOAST  MATLAB's own coastline, already NaN-separated.
s = load('coastlines.mat');
xy = [s.coastlon(:), s.coastlat(:)];
end
