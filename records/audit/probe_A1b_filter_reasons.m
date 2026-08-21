%PROBE_A1B_FILTER_REASONS  What filters on CI, and can the reason be read?
%
%   AUDIT PROBE - evidence only. Not part of the toolbox, not for merge.
%
%   TWO QUESTIONS, one run, because the suite costs four minutes.
%
%   Q1  WHAT filters here. The bridge machine reports five filtered
%       points and PV-129 explains four of them. CI is a different host
%       with a different data pool, and the remedy for A-1 registers
%       reasons - so the register has to be authored against the real
%       inventory on both hosts, not against one host and an assumption.
%
%   Q2  HOW a reason can be read. Two candidate routes are measured:
%       (a) a QualifyingPlugin subclass seeing the event live;
%       (b) TestResult.Details.DiagnosticRecord after the run, which
%           needs DiagnosticsRecordingPlugin to be present.
%       Whichever is measured to work is the one the remedy uses.
%
%   ASSERTS NOTHING. A probe that fails the job destroys its own evidence.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE A-1b: filter inventory and reason routes\n');

import matlab.unittest.TestSuite
import matlab.unittest.TestRunner
import matlab.unittest.plugins.DiagnosticsRecordingPlugin

addpath(fullfile(pwd, 'records', 'audit'));
suite = TestSuite.fromFolder(fullfile(pwd, 'tests'));
fprintf('suite size: %d\n', numel(suite));

runner = TestRunner.withNoPlugins();
plugin = FilterInventoryPlugin();
runner.addPlugin(plugin);
runner.addPlugin(DiagnosticsRecordingPlugin( ...
    'IncludingPassingDiagnostics', false));

result = runner.run(suite);

nInc = sum([result.Incomplete]);
fprintf('\n########## Q1: %d incomplete of %d\n', nInc, numel(result));

fprintf('\n--- by suite ---\n');
names = string({result.Name});
inc = [result.Incomplete];
cls = extractBefore(names + "/", "/");
u = unique(cls(inc));
for i = 1:numel(u)
    fprintf('  %-30s %d\n', u(i), sum(inc & cls == u(i)));
end

fprintf('\n--- the incomplete points, named ---\n');
idx = find(inc);
for i = 1:numel(idx)
    fprintf('  %s\n', names(idx(i)));
end

fprintf('\n########## Q2a: QualifyingPlugin route\n');
fprintf('  events captured: %d\n', numel(plugin.Seen));
for i = 1:min(numel(plugin.Seen), 12)
    fprintf('  [%s]\n    name: %s\n    text: %s\n', ...
        plugin.Notes(i), plugin.Seen(i), ...
        regexprep(extractBefore(plugin.Texts(i) + " ", ...
        min(200, strlength(plugin.Texts(i)) + 1)), '\s+', ' '));
end

fprintf('\n########## Q2b: Details.DiagnosticRecord route\n');
shown = 0;
for i = idx
    d = result(i).Details;
    if ~isfield(d, 'DiagnosticRecord')
        fprintf('  %s: no DiagnosticRecord field (fields: %s)\n', ...
            names(i), strjoin(string(fieldnames(d))', ', '));
        break
    end
    rec = d.DiagnosticRecord;
    for k = 1:numel(rec)
        if shown >= 8, break, end
        try
            ev = string(rec(k).Event);
        catch
            ev = "<no Event>";
        end
        if ev ~= "AssumptionFailed", continue, end
        try
            rep = string(rec(k).Report);
        catch
            rep = "<no Report>";
        end
        rep = regexprep(rep, '\s+', ' ');
        fprintf('  %s\n    class : %s\n    report: %s\n', names(i), ...
            class(rec(k)), extractBefore(rep + " ", ...
            min(220, strlength(rep) + 1)));
        shown = shown + 1;
    end
    if shown >= 8, break, end
end
fprintf('\n########## PROBE A-1b END\n');
