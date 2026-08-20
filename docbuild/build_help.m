function report = build_help(options)
%BUILD_HELP  Render the toolbox help into HTML, and count what it rendered.
%
%   SYNTAX
%     report = BUILD_HELP()
%     report = BUILD_HELP(OutDir = "docs/html", Verbose = false)
%
%   DESCRIPTION
%     Parses every public function's help block into structured HTML:
%     one page per function with typed input, option and output tables,
%     the ACCURACY block, the ERRORS block, a highlighted example and
%     resolved See-also links; one index grouped by layer; a projection
%     guide; and a GRACE workflow tutorial.
%
%     IT COUNTS COMPLETENESS IN THE ARTEFACT, NOT IN THE MODEL, and that
%     is the whole reason this function returns a report. A reference
%     project parsed argument descriptions into its documentation model
%     for years while the renderer never read the field; every audit
%     stayed green, because there was no text anywhere to disagree with
%     (handover F1). A builder that reports "42 of 42 arguments
%     documented" from its own parse tree is reporting on its parser.
%     So after each page is WRITTEN, it is read back off disk and the
%     documented names are counted where they actually appear, inside a
%     table cell. Rendered is the number that can be wrong.
%
%     EVERY EXAMPLE IS LINTED AT BUILD TIME. The EXAMPLE block is
%     extracted, written to a scratch file and passed to MATLAB's own
%     Code Analyzer. An example that does not parse is documentation
%     that will be copied and pasted into a session and fail there.
%
%     THE LAYER GROUPING COMES FROM CONTENTS.M, which is the catalogue
%     authority and is asserted against every function's H1. Reading it
%     here rather than restating it means the index cannot disagree with
%     the contents file, and neither can disagree with the code.
%
%   INPUTS
%     (none)
%
%   OPTIONS
%     OutDir   "docs/html"  Where the pages are written. Created if
%                           absent; existing .html files are replaced.
%     Verbose  false        Print a line per page.
%
%   OUTPUTS
%     report  (1,1) struct  Fields:
%       Functions      (1,1) double  Pages written.
%       ArgsDocumented (1,1) double  Names parsed out of the help blocks.
%       ArgsRendered   (1,1) double  Names found in the WRITTEN HTML.
%       Completeness   (1,1) double  Rendered / documented, in [0, 1].
%       BrokenLinks    (1,:) string  See-also targets that resolve to
%                                    no page and no MATLAB function.
%       BadExamples    (1,:) string  Functions whose EXAMPLE does not
%                                    parse.
%       MissingSections (1,:) string  "function: SECTION" for each
%                                    required header not found.
%       OutDir         (1,1) string
%
%   ACCURACY
%     Completeness is a count of strings found in files on disk, so it
%     is exact. It is not a judgement of whether the documentation is
%     GOOD - nothing automated can be - and the report says how many
%     names were rendered, never that the prose is right.
%
%   ERRORS
%     geo:docbuild:NoContents - Contents.m absent, so there is no
%                               catalogue authority to group by
%     geo:docbuild:MalformedHelp - a function whose help block cannot be
%                               parsed at all; the build FAILS rather
%                               than skipping the page
%
%   EXAMPLE
%     report = build_help();
%     fprintf('%.1f%% rendered\n', 100 * report.Completeness);
%
%   LIMITATIONS
%     The parser relies on the fixed headers of handover 2.8.1, which
%     the audit enforces, so it is not a general MATLAB help parser and
%     does not try to be. It does not execute the examples; it parses
%     them. Executing every example would need data files the toolbox
%     does not ship.
%
%   See also GEOMAPAUDIT, CONTENTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    options.OutDir (1,1) string = ""
    options.Verbose (1,1) logical = false
end

root = docRoot();
outDir = options.OutDir;
if outDir == ""
    outDir = fullfile(root, "docs", "html");
end
if ~isfolder(outDir)
    mkdir(outDir);
end

