classdef TestContentsConsistency < GeoMapTestCase
%TESTCONTENTSCONSISTENCY  Stage F: the catalogue tells the truth.
%
%   DESCRIPTION
%     Contents.m lists every public function with a one-line summary and
%     carries the version the whole project is checked against. Both are
%     facts stated twice - once here and once in the function itself -
%     and this is what stops the second copy drifting.
%
%     WHY EXACT AND NOT "SIMILAR". A summary that paraphrases is a
%     second description of the same thing, which is F6 applied to
%     prose: it drifts, and the drift is invisible because both halves
%     read plausibly. Character-for-character is the only comparison
%     that a human cannot talk themselves past.
%
%   ACCURACY
%     Exact string equality throughout. No tolerance applies to prose.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestContentsConsistency");
%
%   LIMITATIONS
%     It checks that the catalogue matches the code. It cannot check
%     that either is a good description - that is what reading is for.
%
%   See also CONTENTS, GEOMAPAUDIT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = string.empty(1, 0)
    end

    methods (Access = private)

        function s = contentsText(tc)
            p = fullfile(geoMapRoot(), "Contents.m");
            tc.assertTrue(isfile(p), 'Contents.m is the version authority.');
            s = string(splitlines(fileread(p)));
        end

        function [names, summaries] = listedEntries(tc)
            %LISTEDENTRIES  The geo.* rows of the catalogue.
            L = tc.contentsText();
            m = regexp(L, '^%\s+(geo\.[\w.]+)\s+-\s+(.+)$', 'tokens', 'once');
            hit = ~cellfun(@isempty, m);
            m = m(hit);
            names = strings(1, numel(m));
            summaries = strings(1, numel(m));
            for k = 1:numel(m)
                names(k) = string(m{k}{1});
                summaries(k) = strtrim(string(m{k}{2}));
            end
        end

        function h1 = h1Of(~, fn)
            %H1OF  The function's own one-line summary, from its source.
            L = string(splitlines(fileread(which(fn))));
            h1 = regexprep(L(2), '^%\S*\s+', '');
        end

        function names = publicFunctions(~)
            d = dir(fullfile(geoMapRoot(), "+geo", "*.m"));
            names = "geo." + string(erase({d.name}, ".m"));
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function everyPublicFunctionIsListed(tc)
            listed = tc.listedEntries();
            missing = setdiff(tc.publicFunctions(), listed);
            tc.verifyEmpty(missing, ...
                "public and not in Contents.m: " + strjoin(missing, ", "));
        end

        function noEntryNamesAFunctionThatDoesNotExist(tc)
            listed = tc.listedEntries();
            for fn = listed
                tc.verifyNotEmpty(which(fn), ...
                    fn + " is listed in Contents.m and does not exist");
            end
        end

        function everySummaryIsItsOwnH1CharacterForCharacter(tc)
            % The assertion this file exists for.
            [names, summaries] = tc.listedEntries();
            for k = 1:numel(names)
                tc.verifyEqual(summaries(k), tc.h1Of(names(k)), ...
                    names(k) + ": Contents.m and the function disagree");
            end
        end

        function theVersionLineParses(tc)
            L = tc.contentsText();
            tok = regexp(L, '^%\s*Version\s+(\S+)\s', 'tokens', 'once');
            tok = tok(~cellfun(@isempty, tok));
            tc.verifyNumElements(tok, 1, ...
                'exactly one Version line, or it is not an authority');
            v = string(tok{1}{1});
            tc.verifyTrue(~isempty(regexp(v, '^\d+\.\d+\.\d+', 'once')), ...
                "version " + v + " is not a dotted triple");
        end

        function theLayerGroupingCoversEveryFunction(tc)
            % A catalogue in which a function is listed but under no
            % heading is a catalogue that has stopped describing the
            % architecture.
            L = tc.contentsText();
            headings = find(~cellfun(@isempty, ...
                regexp(L, '^%\s{3}(L\d|Compatibility|Instruments)', 'once')));
            tc.verifyGreaterThanOrEqual(numel(headings), 5, ...
                'the five layers plus compatibility');
            rows = find(~cellfun(@isempty, ...
                regexp(L, '^%\s+geo\.[\w.]+\s+-\s', 'once')));
            tc.verifyGreaterThan(min(rows), min(headings), ...
                'every entry must sit under a heading');
        end
    end
end
