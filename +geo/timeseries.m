function H = timeseries(T, options)
%GEO.TIMESERIES  Several stations' records, stacked and labelled.
%
%   L4-FRONT
%
%   SYNTAX
%     H = GEO.TIMESERIES(T)
%     H = GEO.TIMESERIES(T, Name, Value)
%
%   DESCRIPTION
%     Draws an array of GEO.TRACK as a stack of time series: one
%     GEO.SERIES per station, offset vertically so they do not overlap,
%     each labelled at its own trace.
%
%     IT DRAWS NOTHING ITSELF. Every mark on the figure is made by
%     GEO.SERIES, including the reference lines - a horizontal line at a
%     constant value over the time span IS a series, and treating it as
%     one is why there is no second line-drawing path here. That is the
%     whole reason GEO.SERIES exists: v1's geoImagescTimeSeries inlined
%     its plotting, its gap detection and its band drawing, and the gap
%     detection then disagreed with the one in the track plotter.
%
%     THE OFFSET IS COMPUTED FROM THE DATA, ONCE. The default spacing is
%     a robust measure of how much room a station needs - the median of
%     the per-station 5-to-95 percentile ranges - so a single noisy
%     station does not push every trace apart, and a single flat one
%     does not let them collide. v1 defaulted to the maximum range,
%     which is that first failure exactly.
%
%     THE OFFSETS ARE REPORTED, and that matters more than it looks: a
%     stacked plot is read by subtracting the offsets by eye, so a plot
%     whose offsets were not exactly what it reported would be
%     unreadable. H.Offsets is what was applied.
%
%     ON THE Y LABEL AND THE AXES SETTINGS. This function writes
%     axH.YLabel.String and the axis limits directly. That is
%     CONFIGURATION of objects the axes already owns, not drawing: no
%     graphics object is created, and the same is true of XLim. Calling
%     ylabel() would create one, which is why ylabel is on the audit's
%     banned list and this is not. The distinction is narrow enough to
%     be worth stating rather than leaving to be inferred.
%
%   INPUTS
%     T  (1,:) struct  An array of GEO.TRACK, each carrying Time and
%                      Obs. One track is a stack of one.
%
%   OPTIONS
%     Offset        true    false draws every series on a common
%                           baseline; true stacks them; a numeric vector
%                           gives the offsets explicitly, one per series.
%     OffsetSpacing []      The gap between stacked traces. Empty
%                           computes it from the data, as above.
%     Labels        []      One string per series. Empty uses each
%                           track's Source, and then "1", "2", ...
%     Colors        []      Nx3. Empty takes N colours from
%                           GEO.COLORMAPS' qualitative set.
%     Uncertainty   {}      A cell array, one entry per series, each
%                           passed to GEO.SERIES as its Uncertainty.
%     ReferenceLines []     Y values at which to draw a horizontal line,
%                           in each series' own offset frame.
%     ReferenceColor [0.6 0.6 0.6]
%     GapThreshold  "auto"  Passed through to GEO.SERIES, which passes
%                           it to GEO.SPLITTRACKS.
%     GapFactor     5
%     YLabel        ""
%     Title         ""      Drawn by GEO.TITLE if the axes carries a
%                           map, and set as the axes title otherwise -
%                           a series plot has no plotted box to hang a
%                           map title on.
%     LineWidth     1
%     Marker        "none"
%     FontName      "Helvetica"
%     FontSize      9
%     Parent        []      An axes to draw into.
%     Export        ""      A path, handed to GEO.EXPORT.
%     ExportOptions struct()
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Figure   (1,1) matlab.ui.Figure
%          Axes     (1,1) matlab.graphics.axis.Axes
%          Series   (1,:) struct  One GEO.SERIES result per station.
%          Reference (1,:) struct  One per reference line.
%          Offsets  (1,:) double  As applied, in the order given.
%          Spacing  (1,1) double  The spacing used, computed or given.
%
%   ACCURACY
%     Exact, and asserted: the drawn ordinate of series k equals its Obs
%     plus H.Offsets(k) at every sample, and the offsets are evenly
%     spaced by H.Spacing when they were computed rather than given.
%
%   ERRORS
%     geo:timeseries:NoSeries      - an empty array of tracks
%     geo:timeseries:OffsetCount   - explicit offsets, wrong number
%     geo:timeseries:LabelCount    - explicit labels, wrong number
%
%   EXAMPLE
%     H = geo.timeseries([gps1 gps2 gps3], ...
%         Labels = ["ONSA" "MAR6" "VIS0"], YLabel = "EWH (cm)", ...
%         ReferenceLines = 0, Export = "stations.pdf");
%
%   LIMITATIONS
%     One axes. Series beside a map is GEO.PANEL's job. Time is drawn as
%     whatever numeric value the tracks carry; this does not convert
%     datenums to dates, because it cannot know which convention a
%     caller's numbers follow.
%
%   See also GEO.SERIES, GEO.TRACK, GEO.SPLITTRACKS, GEO.PANEL.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    T
    options.Offset = true
    options.OffsetSpacing double = []
    options.Labels string = string.empty(1, 0)
    options.Colors double = []
    options.Uncertainty cell = {}
    options.ReferenceLines double = []
    options.ReferenceColor (1,3) double = [0.6 0.6 0.6]
    options.GapThreshold (1,1) string = "auto"
    options.GapFactor (1,1) double {mustBePositive} = 5
    options.YLabel (1,1) string = ""
    options.Title (1,1) string = ""
    options.LineWidth (1,1) double {mustBePositive} = 1
    options.Marker (1,1) string = "none"
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 9
    options.Parent = []
    options.Export (1,1) string = ""
    options.ExportOptions struct = struct()
