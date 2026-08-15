classdef WarningInventoryPlugin < matlab.unittest.plugins.TestRunnerPlugin
%WARNINGINVENTORYPLUGIN  Collect warning identifiers raised during a run.
%
%   DESCRIPTION
%     Exactly one identifier may appear in a clean run's inventory - a
%     deliberate test probe. Any other identifier is new and fails the
%     gate. Expressed that way the rule needs no allow-list to maintain,
%     which is the point.
%
%   LIMITATIONS
%     MATLAB offers no global warning hook, so this plugin resets and reads
%     LASTWARN around each test method and therefore captures only the LAST
%     identifier raised per method. A method raising two distinct
%     identifiers reports one. This UNDER-reports and is recorded as
%     finding PV-013.
%
%     It is adequate for the gate it serves, because the gate asserts the
%     inventory is empty apart from one probe: any leak makes it non-empty
%     regardless of ordering. It is NOT adequate for counting warnings, and
%     no count from it should be quoted.
%
%   EXAMPLE
%     runner.addPlugin(WarningInventoryPlugin());
%
%   See also RUNGEOMAPTESTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
%   PROVISIONAL: not verified until its first green run.

    properties (SetAccess = private)
        Inventory = struct()
    end

    methods (Access = protected)
        function runTest(plugin, pluginData)
            lastwarn('');
            runTest@matlab.unittest.plugins.TestRunnerPlugin(plugin, pluginData);
            [~, id] = lastwarn();
            if ~isempty(id)
                key = matlab.lang.makeValidName(id);
                if isfield(plugin.Inventory, key)
                    plugin.Inventory.(key).count = ...
                        plugin.Inventory.(key).count + 1;
                else
                    plugin.Inventory.(key) = struct('id', string(id), ...
                                                    'count', 1);
                end
            end
        end
    end
end
