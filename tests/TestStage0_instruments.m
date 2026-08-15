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
%   PROVISIONAL: written without a MATLAB interpreter. Not verified until
%   its first green run.

    properties (Constant)
        CoveredFunctions = ["GeoMapTestCase" "geoMapTestRecord" ...
                            "verifyManifest" "sha256OfText"]
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
                tc.assumeFail('No JVM: the strong hash path is unavailable.');
            end
            tc.verifyEqual(char(sha256OfText('')), ...
                'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
            tc.verifyEqual(char(sha256OfText('abc')), ...
                'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
        end

        function mirrorReferenceIsReadable(tc)
            % The mirror is the authority for every number this project
            % asserts. If it is missing, say so loudly rather than
            % falling back on the handover's unmeasured values.
            try
                v = tc.loadMirrorReference("mercator_y_at_lat35");
            catch err
                tc.assumeFail(['Mirror reference unavailable (' ...
                    err.identifier ']. Run the Python mirror first.']);
                return
            end
            tc.verifyEqual(v.measured, 0.6528365797197981, 'AbsTol', 1e-12);
            tc.verifyTrue(v.agrees);
        end

        function missingMirrorKeyIsAnError(tc)
            try
                tc.loadMirrorReference("mercator_y_at_lat35");
            catch
                tc.assumeFail('Mirror reference unavailable.');
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
            n = 4e6;
            a = rand(1, 4*n);
            b = rand(1, n);
            n0 = geoMapTestRecord('count');   % delta, never reset
            rec = tc.assertRatioBudget(@() sum(a.^2), @() sum(b.^2), ...
                6.0, 4.0, "self-test: sum of 4N squares / N squares, N=4e6");
            % The ACCURACY claim: recovery within 10%, because 15 repeats
            % measured 10.2% spread in the source study and a tighter
            % figure would assert below the instrument's own noise.
            tc.verifyEqual(rec.ratio, 4.0, 'RelTol', 0.10, ...
                sprintf(['Constructed ratio not recovered. band %.3g..%.3g, ' ...
                         'batch %d, machine %s'], rec.band(1), rec.band(2), ...
                         rec.innerBatch, rec.machine));
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

