function p = geoMapRoot()
%GEOMAPROOT  Absolute path of the toolbox root.
%
%   DESCRIPTION
%     One authority for where the tree lives. Derived from this file's own
%     location, never from pwd or from a hard-coded path: a hard-coded path
%     in an authoring harness is exactly the rot that a project-wide rename
%     cannot see.
%
%   OUTPUTS
%     p  (1,:) char   Absolute path to the directory containing +geo,
%                     tests, tools and mirror.
%
%   EXAMPLE
%     fullfile(geoMapRoot(), 'mirror')
%
%   See also RUNGEOMAPTESTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
%   PROVISIONAL: not verified until its first green run.

p = fileparts(fileparts(mfilename('fullpath')));
end
