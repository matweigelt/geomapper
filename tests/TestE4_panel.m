classdef TestE4_panel < GeoMapTestCase
%TESTE4_PANEL  Stage E.4: the last front, and the height correction.
%
%   DESCRIPTION
%     Two assertions carry this file. The map tiles have equal plotted
%     heights - v1's own 2% visual-equality criterion, carried forward
%     deliberately - and a series tile's plot box matches the plotted
%     height of the map sharing its row.
%
%     The second is the one with a story. A map axes uses `axis equal`
%     and fills only a centred sub-rectangle of its tile; a series axes
%     fills the whole tile, so two equal tiles look like two different
%     heights. TILEDLAYOUT FORBIDS SETTING Position ON ITS CHILDREN -
%     the assignment warns and is ignored, so the obvious repair appears
%     to work and changes nothing. v1 found that and reshaped the axes
%     with PlotBoxAspectRatio instead; the workaround is carried forward
%     rather than rediscovered, and this file is what stops someone
%     "fixing" it back.
%
%   ACCURACY
%     Map plotted heights within 2%, which is a visual threshold and is
%     labelled as one. The series match is exact and is asserted at
%     1e-12 relative.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestE4");
%
%   LIMITATIONS
%     Nothing here asserts appearance. Panel labels are absent by
%     design and are not tested.
%
%   See also GEO.PANEL, GEO.INTERNAL.PLOTTEDBOX.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = "geo.panel"
    end

    methods (Access = private)

        function G = field(~, amp)
            lon = -180:4:180;
            lat = -90:4:90;
            G = geo.grid(lon, lat, ...
                amp * repmat(sind(lat(:)), 1, numel(lon)));
        end

        function S = record(~)
            t = 0:0.05:8;
            S = geo.track(zeros(size(t)), zeros(size(t)), Time = t, ...
                Obs = sin(t));
        end

        function h = boxHeight(~, axH)
            b = geo.internal.plottedBox(axH);
            h = b(4);
        end

        function h = seriesBoxHeight(~, axH)
            %SERIESBOXHEIGHT  The drawn height a PlotBoxAspectRatio gives.
            u = axH.Units;
            axH.Units = 'points';
            p = axH.Position;
            axH.Units = u;
            r = axH.PlotBoxAspectRatio;
            h = p(3) * r(2) / r(1);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function geoPanelIsAPureFront(tc)
            tc.verifyIsAPureFront("geo.panel");
        end

        function anEmptySpecSaysSo(tc)
            tc.verifyError(@() geo.panel(struct([])), 'geo:panel:NoTiles');
        end

        function anUnknownTileTypeNamesTheFour(tc)
            tc.verifyError(@() geo.panel(struct('Type', "nope", ...
                'Data', tc.field(50))), 'geo:panel:UnknownType');
        end

        function aLayoutTooSmallSaysSo(tc)
            spec = struct('Type', {"map", "map"}, ...
                'Data', {tc.field(50), tc.field(30)});
            tc.verifyError(@() geo.panel(spec, Layout = [1 1]), ...
                'geo:panel:LayoutTooSmall');
        end

        function theLayoutDefaultsToNearlySquare(tc)
            spec = struct('Type', {"map", "map", "map"}, ...
                'Data', {tc.field(50), tc.field(30), tc.field(10)});
            H = tc.keep(geo.panel(spec));
            tc.verifyEqual(H.Layout.GridSize, [2 2], ...
                'three tiles fill a 2x2, not a 1x3');
        end

        function everyTileGetsItsOwnFrontsResult(tc)
            spec = struct('Type', {"map", "series"}, ...
                'Data', {tc.field(50), tc.record()});
            H = tc.keep(geo.panel(spec));
            tc.verifyEqual(numel(H.Tiles), 2);
            tc.verifyEqual(H.IsMap, [true false]);
            tc.verifyTrue(isfield(H.Tiles{1}, 'Basemap'));
            tc.verifyTrue(isfield(H.Tiles{2}, 'Series'));
        end

        function aTilesOwnOptionsReachItsFront(tc)
            spec = struct('Type', {"map"}, 'Data', {tc.field(50)}, ...
                'Options', {{'Title', "(a) 2003", 'Graticule', false}});
            H = tc.keep(geo.panel(spec));
            tc.verifyTrue(isfield(H.Tiles{1}, 'Title'));
            tc.verifyFalse(isfield(H.Tiles{1}, 'Graticule'));
        end

        function theColorbarPolicyIsHonoured(tc)
            spec = struct('Type', {"map", "map"}, ...
                'Data', {tc.field(50), tc.field(30)});
            last = tc.keep(geo.panel(spec, Colorbar = "last"));
            each = tc.keep(geo.panel(spec, Colorbar = "each"));
            none = tc.keep(geo.panel(spec, Colorbar = "none"));
            tc.verifyEqual([isfield(last.Tiles{1}, 'Colorbar') ...
                            isfield(last.Tiles{2}, 'Colorbar')], [false true]);
            tc.verifyTrue(isfield(each.Tiles{1}, 'Colorbar'));
            tc.verifyFalse(isfield(none.Tiles{1}, 'Colorbar'));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function theMapTilesHaveEqualPlottedHeights(tc)
            % v1's own criterion, carried forward deliberately. 2% is a
            % VISUAL-equality threshold - the point at which a reader
            % stops seeing two panels as the same size - and it is
            % labelled as one rather than tightened to look rigorous.
            spec = struct('Type', {"map", "map", "map"}, ...
                'Data', {tc.field(50), tc.field(30), tc.field(10)});
            H = tc.keep(geo.panel(spec, Layout = [1 3]));
            drawnow;
            h = arrayfun(@(a) tc.boxHeight(a), H.Axes);
            tc.verifyAndRecord((max(h) - min(h)) / max(h), 0.02, ...
                "panel map plotted heights, spread over three tiles", ...
                "relative");
        end

        function theSeriesBoxMatchesTheMapItSharesARowWith(tc)
            % The correction the whole file is about. Exact, because the
            % target IS the map's plotted height.
            spec = struct('Type', {"map", "series"}, ...
                'Data', {tc.field(50), tc.record()});
            H = tc.keep(geo.panel(spec, Layout = [1 2]));
            drawnow;
            want = tc.boxHeight(H.Axes(1));
            got = tc.seriesBoxHeight(H.Axes(2));
            tc.verifyEqual(string(H.Axes(2).PlotBoxAspectRatioMode), ...
                "manual", 'the correction must actually be applied');
            tc.verifyAndRecord(abs(got - want) / want, 1e-12, ...
                "series plot-box height vs the map's plotted height", ...
                "relative");
        end

        function theSharedScaleCoversEveryMapsData(tc)
            % Panels that are not comparable are worse than no panels: a
            % reader assumes a shared scale unless told otherwise.
            spec = struct('Type', {"map", "map"}, ...
                'Data', {tc.field(50), tc.field(30)});
            H = tc.keep(geo.panel(spec));
            tc.verifyEqual(H.Tiles{2}.Basemap.CLim, H.Tiles{1}.Basemap.CLim, ...
                'both maps must share one scale');
            tc.verifyEqual(H.Tiles{1}.Basemap.CLim, H.CLim, ...
                'the reported scale is the one applied', AbsTol = 1e-12);
            tc.verifyGreaterThan(H.CLim(2), 30, ...
                'and it must reach the larger field''s range');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aPanelWithNoMapIsNotCorrected(tc)
            spec = struct('Type', {"series", "series"}, ...
                'Data', {tc.record(), tc.record()});
            H = tc.keep(geo.panel(spec));
            tc.verifyEqual(string(H.Axes(1).PlotBoxAspectRatioMode), "auto", ...
                'nothing to match against, so nothing is changed');
        end

        function theSeriesTilesShareAnXAxis(tc)
            spec = struct('Type', {"series", "series"}, ...
                'Data', {tc.record(), tc.record()});
            H = tc.keep(geo.panel(spec, LinkX = true));
            H.Axes(1).XLim = [2 3];
            drawnow;
            tc.verifyEqual(H.Axes(2).XLim, [2 3], ...
                'linked axes move together');
        end

        function allFourTileTypesDispatch(tc)
            lonT = -20:2:20;
            spec = struct( ...
                'Type', {"map", "trackmap", "pointmap", "series"}, ...
                'Data', {tc.field(50), ...
                         geo.track(lonT, 40 + 0 * lonT, Obs = sind(lonT)), ...
                         geo.points([0 10], [40 45], Obs = [1 2]), ...
                         tc.record()});
            H = tc.keep(geo.panel(spec, Layout = [2 2]));
            tc.verifyEqual(numel(H.Tiles), 4);
            tc.verifyTrue(isfield(H.Tiles{2}, 'Region'), 'trackmap ran');
            tc.verifyTrue(isfield(H.Tiles{3}, 'Region'), 'pointmap ran');
            tc.verifyTrue(isfield(H.Tiles{4}, 'Series'), 'timeseries ran');
        end

        function exportingFromThePanelWritesTheFile(tc)
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            file = fullfile(d, "p.png");
            spec = struct('Type', {"map", "series"}, ...
                'Data', {tc.field(50), tc.record()});
            tc.keep(geo.panel(spec, Export = file, ...
                ExportOptions = struct('Width', 12, 'Resolution', 150)));
            info = imfinfo(file);
            tc.verifyEqual(info.Width, round(12 / 2.54 * 150), AbsTol = 1);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function theOrderOfTilesDoesNotChangeTheSharedScale(tc)
            a = tc.keep(geo.panel(struct('Type', {"map", "map"}, ...
                'Data', {tc.field(50), tc.field(30)})));
            b = tc.keep(geo.panel(struct('Type', {"map", "map"}, ...
                'Data', {tc.field(30), tc.field(50)})));
            % PV-077, fourth occurrence: the diagnostic goes BEFORE the
            % tolerance. Written the other way round it is a syntax
            % error and costs a whole suite load.
            tc.verifyEqual(b.CLim, a.CLim, ...
                'the scale comes from the data, not from the order', ...
                AbsTol = 1e-12);
        end

        function twoIdenticalPanelsAgree(tc)
            spec = struct('Type', {"map", "series"}, ...
                'Data', {tc.field(50), tc.record()});
            a = tc.keep(geo.panel(spec));
            b = tc.keep(geo.panel(spec));
            tc.verifyEqual(b.CLim, a.CLim);
            tc.verifyEqual(b.Tiles{1}.Basemap.Surface.CData, ...
                a.Tiles{1}.Basemap.Surface.CData);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function thePanelCostsNoMoreThanItsTiles(tc)
            spec = struct('Type', {"map", "map"}, ...
                'Data', {tc.field(50), tc.field(30)});
            G1 = tc.field(50);
            G2 = tc.field(30);
            tc.assertRatioBudget( ...
                @() asPanel(spec), @() asTwoFigures(G1, G2), ...
                1.8, 1.2, "geo.panel vs two separate maps, N = 2 tiles", ...
                Weak = true, Repeats = 4);

            function asPanel(spec)
                H = geo.panel(spec, Colorbar = "none");
                close(H.Figure);
            end
            function asTwoFigures(G1, G2)
                a = geo.map(G1, [], Colorbar = false);
                b = geo.map(G2, [], Colorbar = false);
                close([a.Figure b.Figure]);
            end
        end
    end
end