groups = layersFromContents(root);
report = struct('Functions', 0, 'ArgsDocumented', 0, 'ArgsRendered', 0, ...
    'Completeness', 1, 'BrokenLinks', strings(1, 0), ...
    'BadExamples', strings(1, 0), 'MissingSections', strings(1, 0), ...
    'OutDir', outDir);

allNames = [groups.Functions];
for name = allNames
    page = renderOne(name, allNames, outDir);
    report.Functions = report.Functions + 1;
    report.ArgsDocumented = report.ArgsDocumented + page.Documented;
    report.ArgsRendered = report.ArgsRendered + page.Rendered;
    report.BrokenLinks = [report.BrokenLinks, page.Broken];
    report.BadExamples = [report.BadExamples, page.BadExample];
    report.MissingSections = [report.MissingSections, page.Missing];
    if options.Verbose
        fprintf('  %-22s %d/%d arguments rendered\n', name, ...
            page.Rendered, page.Documented);
    end
end

writeText(fullfile(outDir, "index.html"), indexPage(groups));
writeText(fullfile(outDir, "projections.html"), projectionGuide());
writeText(fullfile(outDir, "grace_workflow.html"), graceWorkflow());
% THE TOC IS GENERATED FROM THE SAME GROUPING as the index, so the Help
% browser tree and the index page cannot disagree - and neither can
% disagree with Contents.m, which is where both came from.
writeText(fullfile(outDir, "helptoc.xml"), tocXml(groups));

if report.ArgsDocumented > 0
    report.Completeness = report.ArgsRendered / report.ArgsDocumented;
end
end

% ======================================================================
% Sources of truth
% ======================================================================
function r = docRoot()
%DOCROOT  The repository root, from this file's own location.
r = string(fileparts(fileparts(mfilename('fullpath'))));
end

function groups = layersFromContents(root)
%LAYERSFROMCONTENTS  The catalogue's own grouping, not a second copy.
p = fullfile(root, "Contents.m");
if ~isfile(p)
    error('geo:docbuild:NoContents', ...
        ['Contents.m is the catalogue authority and is absent, so the ' ...
         'index has nothing to group by.']);
end
L = string(splitlines(fileread(p)));
groups = struct('Name', {}, 'Functions', {});
current = "";
for k = 1:numel(L)
    head = regexp(L(k), '^%\s{3}(L\d[^\n]*|Compatibility)\s*$', 'tokens', 'once');
    if ~isempty(head)
        current = strtrim(string(head{1}));
        groups(end + 1) = struct('Name', current, ...
            'Functions', strings(1, 0));                    %#ok<AGROW>
        continue
    end
    row = regexp(L(k), '^%\s+(geo\.[\w.]+)\s+-\s', 'tokens', 'once');
    if ~isempty(row) && ~isempty(groups)
        groups(end).Functions(end + 1) = string(row{1});
    end
end
end

% ======================================================================
% One function page
% ======================================================================
function page = renderOne(name, allNames, outDir)
%RENDERONE  Write the page, then READ IT BACK and count what is in it.
help = helpLines(name);
S = sections(help);
page.Missing = missingSections(name, S);

[inRows, inNames] = argRows(S, "INPUTS");
[optRows, optNames] = argRows(S, "OPTIONS");
[outRows, outNames] = argRows(S, "OUTPUTS");
documented = unique([inNames, optNames, outNames]);

[seeHtml, broken] = seeAlso(S, allNames);
page.Broken = broken;
[exHtml, badExample] = exampleBlock(S, name);
page.BadExample = badExample;

html = functionPage(name, S, inRows, optRows, outRows, seeHtml, exHtml);
% THE HASH OF THE HELP BLOCK THIS PAGE WAS BUILT FROM. It is what makes
% staleness detectable at all: a page whose source help has since been
% edited is a page that LIES, and it lies plausibly, because it was
% correct when it was written. Comparing rendered prose to source prose
% is guesswork; comparing a hash is not.
html = html + newline + "<!-- helpsha256: " + helpHash(help) + " -->";
file = fullfile(outDir, pageName(name));
writeText(file, html);

