function names = projectionNames()
%GEO.INTERNAL.PROJECTIONNAMES  The sixteen supported projections, once.
%
%   SYNTAX
%     NAMES = GEO.INTERNAL.PROJECTIONNAMES()
%
%   DESCRIPTION
%     The single authority for which projections exist. GEO.CRS validates
%     against it, the doc build enumerates it, and the test suite iterates
%     it. A list repeated in three places is a list that will disagree with
%     itself the first time a seventeenth projection is added.
%
%     The order is the handover's and is not alphabetical: it runs
%     cylindrical, pseudocylindrical, azimuthal, conic, which is the order
%     a reader learning the toolbox wants and the order the documentation
%     presents.
%
%   INPUTS
%     (none)
%
%   OUTPUTS
%     names  (1,16) string  Lower-case projection names.
%
%   ACCURACY
%     No numerical claim. The count is asserted as 16 in the contract
%     tests, so a projection added without updating the tests fails
%     loudly rather than slipping in unmeasured.
%
%   ERRORS
%     (none raised)
%
%   EXAMPLE
%     for p = geo.internal.projectionNames()
%         c = geo.crs(p);
%     end
%
%   LIMITATIONS
%     Names only. Everything else about a projection - class, domain, cone
%     constant - lives in GEO.CRS, so this function cannot go stale in any
%     way except by omission.
%
%   See also GEO.CRS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

names = ["equirectangular" "mercator" "transversemercator" ...
         "robinson" "mollweide" "hammer" "winkeltripel" "sinusoidal" ...
         "lambert" "stereographic" "orthographic" ...
         "azimuthalequidistant" "gnomonic" "polarstereographic" ...
         "lambertconformal" "albers"];
end
