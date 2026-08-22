function ok = rungeoMapTests(selector, opts)
%RUNGEOMAPTESTS  The one project runner. Its count is authoritative.
%
%   DESCRIPTION
%     Never call MATLAB's directory-discovery entry point directly: a
%     runner that reports what it did is the instrument. This one verifies
%     the transfer manifest BEFORE running anything, then reports what
%     loaded, per-suite seconds, the warning inventory by identifier, every
%     measurement left behind by a passing assertion, and the per-function
%     test-category coverage.
%
%     A green gate means: zero failures AND every suite loaded AND no new
%     warning identifier AND no speed budget exceeded AND the manifest
%     verified. Not "the number went up".
%
%   SYNTAX
%     ok = rungeoMapTests()             % correctness tiers
%     ok = rungeoMapTests("all")        % adds the speed tier
%     ok = rungeoMapTests("speed")      % speed tier only
%     ok = rungeoMapTests("TestB1")     % name filter
%     ok = rungeoMapTests(..., SkipManifest=true)
%
%   INPUTS
%     selector  (1,1) string  ["default"] "default" | "all" | "speed" |
%                             any other value is treated as a test-name
%                             substring filter.
%
%   OPTIONS
%     SkipManifest  (1,1) logical  [false]  Skip manifest verification.
%                                           Under Tier B this is a debt,
%                                           not a convenience.
%     Verbosity     (1,1) double   [2]      matlab.unittest verbosity.
%
%   OUTPUTS
%     ok  (1,1) logical  True only if the full green-gate definition holds.
%
%   ACCURACY
%     The pass count is authoritative but not sufficient: a suite that
%     silently fails to load is indistinguishable from a green run by the
%     pass count alone. Predict the count before the run and reconcile it
%     against the three sums this function prints.
%
%   ERRORS
%     Tree integrity:
%       geo:runner:ManifestMismatch - a shipped file is missing, truncated
%                                     or altered relative to MANIFEST.txt
%       geo:runner:NoTests          - the selector matched nothing
%
%   EXAMPLE
%     ok = rungeoMapTests("all");
%
%   LIMITATIONS
%     The warning inventory captures the LAST warning raised per test
%     method, via lastwarn. MATLAB offers no global warning hook, so a test
%     that raises two different identifiers reports only the second. This
%     under-reports and is recorded as such (finding PV-013). It is
%     adequate for the gate because the gate asserts the inventory is
%     EMPTY except for one deliberate probe: any leak shows up as a
%     non-empty inventory regardless of ordering.
%
%   See also GEOMAPTESTCASE, MAKEMANIFEST.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    selector (1,1) string = "default"
    opts.SkipManifest (1,1) logical = false
    opts.Verbosity (1,1) double = 2
end

root = geoMapRoot();
addpath(root, fullfile(root, 'tests'), fullfile(root, 'tools'), ...
        fullfile(root, 'records'));

fprintf('\n=============================================================\n');
fprintf(' geoMap v2 test runner   %s\n', string(datetime("now")));
fprintf(' machine: %s\n', geoMapMachineTag());
fprintf('=============================================================\n');

% --- 1. Manifest, before anything runs ------------------------------
manifestOk = true;
if opts.SkipManifest
    fprintf('\n[manifest] SKIPPED - this is a verification debt, not a\n');
    fprintf('           convenience. A transfer loss will now surface as\n');
    fprintf('           a mysterious test failure rounds later.\n');
else
    [manifestOk, mreport] = verifyManifest(root);
    fprintf('\n[manifest] %s\n', mreport);
end

% --- 2. Build the suite ---------------------------------------------
import matlab.unittest.TestSuite
import matlab.unittest.TestRunner
import matlab.unittest.selectors.HasTag

suite = TestSuite.fromFolder(fullfile(root, 'tests'));
if isempty(suite)
    error('geo:runner:NoTests', ...
        'No tests found in %s.', fullfile(root, 'tests'));
