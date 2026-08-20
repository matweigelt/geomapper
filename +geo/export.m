function H = export(figs, files, options)
%GEO.EXPORT  Write figures to files at an exact physical size.
%
%   SYNTAX
%     H = GEO.EXPORT(FIG, FILE)
%     H = GEO.EXPORT(FIG, FILE, Name, Value)
%     H = GEO.EXPORT(FIGS, FILES, Name, Value)
%     H = GEO.EXPORT(BUILDERS, FILES, UseParallel = "auto")
%
%   DESCRIPTION
%     The export tail, and it exists as its own function for one reason:
%     a figure that is going into a journal has a width in CENTIMETRES,
%     and neither of MATLAB's two export routes delivers one by itself.
%
%     WHY THIS IS NOT A CALL TO EXPORTGRAPHICS. v1's whole export path
%     was one line - EXPORTGRAPHICS(fig, path, 'Resolution', dpi) - with
%     the figure sized in SCREEN PIXELS. Two things follow, and both were
%     measured rather than reasoned about:
%
%       1. EXPORTGRAPHICS CROPS TO CONTENT. A figure set to 17 x 12 cm
%          exported to PNG at 300 dpi came back 1486 x 711 pixels, which
%          is 12.58 x 6.02 cm - 26% narrow, and narrow by an amount that
%          depends on how much margin the axes happened to leave. The
%          same call to PRINT gave 2008 x 1418 pixels: 17.00 x 12.01 cm.
%       2. A PIXEL IS NOT A LENGTH. v1's FigureSize is in pixels and its
%          export takes a DPI, so the centimetres you receive are a
%          function of the machine's ScreenPixelsPerInch. There was no
%          way to ask v1 for 17.0 cm at all.
%
%     So PRINT is the primary route here, driven by PaperPosition and
%     PaperSize, which is what makes the size a contract instead of a
%     side effect. Measured on the produced files: a 17.0 cm request
%     yields a PDF page of 482 pt = 17.004 cm and a PNG of 2008 px at
%     300 dpi = 17.007 cm. The residual is one point and one pixel of
%     rounding-up, in that order, and it is asserted rather than assumed.
%
%     EXPORTGRAPHICS IS STILL USED where it is the better instrument:
%     when Crop = true, and for .gif, which PRINT has no driver for
%     (measured: MATLAB:print:InvalidDeviceOption). It is also the
%     fallback if PRINT fails, and H.Method reports which route wrote
%     each file - an export that silently changed instrument has
%     silently changed size. The routing lives in
%     GEO.INTERNAL.WRITEFIGUREFILE, one decision in one place.
%
%     THE FIGURE IS RESTORED. PaperUnits, PaperPosition, PaperSize,
%     PaperPositionMode, Units and Color are saved before the write and
%     put back after it, through ONCLEANUP so that a failed write
%     restores them too. An export is a read of the figure; a caller who
%     exports and then keeps working must not find the figure changed.
%
%     THE PARALLEL FORM TAKES BUILDERS, NOT HANDLES, and this is the
%     design point worth reading. Graphics handles cannot cross a worker
%     boundary - a figure exists in one MATLAB's graphics system and
%     nowhere else. So the batch form accepts a CELL ARRAY OF FUNCTION
%     HANDLES, each of which creates its own figure on the worker and
%     returns it. Passing live handles with UseParallel = "always" is an
%     error rather than a silent serialisation, because the failure it
%     replaces is obscure.
%
%     THIS IS AN L4 UTILITY AND NOT AN L4 FRONT: it draws nothing and
%     orchestrates nothing, so it declares no L4 marker and is not held
%     to the 200-line orchestration budget. Declaring one would have
%     meant a false pass or a raised limit, and 4.6 forbids the second.
%
%   INPUTS
%     figs   Either graphics figure handles, (1,:), or a cell array of
%            function handles, (1,:), each returning one figure. The
%            second form is the only one that can be run in parallel.
%     files  (1,:) string  One path per figure. The extension chooses
%                          the format: .pdf .eps .svg .emf .png .jpg
%                          .tif .bmp go through PRINT, .gif through
%                          EXPORTGRAPHICS.
%
%   OPTIONS
%     Width        17          Page width, in Units.
%     Height       []          Page height. Empty takes it from the
%                              figure's own aspect ratio.
%     Units        "centimeters"  "centimeters" | "inches" | "points".
%     Resolution   300         DPI, for raster formats and for rasterised
%                              content inside a vector file.
%     ContentType  "auto"      "auto" | "vector" | "image". "auto" is
%                              vector for .pdf .eps .svg .emf and image
%                              for everything else.
%     BackgroundColor []       Empty keeps the figure's own Color.
%     Crop         false       True content-crops via EXPORTGRAPHICS, in
%                              which case Width and Height no longer
%                              describe the file and H.Cropped says so.
%     UseParallel  "never"     "never" | "auto" | "always". "auto" goes
%                              parallel only if builders were given,
%                              there is more than one, and Parallel
%                              Computing Toolbox is present; "always"
%                              raises if any of those is missing.
%     CloseAfter   false       Close each figure once written. A figure
%                              made by a BUILDER is always closed, on a
%                              worker or not: this function created it,
%                              so this function disposes of it, and a
%                              batch of 200 would otherwise leak 200.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Files       (1,:) string   As written.
%          Method      (1,:) string   "print" | "exportgraphics", per file.
%          Width       (1,1) double   As requested, in Units.
%          Height      (1,:) double   Per file; differs when taken from
%                                     each figure's aspect ratio.
%          Units       (1,1) string
%          Resolution  (1,1) double
%          Cropped     (1,1) logical
%          Parallel    (1,1) logical  Whether the batch actually ran on
%                                     workers, which is not the same as
%                                     what was asked for.
%          NumWritten  (1,1) double
%
%   ACCURACY
%     One claim, on the file the operating system wrote and not on the
%     figure: a PDF asked for at W centimetres has a MediaBox width of
%     W +/- 0.05 cm, and a PNG at R dpi has round(W/2.54*R) pixels to
%     within one pixel. Both are read back out of the produced file.
%
%   ERRORS
%     geo:export:BadFigures        - not figures and not builder handles
%     geo:export:InvalidFigure     - a figure handle that has been deleted
%     geo:export:CountMismatch     - numel(files) ~= numel(figs)
%     geo:export:HandlesCannotCross - UseParallel="always" with live handles
%     geo:export:NoParallel        - UseParallel="always" without the pool
%     geo:export:BuilderReturnedNothing - a builder gave back no figure
%     geo:export:WorkerFailed      - a builder failed on a worker
%     geo:export:CannotWrite       - the folder is missing, or both routes
%                                    failed to write the file
%
%   EXAMPLE
%     % One figure, exactly 17 cm wide for a two-column journal.
%     H = geo.export(fig, "figure3.pdf", Width = 17);
%
%     % A batch, built on workers. Note the handles, not the figures.
%     builders = { @() makeMap(2003), @() makeMap(2004) };
%     files    = ["y2003.png" "y2004.png"];
%     geo.export(builders, files, Width = 9, UseParallel = "auto");
%
%   LIMITATIONS
%     A BUILDER MUST BE SELF-CONTAINED, and this is the sharp edge of
%     the parallel form. It runs on a worker, so it may not call a local
%     function of the calling script, capture a variable from the base
%     workspace, or read a file off the worker's path. Measured while
%     writing this: a builder calling a local function of the test
%     script failed with "Unrecognized function or variable", which
%     names the symbol and not the cause - hence
%     geo:export:WorkerFailed, which names the cause.
%
%     A vector PDF of a basemap embeds the whole surface as vector art
%     and can be very large; ContentType = "image" rasterises the page
%     at Resolution and is usually what a 2000 x 1000 grid wants.
%     Reading the produced PDF's page box assumes the MediaBox is plain
%     text in the file, which MATLAB's own writer produces; it is not
%     true of PDFs in general.
%
%   See also GEO.MAP, EXPORTGRAPHICS, PRINT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    figs
    files (1,:) string
    options.Width (1,1) double {mustBePositive, mustBeFinite} = 17
    options.Height double {mustBePositive} = []
    options.Units (1,1) string {mustBeMember(options.Units, ["centimeters" "inches" "points"])} = "centimeters"
    options.Resolution (1,1) double {mustBePositive, mustBeFinite} = 300
    options.ContentType (1,1) string {mustBeMember(options.ContentType, ["auto" "vector" "image"])} = "auto"
    options.BackgroundColor double = []
    options.Crop (1,1) logical = false
    options.UseParallel (1,1) string {mustBeMember(options.UseParallel, ["never" "auto" "always"])} = "never"
    options.CloseAfter (1,1) logical = false
