function [own, rest] = splitOptions(nv, names)
%GEO.INTERNAL.SPLITOPTIONS  Take the options that are mine, forward the rest.
%
%   SYNTAX
%     [own, rest] = GEO.INTERNAL.SPLITOPTIONS(NV, NAMES)
%
%   DESCRIPTION
%     Splits a name-value list into a struct of the options this
%     function owns and a cell array of everything else, ready to
%     forward unchanged.
%
%     WHY A FRONT FORWARDS RATHER THAN RESTATES. GEO.TRACKMAP and
%     GEO.POINTMAP are GEO.MAP plus an extent and a background. If each
%     restated GEO.MAP's option surface in its own arguments block, the
%     three would drift - and that is not a hypothetical, it is F8's
%     sibling: v1's geoImagescTrack and geoImagescPoints are 75 and 82
%     option near-clones of geoImagesc, which is how one fix came to
%     need applying in three places. Here the surface has one home and
%     the fronts pass what they do not recognise straight through, so
%     GEO.MAP's own arguments block is what validates it - and it has
%     the better error, because it knows the whole list.
%
%     THE COST IS HONEST AND STATED: a front's own options are not
%     validated by an arguments block, so they are validated here and
%     asserted under `contract`. An unknown name is not this function's
%     to reject; it belongs to whoever receives REST.
%
%   INPUTS
%     nv     (1,:) cell    Name-value pairs.
%     names  (1,:) string  The option names this caller owns.
%
%   OUTPUTS
%     own   (1,1) struct  Only the owned names that were actually given,
%                         so ISFIELD distinguishes "not set" from "set
%                         to the default" - which a defaulted struct
%                         cannot.
%     rest  (1,:) cell    Everything else, in the order given.
%
%   ACCURACY
%     Exact: values are carried across untouched. Only the partition is
%     computed, and it is by name equality.
%
%   ERRORS
%     geo:splitOptions:OddArguments - an unpaired name-value list
%
%   EXAMPLE
%     [own, rest] = geo.internal.splitOptions(varargin, ["Pad" "Region"]);
%
%   LIMITATIONS
%     Name matching is case-sensitive, as MATLAB's own name-value
%     matching is not. A caller writing "pad" gets it forwarded rather
%     than owned, and GEO.MAP then rejects it - which is a worse message
%     than this could give but a better one than silently accepting a
%     spelling the documentation does not use.
%
%   See also GEO.TRACKMAP, GEO.POINTMAP, GEO.MAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    nv (1,:) cell
    names (1,:) string
end

if mod(numel(nv), 2) ~= 0
    error('geo:splitOptions:OddArguments', ...
        ['%d arguments is not a name-value list. Every option needs a ' ...
         'value.'], numel(nv));
end

own = struct();
% Collected per pair and flattened once: how many are forwarded is not
% known until the list has been walked (F13).
kept = cell(1, 0);
for k = 1:2:numel(nv)
    name = string(nv{k});
    if any(names == name)
        own.(name) = nv{k + 1};
    else
        kept{end + 1} = {nv{k}, nv{k + 1}};
    end
end
rest = [kept{:}];
end
