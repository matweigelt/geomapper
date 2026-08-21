classdef TestD2_annotations < GeoMapTestCase
%TESTD2_ANNOTATIONS  Stage D.2a: coastline, scale bar, north arrow.
%
%   DESCRIPTION
%     Covers the three elements that sit on a basemap and say something
%     about it, plus the shared polyline projector they and GEO.GRATICULE
%     all use.
%
%     THE SCALE BAR IS THE ONE ELEMENT HERE WITH A HARD NUMERICAL CLAIM,
%     and it is checked by walking the bar. The length of a bar on the
%     ground is the integral of the local scale along it, so the test
%     unprojects four thousand points across the drawn bar and sums the
%     great-circle steps between them. That is an independent quantity:
%     the bar was built from a single derivative at one point, and the
%     check accumulates a different thing entirely.
%
%   ACCURACY
%     Where a horizontal line in projected space IS a parallel -
%     equirectangular, Mercator, Mollweide, Robinson - the scale along
%     the bar is constant and the walked length equals the label
%     EXACTLY, asserted at 1e-9 relative. On a conic it does not, because
%     a horizontal line is not a parallel there, and the residual is the
%     variation the bar itself reports.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestD2");
%
%   LIMITATIONS
%     Nothing here asserts appearance. The north arrow's bearing is a
%     number and is checked; whether the glyph looks like an arrow is not
%     something this harness can see.
%
%   See also GEO.COASTLINE, GEO.SCALEBAR, GEO.NORTHARROW.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.coastline" "geo.scalebar" ...
                            "geo.northarrow" "geo.internal.projectPolyline"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function eachElementNeedsAProjectionFromSomewhere(tc)
            ax = tc.axesFor();
            tc.verifyError(@() geo.coastline(ax), 'geo:coastline:NoBasemap');
            tc.verifyError(@() geo.scalebar(ax), 'geo:scalebar:NoBasemap');
            tc.verifyError(@() geo.northarrow(ax), 'geo:northarrow:NoBasemap');
        end

        function theBuiltinCoastlineIsThisToolboxesNotMatlabs(tc)
            % Stage C loaded MATLAB's coastlines.mat, which does not ship
            % with R2026a. Nothing caught it because nothing had asked.
            [xy, meta] = geo.readCoastline("builtin");
            tc.verifyGreaterThan(size(xy, 1), 1000);
            tc.verifyEqual(meta.Provenance, "verified");
            p = fullfile(geoMapRoot(), "data", "coast_110m.mat");
            tc.assertTrue(isfile(p), "The shipped coastline is missing.");
            s = load(p);
            tc.verifySubstring(s.provenance.Producer, "Natural Earth");
            tc.verifySubstring(s.provenance.Licence, "Public domain");
        end

        function kindSelectsDefaultsNotACodePath(tc)
            % v1 had three near-identical drawing loops, one per kind.
            % Here Kind is three numbers; the code they run is the same.
            ax = tc.mapAxes();
            a = geo.coastline(ax, Kind = "coastline");
            colourA = a.Line.Color;
            b = geo.coastline(ax, Kind = "river");
            tc.verifyNotEqual(b.Line.Color, colourA);
            tc.verifyClass(b.Line, class(a.Line));
        end

        function anExplicitStyleBeatsTheKindDefault(tc)
            ax = tc.mapAxes();
            H = geo.coastline(ax, Kind = "river", Color = [0 1 0], ...
                LineWidth = 3);
            tc.verifyEqual(H.Line.Color, [0 1 0]);
            tc.verifyEqual(H.Line.LineWidth, 3);
        end

        function everyElementReplacesRatherThanDuplicates(tc)
            ax = tc.mapAxes();
            geo.coastline(ax);
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            geo.scalebar(ax);
            geo.northarrow(ax);
            before = numel(ax.Children);
            geo.coastline(ax);
            geo.scalebar(ax);
            geo.northarrow(ax);
            tc.verifyEqual(numel(ax.Children), before, ...
                'A redraw must replace every element, not add one.');
        end

        function theZLadderIsWhatTheContractSays(tc)
            ax = tc.mapAxes();
            C = geo.coastline(ax);
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            S = geo.scalebar(ax);
            N = geo.northarrow(ax);
            tc.verifyEqual(unique(C.Line.ZData(isfinite(C.Line.ZData))), 4);
            tc.verifyEqual(unique(S.Patches(1).ZData(:)), 6);
            tc.verifyEqual(unique(N.Patches(1).ZData(:)), 6);
        end

        function anExplicitBarLengthIsHonouredExactly(tc)
            ax = tc.mapAxes();
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            H = geo.scalebar(ax, Length = 1234);
            tc.verifyEqual(H.LengthGround, 1234);
        end

        function theNiceLadderIsOneTwoFiveAcrossEveryDecade(tc)
            % Generated, not tabulated: v1's table clamped below 1 km and
            % above 5000 km, so every regional map and every planetary
            % one was mislabelled.
            ax = tc.mapAxes();
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            seen = zeros(1, 0);
            for frac = [0.02 0.05 0.1 0.25 0.5]
                H = geo.scalebar(ax, TargetFraction = frac);
                seen(end + 1) = H.LengthGround; %#ok<AGROW>
            end
            mantissa = seen ./ 10 .^ floor(log10(seen));
            tc.verifyTrue(all(ismember(round(mantissa, 9), [1 2 5 10])), ...
                sprintf('Lengths were %s', mat2str(seen)));
        end

        function theArrowLabelCanBeOmitted(tc)
            ax = tc.mapAxes();
            H = geo.northarrow(ax, Label = "");
            tc.verifyEmpty(H.Label);
            tc.verifyNumElements(H.Patches, 2);
        end

        function theProjectorRejectsMismatchedInput(tc)
            tc.verifyError(@() geo.internal.projectPolyline([1 2 3], [1 2], ...
                geo.crs("equirectangular")), ...
                'geo:projectPolyline:SizeMismatch');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function theBarMeasuresTheDistanceItClaims(tc)
            % THE ASSERTION v1 COULD NOT HAVE PASSED. Its bar was always
            % 90 points wide and its label was the nearest ladder entry
            % to whatever ground distance those points happened to span -
            % errors approaching 50%. Here the walked length of the drawn
            % bar is compared with its own label.
            %
            % Only projections on which a horizontal line IS a parallel,
            % because only then is the scale constant along the bar and
            % the claim exact. The conic case is the next test.
            worst = 0;
            for name = ["equirectangular" "mercator" "mollweide" "robinson"]
                ax = tc.mapAxes(name);
                tc.suppressWarning('geo:scalebar:ScaleVaries');
                H = geo.scalebar(ax);
                walked = tc.walkBar(H, geo.crs(name));
                worst = max(worst, ...
                    abs(walked - H.LengthGround) / H.LengthGround);
            end
            % 1e-9 is not arbitrary: the calibration is a secant whose
            % error is O(step^2), and the step was set to the floor of
            % that curve - measured 5.3e-12 relative against the closed
            % form R*cos(lat), against 1.3e-6 at the first step tried.
            tc.verifyAndRecord(worst, 1e-9, ...
                "scale bar walked length vs its own label", "relative");
        end

        function onAConicTheBarIsOffByTheVariationItReports(tc)
            % A horizontal line on a conic is not a parallel, so the
            % scale genuinely varies along the bar. The bar does not
            % pretend otherwise - it reports ScaleVariation, and the
            % residual must be inside it rather than unexplained.
            c = geo.crs("lambertconformal", StandardParallel = 33, ...
                StandardParallel2 = 45);
            ax = tc.mapAxes(c);
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            H = geo.scalebar(ax);
            walked = tc.walkBar(H, c);
            residual = abs(walked - H.LengthGround) / H.LengthGround;
            tc.verifyLessThan(residual, H.ScaleVariation - 1, ...
                'The error must be inside the variation the bar reports.');
            tc.verifyGreaterThan(H.ScaleVariation, 1);
        end

        function northIsMeasuredWhereTheArrowIs(tc)
            % On equirectangular north is up everywhere, so every anchor
            % must give exactly zero. A bearing computed once at the map
            % centre would also pass this; the conic test below is what
            % separates them.
            worst = 0;
            for loc = ["northwest" "northeast" "southwest" "southeast"]
                ax = tc.mapAxes();
                H = geo.northarrow(ax, Location = loc);
                worst = max(worst, abs(H.BearingDeg));
            end
            tc.verifyAndRecord(worst, 1e-9, ...
                "north arrow bearing on equirectangular, worst corner", "deg");
        end

        function onAConicNorthDiffersBetweenCorners(tc)
            % This is what v1 got wrong: it computed one bearing at the
            % projection's reference point and used it wherever the arrow
            % sat. On a conic the convergence of the meridians makes that
            % simply false, and the two upper corners must disagree.
            c = geo.crs("lambertconformal", StandardParallel = 33, ...
                StandardParallel2 = 45);
            ax = tc.mapAxes(c);
            w = geo.northarrow(ax, Location = "northwest");
            e = geo.northarrow(ax, Location = "northeast");
            tc.verifyGreaterThan(abs(w.BearingDeg - e.BearingDeg), 10, ...
                'A single map-wide bearing would make these equal.');
            tc.verifyEqual(w.BearingDeg, -e.BearingDeg, AbsTol = 1e-6);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function anAntimeridianCrossingIsBrokenNotDrawnAcross(tc)
            % The coastline's own version of the branch cut. On a
            % cylindrical projection the shoreline wraps; on an
            % orthographic hemisphere the seam is not visible at all, so
            % there is nothing to break.
            axCyl = tc.mapAxes("equirectangular");
            cyl = geo.coastline(axCyl);
            axOrtho = tc.mapAxes(geo.crs("orthographic", CenterLatitude = 30));
            ortho = geo.coastline(axOrtho);
            tc.verifyGreaterThan(cyl.NumCuts, 0, ...
                'A global coastline crosses the antimeridian.');
            tc.verifyEqual(ortho.NumCuts, 0, ...
                'A hemisphere cannot contain the seam.');
        end

        function nothingIsDensifiedIntoTheCoastline(tc)
            % Adding vertices between two survey points invents
            % shoreline. RE-DERIVED, not loosened, when the cut arrived
            % (PV-136): a clip both DROPS vertices that fall outside the
            % extent and INSERTS one at each crossing, so the old
            % identity - drawn == read + branch cuts - became false for
            % an honest reason. It is asserted here in the only place it
            % still holds unchanged, a pole-to-pole global extent where
            % nothing is outside, so that a regression in the no-clip
            % path cannot hide behind the new arithmetic.
            lon = -180:20:180;
            lat = (-90:15:90)';
            G = geo.grid(lon, lat, sind(3 * repmat(lon, numel(lat), 1)) .* ...
                cosd(2 * repmat(lat, 1, numel(lon))));
            ax = tc.axesFor();
            geo.basemap(G, "equirectangular", Parent = ax);
            xy = geo.readCoastline("builtin");
            H = geo.coastline(ax);
            tc.verifyEqual(H.ExtentKept, size(xy, 1) - sum(isnan(xy(:, 1))), ...
                'A global extent excludes nothing.');
            tc.verifyEqual(numel(H.Line.XData), size(xy, 1) + H.NumCuts, ...
                'Points may be broken apart but never invented.');
        end

        function aClipInventsOnePointPerCrossingAndNoMore(tc)
            % The other half of the same contract, on an extent that
            % DOES cut. Every drawn vertex is either one that was read
            % and kept, or one crossing point placed on the extent's own
            % edge. Anything else is invention (PV-136).
            % The limit has to be one the DATA actually crosses: the
            % builtin coastline reaches 83.6 N and -85.6 S, so demoGrid's
            % 87.5 excludes nothing and the first version of this test
            % asserted a crossing that could not happen.
            lon = -180:20:180;
            lat = (-60:15:60)';
            G = geo.grid(lon, lat, sind(3 * repmat(lon, numel(lat), 1)) .* ...
                cosd(2 * repmat(lat, 1, numel(lon))));
            ax = tc.axesFor();
            geo.basemap(G, "equirectangular", Parent = ax);
            H = geo.coastline(ax);
            drawn = nnz(~isnan(H.Line.XData));
            tc.verifyTrue(H.ClippedToExtent, ...
                'An extent short of the pole must cut a global coastline.');
            tc.verifyEqual(drawn, H.ExtentKept + H.ExtentCuts, ...
                'Drawn = kept + one point per crossing, exactly.');
            tc.verifyGreaterThan(H.ExtentCuts, 0, ...
                'A global coastline crosses a 60-degree limit.');
        end

        function anArrayCoastlineIsDrawnAsGiven(tc)
            ax = tc.mapAxes();
            xy = [0 0; 10 10; NaN NaN; 20 20; 30 30];
            H = geo.coastline(ax, Source = xy);
            tc.verifyEqual(H.NumParts, 2);
        end

        function aVaryingScaleWarnsAndStillDraws(tc)
            % D-006. A global map's scale varies enormously; refusing to
            % draw a bar on one would refuse most real maps.
            ax = tc.mapAxes();
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            H = geo.scalebar(ax);
            [~, id] = lastwarn;
            tc.verifyEqual(id, 'geo:scalebar:ScaleVaries');
            tc.verifyNumElements(H.Patches, 4);
            tc.verifyGreaterThan(H.ScaleVariation, 1.05);
        end

        function anArrowWhoseAnchorIsOffTheMapStillDraws(tc)
            % An orthographic hemisphere does not fill its bounding box,
            % so a corner anchor does not unproject. The arrow points up
            % and says so, rather than erroring or drawing nothing.
            ax = tc.mapAxes(geo.crs("orthographic", CenterLatitude = 0));
            H = geo.northarrow(ax, Location = "northwest");
            tc.verifyNumElements(H.Patches, 2);
            tc.verifyTrue(isfinite(H.BearingDeg));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function drawOrderDoesNotChangeTheResult(tc)
            axA = tc.mapAxes();
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            geo.coastline(axA);
            sA = geo.scalebar(axA);
            nA = geo.northarrow(axA);

            axB = tc.mapAxes();
            nB = geo.northarrow(axB);
            sB = geo.scalebar(axB);
            geo.coastline(axB);

            tc.verifyEqual(sB.LengthGround, sA.LengthGround);
            tc.verifyEqual(sB.LengthData, sA.LengthData, RelTol = 1e-12);
            tc.verifyEqual(nB.BearingDeg, nA.BearingDeg, AbsTol = 1e-12);
        end

        function theCachedCoastlineEqualsTheUncachedOne(tc)
            % The cache is transparent or it is a defect.
            geo.cache("clear");
            ax1 = tc.mapAxes();
            cold = geo.coastline(ax1);
            ax2 = tc.mapAxes();
            warm = geo.coastline(ax2);
            tc.verifyTrue(isequaln(warm.Line.XData, cold.Line.XData));
            tc.verifyTrue(isequaln(warm.Line.YData, cold.Line.YData));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function theCoastlineCostsLessThanTheRasterItSitsOn(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED, tagged WEAK - a graphics budget measures
            % MATLAB's renderer as much as this code. The property is
            % directional: vector geography over a basemap must not cost
            % more than the basemap, or every figure pays twice for its
            % decoration.
            %
            % THE FIXTURE IS A REPRESENTATIVE RASTER, NOT A TOY, and the
            % first version was not. Against a 36x72 grid the ratio
            % measured 3.29 and the budget failed - correctly, because
            % nobody draws a coastline over 2 592 cells. Against the
            % shipped 10-arc-minute grid it is 0.139. Third time a Stage
            % D fixture has been too small to ask its own question
            % (PV-069, PV-076); the pattern is now named.
            G = geo.readGrid(fullfile(geoMapRoot(), "data", ...
                "etopo_10min_surface.mat"), Stride = 2);
            ax = tc.axesFor();
            geo.basemap(G, "equirectangular", Parent = ax, Hillshade = "off");
            geo.coastline(ax);
            tc.assertRatioBudget( ...
                @() geo.coastline(ax), ...
                @() geo.basemap(G, "equirectangular", Parent = ax, ...
                                Hillshade = "off"), ...
                1.5, 0.5, "coastline draw / basemap draw [PREDICTED]", ...
                Weak = true);
        end
    end

    % ==================================================================
    methods (Access = private)
        function ax = axesFor(tc)
            ax = axes('Parent', tc.figureFor());
        end



        function km = walkBar(~, H, crs)
            %WALKBAR  Ground length of the drawn bar, by walking along it.
            %   The bar was built from ONE derivative at ONE point; this
            %   accumulates four thousand great-circle steps across it,
            %   which is a different quantity computed a different way.
            xs = zeros(0, 1);
            for k = 1:numel(H.Patches)
                xs = [xs; H.Patches(k).XData(:)]; %#ok<AGROW> per patch
            end
            x0 = min(xs);
            x1 = max(xs);
            yb = mean(H.Patches(1).YData(:));
            % SIXTEEN THOUSAND, AND THE NUMBER IS MEASURED. The walk is
            % a polygonal approximation of an arc and converges as
            % O(1/n^2): against the closed form R*cos(lat) its own error
            % runs 3.5e-7 at n=500, 2.2e-8 at 2000, 6.0e-9 at 4000 and
            % 4e-10 at 16000. The bar's own calibration error is 5.3e-12,
            % so below about 16000 this test measures ITS OWN
            % discretisation and not the bar - which is what it did at
            % 4000, reporting 1.24e-8 against a 1e-9 bound. The
            % instrument was sharpened; the bound did not move.
            n = 16000;
            xv = linspace(x0, x1, n);
            [lon, lat] = geo.unproject(xv, repmat(yb, 1, n), crs);
            step = geo.greatCircle([lon(1:end-1).', lat(1:end-1).'], ...
                [lon(2:end).', lat(2:end).']);
            km = sum(step.DistanceKm);
        end
    end
end
