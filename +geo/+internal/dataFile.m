function p = dataFile(name)
%GEO.INTERNAL.DATAFILE  Locate a shipped data file, from the code's own home.
%
%   SYNTAX
%     p = GEO.INTERNAL.DATAFILE(NAME)
%
%   DESCRIPTION
%     Returns the full path of a file in the toolbox's data directory,
%     found relative to THIS FILE rather than through the MATLAB path.
%
%     WHY THAT DISTINCTION IS THE WHOLE FUNCTION. GEO.READCOASTLINE and
%     GEO.READGRID located their builtin data with
%     fullfile(geoMapRoot(), "data", ...), and geoMapRoot lives in
%     tests/. The test harness always has tests/ on the path, so every
%     test passed; an INSTALLED toolbox does not, and
%     geo.readCoastline("builtin") failed there with "Unrecognized
%     function or variable 'geoMapRoot'". Measured by restoring the
%     default path, adding only the toolbox root, and calling it - which
%     is what a user's session looks like and what no test looked like
%     (PV-115).
%
%     MFILENAME('FULLPATH') CANNOT BE WRONG IN THAT WAY. It answers
%     where this file is, so the data is found whenever the code that
%     needs it was found - which is the only condition that can be true
%     at the moment of the call. GEO.INTERNAL.CVDCOLORMAP already used
%     this pattern correctly; the two readers did not, and now all three
%     ask one function.
%
%   INPUTS
%     name  (1,1) string  File name inside the data directory.
%
%   OUTPUTS
%     p  (1,1) string  Full path. Existence is not checked here; the
%                      reader that asked for it reports a missing file
%                      with the context of what it was trying to read.
%
%   ACCURACY
%     Exact: a path is right or it is not. No tolerance applies.
%
%   ERRORS
%     (none raised)
%
%   EXAMPLE
%     p = geo.internal.dataFile("coast_110m.mat");
%
%   LIMITATIONS
%     Assumes the data directory is a sibling of +geo, which is the
%     repository layout and the installed layout. A deployed
%     (compiled) toolbox would need the files marked as dependencies.
%
%   See also GEO.READCOASTLINE, GEO.READGRID, GEO.INTERNAL.CVDCOLORMAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    name (1,1) string
end

% .../+geo/+internal/dataFile.m -> up three, then into data.
here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(here));
p = string(fullfile(root, 'data', name));
end
