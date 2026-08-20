classdef TestE3_series < GeoMapTestCase
%TESTE3_SERIES  Stage E.3: one series element, one stacking front.
%
%   DESCRIPTION
%     One assertion carries this file: the drawn ordinate of series k
%     equals its Obs plus the offset the front REPORTS, exactly. A
%     stacked plot is read by subtracting the offsets by eye, so a plot
%     whose offsets were not exactly what it reported would be
%     unreadable in a way no reader could detect.
%
%     The second theme is the rule, for the third time. GEO.TIMESERIES
%     is a front and a front draws nothing, so a series needed an
%     element - GEO.SERIES - exactly as a title did at E.1a. The
%     reference lines go through the same element, because a horizontal
%     line at a constant value over the time span IS a series.
%
%   ACCURACY
%     The ordinate claim is exact and asserted at 0. The gap rule is
%     GEO.SPLITTRACKS', asserted by the band and the line breaking in
%     the same places.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestE3");
%
%   LIMITATIONS
%     Nothing here asserts appearance, and nothing asserts that the time
%     axis is formatted - this does not convert datenums, and says so.
%
%   See also GEO.SERIES, GEO.TIMESERIES.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.series" "geo.timeseries"]
    end

    methods (Access = private)

        function T = station(~, amp, noise)
            t = 0:0.05:8;
            T = geo.track(zeros(size(t)), zeros(size(t)), Time = t, ...
                Obs = amp * sin(t) + noise * 0.1 * sin(9 * t), ...
                Units = "cm");
        end

        function T = gapped(~)
            t = [0:0.05:4, 34:0.05:38];
            T = geo.track(zeros(size(t)), zeros(size(t)), Time = t, ...
                Obs = sin(t), Units = "cm");
        end

        function ax = plainAxes(tc)
            ax = axes('Parent', tc.figureFor());
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function geoTimeseriesIsAPureFront(tc)
            tc.verifyIsAPureFront("geo.timeseries");
        end

        function aSeriesNeedsTimeAndObs(tc)
            ax = tc.plainAxes();
            tc.verifyError(@() geo.series(ax, geo.track(0, 0)), ...
                'geo:series:NoTime');
            tc.verifyError(@() geo.series(ax, ...
                geo.track([0 1], [0 1], Time = [1 2])), 'geo:series:NoObs');
        end

        function uncertaintyIsScalarOrOnePerSample(tc)
            ax = tc.plainAxes();
            T = tc.station(1, 1);
            tc.verifyError(@() geo.series(ax, T, Uncertainty = [1 2 3]), ...
                'geo:series:UncertaintySize');
            tc.verifyNotEmpty(geo.series(ax, T, Uncertainty = 0.2).Band);
            tc.verifyNotEmpty(geo.series(ax, T, ...
                Uncertainty = 0.1 * ones(1, T.NumPoints)).Band);
        end

        function anEmptyStackSaysSo(tc)
            tc.verifyError(@() geo.timeseries(struct([])), ...
                'geo:timeseries:NoSeries');
        end

        function explicitOffsetsAndLabelsMustMatchTheCount(tc)
            T = [tc.station(1, 1) tc.station(2, 1)];
            tc.verifyError(@() geo.timeseries(T, Offset = [1 2 3]), ...
                'geo:timeseries:OffsetCount');
            tc.verifyError(@() geo.timeseries(T, Labels = ["a" "b" "c"]), ...
                'geo:timeseries:LabelCount');
        end

        function offsetFalsePutsEveryTraceOnOneBaseline(tc)
            T = [tc.station(1, 1) tc.station(2, 1)];
            H = tc.keep(geo.timeseries(T, Offset = false));
            tc.verifyEqual(H.Offsets, [0 0]);
            tc.verifyEqual(H.Spacing, 0);
        end

        function explicitOffsetsAreUsedAsGiven(tc)
            T = [tc.station(1, 1) tc.station(2, 1)];
            H = tc.keep(geo.timeseries(T, Offset = [10 -4]));
            tc.verifyEqual(H.Offsets, [10 -4]);
            tc.verifyEqual(H.Series(1).Offset, 10);
        end

        function theLabelSitsAtTheTraceNotInALegend(tc)
            % A legend makes the reader match a colour to a name across
            % the figure, which is the task stacking was meant to remove.
            ax = tc.plainAxes();
            T = tc.station(1, 1);
            right = geo.series(ax, T, Label = "ONSA");
            tc.verifyEqual(string(right.Label.String), "ONSA");
            tc.verifyEqual(string(right.Label.HorizontalAlignment), "left");
            left = geo.series(ax, T, Label = "ONSA", LabelSide = "left");
            tc.verifyLessThan(left.Label.Position(1), right.Label.Position(1));
            tc.verifyEmpty(geo.series(ax, T).Label, ...
                'no label asked for, no label drawn');
        end

        function theResultReportsWhatItApplied(tc)
            T = [tc.station(1, 1) tc.station(2, 1) tc.station(3, 1)];
            H = tc.keep(geo.timeseries(T));
            tc.verifyEqual(numel(H.Series), 3);
            tc.verifyEqual(numel(H.Offsets), 3);
            tc.verifyGreaterThan(H.Spacing, 0);
            for k = 1:3
                tc.verifyEqual(H.Series(k).Offset, H.Offsets(k));
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function theDrawnOrdinateIsObsPlusOffsetExactly(tc)
            % The claim the whole file exists for.
            T = [tc.station(1, 1) tc.station(3, 4) tc.station(0.5, 1)];
            H = tc.keep(geo.timeseries(T));
            worst = 0;
            for k = 1:numel(T)
                drawn = H.Series(k).Line.YData;
                drawn = drawn(isfinite(drawn));
                want = double(T(k).Obs(:)).' + H.Offsets(k);
                worst = max(worst, max(abs(drawn - want)));
            end
            tc.verifyAndRecord(worst, 0, ...
                "stacked ordinate vs Obs plus the reported offset", "cm");
        end

        function theOffsetsAreEvenlySpacedByTheReportedSpacing(tc)
            T = [tc.station(1, 1) tc.station(3, 4) tc.station(0.5, 1)];
            H = tc.keep(geo.timeseries(T));
            tc.verifyAndRecord(max(abs(diff(H.Offsets) + H.Spacing)), 1e-12, ...
                "stack spacing vs the reported Spacing", "cm");
        end

        function quantileTakesAColumnAndARowOfPercentages(tc)
            % PV-119. geo.quantile documents "Z any size; treated as a
            % flat collection" and could not do it: Z(isfinite(Z)) is a
            % COLUMN for a matrix, indexing a column with a row index
            % returns a column, and implicit expansion then built a 2x2
            % where a 1x2 was meant - RESHAPE failed with "number of
            % elements must not change". Invisible until now because
            % every caller passed a SCALAR p, where the expansion is 1x1.
            tc.verifyEqual(geo.quantile((1:10).', [5 95]), ...
                geo.quantile(1:10, [5 95]), ...
                'orientation of Z must not matter', AbsTol = 0);
            tc.verifyEqual(size(geo.quantile(1:10, [5; 95])), [2 1], ...
                'the result follows the shape of p');
            tc.verifyEqual(size(geo.quantile(1:100, [1 2; 3 4])), [2 2]);
            tc.verifyEqual(geo.quantile(magic(4), 50), ...
                geo.quantile(reshape(magic(4), 1, []), 50), AbsTol = 0);
            tc.verifyEqual(geo.quantile([1 2], 50), 1.5, ...
                'and F10 still holds', AbsTol = 0);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aGapBreaksTheLineAndTheBandTogether(tc)
            % A band that bridged a gap would assert a confidence over
            % an interval with no data.
            ax = tc.plainAxes();
            H = geo.series(ax, tc.gapped(), Uncertainty = 0.2);
            tc.verifyEqual(H.NumGaps, 1);
            tc.verifyEqual(numel(H.Band), 2, ...
                'one patch per unbroken run');
            tc.verifyEqual(nnz(isnan(H.Line.XData)), 1);
        end

        function gapThresholdNoneNeverBreaks(tc)
            ax = tc.plainAxes();
            H = geo.series(ax, tc.gapped(), GapThreshold = "none");
            tc.verifyEqual(H.NumGaps, 0);
            tc.verifyEqual(nnz(isnan(H.Line.XData)), 0);
        end

        function aFlatStationStillGetsSpacing(tc)
            % Every series constant: the 5-95 range is zero everywhere,
            % so a spacing derived from it would be zero and the traces
            % would sit on top of each other.
            t = 0:0.1:5;
            flat = geo.track(zeros(size(t)), zeros(size(t)), Time = t, ...
                Obs = ones(size(t)));
            H = tc.keep(geo.timeseries([flat flat]));
            tc.verifyGreaterThan(H.Spacing, 0);
            tc.verifyNotEqual(H.Offsets(1), H.Offsets(2));
        end

        function exportingFromTheFrontWritesTheFile(tc)
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            file = fullfile(d, "s.png");
            tc.keep(geo.timeseries(tc.station(1, 1), Export = file, ...
                ExportOptions = struct('Width', 9, 'Resolution', 150)));
            info = imfinfo(file);
            tc.verifyEqual(info.Width, round(9 / 2.54 * 150), AbsTol = 1);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function oneNoisyStationDoesNotFlattenTheRest(tc)
            % v1's spacing was the MAXIMUM per-station range, so a
            % single noisy station pushed every trace apart and the
            % quiet ones became flat lines. The median is robust to it:
            % adding one station ten times noisier than the others must
            % not multiply the spacing by ten.
            quiet = [tc.station(1, 1) tc.station(1, 1) tc.station(1, 1)];
            a = tc.keep(geo.timeseries(quiet));
            b = tc.keep(geo.timeseries([quiet tc.station(10, 1)]));
            tc.verifyLessThan(b.Spacing, 3 * a.Spacing, ...
                'a robust spacing survives one outlier');
        end

        function twoIdenticalCallsAgree(tc)
            T = [tc.station(1, 1) tc.station(2, 3)];
            a = tc.keep(geo.timeseries(T));
            b = tc.keep(geo.timeseries(T));
            tc.verifyEqual(b.Offsets, a.Offsets);
            tc.verifyEqual(b.Spacing, a.Spacing);
            tc.verifyEqual(b.Series(1).Line.YData, a.Series(1).Line.YData);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function theFrontCostsNoMoreThanItsSeries(tc)
            T = [tc.station(1, 1) tc.station(2, 1) tc.station(3, 1)];
            tc.assertRatioBudget( ...
                @() front(T), @() byHand(T), ...
                1.6, 1.2, "geo.timeseries vs three geo.series by hand, N = 3", ...
                Weak = true, Repeats = 4);

            function front(T)
                H = geo.timeseries(T);
                close(H.Figure);
            end
            function byHand(T)
                f = figure('Visible', 'off');
                ax = axes('Parent', f);
                for k = 1:numel(T)
                    geo.series(ax, T(k), Offset = k);
                end
                close(f);
            end
        end
    end
end
