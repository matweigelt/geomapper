classdef TestE1c_v1Options < GeoMapTestCase
%TESTE1C_V1OPTIONS  Stage E.1c: every v1 option is accounted for.
%
%   DESCRIPTION
%     One assertion carries this file, and it discharges V9: **every
%     option v1's geoImagesc declares either translates to a v2 option
%     THAT EXISTS, or raises with the replacement named.** There is no
%     third outcome - in particular, no v1 option is silently ignored,
%     which is the failure a migration layer exists to prevent.
%
%     BOTH SIDES ARE READ FROM SOURCE. The v1 names come out of
%     geoImagesc.m's own arguments block and the v2 names out of each
%     element's, so neither list can drift from the code it describes.
%     The Stage 0 inventory is a summary and is not used as the
%     authority here - it was, at first, and its "fronts" column matched
%     by prefix, so geoImagescPoints counted as geoImagesc and the
%     option list was wrong in both directions (PV-110).
%
%   ACCURACY
%     Exact: a name is declared or it is not, and a destination exists
%     or it does not. Nothing here is approximate.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestE1c");
%
%   LIMITATIONS
%     Names and routing only. That a translated option produces the same
%     PICTURE v1 produced is not asserted anywhere and could not be:
%     v1 is the thing being replaced, and half the point of replacing it
%     is that several of its pictures were wrong.
%
%   See also GEO.INTERNAL.V1OPTIONS, GEO.INTERNAL.V1OPTIONTABLE, GEO.V1.IMAGESC.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.internal.v1Options" ...
                            "geo.internal.v1OptionTable" "geo.v1.imagesc"]
    end

    methods (Access = private)

        function names = v1Declares(tc)
            %V1DECLARES  geoImagesc's own option list, from its source.
            f = fullfile("C:\Users\matth\Documents\MATLAB\maptoolbox_v1", ...
                "maptoolbox", "geoImagesc.m");
            tc.assumeTrue(isfile(f), ...
                ['v1 tree absent, so oracle O12 is unreachable. Normal ' ...
                 'on CI and a breach of OB-7 anywhere else. Filtered.']);
            names = unique(string(regexp(fileread(f), ...
                '(?m)^\s*options\.([A-Za-z]\w*)', 'tokens')));
        end

        function opts = v2Options(~, fn)
            %V2OPTIONS  A v2 function's own option list, from its source.
            txt = string(splitlines(fileread(which(fn))));
            i = find(strtrim(txt) == "arguments", 1);
            j = find(strtrim(txt) == "end" & (1:numel(txt))' > i, 1);
            opts = unique(string(regexp(strjoin(txt(i:j), newline), ...
                'options\.([A-Za-z]\w*)', 'tokens')));
        end

        function G = worldGrid(~)
            lon = -180:4:180;
            lat = -90:4:90;
            G = geo.grid(lon, lat, repmat(sind(lat(:)), 1, numel(lon)) * 50);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function everyV1OptionIsInTheTableExactlyOnce(tc)
            declared = tc.v1Declares();
            T = geo.internal.v1OptionTable();
            listed = [T.V1];
            tc.verifyEqual(numel(listed), numel(unique(listed)), ...
                'a name listed twice would have two destinations');
            tc.verifyEmpty(setdiff(declared, listed), ...
                "declared by v1 and missing from the table: " + ...
                strjoin(setdiff(declared, listed), ", "));
            tc.verifyEmpty(setdiff(listed, declared), ...
                "in the table and not declared by v1: " + ...
                strjoin(setdiff(listed, declared), ", "));
        end

        function everyDestinationActuallyExists(tc)
            % The claim a hand-written rename table cannot make. A row
            % naming an option that no longer exists would translate a
            % v1 script into an argument error.
            owner = dictionary( ...
                "Basemap", "geo.basemap", "Graticule", "geo.graticule", ...
                "Coastline", "geo.coastline", "Rivers", "geo.coastline", ...
                "Region", "geo.coastline", "Contours", "geo.overlayContours", ...
                "Points", "geo.overlayPoints", "Frame", "geo.frame", ...
                "Colorbar", "geo.colorbar", "ScaleBar", "geo.scalebar", ...
                "NorthArrow", "geo.northarrow", "Inset", "geo.inset");
            T = geo.internal.v1OptionTable();
            for row = T
                if ~any(row.Kind == ["opt" "merge"]), continue, end
                have = tc.v2Options(owner(row.Target));
                tc.verifyTrue(any(have == row.Option), ...
                    row.V1 + " -> " + owner(row.Target) + "(" + ...
                    row.Option + "), which does not exist");
            end
        end

        function everyMapAndCrsDestinationExists(tc)
            T = geo.internal.v1OptionTable();
            mapOpts = tc.v2Options("geo.map");
            crsOpts = [tc.v2Options("geo.crs"), "name"];
            for row = T
                switch row.Kind
                    case "map"
                        tc.verifyTrue(any(mapOpts == row.Option), ...
                            row.V1 + " -> geo.map(" + row.Option + ")");
                    case "crs"
                        tc.verifyTrue(any(crsOpts == row.Option), ...
                            row.V1 + " -> geo.crs(" + row.Option + ")");
                end
            end
        end

        function everyToggleNamesAGeoMapOption(tc)
            T = geo.internal.v1OptionTable();
            mapOpts = tc.v2Options("geo.map");
            for row = T
                if ~any(row.Kind == ["toggle" "data"]), continue, end
                tc.verifyTrue(any(mapOpts == row.Target), ...
                    row.V1 + " toggles geo.map(" + row.Target + ")");
            end
        end

        function everyNoEquivalentSaysWhatToDoInstead(tc)
            % An error that only says "not supported" leaves the reader
            % where they started. Each of these names its replacement.
            T = geo.internal.v1OptionTable();
            none = T([T.Kind] == "none");
            tc.verifyGreaterThan(numel(none), 0);
            for row = none
                tc.verifyGreaterThan(strlength(row.Note), 40, ...
                    row.V1 + " has no explanation worth the name");
                tc.verifyError(@() geo.internal.v1Options({char(row.V1), 1}), ...
                    'geo:v1Options:NoEquivalent', row.V1);
            end
        end

        function noV1OptionIsSilentlyIgnored(tc)
            % THE V9 ASSERTION. Feed every declared name in on its own
            % and require each to either appear in the translation or
            % raise. Nothing may pass through unmentioned.
            declared = tc.v1Declares();
            T = geo.internal.v1OptionTable();
            % NOT declared', and the transpose was a real bug: a FOR over
            % a COLUMN runs once with the whole column as the loop
            % variable, so [T.V1] == name broadcast to 120x120 and the
            % test errored instead of checking 120 names.
            for name = reshape(declared, 1, [])
                row = T([T.V1] == name);
                if row.Kind == "none"
                    tc.verifyError(@() geo.internal.v1Options({char(name), 1}), ...
                        'geo:v1Options:NoEquivalent', name);
                    continue
                end
                nv = geo.internal.v1Options({char(name), sampleFor(row)});
                tc.verifyNotEmpty(nv, name + " translated to nothing");
            end
        end

        function anUnknownNameIsPassedThroughNotRejected(tc)
            % v2's own spellings must survive, so a script can be
            % migrated a line at a time.
            nv = geo.internal.v1Options({'Colorbar', false, 'Graticule', false});
            tc.verifyEqual(numel(nv), 4);
            tc.verifyTrue(any(string(nv(1:2:end)) == "Colorbar"));
        end

        function anOddListIsRejected(tc)
            tc.verifyError(@() geo.internal.v1Options({'Title'}), ...
                'geo:v1Options:OddArguments');
            tc.verifyError(@() geo.v1.imagesc(1:3, 1:3, zeros(3), 'Title'), ...
                'geo:v1:imagesc:NoOptions');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function theSixProjectionOptionsBecomeOneValidatedCrs(tc)
            % v1 took these six loose and checked their agreement
            % nowhere. Here they are gathered into one geo.crs, which
            % validates them together - so a conic without a standard
            % parallel is caught at translation rather than drawn.
            nv = geo.internal.v1Options({'Projection', 'lambertconformal', ...
                'StandardParallel', 30, 'StandardParallel2', 60, ...
                'CenterLongitude', -100});
            s = struct(nv{:});
            tc.verifyEqual(s.CRS.Name, "lambertconformal");
            tc.verifyEqual(s.CRS.StandardParallel, 30);
            tc.verifyEqual(s.CRS.CenterLongitude, -100);
            tc.verifyFalse(isnan(s.CRS.ConeConstant), ...
                'the cone constant is computed once, at construction');
            tc.verifyError(@() geo.internal.v1Options({'Projection', ...
                'lambertconformal'}), 'geo:crs:MissingParallel');
        end

        function twoV1ColoursBecomeTwoRowsOfOneMatrix(tc)
            % The case a rename table cannot express. Setting one colour
            % must leave the other at its default, not at zero.
            nvA = geo.internal.v1Options({'NorthArrowColor1', [1 0 0]});
            a = struct(nvA{:});
            tc.verifyEqual(a.NorthArrow.Colors(1, :), [1 0 0]);
            tc.verifyEqual(a.NorthArrow.Colors(2, :), [0 0 0], ...
                'the untouched row keeps the element''s default');
            nvB = geo.internal.v1Options({'NorthArrowColor1', [1 0 0], ...
                'NorthArrowColor2', [0 0 1]});
            b = struct(nvB{:});
            tc.verifyEqual(b.NorthArrow.Colors, [1 0 0; 0 0 1]);
        end

        function optionsForOneElementAccumulate(tc)
            % Written with a struct assignment this dropped everything
            % set before it, which is the exact failure the layer exists
            % to prevent.
            nvS = geo.internal.v1Options({'GraticuleColor', [0 0 0], ...
                'GraticuleStepLon', 60, 'GraticuleLabels', false});
            s = struct(nvS{:});
            tc.verifyEqual(s.Graticule.Color, [0 0 0]);
            tc.verifyEqual(s.Graticule.StepLon, 60);
            tc.verifyFalse(s.Graticule.Labels);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aV1CallDrawsAV2Map(tc)
            % The whole point, end to end: v1's line, v1's spellings,
            % v2's elements.
            H = geo.v1.imagesc(-180:4:180, -90:4:90, ...
                repmat(sind(-90:4:90)', 1, 91) * 50, ...
                'Projection', 'mollweide', 'CenterLongitude', 30, ...
                'ShowColorbar', true, 'ColorbarLabel', 'cm/yr', ...
                'GraticuleStepLon', 60, 'Coastlines', false, ...
                'NorthArrow', true, 'NorthArrowColor1', [1 0 0], ...
                'Title', 'v1 spelling');
            tc.addTeardown(@() close(H.Figure));
            tc.verifyEqual(H.CRS.Name, "mollweide");
            tc.verifyEqual(H.CRS.CenterLongitude, 30);
            tc.verifyFalse(isfield(H, 'Coastline'), 'Coastlines = false');
            tc.verifyEqual(H.Graticule.LonTicks, -120:60:180);
            tc.verifyEqual(H.NorthArrow.Patches(1).FaceColor, [1 0 0]);
        end

        function theProjectionReachesTheMapFromAnOptionToo(tc)
            % Regression. geo.map read CRS = ... only in the raw-triplet
            % form, so geo.map(G, CRS = c) drew in the DEFAULT
            % projection without complaint - and that is the shape the
            % translator produces, because v1 spelled the projection as
            % an option rather than an argument.
            H = geo.map(tc.worldGrid(), CRS = geo.crs("mollweide"), ...
                Colorbar = false);
            tc.addTeardown(@() close(H.Figure));
            tc.verifyEqual(H.CRS.Name, "mollweide");
        end

        function anEmptyOptionListIsAPlainMap(tc)
            nv = geo.internal.v1Options({});
            tc.verifyEmpty(nv);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function theOrderOfV1OptionsDoesNotMatter(tc)
            nv1 = geo.internal.v1Options({'GraticuleColor', [0 0 0], ...
                'ShowColorbar', false, 'NorthArrowColor1', [1 0 0]});
            nv2 = geo.internal.v1Options({'NorthArrowColor1', [1 0 0], ...
                'GraticuleColor', [0 0 0], 'ShowColorbar', false});
            a = struct(nv1{:});
            b = struct(nv2{:});
            tc.verifyEqual(sort(string(fieldnames(b))), ...
                sort(string(fieldnames(a))));
            tc.verifyEqual(b.Graticule, a.Graticule);
            tc.verifyEqual(b.NorthArrow, a.NorthArrow);
        end

        function translatingTwiceChangesNothing(tc)
            args = {'GraticuleStepLon', 60, 'ShowColorbar', false};
            once = geo.internal.v1Options(args);
            twice = geo.internal.v1Options(once);
            tc.verifyEqual(struct(twice{:}), struct(once{:}), ...
                ['a translated list contains only v2 names, which pass ' ...
                 'through - so the layer is idempotent']);
        end
    end
end

% ======================================================================
function v = sampleFor(row)
%SAMPLEFOR  A value the row will accept, for the round-trip check.
%   Only the NAME is under test here, so the value need only be
%   something the translator will carry rather than something the
%   element would accept.
%   The crs options are the exception: they are validated AT
%   TRANSLATION, because they are gathered into a geo.crs there, so they
%   need a value their validator accepts.
switch row.V1
    case "Projection",       v = "mollweide";
    case "Hemisphere",       v = "north";
    case {"StandardParallel", "StandardParallel2"}
                             v = 30;
    otherwise
        if row.Kind == "toggle"
            v = true;
        else
            v = 1;
        end
end
end
