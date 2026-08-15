function varargout = splitAntimeridian(lon, lat, varargin)
%GEO.SPLITANTIMERIDIAN  Break paths at the antimeridian, at the edge.
%
%   SYNTAX
%     [LON2, LAT2] = GEO.SPLITANTIMERIDIAN(LON, LAT)
%     [LON2, LAT2, P1, P2, ...] = GEO.SPLITANTIMERIDIAN(LON, LAT, P1, P2, ...)
%     [...] = GEO.SPLITANTIMERIDIAN(..., Name, Value)
%
%   DESCRIPTION
%     Inserts a NaN wherever a path crosses the antimeridian, so a line
%     drawn through the result does not streak back across the whole map.
%     In the default "interpolate" mode it additionally inserts the two
%     crossing points, at exactly -180 and +180, so a coastline meets the
%     map edge instead of stopping one sample short of it.
%
%     THIS IS THE ONLY SPLIT IN THE TOOLBOX. v1 had five: two named
%     functions and three ad-hoc copies inside the plotters, which is five
%     places for a seam defect to live and one place for it to be fixed.
%
%     THE CROSSING PARAMETER USES THE WRAPPED LONGITUDE DIFFERENCE, and
%     that is the whole correctness point. A step from 179 to -179 is two
%     degrees east, not 358 degrees west. Measured (mirror
%     `stage_a.check_crossing_interpolation`, finding PV-041): on that
%     segment with latitudes 10 and 20, the wrapped delta puts the
%     crossing at latitude 15.0 - the midpoint, obviously right - and the
%     naive delta puts it at 9.97, which is barely off the start point and
%     looks entirely plausible on a plot. A wrong answer that draws
%     nicely is the failure mode this project exists to catch.
%
%     EXISTING NaNs ARE EXISTING BREAKS. A path already broken is not
%     split across the break, and no second NaN is inserted beside the
%     first: a double break is indistinguishable from a one-sample gap to
%     everything downstream.
%
%   INPUTS
%     lon   (:,1) or (1,:) double  Degrees East. NaN allowed as a gap.
%     lat   same size as lon       Degrees North.
%     P1..  same size as lon       Any number of payload vectors, split
%                                  identically. Interpolated in
%                                  "interpolate" mode, so pass values
%                                  that are meaningful to interpolate.
%
%   OPTIONS
%     JumpThreshold  (1,1) double  [180]  Degrees. A step whose wrapped
%                                         magnitude exceeds this is a
%                                         crossing. Kept as an option
%                                         because a coarsely sampled
%                                         track can step legitimately far.
%     Mode           (1,1) string  ["interpolate"]  "interpolate" inserts
%                                         the two edge points before the
%                                         NaN; "break" inserts only NaN.
%
%   OUTPUTS
%     Same count and orientation as the inputs, longer by two or three
%     elements per crossing. Row input gives row output.
%
%   ACCURACY
%     Inserted crossing points sit at exactly -180 and +180 (bitwise, by
%     assignment rather than arithmetic) and their latitude is exact to
%     1e-12. The tight tolerance is not ambition: linear interpolation of
%     a two-point segment has NO truncation error, so anything looser
%     would be concealing a defect rather than allowing for one. Oracle
%     O3, analytic.
%
%   ERRORS
%     Input geometry:
%       geo:splitAntimeridian:SizeMismatch   - a payload vector is not the
%                                              same length as lon
%       geo:splitAntimeridian:NotAVector     - an input is not a vector
%
%   EXAMPLE
%     [lo, la] = geo.splitAntimeridian([170 179 -179 -170], [0 5 10 15]);
%     % lo = 170  179  180  NaN  -180  -179  -170
%
%   LIMITATIONS
%     A segment that crosses the antimeridian AND spans more than
%     JumpThreshold for an unrelated reason cannot be told apart from a
%     crossing; both are split. Sampling finely enough that a genuine step
%     stays under the threshold is the caller's job, and the threshold is
%     an option so that job is possible.
%
%   See also GEO.WRAPLONGITUDE, GEO.SPLITTRACKS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

[payload, opts] = parseTrailing(varargin);

mustBeVectorLike(lon, "lon");
mustBeVectorLike(lat, "lat");
n = numel(lon);
if numel(lat) ~= n
    error('geo:splitAntimeridian:SizeMismatch', ...
        'lat has %d elements; lon has %d.', numel(lat), n);
end
for k = 1:numel(payload)
    mustBeVectorLike(payload{k}, sprintf("payload %d", k));
    if numel(payload{k}) ~= n
        error('geo:splitAntimeridian:SizeMismatch', ...
            'Payload %d has %d elements; lon has %d.', ...
            k, numel(payload{k}), n);
    end
end

