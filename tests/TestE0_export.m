classdef TestE0_export < GeoMapTestCase
%TESTE0_EXPORT  Stage E.0: the export tail, and the size it promises.
%
%   DESCRIPTION
%     One assertion carries this file: a figure asked for at 17.0 cm
%     arrives as a file 17.0 cm wide, measured on the file the operating
%     system wrote and not on the figure that produced it.
%
%     That is worth a test class because v1 could not do it. Its export
%     was one line - EXPORTGRAPHICS with a DPI - over a figure sized in
%     SCREEN PIXELS, so the centimetres delivered were a function of the
%     machine's ScreenPixelsPerInch and of how much margin the axes left
%     after cropping. There was no way to ask v1 for 17.0 cm at all, and
%     17.0 cm is what a journal asks for.
%
%   ACCURACY
%     PDF page width within 0.05 cm of the request, read from the
%     MediaBox. Raster pixel count within 1 px of width/2.54*dpi. Both
%     read back out of the produced file.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestE0");
%
%   LIMITATIONS
%     The MediaBox is read as text, which MATLAB's own PDF writer
%     produces and which is not true of PDFs in general. Nothing here
%     asserts that the page CONTENT is correct, only its size.
%
%   See also GEO.EXPORT, GEO.INTERNAL.WRITEFIGUREFILE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.export" "geo.internal.writeFigureFile"]
    end

    methods (TestMethodSetup)

        function noGpuIsAMachineFactNotADefect(tc)
            %NOGPUISAMACHINEFACTNOTADEFECT  One suppression, with a reason.
            %   MATLAB:graphics:HardwareUnavailable is a statement about
            %   the HOST - no hardware OpenGL, the software rasteriser
            %   will be used - and not about anything geoMap does. Every
            %   test in this class rasterises, so any of them can raise
            %   it, and which one does depends on execution order; it is
            %   set up per method rather than guessed at.
            %
            %   It is also the exact condition behind PV-104: the
            %   first-render difference is a property of that software
            %   rasteriser. So it is suppressed with its cause named,
            %   which is the opposite of hiding it.
            tc.suppressWarning('MATLAB:graphics:HardwareUnavailable');
        end
    end

    methods (Access = private)

        function d = scratch(tc)
            %SCRATCH  A directory of our own, removed on teardown.
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
        end

        function f = exportFigure(tc, colour)
            %EXPORTFIGURE  A figure with something on it, closed on teardown.
            if nargin < 2, colour = [1 1 1]; end
            f = tc.figureFor();
            f.Color = colour;
            ax = axes('Parent', f);
            surface(ax, peaks(20), 'EdgeColor', 'none');
            axis(ax, 'off');
        end

        function s = imageDiff(~, fileA, fileB)
            %IMAGEDIFF  How two produced images differ, in one string.
            %   An "is not equal" diagnostic tells you nothing about
            %   WHICH failure you have. A size difference is a layout
            %   problem; a handful of channels off by one is renderer
            %   noise; a large count is a real drift. They need different
            %   answers, so the diagnostic names which one it is.
            a = imread(fileA);
            b = imread(fileB);
            da = dir(fileA);
            db = dir(fileB);
            if ~isequal(size(a), size(b))
                s = sprintf('DIMENSIONS differ: %s vs %s (%d vs %d bytes)', ...
                    mat2str(size(a)), mat2str(size(b)), da.bytes, db.bytes);
                return
            end
            d = double(a) - double(b);
            s = sprintf(['same %s; %d of %d pixels differ (%.4f%%), ' ...
                'max channel delta %g, mean |delta| %.4g; %d vs %d bytes'], ...
                mat2str(size(a)), nnz(any(d ~= 0, 3)), ...
                size(a, 1) * size(a, 2), ...
                100 * nnz(any(d ~= 0, 3)) / (size(a, 1) * size(a, 2)), ...
                max(abs(d(:))), mean(abs(d(:))), da.bytes, db.bytes);
        end

        function file = realise(~, figH, folder)
            %REALISE  One discarded export, so the figure is settled.
            %   See the metamorphic block for why this is part of the
            %   test rather than a tolerance. Returns the path it wrote,
            %   so PV-114 can ask whether it rendered at all.
            file = fullfile(folder, "warm.png");
            geo.export(figH, file, Width = 8, Resolution = 150);
        end

        function w = pageWidthCm(tc, file)
            %PAGEWIDTHCM  The page box of the file, in centimetres.
            txt = fileread(file);
            m = regexp(txt, '/MediaBox\s*\[([^\]]*)\]', 'tokens', 'once');
            tc.assertNotEmpty(m, ...
                'No MediaBox in the produced PDF; the size claim is unreadable.');
            box = str2double(strsplit(strtrim(m{1})));
            w = (box(3) - box(1)) / 72 * 2.54;
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function everyFileNeedsItsOwnPath(tc)
            f = tc.exportFigure();
            tc.verifyError(@() geo.export(f, ["a.png" "b.png"]), ...
                'geo:export:CountMismatch');
        end

        function figuresOrBuildersAndNothingElse(tc)
            tc.verifyError(@() geo.export(struct('a', 1), "a.png"), ...
                'geo:export:BadFigures');
            tc.verifyError(@() geo.export({1, 2}, ["a.png" "b.png"]), ...
                'geo:export:BadFigures');
        end

        function aClosedFigureIsNotAFigure(tc)
            % A handle to a deleted figure still reports class
            % matlab.ui.Figure, so the check is ISGRAPHICS and not CLASS.
            f = figure('Visible', 'off');
            close(f);
            tc.verifyError(@() geo.export(f, "a.png"), ...
                'geo:export:InvalidFigure');
        end

        function alwaysWithLiveHandlesSaysWhyNot(tc)
            % The design point. A figure lives in one MATLAB's graphics
            % system, so the parallel form takes builders, and asking for
            % it with handles is an error rather than a silent failure on
            % a worker.
            f = tc.exportFigure();
            g = tc.exportFigure();
            tc.verifyError(@() geo.export([f g], ["a.png" "b.png"], ...
                UseParallel = "always"), 'geo:export:HandlesCannotCross');
        end

        function aBuilderMustReturnItsFigure(tc)
            d = tc.scratch();
            tc.verifyError(@() geo.export({@() 42}, fullfile(d, "a.png")), ...
                'geo:export:BuilderReturnedNothing');
        end

        function theRouteThatWroteEachFileIsReported(tc)
            % An export that silently changed instrument has silently
            % changed size, so the instrument is part of the result.
            d = tc.scratch();
            f = tc.exportFigure();
            H = geo.export(f, fullfile(d, "a.pdf"), Width = 8);
            tc.verifyEqual(H.Method, "print");
            H = geo.export(f, fullfile(d, "a.png"), Width = 8);
            tc.verifyEqual(H.Method, "print");
        end

        function gifHasNoPrintDriverSoItGoesTheOtherWay(tc)
            % Measured: print(-dgif) raises MATLAB:print:InvalidDeviceOption.
            % The route is chosen from the format, not from a failure.
            d = tc.scratch();
            H = geo.export(tc.exportFigure(), fullfile(d, "a.gif"), Width = 6);
            tc.verifyEqual(H.Method, "exportgraphics");
            tc.verifyTrue(isfile(fullfile(d, "a.gif")));
        end

        function cropIsADifferentInstrumentAndSaysSo(tc)
            d = tc.scratch();
            H = geo.export(tc.exportFigure(), fullfile(d, "c.png"), ...
                Width = 8, Crop = true);
            tc.verifyEqual(H.Method, "exportgraphics");
            tc.verifyTrue(H.Cropped, ...
                'A cropped file is not the requested size, and must say so.');
        end

        function heightFollowsTheFigureWhenItIsNotGiven(tc)
            d = tc.scratch();
            f = tc.exportFigure();
            f.Units = 'centimeters';
            f.Position(3:4) = [20 10];
            H = geo.export(f, fullfile(d, "a.png"), Width = 8);
            tc.verifyEqual(H.Height, 4, 'aspect ratio carried over', ...
                RelTol = 1e-12);
        end

        function neverIsNeverEvenWhenItCould(tc)
            % Builders, more than one, toolbox present - and still serial,
            % because "never" is an instruction and not a preference.
            d = tc.scratch();
            H = geo.export({@() figure('Visible', 'off'), ...
                            @() figure('Visible', 'off')}, ...
                fullfile(d, ["a.png" "b.png"]), Width = 5, ...
                UseParallel = "never");
            tc.verifyFalse(H.Parallel);
        end

        function theResultCarriesWhatWasAsked(tc)
            d = tc.scratch();
            H = geo.export(tc.exportFigure(), fullfile(d, "a.png"), ...
                Width = 9, Height = 6, Units = "centimeters", ...
                Resolution = 150);
            tc.verifyEqual(sort(string(fieldnames(H)))', sort(["Files" ...
                "Method" "Width" "Height" "Units" "Resolution" "Cropped" ...
                "Parallel" "NumWritten"]));
            tc.verifyEqual(H.Width, 9);
            tc.verifyEqual(H.Height, 6);
            tc.verifyEqual(H.Resolution, 150);
            tc.verifyEqual(H.NumWritten, 1);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function aSeventeenCentimetrePageIsSeventeenCentimetres(tc)
            % The claim this class exists for, read off the file the
            % operating system wrote. The oracle is the PDF itself.
            d = tc.scratch();
            file = fullfile(d, "j.pdf");
            geo.export(tc.exportFigure(), file, Width = 17, Height = 12);
            tc.verifyAndRecord(abs(tc.pageWidthCm(file) - 17), 0.05, ...
                "PDF page width vs the requested 17.0 cm", "cm");
        end

        function aRasterHasTheRequestedPixelCount(tc)
            % width/2.54*dpi, to within the one pixel PRINT rounds up by.
            d = tc.scratch();
            file = fullfile(d, "j.png");
            geo.export(tc.exportFigure(), file, Width = 17, Height = 12, ...
                Resolution = 300);
            info = imfinfo(file);
            tc.verifyAndRecord(abs(info.Width - 17 / 2.54 * 300), 1, ...
                "PNG pixel width vs 17.0 cm at 300 dpi", "px");
        end

        function exportgraphicsAloneGetsAnotherSizeEntirely(tc)
            % v1's whole export path, on the same figure, for comparison.
            % EXPORTGRAPHICS ignores PaperPosition and crops to content,
            % so what it writes is the on-screen layout minus its margins
            % - which is not what anybody asked for.
            %
            % This asserts a property of MATLAB rather than of geoMap. If
            % MathWorks ever makes EXPORTGRAPHICS honour a page size this
            % test fails, and that failure is the correct signal: the
            % reason for the PRINT route would have gone away.
            d = tc.scratch();
            f = tc.exportFigure();
            f.Units = 'centimeters';
            f.Position(3:4) = [17 12];
            ours = fullfile(d, "ours.png");
            theirs = fullfile(d, "theirs.png");
            geo.export(f, ours, Width = 17, Height = 12, Resolution = 300);
            exportgraphics(f, theirs, 'Resolution', 300);
            a = imfinfo(ours);
            b = imfinfo(theirs);
            tc.verifyAndRecord(abs(b.Width - a.Width) / a.Width, 0.05, ...
                "bare exportgraphics width vs the requested page", ...
                "relative", ">=");
        end

        function theThreeUnitsDescribeOnePage(tc)
            % 17 cm, 6.69291 in and 481.89 pt are one length. If the unit
            % handling were wrong anywhere, these would not agree.
            d = tc.scratch();
            f = tc.exportFigure();
            geo.export(f, fullfile(d, "cm.pdf"), Width = 17, ...
                Height = 12, Units = "centimeters");
            geo.export(f, fullfile(d, "in.pdf"), Width = 17 / 2.54, ...
                Height = 12 / 2.54, Units = "inches");
            geo.export(f, fullfile(d, "pt.pdf"), Width = 17 / 2.54 * 72, ...
                Height = 12 / 2.54 * 72, Units = "points");
            w = [tc.pageWidthCm(fullfile(d, "cm.pdf")), ...
                 tc.pageWidthCm(fullfile(d, "in.pdf")), ...
                 tc.pageWidthCm(fullfile(d, "pt.pdf"))];
            tc.verifyAndRecord(max(w) - min(w), 0.05, ...
                "spread of one page width expressed in cm, in and pt", "cm");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aMissingFolderSaysSoBeforeAnythingIsWritten(tc)
            d = tc.scratch();
            tc.verifyError(@() geo.export(tc.exportFigure(), ...
                fullfile(d, "nosuch", "a.png")), 'geo:export:CannotWrite');
        end

        function theFigureIsHandedBackUnchanged(tc)
            % An export is a READ of the figure. A caller who exports and
            % then keeps working must not find the paper properties
            % rewritten underneath.
            d = tc.scratch();
            f = tc.exportFigure([0.9 0.9 0.8]);
            before = get(f, {'PaperUnits', 'PaperPosition', 'PaperSize', ...
                             'PaperPositionMode', 'Units', 'Color'});
            geo.export(f, fullfile(d, "a.png"), Width = 9, Height = 4, ...
                BackgroundColor = [1 0 0]);
            after = get(f, {'PaperUnits', 'PaperPosition', 'PaperSize', ...
                            'PaperPositionMode', 'Units', 'Color'});
            tc.verifyEqual(after, before, ...
                'every property the export touched was restored');
        end

        function andUnchangedAfterAFailedWrite(tc)
            % The restore is under ONCLEANUP precisely so this holds.
            d = tc.scratch();
            f = tc.exportFigure();
            before = get(f, {'PaperPosition', 'PaperSize', 'Color'});
            try
                geo.export(f, fullfile(d, "nosuch", "a.png"), Width = 9);
            catch
            end
            tc.verifyEqual(get(f, {'PaperPosition', 'PaperSize', 'Color'}), ...
                before, 'a failed export restores the figure too');
        end

        function aFigureThisFunctionBuiltIsAFigureThisFunctionCloses(tc)
            % A batch of 200 builders would otherwise leak 200 figures.
            d = tc.scratch();
            before = numel(findall(groot, 'Type', 'figure'));
            geo.export({@() figure('Visible', 'off', 'Color', 'w')}, ...
                fullfile(d, "a.png"), Width = 5);
            tc.verifyEqual(numel(findall(groot, 'Type', 'figure')), before);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        % WHY EVERY TEST HERE REALISES ITS FIGURE FIRST, and why that is
        % not a tolerance in disguise.
        %
        % Measured on headless software OpenGL (R-016, PV-104): the
        % FIRST export of a figure differs from the second in 31.29% of
        % its pixels, max channel delta 254 - and the second and third
        % are identical to the byte, 0 of 134 805 pixels. It does not
        % reproduce on Windows, interactively or under -batch, so it is
        % a property of that rasteriser's warm-up and not of anything
        % geoMap decides. geo.export cannot certify it and must not
        % pretend to.
        %
        % Written without the warm-up, these tests do not fail because
        % ordering or determinism is broken - they fail because the
        % first render is in the comparison, which CONFOUNDS the very
        % thing they exist to isolate. The batch test in particular
        % compared each figure's first render against its second and
        % called the difference an ordering effect. Removing the
        % confound is not weakening the claim; it is the only way to
        % make the claim testable.
        %
        % What geo.export DOES control across a first export is asserted
        % below, on its own.

        function repeatedExportsOfARealisedFigureAreIdentical(tc)
            d = tc.scratch();
            f = tc.exportFigure();
            warm = tc.realise(f, d);
            r = fullfile(d, ["r1.png" "r2.png" "r3.png"]);
            for k = 1:3
                geo.export(f, r(k), Width = 8, Resolution = 150);
            end
            % THREE, AND BOTH PAIRS REPORTED, because this test passed on
            % CI for three checkpoints and then failed with numbers
            % byte-identical to the original PV-104 measurement - which
            % says the warm-up export above did not take, not that the
            % renderer became noisy. If 1-vs-2 differs and 2-vs-3 does
            % not, the settling is not one-shot per figure and the
            % warm-up is the wrong shape of fix; if both differ, it is
            % nondeterminism and PV-104's conclusion needs revisiting.
            % Guessing between those two would have been a coin flip.
            % PV-114. The warm-up file is compared too, because the
            % previous cycle proved 1v2 differs and 2v3 does not EVEN
            % WITH the warm-up in place - so the cold render is export
            % TWO, not export one, and the only way to tell whether the
            % warm-up rendered at all is to look at what it wrote.
            tc.verifyEqual(imread(r(2)), imread(r(1)), ...
                "warm-vs-1 " + tc.imageDiff(warm, r(1)) + ...
                " || warm-vs-2 " + tc.imageDiff(warm, r(2)) + ...
                " || 1v2 " + tc.imageDiff(r(1), r(2)) + ...
                " || 2v3 " + tc.imageDiff(r(2), r(3)));
        end

        function theOrderOfABatchDoesNotChangeItsFiles(tc)
            d = tc.scratch();
            f = tc.exportFigure([1 1 1]);
            g = tc.exportFigure([0.5 0.5 0.5]);
            tc.realise(f, d);
            tc.realise(g, d);
            p = fullfile(d, ["f1" "g1" "g2" "f2"] + ".png");
            geo.export([f g], p(1:2), Width = 6);
            geo.export([g f], p([3 4]), Width = 6);
            tc.verifyEqual(imread(p(4)), imread(p(1)), ...
                "first figure: " + tc.imageDiff(p(1), p(4)));
            tc.verifyEqual(imread(p(3)), imread(p(2)), ...
                "second figure: " + tc.imageDiff(p(2), p(3)));
        end

        function theFirstExportIsTheSamePageIfNotTheSamePixels(tc)
            % The claim that CAN be made about a never-rendered figure,
            % and the one a user needs: whatever the rasteriser does
            % differently on its first pass, the PAGE is the same. Same
            % dimensions, same route, same reported height. Somebody who
            % builds a figure and exports it once - which is the whole
            % builder and batch workflow - gets a file of the size they
            % asked for.
            d = tc.scratch();
            f = tc.exportFigure();
            a = geo.export(f, fullfile(d, "a.png"), Width = 8, ...
                Height = 6, Resolution = 150);
            b = geo.export(f, fullfile(d, "b.png"), Width = 8, ...
                Height = 6, Resolution = 150);
            ia = imfinfo(fullfile(d, "a.png"));
            ib = imfinfo(fullfile(d, "b.png"));
            tc.verifyEqual([ib.Width ib.Height], [ia.Width ia.Height], ...
                'the first export has the same pixel dimensions as the second');
            tc.verifyEqual(rmfield(b, 'Files'), rmfield(a, 'Files'), ...
                'and reports the same page, route and resolution');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function theWrapperIsThinOverPrint(tc)
            % What this measures is whether the sizing, state-saving and
            % routing around PRINT cost anything next to PRINT itself.
            % They should not: the work is one file write.
            %
            % Weak by construction - it times a disk write through a
            % graphics stack, so the denominator is neither stable nor
            % ours. It is here to catch an order-of-magnitude change, and
            % nothing finer should be read into it.
            d = tc.scratch();
            f = tc.exportFigure();
            f.PaperUnits = 'centimeters';
            f.PaperPositionMode = 'manual';
            f.PaperPosition = [0 0 8 6];
            f.PaperSize = [8 6];
            a = fullfile(d, "a.png");
            b = fullfile(d, "b.png");
            tc.assertRatioBudget( ...
                @() geo.export(f, a, Width = 8, Height = 6, Resolution = 150), ...
                @() print(f, char(b), '-dpng', '-r150', '-image'), ...
                1.6, 1.1, "geo.export vs bare print, N = 1 figure at 8 cm", ...
                Weak = true, Repeats = 6);
        end
    end
end
