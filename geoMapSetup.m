function folders = geoMapSetup()
%GEOMAPSETUP  Put every geoMap folder on the path, from one list.
%
%   SYNTAX
%     GEOMAPSETUP()
%     folders = GEOMAPSETUP()
%
%   DESCRIPTION
%     Adds the toolbox, its tests, its tools, its records and its
%     documentation builder to the MATLAB path, and returns the list.
%
%     WHY THIS EXISTS. The same path list was written out in SIX places:
%     once in .github/workflows/ci.yml, twice in tools/gates.sh and three
%     times in buildfile.m. Adding docbuild/ at Stage F meant the new
%     tests passed locally and would have failed on CI, because the
%     copies had no way of learning about each other - F6, in the one
%     part of the project the audit's duplicate-local check cannot see,
%     since two of the copies are not MATLAB.
%
%     A LIST IN SIX PLACES IS A LIST THAT WILL DIFFER. This is the one
%     place. Callers do `addpath(pwd); geoMapSetup;` - pwd is the
%     repository root in every context that needs this - and the folders
%     are then resolved from THIS FILE's location, so the result does
%     not depend on the working directory afterwards.
%
%   INPUTS
%     (none)
%
%   OUTPUTS
%     folders  (1,:) string  The folders added, in the order added.
%
%   ACCURACY
%     Exact: a folder is on the path or it is not.
%
%   ERRORS
%     geo:setup:MissingFolder - a folder the project needs is absent,
%                               which means this is not a geoMap tree
%
%   EXAMPLE
%     addpath(pwd);
%     geoMapSetup;
%
%   LIMITATIONS
%     It adds folders; it does not remove them, and it does not save the
%     path. A session that wants the toolbox permanently should use
%     MATLAB's own Add-On installation instead.
%
%   See also RUNGEOMAPTESTS, GEOMAPAUDIT, BUILD_HELP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

root = string(fileparts(mfilename('fullpath')));
names = ["tests" "tools" "records" "docbuild"];

folders = root;
for n = names
    p = fullfile(root, n);
    if ~isfolder(p)
        error('geo:setup:MissingFolder', ...
            ['"%s" is missing from %s. This does not look like a geoMap ' ...
             'tree; check the working directory.'], n, root);
    end
    folders(end + 1) = p;                                   %#ok<AGROW>
end
addpath(folders{:});
end
