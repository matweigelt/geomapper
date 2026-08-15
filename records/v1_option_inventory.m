function T = v1_option_inventory(v1Root, outFile)
%V1_OPTION_INVENTORY  Every options. field in v1's five fronts, mapped.
%
%   SYNTAX
%     T = V1_OPTION_INVENTORY()
%     T = V1_OPTION_INVENTORY(V1ROOT, OUTFILE)
%
%   DESCRIPTION
%     Handover debt V9: Stage E promises v1's option names carry over 1:1
%     "wherever the feature survived", and nobody had enumerated them.
%     A promise about names, kept from memory, is how a rename ships.
%
%     This extracts every `options.<Name>` reference from the five front
%     functions and assigns each a v2 destination by an ORDERED RULE
%     TABLE, not by recollection. First match wins, so the table is read
%     top to bottom and the order is part of the rule - narrow families
%     (MapInset*, ScaleBar*) sit above the broad ones (Color*, *Label*)
%     they would otherwise be swallowed by.
%
%     WHAT THIS DELIBERATELY DOES NOT DO. It does not invent a v2 name for
%     an option whose destination does not exist yet. An unmatched option
%     is reported as `unmapped`, and the unmapped count is printed. That
%     is a visible debt Stage D and E must close; a plausible guess in its
%     place would be indistinguishable from an answer.
%
%   INPUTS
%     v1Root   (1,1) string  [auto]  Folder holding v1's .m files.
%     outFile  (1,1) string  [auto]  Markdown report path.
%
%   OUTPUTS
%     T  table  Columns: Option (string), Fronts (string, comma list),
%               Destination (string), Status (string: "carried" |
%               "renamed" | "dropped" | "unmapped"), Note (string).
%
%   ACCURACY
%     No oracle and no numerical claim. Its correctness criterion is
%     mechanical: the option list is derived from the source by regular
%     expression, so re-running it on the same tree gives the same list.
%     The MAPPING is a design judgement and is labelled as one - each row
%     carries the rule that placed it.
%
%   ERRORS
%     Input geometry:
%       geo:v1inventory:RootNotFound  - no v1 tree at the given path
%
%   EXAMPLE
%     T = v1_option_inventory();
%     disp(T(T.Status == "unmapped", :))
%
%   LIMITATIONS
%     It reads `options.<Name>` references, which includes names used in
%     the body but declared in the arguments block of a called function.
%     That over-collects rather than under-collects, which is the safe
%     direction for an inventory whose purpose is that nothing is missed.
%
%   See also V1_DEFECT_PROBES.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    v1Root (1,1) string = defaultV1Root()
    outFile (1,1) string = fullfile(geoMapRoot(), "records", ...
                                    "v1_option_inventory.md")
end

fronts = ["geoImagesc" "geoImagescTrack" "geoImagescPoints" ...
          "geoImagescTimeSeries" "geoImagescMulti"];
if ~isfile(fullfile(v1Root, fronts(1) + ".m"))
    error('geo:v1inventory:RootNotFound', ...
        'No v1 front functions under "%s".', v1Root);
end

% --- 1. Extract, mechanically ---------------------------------------
names = strings(0, 1);
owner = strings(0, 1);
for f = fronts
    t = string(fileread(fullfile(v1Root, f + ".m")));
    hits = unique(string(regexp(t, '(?<=options\.)[A-Za-z]\w*', 'match')));
    for h = hits(:)'
        j = find(names == h, 1);
        if isempty(j)
            names(end+1, 1) = h;          %#ok<AGROW>
            owner(end+1, 1) = f;          %#ok<AGROW>
        else
            owner(j) = owner(j) + ", " + f;
        end
    end
end
[names, ord] = sort(names);
owner = owner(ord);

% --- 2. Map ----------------------------------------------------------
rules = ruleTable();
dest = strings(size(names));
stat = strings(size(names));
note = strings(size(names));
for i = 1:numel(names)
    [dest(i), stat(i), note(i)] = applyRules(names(i), rules);
end

T = table(names, owner, dest, stat, note, ...
    VariableNames = ["Option" "Fronts" "Destination" "Status" "Note"]);

writeInventory(T, outFile, v1Root, fronts);
end

