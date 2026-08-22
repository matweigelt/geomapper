classdef TestStage03_audit < GeoMapTestCase
%TESTSTAGE03_AUDIT  Self-tests for the Stage 0.3 instruments.
%
%   DESCRIPTION
%     Covers the static audit, its fixture builder, and the two v1
%     measurement scripts. The audit already self-tests on every
%     invocation; this suite exists because that self-test is INSIDE the
%     instrument, and an instrument that grades its own homework needs one
%     outside reader.
%
%     What this suite asserts that GEOMAPAUDIT's own self-test does not:
%     that the self-test cannot be satisfied by a check that fires on
%     everything (the healthy control is asserted here independently),
%     that the audit is deterministic across runs, and that its documented
%     error identifiers actually fire.
%
%   ACCURACY
%     No numerical claim of its own. The v1 reference tests use oracle
%     O12 - v1 as installed - which is an authority on exactly one
%     question: what v1 does. It is not an authority on correctness; it is
%     the thing being replaced.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestStage03");
%
%   LIMITATIONS
%     The v1 tests filter loudly when the v1 tree is absent, which is the
%     normal state on CI. A filtered test is reported as filtered and
%     names its reason; it is never reported as a pass.
%
%   See also GEOMAPAUDIT, GEOMAPAUDITFIXTURES, V1_DEFECT_PROBES.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geoMapAudit" "geoMapAuditFixtures" ...
                            "v1_defect_probes" "v1_option_inventory"]
    end

    methods (Access = private)
        function d = buildFixture(tc, name)
            %BUILDFIXTURE  Build one, and guarantee it is removed.
            d = geoMapAuditFixtures("build", name);
            tc.addTeardown(@() geoMapAuditFixtures("clean", d));
        end

        function r = v1Root(tc)
            %V1ROOT  The v1 tree, through the one resolver (PV-148).
            r = tc.v1RootOrFilter();
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function theAuditReadsGeoMapSetupsFolderListRatherThanKeepingOne(tc)
            % D-020. Distribution is git, so the file that decides what a
            % user receives is geoMapSetup - what a developer runs and a
            % user does not. The audit's closure check needs that same
            % list, and PV-126 already paid for what happens when it is
            % copied: six copies across ci.yml, gates.sh and buildfile.m,
            % and adding docbuild/ broke a seventh.
            %
            % So the audit PARSES it out of geoMapSetup, and this asserts
            % the parse still finds what that file declares. If the
            % declaration changes shape the audit raises rather than
            % silently checking an empty list - which is the failure this
            % test exists to make impossible.
            src = string(fileread(which('geoMapSetup')));
            tok = regexp(src, 'names\s*=\s*\[([^\]]*)\]', 'tokens', 'once');
            tc.assertNotEmpty(tok, ...
                'geoMapSetup must declare its folder list readably.');
            % Element by element. The compact form - string() over a
            % nested cell, then brace-expanded - collapses to a CHAR ROW,
            % and `for f = charRow` iterates one letter at a time: the
            % run reported that "t", "e", "s" and "t" were declared on
            % the developer path and did not exist.
            %
            % I had already fixed exactly this in geoMapAudit two commits
            % earlier and left the copy here, which is PV-128 arriving
            % inside a single branch: fix one instance, the other
            % survives underneath.
            hits = regexp(tok{1}, '"([^"]+)"', 'tokens');
            declared = strings(1, numel(hits));
            for k = 1:numel(hits)
                declared(k) = string(hits{k}{1});
            end
            tc.verifyNotEmpty(declared, ...
                'and the list must not parse to nothing.');
            for f = declared
                tc.verifyTrue(isfolder(fullfile(geoMapRoot(), f)), ...
                    sprintf(['%s is declared on the developer path ' ...
                             'and does not exist'], f));
            end
        end

        function rejectsAMissingRoot(tc)
            tc.verifyError(@() geoMapAudit("no such folder anywhere"), ...
                'geo:audit:NoSuchRoot');
        end

        function rejectsAnUnknownCheck(tc)
            tc.verifyError(@() geoMapAudit(geoMapRoot(), Only = "nope"), ...
                'geo:audit:UnknownCheck');
        end

        function rejectsAnUnknownFixture(tc)
            tc.verifyError(@() geoMapAuditFixtures("build", "nope"), ...
                'geo:auditFixtures:UnknownFixture');
        end

        function refusesToCleanOutsideTemp(tc)
            % The cleanup path takes a directory and deletes it
            % recursively. It must not be able to reach the working tree,
            % whatever it is handed.
            tc.verifyError(@() geoMapAuditFixtures("clean", geoMapRoot()), ...
                'geo:auditFixtures:RefusedToClean');
        end

        function probesRejectAMissingV1Tree(tc)
            tc.verifyError(@() v1_defect_probes("no such v1 tree"), ...
                'geo:v1probes:RootNotFound');
        end

        function findingsCarryTheDocumentedShape(tc)
            d = tc.buildFixture("forbidden");
            [ok, f] = geoMapAudit(d, SelfTest = false, Verbose = false);
            tc.verifyFalse(ok);
            tc.verifyGreaterThanOrEqual(numel(f), 1);
            tc.verifyEqual(sort(string(fieldnames(f))), ...
                sort(["check"; "file"; "line"; "message"]));
        end

        function theRealTreeIsClean(tc)
            % The gate itself. Stated as a test so a red tree fails the
            % runner rather than only the shell script.
            [ok, f] = geoMapAudit(geoMapRoot(), SelfTest = false, ...
                Verbose = false);
            tc.verifyTrue(ok, sprintf('%d audit finding(s): %s', ...
                numel(f), listOf(f, "message")));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function everyCheckFiresOnItsOwnDefect(tc)
            % The claim GEOMAPAUDIT's own self-test makes, asserted from
            % outside it. Without this, a broken self-test and a working
            % one look identical from the runner's log.
            reg = geoMapAuditFixtures("list");
            for i = 1:numel(reg)
                if reg(i).check == "", continue, end
                d = tc.buildFixture(reg(i).name);
                [~, f] = geoMapAudit(d, SelfTest = false, Verbose = false);
                tc.verifyTrue(any([f.check] == reg(i).check), ...
                    sprintf(['check "%s" did not fire on fixture "%s" ' ...
                             '(%s). A check with no fixture proving it ' ...
                             'fires is not a check.'], ...
                             reg(i).check, reg(i).name, reg(i).why));
            end
        end

        function nothingFiresOnTheHealthyControl(tc)
            % The other half, and the half more often skipped. A check
            % that fires on everything passes the fire test and is
            % useless.
            d = tc.buildFixture("healthy");
            [ok, f] = geoMapAudit(d, SelfTest = false, Verbose = false);
            tc.verifyTrue(ok, sprintf('fired on a healthy tree: %s', ...
                listOf(f, "check")));
        end

        function v1DefectsReproduceAgainstOracleO12(tc)
            root = tc.v1Root();
            r = v1_defect_probes(root, fullfile(tempdir, "probe.md"));
            tc.addTeardown(@() deleteIfPresent(fullfile(tempdir, "probe.md")));
            tc.verifyEqual(numel(r), 18, ...
                'one probe per row of handover Part 5');
            nRefuted = sum([r.verdict] == "refuted");
            % Zero is the measured state on 15-Aug-2026, not a hope. If
            % this ever moves, the handover's Part 5 must move with it:
            % a design justified by a defect that does not exist is a
            % design without a reason.
            tc.verifyAndRecord(nRefuted, 0, ...
                "v1 defect rows refuted by probe", "rows", "<=");
        end

        function v1OptionsAreAllPlaced(tc)
            root = tc.v1Root();
            T = v1_option_inventory(root, fullfile(tempdir, "inv.md"));
            tc.addTeardown(@() deleteIfPresent(fullfile(tempdir, "inv.md")));
            tc.verifyGreaterThan(height(T), 150, ...
                'v1 has ~177 distinct options across its five fronts');
            tc.verifyAndRecord(sum(T.Status == "unmapped"), 0, ...
                "v1 options with no v2 destination", "options", "<=");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function anEmptyTreeIsCleanNotCrashing(tc)
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            [ok, f] = geoMapAudit(d, SelfTest = false, Verbose = false);
            % Except the version check, which must SAY it cannot find its
            % subject rather than stay silent.
            tc.verifyFalse(ok);
            tc.verifyEqual(unique([f.check]), "versionAgreement");
        end

        function aSingleCheckCanBeRunAlone(tc)
            d = tc.buildFixture("agrow");
            [~, f] = geoMapAudit(d, SelfTest = false, Verbose = false, ...
                Only = "arrayGrowth");
            tc.verifyEqual(unique([f.check]), "arrayGrowth");
        end

        function aFileThatCannotBeParsedIsAFindingNotAnError(tc)
            % The audit must survive the unparseable file it is there to
            % report. A gate that throws on bad input reports nothing at
            % all, which is the one outcome worse than a false negative.
            d = tc.buildFixture("analyzer");
            [ok, f] = geoMapAudit(d, SelfTest = false, Verbose = false);
            tc.verifyFalse(ok);
            tc.verifyTrue(any([f.check] == "codeAnalyzer"));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function theAuditIsDeterministic(tc)
            % Same tree, same findings, in the same order. An audit whose
            % output moves between runs cannot be diffed, and an
            % undiffable gate gets read once and then trusted.
            d = tc.buildFixture("duplicate");
            [~, a] = geoMapAudit(d, SelfTest = false, Verbose = false);
            [~, b] = geoMapAudit(d, SelfTest = false, Verbose = false);
            tc.verifyEqual([b.check], [a.check]);
            tc.verifyEqual([b.message], [a.message]);
        end

        function findingsAreIndependentOfCheckOrder(tc)
            % Running one check alone must give exactly the findings that
            % check contributes to the full run. If it does not, the
            % checks are sharing state, and a shared-state gate reports
            % whichever check ran first.
            d = tc.buildFixture("shadowed");
            [~, all] = geoMapAudit(d, SelfTest = false, Verbose = false);
            [~, one] = geoMapAudit(d, SelfTest = false, Verbose = false, ...
                Only = "shadowedBuiltins");
            fromAll = all([all.check] == "shadowedBuiltins");
            tc.verifyEqual([one.message], [fromAll.message]);
        end
    end
end

% ======================================================================
function deleteIfPresent(p)
if isfile(p), delete(p); end
end

function s = listOf(findings, field)
%LISTOF  One field of a findings array, joined - EMPTY-SAFE.
%   [f.check] on an empty struct array is a 0x0 DOUBLE, not a string
%   array, so strjoin errors. The failure lands precisely on the passing
%   case, because the message is only built when there is nothing to put
%   in it: both of this suite's diagnostic messages errored on a clean
%   tree while the assertion they carried was true. A diagnostic that can
%   only fail when everything is fine is worse than no diagnostic.
if isempty(findings)
    s = "(none)";
    return
end
s = strjoin(unique(string({findings.(field)})), " | ");
end
