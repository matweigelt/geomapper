function H = series(axH, T, options)
%GEO.SERIES  One time series: line, gaps, and an uncertainty band.
%
%   SYNTAX
%     H = GEO.SERIES(AX, T)
%     H = GEO.SERIES(AX, T, Name, Value)
%
%   DESCRIPTION
%     Draws one station's record into an ordinary axes: Time against
%     Obs, broken at gaps, optionally inside a shaded uncertainty band
%     and offset vertically so several can be stacked.
%
%     WHY THIS EXISTS. GEO.TIMESERIES is one of Stage E's six fronts,
%     and a front draws nothing - it orchestrates public elements. There
%     was no element that drew a series, so the rule fired exactly as it
%     did for the title: the missing capability belongs at L3. This is
%     it. Without it, GEO.TIMESERIES would have been v1's
%     geoImagescTimeSeries with the plotting inlined, which is where
%     every one of F8's 3413 lines came from.
%
%     THE GAP LOGIC IS GEO.SPLITTRACKS', NOT A SECOND COPY. A break is
%     where the sampling stops, and deciding that from the median step
%     is a real algorithm with real edge cases - repeated timestamps, a
%     single sample, an unsorted record. v1 wrote it twice, once here
%     and once in the track plotter, and the two used different
%     thresholds. Handover 4.1 names this as the thing not to repeat.
%
%     THE BAND IS DRAWN FIRST AND SITS BEHIND, at a lower z than the
%     line it belongs to, so an uncertainty envelope never hides the
%     measurement it describes. Both are drawn per segment, so a gap in
%     the record is a gap in the band as well - a band that bridged a
%     gap would assert a confidence over an interval with no data.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  Any axes. Unlike the map
%          elements this needs no basemap, because a series is not on a
%          map.
%     T    (1,1) struct  A GEO.TRACK carrying Time and Obs. Lon and Lat
%          are ignored here; the same value struct describes where a
%          record was taken and what it recorded, and a series uses the
%          second half.
%
%   OPTIONS
%     Offset       0        Added to Obs before drawing, for stacking.
%     Color        [0 0 0]
%     LineWidth    1
%     LineStyle    "-"
%     Marker       "none"
%     MarkerSize   4
%     Uncertainty  []       Half-width of the band, one value per
%                           sample or one for all. Empty draws no band.
%     BandAlpha    0.25
%     BandColor    []       Empty uses Color.
%     GapThreshold "auto"   Passed to GEO.SPLITTRACKS as
%                           TimeGapThreshold; "none" never breaks.
%     GapFactor    5        Passed as TimeGapFactor.
%     Label        ""       Drawn at the end of the trace, in the
%                           series' own colour. AT THE TRACE, not in a
%                           legend: a legend makes the reader match a
%                           colour to a name across the figure, which is
%                           the task stacking was meant to remove.
%     LabelSide    "right"  "right" | "left".
%     FontName     "Helvetica"
%     FontSize     9
%     ZLevel       0        Base z. The band sits 0.1 below it.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Line      (1,1) Line
%          Band      (1,1) Patch or empty
%          Label     (1,1) Text or empty
%          NumGaps   (1,1) double  Breaks the gap rule found.
%          Offset    (1,1) double  As applied.
%          All       (1,:)
%
%   ACCURACY
%     One claim, and it is exact: the drawn ordinate equals Obs plus
%     Offset at every sample. A stacked plot whose offsets were not
%     exactly what it reported would be unreadable, because the reader
%     subtracts them by eye.
%
%   ERRORS
%     geo:series:NoTime         - the track carries no Time
%     geo:series:NoObs          - the track carries no Obs
%     geo:series:UncertaintySize - Uncertainty is neither scalar nor one
%                                  value per sample
%
%   EXAMPLE
%     T = geo.track(lon, lat, Time = t, Obs = ewh, Units = "cm");
%     geo.series(ax, T, Uncertainty = sigma, Color = [0.8 0.1 0.1]);
%
%   LIMITATIONS
%     Time is drawn as whatever numeric value it holds - a datenum, a
%     posixtime, a year. Formatting the axis is GEO.TIMESERIES' job,
%     because only a front knows how many series share the axis.
%
%   See also GEO.TIMESERIES, GEO.TRACK, GEO.SPLITTRACKS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    T
    options.Offset (1,1) double {mustBeFinite} = 0
    options.Color (1,3) double {mustBeInRange(options.Color, 0, 1)} = [0 0 0]
    options.LineWidth (1,1) double {mustBePositive} = 1
    options.LineStyle (1,1) string = "-"
    options.Marker (1,1) string = "none"
    options.MarkerSize (1,1) double {mustBePositive} = 4
    options.Uncertainty double = []
    options.BandAlpha (1,1) double {mustBeInRange(options.BandAlpha, 0, 1)} = 0.25
    options.BandColor double = []
    options.GapThreshold (1,1) string = "auto"
    options.GapFactor (1,1) double {mustBePositive} = 5
    options.Label (1,1) string = ""
    options.LabelSide (1,1) string {mustBeMember(options.LabelSide, ["right" "left"])} = "right"
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 9
    options.ZLevel (1,1) double = 0
end

T = geo.track(T);
if isempty(T.Time)
    error('geo:series:NoTime', ...
        ['A series is Obs against Time and this geo.track carries no ' ...
         'Time. Build it with Time = , or draw it on a map with ' ...
         'geo.overlayTrack.']);
end
if isempty(T.Obs)
    error('geo:series:NoObs', ...
        'A series needs Obs. Build the track with Obs = .');
