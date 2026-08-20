function fx = geoMapAuditFixtures(action, arg)
%GEOMAPAUDITFIXTURES  Build the fault-injection trees the audit is proved on.
%
%   SYNTAX
%     fx   = GEOMAPAUDITFIXTURES("list")
%     dir  = GEOMAPAUDITFIXTURES("build", name)
%     GEOMAPAUDITFIXTURES("clean", dir)
%
%   DESCRIPTION
%     Every check in GEOMAPAUDIT ships a fixture proving it FIRES on a
%     broken tree and is SILENT on a healthy one. This function is where
%     those trees live, kept apart from the audit itself for one reason
%     worth stating: a fixture built inside the code under test can be
%     built to match the check rather than to match the defect. Here they
%     are written as the defect, in the form it would actually take in a
%     source file.
%
%     The healthy control is not decoration. A check proven only to fire is
%     half a check: it can fire on everything, including correct code, and
%     look exactly as convincing.
%
%     Each fixture is the healthy tree plus ONE mutation, so a finding
%     attributes to one check. Trees are built under TEMPNAME and never
%     inside the repository — a mutator is proved on a scratch copy before
%     it is pointed at the tree (handover 2.9).
%
%   INPUTS
%     action  (1,1) string  "list" | "build" | "clean".
%     arg     (1,1) string  Fixture name for "build", directory for
%                           "clean". Ignored for "list".
%
%   OUTPUTS
%     fx  For "list": (1,:) struct with fields
%           name   (1,1) string  Fixture identifier.
%           check  (1,1) string  The check that must fire on it. "" for
%                                the healthy control, on which nothing may.
%           why    (1,1) string  The defect this reproduces, in one line.
%         For "build": (1,1) string, the directory built.
%         For "clean": [].
%
%   ACCURACY
%     Not a numerical function; it has no oracle and makes no numerical
%     claim. Its correctness criterion is behavioural and is asserted in
%     TestStage03_audit: exactly the named check fires on each fixture, and
%     none fires on the control.
%
%   ERRORS
%     Argument validation:
%       geo:auditFixtures:UnknownFixture  - name not in the register
%       geo:auditFixtures:UnknownAction   - action not one of the three
%       geo:auditFixtures:RefusedToClean  - the directory is not under the
%                                           system temporary folder
%
%   EXAMPLE
%     fx = geoMapAuditFixtures("list");
%     d  = geoMapAuditFixtures("build", fx(1).name);
%     c  = onCleanup(@() geoMapAuditFixtures("clean", d));
%
%   LIMITATIONS
%     The trees are small and synthetic. A fixture shares the target's
%     failure surface only for the defect it plants; it says nothing about
%     scale, and a check that passes here can still be slow or blind on the
%     real tree. That is why the audit also runs against the repository
%     itself in the same invocation.
%
%   See also GEOMAPAUDIT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    action (1,1) string {mustBeMember(action, ["list" "build" "clean"])}
    arg (1,1) string = ""
end

switch action
    case "list"
        fx = fixtureRegister();
    case "clean"
        tmp = string(tempdir());
        if ~startsWith(arg, tmp) || ~isfolder(arg)
            error('geo:auditFixtures:RefusedToClean', ...
                ['Refusing to delete "%s": it is not under the system ' ...
                 'temporary folder "%s". A cleanup that can reach the ' ...
                 'working tree is a mutator without a scratch copy.'], ...
                arg, tmp);
        end
        rmdir(arg, 's');
        fx = [];
    otherwise
        fx = buildFixture(arg);
end
end

% ======================================================================
function reg = fixtureRegister()
%FIXTUREREGISTER  One row per check, plus the control. The single authority
%   on what the audit is proved against.
r = @(n, c, w) struct('name', string(n), 'check', string(c), ...
                      'why', string(w));
