function tf = insideExtent(lon, lat, B)
%GEO.INTERNAL.INSIDEEXTENT  Is a coordinate inside the drawn map?
%
%   SYNTAX
%     TF = GEO.INTERNAL.INSIDEEXTENT(LON, LAT, B)
%
%   DESCRIPTION
%     The one membership test for every element that has to decide what
%     falls inside the frame. Promoted out of GEO.INTERNAL.CLIPTOBOUNDARY
%     the moment a second caller needed it, which is the rule R-011 left
%     behind - and the moment there were five, since the overlays each
%     had to answer the same question (PV-142).
%
%     A polyline gets CUT at the boundary and needs the crossing found;
%     a MARKER cannot be cut, it is in or it is out, and needs only this.
%     Both read the same rule, so a point cannot be inside for one
%     element and outside for another.
%
%   INPUTS
%     lon  (1,:) double  Degrees East.
%     lat  (1,:) double  Degrees North.
%     B    (1,1) struct  From GEO.INTERNAL.MAPBOUNDARY. Uses LonLim,
%                        LatLim and Crs.
%
%   OUTPUTS
%     tf   (1,:) logical  True where the coordinate is inside BOTH the
%                         extent and the projection's domain. NaN in
%                         gives false, which is what a gap should be.
%
%   ACCURACY
%     Exact, to a 1e-9-degree slack on each limit. The slack exists so a
%     vertex written AT a rim - lat 90, or a longitude that is the
%     extent's own boundary - is not excluded by the last bit of a
%     decimal conversion. It is a hundred-thousandth of the narrowest
%     step this toolbox draws, so nothing legitimately outside can reach
%     it.
%
%   ERRORS
%     None of its own; a malformed B fails in GEO.PROJECT.
%
%   EXAMPLE
%     B = geo.internal.mapBoundary(crs, lonLim, latLim);
%     keep = geo.internal.insideExtent(lon, lat, B);
%
%   See also GEO.INTERNAL.CLIPTOBOUNDARY, GEO.INTERNAL.MAPBOUNDARY.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

lon0 = mean(B.LonLim);
if diff(B.LonLim) >= 360 - 1e-9
    inLon = true(size(lon));            % a full turn excludes nothing
    % A SPAN test, and it works because PV-140 made the extent report
    % the REGION rather than the node range. Before that a global grid's
    % endpoints spanned 360 minus one step, the test never fired, and
    % the clip ate the last cell - which is why this briefly needed a
    % flag to disbelieve its own numbers.
else
    lonW = geo.wrapLongitude(lon, lon0);
    inLon = lonW >= B.LonLim(1) - 1e-9 & lonW <= B.LonLim(2) + 1e-9;
end
inLat = lat >= B.LatLim(1) - 1e-9 & lat <= B.LatLim(2) + 1e-9;
[x, y] = geo.project(lon, lat, B.Crs);
tf = inLon & inLat & isfinite(x) & isfinite(y);
end
