classdef FigureCensusPlugin < matlab.unittest.plugins.TestRunnerPlugin
%FIGURECENSUSPLUGIN  Which test methods left a figure behind.
%
%   DESCRIPTION
%     Counts the figures parented to the graphics root immediately before
%     and immediately after every test method, and records the ones whose
%     count went up. RUNGEOMAPTESTS reports the table and fails the gate
%     on a non-empty one.
%
%     WHY THIS IS A SEPARATE INSTRUMENT FROM THE WARNING INVENTORY.
%     VALIDATION_GUIDE Part 3: the second gate must read something the
%     first does not. Every other condition the runner applies reads test
%     results, warning identifiers, filter reasons, speed records,
%     category coverage or source files. Not one of them reads the
%     graphics root, and a green 516-point run therefore left four
%     visible figures open on the target machine and reported nothing
%     (PV-149). The leak was found by a human noticing windows on a
%     desktop, which is not an instrument.
%
%     IT REPORTS, IT DOES NOT CLEAN UP. VALIDATION_GUIDE Part 10 - a test
%     must not change the machine it measures, and neither may the thing
%     watching it. Closing the leak here would make the gate green by
%     destroying its own evidence, and would also close figures the
%     person running the suite had open for their own reasons. The census
%     names the method; the repair belongs in the method or in the
%     library it exercises.
%
%     WHY A DELTA AND NOT AN ABSOLUTE COUNT. The suite may legitimately
%     be run in a session that already has figures open. Only the change
%     across one test method is attributable to that method.
%
%   EXAMPLE
%     runner.addPlugin(FigureCensusPlugin());
%
%   LIMITATIONS
%     A method that leaks one figure and closes another shows a delta of
%     zero. The census is a leak detector, not an audit of identity - it
%     answers "did the population grow", not "are these the same
%     figures". That is adequate for the gate, whose claim is that a
%     clean run ends with the graphics root as it found it, and it is
%     recorded here rather than left for a reader to discover.
%
%     It cannot see a figure created on a parallel worker: the worker has
%     its own graphics root and its own lifetime. TESTINTEGRATION's
%     parallel export path is therefore outside this instrument's reach,
%     which is stated rather than assumed covered.
%
%   See also RUNGEOMAPTESTS, WARNINGINVENTORYPLUGIN,
%   GEO.INTERNAL.DISCARDONFAILURE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (SetAccess = private)
        % One row per leaking method: Name, Delta.
        Leaks = struct('name', {}, 'delta', {})
    end

    methods (Access = protected)
        function runTest(plugin, pluginData)
            before = numel(findall(groot, 'Type', 'figure'));
            runTest@matlab.unittest.plugins.TestRunnerPlugin(plugin, ...
                pluginData);
            delta = numel(findall(groot, 'Type', 'figure')) - before;
            if delta > 0
                plugin.Leaks(end + 1) = struct( ...
                    'name', string(pluginData.Name), 'delta', delta);
            end
        end
    end
end
