classdef TestF2_docbuild < GeoMapTestCase
%TESTF2_DOCBUILD  Stage F: the manual says what the code says.
%
%   DESCRIPTION
%     The documentation builder parses every public function's help into
%     HTML and reports how much of it it actually rendered. This suite
%     asserts the report, and asserts it against the FILES ON DISK
%     rather than against the builder's own account of itself.
%
%     WHY THAT DISTINCTION IS THE POINT. A reference project parsed
%     argument descriptions into its documentation model for years while
%     the renderer never read the field. Every audit stayed green,
%     because a builder reporting "42 of 42 documented" from its own
%     parse tree is reporting on its parser and not on the manual
%     (handover F1). Completeness here is counted by reading the written
%     page back and looking for each documented name inside a table
%     cell.
%
%   ACCURACY
%     Completeness is a count of strings found in files, so it is exact.
%     100% of documented arguments must be rendered, and there must be
%     no broken cross-reference.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestF2");
%
%   LIMITATIONS
%     It checks that the manual contains what the help contains. It
%     cannot check that either is a good explanation, and nothing
%     automated can. The rendered pages still have to be looked at,
%     which is a release-checklist item and not a test.
%
%   See also BUILD_HELP, CONTENTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = "build_help"
    end

    methods (Access = private)

        function [rep, d] = buildToScratch(tc)
            %BUILDTOSCRATCH  Never into docs/html: a test must not
            %   overwrite the artefact the release ships.
            d = string(tempname());
            mkdir(d);
            tc.addTeardown(@() rmdir(d, 's'));
            rep = build_help(OutDir = d);
        end
    end

    methods (Static, Access = private)

        function writeBack(page, text)
            %WRITEBACK  Put a fault-injected file back as it was.
            fid = fopen(page, 'w');
            fwrite(fid, text);
            fclose(fid);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function aPageIsWrittenForEveryCatalogueEntry(tc)
            [rep, d] = tc.buildToScratch();
            L = string(splitlines(fileread(fullfile(geoMapRoot(), "Contents.m"))));
            listed = regexp(L, '^%\s+(geo\.[\w.]+)\s+-\s', 'tokens', 'once');
            listed = listed(~cellfun(@isempty, listed));
            tc.verifyEqual(rep.Functions, numel(listed), ...
                'one page per catalogue entry, no more and no fewer');
            for k = 1:numel(listed)
                page = fullfile(d, replace(string(listed{k}{1}), ".", "_") + ".html");
                tc.verifyTrue(isfile(page), "no page for " + string(listed{k}{1}));
            end
        end

        function theIndexAndTheTocAreWrittenTogether(tc)
            [~, d] = tc.buildToScratch();
            for f = ["index.html" "projections.html" "grace_workflow.html" ...
                     "helptoc.xml"]
                tc.verifyTrue(isfile(fullfile(d, f)), "missing " + f);
            end
            % Both come from Contents.m, so neither can name a function
            % the other does not.
            idx = string(fileread(fullfile(d, "index.html")));
            toc = string(fileread(fullfile(d, "helptoc.xml")));
            names = unique(string(regexp(idx, 'geo\.[\w.]+', 'match')));
            for n = names
                tc.verifyTrue(contains(toc, n), ...
                    n + " is in the index and not in the toc");
            end
        end

        function theProjectionGuideStatesTheSphericalCaveat(tc)
            % The single most important sentence in the manual: this is
            % a visualisation tool and the model is a sphere. A guide
            % that omitted it would invite someone to survey with it.
            [~, d] = tc.buildToScratch();
            guide = string(fileread(fullfile(d, "projections.html")));
            tc.verifyTrue(contains(guide, "SPHERE"), ...
                'the guide must say the model is spherical');
            tc.verifyTrue(contains(guide, "0.3%"), ...
                'and state the size of the resulting error');
            tc.verifyTrue(contains(guide, "not a survey tool"), ...
                'and say plainly what it is not for');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function everyDocumentedArgumentIsRenderedInTheArtefact(tc)
            % Counted in the written HTML, not in the parse tree.
            rep = tc.buildToScratch();
            tc.verifyGreaterThan(rep.ArgsDocumented, 300, ...
                'a completeness ratio over a handful of arguments proves nothing');
            tc.verifyAndRecord(1 - rep.Completeness, 0, ...
                "documented arguments missing from the rendered pages", ...
                "fraction");
        end

        function thereAreNoBrokenCrossReferences(tc)
            rep = tc.buildToScratch();
            tc.verifyAndRecord(numel(rep.BrokenLinks), 0, ...
                "See-also targets resolving to no page and no function", ...
                "links");
        end

        function everySectionTheParserNeedsIsPresent(tc)
            rep = tc.buildToScratch();
            tc.verifyEmpty(rep.MissingSections, ...
                "help blocks missing a required header: " + ...
                strjoin(rep.MissingSections, ", "));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function everyExampleInTheManualParses(tc)
            % An example that does not parse is documentation that will
            % be pasted into a session and fail there.
            rep = tc.buildToScratch();
            tc.verifyEmpty(rep.BadExamples, ...
                "examples that do not parse: " + ...
                strjoin(rep.BadExamples, ", "));
        end

        function theCompletenessCounterDiscriminates(tc)
            % HALF A CHECK IS ONE THAT ONLY EVER PASSES. The counter
            % looks for a documented name inside a table cell of the
            % written page; if that predicate matched anything, 100%
            % would be meaningless. So it is exercised both ways on a
            % real artefact: a name that IS documented must be found,
            % and one that is not must not.
            %
            % Stated limitation: this proves the PREDICATE
            % discriminates, not that the whole pipeline fails when a
            % renderer drops a field. Doing that properly needs the
            % builder to accept an alternative input tree, which it does
            % not, and inventing a weaker claim would be worse than
            % naming the gap.
            [~, d] = tc.buildToScratch();
            page = string(fileread(fullfile(d, "geo_title.html")));
            tc.verifyTrue(contains(page, "<td><code>Gap</code>"), ...
                'a documented option must appear as a table cell');
            tc.verifyFalse(contains(page, "<td><code>NoSuchOption</code>"), ...
                'and a name that is not documented must not');
        end

        function theSyncGateCatchesAStalePage(tc)
            % A DOCUMENTATION PAGE DOES NOT ROT LOUDLY. It was correct
            % when built, it still renders, it still reads well, and it
            % describes a function that has since changed. No test
            % suite notices, because the page is not code and the help
            % is not executed.
            %
            % So each page carries the SHA-256 of the help block it was
            % built from, and the audit recomputes it. Proved here by
            % corrupting one page and putting it back: a check never
            % seen to fire is not a check.
            page = fullfile(geoMapRoot(), "docs", "html", "geo_title.html");
            if ~isfile(page)
                tc.filterBecause("geo:filter:manualNotBuilt", ...
                    ['docs/html has not been built in this tree, so ' ...
                     'there is nothing to be stale.']);
            end
            orig = fileread(page);
            restore = onCleanup(@() TestF2_docbuild.writeBack(page, orig)); %#ok<NASGU>

            [okBefore, ~] = geoMapAudit(geoMapRoot(), Verbose = false, SelfTest = false);
            tc.verifyTrue(okBefore, 'the tree must be clean before it is broken');

            fid = fopen(page, 'w');
            fwrite(fid, strrep(orig, 'helpsha256: ', 'helpsha256: ff'));
            fclose(fid);
            [okAfter, found] = geoMapAudit(geoMapRoot(), Verbose = false, SelfTest = false);
            tc.verifyFalse(okAfter, 'a stale page must fail the audit');
            tc.verifyTrue(any([found.check] == "documentationSync"), ...
                'and must fail it as a documentation finding');
        end

        function theGettingStartedGuideParses(tc)
            % It is published as the toolbox's front door. One that does
            % not parse is a front door that does not open.
            issues = checkcode(which('GettingStarted'), '-struct');
            bad = issues(contains(lower(string({issues.message})), ...
                ["parse error" "unbalanced" "invalid"]));
            tc.verifyEmpty(bad, ...
                "GettingStarted.m does not parse: " + ...
                strjoin(string({bad.message}), "; "));
        end

        function buildingIntoAMissingFolderCreatesIt(tc)
            d = fullfile(string(tempname()), "nested", "out");
            tc.addTeardown(@() rmdir(fileparts(fileparts(d)), 's'));
            rep = build_help(OutDir = d);
            tc.verifyTrue(isfolder(d));
            tc.verifyGreaterThan(rep.Functions, 0);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function buildingTwiceGivesTheSameBytes(tc)
            % A manual that differs between builds cannot be reviewed:
            % every rebuild would show a diff nobody wrote.
            [~, a] = tc.buildToScratch();
            [~, b] = tc.buildToScratch();
            files = dir(fullfile(a, "*.html"));
            for k = 1:numel(files)
                x = fileread(fullfile(a, files(k).name));
                y = fileread(fullfile(b, files(k).name));
                tc.verifyEqual(y, x, files(k).name + " differs between builds");
            end
        end
    end
end
