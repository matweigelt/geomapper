function tag = geoMapMachineTag()
%GEOMAPMACHINETAG  Short identifier for the machine a measurement came from.
%
%   DESCRIPTION
%     A speed number without its machine is not a measurement. This tag is
%     recorded beside every ratio so a budget re-baselined on one machine
%     is not silently compared against another.
%
%   OUTPUTS
%     tag  (1,1) string   arch | release | thread count
%
%   EXAMPLE
%     geoMapMachineTag()
%
%   See also GEOMAPTESTCASE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)

persistent cached
if isempty(cached)
    try
        nThreads = maxNumCompThreads;
    catch
        nThreads = NaN;
    end
    cached = string(sprintf('%s | R%s | %g threads', ...
        computer('arch'), version('-release'), nThreads));
end
tag = cached;
end