end

T = normalise(T);
n = numel(T);
[offsets, spacing] = offsetsFor(T, options);
labels = labelsFor(T, options);
colours = coloursFor(n, options);

[figH, axH] = axesFor(options);
H = struct('Figure', figH, 'Axes', axH, 'Offsets', offsets, ...
    'Spacing', spacing);
H.Reference = drawReferences(axH, T, offsets, options);
H.Series = drawSeries(axH, T, offsets, labels, colours, options);

axH.YLabel.String = char(options.YLabel);
axH.FontName = char(options.FontName);
axH.FontSize = options.FontSize;
if strlength(options.Title) > 0
    axH.Title.String = char(options.Title);
end

if strlength(options.Export) > 0
    nv = namedargs2cell(options.ExportOptions);
    geo.export(figH, options.Export, nv{:});
end
end

% ======================================================================
function T = normalise(T)
%NORMALISE  One array of geo.track, however it arrived.
if isstruct(T) && ~isempty(T)
    T = arrayfun(@geo.track, T);
elseif iscell(T)
    T = cellfun(@geo.track, T);
end
if isempty(T)
    error('geo:timeseries:NoSeries', ...
        'There are no tracks to draw. Give at least one geo.track.');
end
end

function [offsets, spacing] = offsetsFor(T, options)
%OFFSETSFOR  Explicit, stacked, or flat - and the spacing it used.
n = numel(T);
if isnumeric(options.Offset) && ~islogical(options.Offset)
    offsets = double(options.Offset(:)).';
    if numel(offsets) ~= n
        error('geo:timeseries:OffsetCount', ...
            '%d offsets for %d series.', numel(offsets), n);
    end
    spacing = NaN;
    return
end
if ~options.Offset
    offsets = zeros(1, n);
    spacing = 0;
    return
end
spacing = options.OffsetSpacing;
if isempty(spacing)
    spacing = typicalRange(T);
end
% Descending, so the first series is at the top - which is the order the
% labels are read in and the order the caller listed them.
offsets = (n - 1:-1:0) * spacing;
end

function s = typicalRange(T)
%TYPICALRANGE  How much room a station needs, robustly.
%   The MEDIAN of the per-station 5-95 ranges, not the maximum. v1 used
%   the maximum, so one noisy station pushed every trace apart and the
%   quiet ones became flat lines with no visible structure.
r = zeros(1, numel(T));
for k = 1:numel(T)
    v = double(T(k).Obs(:));
    v = v(isfinite(v));
    if numel(v) < 2
        r(k) = 0;
        continue
    end
    % PERCENTAGES, not fractions: geo.quantile takes [0, 100]. Written
    % as [0.05 0.95] this asked for the 0.05th and 0.95th percentiles -
    % two values a hair apart at the very bottom of the distribution -
    % and the spacing would have been near zero with every trace on top
    % of the next.
    q = geo.quantile(v, [5 95]);
    r(k) = q(2) - q(1);
