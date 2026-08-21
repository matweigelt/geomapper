%PROBE_LOST_COLUMN  Does a flat surface drop the last row and column?
%
%   AUDIT PROBE - evidence only. Not part of the toolbox, not for merge.
%
%   THE CLAIM UNDER TEST. GEO.BASEMAP draws SURFACE with FaceColor flat
%   and CData the same size as XData. MATLAB then colours the face
%   between vertices (i,j) and (i+1,j+1) with CData(i,j), so the LAST
%   ROW AND COLUMN of the data are never painted, and every cell sits
%   half a step from where its value belongs. If that is true, the
%   antimeridian wedge is not a seam defect at all - it is this defect,
%   showing up in the one place where the missing column happens to be
%   the join.
%
%   MATLAB's documented behaviour should not be asserted from memory,
%   which is why this renders and counts pixels instead.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE: is the last column drawn?\n');

% Two cells wide, two tall, four DISTINCT values. If all four are
% painted the export holds four colours; if the last row and column are
% dropped, one face is painted and it holds one.
lon = [0 10 20];
lat = [0 10 20]';
Z = [1 2 3; 4 5 6; 7 8 9];
G = geo.grid(lon, lat, Z);
f = figure('Visible', 'off');
ax = axes(f); %#ok<LAXES>
[~, ~, B] = geo.basemap(G, "equirectangular", Parent = ax);

fprintf('nodes            : %d x %d\n', numel(lat), numel(lon));
fprintf('size(Surface.CData): %s\n', mat2str(size(B.Surface.CData)));
fprintf('size(Surface.XData): %s\n', mat2str(size(B.Surface.XData)));

C = B.Surface.CData;
u = unique(reshape(C, [], size(C, 3)), 'rows');
fprintf('distinct vertex colours in CData: %d (of %d values)\n', ...
    size(u, 1), numel(Z));

axis(ax, 'off');
p = fullfile(tempdir, 'probe_lost_column.png');
exportgraphics(ax, p, 'Resolution', 120, 'BackgroundColor', 'white');
I = imread(p);
px = double(reshape(I, [], size(I, 3)));
px = px(~all(px > 250, 2), :);          % drop the white background
uq = unique(round(px / 8), 'rows');
fprintf('\ndistinct non-white colours RENDERED: %d\n', size(uq, 1));
fprintf('  4 => every cell painted;  1 => three of four dropped\n');

fprintf('\nlatitude region check\n');
fprintf('  B.LatLimit  : [%g %g]\n', B.LatLimit);
fprintf('  node range  : [%g %g]\n', min(lat), max(lat));
close(f);
fprintf('########## PROBE END\n');
