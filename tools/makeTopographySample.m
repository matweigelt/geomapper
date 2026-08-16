function out = makeTopographySample(source, options)
%MAKETOPOGRAPHYSAMPLE  Build the shipped 10-arc-minute topography sample.
%
%   SYNTAX
%     out = MAKETOPOGRAPHYSAMPLE(SOURCE)
%     out = MAKETOPOGRAPHYSAMPLE(SOURCE, Name, Value)
%
%   DESCRIPTION
%     Reduces a global ETOPO 2022 relief grid to a file small enough to
%     live in the repository, so that doc examples and graphics tests can
%     draw a real basemap without the 478 MB original. Shipped rather
%     than run once and thrown away, because a data file whose
%     construction cannot be repeated is a number nobody can check.
%
%     IT AVERAGES, IT DOES NOT SUBSAMPLE, and for topography that is the
%     whole decision. Taking every tenth cell keeps whichever peaks and
%     trenches happen to land on the sampled indices and discards their
%     neighbours; the result has the same range as the original but a
%     rougher derivative, and hillshade is a derivative. The block mean
%     is the honest reduction and it is what NCEI themselves used to make
%     the 30 and 60 arc-second grids from the 15 arc-second one.
%
%     THE COST OF AVERAGING IS STATED RATHER THAN HIDDEN: a block
%     straddling a coast averages land and sea and can come out either
%     side of zero, so small islands disappear and narrow inlets fill in.
%     That is acceptable here only because the coastline is a separate
%     vector layer drawn from GSHHG or Natural Earth, and never inferred
%     from the sign of this field. If anything ever derives a land mask
%     from it, this file is the wrong input.
%
%     STORED AS int16, which is lossless for the ORIGINAL data - ETOPO
%     elevations are whole metres - but not for the block means, which
%     are rounded. Sub-metre precision in a 10-arc-minute average of an
%     18 km cell is not information, and halving the file is worth more
%     than keeping it.
%
%   INPUTS
%     source  (1,1) string  Path to a global ETOPO 2022 NetCDF, e.g.
%                           ETOPO_2022_v1_60s_N90W180_surface.nc.
%
%   OPTIONS
%     Factor  (1,1) double  [10]  Block size. 10 turns 1 arc-minute into
%                                 10 arc-minutes. Must divide both axes
%                                 exactly: a partial block at the edge
%                                 would be an average over fewer cells
%                                 and would not be comparable with its
%                                 neighbours.
%     Output  (1,1) string  [data/etopo_10min_surface.mat]
%
%   OUTPUTS
%     out  (1,1) struct  Fields:
%            File      (1,1) string   Where it was written.
%            Size      (1,2) double   [nLat nLon] of the result.
%            Bytes     (1,1) double   File size on disk.
%            Extremes  (1,2) double   [min max] metres, after averaging.
%
%   ACCURACY
%     No claim beyond the arithmetic: each output cell is the unweighted
%     mean of exactly Factor^2 input cells, rounded to the nearest metre.
%     The mean is UNWEIGHTED, which is correct here and would not be for
%     an area-weighted quantity: these cells are being averaged for the
%     look of the terrain, not to conserve anything. GEO.REGRID is the
%     function that conserves, and its mass closure is asserted at 1e-13.
%
%   ERRORS
%     geoMap:makeTopographySample:FactorDoesNotDivide - Factor leaves a
%                                 partial block on one of the axes
%
%   EXAMPLE
%     makeTopographySample("E:\DATAPOOL\Borders\" + ...
%                          "ETOPO_2022_v1_60s_N90W180_surface.nc");
%
%   LIMITATIONS
%     Global grids only. The block mean assumes the source covers the
%     whole sphere, which is what makes the output axes derivable from
%     the factor alone.
%
%   See also GEO.READGRID, GEO.REGRID, GEO.HILLSHADE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    source (1,1) string
    options.Factor (1,1) double {mustBeInteger, mustBePositive} = 10
    options.Output (1,1) string = ""
end

f = options.Factor;
out = struct();

lon = double(ncread(char(source), 'lon'));
lat = double(ncread(char(source), 'lat'));
nLon = numel(lon);
nLat = numel(lat);
if mod(nLon, f) ~= 0 || mod(nLat, f) ~= 0
    error('geoMap:makeTopographySample:FactorDoesNotDivide', ...
        ['Factor %d leaves a partial block: the source is %d by %d. ' ...
         'A partial block averages fewer cells than its neighbours and ' ...
         'is not comparable with them.'], f, nLon, nLat);
end

% Read in latitude bands so the full 1.74 GB field is never resident.
%
% THE BAND IS WIDE ON PURPOSE. The first version read one output row at a
% time - f source rows - and did not finish. ETOPO stores z deflated in
% 2700x1350 chunks, so a ten-row request still decompresses every chunk
% it touches, which is the full width of the file: about 29 Mcell of work
% to deliver 0.2 Mcell, repeated 1080 times. Reading roughly a chunk's
% height at once pays that cost eight times instead. The band must stay a
% whole number of output rows, or the reshape below would fold one output
% cell across two reads.
mLon = nLon / f;
mLat = nLat / f;
rows = max(1, floor(1200 / f)) * f;
Z = zeros(mLat, mLon);
for start = 1:rows:nLat
    cnt = min(rows, nLat - start + 1);
    band = double(ncread(char(source), 'z', ...
        [1 start], [nLon cnt]));            % (lon, lat) as ETOPO stores it
    b = reshape(mean(reshape(band, [f, mLon, cnt]), 1), [mLon, cnt]);
    b = reshape(mean(reshape(b, [mLon, f, cnt / f]), 2), [mLon, cnt / f]);
    o = (start - 1) / f;
    Z(o + (1:cnt / f), :) = b.';
end

% Named for what GEO.READGRID's .mat path looks for, so the sample is
% read by the shipped reader and not by a loader written for it alone.
topo = int16(round(Z));
lon = blockCentres(lon, f).';
lat = blockCentres(lat, f);

provenance = struct( ...
    'Source', "ETOPO 2022 v1, " + string(dir(source).name), ...
    'Producer', "NOAA National Centers for Environmental Information", ...
    'Citation', "NOAA NCEI (2022), ETOPO 2022 15 Arc-Second Global " + ...
                "Relief Model, doi:10.25921/fd45-gt74", ...
    'VerticalDatum', "EGM2008 geoid (EPSG:3855), metres, positive up", ...
    'Horizontal', "WGS 84 (EPSG:4326), cell-centred", ...
    'Reduction', sprintf("unweighted mean of %dx%d cells, rounded", f, f), ...
    'Built', string(datetime("now", Format = "dd-MMM-uuuu HH:mm")), ...
    'BuiltBy', "tools/makeTopographySample.m");

target = options.Output;
if target == ""
    target = fullfile(geoMapRoot(), "data", ...
        sprintf("etopo_%dmin_surface.mat", f));
end
if ~isfolder(fileparts(target))
    mkdir(fileparts(target));
end
save(target, "lon", "lat", "topo", "provenance", "-v7");

d = dir(target);
out.File = string(target);
out.Size = [mLat mLon];
out.Bytes = d.bytes;
out.Extremes = [min(Z(:)) max(Z(:))];
end

% ======================================================================
function c = blockCentres(axisVec, f)
%BLOCKCENTRES  Centre of each block of F cells, as a column.
%   Derived from the source centres rather than from limits, so a source
%   whose registration differs carries its own registration through.
c = mean(reshape(axisVec(:), f, []), 1).';
end
