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

        function twoExportsOfOneFigureAgreeByteForByte(tc)
            d = tc.scratch();
            f = tc.exportFigure();
            r = fullfile(d, ["r1.png" "r2.png" "r3.png"]);
            for k = 1:3
                geo.export(f, r(k), Width = 8, Resolution = 150);
            end
            % Three, not two, so the diagnostic can tell a FIRST-RENDER
            % effect from genuine nondeterminism: if 1 differs from 2 but
            % 2 equals 3, the figure was simply not realised yet the
            % first time, and that is a defect with a fix rather than a
            % property of the renderer.
            tc.verifyEqual(imread(r(2)), imread(r(1)), ...
                "1 vs 2: " + tc.imageDiff(r(1), r(2)) + ...
                " || 2 vs 3: " + tc.imageDiff(r(2), r(3)));
        end

        function theOrderOfABatchDoesNotChangeItsFiles(tc)
            d = tc.scratch();
            f = tc.exportFigure([1 1 1]);
            g = tc.exportFigure([0.5 0.5 0.5]);
            n = ["f1" "g1" "g2" "f2"];
            p = fullfile(d, n + ".png");
            geo.export([f g], p(1:2), Width = 6);
            geo.export([g f], p([3 4]), Width = 6);
            tc.verifyEqual(imread(p(4)), imread(p(1)), ...
                "first figure: " + tc.imageDiff(p(1), p(4)));
            tc.verifyEqual(imread(p(3)), imread(p(2)), ...
                "second figure: " + tc.imageDiff(p(2), p(3)));
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
