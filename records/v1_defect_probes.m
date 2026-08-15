function results = v1_defect_probes(v1Root, outFile)
%V1_DEFECT_PROBES  Measure whether v1's defects F1-F18 are real.
%
%   SYNTAX
%     results = V1_DEFECT_PROBES()
%     results = V1_DEFECT_PROBES(V1ROOT)
%     results = V1_DEFECT_PROBES(V1ROOT, OUTFILE)
%
%   DESCRIPTION
%     Handover debt V4 says the v1 defect list is a READING, not a
%     measurement: v1 was never executed during the review. The whole v2
%     design rests on those eighteen findings, and a design justified by a
%     defect that does not exist is a design without a reason.
%
%     This runs one probe per row of handover Part 5 against the installed
%     v1 tree and writes the verdicts to records/v1_probe_results.md.
%
%     A row that fails to reproduce is REPORTED FOR DELETION from the
%     design rationale. It is not quietly kept, and it is not quietly
%     dropped either - both hide the same thing, which is that the
%     rationale was never checked.
%
%     Probes come in three kinds, and the kind is recorded with each
%     verdict because they are not equally strong:
%       executed    v1 code ran and returned a number. The strongest.
%       counted     the source was counted or searched. A measurement of
%                   the text, which is what F1, F6, F7, F8, F11-F15 and
%                   F18 actually claim.
%       blocked     the probe needs something absent. Reported as blocked,
%                   never as passed.
%
%   INPUTS
%     v1Root   (1,1) string  [auto]  Folder holding v1's .m files. The
%                                    default searches the usual places and
%                                    errors rather than guessing.
%     outFile  (1,1) string  [auto]  Markdown report path.
%
%   OUTPUTS
%     results  (1,:) struct  Fields: id (1,1) string, claim (1,1) string,
%                            kind (1,1) string, verdict (1,1) string
%                            ("reproduced" | "refuted" | "blocked"),
%                            evidence (1,1) string.
%
%   ACCURACY
%     Oracle O12 (v1 itself), and O12 only. v1 is NOT an authority on
%     correctness - it is the thing being replaced. It is an authority on
%     exactly one question: what does v1 do. Every expected value here is
%     therefore either analytic or derived in this file, never taken from
%     v1's own output.
%
%   ERRORS
%     Input geometry:
%       geo:v1probes:RootNotFound  - no v1 tree at the given or default path
%       geo:v1probes:NotV1         - the folder has no geoProject.m
%
%   EXAMPLE
%     r = v1_defect_probes("C:\Users\matth\Documents\MATLAB\maptoolbox_v1");
%
%   LIMITATIONS
%     A "counted" verdict measures the source text, not the behaviour it
%     implies. F9 is the clearest case: the co-occurrence of light,
%     shading interp and FaceAlpha on one surface is countable, but that
%     this PRODUCES renderer-dependent output is still an inference. The
%     verdict says so rather than borrowing the strength of the executed
%     probes around it.
%
%   See also GEOMAPAUDIT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    v1Root (1,1) string = defaultV1Root()
    outFile (1,1) string = fullfile(geoMapRoot(), "records", ...
                                    "v1_probe_results.md")
end

if ~isfolder(v1Root)
    error('geo:v1probes:RootNotFound', ...
        ['No v1 tree at "%s". OB-7 requires v1 to stay installed and ' ...
         'runnable until Stage F so these probes stay reproducible.'], ...
        v1Root);
end
if ~isfile(fullfile(v1Root, "geoProject.m"))
    error('geo:v1probes:NotV1', ...
        '"%s" has no geoProject.m, so it is not the v1 tree.', v1Root);
end

old = path();
restorePath = onCleanup(@() path(old));
addpath(v1Root);

