function [ok, findings] = geoMapAudit(root, opts)
%GEOMAPAUDIT  The static audit. A gate, not a report.
%
%   SYNTAX
%     ok              = GEOMAPAUDIT()
%     [ok, findings]  = GEOMAPAUDIT(ROOT)
%     [ok, findings]  = GEOMAPAUDIT(ROOT, SelfTest = false)
%     [ok, findings]  = GEOMAPAUDIT(ROOT, Only = "forbiddenFunctions")
%
%   DESCRIPTION
%     Fifteen checks over the tree, each encoding a defect the v1 review
%     found (handover Part 5) or a rule the design rests on (Part 2.7).
%     It exits zero before any ship. It is a gate: a finding blocks, it
%     does not inform.
%
%     WHY IT SELF-TESTS FIRST, and refuses to report a clean tree if the
%     self-test fails. This instrument was written in the same session as
%     the code it will judge, and handover 2.9 forbids a structure or
%     coverage claim from such an instrument unless it has been SHOWN to
%     fail on a known defect. So every check ships a fixture that plants
%     its defect in the form the defect actually takes, and one healthy
%     control on which nothing may fire. A check with no fixture proving
%     it fires is not a check; a check never seen to stay silent is worse,
%     because it fires on correct code just as convincingly.
%
%     WHY IT IS NOT tools/mcheck.py. The second gate must read something
%     the first does not (handover 2.9). mcheck.py reads MATLAB as text
%     from Python and checks block balance, help presence and a forbidden
%     word list. This one runs INSIDE MATLAB, so it reaches MATLAB's own
%     Code Analyzer - which caught three stale AGROW pragmas the Python
%     checker was structurally blind to (RECORDS R-004) - and it can
%     compare a documented error identifier against the raised one, which
%     needs the help block and the executable body read together.
%
%     THE CHECKS, and what each is for:
%       forbiddenFunctions      F1, F9, F11, F15: toolbox-only and
%                               renderer-dependent calls inside +geo
%       shadowedBuiltins        F11: a variable named clim forces caxis
%       arrayGrowth             F13: O(N^2) accumulation in a record loop
%       barePrinting            library code must not print directly
%       identifierAgreement     the documented identifier must equal the
%                               raised one - help that lies is worse than
%                               help that is absent
%       helpTemplate            handover 2.8.1, reading the WHOLE block
%       functionLength          D-003's 400-line rule; F8 was 3413 lines
%       positionalArity         F7: geoNorthArrow took fifteen
%       duplicateLocalFunctions F6: six locals duplicated across plotters
%       versionAgreement        one authority per fact: Contents.m
%       contractExemption       contract may never be exempted for a
%                               function with an arguments block
%       codeAnalyzer            MATLAB's own reader, over the whole tree
%       orchestrationPurity     F8: a file marked L4-FRONT may call no
%                               drawing primitive and may not exceed 200
%                               executable lines. This is the Stage E
%                               hard rule, and it is here rather than in
%                               a test because a rule enforced only by
%                               review is a rule that erodes
%       documentationSync       the shipped manual describes the code
%                               that is here now, compared by hash
%       packageClosure          PV-115 and PV-127: +geo may not call the
%                               harness. It resolves in a checkout and is
%                               undefined on every installed copy, so no
%                               green run anywhere can see it
%
%   INPUTS
%     root  (1,1) string  [geoMapRoot()]  Tree to audit.
%
%   OPTIONS
%     SelfTest  (1,1) logical  [true]   Prove every check first. Setting
%                                       this false is how the self-test
%                                       itself invokes the audit; nothing
%                                       else should.
%     Only      (1,1) string   [""]     Run one named check.
%     Verbose   (1,1) logical  [true]   Print the per-check table.
%
%   OUTPUTS
%     ok        (1,1) logical  True only if zero findings AND the
%                              self-test passed.
%     findings  (1,:) struct   Fields: check (1,1) string, file (1,1)
%                              string, line (1,1) double, message (1,1)
%                              string. Empty struct array when clean.
%
%   ACCURACY
%     Not a numerical instrument and it has no oracle in the register.
%     Its correctness criterion is behavioural: on each fixture in
%     GEOMAPAUDITFIXTURES exactly the named check fires, and on the healthy
%     control none does. That criterion is asserted in TestStage03_audit
%     and re-asserted on every invocation through SelfTest.
%
%   ERRORS
%     Argument validation:
%       geo:audit:NoSuchRoot     - root is not a folder
%       geo:audit:UnknownCheck   - Only names no check
%     Instrument integrity:
%       geo:audit:SelfTestFailed - a check did not fire on its own broken
%                                  fixture, or fired on the healthy one
%
%   EXAMPLE
%     ok = geoMapAudit();
%     [~, f] = geoMapAudit(geoMapRoot(), Only = "helpTemplate");
%
%   LIMITATIONS
%     Static. It reads text and the Code Analyzer's view of it, and knows
%     nothing about what the code computes. A file can pass every check
%     here and be numerically wrong; that is what the mirror and the test
%     suite are for. It also cannot see a defect in a file it does not
%     scan, so the scanned-file count is printed rather than assumed.
%
%   See also GEOMAPAUDITFIXTURES, RUNGEOMAPTESTS, MAKEMANIFEST.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    root (1,1) string = geoMapRoot()
    opts.SelfTest (1,1) logical = true
    opts.Only (1,1) string = ""
    opts.Verbose (1,1) logical = true
end

if ~isfolder(root)
    error('geo:audit:NoSuchRoot', 'Not a folder: %s', root);
end

names = checkNames();
if opts.Only ~= "" && ~any(names == opts.Only)
    error('geo:audit:UnknownCheck', ...
        'No check named "%s". Known: %s.', opts.Only, strjoin(names, ', '));
end

% --- 1. Prove the instrument before believing it ---------------------
selfOk = true;
if opts.SelfTest
    [selfOk, selfReport] = runSelfTest(opts.Verbose);
    if opts.Verbose
        fprintf('\n[audit self-test] %s\n', selfReport);
    end
end

% --- 2. Scan -----------------------------------------------------------
files = scanTree(root);
active = names;
if opts.Only ~= ""
    active = opts.Only;
end