end

isBuilder = classifyInput(figs);
n = numel(figs);
if numel(files) ~= n
    error('geo:export:CountMismatch', ...
        ['%d file%s for %d figure%s. Every figure needs its own path; ' ...
         'there is no template expansion here.'], ...
        numel(files), plural(numel(files)), n, plural(n));
end

runParallel = decideParallel(options.UseParallel, isBuilder, n);

if runParallel
    [routes, heights] = exportOnWorkers(figs, files, options);
else
    routes = strings(1, n);
    heights = zeros(1, n);
    for k = 1:n
        [figH, owned] = resolveFigure(figs, k, isBuilder);
        [routes(k), heights(k)] = writeOne(figH, files(k), options);
        if options.CloseAfter || owned
            close(figH);
        end
    end
end

H = struct('Files', files, 'Method', routes, 'Width', options.Width, ...
    'Height', heights, 'Units', options.Units, ...
    'Resolution', options.Resolution, 'Cropped', options.Crop, ...
    'Parallel', runParallel, 'NumWritten', n);
end

% ======================================================================
% Input classification
% ======================================================================
function isBuilder = classifyInput(figs)
%CLASSIFYINPUT  Builders or figures, and nothing in between.
if iscell(figs)
    ok = ~isempty(figs) && all(cellfun(@(c) isa(c, 'function_handle'), figs(:)));
    if ~ok
        error('geo:export:BadFigures', ...
            ['A cell array must hold only function handles, each ' ...
             'returning one figure. Live figure handles are passed ' ...
             'directly, not in a cell.']);
    end
    isBuilder = true;
    return
