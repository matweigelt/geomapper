classdef TestE2_dataMaps < GeoMapTestCase
%TESTE2_DATAMAPS  Stage E.2: the two data-map fronts, and one shared backdrop.
%
%   DESCRIPTION
%     One assertion carries this file: the automatic extent CONTAINS
%     every finite data point, and the margin on each side equals Pad
%     times that side's span. A map that clipped the track it was built
%     for would be worse than no map, and v1's two data fronts each
%     carried their own copy of this arithmetic.
%
%     The second theme is that GEO.TRACKMAP and GEO.POINTMAP are
%     seventeen executable lines each. v1's geoImagescTrack and
%     geoImagescPoints were 75- and 82-option near-clones of a 3413-line
%     function; here the two differ by one word and share one resolver.
%
%   ACCURACY
%     The pad is exact - asserted at 1e-12 relative on the returned
%     limits, on both fronts.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestE2");
%
%   LIMITATIONS
%     Nothing here asserts appearance. The antimeridian case is
%     documented as needing explicit limits and is not tested as an
%     automatic extent, because there is no right answer to assert.
%
%   See also GEO.TRACKMAP, GEO.POINTMAP, GEO.INTERNAL.MAPBACKDROP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.trackmap" "geo.pointmap" ...
            "geo.internal.mapBackdrop" "geo.internal.splitOptions" ...
            "geo.internal.withData" "geo.internal.backdropOptions" ...
            "geo.internal.dataFile"]
    end

    methods (Access = private)

        function T = demoPass(~)
            lon = -20:2:40;
            T = geo.track(lon, 30 + 20 * sind(lon * 3), ...
                Obs = sind(lon / 2), Units = "cm");
        end

        function P = demoStations(~)
            P = geo.points([-10 5 22 33], [35 48 31 44], ...
                Obs = [1 -2 3 0.5], SizeData = [1 2 3 4]);
        end

    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function bothFrontsDeclareThemselvesAndDrawNothing(tc)
            % STRENGTHENED at E.4: this carried its own shorter banned
            % list, so neither front was ever checked for ylabel,
            % xlabel, legend or sgtitle. Four copies had drifted; there
            % is one list now.
            tc.verifyIsAPureFront("geo.trackmap");
            tc.verifyIsAPureFront("geo.pointmap");
        end

        function bothFrontsOwnExactlyTheSameOptions(tc)
            % Not asserted by reading the two files - asserted by there
            % being only one list. v1's two data fronts each carried
            % their own extent options and disagreed about the pad.
            names = geo.internal.backdropOptions();
            tc.verifyEqual(names, unique(names, 'stable'), ...
                'a duplicated name would be owned twice');
            for fn = ["geo.trackmap" "geo.pointmap"]
                src = fileread(which(fn));
                tc.verifyTrue(contains(src, "geo.internal.backdropOptions"), ...
                    fn + " must take the shared list, not a literal");
            end
        end

        function splitOptionsPartitionsWithoutLosingAnything(tc)
            nv = {'Pad', 0.2, 'Title', "t", 'Region', [0 1 2 3], 'Frame', false};
            [own, rest] = geo.internal.splitOptions(nv, ["Pad" "Region"]);
            tc.verifyEqual(sort(string(fieldnames(own)))', ["Pad" "Region"]);
            tc.verifyEqual(own.Pad, 0.2);
            tc.verifyEqual(rest, {'Title', "t", 'Frame', false});
        end

        function anOptionNotGivenIsAbsentNotDefaulted(tc)
            % ISFIELD has to distinguish "not set" from "set to the
            % default", because the resolver's precedence depends on
            % which of them it is.
            [own, ~] = geo.internal.splitOptions({'Pad', 0.2}, ...
                geo.internal.backdropOptions());
            tc.verifyFalse(isfield(own, 'Region'));
            tc.verifyTrue(isfield(own, 'Pad'));
        end

        function splitOptionsRejectsAnOddList(tc)
            tc.verifyError(@() geo.internal.splitOptions({'Pad'}, "Pad"), ...
                'geo:splitOptions:OddArguments');
        end

        function withDataMergesRatherThanReplaces(tc)
            % A struct assignment here would discard the caller's Style
            % silently, and they would see a default-styled map with no
            % error and no clue.
            nv = geo.internal.withData({'Track', struct('Style', "bicolor")}, ...
                "Track", struct('T', 42));
            s = nv{2};
            tc.verifyEqual(s.Style, "bicolor");
            tc.verifyEqual(s.T, 42);
        end

        function withDataDoesNotOverruleTheCaller(tc)
            nv = geo.internal.withData({'Track', struct('T', 7)}, ...
                "Track", struct('T', 42));
            s = nv{2};
            tc.verifyEqual(s.T, 7, ...
                'an explicit field wins over the front''s own');
        end

        function theExtentHasTheDocumentedPrecedence(tc)
            T = tc.demoPass();
            box = [-5 5 -5 5];
            a = tc.keep(geo.trackmap(T, [], 'LonLimit', [0 10], ...
                'LatLimit', [0 10], 'Region', box, 'Colorbar', false));
            tc.verifyEqual(a.Region.LonLim, [0 10], ...
                'explicit limits beat Region');
            b = tc.keep(geo.trackmap(T, [], 'Region', box, 'Colorbar', false));
            tc.verifyEqual(b.Region.LonLim, [-5 5], ...
                'Region beats the automatic box');
            c = tc.keep(geo.trackmap(T, [], 'Colorbar', false));
            tc.verifyGreaterThan(diff(c.Region.LonLim), ...
                max(T.Lon) - min(T.Lon), 'and the box is padded');
        end

        function dataWithNoFinitePositionSaysSo(tc)
            T = geo.track([NaN NaN], [NaN NaN]);
            tc.verifyError(@() geo.trackmap(T), ...
                'geo:mapBackdrop:NoFinitePoints');
        end

        function theResultCarriesTheRegionAndTheGrid(tc)
            H = tc.keep(geo.trackmap(tc.demoPass(), [], 'Colorbar', false));
            tc.verifyTrue(isfield(H, 'Region'));
            tc.verifyTrue(isfield(H, 'Grid'));
            tc.verifyEqual(H.Grid.Identity, "geo.grid");
            tc.verifyEqual(H.Region.Identity, "geo.region");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function theAutoExtentContainsEveryPointWithTheDocumentedPad(tc)
            % The claim both fronts make in their help, asserted on the
            % limits they return, for both of them.
            pad = 0.08;
            worst = 0;
            T = tc.demoPass();
            P = tc.demoStations();
            cases = {tc.keep(geo.trackmap(T, [], 'Pad', pad, 'Colorbar', false)), ...
                     [T.Lon(:) T.Lat(:)]; ...
                     tc.keep(geo.pointmap(P, [], 'Pad', pad, 'Colorbar', false)), ...
                     [P.Lon(:) P.Lat(:)]};
            for k = 1:size(cases, 1)
                R = cases{k, 1}.Region;
                xy = cases{k, 2};
                lim = [R.LonLim; R.LatLim];
                for a = 1:2
                    v = xy(:, a);
                    span = max(v) - min(v);
                    tc.verifyLessThanOrEqual(lim(a, 1), min(v), ...
                        'the extent must contain the data');
                    tc.verifyGreaterThanOrEqual(lim(a, 2), max(v), ...
                        'the extent must contain the data');
                    worst = max([worst, ...
                        abs((min(v) - lim(a, 1)) / span - pad), ...
                        abs((lim(a, 2) - max(v)) / span - pad)]);
                end
            end
            tc.verifyAndRecord(worst, 1e-12, ...
                "auto-extent margin vs Pad times the data span, both fronts", ...
                "relative");
        end

        function theBuiltinDataIsFoundWithoutTheTestFolder(tc)
            % PV-115. geo.readCoastline("builtin") located its file with
            % fullfile(geoMapRoot(), ...) and geoMapRoot lives in tests/,
            % so an INSTALLED toolbox raised "Unrecognized function or
            % variable 'geoMapRoot'". Every test passed because the
            % harness always has tests/ on the path - which is exactly
            % the shape of defect a test suite is blind to unless it
            % looks at the question directly.
            p = geo.internal.dataFile("coast_110m.mat");
            tc.verifyTrue(isfile(p), 'the shipped coastline must be found');
            pkg = fileparts(fileparts(which('geo.internal.dataFile')));
            tc.verifyTrue(startsWith(p, fileparts(pkg)), ...
                'and found relative to the package, not to the path');
            % CODE LINES ONLY, and this is the fourth time this project
            % has met the same shape. Written as a CONTAINS over the
            % whole file, this failed on geo.readCoastline - whose
            % comment EXPLAINS that geoMapRoot must not be used here.
            % PV-102 was the same thing on the L4-FRONT marker,
            % arrayGrowth met it on the file documenting the AGROW ban,
            % and checkPrinting carries a comment about it. Prose about
            % a token is not the token, and only stripping the comments
            % tells them apart.
            for f = ["geo.readCoastline" "geo.readGrid"]
                code = regexprep(string(splitlines(fileread(which(f)))), ...
                    '%.*$', '');
                tc.verifyEmpty(find(contains(code, "geoMapRoot("), 1), ...
                    f + " must not reach into the test harness");
            end
        end

        function regionPaddingReportsWhatWasApplied(tc)
            % PV-116. The field is documented "As applied" and reported
            % the value that had been ignored, so a caller who asked for
            % a 5% margin on a box was told they had one.
            box = geo.region([-20 40 10 50], Padding = 0.05);
            tc.verifyEqual(box.LonLim, [-20 40], 'a box is a stated extent');
            tc.verifyEqual(box.Padding, 0, 'and reports no padding applied');
            named = geo.region("north america", Padding = 0.05);
            tc.verifyEqual(named.Padding, 0);
            out = geo.region([0 0; 10 10], Padding = 0.05);
            tc.verifyEqual(out.Padding, 0.05, 'an outline is padded');
            tc.verifyEqual(out.LonLim, [-0.5 10.5], AbsTol = 1e-12);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aSinglePointStillGetsAMap(tc)
            % A fractional pad around a zero span is zero, so the map
            % would have no extent at all. Half a degree is arbitrary,
            % which is why it is stated in the code rather than tuned.
            H = tc.keep(geo.pointmap(geo.points(10, 45), [], 'Colorbar', false));
            tc.verifyGreaterThan(diff(H.Region.LonLim), 0);
            tc.verifyGreaterThan(diff(H.Region.LatLim), 0);
        end

        function theBackgroundIsNeverFinerThanItsSource(tc)
            % Upsampling topography makes a smoother picture out of no
            % more information, and a map that looks finer than its data
            % is a map that lies about its resolution.
            src = geo.readGrid("builtin", Region = [0 4 40 44]);
            H = tc.keep(geo.trackmap(geo.track([1 3], [41 43], Obs = [1 2]), [], ...
                'LonLimit', [0 4], 'LatLimit', [40 44], ...
                'BackgroundResolution', 4000, 'Colorbar', false));
            tc.verifyLessThanOrEqual(numel(H.Grid.Lon), numel(src.Lon));
            tc.verifyLessThanOrEqual(numel(H.Grid.Lat), numel(src.Lat));
        end

        function theBackgroundCanBeFlatOrYourOwn(tc)
            T = tc.demoPass();
            flat = tc.keep(geo.trackmap(T, [], 'Background', false, ...
                'Colorbar', false));
            tc.verifyEqual(numel(flat.Grid.Lon), 2, ...
                'a flat backdrop carries no information it does not have');
            mine = geo.readGrid("builtin", Region = [-30 50 0 60], Stride = [4 4]);
            own = tc.keep(geo.trackmap(T, [], 'Background', mine, ...
                'Colorbar', false));
            tc.verifyLessThan(numel(own.Grid.Lon), numel(mine.Lon) + 1);
        end

        function everythingElseReachesGeoMap(tc)
            % The forwarding claim, exercised across a spread of GEO.MAP
            % options that this front knows nothing about.
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            H = tc.keep(geo.trackmap(tc.demoPass(), [], ...
                'Title', "forwarded", 'ScaleBar', true, 'NorthArrow', true, ...
                'Graticule', struct('StepLon', 20), 'Coastline', false, ...
                'Colorbar', struct('Label', "cm")));
            tc.verifyTrue(all(ismember(["Title" "ScaleBar" "NorthArrow" ...
                "Graticule" "Colorbar" "Track"], H.Order)));
            tc.verifyFalse(isfield(H, 'Coastline'));
            tc.verifyEqual(H.Graticule.LonTicks(2) - H.Graticule.LonTicks(1), 20);
        end

        function exportingFromAFrontWritesTheFile(tc)
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            file = fullfile(d, "t.png");
            tc.keep(geo.trackmap(tc.demoPass(), [], 'Colorbar', false, ...
                'Export', file, 'ExportOptions', ...
                struct('Width', 9, 'Resolution', 150)));
            info = imfinfo(file);
            tc.verifyEqual(info.Width, round(9 / 2.54 * 150), AbsTol = 1);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function aFrontIsItsBackdropPlusGeoMapAndNothingElse(tc)
            % The composition claim, one layer up from TestE1's: if the
            % front added behaviour of its own, these would differ.
            T = tc.demoPass();
            own = struct('Pad', 0.05);
            [R, G, crs] = geo.internal.mapBackdrop([T.Lon(:) T.Lat(:)], [], own);
            a = tc.keep(geo.map(G, crs, Track = struct('T', T), ...
                Colorbar = false));
            b = tc.keep(geo.trackmap(T, [], 'Colorbar', false));
            tc.verifyEqual(b.Basemap.Surface.CData, a.Basemap.Surface.CData);
            tc.verifyEqual(b.Order, a.Order);
            tc.verifyEqual(b.Region.LonLim, R.LonLim);
        end

        function theOrderOfOptionsDoesNotMatter(tc)
            T = tc.demoPass();
            a = tc.keep(geo.trackmap(T, [], 'Pad', 0.1, 'Colorbar', false, ...
                'Title', "x"));
            b = tc.keep(geo.trackmap(T, [], 'Title', "x", 'Colorbar', false, ...
                'Pad', 0.1));
            tc.verifyEqual(b.Region.LonLim, a.Region.LonLim);
            tc.verifyEqual(b.Order, a.Order);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function theFrontCostsNoMoreThanItsParts(tc)
            T = tc.demoPass();
            own = struct('Pad', 0.05);
            [R, G, crs] = geo.internal.mapBackdrop([T.Lon(:) T.Lat(:)], [], own); %#ok<ASGLU>
            tc.assertRatioBudget( ...
                @() front(T), @() byHand(G, crs, T), ...
                1.6, 1.2, "geo.trackmap vs mapBackdrop plus geo.map, N = 1 map", ...
                Weak = true, Repeats = 4);

            function front(T)
                H = geo.trackmap(T, [], 'Colorbar', false);
                close(H.Figure);
            end
            function byHand(G, crs, T)
                H = geo.map(G, crs, Track = struct('T', T), Colorbar = false);
                close(H.Figure);
            end
        end
    end
end