end

correctnessTags = ["contract" "reference" "precision" "robustness" ...
                   "vectorisation" "metamorphic"];
switch selector
    case "default"
        suite = selectAnyTag(suite, correctnessTags);
    case "all"
        % everything
    case "speed"
        suite = suite.selectIf(HasTag("speed"));
    otherwise
        keep = contains(string({suite.Name}), selector);
        suite = suite(keep);
end
if isempty(suite)
    error('geo:runner:NoTests', ...
        'Selector "%s" matched no tests.', selector);
end

% --- 3. Run ----------------------------------------------------------
geoMapTestRecord('reset');
runner = TestRunner.withTextOutput('OutputDetail', opts.Verbosity);
plugin = WarningInventoryPlugin();
runner.addPlugin(plugin);

result = runner.run(suite);

% --- 4. Report -------------------------------------------------------
fprintf('\n-------------------------------------------------------------\n');
fprintf(' FILES LOADED\n');
fprintf('-------------------------------------------------------------\n');
classes = unique(extractBefore(string({suite.Name}) + "/", "/"));
for i = 1:numel(classes)
    n = sum(startsWith(string({suite.Name}), classes(i)));
    fprintf('  %-40s %4d points\n', classes(i), n);
end

fprintf('\n-------------------------------------------------------------\n');
fprintf(' PER-SUITE SECONDS\n');
fprintf('-------------------------------------------------------------\n');
names = string({result.Name});
dur = [result.Duration];
for i = 1:numel(classes)
    m = startsWith(names, classes(i));
    fprintf('  %-40s %8.2f s\n', classes(i), sum(dur(m)));
end
fprintf('  %-40s %8.2f s\n', 'TOTAL', sum(dur));
fprintf(['  NOTE: do not compare these across rounds of different\n' ...
         '  colour. A failing verification makes the framework build a\n' ...
         '  diagnostic, resolve a stack and format links, which is not\n' ...
         '  free.\n']);

nInc = sum([result.Incomplete]);   % read here: the filter inventory needs it

fprintf('\n-------------------------------------------------------------\n');
fprintf(' WARNING INVENTORY\n');
fprintf('-------------------------------------------------------------\n');
inv = plugin.Inventory;
% The filter registry is the allow-list for the geo:filter:* family.
% Audit finding A-1: a filtered point did not run, and the gate had no
% way to tell one that was expected from one that was not. Registering
% the REASON rather than bounding the COUNT reuses the alarm that was
% already here; nothing was added to the gate.
registered = readFilterRegistry(fullfile(root, 'tests', 'FILTERS.md'));
allowed = ["geo:internal:testProbe", registered];
warnOk = true;
if isempty(fieldnames(inv))
    fprintf('  (empty)\n');
else
    ids = string(fieldnames(inv));
    for i = 1:numel(ids)
        id = ids(i);
        realId = inv.(id).id;
        n = inv.(id).count;
        isAllowed = any(realId == allowed);
        fprintf('  %-50s %4d %s\n', realId, n, ...
            string(missing2str(isAllowed)));
        if ~isAllowed
            warnOk = false;
        end
    end
end
if ~warnOk
    fprintf(['  GATE FAILED: an identifier appeared that is neither the\n' ...
             '  deliberate probe (%s) nor a filter\n' ...
             '  reason registered in tests/FILTERS.md. A test that\n' ...
             '  raises a warning on purpose must call\n' ...
             '  tc.suppressWarning(id); a test that filters must call\n' ...
             '  tc.filterBecause(id, why) with a REGISTERED id.\n'], ...
             allowed(1));
end

fprintf('\n-------------------------------------------------------------\n');
fprintf(' FILTER INVENTORY  (points that did NOT run)\n');
fprintf('-------------------------------------------------------------\n');
reportFilters(inv, registered, nInc);