results = [ ...
    probeF1(v1Root), probeF2(), probeF3(), probeF4(), probeF5(v1Root), ...
    probeF6(v1Root), probeF7(v1Root), probeF8(v1Root), probeF9(v1Root), ...
    probeF10(), probeF11(v1Root), probeF12(v1Root), probeF13(v1Root), ...
    probeF14(v1Root), probeF15(v1Root), probeF16(), probeF17(), ...
    probeF18(v1Root)];

writeReport(results, outFile, v1Root);
end

% ======================================================================
function r = mk(id, claim, kind, verdict, fmt, varargin)
r = struct('id', string(id), 'claim', string(claim), 'kind', string(kind), ...
           'verdict', string(verdict), ...
           'evidence', string(sprintf(fmt, varargin{:})));
end

function v = verdictFrom(tf)
v = "refuted";
if tf, v = "reproduced"; end
end

% ======================================================================
% F1 - range() is a Statistics Toolbox function
% ======================================================================
function r = probeF1(root)
[nFiles, nSites, files] = countCalls(root, "range");
% which -all is the part that makes this a measurement rather than a
% grep: it says where the symbol actually resolves on THIS installation.
w = which('range', '-all');
onStatsPath = any(contains(string(w), "stats"));
r = mk("F1", "range() is a Statistics Toolbox function, ~15 sites", ...
    "counted", verdictFrom(nSites > 0 && onStatsPath), ...
    ['%d call sites across %d files (%s). which -all resolves range to ' ...
     '%s. The handover said "~15 sites across 5 files"; the measured ' ...
     'figure is %d across %d.'], ...
    nSites, nFiles, strjoin(files, ", "), ...
    strjoin(string(w), " | "), nSites, nFiles);
end

% ======================================================================
% F2 - Robinson receives an unwrapped longitude difference
% ======================================================================
function r = probeF2()
x = geoProject(359, 10, "robinson", 0, 0);
% Analytic expectation: lon 359 with lon0 = 0 is 1 degree WEST, so x must
% be small and negative. 0.02 is generous: 0.8487 * 1 degree in radians is
% about 0.0148 Earth radii at this latitude.
bad = ~(x < 0 && abs(x) < 0.02);
r = mk("F2", "Robinson gets unwrapped LON-lon0; lon=359 lands at +3.0", ...
    "executed", verdictFrom(bad), ...
    ['geoProject(359, 10, "robinson", 0, 0) returned x = %.6f. Correct ' ...
     'is a small negative value near -0.0148 (one degree west). The ' ...
     'returned value is %s.'], x, ...
    string(ternary(bad, "wrong by about 200 map widths", "correct")));
end

% ======================================================================
% F3 - Mercator clamps instead of returning NaN
% ======================================================================
function r = probeF3()
[~, y87] = geoProject(0, 87, "mercator", 0, 0);
[~, y85] = geoProject(0, 85, "mercator", 0, 0);
clamped = ~isnan(y87) && abs(y87 - y85) < 1e-12;
r = mk("F3", "Mercator clamps to +/-85 where others return NaN", ...
    "executed", verdictFrom(clamped), ...
    ['y(87) = %.10f, y(85) = %.10f, difference %.3e. A clamp puts data ' ...
     'at latitude 87 on the parallel of 85 - silently, and %.0f km out ' ...
     'of place.'], y87, y85, abs(y87 - y85), ...
    2 * 6371.0072 * pi / 180);
end

