%% geoMap — getting started
% Cartographic visualisation in base MATLAB, for GRACE-like satellite
% gravimetry. No Mapping Toolbox, no Image Processing Toolbox, no
% Statistics Toolbox.
%
% Run this file section by section. Every section stands alone.
%
% geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

%% One map, one call
% |geo.map| draws the whole z-ladder: basemap, graticule, coastline,
% frame, colorbar. Everything is optional except the basemap.
lon = -180:2:180;
lat = -90:2:90;
Z = 40 * sind(3 * repmat(lon, numel(lat), 1)) .* ...
    cosd(2 * repmat(lat(:), 1, numel(lon)));
G = geo.grid(lon, lat, Z, Units = "cm");

H = geo.map(G, geo.crs("mollweide"), ...
    Title = "A field on an equal-area projection", ...
    Colorbar = struct(Label = "cm"));

%% The projection is a value, not six loose options
% A |geo.crs| validates its parameters together and can be handed to
% every overlay, so a track lands in the same coordinate system as the
% map underneath it. Its domain is queryable.
crs = geo.crs("lambertconformal", StandardParallel = 30, ...
    StandardParallel2 = 60, CenterLongitude = -100);
disp(crs.Domain)

%% Equal-area or the comparison is wrong
% A mass anomaly is read BY AREA. On a compromise projection the reader
% is comparing distorted areas and does not know it. See the projection
% guide in the documentation; the model here is a SPHERE, good to about
% 0.3%, which is a visualisation tool and not a survey tool.
geo.map(G, geo.crs("hammer"), Title = "Equal-area", Colorbar = false);

%% Composed, element by element
% Anything |geo.map| does in one call can be done element by element,
% and the two give the same map - identical CData, identical colour
% limits. That equivalence is asserted by the test suite, because it is
% the guarantee the whole architecture rests on.
[f, ax] = geo.basemap(G, geo.crs("robinson"));
geo.graticule(ax, [], StepLon = 60);
geo.coastline(ax, []);
geo.frame(ax, []);
geo.title(ax, "The same map, built by hand");

%% A track over topography
% |geo.trackmap| works out the extent from the data, fetches a
% background and hands the rest to |geo.map|. The margin is exactly the
% fraction of the data span you ask for.
tLon = -20:2:40;
T = geo.track(tLon, 30 + 20 * sind(3 * tLon), ...
    Obs = sind(tLon / 2), Units = "cm");
H = geo.trackmap(T, [], Pad = 0.1, ...
    Track = struct(Style = "bicolor"), ...
    Title = "Ascending pass 042");
disp(H.Region.LonLim)

%% Stations, stacked
% |geo.timeseries| stacks records with one offset each and reports the
% offsets it used - a stacked plot is read by subtracting them by eye.
t = 0:0.05:8;
mk = @(a) geo.track(zeros(size(t)), zeros(size(t)), Time = t, ...
    Obs = a * sin(t) + 0.1 * sin(9 * t));
S = geo.timeseries([mk(1) mk(2) mk(0.5)], ...
    Labels = ["ONSA" "MAR6" "VIS0"], YLabel = "EWH (cm)", ...
    ReferenceLines = 0);
disp(S.Offsets)

%% Export at the width a journal asked for
% |geo.export| delivers centimetres. |exportgraphics| crops to content
% and ignores the page, so a 17 cm request can arrive as 12.6 cm or
% 27.7 cm - both measured. This uses |print| with an explicit page.
file = fullfile(tempdir, "geomap_getting_started.pdf");
geo.export(H.Figure, file, Width = 17);
fprintf('wrote %s\n', file);

%% Where to read next
% * |doc geoMap| for the full reference, one page per function
% * the projection guide, for which projection and why
% * the GRACE workflow, for the whole thing end to end
% * |Contents.m| for the catalogue, grouped by layer