fprintf('\n-------------------------------------------------------------\n');
fprintf(' MEASUREMENTS LEFT BY PASSING ASSERTIONS\n');
fprintf('-------------------------------------------------------------\n');
recs = geoMapTestRecord('get');
speedOk = true;
% Audit finding A-1, second half. speedOk was initialised true and then
% ANDed over whatever ratio records existed, so an empty set earned the
% tick: the gate could not tell "the budgets were met" from "the budgets
% were not measured". The three-state answer is decided below, after the
% records are read, from what the SUITE contained rather than from what
% it happened to leave behind - five weak graphics ratios survived the
% probe run and would have gone on earning the tick.
speedSel = arrayfun(@(x) any(string(x.Tags) == "speed"), suite);
nSpeedSel = sum(speedSel);
nSpeedRan = nSpeedSel - sum([result(speedSel).Incomplete]);
nVal = 0; nRatio = 0; nWeak = 0;
for i = 1:numel(recs)
    r = recs{i};
    switch r.kind
        case "value"
            nVal = nVal + 1;
            fprintf('  [value] %-44s %12.6g %s (bound %s %.6g)\n', ...
                r.label, r.actual, r.units, r.cmp, r.bound);
        case "ratio"
            nRatio = nRatio + 1;
            nWeak = nWeak + double(r.weak);
            pass = (r.direction == "<=" && r.ratio <= r.budget) || ...
                   (r.direction == ">=" && r.ratio >= r.budget);
            speedOk = speedOk && pass;
            fprintf('  [ratio%s] %-42s %8.4g %s %-8.4g band %.4g..%.4g\n', ...
                repmat('*', 1, double(r.weak)), r.label, r.ratio, ...
                r.direction, r.budget, r.band(1), r.band(2));
    end
end
fprintf('  (%d value records, %d ratio records, %d of them weak/graphics)\n', ...
    nVal, nRatio, nWeak);

if nSpeedSel > 0 && nSpeedRan == 0
    speedOk = false;
    speedNote = sprintf(['NOT MEASURED: %d speed-tagged points were ' ...
        'selected and every one filtered'], nSpeedSel);
elseif nSpeedSel == 0
    speedNote = 'tier not selected by this run';
else
    speedNote = sprintf('%d of %d speed-tagged points ran', ...
        nSpeedRan, nSpeedSel);
end
fprintf('  speed tier: %s\n', speedNote);

fprintf('\n-------------------------------------------------------------\n');
fprintf(' TEST-CATEGORY COVERAGE BY FUNCTION\n');
fprintf('-------------------------------------------------------------\n');
covOk = reportCategoryCoverage(root, suite);

fprintf('\n-------------------------------------------------------------\n');
fprintf(' STATIC AUDIT\n');
fprintf('-------------------------------------------------------------\n');
% Part of the green gate by definition (handover 2.6.1), so it is read
% here and not only in the shell script. SelfTest is off: the audit's
% fixtures are already exercised as test points by TestStage03_audit, and
% running them twice would double the cost for no new information.
[auditOk, auditFindings] = geoMapAudit(root, SelfTest = false, ...
    Verbose = false);
if auditOk
    fprintf('  geoMapAudit: 0 findings\n');
else
    for i = 1:numel(auditFindings)
        fprintf('  ! [%s] %s: %s\n', auditFindings(i).check, ...
            auditFindings(i).file, auditFindings(i).message);
    end
end

% --- 5. The gate -----------------------------------------------------
nFail = sum([result.Failed]);
nPass = sum([result.Passed]);

fprintf('\n=============================================================\n');
fprintf(' RECONCILE THE COUNT THREE WAYS\n');
fprintf('-------------------------------------------------------------\n');
fprintf('  passed + failed + incomplete = %d + %d + %d = %d\n', ...
    nPass, nFail, nInc, nPass + nFail + nInc);
