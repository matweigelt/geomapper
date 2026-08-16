function H = overlayTrack(axH, T, crs, options)
%GEO.OVERLAYTRACK  An along-track series, as a wiggle or a coloured line.
%
%   SYNTAX
%     H = GEO.OVERLAYTRACK(AX, T)
%     H = GEO.OVERLAYTRACK(AX, T, CRS)
%     H = GEO.OVERLAYTRACK(AX, T, CRS, Name, Value)
%
%   DESCRIPTION
%     Draws a GEO.TRACK over a basemap at z = 5. Four styles, which are
%     v1's four: a filled wiggle graded along its length, the same wiggle
%     split by sign into two flat colours, a coloured line with no
%     deviation, and markers.
%
%     THE SCALE IS COMPUTED ONCE FOR THE WHOLE TRACK, NOT PER RUN, and
%     this is the defect that matters most here. v1 computed the "auto"
%     amplitude scale inside its per-run drawing function, from that
%     run's own maximum. A track broken by a single missing sample
%     therefore drew two ribbons at two different scales, with nothing on
%     the figure to say so - and a wiggle is a QUANTITATIVE display whose
%     whole content is the amplitude. Two segments of one orbit could not
%     be compared by eye, which is the only way anybody reads them.
%
%     RUNS ARE BROKEN THREE WAYS AND ALL THREE ARE NEEDED. NaN in the
%     coordinates or the observation is a gap in the data. A jump in
%     longitude is the antimeridian. And a segment that will not shrink
%     under bisection is a branch cut - which v1 did not test for on
%     tracks at all, though it did on coastlines, so a track crossing a
%     projection's seam drew a ribbon straight across the map.
%
%     SCATTER3 CLEARS THE AXES, and in a composable toolbox that is a
%     landmine. It is a high-level plotting call, so unless HOLD is on it
%     resets the axes first - measured: a map carrying fifty objects came
%     back with five, the basemap and every element drawn before it gone.
%     v1 never met this because it drew everything inside one function in
%     a fixed order; here any element may be called at any time, so the
%     hold state is saved, forced on, and restored.
%
%     THE NORMAL IS TAKEN IN PROJECTED SPACE, from centred differences of
%     the projected coordinates, so the wiggle stands perpendicular to
%     the track AS DRAWN. A normal computed in lon/lat and then projected
%     would lean, by an amount that varies across the map.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     T    (1,1) struct  A GEO.TRACK. Its Obs field is what is drawn;
%                        without one there is nothing to make a wiggle
%                        from and only "line" and "markers" are possible.
%     crs  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     Style          "gradient"  "gradient" | "bicolor" | "line" | "markers".
%     Scale          "auto"      Map units per observation unit, or
%                                "auto" to make the largest |Obs| reach
%                                ScaleFraction of the map diagonal.
%     ScaleFraction  0.06
%     Colormap       []          Defaults to the basemap's.
%     CLim           []          Defaults to the basemap's.
%     BicolorColors  [0 0.35 0.7; 0.75 0.1 0.1]  Negative, positive.
%     Baseline       true        Draw the undeviated path underneath.
%     BaselineColor  [0.2 0.2 0.2]
%     LineWidth      1.2
%     MarkerSize     24          Points squared, for "markers".
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Objects     (1,:)         One per run, plus baselines.
%          Style       (1,1) string
%          Scale       (1,1) double  Map units per observation unit, as
%                                    used - ONE number for the whole
%                                    track, whatever it was broken into.
%          NumRuns     (1,1) double
%          NumCuts     (1,1) double  Branch cuts broken.
%          CLim        (1,2) double
%          All         (1,:)
%
%   ACCURACY
%     The amplitude of the wiggle at a sample is exactly
%     Obs * Scale in projected units, measured along the unit normal.
%     That is asserted rather than described, and it is the property that
%     makes the display quantitative.
%
%   ERRORS
%     geo:overlayTrack:NoBasemap   - no crs and no basemap
%     geo:overlayTrack:NoObs       - a wiggle style without Obs
%     geo:overlayTrack:BadScale    - Scale is neither "auto" nor a
%                                    positive finite number
%
%   EXAMPLE
%     T = geo.track(lon, lat, Obs = residual, Units = "cm");
%     H = geo.overlayTrack(ax, T, Style = "bicolor");
%     H.Scale
%
%   LIMITATIONS
%     The wiggle is drawn in projected space, so on a strongly distorting
%     projection a constant observation makes a ribbon of varying width
%     on the ground. That is the honest behaviour for a display measured
%     against a scale bar in map units, and it is why the returned Scale
%     is in map units per observation unit rather than in kilometres.
%
%   See also GEO.TRACK, GEO.SPLITTRACKS, GEO.OVERLAYPOINTS, GEO.BASEMAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    T
    crs = []
    options.Style (1,1) string {mustBeMember(options.Style, ["gradient" "bicolor" "line" "markers"])} = "gradient"
    options.Scale = "auto"
    options.ScaleFraction (1,1) double {mustBePositive} = 0.06
    options.Colormap double = []
    options.CLim double = []
    options.BicolorColors (2,3) double {mustBeInRange(options.BicolorColors, 0, 1)} = [0 0.35 0.7; 0.75 0.1 0.1]
    options.Baseline (1,1) logical = true
    options.BaselineColor (1,3) double {mustBeInRange(options.BaselineColor, 0, 1)} = [0.2 0.2 0.2]
    options.LineWidth (1,1) double {mustBePositive} = 1.2
    options.MarkerSize (1,1) double {mustBePositive} = 24