% THE COUNT THAT MATTERS. Read from the file, not from the variables
% above: a name that the renderer dropped is absent here and present in
% every model the builder holds (F1).
written = string(fileread(file));
page.Documented = numel(documented);
page.Rendered = nnz(arrayfun(@(n) isRenderedIn(written, n), documented));
end

function h = helpHash(lines)
%HELPHASH  A stable digest of a help block.
%   Whitespace-normalised so that reflowing a paragraph does not read as
%   a content change, and so the same source gives the same hash on
%   every platform whatever its line endings.
h = string(sha256OfText(char(regexprep(strjoin(lines, " "), '\s+', ' '))));
end

function tf = isRenderedIn(html, name)
%ISRENDEREDIN  The name appears inside a table cell of the written page.
tf = ~isempty(regexp(html, "<td[^>]*>\s*<code>" + regexptranslate('escape', name) + ...
    "</code>", 'once'));
end

function html = functionPage(name, S, inRows, optRows, outRows, seeHtml, exHtml)
parts = strings(1, 0);
parts(end+1) = pageHead(name);
parts(end+1) = "<h1>" + esc(name) + "</h1>";
parts(end+1) = "<p class=""h1line"">" + esc(firstLine(S)) + "</p>";
parts(end+1) = block("Syntax", "<pre class=""syntax"">" + ...
    esc(joinLines(S, "SYNTAX")) + "</pre>");
parts(end+1) = block("Description", paragraphs(joinLines(S, "DESCRIPTION")));
parts(end+1) = argTable("Inputs", ["Argument" "Type" "Description"], inRows);
parts(end+1) = argTable("Options", ["Option" "Default" "Description"], optRows);
parts(end+1) = argTable("Outputs", ["Output" "Type" "Description"], outRows);
parts(end+1) = block("Accuracy", "<div class=""accuracy"">" + ...
    paragraphs(joinLines(S, "ACCURACY")) + "</div>");
parts(end+1) = block("Errors", errorList(joinLines(S, "ERRORS")));
parts(end+1) = block("Example", exHtml);
parts(end+1) = block("Limitations", paragraphs(joinLines(S, "LIMITATIONS")));
parts(end+1) = block("See also", seeHtml);
parts(end+1) = pageFoot();
html = strjoin(parts, newline);
end

% ======================================================================
% Help parsing
% ======================================================================
function L = helpLines(name)
%HELPLINES  The help block of a function, as comment-stripped lines.
p = which(name);
if isempty(p)
    error('geo:docbuild:MalformedHelp', ...
        '%s is listed in Contents.m and cannot be found.', name);
end
txt = string(splitlines(fileread(p)));
first = find(startsWith(strtrim(txt), "%"), 1);
if isempty(first)
    error('geo:docbuild:MalformedHelp', '%s has no help block.', name);
end
last = first;
while last < numel(txt) && startsWith(strtrim(txt(last + 1)), "%")
    last = last + 1;
end
L = regexprep(txt(first:last), '^\s*%', '');
end

function S = sections(L)
%SECTIONS  Split the help at its fixed headers (handover 2.8.1).
known = ["SYNTAX" "DESCRIPTION" "INPUTS" "OPTIONS" "OUTPUTS" ...
         "ACCURACY" "ERRORS" "EXAMPLE" "LIMITATIONS" "See also"];
S = struct('First', "", 'Names', strings(1, 0), 'Bodies', {{}});
if isempty(L)
    return