reg = [ ...
    r("healthy", "", ...
      "template-complete tree on which NO check may fire") ...
    r("forbidden", "forbiddenFunctions", ...
      "F1: range() is a Statistics Toolbox function, called at ~15 v1 sites") ...
    r("shadowed", "shadowedBuiltins", ...
      "F11: a variable named clim shadows clim(), forcing deprecated caxis") ...
    r("agrow", "arrayGrowth", ...
      "F13: coastline readers grow arrays in the record loop, O(N^2)") ...
    r("printing", "barePrinting", ...
      "library code that prints bypasses geo.internal.verbosity") ...
    r("identifier", "identifierAgreement", ...
      "an error identifier raised but never documented; the help lies") ...
    r("helptext", "helpTemplate", ...
      "a help block missing ACCURACY: the numerical claim goes unstated") ...
    r("longfunction", "functionLength", ...
      "F8: geoImagesc is 3413 lines; D-003 caps a function at 400") ...
    r("arity", "positionalArity", ...
      "F7: geoNorthArrow takes 15 positional arguments") ...
    r("duplicate", "duplicateLocalFunctions", ...
      "F6: six local functions duplicated across the main plotters") ...
    r("version", "versionAgreement", ...
      "a version string maintained in two places drifts in one of them") ...
    r("exemption", "contractExemption", ...
      "contract exempted for a function that validates its arguments") ...
    r("analyzer", "codeAnalyzer", ...
      "a parse error MATLAB's own reader sees and a text checker does not") ...
    r("purity", "orchestrationPurity", ...
      "F8: an L4 front that draws instead of orchestrating - one text()") ...
    r("puritylength", "orchestrationPurity", ...
      "F8 by accretion: a front over the 200-line orchestration budget") ...
    r("staledoc", "documentationSync", ...
      "a shipped manual page describing a help block that has since changed") ...
    ];
end

% ======================================================================
function d = buildFixture(name)
reg = fixtureRegister();
if ~any([reg.name] == name)
    error('geo:auditFixtures:UnknownFixture', ...
        'No fixture named "%s". Known: %s.', name, ...
        strjoin([reg.name], ', '));
end

d = string(tempname());
mkdir(d);
mkdir(fullfile(d, '+geo'));
mkdir(fullfile(d, '+geo', '+internal'));
mkdir(fullfile(d, 'tests'));

writeText(fullfile(d, '+geo', 'healthy.m'), healthySource());
writeText(fullfile(d, '+geo', 'frontish.m'), frontSource());
writeText(fullfile(d, '+geo', '+internal', 'log.m'), logSource());
writeText(fullfile(d, 'Contents.m'), contentsSource("2.0.0"));
writeText(fullfile(d, 'README.md'), ...
    "# fixture" + newline + "geoMap **v2.0.0**" + newline);
writeText(fullfile(d, 'HANDOVER.md'), ...
    "# fixture handover" + newline);
writeText(fullfile(d, 'tests', 'EXEMPTIONS.md'), exemptionsSource(false));

