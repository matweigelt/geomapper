%PROBE_LOST_COLUMN  Does a flat surface drop the last row and column?
%
%   AUDIT PROBE - evidence only. Not part of the toolbox, not for merge.
%
%   THE CLAIM UNDER TEST. GEO.BASEMAP draws SURFACE with FaceColor flat
%   and CData the same size as XData. MATLAB then colours the face
%   between vertices (i,j) and (i+1,j+1) with CData(i,j), so the LAST
%   ROW AND COLUMN of the data would never be painted. If that is so,
%   the antimeridian wedge is not a seam defect at all: it is this
%   defect, in the one place where the missing column is the join.
%
%   DIFFERENTIAL, so no colour counting and no anti-aliasing argument.
%   Two grids differing ONLY in the last element, drawn at a FIXED CLim
%   so the change cannot move the colour scale. If the renders are
%   byte-identical, that element was never painted.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE: is the last column drawn?\n');
lon = [0 10 20];
lat = [0 10 20]';
base = [1 2 3; 4 5 6; 7 8 9];

files = strings(1, 3);
tag = ["unchanged", "last element 9->1", "FIRST element 1->9"];
Zs = {base, base, base};
Zs{2}(3, 3) = 1;
Zs{1}(1, 1) = 1;   Zs{2}(1, 1) = 1;   % keep (1,1) equal in 1 and 2
Zs{3}(1, 1) = 9;

for k = 1:3
    G = geo.grid(lon, lat, Zs{k});
    f = figure('Visible', 'off');
    ax = axes(f); %#ok<LAXES>
    geo.basemap(G, "equirectangular", Parent = ax, CLim = [1 9]);
    axis(ax, 'off');
    files(k) = fullfile(tempdir, sprintf('probe_lost_%d.png', k));
    exportgraphics(ax, files(k), 'Resolution', 100, 'BackgroundColor', 'white');
    close(f);
end

A = imread(files(1));
B = imread(files(2));
C = imread(files(3));
d12 = nnz(any(A ~= B, 3));
d13 = nnz(any(A ~= C, 3));
fprintf('pixels differing, change to the LAST  element : %d\n', d12);
fprintf('pixels differing, change to the FIRST element : %d\n', d13);
fprintf('\nVERDICT\n');
if d12 == 0 && d13 > 0
    fprintf('  the last row/column is NEVER PAINTED. The first is.\n');
elseif d12 > 0
    fprintf('  the last element does reach the render (%d px).\n', d12);
else
    fprintf('  inconclusive: neither change reached the render.\n');
end
fprintf('########## PROBE END\n');
