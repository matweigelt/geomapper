function n = countGaps(v)
%GEO.INTERNAL.COUNTGAPS  Count NaN RUNS, not NaN elements.
%
%   SYNTAX
%     N = GEO.INTERNAL.COUNTGAPS(V)
%
%   DESCRIPTION
%     Returns the number of maximal runs of NaN in V.
%
%     WHY RUNS AND NOT ELEMENTS. The question a track's gap count answers
%     is "how many times did this break", and a six-hour outage sampled
%     once a minute is one break, not 360. A count of elements would be
%     largest exactly where it is least informative - on the finest
%     sampling - and would make two recordings of the same outage report
%     different numbers of gaps.
%
%   INPUTS
%     v  (:,1) or (1,:) double  Series, possibly containing NaN.
%
%   OUTPUTS
%     n  (1,1) double  Number of NaN runs. Zero for a series with none.
%
%   ACCURACY
%     Exact by construction: a run starts wherever a NaN follows a
%     non-NaN or begins the series, which is a count of rising edges.
%
%   ERRORS
%     (none raised; a non-vector cannot reach here, the callers validate)
%
%   EXAMPLE
%     geo.internal.countGaps([1 NaN NaN 4 NaN 6])   % 2
%
%   LIMITATIONS
%     Leading and trailing NaN runs are counted like any other. Whether a
%     track that begins with missing data has a "gap" at its start is a
%     question of interpretation, and this function takes the literal
%     reading rather than guessing at intent.
%
%   See also GEO.TRACK, GEO.SPLITTRACKS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    v double
end

if isempty(v)
    n = 0;
    return
end
isGap = isnan(v(:)).';
% A run starts at a NaN whose predecessor is not one; the leading element
% counts as a start if it is itself a NaN.
n = sum(isGap & [true, ~isGap(1:end-1)]);
end