switch name
    case "healthy"
        % nothing further: this is the control
    case "forbidden"
        appendToBody(fullfile(d, '+geo', 'healthy.m'), ...
            "y = y + range(x);");
    case "shadowed"
        appendToBody(fullfile(d, '+geo', 'healthy.m'), ...
            "clim = [0 1];" + newline + "y = y * clim(2);");
    case "agrow"
        % A REAL pragma, on a line that carries code. The control tree
        % separately contains a COMMENT naming the same pragma, so this
        % fixture proves the check tells the two apart rather than
        % matching the string wherever it appears.
        appendToBody(fullfile(d, '+geo', 'healthy.m'), ...
            "for k = 1:3" + newline + ...
            "    y(end+1) = k; %#ok<AGROW>" + newline + "end");
    case "printing"
        appendToBody(fullfile(d, '+geo', 'healthy.m'), ...
            "fprintf('scaled %d values\\n', numel(y));");
    case "identifier"
        appendToBody(fullfile(d, '+geo', 'healthy.m'), ...
            "if any(~isfinite(y))" + newline + ...
            "    error('geo:healthy:NotFinite', 'y is not finite.');" + ...
            newline + "end");
    case "helptext"
        stripSection(fullfile(d, '+geo', 'healthy.m'), "ACCURACY");
    case "longfunction"
        appendToBody(fullfile(d, '+geo', 'healthy.m'), ...
            join(repmat("y = y + 0;", 1, 420), newline));
    case "arity"
        writeText(fullfile(d, '+geo', 'wide.m'), wideAritySource());
    case "duplicate"
        writeText(fullfile(d, '+geo', 'twinA.m'), twinSource("twinA"));
        writeText(fullfile(d, '+geo', 'twinB.m'), twinSource("twinB"));
    case "version"
        writeText(fullfile(d, 'README.md'), ...
            "# fixture" + newline + "geoMap **v2.1.0**" + newline);
    case "exemption"
        writeText(fullfile(d, 'tests', 'EXEMPTIONS.md'), ...
            exemptionsSource(true));
    case "analyzer"
        % A parse error, not a style warning. This fixture is the one that
        % proves the audit reads something tools/mcheck.py cannot: the
        % unmatched bracket below is invisible to a line-oriented text
        % checker and is an ERROR to MATLAB's Code Analyzer. Its ancestor
        % is real - three stale AGROW pragmas reached a green run because
        % only the Code Analyzer could see them (RECORDS R-004).
        writeText(fullfile(d, '+geo', 'broken.m'), brokenSource());
    case "purity"
        % ONE primitive, in the form the erosion actually takes: not a
        % rewrite, just a label the front drew itself "for now" because
        % reaching for geo.colorbar felt like more work. Six of those and
        % the front is a plotter; 3413 lines of them and it is F8.
        appendToBody(fullfile(d, '+geo', 'frontish.m'), ...
            "text(0, 0, 'a label the front drew itself');");
    case "staledoc"
        % A page that renders, reads well, and describes a help block
        % that no longer exists. Nothing else in the tree is wrong -
        % which is the point: this is the defect that a test suite
        % cannot see, because the page is not code.
        mkdir(fullfile(d, 'docs', 'html'));
        writeText(fullfile(d, 'docs', 'html', 'geo_healthy.html'), ...
            join(["<!DOCTYPE html><html><body><h1>geo.healthy</h1>"
                  "<p>Scale a vector, as a control for the static audit.</p>"
                  "</body></html>"
                  "<!-- helpsha256: " + repmat('a', 1, 64) + " -->"], newline));
        appendToContents(fullfile(d, 'Contents.m'), ...
            "%     geo.healthy  - Scale a vector, as a control for the static audit.");
    case "puritylength"
        % No forbidden call anywhere - only length. A front can violate
        % the rule without ever naming a primitive, by accumulating
        % orchestration until nothing can be read at once, and the budget
        % is the only thing that catches that shape of the defect.
        appendToBody(fullfile(d, '+geo', 'frontish.m'), ...
            join("y = y + " + string(1:210) + ";", newline));
end
end

% ======================================================================
% Sources. Written out rather than templated: a fixture a reader cannot
% read is a fixture nobody checks.
% ======================================================================
function s = healthySource()
s = join([
"function y = healthy(x, options)"
"%GEO.HEALTHY  Scale a vector, as a control for the static audit."
"%"
"%   SYNTAX"
"%     Y = GEO.HEALTHY(X)"
"%     Y = GEO.HEALTHY(X, Scale = S)"
"%"
"%   DESCRIPTION"
"%     Exists so the audit can be shown to be SILENT on a healthy tree."
"%     A check proven only to fire is half a check."
"%"
"%   INPUTS"
"%     x  (1,:) double  Values to scale."
"%"
"%   OUTPUTS"
"%     y  (1,:) double  Scaled values."
"%"
"%   OPTIONS"
"%     Scale  (1,1) double  [2]  Multiplier."
"%"
"%   ACCURACY"
"%     Exact: one multiplication in double precision. No oracle applies."
"%"
"%   ERRORS"
"%     Input geometry:"
"%       geo:healthy:Empty  - when x is empty"
"%"
"%   EXAMPLE"
"%     y = geo.healthy([1 2 3]);"
"%"
"%   LIMITATIONS"
"%     A fixture. It does nothing useful and is not shipped."
"%"
"%   See also GEOMAPAUDIT."
"%"
"%   ---------------------------------------------------------------------"
"%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)"
""
"arguments"
"    x (1,:) double"
"    options.Scale (1,1) double = 2"
"end"
"% This comment names %#ok<AGROW> deliberately. Prose about a banned"
"% pragma is documentation, not a pragma, and a check that cannot tell"
"% them apart fires on the file explaining why the ban exists - which is"
"% exactly what happened to +geo/splitAntimeridian.m on its first run."
"if isempty(x)"
"    error('geo:healthy:Empty', 'x must not be empty.');"
"end"
"y = x * options.Scale;"
"end"
], newline);
end

