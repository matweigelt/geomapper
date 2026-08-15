function out = greatCircle(from, to, options)
%GEO.GREATCIRCLE  Spherical distance, bearing and destination.
%
%   SYNTAX
%     OUT = GEO.GREATCIRCLE(FROM, TO)
%     OUT = GEO.GREATCIRCLE(FROM, TO, Radius = R)
%     TO  = GEO.GREATCIRCLE(FROM, Bearing = B, Distance = D)
%
%   DESCRIPTION
%     The toolbox's only spherical geometry. GEO.SCALEBAR calibrates its
%     bar with it, GEO.SPLITTRACKS measures spatial jumps with it, and
%     Stage D's inset uses it for extent rectangles - in v1 each of those
%     carried its own haversine, and two of them disagreed about the
%     radius.
%
%     COORDINATES COME IN PAIRS, Nx2 [lon lat], and that is a DELIBERATE
%     DEVIATION from the handover's §7.3 signature
%     geo.greatCircle(lon1, lat1, lon2, lat2, ...). Four positional
%     arguments breaks the toolbox's own arity rule, which caps public
%     functions at three because v1's geoNorthArrow took fifteen and a
%     caller who got one wrong had no way to learn which (defect F7). A
%     rule with an exception written for the first function that finds it
%     inconvenient is not a rule. Pairing the coordinates also makes the
%     two arguments symmetric and unswappable-by-accident in a way four
%     loose numbers are not. Recorded as finding PV-042.
%
%     THE DESTINATION FORM TAKES ITS ARGUMENTS BY NAME for the same
%     reason: Bearing and Distance are not interchangeable, and
%     greatCircle(p, 45, 100) would not say which was which.
%
%   INPUTS
%     from  (N,2) double  [lon lat] in degrees. N = 1 broadcasts.
%     to    (N,2) double  [lon lat] in degrees. Omitted in the
%                         destination form.
%
%   OPTIONS
%     Radius    (1,1) double  [6371.0072]  km, authalic (D-001).
%     Bearing   (N,1) double  []           Degrees clockwise from north.
%                                          Destination form only.
%     Distance  (N,1) double  []           km along the great circle.
%                                          Destination form only.
%
%   OUTPUTS
%     Distance/bearing form - OUT (1,1) struct with fields:
%       DistanceKm         (N,1) double  Great-circle distance.
%       InitialBearingDeg  (N,1) double  At FROM, clockwise from north,
%                                        in [0, 360).
%       FinalBearingDeg    (N,1) double  Arriving at TO.
%     Destination form - OUT (N,2) double, [lon lat] of the destination,
%       longitude wrapped into [-180, 180).
%
%   ACCURACY
%     SPHERICAL, and the difference from a geodesic is quantified rather
%     than waved at. Measured against oracle O4 (pyproj.Geod, WGS84) on
%     Paris (2.3522, 48.8566) to New York (-74.0060, 40.7128), values in
%     mirror/geomap_mirror/out/reference_values.json under
%     stage_a_great_circle:
%
%       spherical, authalic radius   5837.2475 km
%       WGS84 geodesic               5852.9353 km
%       difference                   -0.268%
%       initial bearing, spherical   291.7939 deg
%       initial bearing, geodesic    291.8261 deg   (0.032 deg apart)
%
%     That -0.268% is the measurement decision D-001's "at most about
%     0.3%" rests on. It is invisible at figure scale and quite unsuitable
%     for survey work, which is the whole position of this toolbox.
%
%     The haversine form is used rather than the spherical law of
%     cosines: acos(...) loses precision catastrophically for short
%     separations, where a scale bar on a regional map lives.
%
%   ERRORS
%     Input geometry:
%       geo:greatCircle:SizeMismatch    - from and to have different N and
%                                         neither is 1
%     Shape is enforced by the ARGUMENTS block, so an input that is not
%     Nx2 fails with MATLAB's own size-mismatch identifier before the body
%     runs. No geo:* twin is coined for it: a deprecated alias for an
%     error is still an alias.
%     Form selection:
%       geo:greatCircle:AmbiguousForm   - both TO and Bearing/Distance
%                                         given, or neither
%       geo:greatCircle:IncompleteForm  - Bearing without Distance, or
%                                         the reverse
%
%   EXAMPLE
%     paris = [2.3522 48.8566];
%     ny    = [-74.0060 40.7128];
%     g = geo.greatCircle(paris, ny);
%     g.DistanceKm          % 5837.2
%
%     p = geo.greatCircle(paris, Bearing = 291.79, Distance = 5837.25);
%
%   LIMITATIONS
%     A sphere, not an ellipsoid, and no geodesic solver. For antipodal
%     or near-antipodal pairs the initial bearing is ill-conditioned -
%     every direction is a shortest path - and the returned value is
%     whatever atan2 makes of two nearly zero arguments. The distance
%     stays accurate there; the bearing does not.
%
%   See also GEO.SPLITTRACKS, GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    from (:,2) double {mustBeReal}
    to (:,2) double {mustBeReal} = double.empty(0, 2)
    options.Radius (1,1) double {mustBeReal, mustBePositive} = 6371.0072
    options.Bearing (:,1) double {mustBeReal} = []
    options.Distance (:,1) double {mustBeReal} = []
