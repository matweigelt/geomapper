%PROBE_FLAT_INDEXING  Which CData element colours which face?
%
%   AUDIT PROBE - evidence only. Not part of the toolbox, not for merge.
%
%   Registration needs the surface drawn on cell EDGES, and that means
%   knowing exactly which element of a truecolor CData paints which
%   face. The last probe refuted "the last row and column are dropped"
%   and left an anomaly behind - changing the FIRST element altered every
%   pixel, where it should have altered one face of four. Guessing
%   MATLAB's flat-shading convention is what produced that claim in the
%   first place, so this measures it on the smallest case that can
%   distinguish the answers.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE: flat shading indexing\n');

% ONE face, four candidate colours. Whichever appears is the convention.
X = [0 1; 0 1];
Y = [0 0; 1 1];
C = zeros(2, 2, 3);
C(1,1,:) = [1 0 0];   % red
C(1,2,:) = [0 1 0];   % green
C(2,1,:) = [0 0 1];   % blue
C(2,2,:) = [1 1 0];   % yellow
names = ["(1,1) red" "(1,2) green" "(2,1) blue" "(2,2) yellow"];
rgb = [1 0 0; 0 1 0; 0 0 1; 1 1 0];

f = figure('Visible', 'off', 'Color', 'w');
ax = axes(f, 'Position', [0 0 1 1]); %#ok<LAXES>
surface('Parent', ax, 'XData', X, 'YData', Y, 'ZData', zeros(2), ...
    'CData', C, 'FaceColor', 'flat', 'EdgeColor', 'none');
axis(ax, 'off'); xlim(ax, [0 1]); ylim(ax, [0 1]);
p = fullfile(tempdir, 'flatidx.png');
exportgraphics(ax, p, 'Resolution', 100, 'BackgroundColor', 'white');
I = double(imread(p)) / 255;
px = reshape(I, [], 3);
px = px(~all(px > 0.95, 2), :);
fprintf('non-white pixels: %d\n', size(px, 1));
for k = 1:4
    hit = nnz(all(abs(px - rgb(k, :)) < 0.1, 2));
    fprintf('  %-14s %7d px  %5.1f%%\n', names(k), hit, ...
        100 * hit / max(size(px, 1), 1));
end
close(f);

% Now the shape registration would produce: 2x2 cells drawn on 3x3 edges.
fprintf('\nedge-drawn 2x2 cells on 3x3 vertices\n');
[XE, YE] = meshgrid(0:2, 0:2);
CE = zeros(3, 3, 3);
CE(1,1,:) = [1 0 0]; CE(1,2,:) = [0 1 0];
CE(2,1,:) = [0 0 1]; CE(2,2,:) = [1 1 0];
f = figure('Visible', 'off', 'Color', 'w');
ax = axes(f, 'Position', [0 0 1 1]); %#ok<LAXES>
surface('Parent', ax, 'XData', XE, 'YData', YE, 'ZData', zeros(3), ...
    'CData', CE, 'FaceColor', 'flat', 'EdgeColor', 'none');
axis(ax, 'off'); xlim(ax, [0 2]); ylim(ax, [0 2]);
p2 = fullfile(tempdir, 'flatidx2.png');
exportgraphics(ax, p2, 'Resolution', 100, 'BackgroundColor', 'white');
I2 = double(imread(p2)) / 255;
px2 = reshape(I2, [], 3);
px2 = px2(~all(px2 > 0.95, 2), :);
fprintf('non-white pixels: %d  (expect four quarters)\n', size(px2, 1));
for k = 1:4
    hit = nnz(all(abs(px2 - rgb(k, :)) < 0.1, 2));
    fprintf('  %-14s %7d px  %5.1f%%\n', names(k), hit, ...
        100 * hit / max(size(px2, 1), 1));
end
close(f);
fprintf('########## PROBE END\n');
