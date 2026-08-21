classdef TestD3a_fieldOverlays < GeoMapTestCase
%TESTD3A_FIELDOVERLAYS  Stage D.3a: polygons, stipple, contours.
%
%   DESCRIPTION
%     The three overlays that describe the FIELD rather than annotate the
%     map, and therefore sit under the graticule: contours at z = 1,
%     polygons and stipple at z = 2.
%
%     TWO OF THESE ARE NEW AND ARE WHY v2 EXISTS FOR THIS PROJECT.
%     GEO.OVERLAYPOLYGONS draws a value per irregular cell, which is what
%     a mascon solution IS and which a regular grid cannot represent at
%     all; v1 forced such a field onto a lon/lat raster, inventing
%     boundaries it does not have. GEO.STIPPLE draws a significance mask,
%     which v1 could not do, so every figure it made either overstated
%     its result or carried the mask in a panel nobody put beside it.
%
%   ACCURACY
%     Two exact claims. A polygon's colour equals the basemap's truecolor
%     mapping of the same value, bit for bit. A seam-crossing polygon's
%     parts total exactly the width of the polygon.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestD3a");
%
%   LIMITATIONS
%     Nothing here asserts appearance.
%
%   See also GEO.OVERLAYPOLYGONS, GEO.STIPPLE, GEO.OVERLAYCONTOURS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.overlayPolygons" "geo.stipple" ...
                            "geo.overlayContours"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function anOverlayIsCutOrMaskedAtTheFrameNotAtTheWorld(tc)
            % PV-142. geo.coastline was cut at the frame at PV-136; the
            % four other elements that take the same path were not, and
            % each drew the whole world into the margin geo.frame opens
            % for its band. A contour is CUT, because a polyline can be;
            % a stipple mark is MASKED, because a marker cannot be.
            % The extent comes from the BASEMAP's grid; the overlay's
            % data is global. That is the real case - a regional map of
            % a global field - and it is how the defect reaches a user.
            world = globalField();
            ax = axes('Parent', tc.figureFor());
            geo.basemap(regionalField(), "equirectangular", Parent = ax);
            [xl, yl] = deal(xlim(ax), ylim(ax));
            G = world;

            H = geo.overlayContours(ax, G, Levels = [-0.5 0 0.5]);
            x = H.Lines(1).XData;
            tc.verifyLessThanOrEqual(max(x(~isnan(x))), max(xl) + 1e-9, ...
                'A contour must not run past the frame.');

            % GEO.STIPPLE takes the mask AS THE GRID - G.Z is the
            % significance itself, not a field with a Mask option beside
            % it. Written the other way it raised TooManyInputs, which
            % is the arguments block doing its job on a caller that had
            % assumed an interface instead of reading one.
            sig = geo.grid(G.Lon, G.Lat, abs(G.Z) > 0.5);
            S = geo.stipple(ax, sig);
            sx = S.Marks.XData;
            tc.verifyLessThanOrEqual(max(sx), max(xl) + 1e-9, ...
                'A significance mark outside the map is a claim about a place the map is not showing.');
            tc.verifyGreaterThanOrEqual(min(S.Marks.YData), min(yl) - 1e-9);
        end

        function aPointOutsideTheMapIsDroppedNotDrawn(tc)
            % A marker is inside or it is not; there is nothing to cut.
            ax = axes('Parent', tc.figureFor());
            geo.basemap(regionalField(), "equirectangular", Parent = ax);
            P = geo.points([0 30 150], [30 40 -60]);
            H = geo.overlayPoints(ax, P);
            tc.verifyEqual(numel(H.Markers.XData), 2, ...
                'The third point is on the other side of the world.');
        end

        function everyPointOutsideTheMapIsAnErrorNotAnEmptyDraw(tc)
            % Silence would look exactly like a successful overlay of
            % nothing, which is the failure mode this project keeps
            % finding. The message names the extent, because "outside
            % the domain" was never the reason on a regional map.
            ax = axes('Parent', tc.figureFor());
            geo.basemap(regionalField(), "equirectangular", Parent = ax);
            P = geo.points([150 160], [-60 -70]);
            tc.verifyError(@() geo.overlayPoints(ax, P), ...
                'geo:overlayPoints:NothingToDraw');
        end

        function eachNeedsAProjectionFromSomewhere(tc)
            ax = axes('Parent', tc.figureFor());
            G = tc.demoGrid();
            tc.verifyError(@() geo.overlayPolygons(ax, {[0 0; 1 0; 1 1]}), ...
                'geo:overlayPolygons:NoBasemap');
            tc.verifyError(@() geo.stipple(ax, geo.grid(G.Lon, G.Lat, ...
                true(size(G.Z)))), 'geo:stipple:NoBasemap');
            tc.verifyError(@() geo.overlayContours(ax, G), ...
                'geo:overlayContours:NoBasemap');
        end

        function oneValuePerPolygonOrNone(tc)
            ax = tc.mapAxes();
            tc.verifyError(@() geo.overlayPolygons(ax, ...
                {[0 0; 1 0; 1 1], [2 2; 3 2; 3 3]}, Values = 1), ...
                'geo:overlayPolygons:ValueCount');
        end

        function bothPolygonFormsAreAccepted(tc)
            % A mascon file gives a cell array; a shapefile reader gives
            % one NaN-separated array. Both are the same information.
            ax = tc.mapAxes();
            cellForm = {[0 40; 10 40; 10 50; 0 50], [20 40; 30 40; 30 50]};
            flatForm = [0 40; 10 40; 10 50; 0 50; NaN NaN; ...
                        20 40; 30 40; 30 50];
            a = geo.overlayPolygons(ax, cellForm, Values = [1 2]);
            b = geo.overlayPolygons(ax, flatForm, Values = [1 2]);
            tc.verifyEqual(numel(b.Patches), numel(a.Patches));
            tc.verifyEqual(b.PolygonOf, a.PolygonOf);
        end

        function aBadPolygonFormIsRejected(tc)
            ax = tc.mapAxes();
            tc.verifyError(@() geo.overlayPolygons(ax, ones(4, 3)), ...
                'geo:overlayPolygons:BadPolygons');
            tc.verifyError(@() geo.overlayPolygons(ax, {ones(4, 3)}), ...
                'geo:overlayPolygons:BadPolygons');
        end

        function anEmptyMaskSaysSoRatherThanDrawingNothing(tc)
            % Drawing nothing silently is indistinguishable from a mask
            % built the wrong way round, which is the likelier mistake.
            ax = tc.mapAxes();
            G = tc.demoGrid();
            tc.verifyError(@() geo.stipple(ax, ...
                geo.grid(G.Lon, G.Lat, zeros(size(G.Z)))), ...
                'geo:stipple:EmptyMask');
        end

        function aFlatFieldHasNoContours(tc)
            ax = tc.mapAxes();
            G = tc.demoGrid();
            tc.verifyError(@() geo.overlayContours(ax, ...
                geo.grid(G.Lon, G.Lat, ones(size(G.Z)))), ...
                'geo:overlayContours:FlatField');
        end

        function allThreeReplaceRatherThanDuplicate(tc)
            ax = tc.mapAxes();
            G = tc.demoGrid();
            sig = geo.grid(G.Lon, G.Lat, abs(G.Z) > 0.5);
            M = {[0 40; 10 40; 10 50; 0 50]};
            geo.overlayPolygons(ax, M, Values = 1);
            geo.stipple(ax, sig);
            geo.overlayContours(ax, G);
            before = numel(ax.Children);
            geo.overlayPolygons(ax, M, Values = 1);
            geo.stipple(ax, sig);
            geo.overlayContours(ax, G);
            tc.verifyEqual(numel(ax.Children), before);
        end

        function theZLadderIsWhatTheContractSays(tc)
            ax = tc.mapAxes();
            G = tc.demoGrid();
            P = geo.overlayPolygons(ax, {[0 40; 10 40; 10 50; 0 50]}, ...
                Values = 1);
            S = geo.stipple(ax, geo.grid(G.Lon, G.Lat, abs(G.Z) > 0.5));
            C = geo.overlayContours(ax, G);
            tc.verifyEqual(unique(P.Patches(1).ZData(:)), 2);
            tc.verifyEqual(unique(S.Marks.ZData), 2);
            tc.verifyEqual(unique(C.Lines(1).ZData(isfinite(C.Lines(1).ZData))), 1);
        end

        function negativeContoursAreDashed(tc)
            ax = tc.mapAxes();
            G = tc.demoGrid();
            H = geo.overlayContours(ax, G, Levels = [-0.5 0.5]);
            styles = arrayfun(@(h) string(h.LineStyle), H.Lines);
            tc.verifyEqual(styles(H.Levels < 0), "--");
            tc.verifyEqual(styles(H.Levels > 0), "-");
            off = geo.overlayContours(ax, G, Levels = [-0.5 0.5], ...
                DashNegative = false);
            tc.verifyTrue(all(arrayfun(@(h) string(h.LineStyle), off.Lines) == "-"));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function aPolygonIsTheColourTheBasemapWouldGiveThatValue(tc)
            % One scale, one meaning. A mascon layer over a hillshaded
            % background must be readable against the same colorbar, and
            % "the same colour" is checkable exactly rather than by eye.
            ax = tc.mapAxes();
            base = geo.internal.layout("data", ax, "basemap");
            values = [-0.6 0 0.4];
            rings = {[0 40; 10 40; 10 50; 0 50], ...
                     [20 40; 30 40; 30 50; 20 50], ...
                     [40 40; 50 40; 50 50; 40 50]};
            H = geo.overlayPolygons(ax, rings, Values = values);
            worst = 0;
            for k = 1:numel(values)
                want = geo.colormaps("truecolor", values(k), ...
                    base.Colormap, CLim = base.CLim);
                got = H.Patches(H.PolygonOf == k).FaceColor;
                worst = max(worst, max(abs(reshape(want, 1, 3) - got)));
            end
            tc.verifyAndRecord(worst, 0, ...
                "polygon colour vs the basemap's for the same value", "RGB");
        end

        function aSeamPolygonSplitsIntoPartsTotallingItsOwnWidth(tc)
            % Both halves of the argument at once: it must SPLIT, and the
            % two parts must add up to the polygon and not to the map. A
            % 20-degree box is 20/360 of an equirectangular map's width,
            % and that is asserted rather than eyeballed.
            ax = tc.mapAxes();
            H = geo.overlayPolygons(ax, ...
                {[170 -10; 190 -10; 190 10; 170 10]}, Values = 0.5);
            tc.assertEqual(numel(H.Patches), 2, ...
                'A polygon across the seam is two closed parts.');
            tc.verifyEqual(H.NumSplit, 1);
            total = 0;
            for k = 1:2
                x = H.Patches(k).XData;
                total = total + (max(x) - min(x));
            end
            tc.verifyAndRecord(abs(total - 2 * pi * 20 / 360) / (2 * pi), ...
                1e-9, "seam polygon parts vs its own width", "fraction of map");
        end

        function theStrideIsExactlyWhatTheDensityAsksFor(tc)
            % Deterministic and derivable: stride = ceil(masked/density),
            % so a reader can predict the pattern from the two numbers.
            ax = tc.mapAxes();
            G = tc.demoGrid();
            sig = geo.grid(G.Lon, G.Lat, abs(G.Z) > 0.5);
            masked = nnz(abs(G.Z) > 0.5);
            for density = [200 800 5000]
                H = geo.stipple(ax, sig, Density = density);
                tc.verifyEqual(H.NumMasked, masked);
                tc.verifyEqual(H.Stride, max(1, ceil(masked / density)));
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function bothLongitudeConventionsGiveTheSameFigure(tc)
            % A region may arrive running past 180, as geo.region's boxes
            % do, or wrapped, as a shapefile's do. Neither is wrong and
            % they must not draw differently.
            ax = tc.mapAxes();
            a = geo.overlayPolygons(ax, ...
                {[170 -10; 190 -10; 190 10; 170 10]}, Values = 0.5);
            widthsA = sort(arrayfun(@(h) max(h.XData) - min(h.XData), a.Patches));
            b = geo.overlayPolygons(ax, ...
                {[170 -10; -170 -10; -170 10; 170 10]}, Values = 0.5);
            widthsB = sort(arrayfun(@(h) max(h.XData) - min(h.XData), b.Patches));
            tc.verifyEqual(widthsB, widthsA, AbsTol = 1e-9);
        end

        function aPolygonNotCrossingTheSeamIsLeftAlone(tc)
            ax = tc.mapAxes();
            H = geo.overlayPolygons(ax, {[0 40; 10 40; 10 50; 0 50]}, ...
                Values = 1);
            tc.verifyEqual(numel(H.Patches), 1);
            tc.verifyEqual(H.NumSplit, 0);
        end

        function aPolygonWithNoValueIsUnfilled(tc)
            % A mascon with no solution is not a mascon with a value of
            % zero, and filling it with the colour of zero would say so.
            ax = tc.mapAxes();
            H = geo.overlayPolygons(ax, ...
                {[0 40; 10 40; 10 50; 0 50], [20 40; 30 40; 30 50; 20 50]}, ...
                Values = [NaN 1]);
            tc.verifyEqual(string(H.Patches(1).FaceColor), "none");
            tc.verifyNotEqual(string(H.Patches(2).FaceColor), "none");
        end

        function askingForMoreDotsThanCellsMarksThemAll(tc)
            ax = tc.mapAxes();
            G = tc.demoGrid();
            sig = geo.grid(G.Lon, G.Lat, abs(G.Z) > 0.5);
            H = geo.stipple(ax, sig, Density = 1e6);
            tc.verifyEqual(H.Stride, 1);
            tc.verifyEqual(H.NumMarks, H.NumMasked);
        end

        function theHatchIsOneObject(tc)
            % Ten thousand strokes as ten thousand objects is what makes
            % a figure take a minute to export.
            ax = tc.mapAxes();
            G = tc.demoGrid();
            H = geo.stipple(ax, geo.grid(G.Lon, G.Lat, abs(G.Z) > 0.5), ...
                Style = "hatch");
            tc.verifyNumElements(H.Marks, 1);
            tc.verifyGreaterThan(H.NumMarks, 10, ...
                'and it must actually contain strokes.');
        end

        function contoursSurviveAProjectionWithASingularity(tc)
            ax = tc.mapAxes(geo.crs("polarstereographic", ...
                Hemisphere = "north"));
            H = geo.overlayContours(ax, tc.demoGrid());
            tc.verifyNotEmpty(H.Lines);
            for k = 1:numel(H.Lines)
                d = hypot(diff(H.Lines(k).XData), diff(H.Lines(k).YData));
                d = d(isfinite(d));
                tc.verifyLessThan(max(d), diff(xlim(ax)), ...
                    'No contour segment may span the whole map.');
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function stippleIsBitIdenticalBetweenCalls(tc)
            % A random thinning would be prettier and untestable, and a
            % reader with the same data could not reproduce the figure.
            ax = tc.mapAxes();
            G = tc.demoGrid();
            sig = geo.grid(G.Lon, G.Lat, abs(G.Z) > 0.5);
            a = geo.stipple(ax, sig, Density = 700);
            xa = a.Marks.XData;
            ya = a.Marks.YData;
            b = geo.stipple(ax, sig, Density = 700);
            tc.verifyTrue(isequaln(b.Marks.XData, xa));
            tc.verifyTrue(isequaln(b.Marks.YData, ya));
        end

        function contourLevelsDoNotDependOnTheProjection(tc)
            % The levels are a property of the FIELD. If a projection
            % changed them, two maps of one dataset would contour
            % different things.
            G = tc.demoGrid();
            ref = [];
            for name = ["equirectangular" "mollweide" "robinson"]
                ax = tc.mapAxes(name);
                H = geo.overlayContours(ax, G);
                if isempty(ref)
                    ref = H.Levels;
                else
                    tc.verifyEqual(H.Levels, ref, ...
                        sprintf('%s changed the levels.', name));
                end
            end
        end

        function drawOrderDoesNotChangeTheResult(tc)
            G = tc.demoGrid();
            sig = geo.grid(G.Lon, G.Lat, abs(G.Z) > 0.5);
            M = {[0 40; 10 40; 10 50; 0 50]};
            axA = tc.mapAxes();
            pA = geo.overlayPolygons(axA, M, Values = 1);
            sA = geo.stipple(axA, sig);
            cA = geo.overlayContours(axA, G);
            axB = tc.mapAxes();
            cB = geo.overlayContours(axB, G);
            sB = geo.stipple(axB, sig);
            pB = geo.overlayPolygons(axB, M, Values = 1);
            tc.verifyEqual(pB.CLim, pA.CLim);
            tc.verifyEqual(sB.Stride, sA.Stride);
            tc.verifyEqual(cB.Levels, cA.Levels);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function stipplingCostsLessThanTheRasterItMarks(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED, tagged WEAK. A significance mask is a decoration
            % on a field that has already been drawn; if marking it costs
            % more than drawing it, nobody will turn it on, and a mask
            % nobody turns on is a mask nobody publishes.
            G = geo.readGrid(fullfile(geoMapRoot(), "data", ...
                "etopo_10min_surface.mat"), Stride = 2);
            ax = axes('Parent', tc.figureFor());
            geo.basemap(G, "equirectangular", Parent = ax, Hillshade = "off");
            sig = geo.grid(G.Lon, G.Lat, G.Z > 0);
            geo.stipple(ax, sig);
            tc.assertRatioBudget( ...
                @() geo.stipple(ax, sig), ...
                @() geo.basemap(G, "equirectangular", Parent = ax, ...
                                Hillshade = "off"), ...
                1, 0.3, "stipple draw / basemap draw [PREDICTED]", ...
                Weak = true);
        end
    end

    % ==================================================================
    methods (Access = private)
    end
end

% ======================================================================
function G = regionalField()
%REGIONALFIELD  A map of one corner of the world, so an extent exists.
%   The shared fixtures are global, and a clip to a global extent has
%   nothing to do - which is precisely why PV-142 went unnoticed.
lon = -20:2:40;
lat = (10:2:50)';
G = geo.grid(lon, lat, sind(3 * repmat(lon, numel(lat), 1)) .* ...
    cosd(2 * repmat(lat, 1, numel(lon))));
end

function G = globalField()
%GLOBALFIELD  Overlay data that reaches well past any regional map.
lon = -180:5:180;
lat = (-90:5:90)';
G = geo.grid(lon, lat, sind(3 * repmat(lon, numel(lat), 1)) .* ...
    cosd(2 * repmat(lat, 1, numel(lon))));
end