end

wantDestination = ~isempty(options.Bearing) || ~isempty(options.Distance);
if wantDestination && ~isempty(to)
    error('geo:greatCircle:AmbiguousForm', ...
        ['Both a destination point and a Bearing/Distance were given. ' ...
         'Ask for a distance between two points, or for the point at a ' ...
         'bearing and distance, not both at once.']);
end
if ~wantDestination && isempty(to)
    error('geo:greatCircle:AmbiguousForm', ...
        ['Neither a destination point nor a Bearing and Distance were ' ...
         'given, so there is nothing to compute.']);
end

d2r = pi / 180;

if wantDestination
    if isempty(options.Bearing) || isempty(options.Distance)
        error('geo:greatCircle:IncompleteForm', ...
            ['The destination form needs BOTH Bearing and Distance. ' ...
             'One without the other describes a circle, not a point.']);
    end
    p1 = from(:, 2) * d2r;
    l1 = from(:, 1) * d2r;
    brg = options.Bearing * d2r;
    ang = options.Distance / options.Radius;      % angular distance
    p2 = asin(sin(p1) .* cos(ang) + cos(p1) .* sin(ang) .* cos(brg));
    l2 = l1 + atan2(sin(brg) .* sin(ang) .* cos(p1), ...
                    cos(ang) - sin(p1) .* sin(p2));
    out = [geo.wrapLongitude(l2 / d2r, 0), p2 / d2r];
    return
end

if size(from, 1) ~= size(to, 1) && size(from, 1) ~= 1 && size(to, 1) ~= 1
    error('geo:greatCircle:SizeMismatch', ...
        ['from has %d row(s) and to has %d. They must match, or one of ' ...
         'them must be a single point to broadcast.'], ...
        size(from, 1), size(to, 1));
end

p1 = from(:, 2) * d2r;   l1 = from(:, 1) * d2r;
p2 = to(:, 2) * d2r;     l2 = to(:, 1) * d2r;
dp = p2 - p1;
dl = l2 - l1;

% Haversine, not the law of cosines: acos loses precision catastrophically
% at short separations, which is exactly where a regional scale bar lives.
a = sin(dp / 2).^2 + cos(p1) .* cos(p2) .* sin(dl / 2).^2;
distKm = 2 * options.Radius * asin(min(sqrt(a), 1));

initial = atan2(sin(dl) .* cos(p2), ...
                cos(p1) .* sin(p2) - sin(p1) .* cos(p2) .* cos(dl));
% The final bearing is the reverse of the bearing from TO back to FROM.
finalB = atan2(sin(-dl) .* cos(p1), ...
               cos(p2) .* sin(p1) - sin(p2) .* cos(p1) .* cos(dl)) + pi;

out = struct( ...
    'DistanceKm', distKm, ...
    'InitialBearingDeg', mod(initial / d2r, 360), ...
    'FinalBearingDeg', mod(finalB / d2r, 360));
end
