function nv = v1Options(args)
%GEO.INTERNAL.V1OPTIONS  Translate v1 geoImagesc options into geo.map's.
%
%   SYNTAX
%     nv = GEO.INTERNAL.V1OPTIONS(ARGS)
%
%   DESCRIPTION
%     Takes a name-value list in v1's spelling and returns one in v2's,
%     ready to pass to GEO.MAP. Discharges handover debt V9.
%
%     WHAT IT IS NOT: a rename table. Three of the six kinds in
%     GEO.INTERNAL.V1OPTIONTABLE cannot be expressed as substitutions,
%     and each one is a real shape of the migration.
%
%       COLLAPSED PAIRS. NorthArrowColor1 and NorthArrowColor2 are rows
%       1 and 2 of one Colors matrix. Two inputs, one output - so this
%       ACCUMULATES, and giving only one of the pair leaves the other
%       row at its default rather than at zero.
%
%       SCATTERED OPTIONS BECOMING ONE VALUE. v1's six loose projection
%       settings had to agree with each other and were checked nowhere;
%       they are gathered here into a single GEO.CRS, which validates
%       them together.
%
%       NO EQUIVALENT. Twenty-eight of the 120 have none, and every one
%       of them RAISES with the replacement named. That is the point: a
%       v1 script that used FigureSize gets told that a size in pixels
%       does not describe a page and that geo.export takes centimetres -
%       not "unrecognised argument", and not silence.
%
%     AN UNKNOWN NAME IS PASSED THROUGH, not rejected. v2's own option
%     names are not in the table and must survive, so the two spellings
%     can be mixed while a script is being migrated a line at a time.
%     GEO.MAP's own arguments block is what rejects a genuine typo, and
%     it has the better error for it.
%
%   INPUTS
%     args  (1,:) cell  Name-value pairs in v1's spelling, v2's, or both.
%
%   OUTPUTS
%     nv  (1,:) cell  Name-value pairs for GEO.MAP.
%
%   ACCURACY
%     Exact. Every value is carried across unchanged; only names move.
%     The one exception is Illuminate, a logical that becomes
%     GEO.BASEMAP's Hillshade string, and it is the only value this
%     function rewrites.
%
%   ERRORS
%     geo:v1Options:NoEquivalent - a v1 option with no v2 counterpart,
%                                  raised with the replacement named
%     geo:v1Options:OddArguments - an unpaired name-value list
%
%   EXAMPLE
%     nv = geo.internal.v1Options({'GraticuleColor', [0 0 0], ...
%                                  'ShowColorbar', false});
%     H  = geo.map(G, crs, nv{:});
%
%   LIMITATIONS
%     geoImagesc only; the other four v1 fronts translate when their v2
%     counterparts exist. It does not check VALUES, so a v1 option whose
%     accepted values changed is caught by the element, not here.
%
%   See also GEO.INTERNAL.V1OPTIONTABLE, GEO.MAP, GEO.V1.IMAGESC.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    args (1,:) cell
end

if mod(numel(args), 2) ~= 0
    error('geo:v1Options:OddArguments', ...
        ['%d arguments is not a name-value list. Every option needs a ' ...
         'value.'], numel(args));
end

T = geo.internal.v1OptionTable();
known = [T.V1];

out = struct();          % geo.map's own options
elem = struct();         % per-element option structs
crsArgs = struct();
crsName = "";
exportArgs = struct();
% Collected as one cell per pair and flattened once: how many names are
% v2-native is not known until the list has been walked (F13).
kept = cell(1, 0);