end
S.First = strtrim(regexprep(L(1), '^\S*\s+', ''));
current = "";
body = strings(1, 0);
for k = 2:numel(L)
    % THE SEPARATOR ENDS THE HELP. Without this the last section - which
    % is always "See also" - swallowed the version footer, and the
    % See-also resolver then handed "Claude Opus 5 (Anthropic)" to
    % WHICH, which tries command syntax on it and raises. A parser that
    % has no terminator reads until it runs out, and what it reads last
    % is whatever happens to be there.
    if ~isempty(regexp(L(k), '^\s*-{10,}\s*$', 'once'))
        break
    end
    hit = "";
    for h = known
        if strtrim(L(k)) == h || startsWith(L(k), "   " + h)
            hit = h;
            break
        end
    end
    if hit ~= ""
        if current ~= ""
            S.Names(end + 1) = current;
            S.Bodies{end + 1} = body;
        end
        current = hit;
        body = strings(1, 0);
        if hit == "See also"
            body(end + 1) = strtrim(erase(L(k), "   See also"));
        end
        continue
    end
    if current ~= ""
        body(end + 1) = L(k);                              %#ok<AGROW>
    end
end
if current ~= ""
    S.Names(end + 1) = current;
    S.Bodies{end + 1} = body;
end
end

function s = firstLine(S)
s = S.First;
end

function txt = joinLines(S, name)
idx = find(S.Names == name, 1);
if isempty(idx)
    txt = "";
    return
end
txt = strjoin(S.Bodies{idx}, newline);
end

function miss = missingSections(name, S)
required = ["SYNTAX" "DESCRIPTION" "INPUTS" "OUTPUTS" "ACCURACY" ...
            "ERRORS" "EXAMPLE" "See also"];
miss = strings(1, 0);
for r = required
    if ~any(S.Names == r)
        miss(end + 1) = name + ": " + r;                   %#ok<AGROW>
    end
end
end

function [rows, names] = argRows(S, section)
%ARGROWS  Name, type-or-default, description - one row per argument.
%   A continuation line is one indented further than the name it belongs
%   to, and is appended to that row's description rather than becoming a
%   row of its own. Written the other way round, the tables filled with
%   half-sentences that looked like undocumented arguments.
rows = strings(0, 3);
names = strings(1, 0);
body = joinLines(S, section);
if strlength(body) == 0
    return
end
L = string(splitlines(body));
for k = 1:numel(L)
    if strlength(strtrim(L(k))) == 0, continue, end
    m = regexp(L(k), '^\s{4,7}(\w+)\s\s+(.*)$', 'tokens', 'once');
    if isempty(m)
        if ~isempty(rows)
            rows(end, 3) = strtrim(rows(end, 3) + " " + strtrim(L(k)));
        end
        continue
    end
    nm = string(m{1});
    rest = strtrim(string(m{2}));
    [ty, desc] = splitTypeAndDescription(rest);
    rows(end + 1, :) = [nm, ty, desc];                     %#ok<AGROW>
    names(end + 1) = nm;                                   %#ok<AGROW>
end
end

function [ty, desc] = splitTypeAndDescription(rest)
%SPLITTYPEANDDESCRIPTION  A leading (dims) type, or a leading default.
m = regexp(rest, '^(\(\S+\)\s+\S+|\[[^\]]*\]|"[^"]*"|\S+)\s\s+(.*)$', ...
    'tokens', 'once');
if isempty(m)
    ty = "";
    desc = rest;
    return
end
ty = strtrim(string(m{1}));
desc = strtrim(string(m{2}));
end

% ======================================================================
% Blocks
% ======================================================================
function html = errorList(txt)
%ERRORLIST  Identifiers as terms, their explanations as definitions.
if strlength(txt) == 0
    html = "";
    return
end
L = string(splitlines(txt));
items = strings(1, 0);
for k = 1:numel(L)
    m = regexp(L(k), '^\s+(\S+:\S+)\s*-\s*(.*)$', 'tokens', 'once');
    if isempty(m)
        if ~isempty(items) && strlength(strtrim(L(k))) > 0
            items(end) = items(end) + " " + esc(strtrim(L(k)));
        end
        continue
    end
    items(end + 1) = "<dt><code>" + esc(string(m{1})) + "</code></dt><dd>" + ...
        esc(strtrim(string(m{2})));                        %#ok<AGROW>
