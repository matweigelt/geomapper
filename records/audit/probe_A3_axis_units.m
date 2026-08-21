%PROBE_A3_AXIS_UNITS  Are projected metres accepted as degrees?
%
%   AUDIT PROBE - evidence only. Not part of the toolbox.
%
%   HYPOTHESIS (audit finding A-3). GEO.READGRID's axis picker accepts
%   the variable names "x" and "y" as longitude and latitude. GEO.GRID
%   validates an axis for being a real, finite, strictly monotone vector
%   of at least two points - and never for lying inside a plausible
%   angular range. A NetCDF on a projected grid, which is how a good deal
%   of gridded geophysics is distributed, therefore has its metres read
%   as degrees, and nothing on the path says so.
%
%   WHAT WOULD REFUTE IT. Any named error out of readGrid or geo.grid,
%   or a returned grid whose Lat has been recognised as not angular.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE A-3: a projected NetCDF, axes in metres\n');
f = fullfile(tempdir, 'audit_projected.nc');
if isfile(f), delete(f); end
x = -3e6:1e6:3e6;            % easting,  metres
y = -2e6:1e6:2e6;            % northing, metres
Z = single(rand(numel(x), numel(y)));
nccreate(f, 'x', 'Dimensions', {'x', numel(x)});  ncwrite(f, 'x', x);
nccreate(f, 'y', 'Dimensions', {'y', numel(y)});  ncwrite(f, 'y', y);
nccreate(f, 'z', 'Dimensions', {'x', numel(x), 'y', numel(y)});
ncwrite(f, 'z', Z);
fprintf('file written: x in [%g %g] m, y in [%g %g] m\n', ...
    min(x), max(x), min(y), max(y));
try
    G = geo.readGrid(f);
    fprintf('########## PROBE A-3 RESULT: readGrid RETURNED a grid.\n');
    fprintf('  Lat range : %g .. %g   (degrees, per the struct contract)\n', ...
        min(G.Lat(:)), max(G.Lat(:)));
    fprintf('  Lon range : %g .. %g\n', min(G.Lon(:)), max(G.Lon(:)));
    fprintf('  size(Z)   : %s\n', mat2str(size(G.Z)));
    try
        [px, py] = geo.project(G.Lon(1), G.Lat(1), geo.crs("mollweide"));
        fprintf('  geo.project on the first node: x = %g, y = %g\n', px, py);
    catch PE
        fprintf('  geo.project REFUSED it: %s (%s)\n', PE.message, PE.identifier);
    end
catch ME
    fprintf('########## PROBE A-3 RESULT: REFUSED - %s\n', ME.identifier);
    fprintf('  %s\n', ME.message);
end
