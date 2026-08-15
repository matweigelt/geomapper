function [T, trackID] = splitTracks(track, options)
%GEO.SPLITTRACKS  Split one continuous series into separate passes.
%
%   SYNTAX
%     T = GEO.SPLITTRACKS(TRACK)
%     [T, TRACKID] = GEO.SPLITTRACKS(TRACK, Name, Value)
%
%   DESCRIPTION
%     Ported from v1's geoSplitTracks, onto the GEO.TRACK struct. Takes
%     one long series - a month of along-track observations, a station
%     record, a set of concatenated passes - and inserts NaN breaks
%     wherever it decides one pass ended and the next began.
%
%     THE AUTO THRESHOLD IS THE MEDIAN OF THE STRICTLY POSITIVE TIME
%     STEPS, times TimeGapFactor. Both halves matter. The median rather
%     than the mean, because one long outage would drag a mean up until
%     nothing else counted as a gap. STRICTLY POSITIVE because merged
%     products repeat timestamps, and a median of zero would make every
%     step a gap and every sample its own track - v1's guard, ported
%     verbatim because it is correct and was hard won.
%
%     WHERE NOTHING CAN BE MEASURED, NOTHING IS SPLIT. If every step is
%     zero or there are no steps at all, the threshold becomes Inf rather
%     than a guess. A function that invents a threshold when it cannot
%     measure one produces confident nonsense.
%
%     REGION REMOVAL FORCES A BREAK. Samples dropped for falling outside
%     Region leave a real hole wherever they were, even if the two
%     surviving neighbours happen to be close in time - two separate
%     visits to the same place must not be joined into one pass just
%     because the gap between them was removed. v1 got this right and it
%     is one of Appendix B's named regression anchors.
%
%     TRACKID IS REPORTED AT THE ORIGINAL LENGTH, before any filtering,
%     with NaN for every sample that was dropped. A caller can therefore
%     line it up against the data they passed in, which they cannot do
%     with an index into a compacted array.
%
%   INPUTS
%     track  (1,1) struct  A GEO.TRACK. The loose form is not accepted:
%                          build the struct, so validation happens once.
%
%   OPTIONS
%     GroupID              (:,1)         []       Explicit grouping; when
%                                                 given, gap detection is
%                                                 skipped entirely.
%     TimeGapThreshold     (1,1) string  "auto"   "auto", or a numeric
%                                                 string in Time's units.
%     TimeGapFactor        (1,1) double  [5]      Multiplier for "auto".
%     SpatialJumpThreshold (1,1) double  [NaN]    km along the great
%                                                 circle. NaN disables.
%     MaxTrackDuration     (1,1) double  [NaN]    Force a break every so
%                                                 much elapsed time.
%     MaxTrackPoints       (1,1) double  [NaN]    Force a break every so
%                                                 many samples.
%     MinTrackPoints       (1,1) double  [2]      Shorter tracks dropped.
%     Region               (1,1)         []       Anything GEO.REGION
%                                                 accepts. Samples
%                                                 outside are dropped.
%
%   OUTPUTS
%     T        (1,1) struct  A GEO.TRACK, NaN-separated between passes.
%     trackID  (1,:) double  One entry per ORIGINAL sample: the 1-based
%                            pass number, or NaN if the sample was
%                            dropped. Numbering is contiguous, so a
%                            dropped short track leaves no hole in it.
%
%   ACCURACY
%     SpatialJumpThreshold is measured with GEO.GREATCIRCLE, so it is a
%     real distance in km on the authalic sphere rather than v1's
%     hypot(diff(lon), diff(lat)) in degrees - which counted a degree of
%     longitude at 70 degrees north as worth the same as one at the
%     equator, and so needed a different threshold per latitude band. The
%     spherical figure is within -0.268% of a WGS84 geodesic (see
%     GEO.GREATCIRCLE's ACCURACY block). This is a DELIBERATE CHANGE from
%     v1 and changes the meaning of the option's units; recorded as such
%     rather than slipped in.
%
%   ERRORS
%     Input:
%       geo:splitTracks:NoTime            - a time-based split was asked
%                                           for on a track with no Time
%       geo:splitTracks:GroupIDSizeMismatch - GroupID is not the track's
%                                           length
%       geo:splitTracks:InvalidThreshold  - TimeGapThreshold is neither
%                                           "auto" nor numeric
%     Outcome:
%       geo:splitTracks:NoTracksSurvived  - every pass was shorter than
%                                           MinTrackPoints
%       geo:splitTracks:TooFewInRegion    - fewer than two samples remain
%                                           after applying Region
%
%   WARNINGS
%       geo:splitTracks:TracksDropped     - some passes were shorter than
%                                           MinTrackPoints and removed
%
%   EXAMPLE
%     T0 = geo.track(lon, lat, Time = t, Obs = ewh);
%     [T, id] = geo.splitTracks(T0, TimeGapFactor = 5, MinTrackPoints = 10);
%
%   LIMITATIONS
%     Gap detection is one-dimensional in time and one-dimensional in
%     space, applied independently. A pass that doubles back on itself
%     slowly is not detected as two passes by either test, and no
%     threshold on this function can find it - that needs a heading
%     change, which is a different question from the one asked here.
%
%   See also GEO.TRACK, GEO.REGION, GEO.GREATCIRCLE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    track (1,1) struct
    options.GroupID (:,1) double = []
    options.TimeGapThreshold (1,1) string = "auto"
    options.TimeGapFactor (1,1) double {mustBePositive} = 5
    options.SpatialJumpThreshold (1,1) double = NaN
    options.MaxTrackDuration (1,1) double = NaN
    options.MaxTrackPoints (1,1) double = NaN
    options.MinTrackPoints (1,1) double {mustBeInteger, mustBePositive} = 2
    options.Region = []
end

geo.internal.mustBeIdentity(track, "geo.track", 'geo:track:NotATrack');

lon = double(track.Lon(:)).';
lat = double(track.Lat(:)).';
obs = double(track.Obs(:)).';
time = double(track.Time(:)).';
nFull = numel(lon);
if isempty(obs), obs = nan(1, nFull); end

% --- Region filter, before anything else -----------------------------
origIdx = 1:nFull;
haveRegion = ~isempty(options.Region);
if haveRegion
    R = geo.region(options.Region);
    keep = insideRegion(lon, lat, R);
    if sum(keep) < 2
        error('geo:splitTracks:TooFewInRegion', ...
            ['Fewer than two samples remain inside the region (%d of ' ...
             '%d). There is no track left to split.'], sum(keep), nFull);
    end
    origIdx = origIdx(keep);
    lon = lon(keep); lat = lat(keep); obs = obs(keep);
    if ~isempty(time), time = time(keep); end
end
n = numel(lon);

% --- Where does one pass end and the next begin? ---------------------
breakHere = false(1, n);
if ~isempty(options.GroupID)
    gid = options.GroupID(:).';
    if numel(gid) ~= nFull
        error('geo:splitTracks:GroupIDSizeMismatch', ...
            'GroupID has %d entries; the track has %d.', ...
            numel(gid), nFull);
    end
    gid = gid(origIdx);
    [~, ~, rawID] = unique(gid, 'stable');
    breakHere(2:end) = rawID(2:end).' ~= rawID(1:end-1).';
else
    breakHere = timeAndSpaceBreaks(time, lon, lat, n, options);
end

if haveRegion
    % A removed sample is a real gap, whatever the survivors' spacing.
    breakHere(2:end) = breakHere(2:end) | (diff(origIdx) > 1);
end

breakHere = forceExtraBreaks(breakHere, time, n, options);

% --- Number the passes, drop the short ones --------------------------
rawTrack = cumsum(breakHere) + 1;
counts = accumarray(rawTrack(:), 1);
tooShort = counts < options.MinTrackPoints;
dropped = tooShort(rawTrack);

if all(dropped)
    error('geo:splitTracks:NoTracksSurvived', ...
        ['Every one of the %d detected pass(es) was shorter than ' ...
         'MinTrackPoints (%d).'], numel(counts), options.MinTrackPoints);
end
if any(dropped)
    warning('geo:splitTracks:TracksDropped', ...
        '%d sample(s) in %d pass(es) shorter than MinTrackPoints (%d) dropped.', ...
        nnz(dropped), nnz(tooShort), options.MinTrackPoints);
end

surviving = unique(rawTrack(~dropped));
remap = zeros(1, max(rawTrack));
remap(surviving) = 1:numel(surviving);
localID = nan(1, n);
localID(~dropped) = remap(rawTrack(~dropped));

% --- Build the NaN-separated output ----------------------------------
keep = ~dropped;
idK = localID(keep);
breakAfter = find(diff(idK) ~= 0);
T = geo.track( ...
    insertBreaks(lon(keep), breakAfter), ...
    insertBreaks(lat(keep), breakAfter), ...
    Obs = insertBreaks(obs(keep), breakAfter), ...
    Time = insertBreaks(timeOrEmpty(time, keep), breakAfter), ...
    Source = track.Source, Units = track.Units);

trackID = nan(1, nFull);
trackID(origIdx) = localID;
end

% ======================================================================
function b = timeAndSpaceBreaks(time, lon, lat, n, options)
%TIMEANDSPACEBREAKS  Gap detection in time, then in space.
b = false(1, n);
if ~isempty(time)
    dt = diff(time);
    if options.TimeGapThreshold == "auto"
        % Median of the STRICTLY POSITIVE steps: repeated timestamps are
        % common and a median of zero would make every step a gap.
        med = median(dt(dt > 0));
        if isempty(med) || isnan(med) || med <= 0
            thresh = Inf;       % nothing measurable: split nothing
        else
            thresh = options.TimeGapFactor * med;
        end
    else
        thresh = str2double(options.TimeGapThreshold);
        if isnan(thresh)
            error('geo:splitTracks:InvalidThreshold', ...
                ['TimeGapThreshold must be "auto" or a numeric string; ' ...
                 'got "%s".'], options.TimeGapThreshold);
        end
    end
    b(2:end) = dt > thresh;
elseif options.TimeGapThreshold ~= "auto"
    error('geo:splitTracks:NoTime', ...
        ['A TimeGapThreshold was given but the track carries no Time. ' ...
         'Build the track with Time =, or split on ' ...
         'SpatialJumpThreshold instead.']);
end

if ~isnan(options.SpatialJumpThreshold)
    % Real kilometres on the sphere, not degrees: a degree of longitude
    % at 70 N is a third of one at the equator, and v1's degree-space
    % hypot needed a different threshold per latitude band because of it.
    g = geo.greatCircle([lon(1:end-1).' lat(1:end-1).'], ...
                        [lon(2:end).' lat(2:end).']);
    b(2:end) = b(2:end) | (g.DistanceKm.' > options.SpatialJumpThreshold);
end
end

function b = forceExtraBreaks(b, time, n, options)
%FORCEEXTRABREAKS  MaxTrackDuration and MaxTrackPoints, within segments.
if isnan(options.MaxTrackDuration) && isnan(options.MaxTrackPoints)
    return
end
segStart = [1, find(b)];
segEnd = [segStart(2:end) - 1, n];
extra = false(1, n);
for s = 1:numel(segStart)
    idx = segStart(s):segEnd(s);
    local = false(1, numel(idx));
    if ~isnan(options.MaxTrackDuration) && ~isempty(time)
        chunk = floor((time(idx) - time(idx(1))) / options.MaxTrackDuration);
        local(2:end) = local(2:end) | (diff(chunk) ~= 0);
    end
    if ~isnan(options.MaxTrackPoints)
        pos = 1:numel(idx);
        local(2:end) = local(2:end) | ...
            (mod(pos(2:end) - 1, options.MaxTrackPoints) == 0);
    end
    extra(idx) = local;
end
b = b | extra;
end

function out = insertBreaks(v, breakAfter)
%INSERTBREAKS  A NaN after each named index. Preallocated, never grown.
if isempty(v)
    out = v;
    return
end
n = numel(v);
out = nan(1, n + numel(breakAfter));
src = 1;
dst = 1;
for k = 1:numel(breakAfter)
    len = breakAfter(k) - src + 1;
    out(dst:dst+len-1) = v(src:src+len-1);
    dst = dst + len + 1;            % leave the NaN in place
    src = src + len;
end
out(dst:end) = v(src:end);
end

function t = timeOrEmpty(time, keep)
t = [];
if ~isempty(time)
    t = time(keep);
end
end

function tf = insideRegion(lon, lat, R)
%INSIDEREGION  Box test, or point-in-polygon when an outline exists.
if R.IsEmpty
    tf = true(size(lon));
    return
end
if isempty(R.Outline)
    tf = lon >= R.LonLim(1) & lon <= R.LonLim(2) & ...
         lat >= R.LatLim(1) & lat <= R.LatLim(2);
    return
end
% inpolygon is base MATLAB and handles NaN-separated multi-part outlines.
tf = inpolygon(lon, lat, R.Outline(:, 1), R.Outline(:, 2));
end
