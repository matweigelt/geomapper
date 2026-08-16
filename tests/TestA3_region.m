classdef TestA3_region < GeoMapTestCase
%TESTA3_REGION  Stage A.3: region, great circle, track splitting.
%
%   DESCRIPTION
%     The three ported functions that close Stage A. Two of them carry
%     v1 behaviour forward deliberately - the conventional preset boxes
%     and the median-of-positive-dt auto threshold are named regression
%     anchors in the handover's Appendix B - so a good part of this suite
%     asserts that v1's hard-won guards survived the port.
%
%   ACCURACY
%     Distances and bearings come from the mirror, which measured them
%     against oracle O4 (pyproj.Geod on WGS84). The spherical model's
%     error is asserted as a NUMBER rather than described, because
%     decision D-001 rests on it.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestA3");
%
%   LIMITATIONS
%     The Stage C file hook is asserted as a REFUSAL here. When Stage C
%     lands, that test converts into a success test rather than being
%     deleted and rewritten.
%
%   See also GEO.REGION, GEO.GREATCIRCLE, GEO.SPLITTRACKS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.region" "geo.greatCircle" ...
                            "geo.splitTracks"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function everyFormOfSpecResolves(tc)
            named = geo.region("north america");
            tc.verifyEqual(named.Name, "northamerica", ...
                'the space is optional, as in v1');
            tc.verifyEqual(named.LonLim, [-170 -50]);
            % CHANGED at E.1b, and the old assertion is worth reading:
            % it required Outline to be EMPTY for a preset, with the
            % diagnostic "an empty outline is how a caller knows". That
            % made the field mean "the polygon, IF this region happened
            % to be given as one" - a meaning that depended on how the
            % region was built, so anything wanting to draw a region had
            % to ask which kind it was and derive the rectangle itself.
            % A box has four corners; they are now computed once in
            % geo.region, and Outline means the vertices of THIS region
            % for every region. Closed, so it draws four sides.
            tc.verifyEqual(size(named.Outline), [5 2], ...
                'a box carries its own corners');
            tc.verifyEqual(named.Outline(end, :), named.Outline(1, :), ...
                'and closes');
            tc.verifyEqual(unique(named.Outline(:, 1))', named.LonLim);
            tc.verifyEqual(unique(named.Outline(:, 2))', named.LatLim);

            box = geo.region([-25 45 34 72]);
            tc.verifyEqual(box.LatLim, [34 72]);
            tc.verifyEqual(box.Name, "");

            poly = geo.region([0 0; 10 0; 10 10; 0 10], Padding = 0);
            tc.verifyEqual(poly.LonLim, [0 10]);
            tc.verifyEqual(size(poly.Outline), [4 2]);

            none = geo.region([]);
            tc.verifyTrue(none.IsEmpty);
            tc.verifyTrue(all(isnan(none.LonLim)), ...
                'no region means NaN limits, so a caller falls back');
        end

        function badSpecificationsAreRejected(tc)
            tc.verifyError(@() geo.region("atlantis"), ...
                'geo:region:UnknownPreset');
            tc.verifyError(@() geo.region([45 -25 34 72]), ...
                'geo:region:InvalidBoundingBox');
            tc.verifyError(@() geo.region([170 -170 -10 10]), ...
                'geo:region:InvalidBoundingBox');
            tc.verifyError(@() geo.region({1, 2}), ...
                'geo:region:InvalidSpec');
            tc.verifyError(@() geo.region([NaN NaN; NaN NaN]), ...
                'geo:region:EmptyOutline');
        end

        function fileInputReachesTheReader(tc)
            % CONVERTED AT STAGE C, as promised, rather than deleted and
            % rewritten. Between Stage A and Stage C this asserted
            % geo:region:FileInputNotYetAvailable; now the same call
            % reaches geo.readCoastline, so a missing file surfaces the
            % READER's identifier and the capability is real.
            tc.verifyError(@() geo.region("no_such_basin.shp"), ...
                'geo:readCoastline:FileNotFound');
            tc.verifyError(@() geo.region("no_such_coast.b"), ...
                'geo:readCoastline:FileNotFound');
        end

        function theGreatCircleFormIsChosenUnambiguously(tc)
            p = [2.3522 48.8566];
            tc.verifyError(@() geo.greatCircle(p), ...
                'geo:greatCircle:AmbiguousForm');
            tc.verifyError(@() geo.greatCircle(p, [0 0], Bearing = 90, ...
                Distance = 100), 'geo:greatCircle:AmbiguousForm');
            tc.verifyError(@() geo.greatCircle(p, Bearing = 90), ...
                'geo:greatCircle:IncompleteForm');
            tc.verifyError(@() geo.greatCircle(p, Distance = 100), ...
                'geo:greatCircle:IncompleteForm');
        end

        function mismatchedPointSetsAreRejectedButOneBroadcasts(tc)
            a = [0 0; 10 10; 20 20];
            tc.verifyError(@() geo.greatCircle(a, [0 0; 1 1]), ...
                'geo:greatCircle:SizeMismatch');
            g = geo.greatCircle(a, [0 0]);
            tc.verifyEqual(numel(g.DistanceKm), 3, ...
                'a single point broadcasts against many');
        end

        function splitTracksRefusesWhatIsNotATrack(tc)
            tc.verifyError(@() geo.splitTracks(geo.points([1 2], [1 2])), ...
                'geo:track:NotATrack');
            T = tc.simpleTrack();
            tc.verifyError(@() geo.splitTracks(T, GroupID = [1 2]), ...
                'geo:splitTracks:GroupIDSizeMismatch');
        end

        function aTimeThresholdWithoutATimeIsRejected(tc)
            T = geo.track([1 2 3], [1 2 3]);        % no Time
            tc.verifyError(@() geo.splitTracks(T, ...
                TimeGapThreshold = "10"), 'geo:splitTracks:NoTime');
        end

        function shortPassesAreDroppedLoudly(tc)
            % The warning is part of the contract, so it is asserted -
            % and suppressed with a cleanup-based restore, so a failing
            % assertion cannot leave the warning state altered for the
            % suites that follow (handover 2.5).
            tc.suppressWarning("geo:splitTracks:TracksDropped");
            t = [1 2 3 100 200 201 202 203];
            T = geo.track(linspace(0, 7, 8), linspace(0, 7, 8), Time = t);
            [T2, id] = geo.splitTracks(T, MinTrackPoints = 3);
            tc.verifyTrue(any(isnan(id)), ...
                'a dropped sample is NaN in trackID, not renumbered away');
            tc.verifyLessThan(sum(~isnan(id)), numel(t));
            tc.verifyEqual(numel(id), numel(t), ...
                'trackID is reported at the ORIGINAL length');
            tc.verifyEqual(T2.Identity, "geo.track");
        end

        function trackIDLinesUpWithTheInputEvenAfterRegionFiltering(tc)
            T = geo.track(0:10, zeros(1, 11), Time = 0:10);
            [~, id] = geo.splitTracks(T, Region = [3 7 -1 1]);
            tc.verifyEqual(numel(id), 11);
            tc.verifyTrue(all(isnan(id([1 2 3 9 10 11]))), ...
                'samples outside the region are NaN, at their own indices');
            tc.verifyTrue(all(~isnan(id(4:8))));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function parisToNewYorkAgreesWithTheMirror(tc)
            ref = tc.loadMirrorReference("stage_a_great_circle");
            g = geo.greatCircle([2.3522 48.8566], [-74.0060 40.7128]);
            tc.verifyAndRecord(abs(g.DistanceKm - ref.spherical_km), ...
                1e-6, "Paris-NY spherical distance vs mirror", "km");
            tc.verifyAndRecord( ...
                abs(g.InitialBearingDeg - ref.initial_bearing_spherical_deg), ...
                1e-9, "Paris-NY initial bearing vs mirror", "deg");
        end

        function theCostOfTheSphericalModelIsANumber(tc)
            % Decision D-001 claims "at most about 0.3%". That claim is
            % asserted here against oracle O4's WGS84 geodesic, so the
            % decision rests on a measurement rather than on a memory.
            ref = tc.loadMirrorReference("stage_a_great_circle");
            g = geo.greatCircle([2.3522 48.8566], [-74.0060 40.7128]);
            pct = 100 * (g.DistanceKm - ref.geodesic_wgs84_km) / ...
                  ref.geodesic_wgs84_km;
            tc.verifyAndRecord(abs(pct), 0.3, ...
                "spherical vs WGS84 geodesic, Paris-NY", "%");
            tc.verifyEqual(pct, ref.difference_pct, 'AbsTol', 1e-9);
        end

        function thePresetsAreV1sVerbatim(tc)
            % Ported, not re-invented: a v2 figure must cover the same
            % extent as the v1 figure it replaces. They are conventional
            % approximate boxes and the help says so.
            expected = { ...
                "world",        [-180 180 -90 90]; ...
                "europe",       [-25 45 34 72]; ...
                "africa",       [-20 55 -35 38]; ...
                "asia",         [25 180 -10 82]; ...
                "australia",    [110 155 -45 -10]; ...
                "antarctica",   [-180 180 -90 -60]};
            for k = 1:size(expected, 1)
                R = geo.region(expected{k, 1});
                tc.verifyEqual([R.LonLim R.LatLim], expected{k, 2}, ...
                    sprintf('preset %s', expected{k, 1}));
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'precision'})

        function destinationInvertsDistanceAndBearingExactly(tc)
            % The two forms are inverses, so composing them must return
            % the starting point. 1e-9 degrees is about 0.1 mm; the
            % arithmetic is closed-form both ways and nothing looser
            % would be evidence of anything.
            rng(42, 'twister');
            from = [rand(20, 1) * 360 - 180, rand(20, 1) * 160 - 80];
            to = [rand(20, 1) * 360 - 180, rand(20, 1) * 160 - 80];
            g = geo.greatCircle(from, to);
            back = geo.greatCircle(from, Bearing = g.InitialBearingDeg, ...
                Distance = g.DistanceKm);
            dLon = abs(geo.wrapLongitude(back(:, 1) - to(:, 1), 0));
            dLat = abs(back(:, 2) - to(:, 2));
            tc.verifyAndRecord(max(max(dLon), max(dLat)), 1e-9, ...
                "greatCircle destination round-trip", "deg");
        end

        function paddingCannotPushLatitudeOffTheSphere(tc)
            R = geo.region([0 10; 10 89.9], Padding = 1.0);
            tc.verifyLessThanOrEqual(R.LatLim(2), 90, ...
                'a latitude limit past the pole is not a limit');
            R2 = geo.region([0 -89.9; 10 -10], Padding = 1.0);
            tc.verifyGreaterThanOrEqual(R2.LatLim(1), -90);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function antipodalAndCoincidentPointsBehave(tc)
            R = 6371.0072;
            % Antipodes: half the circumference, and the bearing is
            % ill-conditioned by nature - asserted as such, not as a value.
            g = geo.greatCircle([0 0], [180 0]);
            tc.verifyEqual(g.DistanceKm, pi * R, 'RelTol', 1e-12);
            % A point to itself: zero distance, and no exception.
            g0 = geo.greatCircle([12 34], [12 34]);
            tc.verifyEqual(g0.DistanceKm, 0, 'AbsTol', 1e-12);
            tc.verifyTrue(isfinite(g0.InitialBearingDeg));
        end

        function repeatedTimestampsDoNotSplitEverySample(tc)
            % v1's hard-won guard: the auto threshold is the median of the
            % STRICTLY POSITIVE steps. A median including zeros would be
            % zero, every step would exceed it, and every sample would
            % become its own track.
            t = [0 0 0 1 1 1 2 2 2];
            T = geo.track(1:9, 1:9, Time = t);
            [T2, id] = geo.splitTracks(T);
            tc.verifyEqual(max(id), 1, ...
                'repeated timestamps are normal, not nine separate passes');
            tc.verifyEqual(T2.NumGaps, 0);
        end

        function anUnmeasurableThresholdSplitsNothing(tc)
            % Every step zero: nothing can be measured, so nothing is
            % split. Inventing a threshold here would be confident nonsense.
            T = geo.track(1:5, 1:5, Time = zeros(1, 5));
            [~, id] = geo.splitTracks(T);
            tc.verifyEqual(max(id), 1);
        end

        function anImpossibleMinimumIsAnErrorNotAnEmptyResult(tc)
            T = tc.simpleTrack();
            tc.verifyError(@() geo.splitTracks(T, MinTrackPoints = 999), ...
                'geo:splitTracks:NoTracksSurvived');
        end

        function aRegionThatExcludesAlmostEverythingIsAnError(tc)
            T = geo.track(0:10, zeros(1, 11), Time = 0:10);
            tc.verifyError(@() geo.splitTracks(T, ...
                Region = [100 110 -1 1]), 'geo:splitTracks:TooFewInRegion');
        end

        function regionRemovalForcesABreakEvenWhenNeighboursAreClose(tc)
            % Appendix B regression anchor. Two visits to the same place
            % must not be joined into one pass just because the samples
            % between them were removed.
            lon = [0 1 2 50 51 3 4 5];
            T = geo.track(lon, zeros(1, 8), Time = 1:8);
            [~, id] = geo.splitTracks(T, Region = [-1 10 -1 1]);
            kept = id(~isnan(id));
            tc.verifyEqual(max(kept), 2, ...
                'the removed samples leave a real gap, so two passes');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'vectorisation'})

        function batchedGreatCircleEqualsScalarCalls(tc)
            rng(42, 'twister');
            from = [rand(100, 1) * 360 - 180, rand(100, 1) * 160 - 80];
            to = [rand(100, 1) * 360 - 180, rand(100, 1) * 160 - 80];
            batch = geo.greatCircle(from, to);
            d = zeros(100, 1);
            b = zeros(100, 1);
            for i = 1:100
                one = geo.greatCircle(from(i, :), to(i, :));
                d(i) = one.DistanceKm;
                b(i) = one.InitialBearingDeg;
            end
            % Elementwise arithmetic throughout, so bit-identity is the
            % right claim and nothing looser will do.
            tc.verifyTrue(isequal(batch.DistanceKm, d));
            tc.verifyTrue(isequal(batch.InitialBearingDeg, b));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function regionIsIdempotent(tc)
            R = geo.region("europe");
            tc.verifyTrue(isequaln(geo.region(R), R));
            tc.verifyTrue(isequaln(geo.region(geo.region(R)), R));
            tc.verifyError(@() geo.region(geo.crs("mollweide")), ...
                'geo:region:NotARegion');
        end

        function distanceIsSymmetricInItsArguments(tc)
            rng(42, 'twister');
            a = [rand(50, 1) * 360 - 180, rand(50, 1) * 160 - 80];
            b = [rand(50, 1) * 360 - 180, rand(50, 1) * 160 - 80];
            tc.verifyEqual(geo.greatCircle(b, a).DistanceKm, ...
                geo.greatCircle(a, b).DistanceKm, 'AbsTol', 1e-9, ...
                'the distance from A to B is the distance from B to A');
        end

        function shiftingEveryTimestampChangesNothing(tc)
            % The auto threshold is built from DIFFERENCES, so an origin
            % shift must be invisible. If it is not, an absolute time has
            % leaked into a relative rule.
            t = [0 1 2 3 100 101 102];
            T1 = geo.track(1:7, 1:7, Time = t);
            T2 = geo.track(1:7, 1:7, Time = t + 1e6);
            [~, id1] = geo.splitTracks(T1);
            [~, id2] = geo.splitTracks(T2);
            tc.verifyTrue(isequaln(id1, id2));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function splitTracksAgainstABareScan(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED - V5 open. The denominator is the diff-and-find
            % scan the split must at minimum perform, on the SAME arrays.
            % N = 1e6 with a gap every 10 000 samples: 100 passes, which
            % is what a month of along-track data actually looks like.
            % The crossing-count lesson from A.1 applies here too, so the
            % pass count is recorded rather than left implicit.
            n = 1e6;
            t = (1:n) + 1e4 * floor((0:n-1) / 1e4);
            T = geo.track(linspace(-180, 180, n), ...
                linspace(-80, 80, n), Time = t);
            tc.verifyAndRecord(n / 1e4, 200, ...
                "splitTracks speed fixture: passes", "passes");
            tc.assertRatioBudget( ...
                @() geo.splitTracks(T), ...
                @() find(diff(t) > 5 * median(diff(t))), ...
                20, 8, ...
                "splitTracks / diff+find scan, N=1e6, 100 passes [PREDICTED]");
        end
    end

    % ==================================================================
    methods (Access = private)
        function T = simpleTrack(~)
            T = geo.track(1:10, 1:10, Time = 1:10, Obs = (1:10) / 2);
        end
    end
end