function s = frontSource()
%FRONTSOURCE  A healthy L4 front, and the control for CHECKPURITY.
%   It is in the BASE tree, not in one fixture, which makes every fixture
%   a test of the lookbehind: c.text(1) is indexing and geo.healthy() is
%   the whole point of a front, and neither may be read as a primitive.
%   Were the regex written without (?<![\w.]), the control would fail and
%   the check's claims would be void on every run.
s = join([
"function y = frontish(x)"
"%GEO.FRONTISH  A one-call front, as a control for the purity check."
"%"
"%   L4-FRONT"
"%"
"%   SYNTAX"
"%     Y = GEO.FRONTISH(X)"
"%"
"%   DESCRIPTION"
"%     Orchestration only: it calls a public geo.* function and draws"
"%     nothing. Exists so CHECKPURITY can be shown to stay SILENT on a"
"%     front that obeys the rule, which is the half of the proof that"
"%     firing on a defect does not give."
"%"
"%   INPUTS"
"%     x  (1,:) double  Values to pass through."
"%"
"%   OUTPUTS"
"%     y  (1,:) double  Whatever the element returned."
"%"
"%   ACCURACY"
"%     Exact: it adds nothing of its own, which is the property under"
"%     test. No oracle applies."
"%"
"%   ERRORS"
"%     Input geometry:"
"%       geo:frontish:Empty  - when x is empty"
"%"
"%   EXAMPLE"
"%     y = geo.frontish([1 2 3]);"
"%"
"%   LIMITATIONS"
"%     A fixture. It does nothing useful and is not shipped."
"%"
"%   See also GEOMAPAUDIT."
"%"
"%   ---------------------------------------------------------------------"
"%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)"
""
"arguments"
"    x (1,:) double"
"end"
"if isempty(x)"
"    error('geo:frontish:Empty', 'x must not be empty.');"
"end"
"y = geo.healthy(x);"
"cfg.text = numel(y);"
"y = y + cfg.text(1);"
"end"
], newline);
end

function s = logSource()
s = join([
"function log(level, fmt, varargin)"
"%GEO.INTERNAL.LOG  The only place library code is allowed to print."
"%"
"%   SYNTAX"
"%     GEO.INTERNAL.LOG(LEVEL, FMT, ...)"
"%"
"%   DESCRIPTION"
"%     Every diagnostic in the toolbox goes through here, so verbosity is"
"%     one setting rather than a search-and-replace."
"%"
"%   INPUTS"
"%     level  (1,1) double  Verbosity threshold."
"%     fmt    (1,:) char    printf format."
"%"
"%   OUTPUTS"
"%     (none)"
"%"
"%   ACCURACY"
"%     No numerical claim."
"%"
"%   ERRORS"
"%     (none raised)"
"%"
"%   EXAMPLE"
"%     geo.internal.log(1, 'hello');"
"%"
"%   LIMITATIONS"
"%     A fixture stub."
"%"
"%   See also GEOMAPAUDIT."
"%"
"%   ---------------------------------------------------------------------"
"%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)"
""
"arguments"
"    level (1,1) double"
"    fmt (1,:) char"
"end"
"arguments (Repeating)"
"    varargin"
"end"
"if level > 0"
"    fprintf(fmt, varargin{:});"
"end"
"end"
], newline);
end

function s = wideAritySource()
s = join([
"function y = wide(a, b, c, d)"
"%GEO.WIDE  Four positional arguments, which is one too many."
"%"
"%   SYNTAX"
"%     Y = GEO.WIDE(A, B, C, D)"
"%"
"%   DESCRIPTION"
"%     Reproduces F7: v1's geoNorthArrow took fifteen positional"
"%     arguments, so a caller could not tell which one it had got wrong."
"%"
"%   INPUTS"
"%     a  (1,1) double  First."
"%     b  (1,1) double  Second."
"%     c  (1,1) double  Third."
"%     d  (1,1) double  Fourth, the one too many."
"%"
"%   OUTPUTS"
"%     y  (1,1) double  Sum."
"%"
"%   ACCURACY"
"%     Exact."
"%"
"%   ERRORS"
"%     (none raised)"
"%"
"%   EXAMPLE"
"%     y = geo.wide(1, 2, 3, 4);"
"%"
"%   LIMITATIONS"
"%     A fixture."
"%"
"%   See also GEOMAPAUDIT."
"%"
"%   ---------------------------------------------------------------------"
"%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)"
""
"y = a + b + c + d;"
"end"
], newline);
end