% ======================================================================
function rules = ruleTable()
%RULETABLE  Ordered. First match wins, and the order IS the rule.
%   Narrow families first. "MapInsetCoastlineColor" must reach the inset
%   rule before the coastline rule, or the inset's own styling would be
%   filed under an element it merely resembles.
r = @(pat, dst, st, nt) struct('pat', string(pat), 'dest', string(dst), ...
                               'stat', string(st), 'note', string(nt));
rules = [ ...
  r("^MapInset",        "geo.inset",            "carried", ...
    "the whole inset family folds into one element's options") ...
  r("^ScaleBar",        "geo.scalebar",         "carried", ...
    "D-006 changes the BEHAVIOUR, not the option names") ...
  r("^NorthArrow",      "geo.northarrow",       "carried", ...
    "F7: fifteen positional arguments become two plus name-values") ...
  r("^Colorbar|^ShowColorbar|^SharedColorbar", "geo.colorbar", "carried", ...
    "four v1 implementations merge behind Style=") ...
  r("^Graticule|Label(Edge|Offset|Rotation)$|^GridOn", ...
                        "geo.graticule",        "carried", ...
    "labels are placed by geo.unproject now, not by tangent heuristics") ...
  r("^Frame|^SegmentedFrame", "geo.frame",      "carried", "") ...
  r("^Contour",         "geo.overlayContours",  "carried", ...
    "LabelSpacing and dashed negatives are added, nothing removed") ...
  r("^AreaOfInterest|^ShowAreaOfInterestOutline", "geo.region", "renamed", ...
    "AreaOfInterest becomes Region=, accepting anything geo.region takes") ...
  r("^Coastline|^Rivers?$|^River",  "geo.coastline", "carried", ...
    "three near-identical v1 paths collapse into Kind=") ...
  r("^Track",           "geo.overlayTrack",     "carried", "") ...
  r("^Point|^Marker|^SizeData|^SizeRange|^SizeScale|^SizeLegend|^ShowSizeLegend|^ShowLegend|^LegendLocation", ...
                        "geo.overlayPoints",    "carried", "") ...
  r("^Mask|^NaNColor|^Colormap|^CLim|^DiscreteLevels|^Parent", ...
                        "geo.basemap",          "carried", "") ...
  r("^Illuminate$",     "geo.basemap",          "renamed", ...
    "becomes Hillshade=""single""|""multi""|""off""") ...
  r("^LightAzimuth$",   "geo.hillshade",        "renamed", "becomes Azimuth") ...
  r("^LightElevation$", "geo.hillshade",        "renamed", "becomes Elevation") ...
  r("^AmbientStrength$","geo.hillshade",        "renamed", "becomes Ambient") ...
  r("^VerticalExaggeration$", "geo.hillshade",  "renamed", "becomes ZFactor") ...
  r("^Material$|^SpecularStrength$", "-",       "dropped", ...
    "D-009: analytic Horn shading replaces OpenGL lighting, and these " + ...
    "two have no analytic counterpart. They configured a renderer, not " + ...
    "a model") ...
  r("^Projection$",     "geo.crs",              "dropped", ...
    "BREAKING and deliberate: the crs argument replaces it. Passing " + ...
    "'Projection' raises geo:map:ProjectionOption naming the " + ...
    "replacement") ...
  r("^CenterLongitude$|^CenterLatitude$|^Hemisphere$|^StandardParallel", ...
                        "geo.crs",              "renamed", ...
    "moves from a front option to a geo.crs construction option, same " + ...
    "spelling") ...
  r("^Topography|^DownsampleTopography$|^MaxGridSize$|^BackgroundResolution$|^ShowTopographyColor$", ...
                        "geo.readGrid",         "carried", ...
    "topography reading leaves geoImagesc's locals and becomes an L2 " + ...
    "function") ...
  r("^Export|^FigureSize$", "geo.export",       "carried", "") ...
  r("^LonLim$|^LatLim$|^MapPadding$", "geo.map", "carried", ...
    "extent resolution stays a front concern") ...
  r("^Layout$|^PanelLabels$|^LinkTimeAxes$|^LinkPointsToSeries$|^SharedCLim$|^Args$|^TimeSeriesArgs$", ...
                        "geo.panel",            "carried", "") ...
  r("^Offset|^ReferenceLines$|^ShowTrend$|^Uncertainty$|^DateFormat$|^GapThreshold$|^YLabel$", ...
                        "geo.timeseries",       "carried", ...
    "GapThreshold routes to geo.splitTracks' gap logic rather than a " + ...
    "second copy of it") ...
  r("^FontName$|^FontSize$|^LabelColor$|^Title$|^Style$|^Colors$|^LineWidth$|^Labels$|^BicolorColors$", ...
                        "geo.map",              "carried", ...
    "shared styling, forwarded by the front to whichever element owns it") ...
  ];