end
if isempty(items)
    html = paragraphs(txt);
    return
end
html = "<dl class=""errors"">" + strjoin(items + "</dd>", newline) + "</dl>";
end

function [html, bad] = exampleBlock(S, name)
%EXAMPLEBLOCK  Highlighted, and LINTED - an example that does not parse
%   is documentation that will be pasted into a session and fail there.
bad = strings(1, 0);
code = joinLines(S, "EXAMPLE");
if strlength(code) == 0
    html = "";
    return
end
lines = string(splitlines(code));
lines = regexprep(lines, '^\s{4,5}', '');
lines = lines(strlength(strtrim(lines)) > 0);
if ~parsesCleanly(lines)
    bad = name;
end
html = "<pre class=""example"">" + strjoin(highlight(lines), newline) + "</pre>";
end

function tf = parsesCleanly(lines)
%PARSESCLEANLY  MATLAB's own reader, on a scratch copy.
f = [tempname '.m'];
c = onCleanup(@() deleteIfPresent(f));
fid = fopen(f, 'w');
fprintf(fid, '%s\n', lines{:});
fclose(fid);
issues = checkcode(f, '-struct');
tf = true;
for k = 1:numel(issues)
    if contains(lower(string(issues(k).message)), ["parse error" "unbalanced" "invalid"])
        tf = false;
    end
end
end

function deleteIfPresent(f)
if isfile(f), delete(f); end
end

function out = highlight(lines)
%HIGHLIGHT  Comments, strings and keywords. Deliberately small.
out = strings(size(lines));
kw = ["for" "end" "if" "else" "elseif" "while" "function" "return" ...
      "switch" "case" "otherwise" "try" "catch" "arguments"];
for k = 1:numel(lines)
    s = esc(lines(k));
    c = regexp(s, '%', 'once');
    tail = "";
    if ~isempty(c)
        tail = "<span class=""cmt"">" + extractAfter(s, c - 1) + "</span>";
        s = extractBefore(s, c);
    end
    s = regexprep(s, '(&quot;[^&]*&quot;|''[^'']*'')', '<span class="str">$1</span>');
    for w = kw
        s = regexprep(s, "(?<![\w.])" + w + "(?![\w])", ...
            "<span class=""kw"">" + w + "</span>");
    end
    out(k) = s + tail;
end
end

function [html, broken] = seeAlso(S, allNames)
%SEEALSO  Resolved links, and the ones that resolve to nothing.
broken = strings(1, 0);
txt = joinLines(S, "See also");
txt = strtrim(regexprep(txt, '\s+', ' '));
% ONLY THE TRAILING FULL STOP. Written as erase(txt, "."), this deleted
% the dot INSIDE every package name, so "GEO.COASTLINE" became
% "GEOCOASTLINE" and all 117 cross-references were reported broken -
% by the very check that exists to prove they are not.
txt = regexprep(txt, '\.\s*$', '');
if strlength(txt) == 0
    html = "";
    return