% ======================================================================
% F4 - geoResampleGrid is not longitude-periodic
% ======================================================================
function r = probeF4()
%PROBEF4  The seam that is actually outside the hull, not the one that
%   looks like it.
%
%   THE PROBE POINT IS PART OF THE PROBE, and this one had to be measured
%   rather than chosen. The first version queried lon = -0.5, the obvious
%   "seam", and REFUTED F4: v1 returned the exact bilinear midpoint. The
%   reason is v1's rewrap, which maps 0:359 onto -180:179 and sorts. That
%   puts -0.5 comfortably INSIDE the hull, between the columns for 359 and
%   0, where any interpolant is correct.
%
%   The hull's real upper edge is 179. A query at 179.5 is outside it, and
%   griddedInterpolant is constructed with 'nearest' extrapolation, so it
%   returns the value AT 179 rather than the midpoint between 179 and
%   -180. Silently: no NaN, no warning, a plausible number in the wrong
%   place. That is the defect, and it lives one degree from where the
%   first probe looked.
srcLon = 0:359;
srcLat = [-1 0 1];
% cos is smooth across the seam, so the exact bilinear value between the
% two straddling columns is their mean, by construction rather than by
% appeal to the code.
Z = repmat(cosd(srcLon), numel(srcLat), 1);
q = 179.5;
want = (cosd(179) + cosd(180)) / 2;
got = geoResampleGrid(srcLon, srcLat, Z, q, 0, 0);
atEdge = cosd(179);
err = abs(got - want);
isNearest = abs(got - atEdge) < 1e-12;
% Control: the same query one degree the other side of the wrap, which is
% INSIDE the hull and must be exact. Without it, a probe that reported an
% error everywhere would look identical to one that found the defect.
inside = geoResampleGrid(srcLon, srcLat, Z, -0.5, 0, 0);
insideErr = abs(inside - (cosd(359) + cosd(360)) / 2);
r = mk("F4", "regrid is not longitude-periodic; seam hits extrapolation", ...
    "executed", verdictFrom(isNearest && err > 1e-9), ...
    ['query at lon = %.1f returned %.10f. The exact bilinear midpoint ' ...
     'is %.10f (error %.3e); the value AT the hull edge, lon 179, is ' ...
     '%.10f - which is what was returned, to %.1e. That is nearest ' ...
     'extrapolation, not interpolation. CONTROL: the same query at lon ' ...
     '-0.5, which is inside the hull, is exact to %.1e - so the probe ' ...
     'is measuring the seam and not a general inaccuracy.'], ...
    q, got, want, err, atEdge, abs(got - atEdge), insideErr);
end

% ======================================================================
% F5 - no inverse projection anywhere
% ======================================================================
function r = probeF5(root)
d = dir(fullfile(root, "*.m"));
names = string({d.name});
hasInverse = any(contains(lower(names), "unproject") | ...
                 contains(lower(names), "inverse"));
r = mk("F5", "no inverse projection anywhere", "counted", ...
    verdictFrom(~hasInverse), ...
    ['%d files in the tree; none is named for an inverse. Without one ' ...
     'there is no round-trip test, no projected-space picking and no ' ...
     'inverse-based graticule labelling.'], numel(d));
end

% ======================================================================
% F6 - local functions duplicated across the main plotters
% ======================================================================
function r = probeF6(root)
[dups, total] = duplicateLocals(root);
r = mk("F6", "six local functions duplicated across the main plotters", ...
    "counted", verdictFrom(~isempty(dups)), ...
    ['%d local functions in the tree; %d bodies appear in more than one ' ...
     'file: %s.'], total, numel(dups), ...
    strjoin(dups, ", "));
end

% ======================================================================
% F7 - projection state as loose positional arguments
% ======================================================================
function r = probeF7(root)
worst = "";
worstN = 0;
d = dir(fullfile(root, "*.m"));
for i = 1:numel(d)
    n = positionalCount(fullfile(d(i).folder, d(i).name));
    if n > worstN
        worstN = n;
        worst = string(erase(d(i).name, ".m"));
    end
end
r = mk("F7", "geoNorthArrow takes 15 positional arguments", "counted", ...
    verdictFrom(worstN >= 15), ...
    ['the widest signature in the tree is %s with %d positional ' ...
     'arguments. A caller who gets one wrong has no way to learn which.'], ...
    worst, worstN);
end

