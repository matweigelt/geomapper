function method = writeFigureFile(figH, file, options)
%GEO.INTERNAL.WRITEFIGUREFILE  Choose the instrument, write the file.
%
%   SYNTAX
%     method = GEO.INTERNAL.WRITEFIGUREFILE(FIG, FILE, ContentType = ..., ...)
%
%   DESCRIPTION
%     One decision in one place: which of MATLAB's two export routes
%     writes this extension, and what to do when it will not.
%
%     THE ROUTES ARE NOT INTERCHANGEABLE, which is why the choice is
%     made here rather than at each call site. PRINT is driven by the
%     figure's PaperPosition and therefore honours a requested page
%     size; EXPORTGRAPHICS crops to content and therefore does not.
%     Measured on a figure set to 17 x 12 cm at 300 dpi: PRINT wrote
%     2008 x 1418 px (17.01 x 12.01 cm), EXPORTGRAPHICS wrote
%     1486 x 711 px (12.58 x 6.02 cm). So PRINT is the default and
%     EXPORTGRAPHICS is chosen only where it is the better instrument -
%     when a content crop is what was asked for, and for .gif, which
%     PRINT has no driver for (MATLAB:print:InvalidDeviceOption,
%     measured).
%
%     THE FALLBACK REPORTS ITSELF. If PRINT fails, EXPORTGRAPHICS is
%     tried and the returned METHOD says so, because an export that
%     silently changed instrument has silently changed size, and a
%     caller measuring a page against a journal's spec needs to know
%     which of the two numbers above it is holding.
%
%   INPUTS
%     figH  (1,1) matlab.ui.Figure  Already sized by the caller.
%     file  (1,1) string            Path; its extension picks the format.
%
%   OPTIONS
%     ContentType  (1,1) string  "auto" | "vector" | "image".
%     Resolution   (1,1) double  DPI.
%     Crop         (1,1) logical  Force the content-cropping route.
%
%   OUTPUTS
%     method  (1,1) string  "print" | "exportgraphics", as used.
%
%   ACCURACY
%     None of its own. It selects an instrument; the page-size claim
%     belongs to GEO.EXPORT and is asserted on the produced file.
%
%   ERRORS
%     geo:writeFigureFile:CannotWrite - both routes failed
%
%   EXAMPLE
%     m = geo.internal.writeFigureFile(fig, "a.pdf", Resolution = 300);
%
%   LIMITATIONS
%     An unknown extension is offered to PRINT as PNG, which refuses,
%     and the decision then falls to EXPORTGRAPHICS - deliberately, so
%     that a format MathWorks adds later works without a change here.
%
%   See also GEO.EXPORT, PRINT, EXPORTGRAPHICS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    figH (1,1) matlab.ui.Figure
    file (1,1) string
    options.ContentType (1,1) string {mustBeMember(options.ContentType, ["auto" "vector" "image"])} = "auto"
    options.Resolution (1,1) double {mustBePositive} = 300
    options.Crop (1,1) logical = false
end

[~, ~, e] = fileparts(file);
ext = lower(string(e));
content = contentFor(ext, options.ContentType);

if options.Crop || ext == ".gif"
    method = "exportgraphics";
    viaExportgraphics(figH, file, ext, content, options.Resolution);
    return
end

method = "print";
try
    viaPrint(figH, file, ext, content, options.Resolution);
catch printErr
    try
        viaExportgraphics(figH, file, ext, content, options.Resolution);
        method = "exportgraphics";
    catch egErr
        error('geo:writeFigureFile:CannotWrite', ...
            ['Neither route could write "%s".\n  print: %s\n' ...
             '  exportgraphics: %s'], file, printErr.message, egErr.message);
    end
end
end

% ======================================================================
function viaPrint(figH, file, ext, content, resolution)
%VIAPRINT  The sized route. PaperPosition is what makes it exact.
args = {char(file), driverFor(ext), sprintf('-r%d', round(resolution))};
if content == "vector"
    args{end+1} = '-vector';
else
    args{end+1} = '-image';
end
print(figH, args{:});
end

function viaExportgraphics(figH, file, ext, content, resolution)
%VIAEXPORTGRAPHICS  The cropping route, and the only one that writes .gif.
args = {figH, char(file), 'Resolution', resolution};
if any(ext == [".pdf" ".eps" ".emf" ".svg"])
    args = [args, {'ContentType', char(content)}];
end
exportgraphics(args{:});
end

function d = driverFor(ext)
%DRIVERFOR  Extension to PRINT device. .gif is absent on purpose.
known = [".pdf" ".eps" ".svg" ".emf" ".png" ".jpg" ".jpeg" ".tif" ".tiff" ".bmp"];
devs  = ["-dpdf" "-depsc" "-dsvg" "-dmeta" "-dpng" "-djpeg" "-djpeg" ...
         "-dtiff" "-dtiff" "-dbmp"];
hit = find(known == ext, 1);
if isempty(hit)
    d = '-dpng';        % PRINT refuses on a mismatched extension, and
    return              % the fallback then lets EXPORTGRAPHICS decide
end
d = char(devs(hit));
end

function c = contentFor(ext, requested)
%CONTENTFOR  "auto" means vector where vector is possible.
if requested ~= "auto"
    c = requested;
    return
end
if any(ext == [".pdf" ".eps" ".svg" ".emf"])
    c = "vector";
else
    c = "image";
end
end
