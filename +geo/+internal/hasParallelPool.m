function [tf, why] = hasParallelPool(needRunning)
%GEO.INTERNAL.HASPARALLELPOOL  Can this session actually run on workers?
%
%   SYNTAX
%     [tf, why] = GEO.INTERNAL.HASPARALLELPOOL()
%     [tf, why] = GEO.INTERNAL.HASPARALLELPOOL(true)
%
%   DESCRIPTION
%     Answers whether Parallel Computing Toolbox is usable here, by
%     TRYING IT rather than by asking whether a file exists.
%
%     WHY NOT EXIST('parfeval', 'file'). Because it was wrong, and it
%     was wrong on the only machine that mattered. GEO.EXPORT guarded
%     its parallel path with
%     exist('parfeval','file') > 0 && exist('gcp','file') > 0, and on
%     CI - which has no Parallel Computing Toolbox - that guard PASSED
%     and the next line died with "Undefined function 'gcp' for input
%     arguments of type 'char'". A guard written to produce a helpful
%     error produced an unhelpful one, on precisely the configuration it
%     existed for (PV-123).
%
%     EXIST(name, 'file') answers a question about the file system, not
%     about whether a function can be CALLED: MATLAB ships dispatch
%     stubs and help files for toolboxes that are not installed, and
%     they are files. The only reliable test of "can I call this" is to
%     call it.
%
%     A CAPABILITY PROBE MUST NOT THROW, so the call is wrapped and any
%     failure means "no". That is the one place where swallowing an
%     error is right: the question being asked IS whether the error
%     happens.
%
%   INPUTS
%     needRunning  (1,1) logical  [false]  When true, a pool must already
%                  be OPEN, not merely available. Starting one takes
%                  about ten seconds, so a test that needs workers asks
%                  for a running pool and filters rather than paying it.
%
%   OUTPUTS
%     tf   (1,1) logical
%     why  (1,1) string  Why not, when tf is false. Empty when it is true.
%
%   ACCURACY
%     Exact: the toolbox answers or it does not.
%
%   ERRORS
%     (none; that is the point)
%
%   EXAMPLE
%     [ok, why] = geo.internal.hasParallelPool();
%     if ~ok, error('geo:export:NoParallel', '%s', why); end
%
%   LIMITATIONS
%     With needRunning false this reports that a pool COULD be started,
%     not that starting one will succeed - a cluster profile can fail at
%     connection time, which no probe can foresee.
%
%   See also GEO.EXPORT, PARFEVAL, GCP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    needRunning (1,1) logical = false
end

tf = false;
why = "Parallel Computing Toolbox is not available in this session.";
try
    p = gcp('nocreate');
catch
    return              % gcp itself is absent: no toolbox, no pool
end
if needRunning
    tf = ~isempty(p);
    if ~tf
        why = "No parallel pool is open in this session.";
    end
else
    tf = true;
end
if tf
    why = "";
end
end
