function H = imagesc(lon, lat, Z, varargin)
%GEO.V1.IMAGESC  v1's geoImagesc call, drawn by v2.
%
%   SYNTAX
%     H = GEO.V1.IMAGESC(LON, LAT, Z)
%     H = GEO.V1.IMAGESC(LON, LAT, Z, Name, Value)
%
%   DESCRIPTION
%     v1's front, spelled v1's way, drawn by v2's elements. A script
%     written against geoImagesc runs by changing the function name and
%     nothing else - every option keeps its spelling, its meaning and
%     its position.
%
%     WHY IT IS NOT CALLED geoImagesc. OB-7 keeps v1 installed and
%     runnable until Stage F, and a file of that name would shadow it or
%     be shadowed by it depending on path order - the worst possible
%     failure, because which toolbox drew the figure would depend on
%     something nobody set deliberately. The name changes; nothing else
%     does.
%
%     WHERE THE OPTIONS GO is GEO.INTERNAL.V1OPTIONS' business, and it
%     raises geo:v1Options:NoEquivalent - naming the replacement - for
%     the twenty-eight that have none. A v1 script therefore either runs
%     or is told exactly what to change, and never draws a figure that
%     quietly ignored an argument.
%
%   INPUTS
%     lon  (1,:) or (:,1) double  Longitudes, as v1 took them.
%     lat  (1,:) or (:,1) double  Latitudes.
%     Z    (:,:) double           The field.
%
%   OPTIONS
%     All 120 of geoImagesc's, in v1's spelling. See
%     GEO.INTERNAL.V1OPTIONTABLE for where each one went.
%
%   OUTPUTS
%     H  (1,1) struct  GEO.MAP's return value, not v1's. v1 returned
%                      [figH, axH, C, P]; v2 returns one struct holding
%                      the figure, the axes, the crs and every element -
%                      which is strictly more, but is not the same
%                      shape, and is the one deliberate difference.
%
%   ACCURACY
%     None of its own: it translates names and calls GEO.MAP. Every
%     number on the figure is an element's.
%
%   ERRORS
%     geo:v1:imagesc:NoOptions - options given without a value
%
%   EXAMPLE
%     % A v1 line, unchanged but for the function name:
%     geo.v1.imagesc(lon, lat, Z, 'Projection', 'mollweide', ...
%         'ShowColorbar', true, 'ColorbarLabel', 'cm/yr', ...
%         'GraticuleStepLon', 60, 'ScaleBar', true);
%
%   LIMITATIONS
%     The return shape differs, as above. Options belonging to v1's
%     other four fronts are not translated here; they arrive when their
%     v2 counterparts do.
%
%   See also GEO.MAP, GEO.INTERNAL.V1OPTIONS, GEO.INTERNAL.V1OPTIONTABLE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon double
    lat double
    Z double
end
arguments (Repeating)
    varargin
end

if mod(numel(varargin), 2) ~= 0
    error('geo:v1:imagesc:NoOptions', ...
        ['%d trailing arguments is not a name-value list. v1 took its ' ...
         'options in pairs and so does this.'], numel(varargin));
end

nv = geo.internal.v1Options(varargin);
H = geo.map(lon, lat, Z, nv{:});
end
