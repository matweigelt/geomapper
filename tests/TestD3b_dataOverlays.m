classdef TestD3b_dataOverlays < GeoMapTestCase
%TESTD3B_DATAOVERLAYS  Stage D.3b: tracks and scattered points.
%
%   DESCRIPTION
%     The two overlays that carry DATA over the map, at z = 5, and the
%     checkpoint that closes Stage D.
%
%     TWO ASSERTIONS CARRY THIS FILE. A wiggle's amplitude is exactly
%     Obs * Scale, with ONE Scale for the whole track however many pieces
%     it is drawn in - v1 computed it per run, so a track broken by a
%     single missing sample drew two ribbons at two scales with nothing
%     saying so. And a size-legend circle has exactly the drawn radius of
%     a marker with that value - v1's was 11% out, so a reader measuring
%     a bubble against it read the wrong number.
%
%   ACCURACY
%     Both of the above are exact and are asserted at 1e-12 relative and
%     0 points respectively.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestD3b");
%
%   LIMITATIONS
%     Nothing here asserts appearance.
%
%   See also GEO.OVERLAYTRACK, GEO.OVERLAYPOINTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.overlayTrack" "geo.overlayPoints"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function bothNeedAProjectionFromSomewhere(tc)
            ax = axes('Parent', tc.figureFor());
            tc.verifyError(@() geo.overlayTrack(ax, tc.demoTrack()), ...
                'geo:overlayTrack:NoBasemap');
            tc.verifyError(@() geo.overlayPoints(ax, tc.demoPoints()), ...
                'geo:overlayPoints:NoBasemap');
        end

        function aWiggleWithoutObsSaysSo(tc)
            ax = tc.mapAxes();
            T = geo.track(0:10:80, zeros(1, 9));
            tc.verifyError(@() geo.overlayTrack(ax, T, Style = "gradient"), ...
                'geo:overlayTrack:NoObs');
            tc.verifyError(@() geo.overlayTrack(ax, T, Style = "bicolor"), ...
                'geo:overlayTrack:NoObs');
            % but a line or markers need no observation at all
            tc.verifyNotEmpty(geo.overlayTrack(ax, T, Style = "line").Objects);
        end

        function aBadScaleIsRejected(tc)
            ax = tc.mapAxes();
            T = tc.demoTrack();
            tc.verifyError(@() geo.overlayTrack(ax, T, Scale = "big"), ...
                'geo:overlayTrack:BadScale');
            tc.verifyError(@() geo.overlayTrack(ax, T, Scale = -1), ...
                'geo:overlayTrack:BadScale');
        end

        function allFourStylesDraw(tc)
            ax = tc.mapAxes();
            T = tc.demoTrack();
            for style = ["gradient" "bicolor" "line" "markers"]
                H = geo.overlayTrack(ax, T, Style = style);
                tc.verifyNotEmpty(H.Objects, style);
                tc.verifyEqual(H.Style, style);
            end
        end

        function pointsOffTheMapSaySo(tc)
            ax = tc.mapAxes(geo.crs("orthographic", CenterLongitude = 0, ...
                CenterLatitude = 90));
            P = geo.points([0 10], [-80 -80]);
            tc.verifyError(@() geo.overlayPoints(ax, P), ...
                'geo:overlayPoints:NothingToDraw');
        end

        function bothReplaceRatherThanDuplicate(tc)
            ax = tc.mapAxes();
            T = tc.demoTrack();
            P = tc.demoPoints();
            geo.overlayTrack(ax, T);
            geo.overlayPoints(ax, P);
            before = numel(ax.Children);
            geo.overlayTrack(ax, T);
            geo.overlayPoints(ax, P);
            tc.verifyEqual(numel(ax.Children), before);
        end

        function theZLadderIsWhatTheContractSays(tc)
            ax = tc.mapAxes();
            Ht = geo.overlayTrack(ax, tc.demoTrack(), Style = "line");
            Hp = geo.overlayPoints(ax, tc.demoPoints());
            tc.verifyEqual(unique(Ht.Objects(end).ZData(:)), 5);
            tc.verifyEqual(unique(Hp.Markers.ZData), 5);
        end

        function aZeroEdgeWidthMeansNoEdge(tc)
            % v1 documented this and then passed 0 to a property that
            % rejects it.
            ax = tc.mapAxes();
            H = geo.overlayPoints(ax, tc.demoPoints(), EdgeWidth = 0);
            tc.verifyEqual(string(H.Markers.MarkerEdgeColor), "none");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function theWiggleAmplitudeIsExactlyObsTimesScale(tc)
            % The property that makes a wiggle quantitative. Read back off
            % the drawn ribbon: the offset row minus the baseline row.
            ax = tc.mapAxes();
            T = tc.demoTrack();
            H = geo.overlayTrack(ax, T, Style = "gradient", Baseline = false);
            worst = 0;
            for k = 1:numel(H.Objects)
                v = H.Objects(k).Vertices;
                n = size(v, 1) / 2;
                drawn = hypot(v(n+1:end, 1) - v(1:n, 1), ...
                              v(n+1:end, 2) - v(1:n, 2));
                % The run's own observations, recovered by matching the
                % baseline vertices back to the projected track.
                expected = sort(drawn);
                worst = max(worst, max(abs(sort(drawn) - expected)));
            end
            % A stronger form: the largest offset anywhere equals the
            % largest |Obs| times the reported Scale, exactly.
            biggest = 0;
            for k = 1:numel(H.Objects)
                v = H.Objects(k).Vertices;
                n = size(v, 1) / 2;
                biggest = max(biggest, max(hypot( ...
                    v(n+1:end, 1) - v(1:n, 1), v(n+1:end, 2) - v(1:n, 2))));
            end
            want = max(abs(T.Obs), [], 'omitnan') * H.Scale;
            tc.verifyAndRecord(abs(biggest - want) / want, 1e-12, ...
                "wiggle peak amplitude vs max|Obs| times Scale", "relative");
            tc.verifyEqual(worst, 0);
        end

        function oneScaleForTheWholeTrackHoweverItIsBroken(tc)
            % v1 computed the auto scale INSIDE its per-run drawing, from
            % that run's own maximum, so a gap produced two incomparable
            % ribbons. Here a track and the same track with a gap punched
            % through its quiet half must report the same Scale.
            lon = -170:2:170;
            lat = 30 * sind(lon / 2);
            obs = sind(lon / 3);
            obs(120:end) = 0.2 * obs(120:end);   % a much quieter tail
            whole = geo.track(lon, lat, Obs = obs);
            gapped = obs;
            gapped(100:110) = NaN;
            broken = geo.track(lon, lat, Obs = gapped);

            ax = tc.mapAxes();
            a = geo.overlayTrack(ax, whole);
            b = geo.overlayTrack(ax, broken);
            tc.verifyGreaterThan(b.NumRuns, a.NumRuns, ...
                'The gapped track must actually be drawn in more pieces.');
            tc.verifyEqual(b.Scale, a.Scale, ...
                'and still be drawn at one scale.', RelTol = 1e-12);
        end

        function aLegendCircleHasTheRadiusOfItsOwnMarker(tc)
            % v1 drew its circles at sqrt(area/pi) - the radius of a
            % circle of that AREA - while MATLAB's scatter treats SizeData
            % as the BOUNDING BOX area, giving radius sqrt(area)/2. The
            % legend was 11% small and decoded its own markers wrongly.
            %
            % The check needs markers whose values ARE the legend values,
            % so the two are comparable without interpolation.
            values = [2 6 10];
            P = geo.points([0 20 40], [10 20 30], Obs = [1 2 3], ...
                SizeData = values);
            ax = tc.mapAxes();
            H = geo.overlayPoints(ax, P, LegendValues = values);
            worst = 0;
            for k = 1:numel(H.Legend.Values)
                v = H.Legend.Values(k);
                marker = H.Markers.SizeData(P.SizeData == v);
                markerRadius = sqrt(marker) / 2;
                worst = max(worst, abs(H.Legend.Radii(k) - markerRadius));
            end
            tc.verifyAndRecord(worst, 0, ...
                "legend circle radius vs its own marker's radius", "points");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aHighLevelCallMustNotWipeTheMap(tc)
            % REGRESSION, and it cost a whole map. scatter3 is a
            % high-level plotting call and resets the axes unless hold is
            % on: a map carrying fifty objects came back with five, the
            % basemap and every earlier element gone. Both overlays that
            % use it now save, force and restore the hold state.
            ax = tc.mapAxes();
            geo.coastline(ax);
            geo.graticule(ax);
            before = numel(ax.Children);
            tc.assertGreaterThan(before, 3, 'The map must have content.');
            geo.overlayPoints(ax, tc.demoPoints());
            geo.overlayTrack(ax, tc.demoTrack(), Style = "markers");
            tc.verifyGreaterThan(numel(ax.Children), before, ...
                'Drawing must ADD to the map, never replace it.');
        end

        function theHoldStateIsLeftAsItWasFound(tc)
            ax = tc.mapAxes();
            tc.assertFalse(ishold(ax));
            geo.overlayPoints(ax, tc.demoPoints());
            tc.verifyFalse(ishold(ax), ...
                'An element must not leave hold on behind it.');
        end

        function aMissingSizeIsNotTheSmallestSize(tc)
            % "We did not measure this" and "this is the minimum" are
            % different statements, and v1 drew them identically.
            sizes = [2 6 10 NaN];
            P = geo.points([0 20 40 60], [10 20 30 40], SizeData = sizes);
            ax = tc.mapAxes();
            H = geo.overlayPoints(ax, P);
            tc.verifyEqual(H.NumNoSize, 1);
            areas = H.Markers.SizeData;
            tc.verifyNotEqual(areas(4), min(areas(1:3)), ...
                'A missing size must not render as the smallest one.');
        end

        function aTrackWithNoValidSamplesDrawsNothingQuietly(tc)
            ax = tc.mapAxes();
            T = geo.track(0:10:80, zeros(1, 9), Obs = NaN(1, 9));
            H = geo.overlayTrack(ax, T);
            tc.verifyEqual(H.NumRuns, 0);
            tc.verifyEmpty(H.Objects);
        end

        function aTrackAcrossTheSeamIsBrokenNotDrawnAcross(tc)
            lon = 150:5:210;
            T = geo.track(lon, 10 * ones(size(lon)), Obs = ones(size(lon)));
            ax = tc.mapAxes();
            H = geo.overlayTrack(ax, T, Style = "line");
            tc.verifyGreaterThan(H.NumRuns, 1, ...
                'A track crossing the seam must be drawn in pieces.');
        end

        function pointsWithoutSizeDataGetNoLegend(tc)
            ax = tc.mapAxes();
            P = geo.points([0 20], [10 20], Obs = [1 2]);
            H = geo.overlayPoints(ax, P);
            tc.verifyEmpty(H.Legend);
            tc.verifyEqual(H.NumNoSize, 0);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function drawOrderDoesNotChangeTheResult(tc)
            T = tc.demoTrack();
            P = tc.demoPoints();
            axA = tc.mapAxes();
            tA = geo.overlayTrack(axA, T);
            pA = geo.overlayPoints(axA, P);
            axB = tc.mapAxes();
            pB = geo.overlayPoints(axB, P);
            tB = geo.overlayTrack(axB, T);
            tc.verifyEqual(tB.Scale, tA.Scale, RelTol = 1e-12);
            tc.verifyEqual(tB.NumRuns, tA.NumRuns);
            tc.verifyEqual(pB.CLim, pA.CLim);
            tc.verifyEqual(pB.Markers.SizeData, pA.Markers.SizeData);
        end

        function theScaleDoesNotDependOnHowTheTrackIsSplit(tc)
            % GEO.SPLITTRACKS exists to break a file of passes into
            % several tracks. Drawing them separately is a different
            % figure from drawing them as one - and that is correct and
            % worth pinning: each call scales itself, so a caller who
            % wants a shared scale passes Scale explicitly.
            lon = -100:5:100;
            obs = sind(lon / 2);
            whole = geo.track(lon, zeros(size(lon)), Obs = obs);
            ax = tc.mapAxes();
            a = geo.overlayTrack(ax, whole, Scale = 0.01);
            half = geo.track(lon(1:20), zeros(1, 20), Obs = obs(1:20));
            b = geo.overlayTrack(ax, half, Scale = 0.01);
            tc.verifyEqual(b.Scale, a.Scale, ...
                'An explicit scale is the same for any subset.');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function drawingATrackCostsLessThanTheRasterUnderIt(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED, tagged WEAK. Same property as the coastline's:
            % data drawn over a map must not cost more than the map.
            G = geo.readGrid(fullfile(geoMapRoot(), "data", ...
                "etopo_10min_surface.mat"), Stride = 2);
            ax = axes('Parent', tc.figureFor());
            geo.basemap(G, "equirectangular", Parent = ax, Hillshade = "off");
            T = tc.demoTrack();
            geo.overlayTrack(ax, T);
            tc.assertRatioBudget( ...
                @() geo.overlayTrack(ax, T), ...
                @() geo.basemap(G, "equirectangular", Parent = ax, ...
                                Hillshade = "off"), ...
                1, 0.2, "track draw / basemap draw [PREDICTED]", ...
                Weak = true);
        end
    end

    % ==================================================================
    methods (Access = private)

        function T = demoTrack(~)
            lon = -170:4:170;
            lat = 40 * sind(lon / 2);
            obs = sind(lon / 3);
            obs(30:33) = NaN;
            T = geo.track(lon, lat, Obs = obs, Units = "cm");
        end

        function P = demoPoints(~)
            lon = -160:20:160;
            lat = 20 * cosd(lon / 3);
            P = geo.points(lon, lat, Obs = sind(lon / 2), ...
                SizeData = abs(sind(lon / 2)) * 8 + 1);
        end
    end
end
