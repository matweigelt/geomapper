function out = geoMapTestRecord(cmd, rec)
%GEOMAPTESTRECORD  Collect measurements left behind by passing assertions.
%
%   DESCRIPTION
%     A passing assertion leaves no trace, so a report goes silent about
%     exactly the measurements that went well. Every instrument in
%     GeoMapTestCase writes its record here, and the runner reads them
%     afterwards. A new record kind is not a diagnostic until the report
%     has a section for it - see rungeoMapTests.
%
%     Deliberately a function with a persistent store rather than appdata
%     or a global: one authority, no figure to leak into, and it resets
%     cleanly between runs.
%
%   SYNTAX
%     geoMapTestRecord('reset')
%     geoMapTestRecord('add', rec)
%     recs = geoMapTestRecord('get')
%     n    = geoMapTestRecord('count')
%
%   INPUTS
%     cmd  (1,1) string   'reset' | 'add' | 'get' | 'count'
%     rec  (1,1) struct   Record; must carry a 'kind' field.
%
%   OUTPUTS
%     out  varies   'get' returns a cell array of records; 'count' a
%                   scalar double; otherwise [].
%
%   ERRORS
%     Input:
%       geo:testRecord:UnknownCommand - cmd is not one of the four
%       geo:testRecord:MissingKind    - an added record has no kind field
%
%   EXAMPLE
%     geoMapTestRecord('reset');
%     geoMapTestRecord('add', struct('kind', "value", 'actual', 1));
%     numel(geoMapTestRecord('get'))
%
%   See also GEOMAPTESTCASE, RUNGEOMAPTESTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
%   PROVISIONAL: not verified until its first green run.

arguments
    cmd (1,1) string
    rec struct = struct([])
end

persistent store
if isempty(store)
    store = {};
end

out = [];
switch lower(cmd)
    case "reset"
        store = {};
    case "add"
        if ~isfield(rec, 'kind')
            error('geo:testRecord:MissingKind', ...
                'A record must carry a "kind" field; received fields: %s.', ...
                strjoin(fieldnames(rec)', ', '));
        end
        % No AGROW pragma: MATLAB does not flag cell growth here, and an
        % unnecessary suppression teaches the next reader that the pattern
        % is dangerous when it is not. This IS the accumulator; cell
        % append is O(1) amortised, unlike the numeric concatenation the
        % +geo audit bans. (Found by MATLAB's Code Analyzer on first run;
        % the project's own static checker could not see it.)
        store{end+1} = rec;
    case "get"
        out = store;
    case "count"
        out = numel(store);
    otherwise
        error('geo:testRecord:UnknownCommand', ...
            'Unknown command "%s". Expected reset, add, get or count.', cmd);
end
end
