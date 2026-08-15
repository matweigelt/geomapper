function mustBeSeries(v, what, errId)
%GEO.INTERNAL.MUSTBESERIES  A coordinate series: vector, real, NaN allowed.
%
%   SYNTAX
%     GEO.INTERNAL.MUSTBESERIES(V, WHAT, ERRID)
%
%   DESCRIPTION
%     The shared validator for track and point-set coordinates. Unlike a
%     grid AXIS, a series may contain NaN - that is the gap convention -
%     and need not be monotone. What it may not be is a matrix, a
%     complex array, or a string somebody meant as a label.
%
%     WHY THE CALLER PASSES THE WHOLE IDENTIFIER, not a prefix this
%     function completes. The caller's own name has to appear in the
%     identifier - that is the function the user called and the one whose
%     help documents the error - but the FIRST version of this helper
%     composed it here, as [prefix ':NotAVector'].
%
%     That was wrong for a reason worth keeping. A composed identifier
%     exists nowhere in the source as a literal, so no static reader can
%     find it: the project's own audit reported geo:points:NotAVector as
%     "documented but never raised", which is exactly what a lying help
%     block looks like. The identifier was raised; it was merely
%     invisible. Writing it out in full at the call site makes the help,
%     the code and the audit agree, and it costs one argument.
%
%     Generalises decision D-011: a value assembled out of sight is not a
%     documented contract.
%
%   INPUTS
%     v       any          Candidate series.
%     what    (1,1) string Name to quote in the message, e.g. "lon".
%     errId   (1,:) char   The COMPLETE identifier to raise, written out
%                          at the call site, e.g. 'geo:track:NotAVector'.
%
%   OUTPUTS
%     (none; throws or returns silently)
%
%   ACCURACY
%     No numerical claim. Behavioural criterion in TestA2_structs: a row,
%     a column and an empty pass; a matrix and a complex vector are each
%     rejected with the caller's own identifier.
%
%   ERRORS
%     This function raises whatever identifier its caller supplies, and
%     therefore documents none of its own. The identifiers it can produce
%     are documented on the public functions that pass them in, which is
%     where a user will look for them.
%
%   EXAMPLE
%     geo.internal.mustBeSeries(lon, "lon", 'geo:track:NotAVector');
%
%   LIMITATIONS
%     Says nothing about range. A longitude of 4000 is a legitimate input
%     here and becomes meaningful only once geo.wrapLongitude has seen it,
%     so rejecting it at construction would forbid a normal workflow.
%
%   See also GEO.TRACK, GEO.POINTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    v
    what (1,1) string
    errId (1,:) char
end

if isempty(v)
    return          % an empty series is a legitimate degenerate case
end
if ~isnumeric(v) || ~isreal(v) || ~isvector(v)
    error(errId, ...
        ['%s must be a real numeric vector. NaN is allowed and means a ' ...
         'gap; a matrix is not, because a series has one index.'], what);
end
end