findings = emptyFinding();
counts = zeros(1, numel(active));
for i = 1:numel(active)
    f = runCheck(active(i), files, root);
    counts(i) = numel(f);
    findings = [findings, f];  %#ok<AGROW> - one append per check, 12 total
end

% --- 3. Report ---------------------------------------------------------
if opts.Verbose
    fprintf('\n=============================================================\n');
    fprintf(' geoMapAudit   %s\n', root);
    fprintf(' files scanned: %d MATLAB, %d of them in +geo\n', ...
        numel(files), sum([files.inGeo]));
    fprintf('=============================================================\n');
    for i = 1:numel(active)
        fprintf('  %-26s %s\n', active(i), ...
            string(ternary(counts(i) == 0, "ok", ...
                sprintf('%d FINDING(S)', counts(i)))));
    end
    if ~isempty(findings)
        fprintf('\n-------------------------------------------------------------\n');
        for i = 1:numel(findings)
            fprintf('  ! [%s] %s:%d\n      %s\n', findings(i).check, ...
                findings(i).file, findings(i).line, findings(i).message);
        end
        fprintf(['\n  A finding is a defect to remove, not a threshold to\n' ...
                 '  adjust. A guard that hides one is worse than the\n' ...
                 '  failure it replaces, because it looks like progress.\n']);
    end
    fprintf('\n AUDIT: %s\n', ternary(isempty(findings) && selfOk, ...
        'PASS', 'FAIL'));
    fprintf('   self-test  %s\n', tick(selfOk));
    fprintf('   findings   %s (%d)\n', tick(isempty(findings)), ...
        numel(findings));
    fprintf('=============================================================\n\n');
end

ok = isempty(findings) && selfOk;
end

% ======================================================================
% The register. One authority on what checks exist.
% ======================================================================
function n = checkNames()
n = ["forbiddenFunctions" "shadowedBuiltins" "arrayGrowth" ...
     "barePrinting" "identifierAgreement" "helpTemplate" ...
     "functionLength" "positionalArity" "duplicateLocalFunctions" ...
     "versionAgreement" "contractExemption" "codeAnalyzer" ...
     "orchestrationPurity" "documentationSync" "packageClosure"];
end

function f = runCheck(name, files, root)
switch name
    case "forbiddenFunctions",      f = checkForbidden(files);
    case "shadowedBuiltins",        f = checkShadowed(files);
    case "arrayGrowth",             f = checkArrayGrowth(files);
    case "barePrinting",            f = checkPrinting(files);
    case "identifierAgreement",     f = checkIdentifiers(files);
    case "helpTemplate",            f = checkHelp(files);
    case "functionLength",          f = checkLength(files, root);
    case "positionalArity",         f = checkArity(files);
    case "duplicateLocalFunctions", f = checkDuplicates(files);
    case "versionAgreement",        f = checkVersion(root);
    case "contractExemption",       f = checkContractExemption(files, root);
    case "codeAnalyzer",            f = checkCodeAnalyzer(files);
    case "orchestrationPurity",     f = checkPurity(files);
    case "documentationSync",       f = checkDocSync(root);
    case "packageClosure",          f = checkPackageClosure(files, root);
end
end

% ======================================================================
% Scanning
% ======================================================================
function files = scanTree(root)
%SCANTREE  Every .m file, with its text and the facts each check needs.
%   Read once. Twelve checks re-reading the same files would be twelve
%   chances for two of them to disagree about what a file contains.
d = dir(fullfile(root, '**', '*.m'));
d = d(~[d.isdir]);
keep = ~contains(string({d.folder}), [".git", "docs"]);
d = d(keep);
files = struct('path', {}, 'rel', {}, 'name', {}, 'text', {}, ...
               'lines', {}, 'code', {}, 'inGeo', {}, 'isLog', {});
for i = 1:numel(d)
    p = string(fullfile(d(i).folder, d(i).name));
    txt = string(fileread(p));
    lines = string(splitlines(txt));
    rel = erase(p, root + filesep);
    files(end+1) = struct( ...                            %#ok<AGROW>
        'path', p, ...
        'rel', rel, ...
        'name', string(erase(d(i).name, ".m")), ...
        'text', txt, ...
        'lines', lines, ...
        'code', stripComments(lines), ...
        'inGeo', contains(rel, "+geo"), ...
        'isLog', endsWith(rel, fullfile("+internal", "log.m")));
end
end

