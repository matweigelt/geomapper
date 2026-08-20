function nv = withData(nv, option, defaults)
%GEO.INTERNAL.WITHDATA  Put the front's data into an element's own struct.
%
%   SYNTAX
%     nv = GEO.INTERNAL.WITHDATA(NV, OPTION, FIELD, VALUE)
%
%   DESCRIPTION
%     GEO.TRACKMAP is given a track and forwards the rest of its options
%     to GEO.MAP, which expects that track inside Track.T. If the caller
%     also wrote Track = struct(Style = "bicolor"), both have to end up
%     in the same struct.
%
%     WHY IT MERGES RATHER THAN SETS. Assigning Track = struct(T = ...)
%     would silently discard the caller's Style, and the caller would
%     see a map drawn in the default style with no error and no clue -
%     the exact shape of failure that a front, standing between the user
%     and the elements, is most able to cause and least able to notice.
%     The data is written into whatever struct arrived; every other
%     field survives.
%
%     THE CALLER'S OWN DATA WINS if they supplied it. Someone who wrote
%     Track = struct(T = other) meant that track, and the front's
%     positional argument is then redundant rather than authoritative.
%     Silently overruling an explicit field would be the same defect in
%     the other direction.
%
%   INPUTS
%     nv        (1,:) cell    Name-value pairs bound for GEO.MAP.
%     option    (1,1) string  The GEO.MAP option, e.g. "Track".
%     defaults  (1,1) struct  Fields to supply where the caller gave
%                             none. A struct rather than a name and a
%                             value because D-003 caps positional arity
%                             at three, and because a front may need to
%                             supply more than one field.
%
%   OUTPUTS
%     nv  (1,:) cell  The same list, with the defaults merged in.
%
%   ACCURACY
%     Exact: only absent fields are written, and nothing else is read or
%     changed.
%
%   ERRORS
%     (none raised)
%
%   EXAMPLE
%     rest = geo.internal.withData(rest, "Track", struct('T', T));
%
%   LIMITATIONS
%     If the option was given as a logical - Track = false - the data is
%     still merged and the element draws, because the front was called
%     to draw it. Switching off the very thing GEO.TRACKMAP exists to
%     show is better served by GEO.MAP.
%
%   See also GEO.TRACKMAP, GEO.POINTMAP, GEO.MAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    nv (1,:) cell
    option (1,1) string
    defaults (1,1) struct
end

idx = find(string(nv(1:2:end)) == option, 1);
if isempty(idx)
    nv = [nv, {char(option)}, {defaults}];
    return
end
at = 2 * idx;
s = nv{at};
if ~isstruct(s)
    s = struct();
end
for f = string(fieldnames(defaults))'
    if ~isfield(s, f)
        s.(f) = defaults.(f);
    end
end
nv{at} = s;
end