end
r = r(r > 0);
if isempty(r)
    s = 1;      % every series is flat; any positive spacing will do
    return
end
s = 1.4 * median(r);
end

function labels = labelsFor(T, options)
%LABELSFOR  The caller's, the track's own Source, or its index.
n = numel(T);
if ~isempty(options.Labels)
    labels = string(options.Labels(:)).';
    if numel(labels) ~= n
        error('geo:timeseries:LabelCount', ...
            '%d labels for %d series.', numel(labels), n);
    end
    return
end
labels = strings(1, n);
for k = 1:n
    if strlength(string(T(k).Source)) > 0
        labels(k) = string(T(k).Source);
    else
        labels(k) = string(k);
    end
end
end

function c = coloursFor(n, options)
%COLOURSFOR  N distinguishable colours, or the caller's own.
if ~isempty(options.Colors)
    c = options.Colors;
    c = c(mod(0:n-1, size(c, 1)) + 1, :);
    return
end
% VIRIDIS IN STACK ORDER, not an invented qualitative palette. Two
% reasons, and neither is aesthetic. A palette is DATA, and data belongs
% in geo.colormaps with its provenance, not as a literal inside a front.
% And for a stack the ordering is information: the colour tells the
% reader which trace is which even where two of them cross, which a
% categorical palette does not.
%
% n+1 sampled and the last dropped, because viridis ends in a yellow
% that is faint on white paper. Stated rather than tuned: it is the one
% end of the ramp that does not survive printing.
c = geo.colormaps("get", "viridis", n + 1);
c = c(1:n, :);
end

function [figH, axH] = axesFor(options)
%AXESFOR  The caller's axes, or a new figure.
if ~isempty(options.Parent)
    axH = options.Parent;
    figH = ancestor(axH, 'figure');
    return
end
figH = figure('Color', 'w');
axH = axes('Parent', figH);
end

function R = drawReferences(axH, T, offsets, options)
%DRAWREFERENCES  A horizontal line IS a series, so it is drawn as one.
R = struct([]);
if isempty(options.ReferenceLines)
    return
end
span = timeSpan(T);
% Collected and joined once (F13).
parts = cell(1, 0);
for k = 1:numel(T)
    for v = options.ReferenceLines(:).'
        ref = geo.track([0 0], [0 0], Time = span, Obs = [v v]);
        parts{end + 1} = geo.series(axH, ref, Offset = offsets(k), ...
            Color = options.ReferenceColor, LineWidth = 0.5, ...
            LineStyle = ":", GapThreshold = "none", ZLevel = -1);
    end
end
R = [parts{:}];
end

function S = drawSeries(axH, T, offsets, labels, colours, options)
%DRAWSERIES  One GEO.SERIES per station, and nothing else.
parts = cell(1, numel(T));
for k = 1:numel(T)
    u = [];
    if numel(options.Uncertainty) >= k
        u = options.Uncertainty{k};
    end
    parts{k} = geo.series(axH, T(k), Offset = offsets(k), ...
        Color = colours(k, :), LineWidth = options.LineWidth, ...
        Marker = options.Marker, Uncertainty = u, ...
        GapThreshold = options.GapThreshold, ...
        GapFactor = options.GapFactor, Label = labels(k), ...
        FontName = options.FontName, FontSize = options.FontSize);
end
S = [parts{:}];
end

function span = timeSpan(T)
%TIMESPAN  First and last finite time across every series.
lo = Inf;
hi = -Inf;
for k = 1:numel(T)
    t = double(T(k).Time(:));
    t = t(isfinite(t));
    if isempty(t), continue, end
    lo = min(lo, min(t));
    hi = max(hi, max(t));
end
if ~isfinite(lo)
    lo = 0;
    hi = 1;
end
span = [lo hi];
end
