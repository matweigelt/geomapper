classdef GeoMapTestCase < matlab.unittest.TestCase
%GEOMAPTESTCASE  Shared base class for every geoMap v2 test suite.
%
%   DESCRIPTION
%     Provides the fixtures, tolerances and instruments that every suite in
%     the toolbox shares, so that no suite grows its own. In particular it
%     owns ASSERTRATIOBUDGET, the project's ONLY timing instrument.
%
%     Why one timing helper: before consolidation, one reference project
%     carried eleven near-copies of a local median helper plus two bespoke
%     pairing helpers - thirteen places, which is thirteen chances for the
%     next repair to be applied twelve times. This class is delivered in
%     Stage 0, before the first function, because no speed budget may be
%     written before its instrument exists (handover D-004).
%
%   FIXTURES
%     Every test runs after rng(42,'twister'). Figures come from
%     figureFor(), which closes them on teardown. CRS fixtures are lazy:
%     they construct on first access and fail with a clear message if the
%     +geo package is not yet on the path, so this class is usable in
%     Stage 0 before geo.crs exists.
%
%   TOLERANCES
%     Constants, so a suite cannot quietly widen one. A tolerance is a
%     claim about which error dominates; loosening one to make a test pass
%     is a finding, not a repair.
%
%   ACCURACY
%     assertRatioBudget recovers a constructed ratio to within 10% across
%     its default repeat count. 10% is chosen because the source
%     measurement of repeat-count spread reads 10.2% at 15 repeats
%     (BEST_PRACTICE 3.4.6); a tighter figure would assert below the
%     instrument's own noise. Verified in TestStage0_instruments.
%
%   ERRORS
%     Fixture availability:
%       geo:test:PackageNotOnPath   - a geo.* fixture was requested but
%                                     the +geo package is not visible
%       geo:test:MirrorMissing      - the mirror reference JSON is absent
%       geo:test:MirrorKeyMissing   - the requested key is not in the JSON
%     Unmeasured quantities:
%       geo:test:ToleranceNotMeasured - TolMass requested before the
%                                     mirror has measured it (debt V7)
%
%   EXAMPLE
%     classdef TestMyThing < GeoMapTestCase
%         properties (Constant)
%             CoveredFunctions = "geo.project"
%         end
%         methods (Test, TestTags = {'contract'})
%             function nanPropagates(tc)
%                 tc.verifyTrue(isnan(geo.project(NaN, 0, tc.crsEq)));
%             end
%         end
%     end
%
%   See also RUNGEOMAPTESTS, GEOMAPTESTRECORD.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        % Round-trip forward->inverse, degrees. Measured in the mirror at
        % <= 4e-12 for 13 of 16 projections (RECORDS R-002).
        TolRoundTrip = 1e-9

        % Lambert azimuthal equal-area only: asin conditioning at the
        % antipodal rim measured 4.6e-9 in the mirror (finding PV-010).
        TolRoundTripLambert = 1e-8

        % Global quad-integral equal-area check. Mirror measured
        % 2.5e-5 .. 9.8e-5 at 1-degree quads, so this holds with headroom.
        TolArea = 1e-3

        % Geometric assertions on graphics objects.
        TolGeom = 1e-6

        % Analytic scale-factor invariants. Mirror measured 5.1e-9 .. 9.4e-8.
        TolScale = 1e-6

        % Agreement with oracle O4 (pyproj/PROJ) in projected units.
        % Robinson is excluded: PROJ uses a different interpolant for the
        % Robinson table and agrees only to 8.9e-4 (mirror limit L5).
        TolOracle = 1e-11
        TolOracleRobinson = 1e-3

        % Auto inner-batch threshold: below this, a single call is timing
        % the timer rather than the work.
        MinTimedSeconds = 1e-3
    end

    properties (Access = private)
        MirrorRefCache = []
        CrsCache = struct()
    end

    methods (TestMethodSetup)
        function seedRandom(~)
            % Seeded per test, not per suite: a test must not inherit the
            % random state left by whichever test happened to run before it.
            rng(42, 'twister');
        end
    end

    % ------------------------------------------------------------------
    % Fixtures
    % ------------------------------------------------------------------
    methods
        function f = figureFor(tc)
            %FIGUREFOR  Invisible figure, closed on teardown.
            f = figure('Visible', 'off', 'Color', 'w');
            tc.addTeardown(@() closeIfValid(f));
        end

        function verifyIsAPureFront(tc, fn)
            %VERIFYISAPUREFRONT  The Stage E rule, asserted on one file.
            %   A front declares itself and calls no drawing primitive.
            %   The audit enforces this on every push; asserting it here
            %   too puts the rule where a reader of the tests meets it.
            %
            %   HERE RATHER THAN IN FOUR SUITES. Four near-copies had
            %   accumulated - E1, E2, E3, E4 - and the duplicate-local
            %   check rejected the fourth, which is the SEVENTH time it
            %   has done that. Worse than the duplication: the copies had
            %   DRIFTED. E1's and E2's banned lists were shorter than
            %   E3's and E4's, so `geo.map` and the two data fronts were
            %   never checked for ylabel, xlabel, legend or sgtitle. One
            %   list, and every front is held to all of it.
            %
            %   COMMENTS ARE STRIPPED FIRST. Prose about a token is not
            %   the token, and this project has met that four times
            %   (PV-102, PV-117 and two before them).
            src = string(splitlines(fileread(which(fn))));
            tc.verifyTrue(any(strtrim(erase(src, "%")) == "L4-FRONT"), ...
                fn + " must declare itself an L4 front");
            code = regexprep(src, '%.*$', '');
            banned = ["surf" "surface" "patch" "line" "text" "scatter" ...
                      "scatter3" "plot" "plot3" "colorbar" "annotation" ...
                      "imagesc" "image" "fill" "contour" "contourf" ...
                      "rectangle" "quiver" "title" "xlabel" "ylabel" ...
                      "legend" "sgtitle"];
            for b = banned
                tc.verifyEmpty(find(~cellfun(@isempty, regexp(cellstr(code), ...
                    "(?<![\w.])" + b + "\s*\(", 'once')), 1), ...
                    "bare " + b + "() in " + fn);
            end
        end

        function H = keep(tc, H)
            %KEEP  Close a front's figure on teardown, and pass it on.
            %   Here rather than in two suites: the duplicate-local check
            %   rejected the second copy, which is the sixth time it has
            %   done that and the sixth time it was inside the checkpoint
            %   that wrote it.
            %
            %   BOTH PRIVATE COPIES WERE REMOVED, not just one. PV-099:
            %   a method promoted to this class while a suite still has a
            %   private one of the same name makes the framework DROP
            %   that suite for an access-permission mismatch, and report
            %   it as a warning. The suite would run smaller and still
            %   call itself green.
            tc.addTeardown(@() closeIfValid(H.Figure));
        end

        function G = demoGrid(~)
            %DEMOGRID  The 5-degree global field every Stage D suite draws.
            %   Here rather than in three suites: the duplicate-local
            %   check rejected the third copy, which is the same rule
            %   this class exists to enforce for fixtures.
            lon = -177.5:5:177.5;
            lat = (-87.5:5:87.5)';
            G = geo.grid(lon, lat, ...
                sind(3 * repmat(lon, numel(lat), 1)) .* ...
                cosd(2 * repmat(lat, 1, numel(lon))));
        end

        function ax = mapAxes(tc, crs)
            %MAPAXES  Fresh axes carrying a basemap, ready for an element.
            %   Here rather than in each Stage D suite: the third copy was
            %   rejected by the duplicate-local check, which is the rule
            %   this class exists to enforce for fixtures.
            arguments
                tc
                crs = "equirectangular"
            end
            ax = axes('Parent', tc.figureFor());
            geo.basemap(tc.demoGrid(), crs, Parent = ax, Hillshade = "off");
        end

        function verifyNoTextOverlap(tc, figH, label)
            %VERIFYNOTEXTOVERLAP  No two labels in a finished map collide.
            %   PV-152, and the reason it survived a whole release.
            %   EVERY other graphics assertion in this suite measures ONE
            %   element against its own claim: the tick at its exact
            %   fraction, the label anchor unprojecting to its own
            %   longitude, the title clearing by the fraction asked for.
            %   Not one compared two elements to each other - which is the
            %   one thing a finished map IS. Six pairs overlapped in the
            %   toolbox's own showcase call and 518 green points saw none.
            %
            %   Half a point of tolerance, because touching bounding boxes
            %   are not a collision: the reported extent carries a little
            %   side bearing, and two adjacent labels sharing an edge read
            %   perfectly well.
            arguments
                tc
                figH (1,1) matlab.ui.Figure
                label (1,1) string = "map"
            end
            drawnow
            t = findall(figH, 'Type', 'text');
            t = t(arrayfun(@(h) strlength(string(h.String)) > 0, t));
            r = geo.internal.textRects(reshape(t, 1, []));
            worst = 0;
            pair = "none";
            for i = 1:size(r, 1)
                for j = i + 1:size(r, 1)
                    if any(isnan(r(i, :))) || any(isnan(r(j, :)))
                        continue
                    end
                    ox = min(r(i,1) + r(i,3), r(j,1) + r(j,3)) ...
                         - max(r(i,1), r(j,1));
                    oy = min(r(i,2) + r(i,4), r(j,2) + r(j,4)) ...
                         - max(r(i,2), r(j,2));
                    if ox > 0.5 && oy > 0.5 && min(ox, oy) > worst
                        worst = min(ox, oy);
                        pair = string(t(i).String) + " / " + string(t(j).String);
                    end
                end
            end
            tc.verifyAndRecord(worst, 0.5, ...
                "worst text overlap, " + label + " [" + pair + "]", "points");
        end

        function suppressWarning(tc, id)
            %SUPPRESSWARNING  Disable an identifier for this test only.
            %   Restored by teardown, so a failing assertion cannot leave
            %   the warning state altered for the suites that follow.
            %   Do NOT call this where the identifier cannot fire: an
            %   unnecessary suppression teaches the next reader that the
            %   identifier is unavoidable.
            %
            %   LASTWARN IS RESTORED TOO, and that is not tidiness. A
            %   DISABLED WARNING STILL SETS LASTWARN - measured, not
            %   assumed - and the runner's warning inventory is built by
            %   reading lastwarn around each test method (the instrument
            %   PV-013 already recorded as approximate). So a test that
            %   provoked a documented warning on purpose and suppressed
            %   it exactly as handover 2.5 prescribes STILL failed the
            %   warning gate, with the identifier reported as new.
            %
            %   Found the first time any geoMap code raised a warning at
            %   all: geo:splitTracks:TracksDropped, at Stage A.3. The
            %   handover names that identifier in 2.5 as one tests will
            %   provoke, so the situation was anticipated and the
            %   prescribed mechanism did not cover it. Finding PV-043.
            %
            %   Restoring lastwarn is the honest repair rather than
            %   teaching the plugin to ignore identifiers: the test
            %   asked for this warning, handled it, and should leave the
            %   world as it found it. A warning nobody asked for still
            %   reaches the inventory and still fails the gate.
            arguments
                tc
                id (1,1) string
            end
            st = warning('off', id);
            [priorMsg, priorId] = lastwarn();
            tc.addTeardown(@() restoreWarningState(st, priorMsg, priorId));
        end

        function tf = canUseParallelPool(~)
            %CANUSEPARALLELPOOL  True only if a pool ALREADY exists.
            %   Never starts one. The Parallel Computing Toolbox is
            %   optional throughout geoMap and a test must not make it
            %   mandatory by side effect.
            tf = false;
            if exist('gcp', 'file') == 2
                try
                    tf = ~isempty(gcp('nocreate'));
                catch
                    tf = false;
                end
            end
        end

        function r = v1RootOrFilter(tc)
            %V1ROOTORFILTER  Where the v1 tree is, SEARCHED rather than asserted.
            %
            %   PV-148. This held one absolute path on one developer's
            %   machine - ...\maptoolbox_v1\maptoolbox - and the tree had
            %   moved to ...\maptoolbox. Four points filtered for four
            %   rounds on the strength of a stale string, and PV-129
            %   recorded the cause as "the v1 tree is gone from disk". It
            %   was not gone. Nobody looked, because the filter came with
            %   a reason that sounded like an explanation: "normal on CI
            %   and a breach of OB-7 anywhere else". A filter with a
            %   plausible message is a filter nobody investigates.
            %
            %   Searched now, in order: GEOMAP_V1_ROOT if it is set, then
            %   every sibling of the geoMap root and each sibling's own
            %   maptoolbox subfolder. GEOPROJECT.M is the marker because
            %   it is v1's and only v1's.
            r = "";
            cand = string.empty(1, 0);
            env = string(getenv("GEOMAP_V1_ROOT"));
            if strlength(env) > 0
                cand(end+1) = env;
            end
            parent = string(fileparts(geoMapRoot()));
            d = dir(parent);
            d = d([d.isdir] & ~startsWith(string({d.name}), "."));
            for k = 1:numel(d)
                here = string(fullfile(parent, d(k).name));
                cand(end+1) = here;                          %#ok<AGROW>
                cand(end+1) = fullfile(here, "maptoolbox");   %#ok<AGROW>
            end
            for c = cand
                if isfile(fullfile(c, "geoProject.m"))
                    r = c;
                    return
                end
            end
            tc.filterBecause("geo:filter:v1TreeAbsent", sprintf( ...
                ['v1 tree absent, so oracle O12 is unreachable. ' ...
                 'Searched %d candidate folders under "%s" for ' ...
                 'geoProject.m, and GEOMAP_V1_ROOT is %s. Normal on ' ...
                 'CI and a breach of OB-7 anywhere else. Filtered, ' ...
                 'not passed.'], numel(cand), parent, ...
                 tc.envText(env)));
        end

        function s = envText(~, env)
            %ENVTEXT  The environment override, or the word for its absence.
            if strlength(env) > 0
                s = env;
            else
                s = "unset";
            end
        end

        function filterBecause(tc, id, why)
            %FILTERBECAUSE  Filter this point, naming a REGISTERED reason.
            %   The only door out of a test that is not a pass and not a
            %   failure. Audit finding A-1: the gate had no idea how much
            %   of the suite ran, and 42 of 491 points could vanish with
            %   GREEN GATE still printed. A count would have been an
            %   absolute figure with no baseline - the thing 3.4.1 threw
            %   out for all nineteen speed budgets, and a bound that
            %   permits silent drift up to itself.
            %
            %   So the reason is inventoried instead of the number. The
            %   warning raised here reaches WARNINGINVENTORYPLUGIN, which
            %   already fails the gate on any identifier not on its
            %   allow-list; RUNGEOMAPTESTS extends that list with the ids
            %   registered in tests/FILTERS.md. An unregistered reason is
            %   therefore red on arrival, in the same way a new warning
            %   is, and nothing new had to be added to the gate.
            %
            %   That a warning raised immediately before ASSUMEFAIL is
            %   still in LASTWARN once the framework has caught the
            %   AssumptionFailedException is a claim about MATLAB, not
            %   about this code. It was MEASURED before this was written:
            %   probe A-1b, CI run 32494985310, inventory held both the
            %   filtered test's identifier and a passing test's.
            %
            %   id   (1,1) string  Reason id, must begin "geo:filter:".
            %   why  (1,1) string  What is absent, and what it costs.
            id = string(id);
            if ~startsWith(id, "geo:filter:")
                error('geo:test:BadFilterId', ...
                    ['"%s" is not a filter reason. A filter id begins ' ...
                     '"geo:filter:" and is registered in ' ...
                     'tests/FILTERS.md with what closes it.'], id);
            end
            warning(char(id), '%s', char(why));
            tc.assumeFail(sprintf('[%s] %s', id, why));
        end

        function assumeSpeedTestsEnabled(tc)
            %ASSUMESPEEDTESTSENABLED  Filter speed tiers on request.
            if ~isempty(getenv('GEOMAP_SKIP_SPEED'))
                tc.filterBecause("geo:filter:speedTierOff", ...
                    ['GEOMAP_SKIP_SPEED is set, so this budget was not ' ...
                     'measured. Use rungeoMapTests("default") to run ' ...
                     'the correctness tiers alone; "all" with the ' ...
                     'switch set asks for the speed tier and then ' ...
                     'refuses to run it.']);
            end
        end

        function tol = TolMass(tc)
            %TOLMASS  Conservative-regrid mass-closure tolerance.
            %   Deliberately a method, not a constant: this number must be
            %   MEASURED by the mirror at production grid size, not
            %   guessed. Handover debt V7 is open, so it errors rather
            %   than returning a plausible default.
            % A missing mirror FILE and a missing KEY mean the same
            % thing to this caller: the number has not been measured.
            % Reporting MirrorMissing leaked an implementation detail
            % and made the contract untestable whenever the mirror had
            % not been transferred (finding PV-018).
            try
                ref = tc.loadMirrorReference("regrid_mass_closure_floor", false);
            catch
                ref = [];
            end
            if isempty(ref) || ~isfield(ref, 'tolerance')
                error('geo:test:ToleranceNotMeasured', ...
                    ['TolMass has not been measured. The mirror must ' ...
                     'measure the achievable double-precision mass-closure ' ...
                     'floor at production grid size (handover debt V7) ' ...
                     'before any test asserts it.']);
            end
            % Read the TOLERANCE, not the floor. They are different
            % numbers on purpose: the floor measured at 2161x4321 ->
            % 181x361 over the worst of three summation orders is
            % 2.15e-14, and the asserted tolerance sits one decade above
            % it. A tolerance set exactly at the floor fails on the first
            % machine whose BLAS blocks a reduction differently, and that
            % failure would carry no information about the code.
            tol = ref.tolerance;
        end

        function v = loadMirrorReference(tc, key, required)
            %LOADMIRRORREFERENCE  Read a measured value from the mirror.
            %   No number this project asserts may come from the handover
            %   document; it comes from here, where it was measured.
            arguments
                tc
                key (1,1) string
                required (1,1) logical = true
            end
            if isempty(tc.MirrorRefCache)
                p = fullfile(geoMapRoot(), 'mirror', 'geomap_mirror', ...
                             'out', 'reference_values.json');
                if exist(p, 'file') ~= 2
                    error('geo:test:MirrorMissing', ...
                        ['Mirror reference file not found at %s. Run ' ...
                         '"python -m geomap_mirror.references" first.'], p);
                end
                tc.MirrorRefCache = jsondecode(fileread(p));
            end
            vals = tc.MirrorRefCache.values;
            fname = matlab.lang.makeValidName(key);
            if isfield(vals, fname)
                v = vals.(fname);
            elseif required
                error('geo:test:MirrorKeyMissing', ...
                    'Mirror reference has no key "%s".', key);
            else
                v = [];
            end
        end
    end

    % ------------------------------------------------------------------
    % Lazy CRS fixtures
    % ------------------------------------------------------------------
    methods
        function c = crsEq(tc),          c = tc.getCrs("equirectangular"); end
        function c = crsMercator(tc),    c = tc.getCrs("mercator");        end
        function c = crsMollweide(tc),   c = tc.getCrs("mollweide");       end
        function c = crsRobinson(tc),    c = tc.getCrs("robinson");        end
        function c = crsHammer(tc),      c = tc.getCrs("hammer");          end

        function c = crsLcc3345(tc)
            c = tc.getCrs("lambertconformal", ...
                {'CenterLongitude', -96, 'CenterLatitude', 23, ...
                 'StandardParallel', 33, 'StandardParallel2', 45});
        end

        function c = crsPolarNorth(tc)
            c = tc.getCrs("polarstereographic", ...
                {'Hemisphere', "north", 'StandardParallel', 71});
        end
    end

    methods (Access = private)
        function c = getCrs(tc, name, args)
            arguments
                tc
                name (1,1) string
                args cell = {}
            end
            key = matlab.lang.makeValidName(name + string(numel(args)));
            if isfield(tc.CrsCache, key)
                c = tc.CrsCache.(key);
                return
            end
            if exist('geo.crs', 'file') ~= 2 && isempty(which('geo.crs'))
                error('geo:test:PackageNotOnPath', ...
                    ['geo.crs is not visible. Add the toolbox root to the ' ...
                     'MATLAB path, or run this suite through ' ...
                     'rungeoMapTests, which does it for you. (Stage 0 ' ...
                     'suites do not need a CRS and should not request one.)']);
            end
            c = geo.crs(name, args{:});
            tc.CrsCache.(key) = c;
        end
    end

    % ------------------------------------------------------------------
    % Instruments
    % ------------------------------------------------------------------
    methods
        function rec = verifyAndRecord(tc, actual, bound, label, units, cmp)
            %VERIFYANDRECORD  Qualify a bound AND leave the number behind.
            %   An assertion that passes leaves no trace, so a report goes
            %   silent about exactly the measurements that went well. This
            %   makes it impossible to assert without logging.
            arguments
                tc
                actual (1,1) double
                bound (1,1) double
                label (1,1) string
                units (1,1) string = ""
                cmp (1,1) string {mustBeMember(cmp, ["<=" ">=" "<" ">"])} = "<="
            end
            rec = struct('kind', "value", 'label', label, ...
                'actual', actual, 'bound', bound, 'cmp', cmp, ...
                'units', units, 'machine', geoMapMachineTag());
            geoMapTestRecord('add', rec);
            switch cmp
                case "<=", tc.verifyLessThanOrEqual(actual, bound, label);
                case "<",  tc.verifyLessThan(actual, bound, label);
                case ">=", tc.verifyGreaterThanOrEqual(actual, bound, label);
                case ">",  tc.verifyGreaterThan(actual, bound, label);
            end
        end

        function rec = assertRatioBudget(tc, fcnA, fcnB, budget, expected, ...
                                         label, opts)
            %ASSERTRATIOBUDGET  The project's only timing instrument.
            %
            %   Asserts median( cost(fcnA)/cost(fcnB) ) <= budget, where
            %   both costs are measured INSIDE one repeat, with the order
            %   rotated between repeats.
            %
            %   Why not an absolute figure: an absolute budget with no
            %   baseline cannot detect the change it was written for. One
            %   reference project shipped a 1.30x regression behind one,
            %   and a sub-millisecond absolute row swung 6.8x across three
            %   runs on code nobody had touched.
            %
            %   Why paired inside one repeat: timing A to completion and
            %   only then timing B puts them in different windows, so
            %   everything that drifts across a window - thermal
            %   throttling, allocator state, the page cache - lands
            %   entirely on the later one. A median over repeats cannot
            %   remove it: a median removes a slow repeat INSIDE one
            %   window and is blind to a monotone drift BETWEEN them.
            %   Measured in a reference project: a ratio read 8.298 inside
            %   the full runner against 4.81/5.11/5.34/5.43/5.54 for the
            %   same binary run alone, five times out of five, on a budget
            %   of 8.
            %
            %   Why rotation: timing the same point first leaves a small,
            %   non-zero, always-identically-signed bias.
            %
            %   INPUTS
            %     fcnA     (1,1) function_handle  Numerator, no arguments.
            %     fcnB     (1,1) function_handle  Denominator (baseline).
            %     budget   (1,1) double           Asserted upper bound.
            %     expected (1,1) double           Predicted ratio; NaN if
            %                                     none. Logged, never
            %                                     asserted - it is the
            %                                     margin the next reader
            %                                     sees without re-deriving.
            %     label    (1,1) string           Must state N.
            %
            %   OPTIONS
            %     Repeats    (1,1) double  [auto]  Rounded UP to a multiple
            %                                      of 2, so rotation is
            %                                      balanced. Default 16
            %                                      (see NOTES).
            %     InnerBatch (1,1) double  [auto]  Calls per timed sample.
            %     Weak       (1,1) logical [false] Marks a budget whose
            %                                      evidence is weak
            %                                      (graphics). Reported
            %                                      separately.
            %     Direction  (1,1) string  ["<="]  Use ">=" for a budget
            %                                      that asserts a speedup.
            %
            %   OUTPUTS
            %     rec  (1,1) struct  ratio, band, absolutes, batch, machine.
            %
            %   NOTES
            %     The source guidance says "use 15 repeats" (spread over 10
            %     trials: 5 -> 31.2%, 9 -> 14.0%, 15 -> 10.2%, 21 -> 4.4%)
            %     AND "prefer a repeat count that is a multiple of the
            %     number of points". With two points those conflict: 15 is
            %     odd, so one point is timed first eight times and the
            %     other seven. Resolved in favour of balanced rotation, at
            %     16 - the smallest multiple of 2 not below 15. Recorded as
            %     finding PV-012.
            %
            %     A threshold does not move as part of an instrument
            %     repair. If this instrument reads differently from a
            %     hand-rolled one, that difference is a finding recorded
            %     with its measurement, never absorbed by widening budget.
            arguments
                tc
                fcnA (1,1) function_handle
                fcnB (1,1) function_handle
                budget (1,1) double
                expected (1,1) double
                label (1,1) string
                opts.Repeats (1,1) double {mustBePositive} = 16
                opts.InnerBatch (1,1) double = NaN
                opts.Weak (1,1) logical = false
                opts.Direction (1,1) string ...
                    {mustBeMember(opts.Direction, ["<=" ">="])} = "<="
            end

            nRep = 2 * ceil(opts.Repeats / 2);   % balanced rotation

            % Untimed warm-up: first calls pay JIT and allocation costs
            % that belong to neither point.
            fcnA(); fcnB();

            nb = opts.InnerBatch;
            if isnan(nb)
                nb = autoInnerBatch(fcnA, fcnB, tc.MinTimedSeconds);
            end

            tA = zeros(1, nRep);
            tB = zeros(1, nRep);
            for r = 1:nRep
                if mod(r, 2) == 1
                    tA(r) = timeBatch(fcnA, nb);
                    tB(r) = timeBatch(fcnB, nb);
                else
                    tB(r) = timeBatch(fcnB, nb);
                    tA(r) = timeBatch(fcnA, nb);
                end
            end

            % Statistic per repeat, then the median of those - never a
            % ratio of medians. The arithmetic lives in a static method so
            % it can be proven on a synthetic drifting sequence without
            % timing anything (see TestStage0_instruments).
            [ratio, band] = GeoMapTestCase.ratioStatistic(tA, tB);

            rec = struct('kind', "ratio", 'label', label, ...
                'ratio', ratio, 'band', band, 'budget', budget, ...
                'expected', expected, 'repeats', nRep, 'innerBatch', nb, ...
                'medianAbsA', median(tA), 'medianAbsB', median(tB), ...
                'weak', opts.Weak, 'direction', opts.Direction, ...
                'machine', geoMapMachineTag());
            geoMapTestRecord('add', rec);

            msg = sprintf(['%s\n    ratio %.4g %s budget %.4g ' ...
                '(expected %.4g)\n    per-repeat band %.4g .. %.4g ' ...
                'over %d repeats, inner batch %d\n' ...
                '    absolute: A %.4g s, B %.4g s\n    machine: %s\n' ...
                '    A spread this wide usually means the machine, not ' ...
                'the code; a tight band means a real change.'], ...
                label, ratio, opts.Direction, budget, expected, ...
                band(1), band(2), nRep, nb, ...
                median(tA), median(tB), geoMapMachineTag());

            if opts.Direction == "<="
                tc.verifyLessThanOrEqual(ratio, budget, msg);
            else
                tc.verifyGreaterThanOrEqual(ratio, budget, msg);
            end
        end
    end

    methods (Static)
        function [ratio, band] = ratioStatistic(tA, tB)
            %RATIOSTATISTIC  Median of per-repeat ratios, and their band.
            %
            %   Deliberately NOT median(tA)/median(tB). A median removes a
            %   slow repeat INSIDE one window and is blind to a monotone
            %   drift BETWEEN windows; more repeats give the drift longer
            %   to run. Pairing inside each repeat is what removes it, and
            %   this statistic is what preserves the pairing.
            %
            %   Separated from the measurement so it can be proven on a
            %   synthetic drifting sequence with no timer involved.
            %
            %   INPUTS
            %     tA, tB  (1,:) double  Per-repeat seconds, paired.
            %
            %   OUTPUTS
            %     ratio   (1,1) double  Median of the per-repeat ratios.
            %     band    (1,2) double  [min max] of those ratios.
            %
            %   EXAMPLE
            %     [r, b] = GeoMapTestCase.ratioStatistic([2 4], [1 2])
            arguments
                tA (1,:) double
                tB (1,:) double
            end
            if numel(tA) ~= numel(tB)
                error('geo:test:RatioSizeMismatch', ...
                    ['Paired timing vectors must be the same length; ' ...
                     'received %d and %d. Unequal lengths mean the ' ...
                     'pairing was lost, which is the defect this ' ...
                     'statistic exists to avoid.'], numel(tA), numel(tB));
            end
            ratios = tA ./ tB;
            ratio = median(ratios);
            band = [min(ratios), max(ratios)];
        end
    end
end

% ----------------------------------------------------------------------
% Local functions. These trust their inputs: they are reached only from
% the methods above, which validate.
% ----------------------------------------------------------------------
function closeIfValid(f)
if isvalid(f), close(f); end
end

function restoreWarningState(st, priorMsg, priorId)
%RESTOREWARNINGSTATE  Put back both halves of the warning state.
%   The enable/disable flags AND lastwarn. See SUPPRESSWARNING for why
%   the second half is load-bearing (finding PV-043).
warning(st);
lastwarn(priorMsg, priorId);
end

function t = timeBatch(fcn, nb)
%TIMEBATCH  Mean seconds per call over an inner batch.
t0 = tic;
for k = 1:nb
    fcn();
end
t = toc(t0) / nb;
end

function nb = autoInnerBatch(fcnA, fcnB, floorSec)
%AUTOINNERBATCH  Choose a batch so each timed sample clears the timer.
%   Below about a millisecond you are timing the timer, and the cure is an
%   inner batch, not more repeats.
tA = timeBatch(fcnA, 1);
tB = timeBatch(fcnB, 1);
t = min(tA, tB);
if t <= 0 || ~isfinite(t)
    nb = 1000;
else
    nb = min(max(1, ceil(floorSec / t)), 1e5);
end
end
