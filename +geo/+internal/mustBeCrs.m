function mustBeCrs(c)
%GEO.INTERNAL.MUSTBECRS  Validator every downstream arguments block uses.
%
%   SYNTAX
%     GEO.INTERNAL.MUSTBECRS(C)
%
%   DESCRIPTION
%     Throws unless C is a scalar struct built by GEO.CRS. Every public
%     function that takes a CRS declares it as
%
%         crs (1,1) struct {geo.internal.mustBeCrs}
%
%     so the rejection happens in the arguments block, before the body,
%     and every function rejects a bad CRS the same way with the same
%     message.
%
%     WHY AN IDENTITY FIELD RATHER THAN DUCK TYPING. Checking for the
%     presence of a few likely fields would accept a struct that happens
%     to have them - including, in this toolbox, a half-built one from a
%     caller's own code. The handover's metadata rule asks the question
%     directly: if two objects from different sources were combined by
%     mistake, would anything notice? An Identity field is what makes the
%     answer yes.
%
%     WHY IT CHECKS THE FIELDS TOO. Identity alone would pass a struct
%     from a future version with a renamed field, and the failure would
%     then surface deep inside a projection kernel as a missing-field
%     error with no context. Checking the field set here turns that into
%     one clear message at the boundary.
%
%   INPUTS
%     c  (1,1) struct  Candidate CRS.
%
%   OUTPUTS
%     (none; throws or returns silently)
%
%   ACCURACY
%     No numerical claim. Its criterion is behavioural and is asserted in
%     TestA1_crs: a struct from GEO.CRS passes, and a plain struct, an
%     array of CRS structs and a struct with the Identity field alone all
%     fail with the documented identifier.
%
%   ERRORS
%     Identity:
%       geo:crs:NotACrs  - not a scalar struct from GEO.CRS, or missing
%                          fields GEO.CRS guarantees
%
%   EXAMPLE
%     function y = f(crs)
%     arguments
%         crs (1,1) struct {geo.internal.mustBeCrs}
%     end
%
%   LIMITATIONS
%     It cannot detect a struct whose fields were edited by hand after
%     construction - the value struct decision (D-002) buys save/load
%     simplicity and array-idiomatic use at exactly that price, and the
%     price is recorded here rather than implied.
%
%   See also GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

required = ["Identity" "Name" "CenterLongitude" "CenterLatitude" ...
            "Hemisphere" "StandardParallel" "StandardParallel2" ...
            "Radius" "ConeConstant" "Class" "IsWholeWorld" "Domain"];

ok = isstruct(c) && isscalar(c) && isfield(c, 'Identity') && ...
     isscalar(string(c.Identity)) && string(c.Identity) == "geo.crs";
if ok
    missingFields = setdiff(required, string(fieldnames(c)));
    ok = isempty(missingFields);
else
    missingFields = required;
end

if ~ok
    error('geo:crs:NotACrs', ...
        ['Expected a scalar struct built by geo.crs. Build one with ' ...
         'geo.crs("<projection>", ...) rather than assembling the ' ...
         'fields by hand; missing or unrecognised: %s.'], ...
        strjoin(missingFields, ', '));
end
end
