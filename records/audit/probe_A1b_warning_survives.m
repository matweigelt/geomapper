%PROBE_A1B_WARNING_SURVIVES  Run the two-test probe under the real plugin.
%
%   AUDIT PROBE - evidence only. See PROBEFILTERWARNING for the hypothesis.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE A-1b: does a warning survive assumeFail?\n');
here = fileparts(mfilename('fullpath'));
addpath(here);                       % fileResolver needs it findable
suite  = matlab.unittest.TestSuite.fromFile( ...
    fullfile(here, 'ProbeFilterWarning.m'));
runner = matlab.unittest.TestRunner.withTextOutput();
p = WarningInventoryPlugin();
runner.addPlugin(p);
r = runner.run(suite);

fprintf('\n########## results: %d passed, %d incomplete\n', ...
    sum([r.Passed]), sum([r.Incomplete]));
inv = p.Inventory;
f = fieldnames(inv);
if isempty(f)
    fprintf('########## INVENTORY EMPTY - the design does not hold.\n');
else
    for i = 1:numel(f)
        fprintf('########## inventory: %-38s count %d\n', ...
            inv.(f{i}).id, inv.(f{i}).count);
    end
end
fprintf(['########## VERDICT: the design holds only if BOTH ' ...
         'UnregisteredFilter and PlainWarning appear.\n']);