function code = stripComments(lines)
%STRIPCOMMENTS  Blank out comments and BOTH kinds of string literal.
%   A forbidden word inside a comment is documentation, not a call, and a
%   check that cannot tell them apart trains its readers to ignore it.
%
%   Double-quoted strings matter as much as single-quoted ones, which the
%   first draft missed. tools/geoMapAuditFixtures.m writes MATLAB source
%   AS double-quoted string data, so its literals contain the words
%   "function", "if" and "end". With only single quotes stripped, the
%   block-depth counter read those as real keywords and reported a
%   25-line function as 407 lines. A parser that cannot tell code from
%   text about code is not a parser.
%
%   The single-quote case additionally needs the transpose test: in
%   MATLAB, A' is a transpose and 'A' is a string, and they are told apart
%   only by what precedes the quote.
code = lines;
for i = 1:numel(code)
    s = char(code(i));
    out = repmat(' ', 1, numel(s));
    quote = char(0);            % 0 = not in a string
    j = 1;
    while j <= numel(s)
        c = s(j);
        if quote ~= 0
            if c == quote
                if j + 1 <= numel(s) && s(j+1) == quote
                    j = j + 2;      % doubled quote: an escaped one
                    continue
                end
                quote = char(0);
            end
            j = j + 1;
            continue
        end
        if c == '%'
            break
        end
        if c == '"'
            quote = '"';
            j = j + 1;
            continue
        end
        if c == '''' && ~(j > 1 && (isletter(s(j-1)) ...
                || isstrprop(s(j-1), 'digit') ...
                || any(s(j-1) == ')]}._''')))
            quote = '''';
            j = j + 1;
            continue
        end
        out(j) = c;
        j = j + 1;
    end
    code(i) = string(out);
end
end

function out = codeKeepingStrings(lines)
%CODEKEEPINGSTRINGS  Drop comments, KEEP string literals.
%   The complement of STRIPCOMMENTS, and both are needed. Block-depth
%   counting must not see text inside quotes; identifier scanning must see
%   nothing else, because an error identifier is a string literal.
out = lines;
for i = 1:numel(out)
    s = char(out(i));
    quote = char(0);
    cut = numel(s) + 1;
    j = 1;
    while j <= numel(s)
        c = s(j);
        if quote ~= 0
            if c == quote
                if j + 1 <= numel(s) && s(j+1) == quote
                    j = j + 2; continue
                end
                quote = char(0);
            end
        elseif c == '%'
            cut = j; break
        elseif c == '"'
            quote = '"';
        elseif c == '''' && ~(j > 1 && (isletter(s(j-1)) ...
                || isstrprop(s(j-1), 'digit') ...
                || any(s(j-1) == ')]}._''')))
            quote = '''';
        end
        j = j + 1;
    end
    out(i) = string(s(1:cut-1));
end
end

function f = emptyFinding()
f = struct('check', {}, 'file', {}, 'line', {}, 'message', {});
end

function f = finding(check, file, line, msg, varargin)
f = struct('check', string(check), 'file', string(file), ...
           'line', double(line), ...
           'message', string(sprintf(msg, varargin{:})));
end

% ======================================================================
% Checks
% ======================================================================
function f = checkForbidden(files)
%CHECKFORBIDDEN  Toolbox-only and renderer-dependent calls inside +geo.
% geoMapRoot WAS ON THIS LIST AND IS NOT ANY MORE. Banning it by name
% was the narrow fix for PV-115, and a name-list can only forbid what
% somebody already thought of: geo.cache went on calling sha256OfText
% out of tools/ for eleven checkpoints (PV-127). packageClosure states
% the rule instead of enumerating its instances, and owns it alone,
% because one defect reported by two checks is F6 applied to the audit.
banned = ["range" "prctile" "caxis" "eval" "evalin" "assignin" ...
          "setappdata" "getappdata" "findobj" "light" "material" ...
          "shading"];
why = containers2( banned, [ ...
    "Statistics Toolbox (F1); the no-toolbox claim is the point" ...
    "Statistics Toolbox; use geo.quantile (F10)" ...
    "deprecated; use clim() (F11)" ...
    "defeats every static check in this file" ...
    "defeats every static check in this file" ...
    "defeats every static check in this file" ...
    "global mutable state (F15); use the layout manager" ...
    "global mutable state (F15); use the layout manager" ...
    "rediscovering a handle instead of returning it" ...
    "renderer-dependent output (F9, D-009)" ...
    "renderer-dependent output (F9, D-009)" ...
    "renderer-dependent output (F9, D-009)"]);
f = emptyFinding();
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    for b = banned
        hits = regexp(cellstr(files(i).code), ...
            "(?<![\w.])" + b + "\s*\(", 'once');
        idx = find(~cellfun(@isempty, hits));
        for k = idx(:)'
            f(end+1) = finding("forbiddenFunctions", files(i).rel, k, ...
                '%s() is banned inside +geo: %s', b, why(b)); %#ok<AGROW>
        end
    end
end
end

function f = checkPurity(files)
%CHECKPURITY  The Stage E hard rule, made mechanical.
%   An L4 FRONT is orchestration: it builds a map by calling public geo.*
%   elements in the documented z-order and owns no drawing of its own.
%   F8 is what happens when that erodes - geoImagesc grew to 3413 lines
%   because every new need was answered by one more inlined primitive,
%   and by the end nothing could be reused or tested in isolation.
%
%   The rule is worth having only because it is FALSIFIABLE. "Keep the
%   fronts thin" is not; "zero calls to surf, patch, line, text, scatter,
%   plot, colorbar, annotation, imagesc, image, fill, contour, rectangle
%   or quiver, and at most 200 executable lines" is, and this is where it
%   is decided rather than reviewed.
%
%   A file opts in by carrying the marker ALONE on a help line. Self-
%   declaration is deliberate: a check that GUESSED which files are
%   fronts would have to be taught every new one, and the teaching is
%   where a rule quietly stops applying.
%
%   WHY THE MARKER MUST BE THE WHOLE LINE. Written as a CONTAINS, the
%   check fired on +geo/export.m - a file that carries no marker and
%   merely EXPLAINS the rule in its help. That is the third time this
%   project has met the same shape: prose about a token is not the token.
%   The arrayGrowth check met it on the file describing why AGROW is
%   banned, and checkPrinting carries a comment about it. A mention is
%   not a declaration, and only a structural test - the line, stripped of
%   its comment character and trimmed, IS the marker - tells them apart.
%
%   Note also the lookbehind: geo.colorbar() is the whole point of the
%   rule and must pass, while a bare colorbar() must not.
banned = ["surf" "surface" "patch" "line" "text" "scatter" "scatter3" ...
          "plot" "plot3" "colorbar" "annotation" "imagesc" "image" ...
          "fill" "contour" "contourf" "rectangle" "quiver" ...
          "title" "xlabel" "ylabel" "legend" "sgtitle"];
budget = 200;
f = emptyFinding();
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    declared = strtrim(erase(files(i).lines, "%")) == "L4-FRONT";
    if ~any(declared), continue, end
    for b = banned
        hits = regexp(cellstr(files(i).code), ...
            "(?<![\w.])" + b + "\s*\(", 'once');
        idx = find(~cellfun(@isempty, hits));
        for k = idx(:)'
            f(end+1) = finding("orchestrationPurity", files(i).rel, k, ...
                ['%s() in an L4 front. A front orchestrates public ' ...
                 'geo.* elements and draws nothing itself; if this is ' ...
                 'needed, the missing capability belongs in an L3 ' ...
                 'element (F8).'], b); %#ok<AGROW>
        end
    end
    nCode = nnz(strlength(strtrim(files(i).code)) > 0);
    if nCode > budget
        f(end+1) = finding("orchestrationPurity", files(i).rel, 1, ...
            ['%d executable lines in an L4 front, over the %d-line ' ...
             'budget. Thickness here is F8 restarting.'], ...
            nCode, budget); %#ok<AGROW>
    end
end
end

function f = checkDocSync(root)
%CHECKDOCSYNC  The shipped manual describes the code that is here now.
%   A DOCUMENTATION PAGE DOES NOT ROT LOUDLY. It was correct when it was
%   built, it still renders, it still reads well, and it describes a
%   function that has since changed. Nothing in a test suite notices,
%   because the page is not code and the help is not executed. The only
%   thing that can notice is a comparison between the page and the
%   source it came from.
%
%   So docbuild/build_help.m embeds the SHA-256 of the help block each
%   page was built from, and this recomputes it. Prose cannot be
%   compared to prose; a hash can.
%
%   THE ABSENCE OF THE MANUAL IS NOT A FINDING. docs/html is a build
%   artefact, and a fresh clone that has not run the builder has no
%   pages to be stale. Reporting that as a defect would train people to
%   ignore this check. It reports only DISAGREEMENT: a page that exists
%   and no longer matches, or a page missing while its siblings are
%   present.
f = emptyFinding();
htmlDir = fullfile(root, "docs", "html");
if ~isfolder(htmlDir) || isempty(dir(fullfile(htmlDir, "geo_*.html")))
    return                              % never built here; not a defect
end
cp = fullfile(root, "Contents.m");
if ~isfile(cp), return, end

L = string(splitlines(fileread(cp)));
rows = regexp(L, '^%\s+(geo\.[\w.]+)\s+-\s', 'tokens', 'once');
rows = rows(~cellfun(@isempty, rows));
for k = 1:numel(rows)
    name = string(rows{k}{1});
    page = fullfile(htmlDir, replace(name, ".", "_") + ".html");
    if ~isfile(page)
        f(end+1) = finding("documentationSync", "docs/html", 0, ...
            ['%s is in the catalogue and has no page, while its ' ...
             'siblings do. Run docbuild/build_help.'], name); %#ok<AGROW>
        continue
    end
    want = currentHelpHash(name);
    got = regexp(string(fileread(page)), ...
        '<!--\s*helpsha256:\s*(\w+)\s*-->', 'tokens', 'once');
    if isempty(got)
        f(end+1) = finding("documentationSync", "docs/html", 0, ...
            ['%s''s page carries no help hash, so it cannot be shown ' ...
             'to match its source. Rebuild with the current builder.'], ...
            name); %#ok<AGROW>
        continue
    end
    if string(got{1}) ~= want
        f(end+1) = finding("documentationSync", "docs/html", 0, ...
            ['%s''s help has changed since its page was built. The ' ...
             'shipped manual describes a function that no longer ' ...
             'exists in that form. Run docbuild/build_help.'], ...
            name); %#ok<AGROW>
    end
end
end

function h = currentHelpHash(name)
%CURRENTHELPHASH  The same digest the builder computes, from the source.
h = "";
p = which(name);
if isempty(p), return, end
txt = string(splitlines(fileread(p)));
first = find(startsWith(strtrim(txt), "%"), 1);
if isempty(first), return, end
last = first;
while last < numel(txt) && startsWith(strtrim(txt(last + 1)), "%")
    last = last + 1;
end
lines = regexprep(txt(first:last), '^\s*%', '');
h = string(geo.internal.sha256OfText(char(regexprep(strjoin(lines, " "), '\s+', ' '))));
end

function f = checkShadowed(files)
%CHECKSHADOWED  A variable named after a builtin the project relies on.
%   F11: v1 named a variable clim, which shadowed clim() and forced the
%   deprecated caxis for the rest of the function.
%   And BLOCK KEYWORDS, which are a second and sharper problem. A
%   variable named methods, properties, events, enumeration or arguments
%   is legal MATLAB and runs correctly - but any text-level parser reads
%   the assignment as the start of a class block and loses its depth from
%   there. Measured: `methods = strings(1, n)` in +geo/export.m made
%   tools/mcheck.py report the file as unbalanced by three levels, with
%   two functions and a phantom methods block left unclosed, while MATLAB
%   itself ran the file without complaint. Two gates that read the source
%   differently (2.9) only pay for themselves if the disagreement is
%   treated as a finding, and the finding here is the variable name.
watched = ["clim" "range" "axis" "line" "text" "surf" "patch" "alpha" ...
           "length" "size" "max" "min" "sum" "figure" "plot" ...
           "methods" "properties" "events" "enumeration" "arguments"];
f = emptyFinding();
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    for w = watched
        pat = "^\s*" + w + "\s*=[^=]";
        hits = regexp(cellstr(files(i).code), pat, 'once');
        idx = find(~cellfun(@isempty, hits));
        for k = idx(:)'
            f(end+1) = finding("shadowedBuiltins", files(i).rel, k, ...
                ['"%s" is assigned as a variable and shadows the builtin ' ...
                 'of the same name for the rest of the function.'], w); %#ok<AGROW>
        end
    end
end
end

function f = checkArrayGrowth(files)
%CHECKARRAYGROWTH  Growth pragmas inside +geo.
%   Scoped to +geo deliberately (RECORDS R-003 note 6): the tooling in
%   tests/ and tools/ uses cell accumulators, which are O(1) amortised and
%   are the recommended form, not the banned one.
%
%   A PRAGMA FOLLOWS A STATEMENT; PROSE DOES NOT. The first version
%   searched raw lines for the literal, so the comment in
%   +geo/splitAntimeridian.m that EXPLAINS why the pragma is banned
%   tripped the ban. That is the same mistake in the other direction as
%   the forbidden-function check's: a word inside a comment is
%   documentation, not a call. The line must carry code before its
%   comment character for the pragma to be real.
f = emptyFinding();
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    idx = find(contains(files(i).lines, "%#ok<AGROW>"));
    for k = idx(:)'
        if strlength(strtrim(files(i).code(k))) == 0
            continue        % a comment about the pragma, not a pragma
        end
        f(end+1) = finding("arrayGrowth", files(i).rel, k, ...
            ['%%#ok<AGROW> inside +geo. F13: v1''s readers grew arrays ' ...
             'in the record loop, which is O(N^2) on a 180 MB file. ' ...
             'Accumulate into a cell and vertcat once.']); %#ok<AGROW>
    end
end
end

function f = checkPrinting(files)
%CHECKPRINTING  Library code must route diagnostics through one place.
f = emptyFinding();
for i = 1:numel(files)
    if ~files(i).inGeo || files(i).isLog, continue, end
    hits = regexp(cellstr(files(i).code), ...
        '(?<![\w.])(disp|fprintf)\s*\(', 'once');
    idx = find(~cellfun(@isempty, hits));
    for k = idx(:)'
        f(end+1) = finding("barePrinting", files(i).rel, k, ...
            ['bare print inside +geo. All diagnostics go through ' ...
             'geo.internal.log, so verbosity is one setting rather ' ...
             'than a search-and-replace.']); %#ok<AGROW>
    end
    % error/warning must carry a geo:<function>:<Reason> identifier.
    hits = regexp(cellstr(files(i).code), ...
        '(?<![\w.])(error|warning)\s*\(\s*[''"](?!geo:)', 'once');
    idx = find(~cellfun(@isempty, hits));
    for k = idx(:)'
        f(end+1) = finding("barePrinting", files(i).rel, k, ...
            ['error/warning without a geo:<function>:<Reason> ' ...
             'identifier. An unidentified error cannot be caught, ' ...
             'documented or tested.']); %#ok<AGROW>
    end
end
end

function f = checkIdentifiers(files)
%CHECKIDENTIFIERS  Every identifier is documented, and every documented
%   identifier exists. Both directions, PACKAGE-WIDE.
%
%   An identifier that appears in code but in no help block makes the
%   documentation a lie. One that appears in a help block but nowhere in
%   code makes a test that can never fail, which is worse, because it
%   reads as coverage.
%
%   WHY PACKAGE-WIDE RATHER THAN PER FILE, and this was learned the hard
%   way. The first version required each file to document exactly the
%   identifiers IT raised, matching only literals handed to error() or
%   warning(). Two legitimate patterns break that:
%
%     - a shared validator raises on its caller's behalf, so
%       geo:grid:NotAGrid is raised inside +internal/mustBeIdentity.m and
%       documented in grid.m, where a user will look for it;
%     - the identifier reaches error() through a VARIABLE, because the
%       caller passed it in - which is itself a repair for an earlier
%       version that composed identifiers out of a prefix and made them
%       invisible to any static reader.
%
%   Both were reported as "documented but never raised" while working
%   perfectly. The check now reads every identifier literal in the code
%   of +geo, wherever it sits in an argument list, and every identifier
%   in every help block, and requires the two SETS to match. It gives up
%   knowing which file owns which identifier; it keeps the two properties
%   that matter.
codeIds = strings(0, 1);
helpIds = strings(0, 1);
owner = dictionary(string.empty, string.empty);
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    % NOT files(i).code: that has string literals blanked out along with
    % the comments, and an error identifier IS a string literal, so
    % scanning it finds nothing at all. The healthy control caught this
    % immediately - it reported its own documented identifier as never
    % raised, while the raise sat three lines below.
    ids = string(regexp(strjoin(codeKeepingStrings(files(i).lines), ...
        newline), 'geo:[\w]+:[\w]+', 'match'));
    codeIds = [codeIds; ids(:)]; %#ok<AGROW> one append per file
    hids = string(regexp(strjoin(extractHelp(files(i).lines), newline), ...
        'geo:[\w]+:[\w]+', 'match'));
    helpIds = [helpIds; hids(:)]; %#ok<AGROW>
    for k = 1:numel(hids)
        if ~isKey(owner, hids(k))
            owner(hids(k)) = files(i).rel;
        end
    end
end

f = emptyFinding();
codeSet = unique(codeIds);
helpSet = unique(helpIds);

undocumented = setdiff(codeSet, helpSet);
for j = 1:numel(undocumented)
    f(end+1) = finding("identifierAgreement", "+geo", 0, ...
        ['%s is raised somewhere in +geo but documented in no ERRORS ' ...
         'block. Help that omits an error is help that lies by ' ...
         'silence.'], undocumented(j)); %#ok<AGROW>
end
unraised = setdiff(helpSet, codeSet);
for j = 1:numel(unraised)
    f(end+1) = finding("identifierAgreement", owner(unraised(j)), 0, ...
        ['%s is documented but appears nowhere in the code of +geo. A ' ...
         'test asserting it can never fail, which reads as coverage ' ...
         'and is not.'], unraised(j)); %#ok<AGROW>
end
end

function f = checkIdentifiersUnused(files) %#ok<DEFNU>
%CHECKIDENTIFIERSUNUSED  Superseded per-file form, kept unreachable.
%   Frozen rather than deleted: it is the record of what the check was
%   before delegation broke it, and the reason the current one is
%   package-wide (handover 2.2, superseded scripts are frozen).
f = emptyFinding();
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    raised = unique(string(regexp(files(i).text, ...
        '(?<=(error|warning)\s*\(\s*[''"])geo:[\w]+:[\w]+', 'match')));
    helpBlock = extractHelp(files(i).lines);
    documented = unique(string(regexp(strjoin(helpBlock, newline), ...
        'geo:[\w]+:[\w]+', 'match')));
    % Indexed, not "for id = setdiff(...)". A for-loop iterates over
    % COLUMNS, and setdiff returns an EMPTY COLUMN vector - which has one
    % column of height zero, so the loop body runs once with an empty
    % value. That produced two findings against a file with no
    % identifiers at all, on the healthy control, which is exactly the
    % false positive the control exists to catch.
    undocumented = setdiff(raised, documented);
    for j = 1:numel(undocumented)
        f(end+1) = finding("identifierAgreement", files(i).rel, 0, ...
            ['%s is raised but not documented in the ERRORS block. ' ...
             'Help that lies is worse than help that is absent.'], ...
            undocumented(j)); %#ok<AGROW>
    end
    unraised = setdiff(documented, raised);
    for j = 1:numel(unraised)
        f(end+1) = finding("identifierAgreement", files(i).rel, 0, ...
            ['%s is documented but never raised. A test asserting it ' ...
             'can never fail, which reads as coverage and is not.'], ...
            unraised(j)); %#ok<AGROW>
    end
end
end

function f = checkHelp(files)
%CHECKHELP  Handover 2.8.1, reading the WHOLE block.
%   Reading only the first line was one of two blind spots that let a
%   documentation gate stay green in a reference project while the
%   documentation was wrong.
required = ["SYNTAX" "DESCRIPTION" "INPUTS" "OUTPUTS" "ACCURACY" ...
            "ERRORS" "EXAMPLE" "See also"];
f = emptyFinding();
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    blk = strjoin(extractHelp(files(i).lines), newline);
    if strlength(strtrim(blk)) == 0
        f(end+1) = finding("helpTemplate", files(i).rel, 1, ...
            'no help block at all.'); %#ok<AGROW>
        continue
    end
    for s = required
        if ~contains(blk, "%   " + s)
            f(end+1) = finding("helpTemplate", files(i).rel, 1, ...
                ['help block has no %s section (handover 2.8.1). The ' ...
                 'Stage F doc builder parses these headers, so a ' ...
                 'missing one is a page that will not render.'], s); %#ok<AGROW>
        end
    end
end
end

function f = checkLength(files, root)
%CHECKLENGTH  D-003's 400-line rule.
%   The escape hatch is deliberately awkward: the justification must be
%   written into HANDOVER.md, where a reviewer sees it, not into a comment
%   beside the code, where the author is the only reader.
limit = 400;
f = emptyFinding();
hp = fullfile(root, "HANDOVER.md");
handover = "";
if isfile(hp)
    handover = string(fileread(hp));
end
for i = 1:numel(files)
    fns = functionSpans(files(i).code);
    for k = 1:numel(fns)
        n = fns(k).last - fns(k).first + 1;
        if n <= limit, continue, end
        marker = "LENGTH-JUSTIFIED: " + fns(k).name;
        if contains(handover, marker), continue, end
        f(end+1) = finding("functionLength", files(i).rel, fns(k).first, ...
            ['%s is %d lines, over the %d-line rule (D-003), with no ' ...
             'justification in HANDOVER.md. Add a line containing ' ...
             '"%s" there, or split the function.'], ...
            fns(k).name, n, limit, marker); %#ok<AGROW>
    end
end
end

function f = checkArity(files)
%CHECKARITY  Public +geo functions take at most three positional arguments.
%   F7: geoNorthArrow took fifteen, so a caller who got one wrong had no
%   way to find out which.
limit = 3;
f = emptyFinding();
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    fns = functionSpans(files(i).code);
    if isempty(fns), continue, end
    main = fns(1);                      % the file's public entry point
    args = main.args;
    args(args == "varargin" | args == "options" | args == "opts") = [];
    if numel(args) > limit
        f(end+1) = finding("positionalArity", files(i).rel, main.first, ...
            ['%s takes %d positional arguments (limit %d). Options ' ...
             'belong in an arguments block as name-value pairs, where ' ...
             'they validate and name themselves.'], ...
            main.name, numel(args), limit); %#ok<AGROW>
    end
end
end

function f = checkDuplicates(files)
%CHECKDUPLICATES  The same local function body in two files.
%   F6: six locals duplicated across v1's main plotters, so the next
%   repair had to be applied six times and was applied five.
% Two parallel dictionaries rather than one holding a composed value.
% Handover 2.7: nothing recovers a fact by taking a substring of a
% composed value, so the owning function's name and its file are stored as
% themselves and never as "name|file" split apart at the consumer.
seenName = configureDictionary("string", "string");
seenFile = configureDictionary("string", "string");
f = emptyFinding();
for i = 1:numel(files)
    fns = functionSpans(files(i).code);
    for k = 2:numel(fns)                % 1 is the entry point, not a local
        key = normaliseBody(files(i).code(fns(k).first:fns(k).last));
        if strlength(key) < 60, continue, end    % too small to be a clone
        if isKey(seenName, key)
            f(end+1) = finding("duplicateLocalFunctions", files(i).rel, ...
                fns(k).first, ...
                ['local function %s is identical (ignoring comments and ' ...
                 'whitespace) to %s in %s. One owner per fact: promote ' ...
                 'it to +geo/+internal.'], ...
                fns(k).name, seenName(key), seenFile(key)); %#ok<AGROW>
        else
            seenName(key) = fns(k).name;
            seenFile(key) = files(i).rel;
        end
    end
end
end

function f = checkVersion(root)
%CHECKVERSION  Contents.m is the authority; everything else is checked.
%   A version maintained in two places is a version that will disagree
%   with itself, and the disagreement surfaces at release.
f = emptyFinding();
cp = fullfile(root, "Contents.m");
if ~isfile(cp)
    f = finding("versionAgreement", "Contents.m", 0, ...
        ['Contents.m is absent, so the version has no authority. This ' ...
         'is Stage F deliverable 6 and is DEFERRED, not passed: a gate ' ...
         'that cannot find its subject must say so rather than stay ' ...
         'silent.']);
    return
end
tok = regexp(string(fileread(cp)), ...
    '^%\s*Version\s+(\S+)', 'tokens', 'once', 'lineanchors');
if isempty(tok)
    f = finding("versionAgreement", "Contents.m", 0, ...
        'Contents.m carries no "%% Version X.Y.Z" line.');
    return
end
authority = string(tok{1});
others = ["README.md" "CHANGELOG.md" "geoMap.prj" "info.xml" ...
          "CITATION.cff"];
for o = others
    p = fullfile(root, o);
    if ~isfile(p), continue, end
    for v = versionsDeclaredIn(string(fileread(p)))
        if v == authority, continue, end
        f(end+1) = finding("versionAgreement", o, 0, ...
            ['%s names version %s; Contents.m is the authority and says ' ...
             '%s. One authority per fact: a version maintained in two ' ...
             'places disagrees with itself at release.'], ...
            o, v, authority); %#ok<AGROW>
    end
end
end

function v = versionsDeclaredIn(txt)
%VERSIONSDECLAREDIN  Version DECLARATIONS only, never a bare dotted triple.
%   A bare \d+\.\d+\.\d+ also matches "PROJ 9.5.1" and "pyproj 3.7.2",
%   which appear all over this project's prose, and a check that fires on
%   its own dependency list is a check people learn to skip.
%
%   "cff-version" is excluded explicitly: it declares the CITATION file
%   FORMAT's version, not this software's, and the two are different facts
%   that happen to share a word.
pat = ["(?<!cff-)[Vv]ersion:?\s+""?(\d[\w.\-]*)", ...
       "(?<![\w.])v(\d+\.\d+\.\d+[\w.\-]*)"];
v = strings(1, 0);
for k = 1:numel(pat)
    t = regexp(txt, pat(k), 'tokens');
    for j = 1:numel(t)
        v(end+1) = string(t{j}{1}); %#ok<AGROW>
    end
end
v = unique(erase(v, """"));
v = v(strlength(v) > 0);
end

function f = checkContractExemption(files, root)
%CHECKCONTRACTEXEMPTION  contract may never be exempted for a function
%   that validates its arguments.
%   Argument validation runs before the body, so a rejected call is
%   refutable in microseconds however expensive a successful one is. Two
%   exemptions in a reference project reasoned from an expensive SUCCESS
%   to an impossible test and were wrong when written.
f = emptyFinding();
p = fullfile(root, "tests", "EXEMPTIONS.md");
if ~isfile(p), return, end
lines = string(splitlines(string(fileread(p))));
for i = 1:numel(lines)
    if ~startsWith(strtrim(lines(i)), "|"), continue, end
    parts = strtrim(split(lines(i), "|"));
    parts(parts == "") = [];
    if numel(parts) < 3 || parts(2) ~= "contract", continue, end
    j = find([files.name] == parts(1), 1);
    if isempty(j), continue, end
    if any(strtrim(files(j).code) == "arguments")
        f(end+1) = finding("contractExemption", "tests/EXEMPTIONS.md", ...
            i, ['contract is exempted for %s, which has an arguments ' ...
                'block. An exemption is a claim that the test is ' ...
                'impossible, not that it is inconvenient.'], parts(1)); %#ok<AGROW>
    end
end
end

function f = checkCodeAnalyzer(files)
%CHECKCODEANALYZER  MATLAB's own reader, over the whole tree.
%   This is the check that reads what tools/mcheck.py cannot. It found
%   three stale AGROW pragmas the Python checker was structurally blind to
%   (RECORDS R-004). Errors block; warnings are reported but do not, since
%   the Code Analyzer's warning set is not this project's rule set.
f = emptyFinding();
if exist('codeIssues', 'file') ~= 2
    return                      % pre-R2023a: the other eleven checks stand
end
for i = 1:numel(files)
    try
        iss = codeIssues(files(i).path);
    catch
        continue
    end
    t = iss.Issues;
    if isempty(t), continue, end
    isErr = t.Severity == "error";
    for k = find(isErr)'
        f(end+1) = finding("codeAnalyzer", files(i).rel, ...
            t.LineStart(k), 'Code Analyzer error %s: %s', ...
            string(t.CheckID(k)), string(t.Description(k))); %#ok<AGROW>
    end
end
end

% ======================================================================
% Parsing helpers
% ======================================================================
function h = extractHelp(lines)
%EXTRACTHELP  The contiguous comment block after the first signature.
% (?![\w]) and not \b: MATLAB's regexp does NOT implement \b as a word
% boundary - it is the backspace escape, so '^\s*function\b' matches
% nothing and matches it SILENTLY. Measured here rather than recalled:
% the pattern with \b returned no match on the string
% "function y = healthy(x, options)" while the same pattern without it
% matched at index 1. The symptom was every help block reported absent,
% including on the healthy control, which is what caught it.
h = strings(0, 1);
first = find(~cellfun(@isempty, regexp(cellstr(lines), ...
    '^\s*(function|classdef)(?![\w])', 'once')), 1);
if isempty(first), return, end
i = first + 1;
while i <= numel(lines) && startsWith(strtrim(lines(i)), "%")
    h(end+1, 1) = lines(i); %#ok<AGROW>
    i = i + 1;
end
end

function s = functionSpans(code)
%FUNCTIONSPANS  Name, argument list and line span of every function.
%   Spans are derived from block depth, not from "the next function
%   keyword": a nested if/for containing the word would otherwise end the
%   span early and every length claim after it would be wrong.
%
%   EVERY keyword on the line is counted, not just the first. The first
%   draft read only the leading word, and MATLAB's one-line form
%   "if cond, continue, end" then opened a block it never closed: depth
%   drifted upward and every function after the first was reported as
%   running to the end of the file. GeoMapTestCase.seedRandom, four lines
%   long, was reported at 404. A length rule fed by a depth counter that
%   never returns is not a strict rule, it is a random one.
s = struct('name', {}, 'args', {}, 'first', {}, 'last', {});
openers = ["function" "if" "for" "parfor" "while" "switch" "try" ...
           "arguments" "spmd" "classdef" "methods" "properties" ...
           "enumeration" "events"];
depth = 0;
stack = [];         % indices into s, innermost last
openDepth = [];     % the depth each open function was declared at
for i = 1:numel(code)
    toks = lineKeywords(code(i), [openers "end"]);
    for t = 1:numel(toks)
        tok = toks(t);
        if tok == "function"
            [nm, ar] = parseSignature(code(i));
            s(end+1) = struct('name', nm, 'args', {ar}, ...
                'first', i, 'last', numel(code)); %#ok<AGROW>
            stack(end+1) = numel(s);      %#ok<AGROW>
            openDepth(end+1) = depth;     %#ok<AGROW>
            depth = depth + 1;
        elseif any(tok == openers)
            depth = depth + 1;
        else                              % "end"
            depth = depth - 1;
            if ~isempty(stack) && depth == openDepth(end)
                s(stack(end)).last = i;
                stack(end) = [];
                openDepth(end) = [];
            end
        end
    end
end
end

function f = checkPackageClosure(files, root)
%CHECKPACKAGECLOSURE  +geo must stand alone: nothing in it may call the
%   harness.
%
%   THIS DEFECT IS INVISIBLE FROM INSIDE THE REPOSITORY. Developing here,
%   geoMapSetup puts tests/, tools/, records/ and docbuild/ on the path,
%   so a call from +geo into any of them resolves, every test passes and
%   CI is green. The .mltbx ships +geo, data and docs/html and nothing
%   else, so the same call is an Undefined function error for every
%   person who installs the toolbox. Green CI is not evidence about the
%   thing that ships, because CI never runs the thing that ships.
%
%   It has now happened twice. PV-115 was geo.readGrid reaching for
%   geoMapRoot to find its data; the fix banned that ONE NAME, which is
%   why PV-127 - geo.cache calling sha256OfText out of tools/, on the
%   path that draws any coastline - survived eleven more checkpoints
%   underneath it. A list of forbidden names can only forbid the
%   instances somebody already thought of. So this states the rule: the
%   package's dependencies stay inside the package.
%
%   HOW IT READS THE TREE, and why not with dependency analysis.
%   matlab.codetools.requiredFilesAndProducts gives the exact closure and
%   is what found PV-127, but it resolves names against the LIVE PATH, so
%   pointed at a fixture tree it would answer about the real +geo instead
%   - the instrument could not then be proved on a planted defect, and
%   handover 2.9 forbids trusting a structure claim from an instrument
%   never seen to fire. This reads the tree: every .m outside +geo is a
%   name +geo may not use unqualified. Exact for the failure mode that
%   has actually occurred twice, and provable on a fixture.
f = emptyFinding();
outside = harnessNames(root);
for i = 1:numel(files)
    if ~files(i).inGeo, continue, end
    for b = outside
        % No dot in front: geo.internal.sha256OfText is the CORRECT form
        % and must not be reported. No word character behind: a call, a
        % bare reference and @handle all count, because all three break
        % the same way, and requiring "(" is how a handle would escape.
        hits = regexp(cellstr(files(i).code), ...
            "(?<![\w.])" + b + "(?![\w])", 'once');
        idx = find(~cellfun(@isempty, hits));
        for k = idx(:)'
            f(end+1) = finding("packageClosure", files(i).rel, k, ...
                ['%s lives outside +geo and is not shipped in the ' ...
                 'toolbox, so this resolves here and is undefined on ' ...
                 'an installed copy (PV-127). Move it into ' ...
                 '+geo/+internal, or do not call it.'], b); %#ok<AGROW>
        end
    end
end
end

function names = harnessNames(root)
%HARNESSNAMES  Every .m in the repository that the .mltbx does not ship.
%   The folder list is geoMap.prj's exclude filter, which is the file that
%   actually decides what a user receives; keeping a second list here
%   would let the two disagree, and the disagreement would only show up
%   after somebody installed the result.
names = strings(1, 0);
d = dir(fullfile(root, "*.m"));                  % root scripts and runners
for k = 1:numel(d)
    names(end+1) = string(erase(d(k).name, ".m")); %#ok<AGROW>
end
for folder = ["tests" "tools" "records" "docbuild"]
    p = fullfile(root, folder);
    if ~isfolder(p), continue, end
    d = dir(fullfile(p, "**", "*.m"));
    for k = 1:numel(d)
        names(end+1) = string(erase(d(k).name, ".m")); %#ok<AGROW>
    end
end
names = unique(names);
end

function toks = lineKeywords(line, words)
%LINEKEYWORDS  Keywords on one line, at BRACKET depth zero, in order.
%   Bracket depth is what separates the `end` that closes a block from the
%   `end` in f(end+1), which is an index and closes nothing. Without that
%   distinction every accumulator in the tree would look like a stray
%   block terminator.
c = char(line);
toks = strings(1, 0);
b = 0;
i = 1;
while i <= numel(c)
    ch = c(i);
    if any(ch == '([{')
        b = b + 1; i = i + 1; continue
    elseif any(ch == ')]}')
        b = b - 1; i = i + 1; continue
    elseif isletter(ch)
        j = i;
        while j <= numel(c) && (isletter(c(j)) || isstrprop(c(j), 'digit') ...
                || c(j) == '_')
            j = j + 1;
        end
        w = string(c(i:j-1));
        prev = "";
        if i > 1, prev = string(c(i-1)); end
        if b == 0 && any(w == words) && prev ~= "." && prev ~= "@"
            toks(end+1) = w; %#ok<AGROW>
        end
        i = j; continue
    end
    i = i + 1;
end
end

function [nm, ar] = parseSignature(line)
%PARSESIGNATURE  Function name and its positional argument names.
m = regexp(line, ...
    '^\s*function\s+(?:\[?[^=\]]*\]?\s*=\s*)?([\w\.]+)\s*\(?([^)]*)', ...
    'tokens', 'once');
nm = "";
ar = strings(0, 1);
if isempty(m), return, end
nm = strtrim(string(m{1}));
a = strtrim(split(string(m{2}), ","));
a(a == "") = [];
ar = a;
end

function b = normaliseBody(lines)
%NORMALISEBODY  Comments and whitespace removed, so a clone is visible
%   through cosmetic edits. Not through a renamed variable - that is a
%   deliberate limit, stated rather than papered over.
b = join(strtrim(lines(strtrim(lines) ~= "")), ";");
b = regexprep(b, '\s+', '');
end

function d = containers2(keys, vals)
d = dictionary(keys, vals);
end

% ======================================================================
% Self-test
% ======================================================================
function [ok, report] = runSelfTest(verbose)
%RUNSELFTEST  Every check fires on its own defect, and none on the control.
reg = geoMapAuditFixtures("list");
ok = true;
lines = strings(0, 1);
for i = 1:numel(reg)
    d = geoMapAuditFixtures("build", reg(i).name);
    c = onCleanup(@() geoMapAuditFixtures("clean", d));
    [~, f] = geoMapAudit(d, SelfTest = false, Verbose = false);
    fired = unique([f.check]);
    if reg(i).check == ""
        good = isempty(fired);
        lines(end+1, 1) = sprintf('  control          %s%s', ...
            tick(good), fired2str(fired)); %#ok<AGROW>
    else
        good = any(fired == reg(i).check);
        lines(end+1, 1) = sprintf('  %-24s %s', reg(i).check, tick(good)); %#ok<AGROW>
    end
    ok = ok && good;
    clear c
end
if verbose
    fprintf('%s\n', strjoin(lines, newline));
end
report = sprintf('%d fixtures, %s', numel(reg), ...
    ternary(ok, 'every check proved', ...
        'A CHECK IS NOT PROVED - its claims are void'));
if ~ok
    error('geo:audit:SelfTestFailed', ...
        ['%s. A check that does not fire on its own broken fixture is ' ...
         'not a check, and a check that fires on the healthy control ' ...
         'is worse.'], report);
end
end

function s = fired2str(fired)
if isempty(fired)
    s = '';
else
    s = sprintf(' (fired: %s)', strjoin(fired, ', '));
end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

function s = tick(c)
s = ternary(c, 'ok', 'FAILED');
end
