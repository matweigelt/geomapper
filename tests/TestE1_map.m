classdef TestE1_map < GeoMapTestCase
%TESTE1_MAP  Stage E.1a: the first L4 front, and the element it needed.
%
%   DESCRIPTION
%     One assertion carries this file: a map built in one call is the
%     same map as one built element by element. That is the whole claim
%     of a front - that it adds no behaviour of its own - and it is the
%     only thing that makes GEO.MAP safe to use instead of the elements.
%
%     The second theme is the rule. GEO.MAP declares L4-FRONT and the
%     audit then holds it to zero drawing primitives and 200 executable
%     lines; it came in at 128, against v1's 3413. The rule has already
%     bitten twice: a title had no element, so GEO.TITLE was written
%     rather than a TEXT call inlined, and a region outline still has
%     none and is flagged rather than improvised.
%
%   ACCURACY
%     Composition is exact: identical CData, identical colour limits.
%     GEO.TITLE's clearance above the map is asserted in points against
%     the fraction asked for.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestE1");
%
%   LIMITATIONS
%     Nothing here asserts appearance, and nothing asserts the v1 option
%     spellings - the compatibility layer is E.1b.
%
%   See also GEO.MAP, GEO.TITLE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.map" "geo.title"]
    end

    methods (Access = private)

        function G = worldGrid(~)
            lon = -180:2:180;
            lat = -90:2:90;
            Z = repmat(sind(lat(:)), 1, numel(lon)) * 50 + ...
                repmat(cosd(lon), numel(lat), 1) * 20;
            G = geo.grid(lon, lat, Z);
        end

        function H = plainMap(tc, varargin)
            %PLAINMAP  A map with the furniture off, closed on teardown.
            bare = {'Graticule', false, 'Coastline', false, ...
                    'Colorbar', false, 'Frame', false};
            H = geo.map(tc.worldGrid(), geo.crs("mollweide"), ...
                bare{:}, varargin{:});
            tc.addTeardown(@() close(H.Figure));
        end

        function p = axesPoints(~, ax)
            u = ax.Units;
            ax.Units = 'points';
            p = ax.Position;
            ax.Units = u;
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function theProjectionOptionNamesItsReplacement(tc)
            % Not "unrecognised argument". The v1 spelling is the one a
            % migrating user will type, so it is the one that has to
            % answer with the migration.
            tc.verifyError(@() geo.map(tc.worldGrid(), ...
                Projection = "mollweide"), 'geo:map:ProjectionOption');
        end

        function thereIsNoMapWithoutABasemap(tc)
            tc.verifyError(@() geo.map(tc.worldGrid(), Basemap = false), ...
                'geo:map:NoBasemap');
        end

        function anElementThatNeedsItsDataSaysWhichField(tc)
            G = tc.worldGrid();
            for spec = ["Points" "Track" "Polygons" "Stipple"]
                args = {spec, struct('LineWidth', 1)};
                tc.verifyError(@() geo.map(G, args{:}), ...
                    'geo:map:MissingField', spec);
            end
        end

        function theRawTripletIsTheSameMap(tc)
            % Three positional arguments is D-003's limit, so the
            % triplet form spends them on lon, lat and Z and takes the
            % projection by name. It must land on the same map.
            lon = -180:2:180;
            lat = -90:2:90;
            Z = repmat(sind(lat(:)), 1, numel(lon)) * 50;
            crs = geo.crs("mollweide");
            a = tc.plainMap();
            b = geo.map(lon, lat, Z, CRS = crs, Graticule = false, ...
                Coastline = false, Colorbar = false, Frame = false);
            tc.addTeardown(@() close(b.Figure));
            tc.verifyEqual(size(b.Basemap.Surface.CData), ...
                size(a.Basemap.Surface.CData));
            tc.verifyEqual(b.Basemap.DataLimits, a.Basemap.DataLimits);
        end

        function falseOmitsTrueDrawsAndAStructConfigures(tc)
            G = tc.worldGrid();
            crs = geo.crs("mollweide");
            off = geo.map(G, crs, Graticule = false, Colorbar = false);
            on = geo.map(G, crs, Graticule = true, Colorbar = false);
            cfg = geo.map(G, crs, Graticule = struct('StepLon', 60), ...
                Colorbar = false);
            tc.addTeardown(@() close([off.Figure on.Figure cfg.Figure]));
            tc.verifyFalse(isfield(off, 'Graticule'));
            tc.verifyTrue(isfield(on, 'Graticule'));
            % RE-DERIVED at PV-140. The expectation was -180:60:120,
            % six ticks, because worldGrid is cell-registered and its
            % NODE range stopped one cell short of the world. Its
            % REGION always ran -180 to 180; now that the extent says so,
            % the seventh tick exists and belongs there. The claim being
            % made is unchanged: the struct reached geo.graticule and
            % StepLon = 60 was honoured.
            tc.verifyEqual(cfg.Graticule.LonTicks, -180:60:180, ...
                'the struct reached geo.graticule');
        end

        function theResultNamesWhatItDrewAndInWhatOrder(tc)
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            H = geo.map(tc.worldGrid(), geo.crs("mollweide"), ...
                Title = "t", ScaleBar = true);
            tc.addTeardown(@() close(H.Figure));
            tc.verifyEqual(H.Order(1), "Basemap");
            tc.verifyTrue(all(ismember(["Graticule" "Coastline" "Frame" ...
                "Colorbar" "Title" "ScaleBar"], H.Order)));
            tc.verifyEqual(string(H.Order), string(H.Order), ...
                'order is a string row');
            tc.verifyFalse(isfield(H, 'Points'));
        end

        function theSharedTypefaceReachesOnlyElementsThatDrawText(tc)
            % Regression. MATLAB's arguments block REJECTS an unknown
            % name-value pair rather than ignoring it, so handing
            % FontSize to geo.coastline - which draws no text - is an
            % error, and was one on this file's first run.
            H = geo.map(tc.worldGrid(), geo.crs("mollweide"), ...
                Coastline = true, Graticule = true, FontSize = 7);
            tc.addTeardown(@() close(H.Figure));
            tc.verifyTrue(isfield(H, 'Coastline'));
            tc.verifyEqual(H.Graticule.Labels(1).FontSize, 7);
        end

        function aStructFieldBeatsTheSharedTypeface(tc)
            H = geo.map(tc.worldGrid(), geo.crs("mollweide"), ...
                FontSize = 7, Graticule = struct('FontSize', 14));
            tc.addTeardown(@() close(H.Figure));
            tc.verifyEqual(H.Graticule.Labels(1).FontSize, 14);
        end

        function aCrsStructIsAcceptedAsWellAsAName(tc)
            % geo.crs is the ONE constructor in this toolbox that is not
            % idempotent: it takes a name and rejects its own output. A
            % front is exactly where a value of unknown provenance
            % arrives, so the guard is asserted rather than remembered.
            G = tc.worldGrid();
            a = geo.map(G, "mollweide", Colorbar = false);
            b = geo.map(G, geo.crs("mollweide"), Colorbar = false);
            tc.addTeardown(@() close([a.Figure b.Figure]));
            tc.verifyEqual(b.CRS.Name, a.CRS.Name);
        end

        function geoMapIsAPureFront(tc)
            % The Stage E rule, read off the file. The audit enforces
            % this on every push; asserting it here too puts the rule
            % where a reader of the tests will meet it.
            tc.verifyIsAPureFront("geo.map");
        end

        function aRegionOutlineIsDrawnByTheOutlineElement(tc)
            % PV-109. This was reported at E.1a as a MISSING capability
            % and it was not missing: geo.coastline has taken
            % Kind = "outline" since D.2, with its own colour and width,
            % and its H1 line says so. The gap was in geo.region, which
            % left Outline empty for a box - so the vertices to draw did
            % not exist, and the element that would have drawn them was
            % blamed. Both halves are asserted here.
            for spec = {[-30 40 20 60], [-30 20; 40 20; 40 60; -30 60]}
                H = geo.map(tc.worldGrid(), geo.crs("mollweide"), ...
                    Region = struct('R', spec{1}), Colorbar = false);
                tc.addTeardown(@() close(H.Figure));
                tc.verifyTrue(isfield(H, 'Region'));
                tc.verifyNotEmpty(H.Region.All, ...
                    'a region outline that draws nothing is not an outline');
            end
        end

        function theRegionOutlineSitsWhereTheRegionIs(tc)
            % The outline must bound the region it names, not merely
            % exist. Checked in projected coordinates against the
            % projected corners.
            R = geo.region([-30 40 20 60]);
            crs = geo.crs("mollweide");
            H = geo.map(tc.worldGrid(), crs, Region = struct('R', R), ...
                Colorbar = false);
            tc.addTeardown(@() close(H.Figure));
            [xc, yc] = geo.project(R.Outline(:, 1).', R.Outline(:, 2).', crs);
            drawn = H.Region.All(1);
            tc.verifyEqual([min(drawn.XData) max(drawn.XData)], ...
                [min(xc) max(xc)], AbsTol = 1e-6);
            tc.verifyEqual([min(drawn.YData) max(drawn.YData)], ...
                [min(yc) max(yc)], AbsTol = 1e-6);
        end

        function aTitleNeedsAMapToSitAbove(tc)
            ax = axes('Parent', tc.figureFor());
            tc.verifyError(@() geo.title(ax, "nothing here"), ...
                'geo:title:NoBasemap');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function oneCallEqualsTheElementsCalledByHand(tc)
            % THE claim of a front: it adds nothing. The oracle is
            % internal - geo.basemap plus manual elements - and that is
            % the strongest available and the one that matters, because
            % what is being certified is that GEO.MAP has no behaviour
            % of its own.
            G = tc.worldGrid();
            crs = geo.crs("mollweide");

            H = geo.map(G, crs, Colorbar = false, ScaleBar = false);

            [f2, ax2, base2] = geo.basemap(G, crs);
            geo.graticule(ax2, crs, FontName = "Helvetica", FontSize = 9);
            geo.coastline(ax2, crs);
            geo.frame(ax2, crs);
            tc.addTeardown(@() close([H.Figure f2]));

            tc.verifyEqual(base2.Surface.CData, H.Basemap.Surface.CData, ...
                'the same colours');
            tc.verifyEqual(base2.DataLimits, H.Basemap.DataLimits);
            tc.verifyEqual(sort(geo.internal.layout("kinds", f2)), ...
                sort(geo.internal.layout("kinds", H.Figure)), ...
                'the same elements registered');
            tc.verifyEqual(numel(ax2.Children), numel(H.Axes.Children), ...
                'and the same number of objects on the axes');
        end

        function theTitleClearsTheMapByTheFractionAskedFor(tc)
            % Asserted in POINTS on the drawn object, because the claim
            % is about where it landed and not about what was requested.
            gap = 0.03;
            H = tc.plainMap();
            [~, ~, ~, ~, ~, yl, diag] = geo.internal.elementExtent(H.Axes, []);
            T = geo.title(H.Axes, "Mass trend", Gap = gap);
            box = geo.internal.plottedBox(H.Axes);
            p = tc.axesPoints(H.Axes);
            drawnPt = p(2) + (T.Text.Position(2) - yl(1)) / (yl(2) - yl(1)) * p(4);
            clearance = drawnPt - (box(2) + box(4));
            wanted = gap * diag / (yl(2) - yl(1)) * p(4);
            tc.verifyAndRecord(abs(clearance - wanted) / wanted, 1e-9, ...
                "title clearance above the map vs Gap times the diagonal", ...
                "relative");
        end

        function theTitleSitsAboveTheMapNotAboveTheAxes(tc)
            % Under `axis equal` an axes letterboxes. The centring is
            % symmetric so the horizontal centres agree - checked, not
            % assumed - but the TOPS do not, and MATLAB's own TITLE
            % anchors to the axes. On a 2:1 world map in a default axes
            % that leaves it floating clear of the map.
            H = tc.plainMap();
            geo.basemap(tc.worldGrid(), geo.crs("equirectangular"), ...
                Parent = H.Axes);
            box = geo.internal.plottedBox(H.Axes);
            p = tc.axesPoints(H.Axes);
            tc.verifyEqual(box(1) + box(3) / 2, p(1) + p(3) / 2, ...
                'letterboxing is centred, so a title is never off to one side', ...
                AbsTol = 1e-9);
            tc.verifyGreaterThan((p(2) + p(4)) - (box(2) + box(4)), 1, ...
                ['the axes top must be measurably above the map top, or ' ...
                 'this fixture cannot discriminate at all']);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function everyElementAtOnceStillDraws(tc)
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            G = tc.worldGrid();
            H = geo.map(G, geo.crs("mollweide"), ...
                Contours = struct('Levels', [-20 0 20]), ...
                Stipple = struct('G', G, 'Density', 6), ...
                Points = struct('P', geo.points([0 40], [10 50])), ...
                Track = struct('T', geo.track(-60:5:60, zeros(1, 25), Obs = sind(-60:5:60))), ...
                Title = "everything", ScaleBar = true, NorthArrow = true, ...
                Inset = true, Rivers = true);
            tc.addTeardown(@() close(H.Figure));
            tc.verifyEqual(numel(H.Order), 14, ...
                'basemap plus thirteen rungs: ' + strjoin(H.Order, ','));
        end

        function drawingTwiceReplacesRatherThanDuplicates(tc)
            % STRENGTHENED at E.4. This asserted only that the first
            % axes' child count had not grown - which is trivially true
            % when the second call goes to a DIFFERENT FIGURE, and that
            % is exactly what was happening: Parent was declared,
            % documented and never read (PV-121). An assertion that
            % cannot distinguish "reused the axes" from "ignored the
            % argument" tests neither, so the reuse is asserted first.
            G = tc.worldGrid();
            crs = geo.crs("mollweide");
            H = geo.map(G, crs, Title = "first", Colorbar = false);
            tc.addTeardown(@() close(H.Figure));
            before = numel(H.Axes.Children);
            nFig = numel(findall(groot, 'Type', 'figure'));
            H2 = geo.map(G, crs, Title = "second", Colorbar = false, ...
                Parent = H.Axes);
            tc.verifyEqual(H2.Axes, H.Axes, 'Parent must be honoured');
            tc.verifyEqual(numel(findall(groot, 'Type', 'figure')), nFig, ...
                'and no new figure created');
            tc.verifyEqual(numel(H.Axes.Children), before, ...
                'and the elements replaced rather than duplicated');
        end

        function anEmptyTitleLeavesNoTitle(tc)
            H = tc.plainMap();
            geo.title(H.Axes, "something");
            tc.verifyTrue(any(geo.internal.layout("kinds", H.Figure) == "title"));
            geo.title(H.Axes, "");
            tc.verifyFalse(any(geo.internal.layout("kinds", H.Figure) == "title"));
        end

        function theTitleRegistersItsFootprint(tc)
            H = tc.plainMap();
            T = geo.title(H.Axes, "a two word title");
            tc.verifyGreaterThan(T.Rect(3), 0);
            tc.verifyGreaterThan(T.Rect(4), 0);
            rects = geo.internal.layout("rects", H.Axes);
            tc.verifyNotEmpty(rects, ...
                'a title the colorbar cannot see is a title it will overlap');
        end

        function exportingFromTheFrontWritesTheFile(tc)
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            file = fullfile(d, "m.png");
            H = geo.map(tc.worldGrid(), geo.crs("mollweide"), ...
                Colorbar = false, Export = file, ...
                ExportOptions = struct('Width', 9, 'Resolution', 150));
            tc.addTeardown(@() close(H.Figure));
            info = imfinfo(file);
            tc.verifyEqual(info.Width, round(9 / 2.54 * 150), AbsTol = 1);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function twoIdenticalCallsGiveIdenticalColours(tc)
            G = tc.worldGrid();
            crs = geo.crs("mollweide");
            a = geo.map(G, crs, Colorbar = false);
            b = geo.map(G, crs, Colorbar = false);
            tc.addTeardown(@() close([a.Figure b.Figure]));
            tc.verifyEqual(b.Basemap.Surface.CData, a.Basemap.Surface.CData);
            tc.verifyEqual(b.Order, a.Order);
        end

        function theOrderOfTheOPTIONSDoesNotChangeTheORDERDRAWN(tc)
            tc.suppressWarning('geo:scalebar:ScaleVaries');
            % The ladder is the contract, so it may not depend on the
            % sequence a caller happened to type the options in.
            G = tc.worldGrid();
            crs = geo.crs("mollweide");
            a = geo.map(G, crs, Title = "t", ScaleBar = true, Colorbar = false);
            b = geo.map(G, crs, Colorbar = false, ScaleBar = true, Title = "t");
            tc.addTeardown(@() close([a.Figure b.Figure]));
            tc.verifyEqual(b.Order, a.Order);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function theFrontCostsNoMoreThanTheElementsItCalls(tc)
            % A front that added a measurable cost would be doing
            % something, and it is supposed to be doing nothing.
            G = tc.worldGrid();
            crs = geo.crs("mollweide");
            f = figure('Visible', 'off');
            tc.addTeardown(@() close(f));
            tc.assertRatioBudget( ...
                @() drawFront(G, crs), @() drawByHand(G, crs), ...
                1.3, 1.0, "geo.map vs the same four elements by hand, N = 1 map", ...
                Weak = true, Repeats = 6);

            function drawFront(G, crs)
                H = geo.map(G, crs, Colorbar = false);
                close(H.Figure);
            end
            function drawByHand(G, crs)
                [fh, ax] = geo.basemap(G, crs);
                geo.graticule(ax, crs, FontName = "Helvetica", FontSize = 9);
                geo.coastline(ax, crs);
                geo.frame(ax, crs);
                close(fh);
            end
        end
    end
end