wasRow = isrow(lon);
% Preallocated, not grown. The first draft appended a column per payload
% with a %#ok<AGROW> beside it, and the project's own static audit
% rejected it on the first run - which is precisely defect F13, the
% O(N^2) accumulation that made v1's readers unusable on a full-resolution
% coastline. A pragma silencing that would have been a guard, not a fix.
cols = zeros(n, 2 + numel(payload));
cols(:, 1) = double(lon(:));
cols(:, 2) = double(lat(:));
for k = 1:numel(payload)
    cols(:, 2 + k) = double(payload{k}(:));
end

out = splitColumns(cols, opts.JumpThreshold, opts.Mode);

varargout = cell(1, size(out, 2));
for k = 1:size(out, 2)
    v = out(:, k);
    if wasRow
        v = v.';
    end
    varargout{k} = v;
end
end

% ======================================================================
function out = splitColumns(cols, threshold, mode)
%SPLITCOLUMNS  The whole algorithm, on columns, orientation already handled.
lon = cols(:, 1);
n = numel(lon);
if n < 2
    out = cols;
    return
end

% DETECTION USES THE RAW STEP; INTERPOLATION USES THE WRAPPED ONE. They
% are different questions and the first draft of this function asked the
% wrong one for detection: it wrapped first, which turns every crossing
% into a small step by construction, so nothing was ever split. A
% crossing is precisely a pair whose RAW separation is large while its
% wrapped separation is small - that is what "crossing the seam" means.
% The wrapped delta comes back below, where the crossing point is placed.
dRaw = lon(2:end) - lon(1:end-1);
isJump = abs(dRaw) > threshold;

% An existing NaN is an existing break: never split across it, and never
% add a second NaN beside the first.
hasNaN = isnan(lon(1:end-1)) | isnan(lon(2:end));
isJump = isJump & ~hasNaN;

if ~any(isJump)
    out = cols;
    return
end

nanRow = nan(1, size(cols, 2));
pieces = cell(1, 2 * n);
np = 0;
last = 1;
for i = find(isJump).'
    np = np + 1;
    pieces{np} = cols(last:i, :);
    if mode == "interpolate"
        [a, b] = crossingRows(cols(i, :), cols(i+1, :));
        np = np + 1;  pieces{np} = a;
        np = np + 1;  pieces{np} = nanRow;
        np = np + 1;  pieces{np} = b;
    else
        np = np + 1;  pieces{np} = nanRow;
    end
    last = i + 1;
end
np = np + 1;
pieces{np} = cols(last:end, :);
out = vertcat(pieces{1:np});
end

function [a, b] = crossingRows(r1, r2)
%CROSSINGROWS  The two edge points, on the correct sides.
%   Longitudes are ASSIGNED +/-180 rather than computed, so they are
%   bitwise exact by construction; only the latitude and the payloads are
%   interpolated, and a two-point linear interpolation is exact.
d = geo.wrapLongitude(r2(1) - r1(1), 0);
% Distance from r1's longitude to the edge it is heading towards.
edgeFromR1 = sign(d) * 180;
t = (edgeFromR1 - r1(1)) / d;
t = min(max(t, 0), 1);              % a crossing lies inside the segment

a = r1 + t * (r2 - r1);
% r2 - r1 in longitude is the NAIVE difference and is meaningless across
% the seam, so the interpolated longitude is discarded and replaced.
a(1) = edgeFromR1;
b = a;
b(1) = -edgeFromR1;
% Latitude and payloads: interpolate on the wrapped parameter t. The
% subtraction r2 - r1 is correct for every column EXCEPT longitude, which
% is why only column 1 is overwritten.
a(2:end) = r1(2:end) + t * (r2(2:end) - r1(2:end));
b(2:end) = a(2:end);
end

function [payload, opts] = parseTrailing(args)
%PARSETRAILING  Separate payload vectors from trailing name-value options.
%   A varargin split, not an ad-hoc parser: the options themselves are
%   validated by an arguments block in a local function, so the rules and
%   the messages are MATLAB's own.
firstOpt = numel(args) + 1;
for i = 1:numel(args)
    if (isstring(args{i}) || ischar(args{i})) && isscalar(string(args{i}))
        firstOpt = i;
        break
    end
end
payload = args(1:firstOpt-1);
opts = optionDefaults(args{firstOpt:end});
end

function o = optionDefaults(options)
arguments
    options.JumpThreshold (1,1) double ...
        {mustBeReal, mustBePositive, mustBeFinite} = 180
    options.Mode (1,1) string ...
        {mustBeMember(options.Mode, ["interpolate" "break"])} = "interpolate"
end
o = options;
end

function mustBeVectorLike(v, what)
if ~isnumeric(v) || ~isreal(v) || (~isvector(v) && ~isempty(v))
    error('geo:splitAntimeridian:NotAVector', ...
        '%s must be a real numeric vector.', what);
end
end
