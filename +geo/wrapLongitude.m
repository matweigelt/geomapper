function lonOut = wrapLongitude(lon, lon0)
%GEO.WRAPLONGITUDE  Wrap longitudes into a half-open window, exactly.
%
%   SYNTAX
%     LONOUT = GEO.WRAPLONGITUDE(LON)
%     LONOUT = GEO.WRAPLONGITUDE(LON, LON0)
%
%   DESCRIPTION
%     Maps every element of LON into the half-open interval
%     [LON0-180, LON0+180), elementwise, preserving size and orientation.
%
%     THIS IS THE ONLY LONGITUDE WRAP IN THE TOOLBOX. v1 wrapped in five
%     places with three different conventions, and geo.project's Robinson
%     branch was the one that forgot (defect F2, measured: v1 placed
%     longitude 359 at x = +5.29 instead of -0.0148, roughly two map
%     widths out). One authority per fact means one wrap.
%
%     WHY THE WINDOW IS HALF-OPEN AT THE UPPER END. +180 and -180 are the
%     same meridian, so a closed interval would let the same place carry
%     two different numbers and every seam test would have to say which
%     one it meant. Choosing the lower end makes the antimeridian a single
%     value, and makes wrapping idempotent - a property Stage A asserts
%     bitwise rather than to a tolerance.
%
%   INPUTS
%     lon   (:,:) double  Degrees East. Any size. NaN and +/-Inf allowed.
%     lon0  (1,1) double  [0]  Window centre, degrees East.
%
%   OUTPUTS
%     lonOut  (:,:) double  Same size as LON, every finite element in
%                           [lon0-180, lon0+180).
%
%   ACCURACY
%     EXACT, bitwise, at the values that matter, and this was measured
%     rather than assumed (mirror `stage_a.check_wrap_exactness`, oracle
%     O3 - the analytic modular definition):
%
%       wrapLongitude( 180, 0) == -180    bitwise
%       wrapLongitude(-180, 0) == -180    bitwise
%       wrapLongitude(539.5, 0) == 179.5  bitwise
%
%     Exactness is required, not merely desirable: every downstream seam
%     test in geo.regrid, geo.splitAntimeridian and geo.coastline inherits
%     this function's error, so a wrap that is right to 1e-12 spends that
%     budget before its callers begin.
%
%     THE FORMULATION IS LOAD-BEARING. Two algebraically identical forms
%     were measured:
%
%       A   mod(lon - lon0 + 180, 360) - 180 + lon0        <- used here
%       B   mod(lon - (lon0 - 180), 360) + (lon0 - 180)
%
%     B is tidier and folds the offset into one term. It is also wrong:
%     at lon = lon0 = 0.1 it returns 0.09999999999999432 rather than 0.1,
%     because (lon0 - 180) is not representable and the error survives the
%     round trip. A returns 0.1 bitwise. Finding PV-040.
%
%   ERRORS
%     This function raises no geo:* identifier of its own, and that is a
%     deliberate contract rather than an omission. All validation happens
%     in the ARGUMENTS block, so a bad call fails with MATLAB's own
%     MATLAB:validators:* identifier before the body runs - which is the
%     identifier a caller can actually catch, and the one MATLAB's own
%     documentation describes. Inventing a geo:* twin for it would create
%     exactly the deprecated-alias problem that one-name-per-thing forbids.
%
%     Argument validation (MATLAB identifiers, listed so they are part of
%     the documented contract):
%       MATLAB:validators:mustBeReal      - lon or lon0 is complex
%       MATLAB:validators:mustBeFinite    - lon0 is NaN or Inf
%
%   EXAMPLE
%     geo.wrapLongitude([-190 -180 0 180 190])
%     % ans =   170  -180     0  -180  -170
%
%     geo.wrapLongitude(0:359, 180)      % into [0, 360)
%
%   LIMITATIONS
%     Inf and -Inf propagate as NaN, because MOD of an infinity is NaN and
%     no wrapped value would be meaningful. NaN propagates as NaN, which
%     is the toolbox-wide NaN-as-gap convention.
%
%   See also GEO.SPLITANTIMERIDIAN, GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    % No size restriction: the wrap is elementwise and must not care
    % whether a caller holds its longitudes as a row, a column or a grid.
    % Orientation preservation is a contract test, not a comment.
    lon double {mustBeReal}
    lon0 (1,1) double {mustBeReal, mustBeFinite} = 0
    options.Window (1,1) string ...
        {mustBeMember(options.Window, ["halfopen" "closed"])} = "halfopen"
end

% Formulation A. See ACCURACY: this is not interchangeable with the form
% that folds lon0 into a single offset.
lonOut = mod(lon - lon0 + 180, 360) - 180 + lon0;

if options.Window == "closed"
    % A CLOSED window leaves anything already inside [lon0-180, lon0+180]
    % exactly as it was, so BOTH antimeridians survive. The half-open
    % default cannot: it folds +180 onto -180, which is right for a
    % branch cut and wrong for a map EDGE. A global grid's eastern rim
    % is at +180 and its western rim at -180, and they are different
    % places on the page even though they are the same meridian on the
    % sphere (PV-140).
    %
    % The default is untouched, deliberately. acceptance.json freezes
    % wrap(180, 0) == -180 bitwise - "the antimeridian must be exactly
    % -180" - and that is F2's fix, not an accident.
    d = lon - lon0;
    inside = abs(d) <= 180;
    lonOut(inside) = lon(inside);
end
end
