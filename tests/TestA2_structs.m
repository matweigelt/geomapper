classdef TestA2_structs < GeoMapTestCase
%TESTA2_STRUCTS  Stage A.2: the three L0 value structs.
%
%   DESCRIPTION
%     Covers geo.grid, geo.track and geo.points, and the three internal
%     validators they share. These structs are the contract every later
%     layer trusts without re-checking, so what is tested here is mostly
%     what they REFUSE: the guarantees are only worth anything if the
%     rejections are real.
%
%   ACCURACY
%     No external oracle applies - these functions validate and record,
%     they do not compute. The claims are structural and behavioural, and
%     the one arithmetic claim (IsGlobalLon's 1.5-step allowance) is
%     asserted at both boundaries rather than in the middle.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestA2");
%
%   LIMITATIONS
%     Nothing here projects or draws. Whether a grid's contents are
%     sensible is not a question a constructor can answer.
%
%   See also GEO.GRID, GEO.TRACK, GEO.POINTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.grid" "geo.track" "geo.points" ...
                            "geo.internal.mustBeIdentity" ...
                            "geo.internal.mustBeSeries" ...
                            "geo.internal.countGaps"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function aGridRecordsWhatItWasGiven(tc)
            lon = -179.5:179.5;
            lat = (-89.5:89.5).';
            Z = rand(180, 360);
            G = geo.grid(lon, lat, Z, Units = "cm/yr", Source = "test");
            tc.verifyEqual(G.Identity, "geo.grid");
            tc.verifyEqual(G.Units, "cm/yr");
            tc.verifyEqual(G.Source, "test");
            tc.verifyEqual(G.Z, Z);
            tc.verifyEqual(G.LonStep, 1, 'AbsTol', 1e-12);
            tc.verifyEqual(G.LatStep, 1, 'AbsTol', 1e-12);
        end

        function theCanonicalOrientationIsRowLonColumnLat(tc)
            % The one place shape is not preserved, because Z fixes it.
            G = geo.grid((1:4).', 1:3, zeros(3, 4));
            tc.verifyTrue(isrow(G.Lon), 'Lon is canonicalised to a row');
            tc.verifyTrue(iscolumn(G.Lat), 'Lat is canonicalised to a column');
        end

        function aTransposedZIsRejectedNotTransposed(tc)
            % Guessing would put half of all data sideways in silence.
            tc.verifyError(@() geo.grid(1:4, 1:3, zeros(4, 3)), ...
                'geo:grid:SizeMismatch');
        end

        function descendingLatitudeIsAcceptedAndPreserved(tc)
            % Many products store north-up. Flipping silently would make
            % Z(1,:) mean different things for different callers.
            lat = (89.5:-1:-89.5).';
            G = geo.grid(-179.5:179.5, lat, zeros(180, 360));
            tc.verifyEqual(G.Lat, lat);
            tc.verifyLessThan(G.LatStep, 0, ...
                'the step keeps its sign, so consumers can read direction');
        end

        function aNaNInAnAxisIsRejectedButNaNInZIsNot(tc)
            % NaN is the gap convention for DATA. In an axis it is an
            % unanswerable question about where the neighbours lie.
            lat = (1:3).';
            tc.verifyError(@() geo.grid([1 NaN 3], lat, zeros(3, 3)), ...
                'geo:grid:NaNCoordinate');
            Z = zeros(3, 3);
            Z(2, 2) = NaN;
            G = geo.grid(1:3, lat, Z);
            tc.verifyTrue(isnan(G.Z(2, 2)), 'a gap in the data survives');
        end

        function nonMonotoneAndTooShortAxesAreRejected(tc)
            tc.verifyError(@() geo.grid([1 3 2], (1:3).', zeros(3, 3)), ...
                'geo:grid:NonMonotonic');
            tc.verifyError(@() geo.grid([1 1 2], (1:3).', zeros(3, 3)), ...
                'geo:grid:NonMonotonic');
            tc.verifyError(@() geo.grid(1, (1:3).', zeros(3, 1)), ...
                'geo:grid:TooFewPoints');
            tc.verifyError(@() geo.grid(ones(2, 2), (1:3).', zeros(3, 4)), ...
                'geo:grid:NotAVector');
        end

        function topoMustShareTheGrid(tc)
            tc.verifyError(@() geo.grid(1:3, (1:3).', zeros(3, 3), ...
                Topo = zeros(2, 2)), 'geo:grid:TopoSizeMismatch');
        end

        function aTrackKeepsItsGapsAndItsOrientation(tc)
            T = geo.track([10 11 NaN 13], [50 51 NaN 53], ...
                Obs = [1 2 NaN 4], Units = "m");
            tc.verifyEqual(T.Identity, "geo.track");
            tc.verifyEqual(T.NumPoints, 4);
            tc.verifyEqual(T.NumGaps, 1, ...
                'one outage is one gap, however many samples it spans');
            tc.verifyTrue(isnan(T.Lon(3)), 'the gap must survive');
            tc.verifyTrue(isrow(T.Lon), 'orientation is preserved');
            Tc = geo.track([10;11], [50;51]);
            tc.verifyTrue(iscolumn(Tc.Lon), 'and preserved the other way');
        end

        function timeMayRepeatButMayNotGoBackwards(tc)
            geo.track([1 2 3], [1 2 3], Time = [1 1 2]);   % must not throw
            tc.verifyError(@() geo.track([1 2 3], [1 2 3], ...
                Time = [1 3 2]), 'geo:track:TimeDecreasing');
        end

        function mismatchedCompanionVectorsAreRejected(tc)
            tc.verifyError(@() geo.track([1 2 3], [1 2]), ...
                'geo:track:SizeMismatch');
            tc.verifyError(@() geo.track([1 2 3], [1 2 3], Obs = [1 2]), ...
                'geo:track:SizeMismatch');
            tc.verifyError(@() geo.points([1 2 3], [1 2 3], ...
                Labels = ["a" "b"]), 'geo:points:SizeMismatch');
        end

        function aPointSetCountsWhatCanActuallyBeDrawn(tc)
            P = geo.points([10 NaN 30 40], [50 51 NaN 53]);
            tc.verifyEqual(P.NumPoints, 4);
            tc.verifyEqual(P.NumLocated, 2, ...
                ['a point needs BOTH coordinates to be drawable; ' ...
                 'counting one-legged points would make the numbers ' ...
                 'agree while the map showed fewer markers']);
        end

        function aNegativeMarkerSizeIsRejected(tc)
            tc.verifyError(@() geo.points([1 2], [1 2], ...
                SizeData = [1 -1]), 'geo:points:NegativeSize');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function isGlobalLonIsMeasuredAtBothConventions(tc)
            % Not an oracle in the register - there is none for a
            % convention - but a reference in the strict sense: the two
            % storage forms real products actually use, and the regional
            % case that must not be mistaken for either.
            lat = (1:3).';
            cases = { ...
                0:359,        true,  "0:359, one cell short of the circle"; ...
                0:360,        true,  "0:360, the seam repeated"; ...
                -180:179,     true,  "-180:179, the other centring"; ...
                0:350,        false, "0:350, genuinely regional"; ...
                0:0.25:359.75, true, "quarter-degree, one cell short"; ...
                0:5:180,      false, "a hemisphere"};
            for k = 1:size(cases, 1)
                lon = cases{k, 1};
                G = geo.grid(lon, lat, zeros(3, numel(lon)));
                tc.verifyEqual(G.IsGlobalLon, cases{k, 2}, ...
                    sprintf('%s', cases{k, 3}));
            end
        end

        function theGapCountMatchesRunsNotElements(tc)
            tc.verifyEqual(geo.internal.countGaps([1 NaN NaN 4 NaN 6]), 2);
            tc.verifyEqual(geo.internal.countGaps([NaN NaN]), 1);
            tc.verifyEqual(geo.internal.countGaps([1 2 3]), 0);
            tc.verifyEqual(geo.internal.countGaps([]), 0);
            tc.verifyEqual(geo.internal.countGaps([NaN 1 NaN]), 2);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'precision'})

        function theGlobalThresholdIsExactAtItsBoundary(tc)
            % The 1.5-step allowance is a number, so it has an edge, and
            % the edge is asserted rather than the comfortable middle.
            %
            % Expressed in WHOLE CELLS, which is the unit real grids come
            % in: a grid one step short of the circle is global (the
            % 0:359 convention), and one two steps short is not. That is
            % where 1.5 sits, and it is why the allowance is 1.5 rather
            % than 1 or 2 - it is the only value that separates those two
            % cases for every step size.
            %
            % An earlier version of this test built the boundary
            % arithmetically as 0:step:(360-1.5*step) and FAILED, because
            % the colon operator stops at 358 rather than 358.5 and the
            % span was a whole step short of what the test claimed to be
            % measuring.
            lat = (1:3).';
            for step = [1 0.25 2.5]
                oneShort = 0:step:(360 - step);
                twoShort = 0:step:(360 - 2 * step);
                g1 = geo.grid(oneShort, lat, zeros(3, numel(oneShort)));
                g2 = geo.grid(twoShort, lat, zeros(3, numel(twoShort)));
                tc.verifyTrue(g1.IsGlobalLon, sprintf( ...
                    'step %g: one cell short of the circle is global', step));
                tc.verifyFalse(g2.IsGlobalLon, sprintf( ...
                    'step %g: two cells short is not', step));
            end
        end

        function theStepIsAMedianNotAnAverage(tc)
            % A single irregular coordinate must not smear the step every
            % later function asks for.
            lon = [0 1 2 3 4 5 6 7 8 20];
            G = geo.grid(lon, (1:2).', zeros(2, 10));
            tc.verifyEqual(G.LonStep, 1, 'AbsTol', 1e-12, ...
                'the median ignores the outlier; a mean would read 2');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function theSmallestLegalGridIsAccepted(tc)
            G = geo.grid([0 1], [0; 1], zeros(2, 2));
            tc.verifyEqual(size(G.Z), [2 2]);
        end

        function anAllNaNFieldIsData(tc)
            % A grid of nothing but gaps is a legitimate input - a masked
            % product before the mask is applied - and must not be
            % mistaken for a broken one.
            G = geo.grid(1:3, (1:3).', nan(3, 3));
            tc.verifyTrue(all(isnan(G.Z(:))));
        end

        function emptyAndAllNaNSeriesAreAccepted(tc)
            T = geo.track([], []);
            tc.verifyEqual(T.NumPoints, 0);
            tc.verifyEqual(T.NumGaps, 0);
            P = geo.points(nan(1, 5), nan(1, 5));
            tc.verifyEqual(P.NumLocated, 0);
            tc.verifyEqual(P.NumPoints, 5);
        end

        function theStructsDoNotSubstituteForOneAnother(tc)
            % The handover's test: if two objects from different sources
            % were combined by mistake, would anything notice?
            G = geo.grid(1:3, (1:3).', zeros(3, 3));
            T = geo.track([1 2], [1 2]);
            P = geo.points([1 2], [1 2]);
            tc.verifyError(@() geo.grid(T), 'geo:grid:NotAGrid');
            tc.verifyError(@() geo.track(G), 'geo:track:NotATrack');
            tc.verifyError(@() geo.points(T), 'geo:points:NotAPoints');
            tc.verifyError(@() geo.grid(struct('a', 1)), 'geo:grid:NotAGrid');
            tc.verifyError(@() geo.track([P P]), 'geo:track:NotATrack');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'vectorisation'})

        function theGapCountIsIndependentOfShape(tc)
            % countGaps is the only arithmetic here, and it must read a
            % row and a column identically - a track's orientation is the
            % caller's business, not the counter's.
            v = [1 NaN NaN 4 NaN 6];
            tc.verifyEqual(geo.internal.countGaps(v), ...
                           geo.internal.countGaps(v.'), ...
                'a gap count must not depend on which way the data lies');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function everyConstructorIsIdempotent(tc)
            G = geo.grid(1:3, (1:3).', zeros(3, 3), Units = "m");
            T = geo.track([1 2 NaN], [1 2 NaN], Obs = [1 2 NaN]);
            P = geo.points([1 2], [1 2], Labels = ["a" "b"]);
            tc.verifyTrue(isequaln(geo.grid(G), G));
            tc.verifyTrue(isequaln(geo.track(T), T));
            tc.verifyTrue(isequaln(geo.points(P), P));
            % Twice, because idempotence is a claim about repetition.
            tc.verifyTrue(isequaln(geo.grid(geo.grid(G)), G));
        end

        function aGridIsInvariantUnderReversingItsLatitudeAxis(tc)
            % Flipping lat and Z together is the same grid described the
            % other way up. Everything except the sign of the step, and
            % the order of the rows, must be untouched.
            lat = (1:5).';
            Z = reshape(1:20, 5, 4);
            up = geo.grid(1:4, lat, Z);
            down = geo.grid(1:4, flipud(lat), flipud(Z));
            tc.verifyEqual(down.LatStep, -up.LatStep, 'AbsTol', 1e-12);
            tc.verifyEqual(flipud(down.Z), up.Z);
            tc.verifyEqual(down.IsGlobalLon, up.IsGlobalLon);
        end

        function shiftingLongitudeByAWholeTurnDoesNotChangeGlobality(tc)
            lat = (1:3).';
            a = geo.grid(0:359, lat, zeros(3, 360));
            b = geo.grid((0:359) + 360, lat, zeros(3, 360));
            tc.verifyEqual(b.IsGlobalLon, a.IsGlobalLon);
            tc.verifyEqual(b.LonStep, a.LonStep, 'AbsTol', 1e-12);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function validationNeverTouchesTheData(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED - V5 open.
            %
            % THE HANDOVER'S BUDGET ROW FOR THIS FUNCTION IS REFUTED, and
            % the replacement is below. §2.4.3 specifies "geo.grid at 4x
            % elements / at 1x", expected ~1.0, budget 1.5, on the grounds
            % that validation cost must not depend on numel(Z).
            %
            % The claim is right; the experiment cannot test it.
            % numel(Z) = nLon * nLat, so quadrupling Z means DOUBLING BOTH
            % AXES - and validation cost is O(nLon + nLat), because it
            % copies each axis and takes a median of its differences.
            % Doubling both axes therefore doubles the honest cost.
            % Measured: 5.82e-05 s against 3.64e-05 s, ratio 1.82, which
            % is a correct implementation reading exactly what the
            % specified comparison actually measures. Budgeting it at 1.5
            % would have demanded that an O(nLon + nLat) function behave
            % like an O(1) one.
            %
            % What the claim really says is that validation never touches
            % Z. So compare it against the cheapest possible SINGLE pass
            % over Z. If geo.grid ever starts reading the data - a
            % range check, a NaN count, an innocent double() on a
            % non-double input - this ratio moves by three orders of
            % magnitude and cannot be missed.
            %
            % InnerBatch is explicit because validation runs in about 40
            % microseconds, far below the millisecond floor at which a
            % single timing sample means anything: left to itself the
            % instrument chose a batch of 3 and returned a band of
            % 1.19 .. 5.33, noise wide enough to contain any answer.
            lat4 = (1:2161).';
            Z4 = zeros(2161, 4321);     % 74.7 MB
            tc.assertRatioBudget( ...
                @() geo.grid(1:4321, lat4, Z4), ...
                @() sum(Z4(:)), ...
                0.1, 0.006, ...
                "geo.grid / one pass over Z, 2161x4321 [PREDICTED]", ...
                InnerBatch = 20);
        end
    end
end