end

sigma = expandUncertainty(options.Uncertainty, T.NumPoints);
[t, y, s, nGaps] = brokenAt(T, sigma, options);
y = y + options.Offset;

wasHeld = ishold(axH);
hold(axH, 'on');
band = drawBand(axH, t, y, s, options);
ln = plot3(axH, t, y, options.ZLevel * ones(size(t)), ...
    'Color', options.Color, ...
    'LineWidth', options.LineWidth, ...
    'LineStyle', char(options.LineStyle), ...
    'Marker', char(options.Marker), ...
    'MarkerSize', options.MarkerSize, ...
    'MarkerFaceColor', options.Color);
label = drawLabel(axH, t, y, options);
if ~wasHeld
    hold(axH, 'off');
end

H = struct('Line', ln, 'Band', band, 'Label', label, 'NumGaps', nGaps, ...
    'Offset', options.Offset, 'All', [band ln label]);
end

% ======================================================================
function sigma = expandUncertainty(u, n)
%EXPANDUNCERTAINTY  Scalar or per-sample, and nothing in between.
if isempty(u)
    sigma = [];
    return
end
u = double(u(:)).';
if isscalar(u)
    sigma = repmat(u, 1, n);
    return
end
if numel(u) ~= n
    error('geo:series:UncertaintySize', ...
        ['Uncertainty has %d values and the track has %d samples. Give ' ...
         'one value per sample, or one for all of them.'], numel(u), n);
end
sigma = u;
end

function [t, y, s, nGaps] = brokenAt(T, sigma, options)
%BROKENAT  NaN-separated at the gaps GEO.SPLITTRACKS finds.
%   The uncertainty rides along by index, which is why the split has to
%   report WHERE the breaks went rather than only the broken series: a
%   band realigned by one sample is worse than no band.
if options.GapThreshold == "none"
    t = double(T.Time(:)).';
    y = double(T.Obs(:)).';
    s = sigma;
    nGaps = 0;
    return
end
[~, id] = geo.splitTracks(T, TimeGapThreshold = options.GapThreshold, ...
    TimeGapFactor = options.GapFactor);
breakAfter = find(diff(id) ~= 0 & isfinite(id(1:end-1)) & isfinite(id(2:end)));
nGaps = numel(breakAfter);
t = insertNaN(double(T.Time(:)).', breakAfter);
y = insertNaN(double(T.Obs(:)).', breakAfter);
s = insertNaN(sigma, breakAfter);
end

function out = insertNaN(v, breakAfter)
%INSERTNAN  One NaN after each named index. Preallocated, never grown.
if isempty(v)
    out = v;
    return
end
out = nan(1, numel(v) + numel(breakAfter));
src = 1;
dst = 1;
for k = 1:numel(breakAfter)
    len = breakAfter(k) - src + 1;
    out(dst:dst+len-1) = v(src:src+len-1);
    dst = dst + len + 1;
    src = src + len;
end
out(dst:end) = v(src:end);
end

function band = drawBand(axH, t, y, s, options)
%DRAWBAND  One patch per unbroken run, behind the line.
band = gobjects(1, 0);
if isempty(s)
    return
end
colour = options.BandColor;
if isempty(colour)
    colour = options.Color;
end
ok = isfinite(t) & isfinite(y) & isfinite(s);
runs = runsOf(ok);
% Collected and joined once: the number of runs is not known until the
% mask has been walked (F13).
parts = cell(1, numel(runs));
for k = 1:numel(runs)
    idx = runs{k};
    if numel(idx) < 2
        continue
    end
    xs = [t(idx), fliplr(t(idx))];
    ys = [y(idx) - s(idx), fliplr(y(idx) + s(idx))];
    parts{k} = patch(axH, 'XData', xs, 'YData', ys, ...
        'ZData', (options.ZLevel - 0.1) * ones(size(xs)), ...
        'FaceColor', colour, 'FaceAlpha', options.BandAlpha, ...
        'EdgeColor', 'none');
end
band = [parts{:}];
end

function label = drawLabel(axH, t, y, options)
%DRAWLABEL  The station's name, at the end of its own trace.
%   AT THE TRACE, NOT IN A LEGEND, and that is the right answer for a
%   stacked plot rather than a stylistic one: a legend makes the reader
%   match a colour to a name across the figure, which is exactly the
%   task that stacking the series was meant to remove. It also keeps
%   the label inside the element - GEO.TIMESERIES then draws nothing at
%   all, which is what lets it be a front.
label = gobjects(1, 0);
if strlength(options.Label) == 0
    return
end
ok = find(isfinite(t) & isfinite(y));
if isempty(ok)
    return
end
if options.LabelSide == "right"
    at = ok(end);
    align = 'left';
    pad = 1;
else
    at = ok(1);
    align = 'right';
    pad = -1;
end
span = max(t(ok)) - min(t(ok));
if span == 0
    span = 1;
end
label = text(axH, t(at) + pad * 0.01 * span, y(at), options.ZLevel, ...
    char(options.Label), ...
    'HorizontalAlignment', align, 'VerticalAlignment', 'middle', ...
    'Color', options.Color, 'FontName', char(options.FontName), ...
    'FontSize', options.FontSize, 'Clipping', 'off');
end

function runs = runsOf(mask)
%RUNSOF  Index ranges of the true runs in a logical vector.
d = diff([false, mask, false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
runs = arrayfun(@(a, b) a:b, starts, stops, 'UniformOutput', false);
end