fprintf('  suite size                   = %d\n', numel(suite));
fprintf('  per-class sum                = %d\n', numel(result));
fprintf(['  Compare these against the count you predicted BEFORE the\n' ...
         '  run. A prediction that misses is the cheapest available\n' ...
         '  signal that the change was not the change you thought you\n' ...
         '  made. Do not write the number into any document.\n']);

ok = (nFail == 0) && manifestOk && warnOk && speedOk && covOk && auditOk;
% A subset run may be green and is not a green GATE. The words are
% reserved for the run the gate is defined over, so a screenshot of a
% partial run cannot be read as one (audit finding A-1).
isFullRun = (selector == "all");
if isFullRun
    fprintf('\n GREEN GATE: %s\n', ternary(ok, 'PASS', 'FAIL'));
else
    fprintf('\n PARTIAL RUN (selector "%s"): %s\n', string(selector), ...
        ternary(ok, 'clean so far', 'FAIL'));
    fprintf(['   This is NOT the green gate. The gate is defined over\n' ...
             '   rungeoMapTests("all").\n']);
end
fprintf('   zero failures      %s\n', tick(nFail == 0));
fprintf('   manifest verified  %s\n', tick(manifestOk));
fprintf('   warning inventory  %s\n', tick(warnOk));
fprintf('   speed budgets      %s   (%s)\n', tick(speedOk), speedNote);
fprintf('   category coverage  %s\n', tick(covOk));
fprintf('   static audit       %s\n', tick(auditOk));
fprintf('=============================================================\n\n');
end

% ----------------------------------------------------------------------
function s = selectAnyTag(suite, tags)
keep = false(1, numel(suite));
for i = 1:numel(suite)
    keep(i) = any(ismember(tags, string(suite(i).Tags)));
end
s = suite(keep);
end

function ok = reportCategoryCoverage(root, suite)
required = ["contract" "reference" "precision" "robustness" ...
            "vectorisation" "metamorphic" "speed"];
exemptFile = fullfile(root, 'tests', 'EXEMPTIONS.md');
exempt = readExemptions(exemptFile);

classes = unique(extractBefore(string({suite.Name}) + "/", "/"));
ok = true;
for i = 1:numel(classes)
    cls = classes(i);
    try
        mc = meta.class.fromName(char(cls));
        pIdx = find(string({mc.PropertyList.Name}) == "CoveredFunctions", 1);
        if isempty(pIdx)
            % A FINDING, NOT A SKIP. Audit finding A-5: this printed and
            % left ok untouched, so a suite could opt out of category
            % coverage by forgetting to declare what it covers - the
            % same shape as A-1, a condition satisfied by the absence of
            % the thing it checks. Every suite declares it today; a new
            % one is exactly how it would have arrived.
            fprintf(['  %-30s NO CoveredFunctions DECLARED. Category ' ...
                     'coverage cannot be measured for a suite that does ' ...
                     'not say what it covers.\n'], cls);
            ok = false;
            continue
        end
        covered = string(mc.PropertyList(pIdx).DefaultValue);
    catch loadErr
        % And a class whose metaclass will not load printed NOTHING at
        % all, which is worse: it left no trace that a suite had been
        % passed over.
        fprintf('  %-30s METACLASS WOULD NOT LOAD (%s)\n', cls, ...
            loadErr.identifier);
        ok = false;
        continue
    end
    m = startsWith(string({suite.Name}), cls);
    tags = unique([suite(m).Tags]);
    tags = string(tags);
    for f = covered(:)'
        missingTags = setdiff(required, tags);
        missingTags = missingTags(~isExempt(exempt, f, missingTags));
        if isempty(missingTags)
            fprintf('  %-30s %-22s all categories\n', cls, f);
        else
            fprintf('  %-30s %-22s MISSING: %s\n', cls, f, ...
                strjoin(missingTags, ', '));
            ok = false;
        end
    end
end
if ok
    fprintf('  (no gaps outside EXEMPTIONS.md)\n');