function s = twinSource(name)
s = join([
"function y = " + name + "(x)"
"%GEO." + upper(name) + "  Carries a local function duplicated elsewhere."
"%"
"%   SYNTAX"
"%     Y = GEO." + upper(name) + "(X)"
"%"
"%   DESCRIPTION"
"%     Reproduces F6: six local functions duplicated across v1's main"
"%     plotters, so one repair had to be applied five more times."
"%"
"%   INPUTS"
"%     x  (1,:) double  Input."
"%"
"%   OUTPUTS"
"%     y  (1,:) double  Output."
"%"
"%   ACCURACY"
"%     Exact."
"%"
"%   ERRORS"
"%     (none raised)"
"%"
"%   EXAMPLE"
"%     y = geo." + name + "([1 2]);"
"%"
"%   LIMITATIONS"
"%     A fixture."
"%"
"%   See also GEOMAPAUDIT."
"%"
"%   ---------------------------------------------------------------------"
"%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)"
""
"y = localNormalise(x);"
"end"
""
"function v = localNormalise(v)"
"m = max(abs(v));"
"if m > 0"
"    v = v / m;"
"end"
"end"
], newline);
end

function s = brokenSource()
s = join([
"function y = broken(x)"
"%GEO.BROKEN  Carries a parse error only MATLAB's own reader sees."
"%"
"%   SYNTAX"
"%     Y = GEO.BROKEN(X)"
"%"
"%   DESCRIPTION"
"%     The bracket on the assignment below is never closed. A line-"
"%     oriented text checker reads the line and moves on."
"%"
"%   INPUTS"
"%     x  (1,:) double  Input."
"%"
"%   OUTPUTS"
"%     y  (1,:) double  Output."
"%"
"%   ACCURACY"
"%     None; it does not run."
"%"
"%   ERRORS"
"%     (none raised)"
"%"
"%   EXAMPLE"
"%     y = geo.broken([1 2]);"
"%"
"%   LIMITATIONS"
"%     A fixture. It is deliberately unparseable."
"%"
"%   See also GEOMAPAUDIT."
"%"
"%   ---------------------------------------------------------------------"
"%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)"
""
"y = sum(x * 2;"
"end"
], newline);
end

function s = contentsSource(ver)
s = join([
"% geoMap fixture toolbox"
"% Version " + ver + " 15-Aug-2026"
"%"
"%   healthy  - scale a vector"
], newline);
end

function s = exemptionsSource(withBadRow)
rows = [
"| Function | Category | Reason |"
"|---|---|---|"
"| healthy | speed | A fixture on no hot path. |"
];
if withBadRow
    rows(end+1) = "| healthy | contract | Too expensive to call. |";
end
s = join(["# fixture exemptions"; ""; rows], newline);
end

% ======================================================================
function writeText(p, s)
fid = fopen(p, 'w');
if fid < 0
    error('geo:auditFixtures:WriteFailed', 'Cannot write %s.', p);
end
c = onCleanup(@() fclose(fid));
fwrite(fid, char(s));
end

function appendToContents(p, row)
%APPENDTOCONTENTS  One catalogue row, so the doc check has a subject.
lines = string(splitlines(string(fileread(p))));
writeText(p, join([lines; row], newline));
end

function appendToBody(p, snippet)
%APPENDTOBODY  Insert before the function's final END.
%   Inserting rather than appending matters: text after the closing END is
%   not in the function, so a check that reads function bodies would not
%   see the planted defect and the fixture would silently prove nothing.
lines = string(splitlines(string(fileread(p))));
last = find(strtrim(lines) == "end", 1, 'last');
lines = [lines(1:last-1); string(splitlines(snippet)); lines(last:end)];
writeText(p, join(lines, newline));
end

function stripSection(p, section)
%STRIPSECTION  Delete one help section, leaving the rest well formed.
lines = string(splitlines(string(fileread(p))));
i0 = find(strtrim(lines) == "%   " + section, 1);
if isempty(i0)
    error('geo:auditFixtures:UnknownFixture', ...
        'Section %s not present to strip.', section);
end
% The section ends at the next section HEADER, which is the only thing in
% this block matching "%   " followed by an all-capitals word and nothing
% else. Anchoring on that rather than on a blank line keeps the fixture
% valid if a section ever gains or loses an internal blank.
isHeader = ~cellfun(@isempty, regexp(cellstr(lines), ...
    '^%   [A-Z][A-Z ]*[A-Z]$', 'once'));
nxt = find(isHeader(:) & ((1:numel(lines))' > i0), 1);
if isempty(nxt)
    nxt = numel(lines) + 1;
end
lines(i0:nxt-1) = [];
writeText(p, join(lines, newline));
end
