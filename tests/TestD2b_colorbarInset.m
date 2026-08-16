classdef TestD2b_colorbarInset < GeoMapTestCase
%TESTD2B_COLORBARINSET  Stage D.2b: the colour scale and the locator.
%
%   DESCRIPTION
%     Covers the merge of v1's four colorbar implementations into one,
%     and the port of its map inset.
%
%     THE HANDLE-STALENESS TEST IS THE POINT OF THIS FILE. All three of
%     v1's custom colorbars captured the handles created by their first
%     draw and then deleted and recreated them on every resize, so the
%     struct a caller was given held nothing but invalid handles as soon
%     as the window was touched. That is asserted against here directly:
%     resize, then check the handles are still the objects on screen.
%
%   ACCURACY
%     One geometric claim, asserted exactly: a tick for value v sits at
%     (v - CLim(1))/diff(CLim) along the bar. Everything else about a
%     colorbar is layout, which has no correct answer.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestD2b");
%
%   LIMITATIONS
%     Nothing here asserts appearance.
%
%   See also GEO.COLORBAR, GEO.INSET.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.colorbar" "geo.inset" ...
                            "geo.internal.plottedBox"]
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function bothNeedSomethingToDescribe(tc)
            ax = axes('Parent', tc.figureFor());
            tc.verifyError(@() geo.colorbar(ax), 'geo:colorbar:NoBasemap');
            tc.verifyError(@() geo.inset(ax), 'geo:inset:NoBasemap');
        end

        function thePlottedBoxIsTheMapNotTheAxes(tc)
            % An axes under `axis equal` letterboxes: it centres a box of
            % the DATA's aspect ratio inside the one it was given.
            % Anything positioned against the map in figure points has to
            % know which is which, and v1 had five verbatim copies of
            % this working it out. Asserted on a 2:1 map in a square
            % axes, where the two answers differ by construction.
            f = tc.figureFor();
            f.Position = [100 100 400 400];
            ax = axes('Parent', f, 'Units', 'points', ...
                'Position', [50 50 300 300]);
            geo.basemap(tc.demoGrid(), "equirectangular", Parent = ax, ...
                Hillshade = "off");
            box = geo.internal.plottedBox(ax);
            tc.verifyEqual(box(3), 300, ...
                'A 2:1 map in a square axes is width-limited.', ...
                AbsTol = 1e-9);
            tc.verifyEqual(box(4), 150, 'and half as tall.', RelTol = 0.02);
            tc.verifyEqual(box(2), 50 + (300 - box(4)) / 2, ...
                'centred in the leftover height.', AbsTol = 1e-9);
        end

        function theInsideLocationsAreRefusedRatherThanIgnored(tc)
            % v1's validator accepted four "inside" names and its
            % reposition callback then returned early for every one of
            % them - a documented option that did nothing. Refusing is
            % the smaller lie.
            ax = tc.mapAxes();
            tc.verifyError(@() geo.colorbar(ax, Location = "southwest"), ...
                'geo:colorbar:BadLocation');
        end

        function dualNeedsItsSecondScale(tc)
            ax = tc.mapAxes();
            tc.verifyError(@() geo.colorbar(ax, Style = "dual"), ...
                'geo:colorbar:NoSecondCLim');
        end

        function theStripIsOneObjectNotTwoHundredAndFiftySix(tc)
            % v1 drew one patch per colour plus two objects per tick: a
            % continuous GMT bar came to about 283 handles. The colour
            % ramp is a truecolor surface and every tick is one
            % NaN-separated line.
            ax = tc.mapAxes();
            H = geo.colorbar(ax, Label = "z");
            tc.verifyNumElements(H.Strip, 1);
            tc.verifyClass(H.Strip, 'matlab.graphics.primitive.Surface');
            tc.verifyNumElements(H.Ticks, 1);
            tc.verifyLessThan(numel(H.All), 30, ...
                sprintf('A five-tick bar should be about a dozen objects, not %d.', ...
                        numel(H.All)));
        end

        function bothReplaceRatherThanDuplicate(tc)
            ax = tc.mapAxes();
            f = ancestor(ax, 'figure');
            geo.colorbar(ax);
            geo.inset(ax);
            before = numel(f.Children);
            geo.colorbar(ax);
            geo.inset(ax);
            tc.verifyEqual(numel(f.Children), before, ...
                'A redraw must replace, not accumulate.');
        end

        function theNativeStyleIsMatlabsOwn(tc)
            ax = tc.mapAxes();
            H = geo.colorbar(ax, Style = "native", Label = "m");
            tc.verifyClass(H.Axes, 'matlab.graphics.illustration.ColorBar');
            tc.verifyEqual(string(H.Axes.Label.String), "m");
        end

        function discreteLevelsPutTicksOnBlockBoundaries(tc)
            ax = tc.mapAxes();
            H = geo.colorbar(ax, DiscreteLevels = 5);
            tc.verifyNumElements(H.Labels, 6, ...
                'Five blocks have six boundaries.');
        end

        function aVerticalBarLaysOutToo(tc)
            ax = tc.mapAxes();
            H = geo.colorbar(ax, Location = "eastoutside", Label = "z");
            pos = get(H.Axes, 'Position');
            tc.verifyGreaterThan(pos(4), pos(3), ...
                'A vertical bar must be taller than it is wide.');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function aTickSitsAtItsExactFractionAlongTheBar(tc)
            % The one geometric claim this function makes. Read back off
            % the drawn tick line rather than off any intermediate.
            ax = tc.mapAxes();
            H = geo.colorbar(ax, CLim = [0 100], Subticks = 0);
            geom = get(H.Axes, 'XLim');
            barLen = geom(2);
            worst = 0;
            for k = 1:numel(H.Labels)
                v = str2double(H.Labels(k).String);
                if isnan(v)
                    continue                % the axis label, not a number
                end
                expected = (v - 0) / 100 * barLen;
                worst = max(worst, abs(H.Labels(k).Position(1) - expected));
            end
            tc.verifyAndRecord(worst, tc.TolGeom, ...
                "colorbar tick position vs its exact fraction", "points");
        end

        function anEndCapMeansTheDataContinues(tc)
            % v1 drew both triangles whenever Arrows was on and only
            % varied their COLOUR by whether data was out of range, so a
            % bar with nothing beyond its limits still grew two
            % arrowheads announcing that there was some.
            axFull = tc.mapAxes();                 % CLim is the data range
            full = geo.colorbar(axFull);
            tc.verifyEmpty(full.Caps, ...
                'Nothing is out of range, so nothing continues.');

            axClipped = tc.mapAxes();
            base = geo.internal.layout("data", axClipped, "basemap");
            mid = mean(base.CLim);
            span = diff(base.CLim) / 10;
            geo.basemap(tc.demoGrid(), "equirectangular", ...
                Parent = axClipped, Hillshade = "off", ...
                CLim = [mid - span, mid + span]);
            clipped = geo.colorbar(axClipped);
            tc.verifyNumElements(clipped.Caps, 2, ...
                'Data continues past both ends, so both caps appear.');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function theHandlesDoNotGoStaleOnResize(tc)
            % THE v1 DEFECT THIS FILE EXISTS FOR. Its custom bars deleted
            % and rebuilt every handle on every resize while returning
            % the first set, so H.Colorbar held only invalid handles
            % after one window drag.
            ax = tc.mapAxes();
            f = ancestor(ax, 'figure');
            H = geo.colorbar(ax, Label = "z");
            I = geo.inset(ax);
            f.Position = [100 100 500 400];
            notify(f, 'SizeChanged');
            drawnow;
            tc.verifyTrue(all(isgraphics(H.All)), ...
                'Every colorbar handle must survive a resize.');
            tc.verifyTrue(all(isgraphics(I.All)), ...
                'Every inset handle must survive a resize.');
        end

        function arrowsCanBeForcedOnAndOff(tc)
            ax = tc.mapAxes();
            on = geo.colorbar(ax, Arrows = "on");
            tc.verifyNumElements(on.Caps, 2);
            off = geo.colorbar(ax, Arrows = "off");
            tc.verifyEmpty(off.Caps);
        end

        function theLocatorCentresOnTheRegionNotTheProjection(tc)
            % v1 inherited the main map's lon0/lat0, which for a regional
            % map with a global-convention centre put the region at the
            % edge of the locator or off it. A locator answers "where is
            % this"; centring it elsewhere answers something else.
            G = geo.grid(5:0.5:20, (45:0.5:55)', zeros(21, 31));
            ax = axes('Parent', tc.figureFor());
            geo.basemap(G, geo.crs("equirectangular"), Parent = ax, ...
                Hillshade = "off");
            H = geo.inset(ax);
            tc.verifyEqual(H.Crs.CenterLongitude, 12.5, AbsTol = 1e-9);
            tc.verifyEqual(H.Crs.CenterLatitude, 50, AbsTol = 1e-9);
        end

        function theLocatorExtentClosesWhereItProjects(tc)
            % Traced with its first vertex repeated as its last, so a
            % rounding difference between two traces of one corner cannot
            % leave the outline open. Asserted on a regional extent,
            % where both endpoints are inside the visible hemisphere.
            G = geo.grid(5:0.5:20, (45:0.5:55)', zeros(21, 31));
            ax = axes('Parent', tc.figureFor());
            geo.basemap(G, geo.crs("equirectangular"), Parent = ax, ...
                Hillshade = "off");
            H = geo.inset(ax);
            x = H.Extent.XData;
            y = H.Extent.YData;
            tc.assertTrue(isfinite(x(1)) && isfinite(x(end)), ...
                'A regional extent must project at both ends.');
            tc.verifyEqual([x(end) y(end)], [x(1) y(1)], AbsTol = 1e-12);
        end

        function aColorbarWithoutABasemapWorksIfToldTheColours(tc)
            ax = axes('Parent', tc.figureFor());
            H = geo.colorbar(ax, CLim = [0 1], ...
                Colormap = geo.colormaps("get", "viridis", 64));
            tc.verifyEqual(H.CLim, [0 1]);
            tc.verifyEmpty(H.Caps, ...
                'With no basemap there is no out-of-range data to know about.');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function repositioningTouchesNoVertex(tc)
            % The locator's contents are fixed in its own axis-equal
            % coordinates, so a resize moves one Position and nothing
            % else. This is v1's one genuinely good idea in this area and
            % it is worth keeping asserted.
            ax = tc.mapAxes();
            f = ancestor(ax, 'figure');
            H = geo.inset(ax);
            globeBefore = H.Globe.XData;
            coastBefore = H.Coast.XData;
            posBefore = get(H.Axes, 'Position');
            f.Position = [100 100 400 320];
            notify(f, 'SizeChanged');
            drawnow;
            tc.verifyTrue(isequaln(H.Globe.XData, globeBefore));
            tc.verifyTrue(isequaln(H.Coast.XData, coastBefore));
            tc.verifyNotEqual(get(H.Axes, 'Position'), posBefore, ...
                'The locator must actually have moved.');
        end

        function theBarAgreesWithTheMapItSitsBeside(tc)
            % One source of truth. A colorbar that disagreed with its map
            % would be worse than none.
            ax = tc.mapAxes();
            base = geo.internal.layout("data", ax, "basemap");
            H = geo.colorbar(ax);
            tc.verifyEqual(H.CLim, base.CLim);
        end

        function drawOrderDoesNotChangeEither(tc)
            axA = tc.mapAxes();
            a1 = geo.colorbar(axA);
            geo.inset(axA);
            axB = tc.mapAxes();
            geo.inset(axB);
            b1 = geo.colorbar(axB);
            tc.verifyEqual(b1.CLim, a1.CLim);
            tc.verifyEqual(numel(b1.All), numel(a1.All));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function repositioningIsCheaperThanDrawing(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED, tagged WEAK. This is the design property stated
            % as a budget: the locator is REPOSITIONED on resize, never
            % redrawn, so a resize must cost far less than a draw. If
            % somebody ever makes the update rebuild the contents - which
            % is what every other v1 element did - this is what notices.
            ax = tc.mapAxes();
            f = ancestor(ax, 'figure');
            geo.inset(ax);
            tc.assertRatioBudget( ...
                @() notify(f, 'SizeChanged'), ...
                @() geo.inset(ax), ...
                0.5, 0.05, "inset reposition / inset draw [PREDICTED]", ...
                Weak = true);
        end
    end

    % ==================================================================
    methods (Access = private)

    end
end
