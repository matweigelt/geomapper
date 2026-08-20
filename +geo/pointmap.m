function H = pointmap(P, crs, varargin)
%GEO.POINTMAP  Scattered stations over topography, extent worked out for you.
%
%   L4-FRONT
%
%   SYNTAX
%     H = GEO.POINTMAP(P)
%     H = GEO.POINTMAP(P, CRS)
%     H = GEO.POINTMAP(P, CRS, Name, Value)
%
%   DESCRIPTION
%     The one-call front for scattered locations. It decides where the
%     map is, fetches a background, and hands the whole thing to
%     GEO.MAP. It adds an extent and a backdrop and nothing else.
%
%     IT IS THE SAME FUNCTION AS GEO.TRACKMAP WITH ONE WORD CHANGED,
%     and that is visible rather than hidden: both are six lines over
%     GEO.INTERNAL.MAPBACKDROP and GEO.MAP. v1's geoImagescPoints was
%     an 82-option near-clone of geoImagesc carrying its own copy of the
%     extent logic, the topography reading and the colorbar - and the
%     copy of the extent logic disagreed with geoImagescTrack's about
%     the pad. One shared internal is the entire difference.
%
%     THE EXTENT HAS A PRECEDENCE: explicit LonLimit/LatLimit beat
%     Region, and Region beats the points' own bounding box padded by
%     Pad.
%
%   INPUTS
%     P    A GEO.POINTS, or anything GEO.POINTS accepts.
%     crs  A GEO.CRS or a projection name. Empty gives equirectangular
%          centred on the map.
%
%   OPTIONS
%     Owned by this function: Pad, Region, LonLimit, LatLimit,
%     Background, BackgroundResolution - all as documented in
%     GEO.TRACKMAP, because they are the same options resolved by the
%     same function.
%
%     Everything else is GEO.MAP's and is forwarded unchanged, including
%     Points itself, so Points = struct(SizeRange = [10 200]) configures
%     the overlay while this function supplies its data.
%
%   OUTPUTS
%     H  (1,1) struct  GEO.MAP's, with Region and Grid added.
%
%   ACCURACY
%     The automatic extent contains every finite point and the margin on
%     each side equals Pad times that side's span, asserted on the
%     returned limits.
%
%   ERRORS
%     geo:mapBackdrop:NoFinitePoints - no point has a finite position
%
%   EXAMPLE
%     P = geo.points(lon, lat, Obs = trend, SizeData = sigma);
%     H = geo.pointmap(P, Colorbar = struct(Label = "cm/yr"), ...
%         Points = struct(LegendLabel = "sigma (cm)"));
%
%   LIMITATIONS
%     As GEO.TRACKMAP: the automatic box is min-to-max in longitude, so
%     a set spanning the antimeridian needs explicit limits.
%
%   See also GEO.MAP, GEO.POINTS, GEO.OVERLAYPOINTS, GEO.TRACKMAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    P
    crs = []
end
arguments (Repeating)
    varargin
end

P = geo.points(P);
[own, rest] = geo.internal.splitOptions(varargin, ...
    geo.internal.backdropOptions());
[R, G, crs] = geo.internal.mapBackdrop([P.Lon(:) P.Lat(:)], crs, own);
rest = geo.internal.withData(rest, "Points", struct('P', P));

H = geo.map(G, crs, rest{:});
H.Region = R;
H.Grid = G;
end
