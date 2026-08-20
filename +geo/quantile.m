function q = quantile(Z, p)
%GEO.QUANTILE  Type-7 interpolated quantiles, without a toolbox.
%
%   SYNTAX
%     Q = GEO.QUANTILE(Z, P)
%
%   DESCRIPTION
%     The linear-interpolation quantile of R, NumPy and MATLAB's own
%     Statistics Toolbox: h = (n-1)*p/100 + 1, then interpolate between
%     the neighbouring order statistics.
%
%     WHY NOT PRCTILE. The Statistics and Machine Learning Toolbox is a
%     dependency this toolbox does not have and will not acquire - that
%     is defect F1's whole subject, and v1 shipped a claim of "no
%     toolboxes required" that was false at 32 call sites.
%
%     F10, AND WHY IT MATTERS MORE THAN IT LOOKS. v1's geoPercentileRange
%     computed an INDEX with round(p/100*n) and returned the sample there.
%     An index rule cannot return a value between two samples at all, so
%     the median of [1 2] came back as 1 rather than 1.5 - measured on the
%     installed v1. On a two-valued mask that is the difference between a
%     colour limit that splits the data and one that puts everything on
%     one side of it.
%
%     NON-FINITE VALUES ARE EXCLUDED, not treated as large. NaN is the
%     toolbox's gap convention, and a gap has no rank.
%
%   INPUTS
%     Z  double        Any size; treated as a flat collection.
%     p  (1,:) double  Percentages in [0, 100]. Any shape; the result
%                      follows it.
%
%   OUTPUTS
%     q  double  Same size as p. NaN if Z has no finite element.
%
%   ACCURACY
%     Exact by construction on the order statistics; the only arithmetic
%     is one linear interpolation. Asserted against closed-form values in
%     TestB2_fields, including the F10 regression geo.quantile([1 2], 50)
%     == 1.5 exactly.
%
%   ERRORS
%     Value validity:
%       geo:quantile:PercentOutOfRange - p outside [0, 100]
%
%   EXAMPLE
%     geo.quantile([1 2], 50)          % 1.5, where v1 gave 1
%     geo.quantile(Z, [2 98])          % robust colour limits
%
%   LIMITATIONS
%     Sorts the finite elements, so it is O(n log n) and allocates a copy.
%     For repeated calls on one array, ask for all the percentages at once
%     rather than calling per percentage.
%
%   See also GEO.SYMMETRICLIMITS, GEO.NICETICKS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    Z double
    p double {mustBeReal}
end

if any(p(:) < 0 | p(:) > 100)
    error('geo:quantile:PercentOutOfRange', ...
        'Percentages must lie in [0, 100]; got %g to %g.', ...
        min(p(:)), max(p(:)));
end

% BOTH SIDES FORCED TO COLUMNS, AND THE SHAPE RESTORED AT THE END.
% Written without the (:), this promised "Z any size, treated as a flat
% collection" and delivered it only for the shapes its own callers
% happened to use. Z(isfinite(Z)) is a COLUMN whenever Z is a matrix or
% a column vector, and indexing a column with a row index returns a
% column - so v(lo) came out (2,1) while (h - lo) was (1,2), implicit
% expansion silently built a 2x2, and RESHAPE then failed with "number
% of elements must not change". geo.quantile(Z(:), [5 95]) - a matrix
% and two percentages, which is the documented use - could not be
% called at all (PV-119). It never showed because every existing caller
% passes a scalar p, where the expansion is 1x1 and invisible.
v = sort(Z(isfinite(Z)));
v = v(:);
if isempty(v)
    q = nan(size(p));
    return
end

n = numel(v);
h = (n - 1) * p(:) / 100 + 1;       % type 7, as a column
lo = floor(h);
hi = ceil(h);
lo = min(max(lo, 1), n);
hi = min(max(hi, 1), n);
q = v(lo) + (h - lo) .* (v(hi) - v(lo));
q = reshape(q, size(p));
end
