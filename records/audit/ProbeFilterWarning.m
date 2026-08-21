classdef ProbeFilterWarning < matlab.unittest.TestCase
%PROBEFILTERWARNING  Does a warning survive an assumption failure?
%
%   DESCRIPTION
%     AUDIT PROBE - evidence only, not part of the toolbox.
%
%     The agreed A-1 remedy routes an UNREGISTERED filter reason through
%     WARNING and lets the existing warning inventory carry the alarm,
%     rather than adding a seventh gate condition. That design rests on
%     one mechanism nobody has tested: WARNINGINVENTORYPLUGIN clears
%     LASTWARN, calls runTest, and reads LASTWARN afterwards. Whether a
%     warning raised immediately BEFORE assumeFail is still in LASTWARN
%     once the framework has caught the AssumptionFailedException is an
%     assumption about MATLAB, not about this code, and V1 says an
%     assumption is not a measurement.
%
%   WHAT WOULD REFUTE IT
%     An inventory that holds PlainWarning but not UnregisteredFilter.
%     The remedy would then have to read the incomplete results directly
%     instead, and the warning would be cosmetic.
%
%   EXAMPLE
%     runner.addPlugin(WarningInventoryPlugin); runner.run(suite);
%
%   See also WARNINGINVENTORYPLUGIN, RUNGEOMAPTESTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

    methods (Test)
        function warnsThenFilters(tc)
            warning('geo:probe:UnregisteredFilter', ...
                'raised immediately before assumeFail');
            tc.assumeFail('filtered on purpose');
        end

        function warnsThenPasses(tc)
            warning('geo:probe:PlainWarning', 'raised in a passing test');
            tc.verifyTrue(true);
        end
    end
end
