function [xy, clip] = clipToExtent(xy, crs, lonLim, options)
%GEO.INTERNAL.CLIPTOEXTENT  Cut geographic vertices at the frame.
%
%   SYNTAX
%     [XY, CLIP] = GEO.INTERNAL.CLIPTOEXTENT(XY, CRS, LONLIM, LATLIM = ...)
%
%   DESCRIPTION
%     Builds the boundary once and hands the vertices to
%     GEO.INTERNAL.CLIPTOBOUNDARY. Promoted out of GEO.COASTLINE when the
%     overlays needed the same three lines (PV-142); five near-copies of
%     a clip is defect F12 with five chances to drift instead of two.
%
%     Reports EXTENTCUTS, not NumCuts. NumCuts already means "branch cuts
%     broken" - antimeridian jumps found by GEO.INTERNAL.PROJECTPOLYLINE -
%     and one name carrying two meanings across two files is the aliasing
%     that one-name-per-thing forbids.
%
%     A part that leaves the frame and returns is TWO parts afterwards.
%     That is the cut working, not a defect, and every caller reporting a
%     part count says so in its own help.
%
%   INPUTS
%     xy      (:,2) double  Lon in column 1, lat in column 2, NaN-separated.
%     crs     (1,1) struct  From GEO.CRS.
%     lonLim  (1,2) double  Degrees East, from GEO.INTERNAL.ELEMENTEXTENT.
%
%   OPTIONS
%     LatLim  (1,2) double  Degrees North. A name-value rather than a
%                           fourth positional: the arity limit is three,
%                           and a limit pair reads better named than
%                           counted anyway.
%
%   OUTPUTS
%     xy      (:,2) double  Cut at the frame, with a crossing vertex
%                           inserted on the extent's own edge.
%     clip    (1,1) struct  Fields:
%               ClippedToExtent (1,1) logical  Whether anything was cut.
%               ExtentCuts      (1,1) double   Crossings, one vertex each.
%               ExtentKept      (1,1) double   Vertices inside, before cuts.
%
%   ACCURACY
%     The crossing is bisected in lon/lat to 16 halvings, which puts it
%     under a thousandth of a screen pixel on any map this draws. See
%     GEO.INTERNAL.CLIPTOBOUNDARY for the measurement.
%
%   ERRORS
%     None of its own.
%
%   EXAMPLE
%     [xy, clip] = geo.internal.clipToExtent(xy, crs, lonLim, ...
%             LatLim = latLim);
%
%   See also GEO.INTERNAL.CLIPTOBOUNDARY, GEO.INTERNAL.MAPBOUNDARY.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    xy (:,2) double
    crs (1,1) struct
    lonLim (1,2) double
    options.LatLim (1,2) double = [-90 90]
end

B = geo.internal.mapBoundary(crs, [lonLim(1) lonLim(2)], ...
    [options.LatLim(1) options.LatLim(2)]);
[lon, lat, info] = geo.internal.clipToBoundary(xy(:, 1).', xy(:, 2).', B);
clip = struct('ClippedToExtent', info.Clipped, ...
    'ExtentCuts', info.NumCuts, 'ExtentKept', info.NumInside);
if info.Clipped
    xy = [lon(:), lat(:)];
end
end