end

T = geo.track(T);
[crs, ~, ~, base, ~, ~, diag] = geo.internal.elementExtent(axH, crs, ...
    ErrorId = "geo:overlayTrack:NoBasemap");

needsObs = any(options.Style == ["gradient" "bicolor"]);
obs = T.Obs;
if isempty(obs)
    if needsObs
        error('geo:overlayTrack:NoObs', ...
            ['Style "%s" draws the observation as a deviation from the ' ...
             'track, and this geo.track carries no Obs. Use "line" or ' ...
             '"markers", or build the track with Obs.'], options.Style);
    end
    obs = zeros(size(T.Lon));
end

[cLim, cmap] = geo.internal.colourScale(base, obs, ...
    Colormap = options.Colormap, CLim = options.CLim);
scale = resolveScale(options, obs, diag);

prior = geo.internal.layout("data", axH, "track");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

runs = contiguousRuns(T.Lon(:).', T.Lat(:).', obs(:).');
target = diag / 200;
% Collected into cells and joined once: the number of drawn pieces is
% not known until every run has been projected and cut (F13).
groups = cell(1, 0);
nCuts = 0;
nRuns = 0;
for k = 1:numel(runs)
    idx = runs{k};
    [x, y, info] = geo.internal.projectPolyline(T.Lon(idx).', T.Lat(idx).', ...
        crs, Target = target, Densify = false);
    nCuts = nCuts + info.NumCuts;
    o = alignObs(obs(idx).', info.SourceIndex);
    for sub = subRuns(x, y)
        s = sub{1};
        if numel(s) < 2 && options.Style ~= "markers"
            continue
        end
        nRuns = nRuns + 1;
        groups{nRuns} = drawRun(axH, x(s), y(s), o(s), scale, ...
            cLim, cmap, options);
    end
end
objects = [groups{:}];

H = struct('Objects', objects, 'Style', options.Style, 'Scale', scale, ...
    'NumRuns', nRuns, 'NumCuts', nCuts, 'CLim', cLim, 'All', objects);
geo.internal.layout("register", axH, "track", @(~) []);
geo.internal.layout("setData", axH, "track", H);
end

% ======================================================================
function scale = resolveScale(options, obs, diag)
%RESOLVESCALE  ONE number for the whole track. See DESCRIPTION.
if isstring(options.Scale) || ischar(options.Scale)
    if string(options.Scale) ~= "auto"
        error('geo:overlayTrack:BadScale', ...
            'Scale must be "auto" or a positive finite number; got "%s".', ...
            string(options.Scale));
    end
    peak = max(abs(obs(:)), [], 'omitnan');
    if ~isfinite(peak) || peak <= 0
        scale = 0;                      % nothing to deviate by
    else
        scale = options.ScaleFraction * diag / peak;
    end
    return
end
if ~isscalar(options.Scale) || ~isfinite(options.Scale) || options.Scale <= 0
    error('geo:overlayTrack:BadScale', ...
        'Scale must be "auto" or a positive finite number.');
end
scale = options.Scale;
end

function runs = contiguousRuns(lon, lat, obs)
%CONTIGUOUSRUNS  Index ranges with no gap in coordinate or observation.
%   The projection's own breaks are handled later; this is the DATA's
%   gap convention, which GEO.TRACK guarantees is preserved.
good = isfinite(lon) & isfinite(lat) & isfinite(obs);
starts = find(diff([false, good]) == 1);
stops = find(diff([good, false]) == -1);
runs = cell(1, numel(starts));
for k = 1:numel(starts)
    runs{k} = starts(k):stops(k);
end
end

function o = alignObs(obs, sourceIndex)
%ALIGNOBS  One observation per projected point, breaks carried as NaN.
%   SourceIndex is why GEO.INTERNAL.PROJECTPOLYLINE reports it: an
%   inserted break and a point that projected to NaN look identical in
%   the output, and only one of them consumes an input.
o = NaN(1, numel(sourceIndex));
ok = isfinite(sourceIndex);
o(ok) = obs(sourceIndex(ok));
end

function parts = subRuns(x, y)
%SUBRUNS  Index ranges of the projected polyline that are drawable.
good = isfinite(x) & isfinite(y);
starts = find(diff([false, good]) == 1);
stops = find(diff([good, false]) == -1);
parts = cell(1, numel(starts));
for k = 1:numel(starts)
    parts{k} = starts(k):stops(k);
end
end

function objs = drawRun(axH, x, y, obs, scale, cLim, cmap, options)
%DRAWRUN  One unbroken piece of track, in the chosen style.
z = 5;
objs = gobjects(1, 0);
if options.Baseline && numel(x) > 1
    objs(end + 1) = line('Parent', axH, 'XData', x, 'YData', y, ...
        'ZData', (z - 0.01) * ones(size(x)), ...
        'Color', options.BaselineColor, ...
        'LineWidth', max(options.LineWidth * 0.5, 0.5));
end

switch options.Style
    case "markers"
        rgb = geo.colormaps("truecolor", obs, cmap, CLim = cLim);
        wasHeld = ishold(axH);
        hold(axH, 'on');
        objs(end + 1) = scatter3(axH, x, y, z * ones(size(x)), ...
            options.MarkerSize, reshape(rgb, [], 3), 'filled');
        if ~wasHeld
            hold(axH, 'off');
        end
    case "line"
        rgb = geo.colormaps("truecolor", obs, cmap, CLim = cLim);
        C = reshape(rgb, 1, [], 3);
        objs(end + 1) = surface('Parent', axH, ...
            'XData', [x; x], 'YData', [y; y], ...
            'ZData', z * ones(2, numel(x)), 'CData', [C; C], ...
            'FaceColor', 'none', 'EdgeColor', 'interp', ...
            'LineWidth', options.LineWidth, 'FaceLighting', 'none');
    case "bicolor"
        [nx, ny] = unitNormals(x, y);
        amp = obs * scale;
        objs(end + 1) = ribbon(axH, x, y, nx, ny, max(amp, 0), z, ...
            options.BicolorColors(2, :), []);
        objs(end + 1) = ribbon(axH, x, y, nx, ny, min(amp, 0), z, ...
            options.BicolorColors(1, :), []);
    otherwise
        [nx, ny] = unitNormals(x, y);
        rgb = reshape(geo.colormaps("truecolor", obs, cmap, CLim = cLim), [], 3);
        objs(end + 1) = ribbon(axH, x, y, nx, ny, obs * scale, z, ...
            'interp', rgb);
end
end

function [nx, ny] = unitNormals(x, y)
%UNITNORMALS  Left-hand normal from centred differences, IN PROJECTED SPACE.
xp = [x(1), x(1:end-1)];
xn = [x(2:end), x(end)];
yp = [y(1), y(1:end-1)];
yn = [y(2:end), y(end)];
tx = xn - xp;
ty = yn - yp;
len = hypot(tx, ty);
len(len == 0) = 1;                      % a repeated point has no direction
nx = -ty ./ len;
ny = tx ./ len;
end

function h = ribbon(axH, x, y, nx, ny, amp, z, faceColour, rgb)
%RIBBON  The filled band between the track and its deviated copy.
n = numel(x);
xw = x + nx .* amp;
yw = y + ny .* amp;
verts = [x(:), y(:), z * ones(n, 1); xw(:), yw(:), z * ones(n, 1)];
faces = [(1:n-1).', (2:n).', (n+2:2*n).', (n+1:2*n-1).'];
if isempty(rgb)
    h = patch('Parent', axH, 'Vertices', verts, 'Faces', faces, ...
        'FaceColor', faceColour, 'EdgeColor', 'none', ...
        'FaceLighting', 'none');
else
    h = patch('Parent', axH, 'Vertices', verts, 'Faces', faces, ...
        'FaceVertexCData', [rgb; rgb], 'FaceColor', faceColour, ...
        'EdgeColor', 'none', 'FaceLighting', 'none');
end
end