else
    fprintf(['  An exemption is a claim that the test is impossible, not\n' ...
             '  that it is inconvenient. Add a row to EXEMPTIONS.md with a\n' ...
             '  reason, or ship the category.\n']);
end
end

function e = readExemptions(f)
e = struct('fcn', strings(0), 'cat', strings(0));
if exist(f, 'file') ~= 2, return, end
lines = string(splitlines(fileread(f)));
for i = 1:numel(lines)
    if ~startsWith(strtrim(lines(i)), "|"), continue, end
    parts = strtrim(split(lines(i), "|"));
    parts(parts == "") = [];
    if numel(parts) < 3, continue, end
    if parts(1) == "Function" || startsWith(parts(1), "---"), continue, end
    e.fcn(end+1) = parts(1);
    e.cat(end+1) = parts(2);
end
end

function tf = isExempt(e, fcn, cats)
tf = false(size(cats));
for i = 1:numel(cats)
    tf(i) = any(e.fcn == fcn & e.cat == cats(i));
end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

function s = tick(c)
s = ternary(c, 'ok', 'FAILED');
end

function s = missing2str(isAllowed)
s = ternary(isAllowed, '(deliberate probe)', '<-- NEW, fails the gate');
end

% ----------------------------------------------------------------------
function ids = readFilterRegistry(file)
%READFILTERREGISTRY  Reason ids permitted by tests/FILTERS.md.
%   The registry is the allow-list, and it is read rather than mirrored
%   here: one authority per fact. A missing registry is an error, not an
%   empty list - an allow-list that silently becomes empty forbids
%   everything, and an allow-list that silently becomes everything
%   forbids nothing. Which of those a typo produced should not be a
%   coin flip.
if ~isfile(file)
    error('geo:runner:NoFilterRegistry', ...
        ['tests/FILTERS.md is missing. Every filtered point names a ' ...
         'registered reason; without the registry the runner cannot ' ...
         'tell an expected filter from a new one.']);
end
tok = regexp(fileread(file), 'geo:filter:[A-Za-z]\w*', 'match');
ids = unique(string(tok));
if isempty(ids)
    error('geo:runner:EmptyFilterRegistry', ...
        'tests/FILTERS.md registers no reason ids.');
end
end

% ----------------------------------------------------------------------
function reportFilters(inv, registered, nInc)
%REPORTFILTERS  What did not run, by reason.
%   The count is REPORTED, never asserted (BEST_PRACTICE 3.4.1 - an
%   absolute figure with no baseline cannot detect the change it was
%   written for, and a bound permits silent drift up to itself). Predict
%   it before the run like every other count. What the gate holds is the
%   reason: an unregistered one is already red in the warning inventory
%   above.
seen = string.empty;
if ~isempty(fieldnames(inv))
    keys = string(fieldnames(inv));
    for i = 1:numel(keys)
        realId = inv.(keys(i)).id;
        if startsWith(realId, "geo:filter:")
            fprintf('  %-46s %4d %s\n', realId, inv.(keys(i)).count, ...
                ternary(any(realId == registered), '', ...
                        '<-- NOT REGISTERED, fails the gate'));
            seen(end+1) = realId; %#ok<AGROW>
        end
    end
end
if isempty(seen)
    fprintf('  (no filter reason raised)\n');
end
fprintf(['  %d point(s) incomplete. The warning inventory counts a\n' ...
         '  reason ONCE PER TEST, so these two numbers agree only when\n' ...
         '  each filtered point raised its own warning; a divergence\n' ...
         '  means a point was filtered by some other route.\n'], nInc);
unregistered = setdiff(registered, seen);
if ~isempty(unregistered)
    fprintf(['  registered but not raised this run: %s\n' ...
             '  (not a failure - a reason that stops firing is good\n' ...
             '  news, and the row says what closes it)\n'], ...
             strjoin(unregistered, ', '));
end
end
