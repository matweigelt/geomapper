function out = makeCoastlineSample(source, options)
%MAKECOASTLINESAMPLE  Build the shipped low-resolution coastline.
%
%   SYNTAX
%     out = MAKECOASTLINESAMPLE(SOURCE)
%     out = MAKECOASTLINESAMPLE(SOURCE, Name, Value)
%
%   DESCRIPTION
%     Converts a Natural Earth coastline shapefile into the small .mat
%     that GEO.READCOASTLINE's "builtin" source reads.
%
%     THIS EXISTS BECAUSE THE BUILTIN SOURCE WAS BROKEN. Stage C's
%     GEO.READCOASTLINE loaded `coastlines.mat`, which used to ship with
%     base MATLAB and does not ship with R2026a - it went to the Mapping
%     Toolbox, which this project does not use and whose absence is the
%     point of defect F1. Nothing caught it because no test had ever
%     asked for the builtin coastline; Stage D's first call to
%     GEO.COASTLINE did, and it failed immediately.
%
%     NATURAL EARTH RATHER THAN GSHHG, and the reason is licensing, not
%     quality. GSHHG is the better coastline and is what a serious figure
%     should use, but it is not redistributable; Natural Earth is
%     explicitly public domain, so it can live in the repository. The
%     shipped file is a fallback and a doc-example fixture. Anyone who
%     cares about the shoreline should pass a GSHHG path.
%
%     NOTHING IS SIMPLIFIED. The 110m Natural Earth coastline is already
%     a generalisation made by cartographers; decimating it further here
%     would move a shoreline for no reason other than file size, and the
%     file is 0.1 MB as it stands.
%
%   INPUTS
%     source  (1,1) string  Path to ne_110m_coastline.shp or similar.
%
%   OPTIONS
%     Output  (1,1) string  [data/coast_110m.mat]
%
%   OUTPUTS
%     out  (1,1) struct  Fields:
%            File      (1,1) string
%            NumPoints (1,1) double
%            NumParts  (1,1) double
%            Bytes     (1,1) double
%
%   ACCURACY
%     No arithmetic at all: the coordinates are the shapefile's IEEE
%     doubles, which Stage C asserted round-trip exactly, written
%     unchanged.
%
%   ERRORS
%     geoMap:makeCoastlineSample:NoGeometry - the shapefile yielded no
%                                             points
%
%   EXAMPLE
%     makeCoastlineSample("E:\DATAPOOL\Borders\ne_110m_coastline.shp");
%
%   LIMITATIONS
%     Polylines only, which is what a coastline shapefile holds.
%
%   See also GEO.READCOASTLINE, GEO.COASTLINE, MAKETOPOGRAPHYSAMPLE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    source (1,1) string
    options.Output (1,1) string = ""
end

[xy, meta] = geo.readCoastline(source);
if isempty(xy)
    error('geoMap:makeCoastlineSample:NoGeometry', ...
        '"%s" yielded no coastline points.', source);
end

coastlon = xy(:, 1);                     %#ok<NASGU> named for the reader
coastlat = xy(:, 2);                     %#ok<NASGU>
provenance = struct( ...
    'Source', "Natural Earth 110m coastline, " + string(dir(source).name), ...
    'Producer', "Natural Earth (naturalearthdata.com)", ...
    'Licence', "Public domain; no restrictions on use or redistribution", ...
    'Reduction', "none - written exactly as read", ...
    'Built', string(datetime("now", Format = "dd-MMM-uuuu HH:mm")), ...
    'BuiltBy', "tools/makeCoastlineSample.m");                %#ok<NASGU>

target = options.Output;
if target == ""
    target = fullfile(geoMapRoot(), "data", "coast_110m.mat");
end
if ~isfolder(fileparts(target))
    mkdir(fileparts(target));
end
save(target, "coastlon", "coastlat", "provenance", "-v7");

d = dir(target);
out = struct('File', string(target), 'NumPoints', size(xy, 1), ...
    'NumParts', meta.NumParts, 'Bytes', d.bytes);
end
