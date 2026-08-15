function T = track(lon, lat, options)
%GEO.TRACK  Validated along-track series, NaN gaps preserved.
%
%   SYNTAX
%     T = GEO.TRACK(LON, LAT)
%     T = GEO.TRACK(LON, LAT, Name, Value)
%     T = GEO.TRACK(T)                      % idempotent: passes through
%
%   DESCRIPTION
%     The value struct an along-track observation series travels in,
%     replacing v1's loose (t, lon, lat, obs) quadruple.
%
%     NaN IS A GAP AND IS PRESERVED, NOT REMOVED. A track with a data
%     outage has a hole in it, and the hole is information: it is what
%     stops a line being drawn straight across the missing hours. v1
%     stripped NaNs in some paths and kept them in others, so whether a
%     gap appeared depended on which plotting function you called. Here
%     they always survive, and every downstream consumer treats them the
%     same way.
%
%     ORIENTATION IS PRESERVED. Unlike GEO.GRID, whose Z fixes a canonical
%     shape, a track is just a sequence: a caller who holds columns gets
%     columns back. The shape is a contract test, not a comment.
%
%     TIME IS OPTIONAL AND, IF PRESENT, MUST BE NON-DECREASING. Not
%     strictly increasing: repeated timestamps are common in merged
%     products and are not an error, whereas a step backwards means two
%     passes have been concatenated without being separated, which
%     GEO.SPLITTRACKS exists to do.
%
%   INPUTS
%     lon  (:,1) or (1,:) double  Degrees East. NaN allowed as a gap.
%                                 Or a geo.track struct, for the
%                                 idempotent form.
%     lat  same size as lon       Degrees North. NaN allowed as a gap.
%
%   OPTIONS
%     Time     same size as lon  []  Datetime, duration or numeric.
%                                    Non-decreasing where finite.
%     Obs      same size as lon  []  The observed quantity.
%     Source   (1,1) string      ""  Where the data came from.
%     Units    (1,1) string      ""  Units of Obs.
%
%   OUTPUTS
%     T  (1,1) struct  Fields:
%          Identity  (1,1) string   Always "geo.track".
%          Lon       same shape as given
%          Lat       same shape as given
%          Time      as given, or empty
%          Obs       as given, or empty
%          NumPoints (1,1) double   numel(Lon), gaps included.
%          NumGaps   (1,1) double   Count of NaN runs in Lon.
%          Source    (1,1) string
%          Units     (1,1) string
%
%   ACCURACY
%     No numerical claim. NumGaps counts RUNS, not NaN elements: a
%     six-hour outage sampled at one minute is one gap, not 360, and a
%     count that said 360 would be useless for exactly the question it is
%     asked - how many times did this track break.
%
%   ERRORS
%     Input geometry:
%       geo:track:SizeMismatch  - lat, Time or Obs is not the same size
%                                 as lon
%       geo:track:NotAVector    - an input is not a vector
%     Time validity:
%       geo:track:TimeDecreasing - Time steps backwards
%     Identity:
%       geo:track:NotATrack     - the idempotent form was given a struct
%                                 that is not a geo.track
%
%   EXAMPLE
%     T = geo.track([10 11 NaN 13], [50 51 NaN 53], ...
%                   Obs = [1 2 NaN 4], Units = "m");
%     T.NumGaps    % 1
%
%   LIMITATIONS
%     One track per struct. A file holding many passes is split into
%     several by GEO.SPLITTRACKS, which is where the notion of "how far
%     apart is too far" lives; this constructor makes no such judgement
%     and will happily hold a series that ought to be several.
%
%   See also GEO.SPLITTRACKS, GEO.POINTS, GEO.GRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon
    lat = []
    options.Time = []
    options.Obs = []
    options.Source (1,1) string = ""
    options.Units (1,1) string = ""
end

if isstruct(lon)
    geo.internal.mustBeIdentity(lon, "geo.track", 'geo:track:NotATrack');
    T = lon;
    return
end

geo.internal.mustBeSeries(lon, "lon", 'geo:track:NotAVector');
geo.internal.mustBeSeries(lat, "lat", 'geo:track:NotAVector');
n = numel(lon);
if numel(lat) ~= n
    error('geo:track:SizeMismatch', ...
        'lat has %d elements; lon has %d.', numel(lat), n);
end
for f = ["Time" "Obs"]
    v = options.(f);
    if isempty(v), continue, end
    if ~isvector(v)
        error('geo:track:NotAVector', '%s must be a vector.', f);
    end
    if numel(v) ~= n
        error('geo:track:SizeMismatch', ...
            '%s has %d elements; lon has %d.', f, numel(v), n);
    end
end

if ~isempty(options.Time)
    t = options.Time(:);
    finite = ~ismissing(t);
    d = diff(t(finite));
    if any(d < 0)
        error('geo:track:TimeDecreasing', ...
            ['Time steps backwards at %d place(s). Repeated timestamps ' ...
             'are accepted - merged products are full of them - but a ' ...
             'step backwards means two passes were concatenated without ' ...
             'being separated, which is geo.splitTracks'' job.'], ...
            sum(d < 0));
    end
end

T = struct( ...
    'Identity', "geo.track", ...
    'Lon', double(lon), ...
    'Lat', double(lat), ...
    'Time', options.Time, ...
    'Obs', double(options.Obs), ...
    'NumPoints', n, ...
    'NumGaps', geo.internal.countGaps(lon), ...
    'Source', options.Source, ...
    'Units', options.Units);
end
