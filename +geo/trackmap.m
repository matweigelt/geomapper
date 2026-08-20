function H = trackmap(T, crs, varargin)
%GEO.TRACKMAP  A track over topography, with the extent worked out for you.
%
%   L4-FRONT
%
%   SYNTAX
%     H = GEO.TRACKMAP(T)
%     H = GEO.TRACKMAP(T, CRS)
%     H = GEO.TRACKMAP(T, CRS, Name, Value)
%
%   DESCRIPTION
%     The one-call front for along-track data. It decides where the map
%     is, fetches a background, and hands the whole thing to GEO.MAP -
%     which draws it. It adds an extent and a backdrop and nothing else.
%
%     IT IS GEO.MAP PLUS TWO DECISIONS, and that is deliberate. v1's
%     geoImagescTrack was a 75-option near-clone of geoImagesc; the two
%     shared a defect list and had to be repaired twice, which is F8
%     seen from the side. Here every option this file does not own is
%     forwarded to GEO.MAP untouched, so the option surface has one home
%     and this file has no table of its own.
%
%     THE EXTENT HAS A PRECEDENCE: explicit LonLimit/LatLimit beat
%     Region, and Region beats the track's own bounding box padded by
%     Pad. The pad applies only to the automatic box - limits and a
%     Region are what the caller asked for, and enlarging those would
%     mean the map does not show the extent its own arguments name.
%
%   INPUTS
%     T    A GEO.TRACK, or anything GEO.TRACK accepts.
%     crs  A GEO.CRS or a projection name. Empty gives equirectangular
%          centred on the map, which is a neutral choice for a regional
%          extent and is stated rather than assumed.
%
%   OPTIONS
%     Owned by this function:
%
%     Pad         0.05   Margin around the track's bounding box, as a
%                        fraction of its span, applied through
%                        GEO.REGION's own Padding.
%     Region      []     A GEO.REGION or anything it accepts. Overrides
%                        the automatic box.
%     LonLimit    []     Explicit limits. Override everything.
%     LatLimit    []
%     Background  true   true for the builtin topography, false for a
%                        flat backdrop, or a GEO.GRID of your own.
%     BackgroundResolution 300  Target cells across the longer side. The
%                        resample never asks for more cells than the
%                        source window has.
%
%     Everything else is GEO.MAP's - Graticule, Coastline, Colorbar,
%     Frame, ScaleBar, NorthArrow, Inset, Title, Export and the rest -
%     and is forwarded unchanged, including Track itself, so
%     Track = struct(Style = "bicolor") configures the overlay while
%     this function supplies its data.
%
%   OUTPUTS
%     H  (1,1) struct  GEO.MAP's, with two fields added:
%          Region  (1,1) struct  The GEO.REGION the map covers.
%          Grid    (1,1) struct  The background GEO.GRID drawn.
%
%   ACCURACY
%     One claim, and it is asserted on the returned limits: the
%     automatic extent CONTAINS every finite track point, and the margin
%     on each side equals Pad times that side's span. A map that clipped
%     the track it was built for would be worse than no map.
%
%   ERRORS
%     geo:mapBackdrop:NoFinitePoints - the track has no finite position
%     (everything else is raised by GEO.MAP or by the elements)
%
%   EXAMPLE
%     T = geo.track(lon, lat, Obs = residual, Units = "cm");
%     H = geo.trackmap(T, Title = "Ascending pass 042", ...
%         Track = struct(Style = "bicolor"), ScaleBar = true);
%
%   LIMITATIONS
%     The automatic box is min-to-max in longitude, so a track crossing
%     the antimeridian gets a box the wide way round the world. Give
%     LonLimit = [170 190] for those; GEO.REGION documents the
%     convention and it passes through unchanged.
%
%   See also GEO.MAP, GEO.TRACK, GEO.OVERLAYTRACK, GEO.POINTMAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    T
    crs = []
end
arguments (Repeating)
    varargin
end

T = geo.track(T);
[own, rest] = geo.internal.splitOptions(varargin, ...
    geo.internal.backdropOptions());
[R, G, crs] = geo.internal.mapBackdrop([T.Lon(:) T.Lat(:)], crs, own);
rest = geo.internal.withData(rest, "Track", struct('T', T));

H = geo.map(G, crs, rest{:});
H.Region = R;
H.Grid = G;
end
