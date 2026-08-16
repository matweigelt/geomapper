function v1_option_resolution()
%V1_OPTION_RESOLUTION  Resolve v1 option names against v2's real options.
%
%   SYNTAX
%     V1_OPTION_RESOLUTION()
%
%   DESCRIPTION
%     Proposes a v2 destination for every v1 option that reaches
%     geoImagesc, and then CHECKS each proposal against the target
%     function's actual arguments block. A proposal that does not resolve
%     to an option that exists is printed as UNRESOLVED.
%
%     WHY THIS IS AN INSTRUMENT AND NOT A TABLE. The Stage 0 inventory
%     states its own rule: "an option no rule matched is unmapped, never
%     guessed - a plausible guess here would be indistinguishable from an
%     answer". A hand-written mapping table cannot enforce that, because
%     nothing checks that the destination it names exists. This reads the
%     arguments blocks and can only agree with reality.
%
%     First pass over the 114 options reaching geoImagesc: 54 resolve
%     mechanically, 60 do not. The 60 are four classes, and only the last
%     is a decision rather than a rule: on/off booleans that map to a
%     geo.map option itself; prefix gaps needing more strip rules;
%     COLLAPSED PAIRS, where two v1 options became one v2 option and the
%     translator must MERGE rather than rename; and options with no v2
%     equivalent at all.
%
%   INPUTS
%     (none)
%
%   OUTPUTS
%     (none; prints a table and a count to the command window)
%
%   ACCURACY
%     Exact: a name either appears in the target's arguments block or it
%     does not. There is no tolerance and no oracle - the source is the
%     authority on its own option names.
%
%   ERRORS
%     (none raised; unresolved names are reported, not thrown)
%
%   EXAMPLE
%     v1_option_resolution
%
%   LIMITATIONS
%     It reads arguments blocks as text, so an option introduced by any
%     other mechanism is invisible to it. It proposes; it does not
%     decide. Nothing here writes a mapping anywhere.
%
%   See also V1_OPTION_INVENTORY, GEO.MAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

root = geoMapRoot();
addpath(root, fullfile(root,'tests'), fullfile(root,'tools'), fullfile(root,'records'));

% --- v1 names that reach geoImagesc, with their inventory destination
[names, dest] = inventory(fullfile(root, 'records', 'v1_option_inventory.md'));

% --- geo.map option -> the function whose options it forwards
owner = dictionary( ...
    "Basemap",    "geo.basemap", ...
    "Graticule",  "geo.graticule", ...
    "Coastline",  "geo.coastline", ...
    "Rivers",     "geo.coastline", ...
    "Contours",   "geo.overlayContours", ...
    "Points",     "geo.overlayPoints", ...
    "Frame",      "geo.frame", ...
    "Colorbar",   "geo.colorbar", ...
    "ScaleBar",   "geo.scalebar", ...
    "NorthArrow", "geo.northarrow", ...
    "Inset",      "geo.inset", ...
    "Title",      "geo.title", ...
    "Stipple",    "geo.stipple", ...
    "Track",      "geo.overlayTrack", ...
    "Polygons",   "geo.overlayPolygons");

% inventory destination -> geo.map option
target = dictionary( ...
    "geo.basemap","Basemap", "geo.graticule","Graticule", ...
    "geo.coastline","Coastline", "geo.colorbar","Colorbar", ...
    "geo.frame","Frame", "geo.scalebar","ScaleBar", ...
    "geo.northarrow","NorthArrow", "geo.inset","Inset", ...
    "geo.overlayContours","Contours", "geo.overlayPoints","Points", ...
    "geo.hillshade","Basemap", "geo.crs","CRS", "geo.export","Export", ...
    "geo.readGrid","ReadGrid", "geo.region","Region", "geo.map","Map");

opts = dictionary(string.empty, cell.empty);
for f = unique(owner.values')
    opts(f) = {argNames(fullfile(root, "+geo", erase(f,"geo.") + ".m"))};
end
opts("geo.crs") = {argNames(fullfile(root,"+geo","crs.m"))};
opts("geo.export") = {argNames(fullfile(root,"+geo","export.m"))};

% --- prefixes to strip, longest first so Coastlines beats Coast
prefix = ["MapInset" "NorthArrow" "ScaleBar" "Colorbar" "Graticule" ...
          "Coastline" "Coastlines" "Contour" "River" "Rivers" "Frame" ...
          "Point" "Points" "AreaOfInterest" "Topography" "Export" ...
          "Longitude" "Latitude" "Light" "Mask" "CLim"];

fprintf('%-28s %-14s %-22s %s\n','v1 option','geo.map','proposed','status');
fprintf('%s\n', repmat('-',1,86));
nOk = 0; unresolved = strings(0,1);
for i = 1:numel(names)
    d = dest(i);
    if ~isKey(target, d)
        fprintf('%-28s %-14s %-22s %s\n', names(i), "-", "-", 'DROPPED in inventory');
        continue
    end
    t = target(d);
    if any(t == ["CRS" "Export" "ReadGrid" "Map" "Region"])
        fprintf('%-28s %-14s %-22s %s\n', names(i), t, "(front-level)", 'special');
        continue
    end
    cand = candidates(names(i), t, prefix);
    have = opts{owner(t)};
    hit = cand(ismember(cand, have));
    if isempty(hit)
        fprintf('%-28s %-14s %-22s %s\n', names(i), t, strjoin(cand,'|'), 'UNRESOLVED');
        unresolved(end+1,1) = names(i); %#ok<AGROW>
    else
        fprintf('%-28s %-14s %-22s %s\n', names(i), t, hit(1), 'ok');
        nOk = nOk + 1;
    end
end
fprintf('\n%d resolved, %d unresolved\n', nOk, numel(unresolved));
if ~isempty(unresolved)
    fprintf('UNRESOLVED: %s\n', strjoin(unresolved', ', '));
end
end

% ======================================================================
function c = candidates(name, t, prefix)
c = name;
for p = prefix
    if startsWith(name, p) && strlength(name) > strlength(p)
        c(end+1) = extractAfter(name, strlength(p)); %#ok<AGROW>
    end
end
c(end+1) = name;
% common suffix synonyms
if endsWith(name, "Width"), c(end+1) = "LineWidth"; end
if endsWith(name, "Thickness"), c(end+1) = "Thickness"; end
if endsWith(name, "Color"), c(end+1) = "Color"; end
c = unique(c, 'stable');
end

function a = argNames(file)
txt = string(splitlines(fileread(file)));
i = find(strtrim(txt) == "arguments", 1);
j = find(strtrim(txt) == "end" & (1:numel(txt))' > i, 1);
a = string(regexp(strjoin(txt(i:j), newline), 'options\.([A-Za-z]\w*)', 'tokens'));
a = unique(a);
end

function [names, dest] = inventory(file)
txt = string(splitlines(fileread(file)));
names = strings(0,1); dest = strings(0,1);
for k = 1:numel(txt)
    m = regexp(txt(k), '^\|\s*`([^`]+)`\s*\|([^|]*)\|\s*`?([^|`]*)`?\s*\|', 'tokens', 'once');
    if isempty(m), continue, end
    fronts = m(2);
    if ~contains(fronts, "geoImagesc"), continue, end
    if ~(contains(fronts,"geoImagesc,") || strtrim(fronts)=="geoImagesc" || startsWith(strtrim(fronts),"geoImagesc"))
        continue
    end
    names(end+1,1) = m(1);  %#ok<AGROW>
    dest(end+1,1) = strtrim(m(3)); %#ok<AGROW>
end
end