end
parts = regexprep(strtrim(split(txt, ",")), '\.\s*$', '');
links = strings(1, 0);
for p = parts(:)'
    if strlength(p) == 0, continue, end
    target = lower(p);
    if any(lower(allNames) == target)
        hit = allNames(lower(allNames) == target);
        links(end + 1) = "<a href=""" + pageName(hit(1)) + """><code>" + ...
            esc(hit(1)) + "</code></a>";                   %#ok<AGROW>
    elseif resolvesToAFunction(target) || resolvesToAFunction(p)
        links(end + 1) = "<code>" + esc(p) + "</code>";     %#ok<AGROW>
    else
        broken(end + 1) = p;                               %#ok<AGROW>
        links(end + 1) = "<code class=""broken"">" + esc(p) + "</code>"; %#ok<AGROW>
    end
end
html = "<p>" + strjoin(links, ", ") + "</p>";
end

function tf = resolvesToAFunction(name)
%RESOLVESTOAFUNCTION  Is this a callable name? Asked safely.
%   WHICH tries command syntax on anything that is not a valid name, so
%   which('Claude Opus 5 (Anthropic)') RAISES rather than returning
%   empty. A resolver that can be made to throw by the text it is
%   resolving is not a resolver.
tf = false;
parts = split(string(name), ".");
if ~all(arrayfun(@(p) isvarname(char(p)), parts))
    return
end
tf = ~isempty(which(char(name)));
end

% ======================================================================
% Index and guides
% ======================================================================
function html = indexPage(groups)
parts = strings(1, 0);
parts(end+1) = pageHead("geoMap");
parts(end+1) = "<h1>geoMap</h1>";
parts(end+1) = "<p class=""h1line"">Cartographic visualisation in base " + ...
    "MATLAB, for GRACE-like satellite gravimetry.</p>";
parts(end+1) = "<p><a href=""projections.html"">Choosing a projection</a>" + ...
    " &middot; <a href=""grace_workflow.html"">A GRACE workflow</a></p>";
for g = groups
    parts(end+1) = "<h2>" + esc(g.Name) + "</h2><ul class=""index"">";
    for f = g.Functions
        parts(end+1) = "<li><a href=""" + pageName(f) + """><code>" + ...
            esc(f) + "</code></a></li>";
    end
    parts(end+1) = "</ul>";
end
parts(end+1) = pageFoot();
html = strjoin(parts, newline);
end

function xml = tocXml(groups)
%TOCXML  The Help browser tree, mirroring the layer grouping.
parts = strings(1, 0);
parts(end+1) = "<?xml version=""1.0"" encoding=""utf-8""?>";
parts(end+1) = "<toc version=""2.0"">";
parts(end+1) = "<tocitem target=""index.html"">geoMap";
parts(end+1) = "  <tocitem target=""projections.html"">Choosing a projection</tocitem>";
parts(end+1) = "  <tocitem target=""grace_workflow.html"">A GRACE workflow</tocitem>";
for g = groups
    parts(end+1) = "  <tocitem target=""index.html"">" + esc(g.Name);
    for f = g.Functions
        parts(end+1) = "    <tocitem target=""" + pageName(f) + """>" + ...
            esc(f) + "</tocitem>";
    end
    parts(end+1) = "  </tocitem>";
end
parts(end+1) = "</tocitem>";
parts(end+1) = "</toc>";
xml = strjoin(parts, newline);
end

function html = projectionGuide()
%PROJECTIONGUIDE  Which projection, and the caveat that governs all of them.
rows = [ ...
    "Global anomaly or mass field", "mollweide, hammer", ...
        "Equal-area. Area is the quantity being read, so it must not be distorted."; ...
    "Global, general purpose", "robinson, winkeltripel", ...
        "Compromise. Neither equal-area nor conformal; chosen because it looks right."; ...
    "Regional, mid-latitude", "lambertconformal, albers", ...
        "Conformal for shape and angle; albers for area. Both need standard parallels."; ...
    "Polar", "polarstereographic", ...
        "Conformal, and the only sane choice above about 70 degrees."; ...
    "Narrow north-south strip, ground tracks", "transversemercator", ...
        "Conformal along the central meridian; diverges 90 degrees away from it."; ...
    "Navigation, small equatorial areas", "mercator", ...
        "Conformal, straight rhumb lines, and areas near the poles that lie."; ...
    "One hemisphere, a globe view", "orthographic, lambert", ...
        "Orthographic looks like a photograph; lambert is equal-area."];
parts = strings(1, 0);
parts(end+1) = pageHead("Choosing a projection");
parts(end+1) = "<h1>Choosing a projection</h1>";
parts(end+1) = "<div class=""warn""><p><strong>The model is a SPHERE, " + ...
    "not an ellipsoid.</strong> Every projection here uses the authalic " + ...
    "radius 6371.0072 km. The resulting geometric error is at most about " + ...
    "0.3%, which is invisible in a figure and unacceptable in a survey. " + ...
    "<strong>This is a visualisation tool, not a survey tool.</strong> " + ...
    "If you need coordinates to hold on the ground, use a projection " + ...
    "library with an ellipsoid.</p></div>";
parts(end+1) = "<table class=""args""><tr><th>What you are showing</th>" + ...
    "<th>Projection</th><th>Why</th></tr>";
for k = 1:size(rows, 1)
    parts(end+1) = "<tr><td>" + esc(rows(k, 1)) + "</td><td><code>" + ...
        esc(rows(k, 2)) + "</code></td><td>" + esc(rows(k, 3)) + "</td></tr>";
end
parts(end+1) = "</table>";
parts(end+1) = "<h2>The rule behind the table</h2><p>Ask what the reader " + ...
    "will MEASURE off the figure. If they will compare areas - a mass " + ...
    "anomaly, a basin total, an ice loss - the projection must be " + ...
    "equal-area or the comparison is wrong before it starts. If they " + ...
    "will read angles or shapes, it must be conformal. No projection is " + ...
    "both, and a compromise projection is neither.</p>";
parts(end+1) = "<p>Every projection's exact domain, singularities and " + ...
    "clip limits are queryable: <code>geo.crs(name).Domain</code>.</p>";
parts(end+1) = pageFoot();
html = strjoin(parts, newline);
end

function html = graceWorkflow()
%GRACEWORKFLOW  The tutorial, end to end, in the order it is done.
steps = [ ...
    "Read the field", "G = geo.readGrid(""ewh_2003.nc"", Units = ""cm"");"; ...
    "Choose a projection", "crs = geo.crs(""mollweide"");"; ...
    "Draw it", "H = geo.map(G, crs, Colorbar = struct(Label = ""EWH (cm)""));"; ...
    "Mark what is significant", "H = geo.map(G, crs, Stipple = struct(G = mask));"; ...
    "Put a track on it", "H = geo.trackmap(T, crs, Track = struct(Style = ""bicolor""));"; ...
    "Compare two epochs", "H = geo.panel(spec, Layout = [1 2]);"; ...
    "Export at journal size", "geo.export(H.Figure, ""fig3.pdf"", Width = 17);"];
parts = strings(1, 0);
parts(end+1) = pageHead("A GRACE workflow");
parts(end+1) = "<h1>A GRACE workflow</h1>";
parts(end+1) = "<p class=""h1line"">From a monthly solution to a figure " + ...
    "at the width a journal asked for.</p>";
for k = 1:size(steps, 1)
    parts(end+1) = "<h2>" + k + ". " + esc(steps(k, 1)) + "</h2>";
    parts(end+1) = "<pre class=""example"">" + ...
        strjoin(highlight(steps(k, 2)), newline) + "</pre>";
end
parts(end+1) = "<h2>Two things worth knowing before you start</h2>";
parts(end+1) = "<p><strong>Equal-area or the comparison is wrong.</strong> " + ...
    "A mass anomaly is read by area. See <a href=""projections.html"">" + ...
    "choosing a projection</a>.</p>";
parts(end+1) = "<p><strong>A shared colour scale, or the panels are not " + ...
    "comparable.</strong> <code>geo.panel</code> shares one by default " + ...
    "across map tiles, because a reader assumes it.</p>";
parts(end+1) = pageFoot();
html = strjoin(parts, newline);
end

% ======================================================================
% HTML plumbing
% ======================================================================
function s = pageName(name)
s = replace(name, ".", "_") + ".html";
end

function s = pageHead(title)
s = "<!DOCTYPE html>" + newline + ...
    "<html lang=""en""><head><meta charset=""utf-8"">" + newline + ...
    "<title>" + esc(title) + " - geoMap</title>" + newline + ...
    "<style>" + styleSheet() + "</style></head><body>" + newline + ...
    "<nav><a href=""index.html"">geoMap</a></nav>";
end

function s = pageFoot()
s = "<footer>geoMap v2.0 - generated by docbuild/build_help.m</footer>" + ...
    newline + "</body></html>";
end

function s = styleSheet()
s = join([ ...
    "body{font-family:Helvetica,Arial,sans-serif;max-width:52em;margin:2em auto;padding:0 1em;color:#222;line-height:1.5}"
    "nav{border-bottom:1px solid #ddd;padding-bottom:.5em;margin-bottom:1.5em}"
    "h1{margin-bottom:.2em}.h1line{color:#555;margin-top:0;font-size:1.1em}"
    "h2{margin-top:1.8em;border-bottom:1px solid #eee;padding-bottom:.2em}"
    "table.args{border-collapse:collapse;width:100%}"
    "table.args th{text-align:left;background:#f6f6f6;padding:.4em .6em;border:1px solid #e0e0e0}"
    "table.args td{padding:.4em .6em;border:1px solid #e0e0e0;vertical-align:top}"
    "code{background:#f4f4f4;padding:0 .2em;border-radius:2px}"
    "pre{background:#f8f8f8;border:1px solid #eee;padding:.8em;overflow-x:auto}"
    "pre.syntax{background:#fbfbfb}"
    ".accuracy{border-left:3px solid #4a7;padding-left:.9em;background:#f6fbf8}"
    ".warn{border-left:3px solid #c62;padding-left:.9em;background:#fdf6f2}"
    "dl.errors dt{margin-top:.6em}dl.errors dd{margin-left:1.5em;color:#444}"
    ".kw{color:#0a5}.str{color:#a50}.cmt{color:#888;font-style:italic}"
    ".broken{background:#fdd}"
    "ul.index{columns:2;list-style:none;padding-left:0}"
    "footer{margin-top:3em;color:#888;font-size:.9em;border-top:1px solid #eee;padding-top:.6em}"], "");
end

function s = block(title, body)
if strlength(strtrim(body)) == 0
    s = "";
    return
end
s = "<h2>" + esc(title) + "</h2>" + newline + body;
end

function s = argTable(title, headers, rows)
if isempty(rows)
    s = "";
    return
end
cells = strings(1, size(rows, 1));
for k = 1:size(rows, 1)
    cells(k) = "<tr><td><code>" + esc(rows(k, 1)) + "</code></td><td>" + ...
        esc(rows(k, 2)) + "</td><td>" + esc(rows(k, 3)) + "</td></tr>";
end
s = "<h2>" + esc(title) + "</h2>" + newline + "<table class=""args"">" + ...
    "<tr><th>" + strjoin(esc(headers), "</th><th>") + "</th></tr>" + ...
    strjoin(cells, newline) + "</table>";
end

function s = paragraphs(txt)
if strlength(strtrim(txt)) == 0
    s = "";
    return
end
% A BLANK HELP LINE SEPARATES PARAGRAPHS, and a "blank" help line is
% "%" alone, which arrives here as whitespace. Splitting on a literal
% double newline missed every one of them.
chunks = split(regexprep(string(txt), '\n\s*\n', char(10) + "@@" + char(10)), "@@");
s = "";
for c = chunks(:)'
    body = strtrim(regexprep(c, '\s+', ' '));
    if strlength(body) == 0, continue, end
    s = s + "<p>" + esc(body) + "</p>" + newline;
end
end

function s = esc(t)
s = replace(string(t), "&", "&amp;");
s = replace(s, "<", "&lt;");
s = replace(s, ">", "&gt;");
s = replace(s, """", "&quot;");
end

function writeText(p, s)
fid = fopen(p, 'w');
if fid < 0
    error('geo:docbuild:MalformedHelp', 'Cannot write %s.', p);
end
fwrite(fid, s);
fclose(fid);
end