% ======================================================================
% F8 - geoImagesc is 3413 lines; Track and Points near-identical
% ======================================================================
function r = probeF8(root)
n = @(f) numel(splitlines(string(fileread(fullfile(root, f)))));
a = n("geoImagesc.m");
b = n("geoImagescTrack.m");
c = n("geoImagescPoints.m");
r = mk("F8", "geoImagesc is 3413 lines; Track and Points ~80% identical", ...
    "counted", verdictFrom(a > 400), ...
    ['geoImagesc.m %d lines, geoImagescTrack.m %d, geoImagescPoints.m ' ...
     '%d. D-003 caps a function at 400; this is one file at %.1f times ' ...
     'that.'], a, b, c, a / 400);
end

% ======================================================================
% F9 - renderer-dependent OpenGL hillshading
% ======================================================================
function r = probeF9(root)
files = ["geoImagesc.m" "geoImagescTrack.m" "geoImagescPoints.m"];
hits = 0;
detail = strings(0, 1);
for f = files
    t = string(fileread(fullfile(root, f)));
    hasLight = contains(t, "light(") || contains(t, "camlight");
    hasInterp = contains(t, "shading interp") || contains(t, "'interp'");
    hasAlpha = contains(t, "FaceAlpha");
    if hasLight && hasInterp && hasAlpha
        hits = hits + 1;
        detail(end+1) = f; %#ok<AGROW>
    end
end
r = mk("F9", "renderer-dependent OpenGL hillshading", "counted", ...
    verdictFrom(hits > 0), ...
    ['light + shading interp + FaceAlpha co-occur on one surface in ' ...
     '%d files (%s). NOTE the limit of this probe: the co-occurrence is ' ...
     'measured, the renderer dependence it implies is still inferred. ' ...
     'D-009 rests on the inference and Stage B settles it against ' ...
     'oracle O8.'], hits, strjoin(detail, ", "));
end

% ======================================================================
% F10 - geoPercentileRange uses round(p/100*n), biased and uninterpolated
% ======================================================================
function r = probeF10()
got = geoPercentileRange([1 2], [50 50]);
% Type 7 on [1 2] at p = 50 is exactly 1.5, by h = (n-1)p/100 + 1 = 1.5.
want = 1.5;
% v1 widens a degenerate range by +/-0.5, so read the centre.
centre = mean(got);
r = mk("F10", "percentile uses round(p/100*n): biased, not interpolated", ...
    "executed", verdictFrom(abs(centre - want) > 1e-12), ...
    ['geoPercentileRange([1 2], [50 50]) returned [%.4f %.4f], centre ' ...
     '%.4f. The type-7 quantile is exactly %.4f. An index-rounding rule ' ...
     'cannot produce a value between two samples at all.'], ...
    got(1), got(2), centre, want);
end

% ======================================================================
% F11 - a variable named clim shadows clim()
% ======================================================================
function r = probeF11(root)
[nFiles, nSites, files] = countAssignments(root, "clim");
usesCaxis = countCalls(root, "caxis") > 0;
r = mk("F11", "variable clim shadows clim(), forcing deprecated caxis", ...
    "counted", verdictFrom(nSites > 0), ...
    ['clim assigned as a variable at %d sites in %d files (%s). caxis ' ...
     'present in the tree: %s.'], nSites, nFiles, strjoin(files, ", "), ...
    string(ternary(usesCaxis, "yes", "no")));
end

% ======================================================================
% F12 - domain clipping by magic numbers
% ======================================================================
function r = probeF12(root)
t = string(fileread(fullfile(root, "geoProject.m")));
lits = string(regexp(t, 'cosc\s*<\s*-?[\d.]+', 'match'));
r = mk("F12", "domain clipping by magic cosc literals", "counted", ...
    verdictFrom(~isempty(lits)), ...
    ['%d bare cosc thresholds in geoProject.m: %s. Each serves as both ' ...
     'a mathematical guard and a cosmetic clip, and nothing says which ' ...
     'is which.'], numel(lits), strjoin(unique(lits), ", "));
end

