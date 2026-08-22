classdef TestIntegration < GeoMapTestCase
%TESTINTEGRATION  Stage F: three scenarios that use the whole stack.
%
%   DESCRIPTION
%     Every other suite tests one function against its own contract.
%     These three run the toolbox the way a user does, end to end, and
%     each one is here because a specific class of failure is invisible
%     from inside a unit test.
%
%     ONE OF THEM MATTERS MORE THAN THE OTHER TWO. "Composed equals
%     front" builds the same map twice - once with GEO.MAP and once by
%     hand from GEO.BASEMAP plus elements in z-order - and requires
%     identical surface CData and identical colour limits. That is the
%     central guarantee of the whole architecture: the fronts add no
%     behaviour of their own, so anything you can do in one call you can
%     also do element by element, and the two are the same map. Without
%     it, "L4 orchestrates L3" is a diagram rather than a fact.
%
%     COVEREDFUNCTIONS IS DECLARED EMPTY, deliberately. These scenarios
%     cover no single function - that is what makes them integration
%     tests - and claiming one would mean promising all seven categories
%     for it here, where they belong in that function's own suite.
%
%     It was an OMISSION until A-5, and an omission cannot be told from
%     forgetting. An empty declaration says the same thing as a decision,
%     and the runner reports it as one.
%
%   ACCURACY
%     The composition guarantee is EXACT: isequal on CData, isequal on
%     clim. The exported file is checked for existence and a floor on
%     size, which is a smoke test and is labelled as one - there is no
%     automated oracle for "the figure is right", and pretending
%     otherwise would be worse than saying so.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestIntegration");
%
%   LIMITATIONS
%     The GRACE-style scenario uses a SYNTHETIC anomaly field. Checking
%     sign, magnitude and pattern against a published mascon product is
%     oracle O11, which needs a named release and its data file; that
%     debt is carried openly rather than faked with a plausible-looking
%     number.
%
%   See also GEO.MAP, GEO.BASEMAP, GEO.REGRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        % EMPTY ON PURPOSE - see DESCRIPTION. An integration scenario
        % covers a composition, not a function, and A-5 made the
        % difference between that decision and a forgotten declaration
        % something the runner can see.
        CoveredFunctions = strings(1, 0)
    end

    methods (Access = private)

        function G = ewhAnomaly(~)
            %EWHANOMALY  A synthetic signed field with the shape of one.
            %   Two negative lobes over Greenland and West Antarctica and
            %   a positive one over the Amazon - not a measurement, and
            %   not offered as one. It exists so the colour scale has a
            %   sign to be symmetric about and the stipple has something
            %   to be significant over.
            lon = -180:2:180;
            lat = -88:2:88;
            [LON, LAT] = meshgrid(lon, lat);
            blob = @(l0, b0, w, a) a * exp(-((LON - l0).^2 + ...
                (LAT - b0).^2) / (2 * w^2));
            Z = blob(-42, 72, 9, -18) + blob(-105, -78, 11, -22) + ...
                blob(-60, -5, 12, 14);
            G = geo.grid(lon, lat, Z, Units = "cm");
        end

        function S = significance(tc)
            %SIGNIFICANCE  A mask grid: where the anomaly exceeds 5 cm.
            G = tc.ewhAnomaly();
            S = geo.grid(G.Lon, G.Lat, double(abs(G.Z) > 5));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function thePackageClosureNeverLeavesThePackage(tc)
            % THE ONLY THING HERE THAT CI CANNOT SEE FOR ITSELF.
            % geoMapSetup puts tests/, tools/, records/ and docbuild/ on
            % the path, so a call from +geo into any of them resolves and
            % every suite passes. A user's path carries +geo, data and
            % docs/html; the same call is undefined for everyone who
            % installs it. Twice now: geo.readGrid reaching for
            % geoMapRoot (PV-115), and geo.cache calling sha256OfText out
            % of tools/ on the path that draws any coastline (PV-127),
            % which survived eleven checkpoints under a green gate.
            %
            % This asks MATLAB's own dependency analyser, so it sees a
            % call the audit's text scan cannot - including one to a file
            % outside the repository altogether. The audit's
            % packageClosure check reads the tree instead, because it
            % must be provable on a fixture; two instruments reading
            % differently is handover 2.9, not duplication.
            root = string(geoMapRoot());
            d = dir(fullfile(root, "+geo", "*.m"));
            entry = fullfile({d.folder}, {d.name});
            closure = string(matlab.codetools.requiredFilesAndProducts(entry));

            inPackage = contains(closure, fullfile(root, "+geo"));
            escaped = closure(~inPackage);
            tc.verifyEmpty(escaped, ...
                "+geo depends on files it does not ship: " + ...
                strjoin(erase(escaped, root + filesep), ", "));

            % HALF A CHECK IS ONE THAT ONLY EVER PASSES. Point the same
            % predicate at a harness file and it must report an escape,
            % or "zero escaped" above would mean nothing.
            probe = string(matlab.codetools.requiredFilesAndProducts( ...
                fullfile(root, "tools", "makeManifest.m")));
            tc.verifyFalse(all(contains(probe, fullfile(root, "+geo"))), ...
                'the predicate must be able to see a file outside +geo');
        end

        function drawingNeedsNothingButBaseMatlab(tc)
            % The headline claim of the toolbox, asserted rather than
            % repeated. Parallel Computing Toolbox is the one permitted
            % entry and it is OPTIONAL: geo.export reaches parfeval only
            % behind geo.internal.hasParallelPool, which probes for the
            % pool instead of trusting exist('parfeval','file') - that
            % test was true on CI with no toolbox installed, so the guard
            % passed and gcp then failed (PV-123).
            root = string(geoMapRoot());
            d = dir(fullfile(root, "+geo", "*.m"));
            entry = fullfile({d.folder}, {d.name});
            [~, prods] = matlab.codetools.requiredFilesAndProducts(entry);
            names = string({prods.Name});

            unexpected = setdiff(names, ["MATLAB" "Parallel Computing Toolbox"]);
            tc.verifyEmpty(unexpected, ...
                "no-toolbox claim broken by: " + strjoin(unexpected, ", "));
            tc.verifyTrue(any(names == "MATLAB"), ...
                'a closure that needs no MATLAB is a closure that was not computed');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function composedEqualsFront(tc)
            % THE CENTRAL GUARANTEE. If this fails, "L4 orchestrates L3"
            % is a diagram and not a fact.
            G = tc.ewhAnomaly();
            crs = geo.crs("mollweide");

            H = geo.map(G, crs, Colorbar = false, ScaleBar = false);
            tc.addTeardown(@() close(H.Figure));

            [f2, ax2, base2] = geo.basemap(G, crs);
            tc.addTeardown(@() close(f2));
            geo.graticule(ax2, crs, FontName = "Helvetica", FontSize = 9);
            geo.coastline(ax2, crs);
            geo.frame(ax2, crs);

            tc.verifyTrue(isequal(base2.Surface.CData, ...
                H.Basemap.Surface.CData), ...
                'one call and element by element must give the same colours');
            tc.verifyEqual(clim(ax2), clim(H.Axes), ...
                'and the same colour limits');
            tc.verifyEqual(sort(geo.internal.layout("kinds", f2)), ...
                sort(geo.internal.layout("kinds", H.Figure)), ...
                'and the same elements registered');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aGraceStyleFigureExportsAPdf(tc)
            % A smoke test, and labelled as one: it proves the whole
            % stack runs together and writes a real file. It does not
            % prove the figure is right, and nothing automated can.
            tc.suppressWarning('MATLAB:graphics:HardwareUnavailable');
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            file = fullfile(d, "grace.pdf");

            G = tc.ewhAnomaly();
            H = geo.map(G, geo.crs("mollweide"), ...
                Basemap = struct('ColormapName', "divergent", ...
                                 'CLim', [-25 25]), ...
                Stipple = struct('G', tc.significance(), 'Density', 8), ...
                Colorbar = struct('Style', "gmt", 'Label', "EWH (cm)"), ...
                Title = "Equivalent water height anomaly", ...
                Export = file, ...
                ExportOptions = struct('Width', 17, 'Resolution', 200));
            tc.addTeardown(@() close(H.Figure));

            tc.verifyTrue(isfile(file), 'the export must write a file');
            info = dir(file);
            tc.verifyGreaterThan(info.bytes, 10e3, ...
                'a PDF under 10 kB has no map in it');
            for kind = ["Basemap" "Graticule" "Coastline" "Stipple" ...
                        "Frame" "Colorbar" "Title"]
                tc.verifyTrue(isfield(H, kind), ...
                    kind + " is missing from the figure");
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function serialEqualsParallel(tc)
            % The parallel path must be an optimisation, not a variant.
            % Filtered rather than skipped where there is no pool: a
            % test that cannot run says so.
            % PROBED, not read off the file system. Written as
            % exist('parfeval','file') > 0 && ~isempty(gcp('nocreate')),
            % this ERRORED on CI rather than filtering: exist returned
            % true where gcp does not exist, so the short circuit never
            % fired and the guard called a function that is not there
            % (PV-123).
            % A-6 / PV-133: this asked hasParallelPool(TRUE), which
            % demands a pool ALREADY OPEN. Every fresh session has none,
            % so the test filtered on machines that have the toolbox -
            % including the bridge, where R-023 had already proved the
            % path with 16 workers. The condition is meant to be "no
            % Parallel Computing Toolbox", not "nobody has started a
            % pool yet", so the toolbox is probed and the pool is
            % STARTED here when it is absent.
            [hasPct, why] = geo.internal.hasParallelPool(false);
            if ~hasPct
                tc.filterBecause("geo:filter:noParallelPool", ...
                    why + " The parallel export path is unreachable " + ...
                    "here, so this is filtered rather than passed - " + ...
                    "geoMap needs base MATLAB only and the pool is an " + ...
                    "option, never a requirement.");
            end
            if isempty(gcp('nocreate'))
                try
                    parpool();
                catch startErr
                    % A DISTINCT reason, deliberately. The toolbox is
                    % here and the pool would not start - a cluster
                    % profile can fail at connection time, which no
                    % probe can foresee (see GEO.INTERNAL.HASPARALLELPOOL).
                    % Collapsing that into "no toolbox" would hide a
                    % broken profile behind an expected filter.
                    % A SECOND registered reason, deliberately. Routing
                    % both exits through one id would hide a broken
                    % cluster profile behind an expected filter, which is
                    % the distinction the comment above exists to keep.
                    tc.filterBecause("geo:filter:parallelPoolWouldNotStart", ...
                        "Parallel Computing Toolbox is present but no " + ...
                        "pool could be started (" + startErr.identifier + ...
                        "). Filtered, not passed - and this is NOT the " + ...
                        "same condition as an absent toolbox.");
                end
                tc.addTeardown(@() delete(gcp('nocreate')));
            end
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            builders = {@() figure('Visible', 'off', 'Color', [1 0 0]), ...
                        @() figure('Visible', 'off', 'Color', [0 0 1])};
            files = fullfile(d, ["a.png" "b.png"]);
            other = fullfile(d, ["c.png" "d.png"]);

            a = geo.export(builders, files, Width = 6, Resolution = 100, ...
                UseParallel = "never");
            b = geo.export(builders, other, Width = 6, Resolution = 100, ...
                UseParallel = "always");
            tc.verifyTrue(b.Parallel, 'the parallel path must have run');
            tc.verifyEqual(b.Method, a.Method);
            tc.verifyEqual(b.Height, a.Height, AbsTol = 1e-12);
            for k = 1:2
                tc.verifyTrue(isequal(imread(other(k)), imread(files(k))), ...
                    "worker " + k + " wrote a different image");
            end
        end
    end
end
