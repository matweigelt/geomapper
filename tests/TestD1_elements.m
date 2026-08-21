classdef TestD1_elements < GeoMapTestCase
%TESTD1_ELEMENTS  Stage D.1: layout, basemap, graticule, frame.
%
%   DESCRIPTION
%     Covers the L3 cartographic frame - the resize manager and the three
%     elements that compose on top of it.
%
%     THIS IS THE WEAKEST STAGE FOR ORACLES AND THAT IS STATED RATHER
%     THAN GLOSSED. Nothing outside this project certifies what a MATLAB
%     frame should look like. The geometry is therefore checked against
%     projected coordinates computed by Stage B, which is itself
%     certified against PROJ - an internal reference, but one certified
%     externally exactly one layer down. Where a property has a closed
%     form (Mollweide's width, the 0-degree meridian's x) it is asserted
%     against the closed form and not against Stage B.
%
%     THE RESIZE TEST FIRES THE EVENT DIRECTLY. An invisible figure does
%     not emit SizeChanged when its Position is set - measured, not
%     assumed - and every figure in this harness is invisible so that the
%     suite can run headless. `notify(fig, 'SizeChanged')` raises the
%     real event on the real object, so the listener, the registry and
%     every element's update run exactly as they would on a drag.
%
%   ACCURACY
%     Geometric assertions at TolGeom, except the two closed-form ones,
%     which are asserted at 1e-9 because they are arithmetic rather than
%     appearance. The resize budget is 5% of on-screen thickness, which
%     is what the eye can see at print size.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestD1");
%
%   LIMITATIONS
%     No test here asserts that a map LOOKS right. Every assertion is on
%     a number recoverable from a graphics object's properties. A visual
%     regression instrument is out of scope for v2 and its absence is a
%     known limit, not an oversight.
%
%   See also GEO.BASEMAP, GEO.GRATICULE, GEO.FRAME, GEO.INTERNAL.LAYOUT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.basemap" "geo.graticule" "geo.frame" ...
                            "geo.internal.layout" ...
                            "geo.internal.mapBoundary" ...
                            "geo.internal.clipToBoundary" ...
                            "geo.internal.avoidRectCollisions"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function basemapRejectsABareMatrix(tc)
            % The grid contract belongs to geo.grid and is not re-checked
            % in the drawing path; this asserts that it still fires there.
            % The identifier is geo.grid's, and deliberately so: the
            % drawing path does not re-validate what the value struct
            % already guarantees, so this asserts that the guarantee
            % still reaches the caller from inside geo.basemap.
            tc.verifyError(@() geo.basemap(rand(10, 20), "equirectangular"), ...
                'geo:grid:NotAVector');
        end

        function divergentGivesSymmetricLimitsOnOneSidedData(tc)
            % The midpoint of a diverging colormap MEANS zero. Fitting the
            % limits to all-positive data would put the neutral colour on
            % a value that is not neutral, which is a lie told in colour.
            G = geo.grid(0:10, (0:10)', 5 + rand(11, 11));
            [~, ~, H] = geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), Divergent = true);
            tc.verifyEqual(sum(H.CLim), 0, AbsTol = 1e-12);
            tc.verifyGreaterThan(H.CLim(2), 0);
        end

        function hillshadeOffEqualsTruecolorWithoutShade(tc)
            % Bit for bit, not to a tolerance: composition must not
            % perturb a path it was told to leave alone.
            G = tc.smallGrid();
            [~, ~, H] = geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), Hillshade = "off");
            ref = geo.colormaps("truecolor", G.Z, H.Colormap, ...
                CLim = H.CLim, NaNColor = [1 1 1]);
            tc.verifyTrue(isequal(ref, H.Surface.CData), ...
                'Hillshade "off" must not touch the colour path.');
            tc.verifyEmpty(H.Shade);
        end

        function aSecondCallReplacesRatherThanDuplicates(tc)
            % Idempotence, asserted by a CONSTANT HANDLE COUNT. v1 grew a
            % second surface, a second graticule and a second frame on
            % every redraw, and the figure looked identical until it was
            % exported and took four times as long.
            G = tc.smallGrid();
            ax = tc.axesFor();
            geo.basemap(G, "equirectangular", Parent = ax);
            geo.graticule(ax, StepLon = 60, StepLat = 30);
            geo.frame(ax, StepLon = 60, StepLat = 30);
            before = numel(ax.Children);
            geo.basemap(G, "equirectangular", Parent = ax);
            geo.graticule(ax, StepLon = 60, StepLat = 30);
            geo.frame(ax, StepLon = 60, StepLat = 30);
            tc.verifyEqual(numel(ax.Children), before, ...
                'A redraw must replace every element, not add one.');
        end

        function theZLadderIsWhatTheContractSays(tc)
            % Occlusion is decided by z under view(2), so an element's
            % level is part of its contract rather than an accident of
            % the order somebody happened to call things in.
            G = tc.smallGrid();
            ax = tc.axesFor();
            [~, ~, B] = geo.basemap(G, "equirectangular", Parent = ax);
            Gr = geo.graticule(ax, StepLon = 60, StepLat = 30);
            F = geo.frame(ax, StepLon = 60, StepLat = 30);
            tc.verifyEqual(unique(B.Surface.ZData(:)), 0);
            tc.verifyEqual(unique(Gr.Meridians(1).ZData), 3);
            tc.verifyEqual(unique(F.Patches(1).ZData), 6);
        end

        function aGlobalGridReportsAFullTurn(tc)
            % PV-138, re-derived at PV-140. geo.wrapLongitude's window
            % is half-open, so a grid
            % written -180:20:180 - the natural way to write a global
            % field - arrives as -180..160, one cell short of the world.
            % Read as a closed interval that cut 222 coastline vertices
            % out of the Pacific. The extent is CYCLIC and says so.
            lon = -180:20:180;
            lat = (-90:15:90)';
            G = geo.grid(lon, lat, sind(3 * repmat(lon, numel(lat), 1)) .* ...
                cosd(2 * repmat(lat, 1, numel(lon))));
            ax = tc.axesFor();
            [~, ~, B] = geo.basemap(G, "equirectangular", Parent = ax);
            % RE-DERIVED at PV-140, not deleted. LonClosesTurn was a
            % flag saying "believe the endpoints less than they say".
            % Registration removes the need for it: this grid holds both
            % rims, so it is POSTING-registered and its region IS 360,
            % and a plain span test now answers what the flag existed to
            % answer.
            tc.verifyEqual(B.Registration, "posting");
            tc.verifyEqual(diff(B.LonLimit), 360, ...
                'A grid holding both ends of the world covers a turn.', ...
                AbsTol = 1e-9);
            tc.verifyEqual(diff(B.LatLimit), 180, ...
                'and both poles.', AbsTol = 1e-9);
        end

        function aRegionalGridReportsNoTurn(tc)
            % The control. The seam gap is compared against the largest
            % INTERIOR step, so a regional grid's 320-degree gap cannot
            % be mistaken for a 20-degree one.
            lon = 0:2:40;
            lat = (10:2:50)';
            G = geo.grid(lon, lat, repmat(lat, 1, numel(lon)) + ...
                repmat(lon, numel(lat), 1));
            ax = tc.axesFor();
            [~, ~, B] = geo.basemap(G, "equirectangular", Parent = ax);
            % The control, unchanged in substance: a regional grid
            % carries no evidence of registration, so it stays posting
            % and its region stays its node range.
            tc.verifyEqual(B.Registration, "posting");
            tc.verifyEqual(B.LonLimit, [0 40]);
            tc.verifyEqual(B.LatLimit, [10 50]);
        end

        function theCoastlineIsCutAtTheFrameNotAtTheWorld(tc)
            % PV-136, reported from GettingStarted: on the track map the
            % coastline ran outside the frame. geo.coastline fetched the
            % extent from elementExtent and discarded outputs two and
            % three, so it drew the whole world and let the axes box hide
            % what it could - and geo.frame widens that box past its own
            % band, which is the margin the spill showed in.
            %
            % Measured on the shipped 110 m coastline over the
            % GettingStarted extent: 486 029 of 529 498 km outside, 91.8%.
            lo = -26:4:46;
            la = (9:4:54)';
            G = geo.grid(lo, la, sind(3 * repmat(lo, numel(la), 1)) .* ...
                cosd(2 * repmat(la, 1, numel(lo))));
            ax = tc.axesFor();
            geo.basemap(G, "equirectangular", Parent = ax);
            C = geo.coastline(ax);
            tc.verifyTrue(C.ClippedToExtent, ...
                'The extent was fetched and not used.');
            tc.verifyGreaterThan(C.ExtentCuts, 0, ...
                'A regional map must cut the shoreline somewhere.');

            % The observable: nothing drawn outside the frame's own ring.
            B = geo.internal.mapBoundary(geo.crs("equirectangular"), ...
                [-26 46], [9 54]);
            good = isfinite(C.Line.XData) & isfinite(C.Line.YData);
            in = inpolygon(C.Line.XData(good), C.Line.YData(good), ...
                B.RingX, B.RingY);
            tc.verifyEqual(nnz(~in), 0, ...
                'A drawn coastline vertex lies outside the map boundary.');
        end


        function aPointPoleDoesNotCollapseTheFrameBand(tc)
            % PV-135, reported from GettingStarted: "the fishnet frame
            % collapsed to a triangle". mollweide, hammer and sinusoidal
            % map the pole to a POINT, so every vertex of the boundary's
            % top edge projects to the same place. OUTWARDNORMALS returned
            % a zero mitre for a zero-length segment, the band offset by
            % nothing, and the frame tapered away.
            %
            % The observable is the band's AREA, not its count: a patch
            % drawn with zero width is still a patch, which is why every
            % count-based check in this suite stayed green through it.
            % The grid must REACH the pole - smallGrid stops at 80 and
            % does not reproduce this.
            for name = ["mollweide" "hammer" "sinusoidal"]
                ax = tc.axesFor();
                geo.basemap(poleToPoleGrid(), name, Parent = ax);
                F = geo.frame(ax, StepLon = 60, StepLat = 30);
                a = arrayfun(@(h) polygonArea(h.XData, h.YData), F.Patches);
                tc.verifyGreaterThan(min(a), 0, ...
                    sprintf('%s: a frame band has zero area.', name));
                tc.verifyEqual(numel(F.Patches), 12, ...
                    sprintf(['%s: 24 boundary vertices, twelve of them ' ...
                             'the two pole runs, so twelve bands.'], name));
            end
        end

        function aPoleLineProjectionIsUntouchedByTheCollapseRepair(tc)
            % The control, and the reason the repair is a rule about
            % coincident vertices rather than a list of projection names.
            % robinson and winkeltripel map the pole to a LINE: no vertex
            % coincides, so nothing may be dropped and all 24 bands stand.
            for name = ["robinson" "winkeltripel"]
                ax = tc.axesFor();
                geo.basemap(poleToPoleGrid(), name, Parent = ax);
                F = geo.frame(ax, StepLon = 60, StepLat = 30);
                a = arrayfun(@(h) polygonArea(h.XData, h.YData), F.Patches);
                tc.verifyGreaterThan(min(a), 0, name);
                tc.verifyEqual(numel(F.Patches), 24, ...
                    sprintf(['%s: a pole-line projection must keep every ' ...
                             'boundary vertex.'], name));
            end
        end

        function noLightingCallsSurvivedTheRewrite(tc)
            % D-009 is enforced statically by the audit; this asserts the
            % OBSERVABLE consequence, which a static check cannot see: the
            % surface must be unlit and flat, whatever the renderer does.
            G = tc.smallGrid();
            [~, ax, H] = geo.basemap(G, "equirectangular", Parent = tc.axesFor());
            tc.verifyEqual(string(H.Surface.FaceLighting), "none");
            tc.verifyEqual(string(H.Surface.FaceColor), "flat");
            tc.verifyEqual(string(H.Surface.EdgeColor), "none");
            tc.verifyEmpty(findobjLightFree(ax));
        end

        function nanCellsAreTransparentNotColoured(tc)
            G = tc.smallGrid();
            G.Z(3, 4) = NaN;
            [~, ax, H] = geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), NaNColor = [0.2 0.3 0.4]);
            tc.verifyEqual(string(H.Surface.AlphaDataMapping), "none");
            tc.verifyEqual(H.Surface.AlphaData(3, 4), 0);
            tc.verifyEqual(ax.Color, [0.2 0.3 0.4], ...
                'NaNColor is the axes background, by design.');
        end

        function theMaskMethodsNeedTheirOwnInputs(tc)
            G = tc.smallGrid();
            tc.verifyError(@() geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), MaskMethod = "threshold"), ...
                'geo:basemap:MaskMethodMismatch');
            tc.verifyError(@() geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), MaskMethod = "polygon"), ...
                'geo:basemap:MaskMethodMismatch');
            tc.verifyError(@() geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), Mask = true(3, 3)), ...
                'geo:basemap:MaskSizeMismatch');
        end

        function graticuleAndFrameNeedAProjectionFromSomewhere(tc)
            ax = tc.axesFor();
            tc.verifyError(@() geo.graticule(ax), 'geo:graticule:NoBasemap');
            tc.verifyError(@() geo.frame(ax), 'geo:frame:NoBasemap');
        end

        function theZeroMeridianLandsAtExactlyZero(tc)
            % Closed form, so the tolerance is arithmetic and not
            % appearance: on equirectangular, x = (lon - lon0) exactly.
            G = tc.smallGrid();
            ax = tc.axesFor();
            geo.basemap(G, "equirectangular", Parent = ax);
            H = geo.graticule(ax, StepLon = 30, StepLat = 30);
            k = find(abs(H.LonTicks) < 1e-12, 1);
            tc.assertNotEmpty(k, 'The 0 meridian must be among the ticks.');
            tc.verifyAndRecord(max(abs(H.Meridians(k).XData)), 1e-9, ...
                "equirectangular 0-meridian x offset", "Earth radii");
        end

        function mollweideSpansTwoRootTwoEachWay(tc)
            % Closed form again: Mollweide's equator half-width is
            % 2*sqrt(2) Earth radii. Asserted at 0.1%, because the grid's
            % outermost cell CENTRE falls short of 180 by half a cell and
            % that shortfall is real rather than an error.
            % A grid whose outermost CELL CENTRES reach 179.9 and whose
            % rows include the equator exactly. The coarse fixture used
            % elsewhere stops at 177.5, and its 2.5-degree shortfall each
            % side is a real 1.4% deficit in the span - the measurement
            % was right and the tolerance was being asked the wrong
            % question.
            lon = linspace(-179.9, 179.9, 361);
            lat = linspace(-90, 90, 181)';
            G = geo.grid(lon, lat, zeros(numel(lat), numel(lon)));
            [~, ~, H] = geo.basemap(G, "mollweide", ...
                Parent = tc.axesFor(), Hillshade = "off");
            span = max(H.Surface.XData(:)) - min(H.Surface.XData(:));
            tc.verifyAndRecord(abs(span - 4 * sqrt(2)) / (4 * sqrt(2)), ...
                1e-3, "mollweide global x span vs 4*sqrt(2)", "relative");
        end

        function theFramePatchCountIsTheComputedSegmentCount(tc)
            % Not "about right": the number of patches is 2 per longitude
            % interval, 2 per latitude interval, plus 4 corners, and it is
            % computed here from the extent and step rather than recorded
            % from a previous run.
            G = tc.demoGrid();
            ax = tc.axesFor();
            [~, ~, B] = geo.basemap(G, "equirectangular", Parent = ax);
            H = geo.frame(ax, StepLon = 60, StepLat = 30);
            lonB = unique([B.LonLimit(1), ...
                ceil(B.LonLimit(1)/60)*60 : 60 : floor(B.LonLimit(2)/60)*60, ...
                B.LonLimit(2)]);
            latB = unique([B.LatLimit(1), ...
                ceil(B.LatLimit(1)/30)*30 : 30 : floor(B.LatLimit(2)/30)*30, ...
                B.LatLimit(2)]);
            expected = 2 * (numel(lonB) - 1) + 2 * (numel(latB) - 1) + 4;
            tc.verifyEqual(numel(H.Patches), expected);
            tc.verifyEqual(H.Style, "rectangle");
        end

        function theLayoutRejectsWhatItCannotDo(tc)
            f = tc.figureFor();
            ax = axes('Parent', f);
            tc.verifyError(@() geo.internal.layout("frobnicate", f), ...
                'geo:layout:BadCommand');
            tc.verifyError(@() geo.internal.layout("setRect", ax, "nope", [0 0 1 1]), ...
                'geo:layout:NotRegistered');
            tc.verifyError(@() geo.internal.layout("remove", ax, "nope"), ...
                'geo:layout:NotRegistered');
            g = tc.figureFor();
            g.UserData = [1 2 3];
            tc.verifyError(@() geo.internal.layout("count", g), ...
                'geo:layout:UserDataInUse');
        end

        function theLayoutReplacesAKindRatherThanAddingOne(tc)
            f = tc.figureFor();
            ax = axes('Parent', f);
            geo.internal.layout("register", ax, "frame", @(~) []);
            geo.internal.layout("register", ax, "frame", @(~) []);
            tc.verifyEqual(geo.internal.layout("count", f), 1);
            geo.internal.layout("register", ax, "scalebar", @(~) []);
            tc.verifyEqual(geo.internal.layout("count", f), 2);
            tc.verifyEqual(geo.internal.layout("kinds", f), ["frame" "scalebar"]);
        end

        function foreignUserDataSurvivesTheRegistry(tc)
            f = tc.figureFor();
            f.UserData = struct('mine', 42);
            ax = axes('Parent', f);
            geo.internal.layout("register", ax, "frame", @(~) []);
            tc.verifyEqual(f.UserData.mine, 42, ...
                'The registry uses one reserved field and nothing else.');
        end

        function anElementNeverSeesItsOwnRectangle(tc)
            f = tc.figureFor();
            ax = axes('Parent', f);
            geo.internal.layout("register", ax, "a", @(~) []);
            geo.internal.layout("register", ax, "b", @(~) []);
            geo.internal.layout("setRect", ax, "a", [0 0 10 10]);
            geo.internal.layout("setRect", ax, "b", [5 5 10 10]);
            tc.verifySize(geo.internal.layout("rects", ax), [2 4]);
            tc.verifySize(geo.internal.layout("rects", ax, "a"), [1 4]);
        end

        function collisionAvoidanceRejectsWhatItCannotUse(tc)
            tc.verifyError(@() geo.internal.avoidRectCollisions( ...
                [0 0 1 1], zeros(0, 4), [0 0]), ...
                'geo:avoidRectCollisions:ZeroDirection');
            tc.verifyError(@() geo.internal.avoidRectCollisions( ...
                [0 0 1 1], ones(2, 3), [0 1]), ...
                'geo:avoidRectCollisions:InvalidObstacles');
            tc.verifyError(@() geo.internal.avoidRectCollisions( ...
                [0 0 1 1], zeros(0, 4), [0 1], Bounds = ones(2, 4)), ...
                'geo:avoidRectCollisions:InvalidBounds');
        end

        function touchingIsNotOverlapping(tc)
            % A bar flush against the neatline is a convention, not a
            % collision, and this is the assertion that keeps it so.
            moved = geo.internal.avoidRectCollisions( ...
                [0 10 10 10], [0 0 10 10], [0 1]);
            tc.verifyEqual(moved, [0 10 10 10], ...
                'Edge contact must not trigger a move.');
        end

        function collisionAvoidanceClearsWithItsStatedGap(tc)
            moved = geo.internal.avoidRectCollisions( ...
                [0 5 10 10], [0 0 10 10], [0 1]);
            tc.verifyEqual(moved(2), 14, ...
                'Clears the obstacle top (10) plus the 4-point gap.', ...
                AbsTol = 1e-12);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function everyProjectionMeetsTheDensificationCriterion(tc)
            % The internal reference: Stage B's projected coordinates,
            % themselves certified against PROJ. The criterion is on the
            % DRAWN RESULT - no projected graticule segment longer than
            % 1/200 of the map diagonal - so it is measured after drawing
            % rather than predicted from the sampling.
            %
            % ALL SIXTEEN. An earlier version of this test excluded
            % transverse Mercator and justified the exclusion at length.
            % The justification was wrong twice over - see R-011 - and
            % the exclusion is gone rather than quietly narrowed.
            G = tc.demoGrid();
            worst = 0;
            for name = geo.internal.projectionNames()
                ax = tc.axesFor();
                geo.basemap(G, tc.crsFor(name), Parent = ax, Hillshade = "off");
                H = geo.graticule(ax);
                worst = max(worst, H.MaxSegment);
            end
            tc.verifyAndRecord(worst, 1 / 200, ...
                "worst graticule segment, all 16 projections", ...
                "fraction of map diagonal");
        end

        function aBranchCutIsBrokenRatherThanDrawnAcross(tc)
            % REGRESSION, and the defect this checkpoint nearly shipped.
            % Transverse Mercator's meridians 120 degrees from the
            % central meridian lie on the back of the transverse
            % cylinder, where cos(dLon) changes sign and the atan2 giving
            % y flips branch. The jump is exactly 2*pi and does not
            % shrink under bisection, so without a break every transverse
            % Mercator map carries a straight line across it - defect
            % F2's cousin on a different projection.
            ax = tc.axesFor();
            geo.basemap(tc.demoGrid(), geo.crs("transversemercator"), ...
                Parent = ax, Hillshade = "off");
            H = geo.graticule(ax, StepLon = 60, StepLat = 30);
            k = find(abs(abs(H.LonTicks) - 120) < 1e-9, 1);
            tc.assertNotEmpty(k, 'The 120-degree meridian must be drawn.');
            x = H.Meridians(k).XData;
            y = H.Meridians(k).YData;
            tc.verifyTrue(any(isnan(x)), ...
                'The back-of-cylinder meridian must be broken by a NaN.');
            d = hypot(diff(x), diff(y));
            tc.verifyLessThan(max(d(isfinite(d))), 2 * pi, ...
                'No drawn segment may span the branch cut.');
        end

        function graticuleLinesReachTheMapEdge(tc)
            % Bisecting the segment that straddles the domain boundary is
            % what makes a meridian arrive AT the edge rather than
            % stopping at whichever sample happened to be last inside.
            % Orthographic has a horizon at radius 1 exactly, so the
            % shortfall is measurable rather than a matter of opinion.
            ax = tc.axesFor();
            c = geo.crs("orthographic", CenterLatitude = 30);
            geo.basemap(tc.demoGrid(), c, Parent = ax, Hillshade = "off");
            H = geo.graticule(ax);
            reached = 0;
            for k = 1:numel(H.Meridians)
                x = H.Meridians(k).XData;
                y = H.Meridians(k).YData;
                ok = isfinite(x) & isfinite(y);
                if any(ok)
                    reached = max(reached, max(hypot(x(ok), y(ok))));
                end
            end
            tc.verifyAndRecord(1 - reached, 1e-6, ...
                "orthographic horizon shortfall of the graticule", ...
                "Earth radii");
        end

        function aLabelAnchorUnprojectsToTheValueItNames(tc)
            % The inverse used as an INDEPENDENT check rather than as
            % machinery. Placing the label with geo.unproject and then
            % checking it with geo.unproject would check it against
            % itself; the placement is analytic, so the two directions
            % are genuinely separate.
            G = tc.demoGrid();
            ax = tc.axesFor();
            c = geo.crs("equirectangular");
            geo.basemap(G, c, Parent = ax);
            H = geo.graticule(ax, StepLon = 30, StepLat = 30);
            worst = 0;
            for k = 1:numel(H.LonTicks)
                p = H.Labels(k).Position;
                lonBack = geo.unproject(p(1), p(2), c);
                worst = max(worst, ...
                    abs(mod(lonBack - H.LonTicks(k) + 180, 360) - 180));
            end
            tc.verifyAndRecord(worst, tc.TolGeom, ...
                "meridian label anchor unprojected to its own longitude", "deg");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'precision'})
        function theCutMeetsTheFrameRatherThanStoppingShortOfIt(tc)
            % The failure mode of the one-line repair, asserted against.
            % Dropping the outside vertex leaves the line short of the
            % ring by up to one coastline segment - measured at 108 km,
            % twelve screen pixels - which trades a spill outside the
            % frame for a white margin inside it. Sixteen halvings take
            % the residual to 1.6e-3 km.
            crs = geo.crs("equirectangular");
            B = geo.internal.mapBoundary(crs, [-26 46], [9 54]);
            lon = [0 0];
            lat = [30 80];              % leaves through the top edge
            [cl, ca] = deal([], []);
            [cl, ca] = geo.internal.clipToBoundary(lon, lat, B);
            tc.verifyEqual(numel(cl), 2);
            [~, yc] = geo.project(cl(end), ca(end), crs);
            [~, yTop] = geo.project(0, 54, crs);
            tc.verifyAndRecord(abs(yc - yTop), 1e-2, ...
                "coastline cut vs the frame it was cut at", "km");
        end

    end

    methods (Test, TestTags = {'robustness'})
        function anIncompleteRingDoesNotStopTheClip(tc)
            % RE-DERIVED, not deleted (PV-137). The premise was that a
            % boundary leaving the projection's domain closes with an
            % invented chord, so clipping against it would delete real
            % shoreline - true of an INPOLYGON test against a ring, and
            % the reason that test was declined.
            %
            % Membership is no longer a ring test. It is the extent in
            % lon/lat AND the domain through geo.project's NaN, both of
            % which are defined whether or not a ring can be drawn. So
            % an incomplete ring no longer declines anything: what falls
            % outside the domain is dropped because the projection says
            % so, which is the same authority that declined before.
            crs = geo.crs("equirectangular");
            B = geo.internal.mapBoundary(crs, [-26 46], [9 54]);
            B.Complete = false;
            lon = [0 0 0];
            lat = [30 80 100];
            [~, la, info] = geo.internal.clipToBoundary(lon, lat, B);
            tc.verifyTrue(info.Clipped, ...
                'The extent still bounds the line without a ring.');
            tc.verifyLessThanOrEqual(max(la), 54 + 1e-6, ...
                'Nothing above the extent may survive the clip.');
        end

        function aSingleCellGridIsRefusedByTheGridContract(tc)
            % Refused at construction, before drawing is reached: a
            % single cell has no step, and every later function asks for
            % one. Asserting it here records that geo.basemap inherits
            % the refusal rather than working around it.
            tc.verifyError(@() geo.grid(0, 0, 1), 'geo:grid:TooFewPoints');
        end

        function aZeroSpanFieldStillGetsUsableLimits(tc)
            % A constant field has no range. Widening by half a unit keeps
            % the colour mapping defined; refusing to draw would be worse
            % than drawing one flat colour, which is the truth about it.
            G = geo.grid(0:10, (0:10)', 7 * ones(11, 11));
            [~, ~, H] = geo.basemap(G, "equirectangular", Parent = tc.axesFor());
            tc.verifyEqual(H.CLim, [6.5 7.5], AbsTol = 1e-12);
        end

        function anAllNaNFieldDrawsNothingAndSaysSoInAlpha(tc)
            G = geo.grid(0:10, (0:10)', NaN(11, 11));
            [~, ~, H] = geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), Hillshade = "off");
            tc.verifyTrue(all(H.Surface.AlphaData(:) == 0), ...
                'Every cell is missing, so every cell is transparent.');
            tc.verifyTrue(all(isfinite(H.CLim)));
        end

        function anExtentOutsideTheDomainSaysSoRatherThanDrawingNothing(tc)
            G = geo.grid(0:5, (0:5)', zeros(6, 6));
            c = geo.crs("orthographic", CenterLongitude = 180, CenterLatitude = 0);
            tc.verifyError(@() geo.basemap(G, c, Parent = tc.axesFor()), ...
                'geo:basemap:NothingToDraw');
        end

        function aMaskThatCoversEverythingWarnsAndStillDraws(tc)
            % Exactly the case v1 warned about, and it must still draw:
            % §4.5, a library that refuses is not protecting anybody.
            G = tc.smallGrid();
            tc.suppressWarning('geo:basemap:MaskCoversEverything');
            [~, ~, H] = geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), Mask = true(size(G.Z)));
            [~, id] = lastwarn;
            tc.verifyEqual(id, 'geo:basemap:MaskCoversEverything');
            tc.verifyTrue(isgraphics(H.Surface));
        end

        function aMaskThatCoversNothingWarnsAndStillDraws(tc)
            G = tc.smallGrid();
            tc.suppressWarning('geo:basemap:MaskCoversNothing');
            [~, ~, H] = geo.basemap(G, "equirectangular", ...
                Parent = tc.axesFor(), Mask = false(size(G.Z)));
            [~, id] = lastwarn;
            tc.verifyEqual(id, 'geo:basemap:MaskCoversNothing');
            tc.verifyTrue(isgraphics(H.Surface));
        end

        function aFigureSqueezedToNearNothingDoesNotThrow(tc)
            G = tc.smallGrid();
            f = tc.figureFor();
            ax = axes('Parent', f);
            geo.basemap(G, "equirectangular", Parent = ax);
            geo.frame(ax, StepLon = 60, StepLat = 30);
            f.Position = [100 100 30 20];
            tc.verifyWarningFree(@() notify(f, 'SizeChanged'), ...
                'A near-zero figure must not break the resize path.');
        end

        function aBrokenElementIsNamedAndTheOthersStillUpdate(tc)
            % v1's bare catch made a broken element indistinguishable from
            % an absent one. This is the assertion that it no longer is.
            f = tc.figureFor();
            ax = axes('Parent', f);
            % A graphics object as the counter, for its handle semantics:
            % a plain variable would be copied into the closure and the
            % increment would be invisible from here.
            probe = line('Parent', ax, 'XData', 0, 'YData', 0, ...
                'Visible', 'off', 'UserData', 0);
            geo.internal.layout("register", ax, "bad", ...
                @(~) error('x:y:z', 'deliberate'));
            geo.internal.layout("register", ax, "good", ...
                @(~) set(probe, 'UserData', probe.UserData + 1));
            tc.suppressWarning('geo:layout:UpdateFailed');
            geo.internal.layout("update", f);
            [~, id] = lastwarn;
            tc.verifyEqual(id, 'geo:layout:UpdateFailed');
            tc.verifyEqual(probe.UserData, 1, ...
                'The healthy element must still have updated.');
        end

        function anEntryWhoseAxesWentAwayIsDropped(tc)
            f = tc.figureFor();
            ax = axes('Parent', f);
            geo.internal.layout("register", ax, "frame", @(~) []);
            delete(ax);
            geo.internal.layout("update", f);
            tc.verifyEqual(geo.internal.layout("count", f), 0);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function theFrameBandSurvivesApproachingThePole(tc)
            % PV-135, metamorphic. The defect showed exactly in the
            % limit - a frame stopping at 85 was right and one reaching
            % 90 was a triangle - so the invariant asserted is continuity
            % of the banded area as the northern limit walks to the pole,
            % not a value at either end.
            lat85 = (-90:15:75)';
            lat85 = [lat85; 85];
            areas = zeros(1, 2);
            lats = {lat85, (-90:15:90)'};
            for i = 1:2
                la = lats{i};
                lo = -180:20:180;
                ax = tc.axesFor();
                G = geo.grid(lo, la, sind(3 * repmat(lo, numel(la), 1)) .* ...
                    cosd(2 * repmat(la, 1, numel(lo))));
                geo.basemap(G, "mollweide", Parent = ax);
                F = geo.frame(ax, StepLon = 60, StepLat = 30);
                areas(i) = sum(arrayfun(@(h) ...
                    polygonArea(h.XData, h.YData), F.Patches));
            end
            tc.verifyAndRecord(abs(log(areas(2) / areas(1))), log(3), ...
                "mollweide frame band area, pole over 85", "");
        end

        function drawOrderDoesNotChangeTheResult(tc)
            % This is what "composable" MEANS, and without this test it is
            % only an intention. Two orders, same object set, same z
            % levels, same patch count.
            G = tc.smallGrid();
            axA = tc.axesFor();
            geo.basemap(G, "equirectangular", Parent = axA);
            geo.graticule(axA, StepLon = 60, StepLat = 30);
            F1 = geo.frame(axA, StepLon = 60, StepLat = 30);

            axB = tc.axesFor();
            geo.basemap(G, "equirectangular", Parent = axB);
            F2 = geo.frame(axB, StepLon = 60, StepLat = 30);
            geo.graticule(axB, StepLon = 60, StepLat = 30);

            tc.verifyEqual(numel(F2.Patches), numel(F1.Patches));
            tc.verifyEqual(F2.Thickness, F1.Thickness, RelTol = 1e-12);
            tc.verifyEqual(sort(zLevels(axA)), sort(zLevels(axB)), ...
                'The same elements must occupy the same z levels.');
        end

        function theResizeIsIdempotentAndDoesNotRatchet(tc)
            % v1 UNIONED the axis limits on every redraw, so shrinking the
            % figure widened them, which lowered the points-per-data-unit,
            % which widened them again: the map crept smaller inside its
            % own axes over repeated resizes. Ten cycles here, and the
            % limits must come back to where they started.
            G = tc.demoGrid();
            f = tc.figureFor();
            f.Position = [100 100 800 500];
            ax = axes('Parent', f);
            geo.basemap(G, "equirectangular", Parent = ax);
            geo.frame(ax, StepLon = 60, StepLat = 30);
            xl0 = xlim(ax);
            for k = 1:10
                f.Position = [100 100 400 + 50 * mod(k, 2) 500];
                notify(f, 'SizeChanged');
            end
            f.Position = [100 100 800 500];
            notify(f, 'SizeChanged');
            tc.verifyAndRecord(max(abs(xlim(ax) - xl0)), tc.TolGeom, ...
                "axis-limit drift over ten resize cycles", "Earth radii");
        end

        function graticuleTicksDoNotDependOnTheProjection(tc)
            % The ticks are a property of the EXTENT. If a projection
            % changed them, two maps of the same region would carry
            % different graticules and read as different regions.
            G = tc.demoGrid();
            ref = [];
            for name = ["equirectangular" "mollweide" "robinson" "hammer"]
                ax = tc.axesFor();
                geo.basemap(G, tc.crsFor(name), Parent = ax, Hillshade = "off");
                H = geo.graticule(ax);
                if isempty(ref)
                    ref = H.LonTicks;
                else
                    tc.verifyEqual(H.LonTicks, ref, ...
                        sprintf('%s changed the tick set.', name));
                end
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function theFrameRedrawIsCheaperThanTheBasemap(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED, and tagged WEAK because it is a graphics budget:
            % it measures MATLAB's renderer as much as this code, and the
            % handover requires Stage D's ratios to be marked as such.
            %
            % THE FIRST VERSION OF THIS BUDGET ASSERTED THE WRONG
            % RELATION. It compared the resize against a basemap redraw
            % and required the resize to be cheaper, on the reasoning
            % that a resize does less work. Measured: basemap 5.2 ms,
            % frame draw 12.5 ms - one Surface object is cheaper than 28
            % Patch objects, so the premise was simply false and no
            % implementation would have passed. The budget was not
            % loosened; it was pointed at the property that matters.
            %
            % That property is that a resize costs ONE frame redraw and
            % nothing more. If the resize path ever started rebuilding
            % the raster too - easy to do by accident, invisible in every
            % correctness test here - this ratio would jump. Measured
            % 1.05 on the baseline machine.
            G = tc.demoGrid();
            f = tc.figureFor();
            ax = axes('Parent', f);
            geo.basemap(G, "equirectangular", Parent = ax);
            geo.frame(ax, StepLon = 60, StepLat = 30);
            tc.assertRatioBudget( ...
                @() notify(f, 'SizeChanged'), ...
                @() geo.frame(ax, StepLon = 60, StepLat = 30), ...
                1.5, 1.05, "frame resize / frame draw [PREDICTED]", ...
                Weak = true);
        end
    end

    % ==================================================================
    methods (Access = private)
        function ax = axesFor(tc)
            %AXESFOR  Fresh axes in an invisible figure, closed on teardown.
            ax = axes('Parent', tc.figureFor());
        end

        function G = smallGrid(~)
            G = geo.grid(-170:20:170, (-80:20:80)', ...
                repmat((1:9)', 1, 18) + repmat(1:18, 9, 1));
        end


        function c = crsFor(~, name)
            %CRSFOR  A usable CRS for each projection in the register.
            switch name
                case {"orthographic", "stereographic", "lambert", ...
                      "azimuthalequidistant", "gnomonic"}
                    c = geo.crs(name, CenterLatitude = 30);
                case "polarstereographic"
                    c = geo.crs(name, Hemisphere = "north");
                case {"lambertconformal", "albers"}
                    c = geo.crs(name, StandardParallel = 33, ...
                        StandardParallel2 = 45);
                otherwise
                    c = geo.crs(name);
            end
        end
    end
end

% ----------------------------------------------------------------------
function z = zLevels(axH)
%ZLEVELS  The distinct z value of every child, for order-independence.
z = zeros(1, numel(axH.Children));
for k = 1:numel(axH.Children)
    c = axH.Children(k);
    if isprop(c, 'ZData') && ~isempty(c.ZData)
        z(k) = c.ZData(1);
    elseif isprop(c, 'Position')
        p = c.Position;
        z(k) = p(3);
    end
end
end

function h = findobjLightFree(axH)
%FINDOBJLIGHTFREE  Light children, without calling the banned FINDOBJ.
%   The audit rejects findobj inside +geo; this is a test, but using the
%   same discipline here keeps the assertion honest about what it reads.
keep = false(1, numel(axH.Children));
for k = 1:numel(axH.Children)
    keep(k) = isa(axH.Children(k), 'matlab.graphics.primitive.Light');
end
h = axH.Children(keep);
end

% ======================================================================
function G = poleToPoleGrid()
%POLETOPOLEGRID  A field whose latitude axis REACHES both poles.
%   The shared fixtures stop short of the pole - smallGrid at 80,
%   demoGrid at 87.5 - and PV-135 only exists where the boundary's top
%   edge lands ON the pole. A fixture that cannot reach the defect is a
%   test that cannot see it.
lon = -180:20:180;
lat = (-90:15:90)';
G = geo.grid(lon, lat, sind(3 * repmat(lon, numel(lat), 1)) .* ...
    cosd(2 * repmat(lat, 1, numel(lon))));
end

function a = polygonArea(x, y)
%POLYGONAREA  Shoelace area of one patch, sign discarded.
%   Local to this suite deliberately: it is an OBSERVABLE of a drawn
%   object, not a toolbox capability, and promoting it would put a
%   geometry routine in the package that nothing in the package needs.
x = double(x(:));
y = double(y(:));
if numel(x) < 3
    a = 0;
    return
end
a = abs(sum(x .* circshift(y, -1) - circshift(x, -1) .* y)) / 2;
end
