classdef TestB1_projection < GeoMapTestCase
%TESTB1_PROJECTION  Stage B.1: the sixteen projections, forward and back.
%
%   DESCRIPTION
%     The stage the toolbox's credibility rests on, and the one where the
%     oracle register does most of its work. Every reference value comes
%     from the mirror, which measured it against pyproj/PROJ (O4), Snyder
%     (O1) or an analytic invariant (O3) - never from the handover, four
%     of whose numbers in this area were refuted before any MATLAB
%     existed.
%
%   ACCURACY
%     Tolerances are per-projection where the projection earns one. The
%     single exception is Lambert azimuthal equal-area at 1e-8 rather than
%     1e-9: asin conditioning at the antipodal rim is inherent to the
%     projection and was measured, not assumed (PV-010).
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestB1");
%
%   LIMITATIONS
%     Nothing here draws. Whether a projected grid renders correctly is
%     Stage D's question, against geometry computed here.
%
%   See also GEO.PROJECT, GEO.UNPROJECT, GEO.SCALEFACTORS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.project" "geo.unproject" ...
                            "geo.scaleFactors" "geo.internal.robinson" ...
                            "geo.internal.mollweideTheta" ...
                            "geo.internal.pairCoordinates"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function aRowAndAColumnAutoMeshgrid(tc)
            c = geo.crs("mollweide");
            [x, y] = geo.project(-180:10:180, (-90:10:90).', c);
            tc.verifyEqual(size(x), [19 37], ...
                'lat first, matching geo.grid''s canonical Z orientation');
            tc.verifyEqual(size(y), size(x));
        end

        function theReversePairingIsRejectedNotGuessed(tc)
            c = geo.crs("mollweide");
            tc.verifyError(@() geo.project((-180:10:180).', -90:10:90, c), ...
                'geo:project:SizeMismatch');
            tc.verifyError(@() geo.unproject([1 2 3], [1 2], c), ...
                'geo:unproject:SizeMismatch');
            tc.verifyError(@() geo.scaleFactors([1 2 3], [1 2], c), ...
                'geo:scaleFactors:SizeMismatch');
        end

        function everyProjectionReturnsNaNOutsideItsDomain(tc)
            % F12: the clip is the DECLARED domain's, for all sixteen.
            for p = geo.internal.projectionNames()
                c = tc.crsFor(p);
                D = c.Domain;
                if ~isnan(D.MaxAngularDistanceDeg) && ...
                        D.MaxAngularDistanceFrom == "centre"
                    % A point just beyond the clip, along the meridian.
                    %
                    % NOT clip + 1. Angular distance saturates at 180,
                    % so "one degree beyond" is only reachable while the
                    % clip is at least a degree short of the antipode.
                    % Lambert's is half a degree short (PV-141), and
                    % clip + 1 came back round the far side to 179.5 -
                    % exactly AT the clip, which is not beyond it, so
                    % the projection rightly returned a number and the
                    % test rightly failed. Halfway to the antipode is
                    % beyond the clip for every value it can take, and
                    % leaves the other fifteen probes unchanged.
                    beyond = min(D.MaxAngularDistanceDeg + 1, ...
                        (D.MaxAngularDistanceDeg + 180) / 2);
                    far = c.CenterLatitude + beyond;
                    if far <= 90
                        [x, ~] = geo.project(c.CenterLongitude, far, c);
                    else
                        [x, ~] = geo.project(c.CenterLongitude + 180, ...
                            180 - far, c);
                    end
                    tc.verifyTrue(isnan(x), sprintf( ...
                        '%s must be NaN beyond its declared clip', p));
                end
                if ~isinf(D.LatLimit(2)) && D.LatLimit(2) < 90
                    [~, y] = geo.project(0, D.LatLimit(2) + 1, c);
                    tc.verifyTrue(isnan(y), sprintf( ...
                        '%s must be NaN beyond its latitude limit', p));
                end
            end
        end

        function nanPropagatesAsAGap(tc)
            for p = ["mollweide" "robinson" "lambert" "albers"]
                c = tc.crsFor(p);
                [x, y] = geo.project([10 NaN 30], [10 20 NaN], c);
                tc.verifyTrue(isnan(x(2)) && isnan(y(2)), ...
                    sprintf('%s: NaN longitude', p));
                tc.verifyTrue(isnan(x(3)) && isnan(y(3)), ...
                    sprintf('%s: NaN latitude', p));
            end
        end

        function theRobinsonWrapDefectIsPinned(tc)
            % F2. v1 returned x = +5.29 here, roughly two map widths out,
            % because it passed a raw LON - lon0 to the table.
            x = geo.project(359, 10, geo.crs("robinson"));
            tc.verifyLessThan(x, 0, 'longitude 359 is one degree WEST');
            tc.verifyAndRecord(abs(x), 0.02, ...
                "F2 pinned: |x| at lon 359, robinson", "Earth radii");
        end

        function theMercatorClampDefectIsPinned(tc)
            % F3. v1 clamped to +/-85, so y(87) and y(85) were bit-
            % identical and data 222 km apart drew on the same parallel.
            c = geo.crs("mercator");
            [~, y87] = geo.project(0, 87, c);
            [~, y85] = geo.project(0, 85, c);
            tc.verifyTrue(isnan(y87), 'outside the domain is NaN, not clamped');
            tc.verifyFalse(isnan(y85), 'the limit itself is inside');
        end

        function pointsOutsideTheImageInvertToNaN(tc)
            [lo, la] = geo.unproject(5, 5, geo.crs("mollweide"));
            tc.verifyTrue(isnan(lo) && isnan(la), ...
                'no point of the sphere lies outside the Mollweide ellipse');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function publishedPointValuesReproduce(tc)
            % Oracle O1, Snyder 1987, via the mirror.
            ref = tc.loadMirrorReference("mercator_y_at_lat35");
            [~, y] = geo.project(0, 35, geo.crs("mercator"));
            tc.verifyAndRecord(abs(y - ref.measured), 1e-12, ...
                "Mercator y(35) vs mirror", "");

            cx = tc.loadMirrorReference("lcc_x_at_35N_75W");
            cy = tc.loadMirrorReference("lcc_y_at_35N_75W");
            [x, y] = geo.project(-75, 35, tc.crsLcc3345);
            tc.verifyAndRecord(max(abs(x - cx.measured), ...
                abs(y - cy.measured)), 1e-12, ...
                "LCC Snyder p.296 point vs mirror", "");
        end

        function thePolarStereographicValueTheHandoverGotWrong(tc)
            % PV-002: the handover said 0.6116372, which matches no
            % evaluation of any formula in either model. The measured
            % value is 0.3430474163 and PROJ confirms it to 1e-10.
            ref = tc.loadMirrorReference("polarstereo_rho_lat70_sp71");
            [x, y] = geo.project(0, 70, tc.crsPolarNorth);
            tc.verifyAndRecord(abs(hypot(x, y) - ref.measured), 1e-12, ...
                "polar stereographic rho(70), SP 71, vs mirror", "");
        end

        function robinsonReproducesItsOwnTableNodes(tc)
            % Robinson IS its table, so the nodes are the reference and
            % PROJ is not: PROJ interpolates the same table differently
            % and agrees only to 8.9e-4 (mirror limit L5).
            T = geo.internal.robinson("table");
            worst = 0;
            for i = 1:size(T, 1)
                worst = max([worst, ...
                    abs(geo.internal.robinson("x", T(i,1)) - T(i,2)), ...
                    abs(geo.internal.robinson("y", T(i,1)) - T(i,3))]);
            end
            tc.verifyAndRecord(worst, 1e-12, ...
                "Robinson PCHIP reproduces its own nodes", "");
        end

        function hammerReachesItsAnalyticLimit(tc)
            % x -> 2*sqrt(2) as lon -> 180 at the equator.
            x = geo.project(179.999, 0, geo.crs("hammer"));
            tc.verifyAndRecord(abs(x - 2*sqrt(2)), 1e-4, ...
                "Hammer x limit at the equator", "");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'precision'})

        function everyProjectionRoundTrips(tc)
            % The suite that exists only because v2 has an inverse at all
            % (F5). 10 000 quasi-random in-domain points per projection.
            rng(42, 'twister');
            for p = geo.internal.projectionNames()
                c = tc.crsFor(p);
                [lon, lat] = tc.samplesFor(p);
                [x, y] = geo.project(lon, lat, c);
                [lo, la] = geo.unproject(x, y, c);
                ok = isfinite(x) & isfinite(y) & isfinite(lo);
                tc.verifyGreaterThan(sum(ok), 1000, sprintf( ...
                    '%s: too few in-domain samples to mean anything', p));
                err = max(max(abs(geo.wrapLongitude(lo(ok) - lon(ok), 0))), ...
                          max(abs(la(ok) - lat(ok))));
                tc.verifyAndRecord(err, tc.roundTripTol(p), ...
                    "round trip, " + p, "deg");
            end
        end

        function mercatorScaleIsSecantOfLatitude(tc)
            % Oracle O3, closed form.
            lat = [0 30 60].';
            s = geo.scaleFactors(zeros(3,1), lat, geo.crs("mercator"));
            tc.verifyAndRecord(max(abs(s.k - secd(lat))), 1e-6, ...
                "Mercator k vs sec(lat)", "");
        end

        function equalAreaProjectionsHaveUnitAreaScale(tc)
            lon = [-120 -30 0 45 100].';
            lat = [-60 -20 0 25 55].';
            worst = 0;
            for p = ["mollweide" "hammer" "sinusoidal" "lambert" "albers"]
                s = geo.scaleFactors(lon, lat, tc.crsFor(p));
                worst = max(worst, max(abs(s.AreaScale - 1)));
            end
            tc.verifyAndRecord(worst, 1e-6, ...
                "equal-area AreaScale vs 1, worst of five", "");
        end

        function conformalProjectionsHaveEqualScaleFactors(tc)
            lon = [-120 -30 0 45 100].';
            lat = [-60 -20 0 25 55].';
            worst = 0;
            for p = ["mercator" "stereographic" "lambertconformal"]
                s = geo.scaleFactors(lon, lat, tc.crsFor(p));
                worst = max(worst, max(abs(s.h - s.k)));
            end
            tc.verifyAndRecord(worst, 1e-6, ...
                "conformal |h - k|, worst of three", "");
        end

        function theConicIsTrueOnBothStandardParallels(tc)
            s = geo.scaleFactors([-96; -96], [33; 45], tc.crsLcc3345);
            tc.verifyAndRecord(max(abs(s.k - 1)), 1e-6, ...
                "LCC k on both standard parallels", "");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function degeneraciesConstructedFromTheAlgebra(tc)
            % Not "near" the singularity: exactly on it, derived rather
            % than approached.
            % Gnomonic at exactly 90 degrees: cosc is identically zero.
            g = geo.crs("gnomonic", CenterLatitude = 0);
            x = geo.project(90, 0, g);
            tc.verifyTrue(isnan(x), 'gnomonic at cosc = 0 exactly');
            % Azimuthal equidistant at the exact antipode.
            a = geo.crs("azimuthalequidistant", CenterLatitude = 40);
            xa = geo.project(180, -40, a);
            tc.verifyTrue(isnan(xa), 'the antipode is a whole circle');
            % Mollweide exactly at the poles: theta is assigned, not solved.
            [xm, ym] = geo.project([0 0], [-90 90], geo.crs("mollweide"));
            tc.verifyTrue(all(isfinite(ym)), 'the poles are on the map');
            tc.verifyEqual(abs(ym), [sqrt(2) sqrt(2)], 'AbsTol', 1e-12);
            tc.verifyEqual(xm, [0 0], 'AbsTol', 1e-12);
        end

        function scaleFactorsReturnNaNOnADomainBoundary(tc)
            % Mirror limit L7, asserted rather than discovered later by
            % geo.scalebar. A central difference at the edge steps
            % outside, geo.project returns NaN there, and NaN propagates.
            % MORE PRECISELY THAN THE MIRROR RECORDED IT: the MERIDIAN
            % scale h is NaN, because its central difference steps in
            % latitude and lands outside the limit. The PARALLEL scale k
            % steps in longitude, stays inside, and is finite. So the
            % boundary yields a HALF-DEFINED result rather than a wholly
            % NaN one, which is worse for a caller that checks only one
            % of them - and is why geo.scalebar must sample strictly
            % inside its extent rather than merely test for NaN.
            s = geo.scaleFactors(0, 85, geo.crs("mercator"));
            tc.verifyTrue(isnan(s.h), ...
                'the meridian difference steps outside the domain');
            tc.verifyTrue(isnan(s.AreaScale) && isnan(s.OmegaDeg), ...
                'anything built from h inherits the NaN');
            tc.verifyTrue(isfinite(s.k), ...
                ['and k does NOT - the boundary is half-defined, which ' ...
                 'is the trap: a caller testing only k sees nothing wrong']);
            sIn = geo.scaleFactors(0, 84.9, geo.crs("mercator"));
            tc.verifyTrue(isfinite(sIn.h) && isfinite(sIn.k), ...
                'and just inside, both are finite');
        end

        function winkelTripelNaNsWhatItCannotInvert(tc)
            % PV-010. Without the residual check the mirror returned
            % errors up to 174 degrees that looked like successes, on
            % about 0.8% of a uniform sample near the antimeridian.
            rng(42, 'twister');
            c = geo.crs("winkeltripel");
            lon = rand(1, 10000) * 358 - 179;
            lat = rand(1, 10000) * 178 - 89;
            [x, y] = geo.project(lon, lat, c);
            [lo, ~] = geo.unproject(x, y, c);
            frac = mean(isnan(lo));
            tc.verifyLessThan(frac, 0.05, ...
                'the divergence band is narrow, not the whole map');
            ok = isfinite(lo);
            err = max(abs(geo.wrapLongitude(lo(ok) - lon(ok), 0)));
            tc.verifyAndRecord(err, 1e-9, ...
                "Winkel Tripel: error among points it CLAIMS to invert", ...
                "deg");
        end

        function anEmptyInputSurvives(tc)
            [x, y] = geo.project([], [], geo.crs("mollweide"));
            tc.verifyEmpty(x);
            tc.verifyEmpty(y);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'vectorisation'})

        function batchedProjectionIsBitIdenticalToScalarCalls(tc)
            % Elementwise arithmetic, so bit-identity is the right claim.
            rng(42, 'twister');
            lon = rand(1, 500) * 358 - 179;
            lat = rand(1, 500) * 178 - 89;
            for p = ["mollweide" "robinson" "lambertconformal"]
                c = tc.crsFor(p);
                [bx, by] = geo.project(lon, lat, c);
                sx = zeros(1, 500);
                sy = zeros(1, 500);
                for i = 1:500
                    [sx(i), sy(i)] = geo.project(lon(i), lat(i), c);
                end
                tc.verifyTrue(isequaln(bx, sx) && isequaln(by, sy), ...
                    sprintf('%s: batched must equal scalar bitwise', p));
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function shiftingTheCentralMeridianShiftsTheData(tc)
            % THE PROPERTY F2 VIOLATED, and the reason this test exists.
            % Not bitwise: the two paths wrap at different points, so
            % eps-level it is.
            rng(42, 'twister');
            lon = rand(1, 2000) * 300 - 150;
            lat = rand(1, 2000) * 160 - 80;
            for p = ["robinson" "mollweide" "hammer" "sinusoidal"]
                a = tc.stack(geo.project(lon, lat, geo.crs(p)));
                b = tc.stack(geo.project(lon + 40, lat, ...
                    geo.crs(p, CenterLongitude = 40)));
                tc.verifyAndRecord(max(abs(b - a)), 1e-12, ...
                    "longitude-shift equivariance, " + p, "Earth radii");
            end
        end

        function theInverseIsTheInverseFromTheOtherSide(tc)
            % Round-tripping the IMAGE, not the sphere: start from x,y,
            % go back, and forward again.
            rng(42, 'twister');
            c = geo.crs("mollweide");
            lon = rand(1, 3000) * 358 - 179;
            lat = rand(1, 3000) * 178 - 89;
            [x, y] = geo.project(lon, lat, c);
            [lo, la] = geo.unproject(x, y, c);
            [x2, y2] = geo.project(lo, la, c);
            ok = isfinite(x) & isfinite(lo);
            tc.verifyAndRecord(max(max(abs(x2(ok) - x(ok))), ...
                max(abs(y2(ok) - y(ok)))), 1e-9, ...
                "inverse then forward, mollweide", "Earth radii");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function mollweideAgainstEquirectangular(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED - V5 open. Same arrays both sides, which is the
            % stable shape (D-016): only the projection differs.
            % Mollweide runs a Newton iteration where equirectangular is
            % two multiplications, so the honest expectation is large.
            rng(42, 'twister');
            lon = rand(1, 1e6) * 358 - 179;
            lat = rand(1, 1e6) * 178 - 89;
            tc.assertRatioBudget( ...
                @() geo.project(lon, lat, geo.crs("mollweide")), ...
                @() geo.project(lon, lat, geo.crs("equirectangular")), ...
                90, 30, ...
                "project mollweide / equirectangular, N=1e6 [PREDICTED]");
        end

        function theInverseCostsWhatTheForwardCosts(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED - V5. Closed forms both ways on the same arrays.
            rng(42, 'twister');
            lon = rand(1, 1e6) * 358 - 179;
            lat = rand(1, 1e6) * 178 - 89;
            c = geo.crs("mollweide");
            [x, y] = geo.project(lon, lat, c);
            tc.assertRatioBudget( ...
                @() geo.unproject(x, y, c), ...
                @() geo.project(lon, lat, c), ...
                6, 2, "unproject / project, mollweide, N=1e6 [PREDICTED]");
        end
    end

    % ==================================================================
    methods (Access = private)
        function c = crsFor(~, name)
            %CRSFOR  A valid CRS per projection, in one place.
            switch name
                case "lambertconformal"
                    c = geo.crs(name, CenterLongitude = -96, ...
                        CenterLatitude = 23, StandardParallel = 33, ...
                        StandardParallel2 = 45);
                case "albers"
                    c = geo.crs(name, CenterLongitude = -96, ...
                        CenterLatitude = 23, StandardParallel = 29.5, ...
                        StandardParallel2 = 45.5);
                case "polarstereographic"
                    c = geo.crs(name, StandardParallel = 71);
                case {"lambert", "stereographic", "orthographic", ...
                      "azimuthalequidistant", "gnomonic"}
                    c = geo.crs(name, CenterLatitude = 40);
                otherwise
                    c = geo.crs(name);
            end
        end

        function [lon, lat] = samplesFor(~, name)
            %SAMPLESFOR  In-domain samples, per projection.
            n = 10000;
            lon = rand(1, n) * 358 - 179;
            lat = rand(1, n) * 178 - 89;
            switch name
                case "mercator"
                    lat = rand(1, n) * 168 - 84;
                case "polarstereographic"
                    lat = rand(1, n) * 79 + 10;
            end
        end

        function t = roundTripTol(tc, name)
            %ROUNDTRIPTOL  1e-9, except where a projection earned better.
            t = tc.TolRoundTrip;
            if name == "lambert"
                % Measured 4.6e-9 in the mirror: asin conditioning at the
                % antipodal rim, inherent to the projection (PV-010).
                t = tc.TolRoundTripLambert;
            end
        end

        function v = stack(~, x)
            v = x(:);
        end
    end
end
