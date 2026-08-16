function [crs, lonLim, latLim, base] = elementExtent(axH, crs, options)
%GEO.INTERNAL.ELEMENTEXTENT  What an L3 element draws over, resolved once.
%
%   SYNTAX
%     [crs, lonLim, latLim, base] = GEO.INTERNAL.ELEMENTEXTENT(AX, CRS)
%     [...] = GEO.INTERNAL.ELEMENTEXTENT(AX, CRS, Name, Value)
%
%   DESCRIPTION
%     Every element after GEO.BASEMAP needs the same three answers: which
%     projection, over which longitudes, over which latitudes. All three
%     default to whatever the basemap on that axes already used, so two
%     elements on one map cannot disagree about the map.
%
%     THIS EXISTS BECAUSE THE AUDIT SAID SO. GEO.GRATICULE and GEO.FRAME
%     were written with a local copy each, identical line for line, and
%     the duplicate-local-function check rejected them - which is defect
%     F6, six locals duplicated across v1's plotters, caught this time
%     before it shipped rather than four years later. One owner per fact.
%
%     THE LATITUDE LIMIT IS INTERSECTED WITH THE DOMAIN, always. An
%     element asked to draw from -90 to 90 on Mercator would otherwise
%     put its edge where the projection has none.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes
%     crs  A GEO.CRS, a projection name, or [] to take the basemap's.
%
%   OPTIONS
%     LonLimit  (1,2) double  [NaN NaN]  Override; NaN takes the basemap's.
%     LatLimit  (1,2) double  [NaN NaN]
%     ErrorId   (1,1) string  "geo:graticule:NoBasemap"  Which identifier
%                             to raise when there is neither a crs nor a
%                             basemap, so the caller's own name appears
%                             in the error the user sees.
%
%   OUTPUTS
%     crs     (1,1) struct  Validated.
%     lonLim  (1,2) double  Degrees East.
%     latLim  (1,2) double  Degrees North, inside CRS.Domain.LatLimit.
%     base    struct or []  The basemap's handle struct, or empty.
%
%   ACCURACY
%     No numerical claim: it selects and intersects, it does not compute.
%
%   ERRORS
%     geo:graticule:NoBasemap  - raised when ErrorId names it
%     geo:frame:NoBasemap      - raised when ErrorId names it
%     Both mean the same thing: no projection was given and the axes
%     carries no basemap to take one from. Two identifiers rather than
%     one shared one, because a user reads the name of the function they
%     called and not the name of its helper.
%
%   EXAMPLE
%     [c, lonLim, latLim] = geo.internal.elementExtent(ax, []);
%
%   LIMITATIONS
%     Reads the basemap entry from the layout registry, so an axes drawn
%     into by something other than GEO.BASEMAP has no extent to offer and
%     the caller must supply one.
%
%   See also GEO.BASEMAP, GEO.GRATICULE, GEO.FRAME, GEO.INTERNAL.LAYOUT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    crs = []
    options.LonLimit (1,2) double = [NaN NaN]
    options.LatLimit (1,2) double = [NaN NaN]
    options.ErrorId (1,1) string = "geo:graticule:NoBasemap"
end

base = geo.internal.layout("data", axH, "basemap");

if isempty(crs)
    if isempty(base)
        error(options.ErrorId, ...
            ['No projection was given and these axes carry no basemap ' ...
             'to take one from. Call geo.basemap first, or pass a crs.']);
    end
    crs = base.Crs;
elseif isstruct(crs)
    geo.internal.mustBeCrs(crs);
else
    crs = geo.crs(crs);
end

lonLim = options.LonLimit;
latLim = options.LatLimit;
if any(isnan(lonLim))
    if isempty(base)
        lonLim = crs.CenterLongitude + [-180 180];
    else
        lonLim = base.LonLimit;
    end
end
if any(isnan(latLim))
    if isempty(base)
        latLim = crs.Domain.LatLimit;
    else
        latLim = base.LatLimit;
    end
end
latLim = [max(latLim(1), crs.Domain.LatLimit(1)), ...
          min(latLim(2), crs.Domain.LatLimit(2))];
end