% ======================================================================
% F13 - coastline readers grow arrays in the record loop
% ======================================================================
function r = probeF13(root)
readers = ["geoCoastlineFromGSHHG.m" "geoCoastlineFromShapefile.m" ...
           "geoCoastlineFromText.m"];
n = 0;
detail = strings(0, 1);
for f = readers
    k = count(string(fileread(fullfile(root, f))), "%#ok<AGROW>");
    n = n + k;
    detail(end+1) = sprintf("%s:%d", erase(f, ".m"), k); %#ok<AGROW>
end
r = mk("F13", "coastline readers grow arrays in the record loop, O(N^2)", ...
    "counted", verdictFrom(n > 0), ...
    ['%d growth pragmas across the three readers (%s). Full-resolution ' ...
     'GSHHG is about 180 MB, where O(N^2) accumulation is the whole ' ...
     'cost.'], n, strjoin(detail, ", "));
end

% ======================================================================
% F14 - no caching: coastlines re-read and re-projected every call
% ======================================================================
function r = probeF14(root)
d = dir(fullfile(root, "*.m"));
names = string({d.name});
hasCache = any(contains(lower(names), "cache"));
persistentUses = 0;
for i = 1:numel(d)
    persistentUses = persistentUses + count( ...
        string(fileread(fullfile(d(i).folder, d(i).name))), "persistent ");
end
r = mk("F14", "no caching: coastlines re-read and re-projected per call", ...
    "counted", verdictFrom(~hasCache && persistentUses == 0), ...
    ['no file in the tree is named for a cache, and "persistent" appears ' ...
     '%d times in %d files. Nothing survives between calls.'], ...
    persistentUses, numel(d));
end

% ======================================================================
% F15 - appdata plus manual SizeChangedFcn chaining
% ======================================================================
function r = probeF15(root)
[nFiles, nSites, files] = countCalls(root, "setappdata|getappdata");
chain = countCalls(root, "SizeChangedFcn");
r = mk("F15", "appdata + manual SizeChangedFcn chaining, global state", ...
    "counted", verdictFrom(nSites > 0), ...
    ['%d appdata calls in %d files (%s); SizeChangedFcn touched %d ' ...
     'times. Any other toolbox that sets the same property breaks the ' ...
     'chain.'], nSites, nFiles, strjoin(files, ", "), chain);
end

% ======================================================================
% F16 - geoNiceGraticuleStep snaps to nearest
% ======================================================================
function r = probeF16()
%PROBEF16  Scan a ladder of spans; do not pick one and hope.
%
%   The first version of this probe tested span 120 alone and REFUTED
%   F16, because at 120 the nearest-snap and the ceiling policy happen to
%   agree exactly (step 20, 7 lines). One favourable point is not a
%   measurement of a policy - it is a measurement of that point. The
%   ladder below finds where the two policies actually diverge and
%   reports the worst case, so the claim is settled by the span that
%   breaks it rather than by the span that was convenient.
target = 6;
niceSet = [0.1 0.2 0.25 0.5 1 2 3 5 10 15 20 30 45 60 90];
spans = [5 10 20 30 45 60 90 120 150 180 240 300 360];
worstSpan = NaN;
worstLines = target;
nDiff = 0;
for s = spans
    step = geoNiceGraticuleStep(s);
    ideal = s / target;
    k = find(niceSet >= ideal, 1);
    ceilStep = niceSet(min(k, numel(niceSet)));
    if isempty(k), ceilStep = niceSet(end); end
    if abs(step - ceilStep) < 1e-9, continue, end
    nDiff = nDiff + 1;
    nLines = s / step + 1;
    if abs(nLines - target) > abs(worstLines - target)
        worstLines = nLines;
        worstSpan = s;
    end
