function plan = buildfile
%BUILDFILE  buildtool tasks for geoMap v2.
%
%   DESCRIPTION
%     Every gate must run locally, byte-identical, on a fresh clone. CI is
%     the shared instrument, not the only one: a contributor who cannot
%     reproduce the gates locally ships guesses and polls. These tasks are
%     what CI invokes, so there is one definition of each gate.
%
%   TASKS
%     check    Static analysis over the toolbox sources.
%     test     Correctness tiers (no speed).
%     testall  All tiers, including speed budgets.
%
%   EXAMPLE
%     >> buildtool test
%     >> buildtool testall
%
%   See also RUNGEOMAPTESTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)

plan = buildplan(localfunctions);
plan.DefaultTasks = ["check" "test"];
end

function checkTask(~)
%CHECKTASK  Static analysis. Fails the build on any error-level issue.
addpath(pwd); geoMapSetup;
targets = ["tests", "tools"];
if isfolder("+geo")
    targets(end+1) = "+geo";
end
issues = codeIssues(targets);
nErr = sum(issues.Issues.Severity == "error");
fprintf('codeIssues: %d total, %d error-level\n', ...
    height(issues.Issues), nErr);
if nErr > 0
    disp(issues.Issues(issues.Issues.Severity == "error", :));
    error('geo:build:StaticAnalysis', ...
        '%d error-level issues. A warning is a finding too - read them.', nErr);
end
end

function testTask(~)
%TESTTASK  Correctness tiers.
addpath(pwd); geoMapSetup;
makeManifest;
ok = rungeoMapTests();
assert(ok, 'geo:build:GateFailed', 'Green gate failed; read the log.');
end

function testallTask(~)
%TESTALLTASK  All tiers including speed budgets.
addpath(pwd); geoMapSetup;
makeManifest;
ok = rungeoMapTests("all");
assert(ok, 'geo:build:GateFailed', 'Green gate failed; read the log.');
end
