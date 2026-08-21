%PROBE_CLIP_MEMBERSHIP  Which predicate is excluding a global coastline?
%
%   AUDIT PROBE - evidence only. Not part of the toolbox, not for merge.
%
%   PV-137's confirming run says 222 of 5128 coastline vertices fall
%   outside a POLE-TO-POLE, FULL-TURN extent on equirectangular, where
%   nothing should. Three predicates could be responsible - longitude,
%   latitude, or the domain's finiteness - and reasoning between them
%   has already been wrong twice this session. Count them separately.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE: clip membership breakdown\n');
root = geoMapRoot();
lon = -180:20:180;
lat = (-90:15:90)';
G = geo.grid(lon, lat, sind(3 * repmat(lon, numel(lat), 1)) .* ...
    cosd(2 * repmat(lat, 1, numel(lon))));
f = figure('Visible', 'off');
ax = axes(f); %#ok<LAXES>
geo.basemap(G, "equirectangular", Parent = ax);

[crs, lonLim, latLim] = geo.internal.elementExtent(ax, []);
fprintf('crs            : %s, CenterLongitude %g\n', crs.Name, crs.CenterLongitude);
fprintf('lonLim         : [%g %g]   span %g\n', lonLim, diff(lonLim));
fprintf('latLim         : [%g %g]   span %g\n', latLim, diff(latLim));

xy = geo.readCoastline("builtin");
L = xy(:, 1).';  A = xy(:, 2).';
real = ~isnan(L) & ~isnan(A);
fprintf('vertices       : %d total, %d non-NaN\n', numel(L), nnz(real));

B = geo.internal.mapBoundary(crs, [lonLim(1) lonLim(2)], [latLim(1) latLim(2)]);
fprintf('B.LonLim       : [%g %g]\nB.LatLim       : [%g %g]\nB.Complete     : %d\n', ...
    B.LonLim, B.LatLim, B.Complete);

lonW = geo.wrapLongitude(L, mean(B.LonLim));
inLon = lonW >= B.LonLim(1) - 1e-9 & lonW <= B.LonLim(2) + 1e-9;
if diff(B.LonLim) >= 360 - 1e-9, inLon = true(size(L)); end
inLat = A >= B.LatLim(1) - 1e-9 & A <= B.LatLim(2) + 1e-9;
[x, y] = geo.project(L, A, crs);
fin = isfinite(x) & isfinite(y);

fprintf('\n  predicate        fails among the %d real vertices\n', nnz(real));
fprintf('  inLon            %d\n', nnz(real & ~inLon));
fprintf('  inLat            %d\n', nnz(real & ~inLat));
fprintf('  isfinite(proj)   %d\n', nnz(real & ~fin));
fprintf('  any of the three %d\n', nnz(real & ~(inLon & inLat & fin)));

bad = find(real & ~(inLon & inLat & fin), 8);
for k = bad
    fprintf('   lon %10.4f  lat %9.4f  ->  x %g  y %g\n', L(k), A(k), x(k), y(k));
end
fprintf('\n  lat extremes of the data: %g .. %g\n', min(A(real)), max(A(real)));
fprintf('  lon extremes of the data: %g .. %g\n', min(L(real)), max(L(real)));
fprintf('########## PROBE END\n');
close(f);