end
r = mk("F16", "graticule step snaps to nearest, overshooting the target", ...
    "executed", verdictFrom(nDiff > 0), ...
    ['over %d spans, v1''s nearest-snap differs from the ceiling policy ' ...
     'at %d of them. Worst measured: span %g deg gives %g lines against ' ...
     'a target of %d. The handover illustrated this as "3 or 11 lines"; ' ...
     'the measured worst is %g, so the DEFECT reproduces and the ' ...
     'ILLUSTRATION does not - Part 5''s wording should be corrected to ' ...
     'the measured figure.'], ...
    numel(spans), nDiff, worstSpan, worstLines, target, worstLines);
end

% ======================================================================
% F17 - GSHHG Antarctica pole closure unhandled
% ======================================================================
function r = probeF17()
r = mk("F17", "GSHHG Antarctica pole closure unhandled", "blocked", ...
    "blocked", ...
    ['needs oracle O6, a real GSHHG .b file, which the register still ' ...
     'lists as unfilled. Handover debt V3 stays open and the reader ' ...
     'ships with provenance = "unverified" (OB-3). Reported as blocked, ' ...
     'never as passed.']);
end

% ======================================================================
% F18 - the tests are smoke tests
% ======================================================================
function r = probeF18(root)
t = string(fileread(fullfile(root, "test_geoImagesc.m")));
nAssert = count(t, "assert") + count(t, "verify");
nTol = numel(regexp(t, '[Tt]ol|1e-\d+', 'match'));
nRound = count(lower(t), "round-trip") + count(lower(t), "roundtrip");
r = mk("F18", "tests are smoke tests: no references, round-trips or budgets", ...
    "counted", verdictFrom(nRound == 0), ...
    ['test_geoImagesc.m: %d assert/verify calls, %d tolerance-like ' ...
     'tokens, %d round-trip mentions. A suite with no reference value ' ...
     'and no tolerance asserts that the code ran, not that it was ' ...
     'right.'], nAssert, nTol, nRound);
end

% ======================================================================
% Counting helpers. Shared, so eighteen probes cannot disagree about how
% a call site is counted.
% ======================================================================
function [nFiles, nSites, files] = countCalls(root, pattern)
d = dir(fullfile(root, "*.m"));
files = strings(0, 1);
nSites = 0;
for i = 1:numel(d)
    t = string(fileread(fullfile(d(i).folder, d(i).name)));
    lines = codeOnly(t);
    k = numel(regexp(strjoin(lines, newline), ...
        "(?<![\w.])(" + pattern + ")\s*\(", 'match'));
    if k > 0
        nSites = nSites + k;
        files(end+1) = string(erase(d(i).name, ".m")); %#ok<AGROW>
    end
end
nFiles = numel(files);
end

function [nFiles, nSites, files] = countAssignments(root, name)
d = dir(fullfile(root, "*.m"));
files = strings(0, 1);
nSites = 0;
for i = 1:numel(d)
    lines = codeOnly(string(fileread(fullfile(d(i).folder, d(i).name))));
    k = sum(~cellfun(@isempty, regexp(cellstr(lines), ...
        "^\s*" + name + "\s*=[^=]", 'once')));
    if k > 0
        nSites = nSites + k;
        files(end+1) = string(erase(d(i).name, ".m")); %#ok<AGROW>
    end
end
nFiles = numel(files);
end

function lines = codeOnly(txt)
%CODEONLY  Drop whole-line comments.
%   Deliberately cruder than the audit's stripper: these are counts over a
%   tree this project does not own and will delete, and a count that is
%   slightly conservative is honest as long as it says so. Trailing
%   comments survive, so a call named inside one is counted; every figure
%   here is therefore an UPPER bound, and the report says that.
lines = string(splitlines(txt));
lines = lines(~startsWith(strtrim(lines), "%"));
end

function n = positionalCount(p)
lines = codeOnly(string(fileread(p)));
m = regexp(lines(1), '\(([^)]*)\)', 'tokens', 'once');
n = 0;
if isempty(m), return, end
a = strtrim(split(string(m{1}), ","));
a(a == "" | a == "options" | a == "varargin") = [];
n = numel(a);
end

