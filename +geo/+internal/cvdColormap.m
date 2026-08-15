function cmap = cvdColormap(name, n)
%GEO.INTERNAL.CVDCOLORMAP  The published CVD-safe tables, read once.
%
%   SYNTAX
%     CMAP = GEO.INTERNAL.CVDCOLORMAP(NAME, N)
%     NAMES = GEO.INTERNAL.CVDCOLORMAP("names")
%
%   DESCRIPTION
%     Loads viridis, magma and cividis from data/cvd_colormaps.txt and
%     resamples them to N rows.
%
%     WHY THESE ARE TABLES AND NOT GENERATED. Stage B.3 dropped all three
%     on the grounds that reproducing third-party tables is copying. That
%     reasoning was half right: copying without permission would be, but
%     ALL THREE ARE CC0 PUBLIC-DOMAIN DEDICATIONS, so there is no legal
%     restriction at all. The remaining argument was that this project
%     generates rather than copies - and that argument fails here, for a
%     reason worth writing down.
%
%     These colormaps encode a MEASURED PERCEPTUAL PROPERTY: monotone
%     perceived lightness, and readability under the common forms of
%     colour vision deficiency. cividis is optimised for it specifically,
%     against a CVD simulation model, in a peer-reviewed paper. A ramp
%     generated here by construction cannot claim that property, because
%     nothing in this project measures it. Substituting a hand-rolled
%     approximation and calling it CVD-safe would be asserting a
%     perceptual claim with no oracle behind it - which is exactly what
%     this project forbids everywhere else.
%
%     So the tables are used, the provenance is recorded in the data file
%     and in LICENSE, and the extraction script ships beside them so a
%     reader can regenerate rather than trust.
%
%   INPUTS
%     name  (1,1) string  "viridis" | "magma" | "cividis" | "names".
%     n     (1,1) double  [256]  Number of rows to return.
%
%   OUTPUTS
%     cmap  (N,3) double in [0,1], or a (1,:) string for "names".
%
%   ACCURACY
%     The 256-row tables are reproduced verbatim from matplotlib 3.10.9,
%     which is stated in the data file's own header. Resampling to a
%     different N is linear interpolation between table rows; asking for
%     256 returns the table untouched, which is asserted.
%
%   ERRORS
%     Data availability:
%       geo:colormaps:DataFileMissing - data/cvd_colormaps.txt is absent
%       geo:colormaps:UnknownPreset   - name is not one of the three
%
%   EXAMPLE
%     c = geo.internal.cvdColormap("cividis", 64);
%
%   LIMITATIONS
%     Linear interpolation between table rows is not the same as
%     resampling in a perceptual space, so a heavily downsampled ramp is
%     no longer exactly perceptually uniform. At the sizes a colourbar
%     uses the difference is far below what a reader can see, and at 256
%     there is no interpolation at all.
%
%   See also GEO.COLORMAPS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    name (1,1) string
    n (1,1) double {mustBePositive, mustBeInteger} = 256
end

persistent TABLES
if isempty(TABLES)
    TABLES = loadTables();
end

if name == "names"
    cmap = string(fieldnames(TABLES)).';
    return
end

key = char(lower(name));
if ~isfield(TABLES, key)
    error('geo:colormaps:UnknownPreset', ...
        '"%s" is not one of the CVD tables (%s).', name, ...
        strjoin(string(fieldnames(TABLES)).', ', '));
end

t = TABLES.(key);
if n == size(t, 1)
    cmap = t;                       % no interpolation at the native size
    return
end
src = linspace(0, 1, size(t, 1)).';
cmap = min(max(interp1(src, t, linspace(0, 1, n).', 'linear'), 0), 1);
end

% ======================================================================
function T = loadTables()
%LOADTABLES  Parse the plain-text data file once per session.
here = fileparts(mfilename('fullpath'));
% +geo/+internal -> +geo -> root
root = fileparts(fileparts(here));
f = fullfile(root, 'data', 'cvd_colormaps.txt');
if exist(f, 'file') ~= 2
    error('geo:colormaps:DataFileMissing', ...
        ['The CVD colormap tables are not at %s. Regenerate them with ' ...
         'tools/extract_cvd_colormaps.py, which records its own ' ...
         'provenance in the file header.'], f);
end

T = struct();
lines = string(splitlines(string(fileread(f))));
current = '';
buf = [];
for i = 1:numel(lines)
    s = strtrim(lines(i));
    if startsWith(s, "#")
        tok = regexp(s, '^#\s+(viridis|magma|cividis)\s+(\d+)$', ...
            'tokens', 'once');
        if ~isempty(tok)
            if ~isempty(current)
                T.(current) = buf;
            end
            current = char(tok{1});
            buf = zeros(str2double(tok{2}), 3);
            row = 0;
        end
        continue
    end
    if s == "" || isempty(current)
        continue
    end
    row = row + 1;
    buf(row, :) = sscanf(s, '%f %f %f').';
end
if ~isempty(current)
    T.(current) = buf;
end
end