for k = 1:2:numel(args)
    name = string(args{k});
    value = args{k + 1};
    hit = find(known == name, 1);
    if isempty(hit)
        kept{end + 1} = {char(name), value};
        continue
    end
    row = T(hit);
    switch row.Kind
        case "none"
            error('geo:v1Options:NoEquivalent', ...
                '%s has no v2 equivalent: %s', name, row.Note);
        case "crs"
            if row.Option == "name"
                crsName = string(value);
            else
                crsArgs.(row.Option) = value;
            end
        case "map"
            out.(row.Option) = value;
        case "export"
            exportArgs.(row.Option) = value;
        case "toggle"
            elem = setToggle(elem, row, value);
        case {"opt", "data"}
            elem = setField(elem, row.Target, row.Option, value);
        case "merge"
            elem = setColorRow(elem, row, value);
    end
end

nv = assemble(out, elem, crsName, crsArgs, exportArgs, [kept{:}]);
end

% ======================================================================
function elem = setToggle(elem, row, value)
%SETTOGGLE  A v1 logical that switches a v2 element on or off.
%   Illuminate is the one toggle whose VALUE changes: geo.basemap takes
%   a Hillshade string rather than a flag, because "single" and "multi"
%   are different algorithms and a logical cannot say which.
if row.Option == "Hillshade"
    elem = setField(elem, row.Target, "Hillshade", ternary(value, "single", "off"));
    return
end
% A STRUCT IS ALREADY v2 SPELLING, so pass it through. Nine v1 names -
% Graticule, Rivers, Points, NorthArrow, ScaleBar, Title, Parent,
% FontName, FontSize - are ALSO geo.map option names, which is not an
% accident: v1 got those spellings right and v2 kept them. But it means
% a translated list contains names this table still recognises, and
% Graticule = struct(StepLon = 60) came back through as a toggle and was
% asked to evaluate a struct as a logical. Translating twice must change
% nothing; that is asserted, and this is what makes it true.
if isstruct(value)
    elem.(row.Target) = value;
    return
end
if isfield(elem, row.Target) && isstruct(elem.(row.Target)) && value
    return          % already configured; a redundant "on" changes nothing
end
if value
    elem.(row.Target) = true;
else
    elem.(row.Target) = false;
end
end

function elem = setField(elem, target, option, value)
%SETFIELD  One element option, without discarding the others.
%   A struct assignment here would silently drop every option set
%   before it, which is exactly the failure this whole layer exists to
%   avoid, so the struct is grown rather than replaced.
if ~isfield(elem, target) || ~isstruct(elem.(target))
    elem.(target) = struct();
end
elem.(target).(option) = value;
end

function elem = setColorRow(elem, row, value)
%SETCOLORROW  Two v1 options, one v2 matrix.
%   The row this option owns is written and the other is left at the
%   element's own default, so setting one colour does not blank the
%   other - which a rename would have done.
which = double(extractAfter(row.Note, "row "));
if ~isfield(elem, row.Target) || ~isstruct(elem.(row.Target)) || ...
        ~isfield(elem.(row.Target), row.Option)
    elem = setField(elem, row.Target, row.Option, defaultColors(row.Target));
end
c = elem.(row.Target).(row.Option);
c(which, :) = value(:).';
elem.(row.Target).(row.Option) = c;
end

function c = defaultColors(target)
%DEFAULTCOLORS  The element's own default, so an untouched row keeps it.
switch target
    case "NorthArrow", c = [1 1 1; 0 0 0];
    otherwise,         c = [0 0 0; 1 1 1];
end
end

function nv = assemble(out, elem, crsName, crsArgs, exportArgs, passthrough)
%ASSEMBLE  One name-value list, with the crs built last.
if strlength(crsName) > 0 || ~isempty(fieldnames(crsArgs))
    if strlength(crsName) == 0
        crsName = "equirectangular";
    end
    ca = namedargs2cell(crsArgs);
    out.CRS = geo.crs(crsName, ca{:});
end
if ~isempty(fieldnames(exportArgs))
    out.ExportOptions = exportArgs;
end
for f = string(fieldnames(elem))'
    out.(f) = elem.(f);
end
nv = [namedargs2cell(out), passthrough];
end

function v = ternary(tf, a, b)
if tf, v = a; else, v = b; end
end
