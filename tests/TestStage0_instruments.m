classdef TestStage0_instruments < GeoMapTestCase
%TESTSTAGE0_INSTRUMENTS  Self-tests for the harness itself.
%
%   DESCRIPTION
%     Every instrument ships a fault-injection self-test in the same round
%     it is added: it must be shown to FIRE on a broken fixture and to be
%     SILENT on a healthy one. A check without a fixture proving it fires
%     is not a check, and no count, structure or coverage claim may come
%     from an instrument written in the same session as the change it
%     checks unless that instrument has been shown to fail on a known
%     defect.
%
%     The most important test here is driftIsCaughtByPairedStatistic. It
%     proves the timing instrument computes the statistic it exists for,
%     by constructing the exact failure it is meant to survive.
%
%   See also GEOMAPTESTCASE, RUNGEOMAPTESTS, VERIFYMANIFEST.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["GeoMapTestCase" "geoMapTestRecord" ...
                            "verifyManifest" "geo.internal.sha256OfText"]
    end

    % ==================================================================
    % The ratio statistic
    % ==================================================================
    methods (Test, TestTags = {'precision'})

        function recoversAConstructedRatio(tc)
            % A ratio that is exactly 4 must read 4.
            tB = [1 1 1 1 1 1];
            tA = 4 * tB;
            [r, band] = GeoMapTestCase.ratioStatistic(tA, tB);
            tc.verifyEqual(r, 4, 'AbsTol', 1e-12);
            tc.verifyEqual(band, [4 4], 'AbsTol', 1e-12);
        end

        function driftIsCaughtByPairedStatistic(tc)
            % THE test that justifies the instrument.
            %
            % Construct a sequence where the true per-repeat ratio is
            % exactly 2 throughout, but the machine slows monotonically
            % across the run (thermal drift, page cache, allocator).
            % Paired inside each repeat, the ratio is immune. Computed as
            % a ratio of medians over UNPAIRED windows - the shape this
            % instrument rejects - it is not.
            n = 16;
            drift = linspace(1, 3, n);        % machine gets 3x slower
            tB = drift;
            tA = 2 * drift;                   % true ratio is 2 everywhere

            [paired, band] = GeoMapTestCase.ratioStatistic(tA, tB);
            tc.verifyEqual(paired, 2, 'AbsTol', 1e-12, ...
                'Paired statistic must be immune to monotone drift.');
            tc.verifyEqual(band, [2 2], 'AbsTol', 1e-12);

            % Now the unpaired shape: A timed to completion first, THEN B.
            % A lands in the fast window, B in the slow one.
            firstHalf = drift(1:n/2);
            secondHalf = drift(n/2+1:end);
            unpaired = median(2 * firstHalf) / median(secondHalf);
            tc.verifyGreaterThan(abs(unpaired - 2), 0.5, ...
                ['The unpaired shape must be visibly wrong here, ' ...
                 'otherwise this fixture does not exercise the defect ' ...
                 'the paired statistic exists to avoid.']);
        end

        function pairingIsLoadBearing(tc)
            % Negative half: with the SAME two multisets of timings, the
            % answer depends on how they are paired. A statistic that did
            % not depend on the pairing would not be measuring a ratio.
            tA = [1 2 3 40];
            tB = [1 1 10 10];
            rGood = GeoMapTestCase.ratioStatistic(tA, tB);
            rPermuted = GeoMapTestCase.ratioStatistic(tA, fliplr(tB));
            tc.verifyNotEqual(rGood, rPermuted, ...
                ['If re-pairing the same timings changes nothing, the ' ...
                 'statistic is not preserving the pairing that removes ' ...
                 'between-window drift.']);
            % And the ratio of medians is blind to that difference, which
            % is exactly why it is the wrong statistic.
            tc.verifyEqual(median(tA) / median(tB), ...
                           median(tA) / median(fliplr(tB)), 'AbsTol', 1e-12);
        end
    end

    methods (Test, TestTags = {'contract'})

        function ratioStatisticRejectsLostPairing(tc)
            tc.verifyError(@() GeoMapTestCase.ratioStatistic([1 2 3], [1 2]), ...
                'geo:test:RatioSizeMismatch');
        end

        function recordStoreRoundTrips(tc)
            % This is the ONLY test that may reset the store,
            % because reset is the thing it proves. It therefore
            % has to put back what it destroys: the store holds the
            % run's measurements, and wiping them made the report
            % read "0 ratio records" while three speed tests passed
            % (finding PV-021). An instrument that erases the
            % evidence it exists to preserve is worse than none.
            saved = geoMapTestRecord('get');
            restore = onCleanup(@() localRestoreRecords(saved));

            geoMapTestRecord('reset');
            tc.verifyEqual(geoMapTestRecord('count'), 0);
            geoMapTestRecord('add', struct('kind', "value", 'x', 1));
            tc.verifyEqual(geoMapTestRecord('count'), 1);
            r = geoMapTestRecord('get');
            tc.verifyEqual(r{1}.x, 1);
            geoMapTestRecord('reset');
            tc.verifyEqual(geoMapTestRecord('count'), 0);
        end

        function recordStoreRejectsBadInput(tc)
            tc.verifyError(@() geoMapTestRecord('nonsense'), ...
                'geo:testRecord:UnknownCommand');
            tc.verifyError(@() geoMapTestRecord('add', struct('x', 1)), ...
                'geo:testRecord:MissingKind');
        end

        function verifyAndRecordLeavesTheNumber(tc)
            % Never reset here: the runner resets once, before the
            % run, and a test that resets erases what every earlier
            % test recorded. Assert on the DELTA instead
            % (finding PV-020).
            n0 = geoMapTestRecord('count');
            tc.verifyAndRecord(0.5, 1.0, "self-test bound", "s");
            r = geoMapTestRecord('get');
            tc.verifyEqual(numel(r), n0 + 1);
            tc.verifyEqual(r{end}.actual, 0.5);
            tc.verifyEqual(r{end}.bound, 1.0);
            tc.verifyNotEmpty(char(r{end}.machine));
        end

        function suppressWarningTurnsTheIdentifierOff(tc)
            % Positive half: inside the test the identifier is off.
            % The restore is a teardown, so it is observable only in a
            % later test; restoreIsObservable below is that half.
            id = 'geo:internal:testProbe';
            tc.suppressWarning(id);
            st = warning('query', id);
            tc.verifyEqual(st.state, 'off');
        end

        function restoreIsObservable(tc)
            % Negative half of the pair above. Alphabetical ordering is
            % not guaranteed, so this asserts only the invariant that
            % matters: no test may leave this identifier off for the
            % suites that follow.
            st = warning('query', 'geo:internal:testProbe');
            tc.verifyEqual(st.state, 'on', ...
                ['A previous test left this identifier suppressed. A ' ...
                 'cluster of unrelated failures sharing one symptom is ' ...
                 'session state, not code.']);
        end

        function parallelPoolIsNeverStarted(tc)
            % canUseParallelPool must not create a pool as a side effect.
            hadPool = false;
            if exist('gcp', 'file') == 2
                hadPool = ~isempty(gcp('nocreate'));
            end
            tf = tc.canUseParallelPool();
            tc.verifyClass(tf, 'logical');
            if exist('gcp', 'file') == 2
                nowPool = ~isempty(gcp('nocreate'));
                tc.verifyEqual(nowPool, hadPool, ...
                    'canUseParallelPool must never start a pool.');
            end
        end

        function unmeasuredToleranceRefusesToGuess(tc)
            % TolMass must error rather than return a plausible default
            % while handover debt V7 is open.
            try
                v = tc.TolMass(); %#ok<NASGU>
                % If it succeeded, the mirror has measured it - then it
                % must be a positive finite number, not a placeholder.
                tc.verifyTrue(isfinite(tc.TolMass()) && tc.TolMass() > 0);
            catch err
                tc.verifyEqual(err.identifier, 'geo:test:ToleranceNotMeasured');
            end
        end
    end

    % ==================================================================
    % Manifest, with fault injection
    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function manifestFiresOnAlteredFile(tc)
            root = tc.makeScratchTree();
            makeManifest(root);

            [ok, msg] = verifyManifest(root);
            tc.verifyTrue(ok, "Healthy tree must verify: " + msg);

            % Fault injection: change one byte.
            f = fullfile(root, 'alpha.m');
            txt = fileread(f);
            fid = fopen(f, 'w'); fprintf(fid, '%s', [txt ' ']); fclose(fid);

            [ok2, msg2] = verifyManifest(root);
            tc.verifyFalse(ok2, 'Altered file must fail verification.');
            tc.verifySubstring(char(msg2), 'alpha.m');
        end

        function manifestFiresOnMissingFile(tc)
            root = tc.makeScratchTree();
            makeManifest(root);
            delete(fullfile(root, 'beta.md'));
            [ok, msg] = verifyManifest(root);
            tc.verifyFalse(ok);
            tc.verifySubstring(char(msg), 'beta.md');
        end

        function manifestFiresWhenAbsent(tc)
            root = tc.makeScratchTree();
            [ok, msg] = verifyManifest(root);
            tc.verifyFalse(ok);
            tc.verifySubstring(char(msg), 'not found');
        end
    end

    methods (Test, TestTags = {'reference'})

        function sha256MatchesKnownVector(tc)
            % NIST empty-string and "abc" vectors: an outside authority,
            % not something built here.
            if ~usejava('jvm')
                tc.filterBecause("geo:filter:noJvm", ...
                    'No JVM: the strong hash path is unavailable.');
            end
            tc.verifyEqual(char(geo.internal.sha256OfText('')), ...
                'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
            tc.verifyEqual(char(geo.internal.sha256OfText('abc')), ...
                'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
        end

        function mirrorReferenceIsReadable(tc)
            % The mirror is the authority for every number this project
            % asserts. If it is missing, say so loudly rather than
            % falling back on the handover's unmeasured values.
            try
                v = tc.loadMirrorReference("mercator_y_at_lat35");
            catch err
                tc.filterBecause("geo:filter:mirrorUnavailable", ...
                    ['Mirror reference unavailable (' err.identifier ...
                     '). Run the Python mirror first.']);
                return
            end
            tc.verifyEqual(v.measured, 0.6528365797197981, 'AbsTol', 1e-12);
            tc.verifyTrue(v.agrees);
        end

        function missingMirrorKeyIsAnError(tc)
            try
                tc.loadMirrorReference("mercator_y_at_lat35");
            catch
                tc.filterBecause("geo:filter:mirrorUnavailable", ...
                    'Mirror reference unavailable.');
                return
            end
            tc.verifyError(@() tc.loadMirrorReference("no_such_key_here"), ...
                'geo:test:MirrorKeyMissing');
        end
    end

    % ==================================================================
    % The timing instrument, end to end
    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function timingInstrumentRecoversAKnownRatio(tc)
            tc.assumeSpeedTestsEnabled();
            % Constructed workload with a known cost ratio of 4: the same
            % operation on 4x the elements.
            %
            % N MEASURED, NOT CHOSEN. The first draft used n = 2e5 and
            % would have failed: measured on win64/R2026a/16 threads, a
            % size ladder reads
            %     n=2e5   ratio 1.434   fixed cost 0.52 ms = 85% of the
            %                           small point -- timing call overhead
            %     n=1e6   ratio 3.491   fixed 0.181 ms (17%)
            %     n=4e6   ratio 4.111   fixed ~0
            %     n=1.6e7 ratio 3.942   fixed 0.281 ms (2%)
            % At 2e5 the points are also 1.6 MB and 6.4 MB, straddling L3,
            % so they are not even in one memory regime. Solve f + v and
            % f + 4v from two points and check f before writing a growth
            % budget: that is the whole lesson here (finding PV-016).
            %
            % THE FIXTURE ABOVE WAS THE WRONG SHAPE, and the ladder is the
            % record of how much work went into calibrating around that.
            % Two DIFFERENT arrays, 4N and N, are two different memory
            % regimes as soon as one of them leaves cache - which is
            % exactly what BEST_PRACTICE 3.4.3 says to check first, and
            % exactly what "two sides doing the same work on the same
            % arrays" exists to avoid. Measured on a GitHub 1-core runner:
            % the constructed 4.0 read 5.536 (band 4.70..6.03) and, on a
            % re-run of the identical commit, 4.885 - while the baseline
            % box read 3.84 (band 3.67..4.15). The twin CI triggers
            % disagreed on the same commit, which is what they are for.
            %
            % Estimating the fixed term to calibrate around it did not
            % work either, and the failure is instructive: f is solved as
            % a difference of two nearly equal times, so its RELATIVE size
            % is badly conditioned. It read +0.98% on one local run and
            % -70.3% on the runner, and a first draft happily SELECTED the
            % -70.3% rung because it minimised the signed fraction.
            %
            % The repair is to remove the confound rather than to model
            % it: ONE array, and the numerator does four passes over it
            % where the denominator does one. The true ratio is then
            % exactly 4 by construction, in one memory regime by
            % construction, on any machine. The only thing left to
            % calibrate is that a single pass clears the timer, which is a
            % well-conditioned measurement.
            %
            % The tolerance did not move. A criterion widened until green
            % is an instrument destroyed in place (BEST_PRACTICE 4.6).
            [x, calib] = calibrateGrowthFixture(tc);
            n0 = geoMapTestRecord('count');   % delta, never reset
            rec = tc.assertRatioBudget( ...
                @() localRepeatedSum(x, 4), @() localRepeatedSum(x, 1), ...
                6.0, 4.0, sprintf(...
                    "self-test: 4 passes / 1 pass over one array, N=%.3g", ...
                    numel(x)));
            % The ACCURACY claim: recovery within 10%, because 15 repeats
            % measured 10.2% spread in the source study and a tighter
            % figure would assert below the instrument's own noise.
            tc.verifyEqual(rec.ratio, 4.0, 'RelTol', 0.10, ...
                sprintf(['Constructed ratio not recovered. band %.3g..%.3g, ' ...
                         'batch %d, machine %s\n' ...
                         'CALIBRATION: N=%.3g, one pass measured %.4g s ' ...
                         '(floor %.4g s). Both points read the SAME ' ...
                         'array, so a memory-regime explanation is ' ...
                         'excluded by construction and this is a ' ...
                         'statement about assertRatioBudget itself.'], ...
                         rec.band(1), rec.band(2), rec.innerBatch, ...
                         rec.machine, calib.n, calib.onePass, calib.floor));
            tc.verifyEqual(mod(rec.repeats, 2), 0, ...
                'Repeat count must be even so rotation is balanced.');
            tc.verifyGreaterThanOrEqual(rec.repeats, 15);
            tc.verifyGreaterThanOrEqual(rec.innerBatch, 1);
            tc.verifyEqual(geoMapTestRecord('count'), n0 + 1, ...
                'assertRatioBudget must leave exactly one record.');
        end

        function subMillisecondWorkGetsAnInnerBatch(tc)
            tc.assumeSpeedTestsEnabled();
            % Below about a millisecond you are timing the timer; the cure
            % is an inner batch, not more repeats.
            x = rand(1, 50);
            rec = tc.assertRatioBudget(@() sum(x), @() sum(x), ...
                3.0, 1.0, "self-test: identical tiny workloads");
            tc.verifyGreaterThan(rec.innerBatch, 1, ...
                'A sub-millisecond point must be batched.');
            tc.verifyEqual(rec.ratio, 1.0, 'RelTol', 0.35, ...
                'Identical workloads must read about 1.');
        end

        function speedupDirectionWorks(tc)
            tc.assumeSpeedTestsEnabled();
            % A budget that asserts a SPEEDUP, as the cache test will.
            % Same sizing lesson as above: at 4e5/1e5 the true ratio is
            % about 1.4, so a >= 2.0 budget would fail for reasons that
            % have nothing to do with direction handling.
            a = rand(1, 1.6e7);
            b = rand(1, 4e6);
            rec = tc.assertRatioBudget(@() sum(a.^2), @() sum(b.^2), ...
                2.0, 4.0, "self-test: speedup direction", Direction=">=");
            tc.verifyGreaterThanOrEqual(rec.ratio, 2.0);
        end
    end

    % ==================================================================
    methods (Access = private)
        function root = makeScratchTree(tc)
            %MAKESCRATCHTREE  Disposable tree for manifest fault injection.
            %   A mutator or checker is proved on a scratch copy before it
            %   is pointed at the real tree.
            % tempname is documented and collision-free; feature() is not.
            root = tempname;
            mkdir(root);
            tc.addTeardown(@() rmdir(root, 's'));
            writeText(fullfile(root, 'alpha.m'), ...
                sprintf('function alpha()\n%% scratch\nend\n'));
            writeText(fullfile(root, 'beta.md'), ...
                sprintf('# scratch\n\nbody\n'));
            mkdir(fullfile(root, 'sub'));
            writeText(fullfile(root, 'sub', 'gamma.py'), ...
                sprintf('x = 1\n'));
        end
    end
end

% ----------------------------------------------------------------------
function localRestoreRecords(saved)
%LOCALRESTORERECORDS  Put the run's measurements back.
geoMapTestRecord('reset');
for k = 1:numel(saved)
    geoMapTestRecord('add', saved{k});
end
end

function writeText(f, txt)
fid = fopen(f, 'w');
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s', txt);
end

function s = localRepeatedSum(x, k)
%LOCALREPEATEDSUM  k identical passes over ONE array.
%   The constructed workload whose true cost ratio between k=4 and k=1 is
%   exactly 4, on any machine, because both calls read the same bytes in
%   the same order. That is the property the previous fixture - 4N
%   elements against N elements - did not have.
s = 0;
for i = 1:k
    s = s + sum(x .^ 2);
end
end

function [x, calib] = calibrateGrowthFixture(tc)
%CALIBRATEGROWTHFIXTURE  Size the array so one pass clears the timer.
%
%   This is all the calibration the fixture needs now. With both points
%   reading one array, memory regime cannot differ between them, and the
%   only remaining confound is the per-call overhead the two share: the
%   measured ratio is (f + 4w)/(f + w), which approaches 4 as w grows
%   against f. So the requirement is simply that ONE PASS is large against
%   the call, and that is a well-conditioned thing to measure - unlike the
%   fixed term itself, which is a difference of two nearly equal times and
%   read +0.98% on one machine and -70.3% on another.
%
%   Floor: 200x the timer's own resolution, and at least 2 ms. At 2 ms
%   against a call overhead measured in microseconds, f/w is below 1e-2,
%   which moves the ratio by under 1% - an order inside the instrument's
%   own 10% noise floor, so the accuracy claim is not being asserted
%   against the fixture's arithmetic.
%
%   The ladder stops at 3.2e7 elements, about 256 MB, because a runner
%   that swaps is measuring the page cache. If no size clears the floor,
%   the test FILTERS - loudly, naming the measurement - rather than
%   asserting a number the machine cannot support. A skipped gate that
%   says so is honest; one that passes quietly is not.
floorSec = max(2e-3, 200 * timerResolution());
report = strings(0, 1);
x = [];
calib = struct('n', NaN, 'onePass', NaN, 'floor', floorSec);
for n = [1e6 4e6 1.6e7 3.2e7]
    x = rand(1, n);
    localRepeatedSum(x, 1);               % warm-up, untimed
    t = timeit(@() localRepeatedSum(x, 1));
    report(end+1, 1) = sprintf('      N=%9.3g  one pass %9.3g s', n, t); %#ok<AGROW>
    calib = struct('n', n, 'onePass', t, 'floor', floorSec);
    if t >= floorSec
        break
    end
end

if calib.onePass < floorSec
    tc.filterBecause("geo:filter:machineTooFast", sprintf([ ...
        'No array size up to 3.2e7 elements makes one pass reach the ' ...
        '%.4g s floor on this machine, so the instrument''s 10%%%% ' ...
        'accuracy claim cannot be asserted here. This is a property of ' ...
        'the machine, not a defect in assertRatioBudget, and the ' ...
        'tolerance was NOT widened to make it pass.\n' ...
        '   machine: %s\n   measured:\n%s'], ...
        floorSec, geoMapMachineTag(), strjoin(report, newline)));
end

% The size this test chose is itself a measurement, so it is recorded
% rather than only printed on failure (handover 2.6.3). A calibration
% that leaves no trace is a calibration nobody can question later.
tc.verifyAndRecord(calib.onePass, floorSec, ...
    "growth fixture: one pass over the shared array", "s", ">=");
end

function r = timerResolution()
%TIMERRESOLUTION  Measured, not assumed. Smallest non-zero tic/toc delta.
d = inf;
for k = 1:20
    t0 = tic;
    q = toc(t0); %#ok<NASGU>
    d = min(d, toc(t0));
end
r = max(d, eps);
end

