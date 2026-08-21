%PROBE_GRATICULE_SEGMENT  Which projection, and which line, is 0.708?
%
%   AUDIT PROBE - evidence only. Not part of the toolbox, not for merge.
%
%   everyProjectionMeetsTheDensificationCriterion takes the MAX over
%   sixteen projections and reports one number, so a failure names
%   nothing. Since registration moved the extent to the poles the worst
%   segment reads 0.7080 against a bound of 0.005, and reasoning about
%   which projection that is has been wrong often enough today.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE: worst graticule segment, per projection\n');
G = geo.grid(-177.5:5:177.5, (-87.5:5:87.5)', ...
    sind(3 * repmat(-177.5:5:177.5, 36, 1)) .* ...
    cosd(2 * repmat((-87.5:5:87.5)', 1, 72)));
fprintf('grid registration : %s\n', G.Registration);
fprintf('LonRegion         : [%g %g]\n', G.LonRegion);
fprintf('LatRegion         : [%g %g]\n\n', G.LatRegion);
fprintf('%-22s %12s %12s %10s\n', 'projection', 'MaxSegment', 'latLim', 'ticks');
for name = geo.internal.projectionNames()
    f = figure('Visible', 'off');
    ax = axes(f); %#ok<LAXES>
    switch name
        case {"orthographic", "stereographic", "lambert", ...
              "azimuthalequidistant", "gnomonic"}
            c = geo.crs(name, CenterLatitude = 30);
        case "polarstereographic"
            c = geo.crs(name, CenterLatitude = 90);
        otherwise
            c = geo.crs(name);
    end
    try
        [~, ~, B] = geo.basemap(G, c, Parent = ax, Hillshade = "off");
        H = geo.graticule(ax);
        fprintf('%-22s %12.6f [%6.2f %6.2f] %10d\n', name, H.MaxSegment, ...
            B.LatLimit, numel(H.LatTicks));
        if H.MaxSegment > 0.05
            fprintf('    lat ticks: %s\n', mat2str(H.LatTicks));
            fprintf('    lon ticks: %s\n', mat2str(H.LonTicks));
        end
    catch ME
        fprintf('%-22s  ERROR %s\n', name, ME.identifier);
    end
    close(f);
end
fprintf('########## PROBE END\n');
