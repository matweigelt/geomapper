%PROBE_WEDGE  Is the antimeridian wedge fixed, and who now spills into it?
%
%   AUDIT PROBE - evidence only. Not part of the toolbox, not for merge.
%
%   PV-138 made the CLIP cyclic-aware: geo.basemap reports
%   LonClosesTurn and the coastline stops excluding the last cell. It did
%   NOT close the seam - that was tried and refuted. So the surface may
%   still stop one cell short of the world while the coastline now draws
%   through to 180, which would put the coastline outside the frame
%   again, at the seam, for the same reason as before.
%
%   Reasoning about this has been wrong twice today. Measure it.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE: the antimeridian wedge\n');
lon = -180:20:180;                      % both ends, the natural way
lat = (-90:15:90)';
G = geo.grid(lon, lat, sind(3 * repmat(lon, numel(lat), 1)) .* ...
    cosd(2 * repmat(lat, 1, numel(lon))));
f = figure('Visible', 'off');
ax = axes(f); %#ok<LAXES>
[~, ~, B] = geo.basemap(G, "equirectangular", Parent = ax);

fprintf('grid given        : %d columns, %g .. %g\n', numel(lon), min(lon), max(lon));
fprintf('B.LonLimit        : [%g %g]   span %g\n', B.LonLimit, diff(B.LonLimit));
fprintf('B.LonClosesTurn   : %d\n', B.LonClosesTurn);
X = B.Surface.XData;
fprintf('surface columns   : %d, unique %d\n', size(X, 2), numel(unique(X(1, :))));
fprintf('surface x range   : %g .. %g\n', min(X(:)), max(X(:)));

F = geo.frame(ax, StepLon = 60, StepLat = 30);
fx = [];
for k = 1:numel(F.Patches), fx = [fx, F.Patches(k).XData(:).']; end %#ok<AGROW>
fprintf('frame  x range    : %g .. %g\n', min(fx), max(fx));

H = geo.coastline(ax);
cx = H.Line.XData;
fprintf('coast  x range    : %g .. %g\n', min(cx), max(cx));
fprintf('coast ExtentKept  : %d\n', H.ExtentKept);

spill = nnz(cx > max(fx) + 1e-9 | cx < min(fx) - 1e-9);
fprintf('\nVERDICT\n');
fprintf('  coast vertices beyond the frame : %d\n', spill);
fprintf('  wedge width in x                : %g\n', max(cx) - max(fx));
close(f);
fprintf('########## PROBE END\n');
