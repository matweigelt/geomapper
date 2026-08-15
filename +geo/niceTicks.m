function ticks = niceTicks(lo, hi, options)
%GEO.NICETICKS  Round tick values, by a CEILING policy that never overshoots.
%
%   SYNTAX
%     TICKS = GEO.NICETICKS(LO, HI)
%     TICKS = GEO.NICETICKS(LO, HI, Mode = "graticule", TargetCount = 6)
%
%   DESCRIPTION
%     Merges v1's geoNiceTicks and geoNiceGraticuleStep, which were two
%     functions doing one job with two different policies.
%
%     THE POLICY IS CEILING, NOT NEAREST, and that is the F16 repair. v1
%     snapped to the NEAREST nice step, which can land either side of the
%     target: measured on the installed v1 over a ladder of thirteen
%     spans, it differs from the ceiling policy at four of them, worst
%     being a span of 45 degrees that yields TEN lines against a target of
%     six. The handover illustrated F16 as "3 or 11 lines"; the measured
%     worst is 10, and Part 5 was corrected to say so (C-033).
%
%     Choosing the smallest nice step NOT LESS THAN span/TargetCount means
%     the count can only come out at or below the target, never above.
%     Under-filling a map with graticule lines is a cosmetic
%     disappointment; over-filling it makes the labels collide, which is
%     a defect.
%
%     TWO STEP SETS, because the questions differ. "linear" uses the
%     decade-scaled 1-2-5 family, which is what a colourbar wants.
%     "graticule" uses the conventional cartographic set, which includes
%     3, 15, 45 and 90 because those divide a circle and a right angle
%     and 2.5 does not.
%
%   INPUTS
%     lo  (1,1) double  Range start.
%     hi  (1,1) double  Range end. Must exceed lo.
%
%   OPTIONS
%     Mode         (1,1) string  ["linear"]  "linear" | "graticule".
%     TargetCount  (1,1) double  [6]         Desired number of intervals.
%
%   OUTPUTS
%     ticks  (1,:) double  Ascending multiples of the chosen step, all
%                          inside [lo, hi] inclusive.
%
%   ACCURACY
%     The step is exact from the table; the ticks are integer multiples
%     of it, so they carry no accumulated error. Asserted in TestB2_fields
%     including the two neighbours F16's ceiling policy must reject.
%
%   ERRORS
%     Input geometry:
%       geo:niceTicks:EmptyRange - hi is not greater than lo
%
%   EXAMPLE
%     geo.niceTicks(0, 45, Mode = "graticule")   % step 10, not 5
%     geo.niceTicks(-3.2, 7.8)                   % step 2
%
%   LIMITATIONS
%     Ticks lie strictly within the range, so a range whose ends are not
%     multiples of the step has no tick at either end. A caller that needs
%     the endpoints labelled should add them; placing them automatically
%     would produce two ticks a hair apart wherever the end nearly
%     coincides with a multiple.
%
%   See also GEO.QUANTILE, GEO.GRATICULE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lo (1,1) double {mustBeReal, mustBeFinite}
    hi (1,1) double {mustBeReal, mustBeFinite}
    options.Mode (1,1) string ...
        {mustBeMember(options.Mode, ["linear" "graticule"])} = "linear"
    options.TargetCount (1,1) double {mustBePositive} = 6
end

if hi <= lo
    error('geo:niceTicks:EmptyRange', ...
        'hi (%g) must be greater than lo (%g).', hi, lo);
end

ideal = (hi - lo) / options.TargetCount;

if options.Mode == "graticule"
    % The conventional cartographic set: these divide a circle and a
    % right angle, which 2.5 and 7.5 do not.
    set = [0.1 0.2 0.25 0.5 1 2 3 5 10 15 20 30 45 60 90];
    k = find(set >= ideal, 1);
    if isempty(k)
        step = set(end);
    else
        step = set(k);
    end
else
    % Decade-scaled 1-2-5. CEILING again: the smallest of the family at
    % or above the ideal, not the closest to it.
    dec = 10^floor(log10(ideal));
    cand = [1 2 5 10] * dec;
    k = find(cand >= ideal, 1);
    step = cand(k);
end

ticks = (ceil(lo / step) : floor(hi / step)) * step;
end