function [dups, total] = duplicateLocals(root)
d = dir(fullfile(root, "*.m"));
seen = configureDictionary("string", "string");
dups = strings(0, 1);
total = 0;
for i = 1:numel(d)
    lines = codeOnly(string(fileread(fullfile(d(i).folder, d(i).name))));
    starts = find(~cellfun(@isempty, regexp(cellstr(lines), ...
        '^\s*function(?![\w])', 'once')));
    for k = 2:numel(starts)
        last = numel(lines);
        if k < numel(starts), last = starts(k+1) - 1; end
        total = total + 1;
        body = regexprep(join(strtrim(lines(starts(k)+1:last)), ";"), ...
            '\s+', '');
        if strlength(body) < 80, continue, end
        nm = string(regexp(lines(starts(k)), ...
            'function\s+(?:\[?[^=\]]*\]?\s*=\s*)?(\w+)', 'tokens', 'once'));
        if isKey(seen, body)
            dups(end+1) = nm + " = " + seen(body); %#ok<AGROW>
        else
            seen(body) = nm;
        end
    end
end
dups = unique(dups);
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

function p = defaultV1Root()
cands = ["C:\Users\matth\Documents\MATLAB\maptoolbox_v1\maptoolbox"
         "C:\Users\matth\Documents\MATLAB\maptoolbox"
         fullfile(geoMapRoot(), "..", "maptoolbox")];
p = cands(1);
for c = cands(:)'
    if isfile(fullfile(c, "geoProject.m"))
        p = c;
        return
    end
end
end

% ======================================================================
function writeReport(results, outFile, v1Root)
folder = fileparts(outFile);
if ~isfolder(folder), mkdir(folder), end
nRep = sum([results.verdict] == "reproduced");
nRef = sum([results.verdict] == "refuted");
nBlk = sum([results.verdict] == "blocked");

L = strings(0, 1);
L(end+1) = "# v1 defect probe results";
L(end+1) = "";
L(end+1) = "*Generated by `records/v1_defect_probes.m` on " + ...
    string(datetime("now", Format = "d-MMM-uuuu HH:mm")) + ...
    " against `" + v1Root + "`.*";
L(end+1) = "";
L(end+1) = "**This file discharges handover debt V4.** Part 5 of the " + ...
    "handover listed eighteen defects derived by reading v1, never by " + ...
    "running it. Each row below is the same claim, measured.";
L(end+1) = "";
L(end+1) = "**A refuted row is deleted from the design rationale**, not " + ...
    "quietly kept. A design justified by a defect that does not exist " + ...
    "is a design without a reason.";
L(end+1) = "";
L(end+1) = sprintf("**%d reproduced · %d refuted · %d blocked**, of %d.", ...
    nRep, nRef, nBlk, numel(results));
L(end+1) = "";
L(end+1) = "Probe kinds are not equally strong and are labelled so: " + ...
    "`executed` ran v1 and read a number; `counted` measured the source " + ...
    "text; `blocked` needs something absent and is never reported as a " + ...
    "pass. Every `counted` figure is an UPPER bound - the counter drops " + ...
    "whole-line comments only, so a name inside a trailing comment is " + ...
    "still counted.";
L(end+1) = "";
L(end+1) = "| id | verdict | kind | claim | evidence |";
L(end+1) = "|---|---|---|---|---|";
for i = 1:numel(results)
    r = results(i);
    mark = "reproduced";
    if r.verdict == "refuted", mark = "**REFUTED**"; end
    if r.verdict == "blocked", mark = "*blocked*"; end
    L(end+1) = "| " + r.id + " | " + mark + " | " + r.kind + " | " + ...
        r.claim + " | " + r.evidence + " |"; %#ok<AGROW>
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
fprintf('v1 probes: %d reproduced, %d refuted, %d blocked -> %s\n', ...
    nRep, nRef, nBlk, outFile);
end