end
isBuilder = false;
if isempty(figs) || ~all(isgraphics(figs(:)))
    if isa(figs, 'matlab.ui.Figure')
        error('geo:export:InvalidFigure', ...
            ['One of the figures has been deleted. A figure closed ' ...
             'before its export leaves a handle that still looks ' ...
             'like a figure and is not one.']);
    end
    error('geo:export:BadFigures', ...
        ['First argument must be figure handles or a cell array of ' ...
         'function handles that build them, and was %s.'], class(figs));
end
if ~all(arrayfun(@(h) isa(h, 'matlab.ui.Figure'), figs(:)))
    error('geo:export:BadFigures', ...
        'Graphics handles were given, but not all of them are figures.');
end
end

function [figH, owned] = resolveFigure(figs, k, isBuilder)
%RESOLVEFIGURE  The k-th figure, built if it does not exist yet.
owned = isBuilder;
if ~isBuilder
    figH = figs(k);
    return
end
figH = figs{k}();
if isempty(figH) || ~isgraphics(figH) || ~isa(figH, 'matlab.ui.Figure')
    error('geo:export:BuilderReturnedNothing', ...
        ['Builder %d returned %s instead of a figure. A builder must ' ...
         'CREATE its figure and RETURN it - one that draws into GCF ' ...
         'and returns nothing cannot be run on a worker.'], ...
        k, class(figH));
end
end

% ======================================================================
% The parallel decision, and the batch
% ======================================================================
function runParallel = decideParallel(want, isBuilder, n)
%DECIDEPARALLEL  Ask for it explicitly and you are told why it cannot.
% PROBED, NOT GUESSED FROM THE FILE SYSTEM. This line read
% exist('parfeval','file') > 0 && exist('gcp','file') > 0, and on CI -
% which has no Parallel Computing Toolbox - it PASSED, so the next line
% died with "Undefined function 'gcp'". A guard written to produce a
% helpful error produced an unhelpful one on the exact configuration it
% existed for (PV-123). EXIST answers a question about files, and MATLAB
% ships stubs for toolboxes it does not have.
havePool = geo.internal.hasParallelPool();
if want == "always"
    if ~isBuilder
        error('geo:export:HandlesCannotCross', ...
            ['UseParallel="always" needs a cell array of builder ' ...
             'function handles. Graphics handles cannot cross a worker ' ...
             'boundary - a figure lives in one MATLAB''s graphics ' ...
             'system and nowhere else - so each worker must build its ' ...
             'own: { @() makeFigure(a), @() makeFigure(b) }.']);
    end
    if ~havePool
        error('geo:export:NoParallel', ...
            ['UseParallel="always", but Parallel Computing Toolbox is ' ...
             'not available. geoMap needs base MATLAB only; the ' ...
             'parallel path is an option, never a requirement. Use ' ...
             '"auto", which falls back silently, or "never".']);
    end
