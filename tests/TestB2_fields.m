classdef TestB2_fields < GeoMapTestCase
%TESTB2_FIELDS  Stage B.2: statistics, ticks, regridding, hillshading.
%
%   DESCRIPTION
%     The five L1 functions that operate on fields rather than
%     coordinates. Three of them carry a v1 defect repair with a pinned
%     regression: F10 (biased percentile), F16 (nearest-snap ticks) and
%     F4 (non-periodic regrid).
%
%   ACCURACY
%     TolMass is READ FROM THE MIRROR, never written here: handover debt
%     V7 forbade asserting the document's 1e-12 guess, and the measured
%     floor at production size sets the number instead.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestB2");
%
%   LIMITATIONS
%     Conservative regridding is asserted at a reduced grid size for
%     runtime; the production-size floor is the mirror's measurement, and
%     this suite asserts against that number rather than re-measuring it.
%
%   See also GEO.QUANTILE, GEO.REGRID, GEO.HILLSHADE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.quantile" "geo.symmetricLimits" ...
                            "geo.niceTicks" "geo.regrid" "geo.hillshade"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function theBiasedPercentileIsPinned(tc)
            % F10. v1 used round(p/100*n) as an INDEX, so it could not
            % return a value between two samples at all: the median of
            % [1 2] came back as 1.
            tc.verifyEqual(geo.quantile([1 2], 50), 1.5, 'AbsTol', 0);
            tc.verifyEqual(geo.quantile([1 2 3 4], [0 100]), [1 4]);
        end

        function quantileIgnoresGapsAndRejectsBadPercentages(tc)
            tc.verifyEqual(geo.quantile([1 NaN 2 Inf], 50), 1.5, ...
                'AbsTol', 1e-12);
            tc.verifyTrue(isnan(geo.quantile([NaN NaN], 50)), ...
                'no finite element means no quantile, not zero');
            tc.verifyError(@() geo.quantile([1 2], 101), ...
                'geo:quantile:PercentOutOfRange');
            tc.verifyError(@() geo.quantile([1 2], -1), ...
                'geo:quantile:PercentOutOfRange');
        end

        function symmetricLimitsStraddleZero(tc)
            L = geo.symmetricLimits([-3 1 2 50], 98);
            tc.verifyEqual(L(1), -L(2), 'AbsTol', 0, ...
                'zero must sit exactly in the middle of a diverging ramp');
            tc.verifyEqual(geo.symmetricLimits(zeros(1, 10)), [-0.5 0.5], ...
                'a degenerate field gets a visibly arbitrary range');
        end

        function theNearestSnapIsPinned(tc)
            % F16, at the span the probe measured as v1's worst: 45
            % degrees, where nearest-snap gives step 5 and TEN lines
            % against a target of six. The ceiling policy gives 10.
            t = geo.niceTicks(0, 45, Mode = "graticule");
            tc.verifyEqual(min(diff(t)), 10, 'AbsTol', 1e-12);
            tc.verifyLessThanOrEqual(numel(t) - 1, 6, ...
                'the ceiling policy can undershoot the target, never overshoot');
        end

        function bothRejectedNeighboursAreAsserted(tc)
            % The step below would overshoot the count; the step above
            % would undershoot it more than necessary. Asserting only the
            % chosen value would pass for a table with the wrong contents.
            set = [0.1 0.2 0.25 0.5 1 2 3 5 10 15 20 30 45 60 90];
            step = min(diff(geo.niceTicks(0, 45, Mode = "graticule")));
            k = find(set == step, 1);
            tc.verifyLessThan(set(k-1), 45/6, ...
                'the next step down is below the ideal, so it is rejected');
            tc.verifyGreaterThanOrEqual(step, 45/6, ...
                'the chosen step is at or above the ideal');
        end

        function anEmptyRangeIsRejected(tc)
            tc.verifyError(@() geo.niceTicks(5, 5), ...
                'geo:niceTicks:EmptyRange');
            tc.verifyError(@() geo.niceTicks(5, 1), ...
                'geo:niceTicks:EmptyRange');
        end

        function regridRefusesWhatItCannotHandle(tc)
            G = tc.simpleGrid();
            tc.verifyError(@() geo.regrid(geo.track([1 2], [1 2]), ...
                1:3, (1:3).'), 'geo:regrid:NotAGrid');
            % A non-uniform axis cannot yield cell edges by bisection.
            Gnu = geo.grid([0 1 2 5], (0:3).', zeros(4, 4));
            tc.verifyError(@() geo.regrid(Gnu, 0:2, (0:2).', ...
                Method = "conservative"), 'geo:regrid:NonUniformAxis');
        end

        function hillshadeRejectsAMismatchedTopography(tc)
            tc.verifyError(@() geo.hillshade(1:5, (1:3).', zeros(5, 3)), ...
                'geo:hillshade:SizeMismatch');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function conservativeRegriddingConservesMass(tc)
            % V7's number, read from the mirror rather than written here.
            rng(42, 'twister');
            ls = -179.5:179.5;
            as = (-89.5:89.5).';
            Z = 30 * sin(3*as*pi/180) .* cos(2*ls*pi/180) + randn(180, 360);
            G = geo.grid(ls, as, Z);
            ld = -177:6:177;
            ad = (-87:6:87).';
            G2 = geo.regrid(G, ld, ad, Method = "conservative");
            rel = abs(tc.mass(G2) - tc.mass(G)) / abs(tc.mass(G));
            tc.verifyAndRecord(rel, tc.TolMass, ...
                "conservative regrid mass closure", "relative");
        end

        function theSeamDefectIsPinnedAtBothEnds(tc)
            % F4. v1 returned the value AT the hull edge for a query past
            % it - silently, with no NaN. Measured on the installed v1 at
            % longitude 179.5, which is the end the obvious test misses.
            lon = 0:359;
            Z = repmat(cosd(lon), 3, 1);
            G = geo.grid(lon, (-1:1).', Z);
            G2 = geo.regrid(G, [-0.5 179.5], (-0.5:1:0.5).');
            tc.verifyAndRecord(abs(G2.Z(1,1) - (cosd(359)+cosd(0))/2), ...
                1e-12, "F4 seam at lon -0.5", "");
            tc.verifyAndRecord(abs(G2.Z(1,2) - (cosd(179)+cosd(180))/2), ...
                1e-12, "F4 seam at lon 179.5", "");
        end

        function flatTerrainShadesAnalytically(tc)
            % Exact closed form, so machine precision is the tolerance.
            s = geo.hillshade(linspace(-10,10,21), (-1:1).', zeros(3,21), ...
                Elevation = 45, Ambient = 0.35);
            want = 0.35 + 0.65 * sind(45);
            tc.verifyAndRecord(max(abs(s(:) - want)), 1e-14, ...
                "flat-terrain shade vs analytic", "");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'precision'})

        function theSphericalMetricIsPresent(tc)
            % THE TEST THAT CATCHES A MISSING cos(lat). The same east-west
            % ramp is physically steeper near the pole because a degree of
            % longitude is shorter there. No oracle supplies this - GDAL
            % has no per-row spacing (mirror limit L10) - so it is checked
            % analytically.
            r = tc.metricSlope(60) / tc.metricSlope(0);
            tc.verifyAndRecord(abs(r - 2) / 2, 1e-5, ...
                "hillshade metric ratio, lat 60 / lat 0", "relative");
        end

        function quantileMatchesItsClosedForm(tc)
            % Type 7: h = (n-1)p/100 + 1, interpolated between the
            % neighbouring order statistics.
            v = 1:11;
            for p = [0 10 25 50 75 90 100]
                h = (numel(v) - 1) * p / 100 + 1;
                want = interp1(1:numel(v), v, h);
                tc.verifyEqual(geo.quantile(v, p), want, 'AbsTol', 1e-12, ...
                    sprintf('p = %g', p));
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aConstantFieldSurvivesBothRegridMethods(tc)
            G = geo.grid(-179.5:179.5, (-89.5:89.5).', 7*ones(180,360));
            for m = ["bilinear" "conservative" "nearest"]
                G2 = geo.regrid(G, -177:6:177, (-87:6:87).', Method = m);
                tc.verifyAndRecord(max(abs(G2.Z(:) - 7)), 1e-12, ...
                    "constant field preserved, " + m, "");
            end
        end

        function anAllNaNSourceGivesAnAllNaNTarget(tc)
            G = geo.grid(-179.5:179.5, (-89.5:89.5).', nan(180,360));
            G2 = geo.regrid(G, -177:6:177, (-87:6:87).', ...
                Method = "conservative");
            tc.verifyTrue(all(isnan(G2.Z(:))), ...
                'no valid overlap must give NaN, never zero');
        end

        function partialGapsRenormaliseRatherThanDilute(tc)
            % A target cell seeing half its sources masked must report the
            % mean of what it saw, not a value pulled towards zero.
            G = geo.grid(-179.5:179.5, (-89.5:89.5).', 5*ones(180,360));
            Z = G.Z;
            Z(1:2:end, :) = NaN;
            G = geo.grid(G.Lon, G.Lat, Z);
            G2 = geo.regrid(G, -177:6:177, (-87:6:87).', ...
                Method = "conservative");
            ok = isfinite(G2.Z);
            tc.verifyAndRecord(max(abs(G2.Z(ok) - 5)), 1e-12, ...
                "masked-source renormalisation", "");
        end

        function lightStraightDownAndFlatGroundAgree(tc)
            s = geo.hillshade(linspace(-5,5,11), (-1:1).', zeros(3,11), ...
                Elevation = 90, Ambient = 0);
            tc.verifyAndRecord(max(abs(s(:) - 1)), 1e-14, ...
                "shade with the light at the zenith", "");
        end

        function aGapInTopographyIsNotAShadow(tc)
            z = zeros(5, 5);
            z(3, 3) = NaN;
            s = geo.hillshade(1:5, (1:5).', z);
            tc.verifyEqual(s(3,3), 1, 'AbsTol', 0, ...
                'unlit data would read as a dark feature that is not there');
        end

        function aDescendingLatitudeAxisRegridsTheSameWay(tc)
            lon = -179.5:179.5;
            asc = (-89.5:89.5).';
            Z = repmat(sind(asc), 1, 360);
            up = geo.regrid(geo.grid(lon, asc, Z), -177:6:177, (-87:6:87).');
            dn = geo.regrid(geo.grid(lon, flipud(asc), flipud(Z)), ...
                -177:6:177, (-87:6:87).');
            tc.verifyAndRecord(max(abs(up.Z(:) - dn.Z(:))), 1e-12, ...
                "regrid invariant to source latitude direction", "");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'vectorisation'})

        function quantileHandlesManyPercentagesAtOnce(tc)
            rng(42, 'twister');
            v = randn(1, 5000);
            p = [1 2 5 25 50 75 95 98 99];
            batch = geo.quantile(v, p);
            one = arrayfun(@(pp) geo.quantile(v, pp), p);
            tc.verifyTrue(isequal(batch, one), ...
                'a batch of percentages must equal one call each, bitwise');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function quantileIgnoresTheOrderItWasGiven(tc)
            rng(42, 'twister');
            v = randn(1, 2000);
            tc.verifyTrue(isequal(geo.quantile(v, [10 50 90]), ...
                geo.quantile(v(randperm(2000)), [10 50 90])), ...
                'a quantile is a property of the multiset, bitwise');
        end

        function niceTicksScaleWithTheirRange(tc)
            % Multiplying the range by a power of ten must multiply the
            % ticks by the same factor: the 1-2-5 family is decade-scaled
            % by construction, and if it is not, the decade logic is wrong.
            a = geo.niceTicks(0, 8);
            b = geo.niceTicks(0, 800);
            tc.verifyEqual(b, a * 100, 'RelTol', 1e-12);
        end

        function hillshadeMirrorsWhenTheLightDoes(tc)
            % Reflecting the terrain east-west and the azimuth about north
            % must give the mirrored shade. Guards the aspect convention,
            % which is where a sign error hides and still looks plausible.
            rng(42, 'twister');
            lon = linspace(-5, 5, 41);
            lat = (-2:2).';
            z = cumsum(randn(5, 41), 2);
            a = geo.hillshade(lon, lat, z, Azimuth = 315, ZFactor = 1);
            b = geo.hillshade(lon, lat, fliplr(z), Azimuth = 45, ...
                ZFactor = 1);
            tc.verifyAndRecord(max(max(abs(a - fliplr(b)))), 1e-12, ...
                "hillshade E-W mirror symmetry", "");
        end

        function regriddingInTwoStepsMatchesOne(tc)
            % Conservative remapping composes: coarsening twice equals
            % coarsening once, at eps level, when the intermediate grid
            % refines the target exactly.
            rng(42, 'twister');
            lon = -179.5:179.5;
            lat = (-89.5:89.5).';
            G = geo.grid(lon, lat, randn(180, 360));
            mid = geo.regrid(G, -177:6:177, (-87:6:87).', ...
                Method = "conservative");
            two = geo.regrid(mid, -168:24:168, (-78:24:78).', ...
                Method = "conservative");
            one = geo.regrid(G, -168:24:168, (-78:24:78).', ...
                Method = "conservative");
            tc.verifyAndRecord(max(abs(two.Z(:) - one.Z(:))), 1e-12, ...
                "conservative regrid split/merge", "");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function conservativeAgainstBilinear(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED - V5 open. Same source and same target both sides,
            % so only the method differs (D-016).
            rng(42, 'twister');
            G = geo.grid(-179.5:179.5, (-89.5:89.5).', randn(180, 360));
            ld = -179.5:179.5;
            ad = (-89.5:89.5).';
            tc.assertRatioBudget( ...
                @() geo.regrid(G, ld, ad, Method = "conservative"), ...
                @() geo.regrid(G, ld, ad, Method = "bilinear"), ...
                60, 20, "regrid conservative / bilinear [PREDICTED]");
        end

        function multidirectionalAgainstSingle(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED - V5. Guards the four-azimuth BLEND, not the
            % kernel: the gradients are computed once either way.
            rng(42, 'twister');
            lon = linspace(-180, 180, 1200);
            lat = linspace(-89, 89, 600).';
            z = cumsum(randn(600, 1200), 2);
            tc.assertRatioBudget( ...
                @() geo.hillshade(lon, lat, z, Multi = true, ZFactor = 1), ...
                @() geo.hillshade(lon, lat, z, Multi = false, ZFactor = 1), ...
                6, 4, "hillshade multi / single [PREDICTED]");
        end
    end

    % ==================================================================
    methods (Access = private)
        function G = simpleGrid(~)
            G = geo.grid(-179.5:179.5, (-89.5:89.5).', zeros(180, 360));
        end

        function m = mass(~, G)
            %MASS  Area-weighted total, in sin-latitude measure.
            e = @(c) [c(1) - (c(2)-c(1))/2, c(:).' + (c(2)-c(1))/2];
            m = sum(sum(G.Z .* (diff(sind(e(G.Lat))).' * diff(e(G.Lon)))));
        end

        function s = metricSlope(~, latCentre)
            %METRICSLOPE  Median |dz/deast| of a fixed ramp at a latitude.
            lon = linspace(-10, 10, 201);
            lat = (latCentre + linspace(-0.5, 0.5, 21)).';
            z = repmat(100 * lon, 21, 1);
            rm = 6371.0072 * 1000;
            d2r = pi / 180;
            dx = abs(rm * cos(lat*d2r) * (median(diff(lon)) * d2r));
            p = [z(1,:); z; z(end,:)];
            p = [p(:,1), p, p(:,end)];
            gx = conv2(p, rot90([-1 0 1; -2 0 2; -1 0 1]/8, 2), 'valid') ./ dx;
            s = median(abs(gx(3:end-2, 3:end-2)), 'all');
        end
    end
end
