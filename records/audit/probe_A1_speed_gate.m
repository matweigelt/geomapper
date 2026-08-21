%PROBE_A1_SPEED_GATE  Does the green gate stay green with the speed tier off?
%
%   AUDIT PROBE - evidence only. This file is not part of the toolbox and
%   this branch is not for merge.
%
%   HYPOTHESIS (audit finding A-1). RUNGEOMAPTESTS initialises
%   speedOk = true and then ANDs it over the ratio records that were
%   actually left behind. When no speed test runs, no ratio record is
%   left, the AND is over an empty set, and the gate prints
%   "speed budgets OK" having measured nothing. A second, independent
%   route to the same emptiness is the environment switch
%   GEOMAP_SKIP_SPEED, which filters all eighteen speed tests.
%
%   The gate also excludes the incomplete count: ok is built from
%   nFail == 0 and never from nInc, so a suite that shrinks by filtering
%   is indistinguishable from one that ran.
%
%   WHAT WOULD REFUTE IT. A red gate, or a "speed budgets" line reading
%   FAIL, or a nonzero ratio-record count with the switch set.
%
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

fprintf('\n########## PROBE A-1: speed tier off, gate expected still green\n');
setenv('GEOMAP_SKIP_SPEED', '1');
ok = rungeoMapTests("all");
fprintf('\n########## PROBE A-1 RESULT: rungeoMapTests returned ok = %d\n', ok);
fprintf('########## Read the gate block above: how many ratio records,\n');
fprintf('########## what does "speed budgets" say, and how many incomplete?\n');
setenv('GEOMAP_SKIP_SPEED', '');
