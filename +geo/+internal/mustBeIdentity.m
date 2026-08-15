function mustBeIdentity(s, want, errId)
%GEO.INTERNAL.MUSTBEIDENTITY  Assert a struct is the kind it claims to be.
%
%   SYNTAX
%     GEO.INTERNAL.MUSTBEIDENTITY(S, WANT, ERRID)
%
%   DESCRIPTION
%     Every L0 value struct carries an Identity field naming what built
%     it, and every idempotent constructor checks that field before
%     passing a struct through untouched. This is the one implementation
%     of that check.
%
%     WHY THE CALLER PASSES THE IDENTIFIER. A caller who hands a track to
%     GEO.GRID should read "geo:grid:NotAGrid", not an identifier naming
%     an internal helper they never called. The first version derived it
%     here with a SWITCH on WANT - and the project's audit then reported
%     all four identifiers as documented-but-never-raised, because none
%     of them appears in the source as a literal. The audit was right:
%     an identifier assembled out of sight is not a documented contract.
%     It is written out at the call site instead.
%
%     THE TEST THE HANDOVER ASKS FOR. If two objects from different
%     sources were combined by mistake, would anything notice? Without an
%     identity field the answer is no: a track and a point set have
%     overlapping field names and would silently substitute for one
%     another until something drew wrongly.
%
%   INPUTS
%     s      (1,1) struct  Candidate.
%     want   (1,1) string  Expected Identity, e.g. "geo.grid".
%     errId  (1,:) char    The COMPLETE identifier to raise, written out
%                          at the call site, e.g. 'geo:grid:NotAGrid'.
%
%   OUTPUTS
%     (none; throws or returns silently)
%
%   ACCURACY
%     No numerical claim. Behavioural criterion asserted in TestA2_structs:
%     each constructor's idempotent path accepts its own kind and rejects
%     the other two with the identifier naming the function called.
%
%   ERRORS
%     This function raises whatever identifier its caller supplies, and
%     therefore documents none of its own. The identifiers it can produce
%     are documented on the public functions that pass them in.
%
%   EXAMPLE
%     geo.internal.mustBeIdentity(G, "geo.grid", 'geo:grid:NotAGrid');
%
%   LIMITATIONS
%     It checks the label, not the contents. A struct whose fields were
%     edited by hand after construction still carries a valid Identity;
%     that is the price of the value-struct decision (D-002) and is
%     recorded rather than implied.
%
%   See also GEO.GRID, GEO.TRACK, GEO.POINTS, GEO.INTERNAL.MUSTBECRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    s
    want (1,1) string
    errId (1,:) char
end

ok = isstruct(s) && isscalar(s) && isfield(s, 'Identity') && ...
     isscalar(string(s.Identity)) && string(s.Identity) == want;
if ok
    return
end

got = "not a struct";
if isstruct(s) && ~isscalar(s)
    got = sprintf("a %d-element struct array", numel(s));
elseif isstruct(s) && isfield(s, 'Identity')
    got = """" + string(s.Identity) + """";
elseif isstruct(s)
    got = "a struct with no Identity field";
end

error(errId, ...
    ['Expected %s; got %s. These structs are not interchangeable even ' ...
     'where their fields overlap, which is exactly why each carries an ' ...
     'Identity.'], want, got);
end