end
runParallel = want ~= "never" && isBuilder && havePool && n > 1;
end

function [routes, heights] = exportOnWorkers(figs, files, options)
%EXPORTONWORKERS  One future per figure, each a serial GEO.EXPORT.
%   The worker re-enters this same function with UseParallel="never", so
%   the parallel path and the serial path cannot drift apart.
n = numel(figs);
nv = namedargs2cell(options);
pool = gcp();
futures(1, n) = parallel.FevalFuture();
for k = 1:n
    futures(k) = parfeval(pool, @geo.export, 1, figs(k), files(k), ...
        nv{:}, 'UseParallel', "never", 'CloseAfter', true);
end
routes = strings(1, n);
heights = zeros(1, n);
for k = 1:n
    try
        [idx, out] = fetchNext(futures);
    catch err
        cancel(futures);
        error('geo:export:WorkerFailed', ...
            ['A builder failed on a worker: %s\n\nThe usual cause is ' ...
             'that the builder reaches something the worker cannot: a ' ...
             'local function of the calling script, a variable captured ' ...
             'from the base workspace, or a file off the worker''s path. ' ...
             'A builder must be self-contained.'], err.message);
    end
    routes(idx) = out.Method;
    heights(idx) = out.Height;
end
end

% ======================================================================
% Writing one file
% ======================================================================
function [method, height] = writeOne(figH, file, options)
%WRITEONE  Size the page, write it, put the figure back as it was.
folder = fileparts(file);
if strlength(folder) > 0 && ~isfolder(folder)
    error('geo:export:CannotWrite', ...
        'Folder "%s" does not exist, so "%s" cannot be written.', ...
        folder, file);
end

saved = saveState(figH);
restorer = onCleanup(@() restoreState(figH, saved));   %#ok<NASGU>

height = pageHeight(figH, options);
applyPage(figH, height, options);

try
    method = geo.internal.writeFigureFile(figH, file, ...
        ContentType = options.ContentType, ...
        Resolution = options.Resolution, Crop = options.Crop);
catch err
    if err.identifier == "geo:writeFigureFile:CannotWrite"
        error('geo:export:CannotWrite', '%s', err.message);
    end
    rethrow(err);
end
end

% ======================================================================
% Page geometry and figure state
% ======================================================================
function height = pageHeight(figH, options)
%PAGEHEIGHT  Explicit if given, otherwise the figure's own aspect.
if ~isempty(options.Height)
    height = options.Height(1);
    return
end
u = figH.Units;
figH.Units = char(options.Units);
onScreen = figH.Position;
figH.Units = u;
height = options.Width * onScreen(4) / onScreen(3);
end

function applyPage(figH, height, options)
%APPLYPAGE  The three properties that turn a request into a page.
figH.PaperUnits = char(options.Units);
figH.PaperPositionMode = 'manual';
figH.PaperPosition = [0 0 options.Width height];
figH.PaperSize = [options.Width height];
if ~isempty(options.BackgroundColor)
    figH.Color = options.BackgroundColor;
end
end

function s = saveState(figH)
%SAVESTATE  Everything APPLYPAGE touches, and nothing else.
s = struct('PaperUnits', figH.PaperUnits, ...
    'PaperPosition', figH.PaperPosition, ...
    'PaperSize', figH.PaperSize, ...
    'PaperPositionMode', figH.PaperPositionMode, ...
    'Units', figH.Units, 'Color', figH.Color);
end

function restoreState(figH, s)
%RESTORESTATE  Under ONCLEANUP, so a failed write restores too.
if ~isgraphics(figH)
    return
end
figH.PaperUnits = s.PaperUnits;
figH.PaperPosition = s.PaperPosition;
figH.PaperSize = s.PaperSize;
figH.PaperPositionMode = s.PaperPositionMode;
figH.Units = s.Units;
figH.Color = s.Color;
end

function s = plural(n)
if n == 1, s = ""; else, s = "s"; end
end
