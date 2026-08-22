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
                            "geo.imageGrid" ...
                            "geo.internal.mustBeIdentity" ...
                            "geo.internal.mustBeSeries" ...
                            "geo.internal.countGaps"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function aProjectedGridIsRefusedRatherThanDrawnBlank(tc)
            % Audit finding A-3. Measured on CI before this guard: a
            % NetCDF whose x and y are projected METRES was read straight
            % through, the grid came back with Lat -2e+06 .. 2e+06 with
            % no error and no warning, and geo.project then returned NaN
            % - so the failure surfaced several layers later as a blank
            % figure with no cause attached.
            %
            % The message is asserted as well as the identifier, because
            % the whole value of this guard is that it says WHY. An
            % identifier alone would turn a blank figure into a bare
            % error, which is barely an improvement.
            lon = -3e6:1e6:3e6;
            lat = (-2e6:1e6:2e6)';
            msg = "";
            try
                geo.grid(lon, lat, zeros(numel(lat), numel(lon)));
                tc.verifyFail('A projected grid must not be accepted.');
            catch ME
                tc.verifyEqual(ME.identifier, 'geo:grid:AxisNotAngular');
                msg = string(ME.message);
            end
            tc.verifySubstring(msg, "DEGREES");
            tc.verifySubstring(msg, "PROJECTED");
        end

        function aShiftedLongitudeWindowIsNotRefused(tc)
            % The control that matters most: a range check that fires on
            % VALID data is worse than none. Longitude is deliberately
            % NOT bounded to +/-180 - both windows are supported, which
            % is why geo.wrapLongitude exists and why F2 is on the defect
            % list. Three legal windows, none of which may raise.
            for lo = {-276:2:-236, 0:2:40, 340:2:380}
                lon = lo{1};
                G = geo.grid(lon, (0:2:40)', zeros(21, numel(lon)));
                tc.verifyEqual(numel(G.Lon), numel(lon), ...
                    sprintf('window %g..%g is legal', lon(1), lon(end)));
            end
        end

        function exactlyNinetyIsAccepted(tc)
            % F17 measured the GSHHG Antarctic closure landing at exactly
            % -90. A tolerance that rejects the pole re-opens a defect
            % that is already closed, so the boundary is tested at the
            % boundary rather than near it.
            G = geo.grid(-180:20:180, (-90:15:90)', zeros(13, 19));
            tc.verifyEqual(min(G.Lat), -90);
            tc.verifyEqual(max(G.Lat), 90);
        end

        function aFullTurnIsLegalAndTwoTurnsAreNot(tc)
            % The span bound is one turn plus one CELL, not one turn plus
            % one degree: a cell-registered global axis spans 360 exactly
            % and a posting one 360 minus a step (PV-140), so the
            % allowance has to scale with the axis.
            % lon -180:20:180 is POSTING (span 360); it must be paired
            % with a latitude that agrees, or geo.grid raises
            % RegistrationAmbiguous - which it did, and correctly. Second
            % time this fixture slip has been made; the error message
            % says how to settle it and the answer is to pair the axes,
            % not to silence the check.
            G = geo.grid(-180:20:180, (-90:20:90)', zeros(10, 19));
            tc.verifyEqual(diff([min(G.Lon) max(G.Lon)]), 360);
            tc.verifyError(@() geo.grid(-400:20:400, (-90:20:90)', ...
                zeros(10, 41)), 'geo:grid:AxisNotAngular');
        end

        function registrationIsInferredFromTheAxisItself(tc)
            % PV-140. GMT calls this gridline vs pixel registration,
            % MATLAB's Mapping Toolbox postings vs cells, GDAL carries it
            % in the geotransform. A POSTING is a value AT a point; a
            % CELL is a value OVER an area, and its region runs half a
            % step past the outermost node. Reading node limits as the
            % region is what lost a cell at the antimeridian.
            % Each longitude axis is paired with a latitude axis that
            % AGREES with it. Written with one shared latitude, three of
            % the four cases raised RegistrationAmbiguous - correctly,
            % and the fixture was the thing at fault.
            cases = { ...
                -180:20:180,    (-90:20:90)',    "posting", 360; ...
                -170:20:170,    (-80:20:80)',    "cell",    360; ...
                0:20:340,       (-80:20:80)',    "cell",    360; ...
                -179.5:1:179.5, (-89.5:1:89.5)', "cell",    360};
            for k = 1:size(cases, 1)
                lon = cases{k, 1};
                lat = cases{k, 2};
                G = geo.grid(lon, lat, ...
                    zeros(numel(lat), numel(lon)), Registration = "auto");
                tc.verifyEqual(G.Registration, cases{k, 3}, ...
                    sprintf('axis %g..%g step %g', lon(1), lon(end), ...
                            median(diff(lon))));
                tc.verifyEqual(diff(G.LonRegion), cases{k, 4}, ...
                    'Every global convention covers exactly one turn.', ...
                    AbsTol = 1e-9);
            end
        end

        function aRegionalGridKeepsTodaysAnswer(tc)
            % The control. A regional axis carries no evidence either
            % way, and with no evidence the answer is POSTING - what
            % every consumer assumed before this field existed - so a
            % regional grid's region is still its node range.
            G = geo.grid(0:2:40, (10:2:50)', zeros(21, 21));
            tc.verifyEqual(G.Registration, "posting");
            tc.verifyEqual(G.LonRegion, [0 40]);
            tc.verifyEqual(G.LatRegion, [10 50]);
        end

        function aGridCannotBeBothAtOnce(tc)
            % Longitude and latitude are read separately and must agree.
            % A grid that looks cell one way and posting the other is a
            % finding, not something to resolve silently in favour of
            % whichever axis was checked first.
            tc.verifyError(@() geo.grid(-170:20:170, (-90:20:90)', ...
                zeros(10, 18)), 'geo:grid:RegistrationAmbiguous');
        end

        function anExplicitRegistrationBeatsTheInference(tc)
            % The inference reads a span. A caller who knows better -
            % and a regional grid's owner always does - overrides it.
            G = geo.grid(0:2:40, (10:2:50)', zeros(21, 21), ...
                Registration = "cell");
            tc.verifyEqual(G.Registration, "cell");
            tc.verifyEqual(G.LonRegion, [-1 41]);
        end

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
            % The axes were 1:2161 and 1:4321 - INDICES standing in for
            % coordinates, which A-3 now refuses because a latitude
            % cannot be 2161. They are the real 2161x4321 global grid
            % they were always meant to represent; the shape, and
            % therefore the measurement, is unchanged.
            lat4 = linspace(-90, 90, 2161).';
            lon4 = linspace(-180, 180, 4321);
            Z4 = zeros(2161, 4321);     % 74.7 MB
            tc.assertRatioBudget( ...
                @() geo.grid(lon4, lat4, Z4), ...
                @() sum(Z4(:)), ...
                0.1, 0.006, ...
                "geo.grid / one pass over Z, 2161x4321 [PREDICTED]", ...
                InnerBatch = 20);
        end
    end
    % ==================================================================
    %  geo.imageGrid  (G.1)
    % ==================================================================
    methods (Access = private)
        function [lon, lat, RGB] = imgFixture(~, nLon, nLat)
            %IMGFIXTURE  A cell-registered world raster with a known ramp.
            %   The ramp is the point: every pixel's value is a function
            %   of its own indices, so a flip, a transpose or an off-by-one
            %   is visible in the VALUES and not only in the size.
            arguments
                ~
                nLon (1,1) double = 8
                nLat (1,1) double = 4
            end
            step = 360 / nLon;
            lon = -180 + step/2 + (0:nLon-1) * step;
            lat = -90 + (180/nLat)/2 + (0:nLat-1) * (180/nLat);
            [I, J] = ndgrid(1:nLat, 1:nLon);
            RGB = uint8(cat(3, I * 10, J * 10, I + J));
        end
    end

    methods (Test, TestTags = {'contract'})

        function imageGridRejectsEveryDocumentedWay(tc)
            [lon, lat, RGB] = tc.imgFixture();
            tc.verifyError(@() geo.imageGrid(lon, lat, RGB(:, 1:end-1, :)), ...
                'geo:imageGrid:SizeMismatch');
            tc.verifyError(@() geo.imageGrid(lon, lat, RGB(:, :, 1:2)), ...
                'geo:imageGrid:SizeMismatch');
            bad = lon; bad(3) = bad(2);
            tc.verifyError(@() geo.imageGrid(bad, lat, RGB), ...
                'geo:imageGrid:NonMonotonic');
            uneven = lon; uneven(3) = uneven(3) + 5;
            tc.verifyError(@() geo.imageGrid(uneven, lat, RGB), ...
                'geo:imageGrid:UnevenStep');
            tc.verifyError(@() geo.imageGrid(lon, lat, RGB, ...
                Alpha = ones(2, 2)), 'geo:imageGrid:AlphaMismatch');
            tc.verifyError(@() geo.imageGrid(lon, lat, double(RGB)), ...
                'geo:imageGrid:BadRange');
        end

        function itCarriesItsOwnProvenance(tc)
            % R2. A raster that has lost track of where it came from is
            % indistinguishable from one that never had a source.
            [lon, lat, RGB] = tc.imgFixture();
            IG = geo.imageGrid(lon, lat, RGB, Source = "NASA BMNG 2004-08");
            tc.verifyEqual(IG.Identity, "geo.imageGrid");
            tc.verifyEqual(IG.Source, "NASA BMNG 2004-08");
            tc.verifyEqual(IG.Registration, "cell");
            tc.verifyClass(IG.RGB, 'uint8');
        end
    end

    methods (Test, TestTags = {'reference'})

        function aWorldRasterKnowsItIsGlobal(tc)
            % Oracle: the arithmetic of a cell-registered world grid,
            % which geo.grid already asserts for scalar fields. The two
            % kinds must agree, or a field and its backdrop disagree
            % about the seam.
            [lon, lat, RGB] = tc.imgFixture(8, 4);
            IG = geo.imageGrid(lon, lat, RGB);
            tc.verifyTrue(IG.IsGlobalLon);
            G = geo.grid(lon, lat, double(RGB(:, :, 1)));
            tc.verifyEqual(IG.IsGlobalLon, G.IsGlobalLon, ...
                "an image and a field on the SAME axes must agree");
            tc.verifyAndRecord(abs(IG.LonStep - G.LonStep), 1e-12, ...
                "imageGrid vs grid step on identical axes", "deg");
        end

        function aRegionalRasterKnowsItIsNot(tc)
            lon = 10:0.5:20;
            lat = 40:0.5:50;
            RGB = zeros(numel(lat), numel(lon), 3, 'uint8');
            tc.verifyFalse(geo.imageGrid(lon, lat, RGB).IsGlobalLon);
        end
    end

    methods (Test, TestTags = {'precision'})

        function doubleToUint8IsTheDocumentedRounding(tc)
            % The help says 0..1 becomes uint8 ONCE, here. That is a
            % numerical claim and it gets a number: exact agreement with
            % round(x*255), not "close enough".
            [lon, lat, ~] = tc.imgFixture();
            d = rand(numel(lat), numel(lon), 3);
            d(1) = 0; d(2) = 1;
            IG = geo.imageGrid(lon, lat, d);
            tc.verifyAndRecord(max(abs(double(IG.RGB(:)) - round(d(:) * 255))), ...
                0, "imageGrid double->uint8 vs round(x*255)", "levels");
        end
    end

    methods (Test, TestTags = {'metamorphic'})

        function aFlippedRasterComesBackTheSameWayUp(tc)
            % The claim that pays for the Flipped field: feeding the
            % north-to-south form of a raster must give BITWISE the same
            % struct as the south-to-north form, apart from the flag.
            [lon, lat, RGB] = tc.imgFixture();
            up = geo.imageGrid(lon, lat, RGB);
            down = geo.imageGrid(lon, fliplr(lat), flipud(RGB));
            tc.verifyEqual(down.RGB, up.RGB, "bitwise: this is a permutation");
            tc.verifyEqual(down.Lat, up.Lat);
            tc.verifyFalse(up.Flipped);
            tc.verifyTrue(down.Flipped);
        end

        function alphaFollowsItsPixels(tc)
            % A flip that moved the raster and left the mask behind would
            % put the transparency on the wrong hemisphere - and every
            % individual value would still look plausible, which is the
            % class of defect metamorphic tests exist for.
            [lon, lat, RGB] = tc.imgFixture();
            A = reshape(1:numel(lat) * numel(lon), numel(lat), numel(lon)) ...
                / (numel(lat) * numel(lon));
            down = geo.imageGrid(lon, fliplr(lat), flipud(RGB), ...
                Alpha = flipud(A));
            tc.verifyEqual(down.Alpha, A, "bitwise");
        end
    end

    methods (Test, TestTags = {'vectorisation'})

        function everyPixelSurvivesTheTrip(tc)
            % An image constructor has no batched form, so the property
            % standing in for it is that the whole raster is carried
            % element for element: a 1-pixel call and the full call must
            % agree at every pixel.
            [lon, lat, RGB] = tc.imgFixture(16, 8);
            IG = geo.imageGrid(lon, lat, RGB);
            for k = [1 17 63 numel(lat) * numel(lon)]
                [i, j] = ind2sub([numel(lat) numel(lon)], k);
                one = geo.imageGrid(lon(j), lat(i), RGB(i, j, :));
                tc.verifyEqual(squeeze(IG.RGB(i, j, :)), ...
                    squeeze(one.RGB(1, 1, :)), "bitwise");
            end
        end
    end

    methods (Test, TestTags = {'robustness'})

        function aSinglePixelRasterIsNotAnError(tc)
            % One pixel has no step to measure. It is a legitimate input -
            % the degenerate case of a region - and must not be rejected
            % by machinery that assumed at least two.
            IG = geo.imageGrid(0, 0, zeros(1, 1, 3, 'uint8'));
            tc.verifyEqual(size(IG.RGB), [1 1 3]);
            tc.verifyFalse(IG.IsGlobalLon);
        end

        function aPostedWorldRasterIsGlobalToo(tc)
            % The other registration, and it closes the globe by a
            % different arithmetic: posted spans a full 360 with a
            % repeated seam column, cell spans 360 minus one step. Getting
            % one right and the other wrong shifts a backdrop by half a
            % cell against the field on top of it.
            lon = -180:45:180;
            lat = -90:45:90;
            RGB = zeros(numel(lat), numel(lon), 3, 'uint8');
            tc.verifyTrue(geo.imageGrid(lon, lat, RGB, ...
                Registration = "posting").IsGlobalLon);
            tc.verifyFalse(geo.imageGrid(lon, lat, RGB, ...
                Registration = "cell").IsGlobalLon);
        end
    end

    methods (Test, TestTags = {'speed'})

        function wrappingARasterCostsLessThanCopyingIt(tc)
            % The budget that matters: this function must not be doing
            % real work. A ratio against ONE pass over the same bytes,
            % both timed on the same arrays, per VALIDATION_GUIDE Part 4.
            tc.assumeSpeedTestsEnabled();
            [lon, lat, RGB] = tc.imgFixture(1024, 512);
            tc.assertRatioBudget( ...
                @() geo.imageGrid(lon, lat, RGB), ...
                @() sum(RGB(:)), ...
                6, 2, "geo.imageGrid / one pass over the raster, 1024x512");
        end
    end


end
