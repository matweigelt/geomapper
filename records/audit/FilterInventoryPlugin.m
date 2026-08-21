classdef FilterInventoryPlugin < matlab.unittest.plugins.QualifyingPlugin
%FILTERINVENTORYPLUGIN  Probe: can a plugin see WHY a point filtered?
%
%   DESCRIPTION
%     AUDIT PROBE - evidence only. Not part of the toolbox, not for merge.
%     Subclasses QUALIFYINGPLUGIN and overrides ASSUMPTIONFAILED to find
%     out, by measurement rather than by reading the documentation, which
%     properties of the plugin data carry a test name and a reason text
%     on this release. Records what it recovered and how; asserts nothing.
%
%   WHAT IS BEING PRE-VALIDATED. Audit finding A-1's proposed remedy is a
%   filter inventory modelled on WARNINGINVENTORYPLUGIN: every filtered
%   point names a registered reason, and an unregistered reason is red.
%   That design needs the runner to hand a plugin the REASON TEXT of an
%   assumption failure, and the authoring session had no interpreter to
%   check it with. Writing the remedy against an assumed API is exactly
%   debt V1's failure mode, so it is measured first.
%
%   This class therefore ASSERTS NOTHING. It introspects: it prints the
%   class and properties of whatever the runner passes, and tries several
%   routes to a name and a reason string, reporting which ones worked.
%   The remedy is written against the route that is measured to work.
%
%   See also RUNGEOMAPTESTS, WARNINGINVENTORYPLUGIN.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

    properties
        Seen  = strings(0, 1)   % test names, as recovered
        Texts = strings(0, 1)   % reason text, as recovered
        Notes = strings(0, 1)   % how each was recovered, or why not
        FirstDump (1,1) logical = true
    end

    methods (Access = protected)

        function assumptionFailed(plugin, pluginData, ~)
            name = "<name not recovered>";
            text = "<text not recovered>";
            note = "";

            if plugin.FirstDump
                plugin.FirstDump = false;
                fprintf('\n--- pluginData introspection (first event only)\n');
                fprintf('    class     : %s\n', class(pluginData));
                try
                    p = properties(pluginData);
                    fprintf('    properties: %s\n', strjoin(p', ', '));
                catch dumpErr
                    fprintf('    properties: unavailable (%s)\n', dumpErr.identifier);
                end
            end

            % Route 1: a Name property on the plugin data.
            try
                name = string(pluginData.Name);
                note = note + "name<-pluginData.Name;";
            catch
                try
                    name = string(pluginData.TestName);
                    note = note + "name<-pluginData.TestName;";
                catch
                    note = note + "name<-NONE;";
                end
            end

            % Route 2: the qualification's own diagnostic text.
            try
                r = pluginData.QualificationEventRecord;
                text = string(r.Report);
                note = note + "text<-EventRecord.Report;";
            catch
                try
                    d = pluginData.TestDiagnosticResults;
                    text = string(d(1).DiagnosticText);
                    note = note + "text<-TestDiagnosticResults;";
                catch
                    try
                        text = string(pluginData.Report);
                        note = note + "text<-pluginData.Report;";
                    catch
                        note = note + "text<-NONE;";
                    end
                end
            end

            plugin.Seen(end+1, 1)  = name;
            plugin.Texts(end+1, 1) = text;
            plugin.Notes(end+1, 1) = note;
        end
    end
end