end

function [dest, stat, note] = applyRules(name, rules)
for k = 1:numel(rules)
    if ~isempty(regexp(name, rules(k).pat, 'once'))
        dest = rules(k).dest;
        stat = rules(k).stat;
        note = rules(k).note;
        return
    end
end
dest = "?";
stat = "unmapped";
note = "no rule matched. Stage D or E must place it or drop it with a " + ...
       "reason; it is NOT silently carried.";
end

% ======================================================================
function writeInventory(T, outFile, v1Root, fronts)
folder = fileparts(outFile);
if ~isfolder(folder), mkdir(folder), end
n = height(T);
nUn = sum(T.Status == "unmapped");
nDr = sum(T.Status == "dropped");
nRe = sum(T.Status == "renamed");

L = strings(0, 1);
L(end+1) = "# v1 option inventory";
L(end+1) = "";
L(end+1) = "*Generated by `records/v1_option_inventory.m` on " + ...
    string(datetime("now", Format = "d-MMM-uuuu HH:mm")) + ...
    " from `" + v1Root + "`.*";
L(end+1) = "";
L(end+1) = "**This file discharges handover debt V9.** Stage E promises " + ...
    "v1's option names carry over 1:1 wherever the feature survived. " + ...
    "**Stage E reads this table, not its recollection.**";
L(end+1) = "";
L(end+1) = sprintf("**%d options across %d fronts: %d carried, " + ...
    "%d renamed, %d dropped, %d unmapped.**", n, numel(fronts), ...
    sum(T.Status == "carried"), nRe, nDr, nUn);
L(end+1) = "";
L(end+1) = "The mapping comes from an ordered rule table in the " + ...
    "generating script; first match wins, and narrow families sit above " + ...
    "the broad ones that would otherwise swallow them. An option no " + ...
    "rule matched is **unmapped**, never guessed: a plausible guess " + ...
    "here would be indistinguishable from an answer.";
L(end+1) = "";
L(end+1) = "| Option | v1 fronts | v2 destination | Status | Note |";
L(end+1) = "|---|---|---|---|---|";
for i = 1:n
    L(end+1) = "| `" + T.Option(i) + "` | " + T.Fronts(i) + " | `" + ...
        T.Destination(i) + "` | " + statusMark(T.Status(i)) + " | " + ...
        T.Note(i) + " |"; %#ok<AGROW>
end
L(end+1) = "";
L(end+1) = "---";
L(end+1) = "";
L(end+1) = "*geoMap v2.0 | " + ...
    string(datetime("now", Format = "d-MMM-uuuu")) + ...
    " | Claude Opus 5 (Anthropic)*";

fid = fopen(outFile, "w");
c = onCleanup(@() fclose(fid));
fwrite(fid, char(join(L, newline)));
fprintf('v1 options: %d total, %d unmapped -> %s\n', n, nUn, outFile);
end

function s = statusMark(st)
switch st
    case "dropped",  s = "**dropped**";
    case "unmapped", s = "**UNMAPPED**";
    case "renamed",  s = "*renamed*";
    otherwise,       s = "carried";
end
end

function p = defaultV1Root()
cands = ["C:\Users\matth\Documents\MATLAB\maptoolbox_v1\maptoolbox"
         "C:\Users\matth\Documents\MATLAB\maptoolbox"];
p = cands(1);
for c = cands(:)'
    if isfile(fullfile(c, "geoImagesc.m"))
        p = c;
        return
    end
end
end
