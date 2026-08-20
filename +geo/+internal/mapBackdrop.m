function [R, G, crs] = mapBackdrop(lonlat, crs, own)
%GEO.INTERNAL.MAPBACKDROP  The extent and background a data map sits on.
%
%   SYNTAX
%     [R, G, crs] = GEO.INTERNAL.MAPBACKDROP(LON, LAT, CRS, OWN)
%
%   DESCRIPTION
%     Given the coordinates of the data to be shown, decides WHERE the
%     map is and WHAT is underneath it. Shared by GEO.TRACKMAP and
%     GEO.POINTMAP so the two cannot drift - v1's geoImagescTrack and
%     geoImagescPoints each carried their own copy of this, and the two
%     copies disagreed about the pad.
%
%     THE EXTENT HAS A PRECEDENCE, and it is stated rather than
%     discovered: explicit LonLimit/LatLimit beat Region, and Region
%     beats the data's own bounding box. Each level is a stronger
%     statement of intent than the one below it, and a caller who gives
%     two of them means the more specific one.
%
%     THE PAD IS A FRACTION OF THE SPAN, applied through GEO.REGION's
%     own Padding so there is one padding rule in the toolbox rather
%     than a second one here. It applies ONLY to the data bounding box:
%     limits and a Region are what the caller asked for, and quietly
%     enlarging them would mean the map does not show the extent its
%     own arguments name.
%
%     THE BACKGROUND IS READ, NOT COMPUTED. GEO.READGRID fetches the
%     builtin topography for the window and GEO.REGRID resamples it -
%     both public, both tested, neither reimplemented here. That is what
%     "orchestration, not engine" means for a front: v1 buried its
%     topography reading in geoImagesc's locals, which is why the same
%     reading had to be written again in two more files.
%
%     IT WILL NOT INVENT CELLS. BackgroundResolution is a target, and
%     the resample never asks for more cells than the source window
%     actually has. Upsampling topography makes a smoother picture out
%     of no more information, and a map that looks finer than its data
%     is a map that lies about its resolution.
%
%   INPUTS
%     lonlat  (:,2) double  The data's coordinates, one row per point.
%                           NaNs are ignored. One argument rather than
%                           two because D-003 caps positional arity at
%                           three and the coordinates are one fact.
%     crs  A GEO.CRS, a name, or empty for a default centred on the map.
%     own  (1,1) struct  Any of: LonLimit, LatLimit, Region, Pad,
%                        Background, BackgroundResolution. A field that
%                        is absent means "not given", which is why this
%                        takes a sparse struct rather than a defaulted one.
%
%   OUTPUTS
%     R    (1,1) struct  The GEO.REGION actually used.
%     G    (1,1) struct  The background GEO.GRID.
%     crs  (1,1) struct  The GEO.CRS actually used.
%
%   ACCURACY
%     One claim, and GEO.TRACKMAP's help states it as a promise: the
%     auto extent CONTAINS every finite data point, and the margin on
%     each side equals Pad times that side's data span. Both halves are
%     asserted on the returned limits.
%
%   ERRORS
%     geo:mapBackdrop:NoFinitePoints - nothing to put a map around
%
%   EXAMPLE
%     [R, G, crs] = geo.internal.mapBackdrop([T.Lon(:) T.Lat(:)], [], ...
%         struct('Pad', 0.1));
%
%   LIMITATIONS
%     The bounding box is min-to-max in longitude, so a data set
%     spanning the antimeridian gets a box the wide way round the world.
%     Give explicit limits or a Region for those - GEO.REGION documents
%     the [170 190] convention, and this passes it through unchanged.
%
%   See also GEO.TRACKMAP, GEO.POINTMAP, GEO.REGION, GEO.READGRID, GEO.REGRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lonlat (:,2) double
    crs = []
    own (1,1) struct = struct()
end

R = resolveRegion(lonlat(:, 1).', lonlat(:, 2).', own);
G = backgroundFor(R, own);
crs = resolveCrs(crs, R);
end

% ======================================================================
function R = resolveRegion(lon, lat, own)
%RESOLVEREGION  Explicit limits, then Region, then the data's own box.
if isfield(own, 'LonLimit') || isfield(own, 'LatLimit')
    lonLim = fieldOr(own, 'LonLimit', dataLim(lon, 'longitude'));
    latLim = fieldOr(own, 'LatLimit', dataLim(lat, 'latitude'));
    R = geo.region([lonLim(:).' latLim(:).']);
    return
end
if isfield(own, 'Region') && ~isempty(own.Region)
    R = geo.region(own.Region);
    return
end
% THE TWO CORNERS AS AN OUTLINE, NOT A 1x4 BOX, and the difference is
% not cosmetic. GEO.REGION applies Padding to an OUTLINE and silently
% ignores it on a box - measured: geo.region([-20 40 12.7 50], Padding =
% 0.05) came back with those limits unchanged and Padding recorded as
% 0.05, so the pad asked for here was exactly zero on both axes
% (PV-116). Passing the corners as the outline they are uses the
% toolbox's one padding rule instead of writing a second one here.
lonLim = dataLim(lon, 'longitude');
latLim = dataLim(lat, 'latitude');
corners = [lonLim(1) latLim(1); lonLim(2) latLim(2)];
R = geo.region(corners, Padding = fieldOr(own, 'Pad', 0.05));
end

function lim = dataLim(v, what)
%DATALIM  Finite min and max, and a real error when there are none.
v = v(isfinite(v));
if isempty(v)
    error('geo:mapBackdrop:NoFinitePoints', ...
        ['No finite %s to put a map around. Give LonLimit and ' ...
         'LatLimit, or a Region.'], what);
end
lim = [min(v) max(v)];
if lim(1) == lim(2)
    % A single point has no span, so a fractional pad is zero and the
    % map has no extent at all. Half a degree is arbitrary and is
    % therefore stated: it is a legible neighbourhood, not a measurement.
    lim = lim + [-0.5 0.5];
end
end

function G = backgroundFor(R, own)
%BACKGROUNDFOR  Builtin topography, a caller's own field, or nothing.
want = fieldOr(own, 'Background', true);
if isstruct(want)
    G = geo.readGrid(want, Region = R);
    return
end
if isequal(want, false)
    % A flat backdrop, so the overlay is read against the graticule and
    % the coastline alone. Two cells each way is enough for a surface
    % and carries no information it does not have.
    G = geo.grid(R.LonLim, R.LatLim, zeros(2, 2));
    return
end
src = geo.readGrid("builtin", Region = R);
G = resample(src, R, fieldOr(own, 'BackgroundResolution', 300));
end

function G = resample(src, R, target)
%RESAMPLE  To the target size, but never finer than the source.
n = numel(src.Lon);
m = numel(src.Lat);
span = [diff(R.LonLim) diff(R.LatLim)];
if span(1) >= span(2)
    nx = min(n, round(target));
    ny = max(2, min(m, round(nx * span(2) / span(1))));
else
    ny = min(m, round(target));
    nx = max(2, min(n, round(ny * span(1) / span(2))));
end
if nx >= n && ny >= m
    G = src;                            % already at or below the target
    return
end
G = geo.regrid(src, linspace(R.LonLim(1), R.LonLim(2), nx), ...
    linspace(R.LatLim(1), R.LatLim(2), ny).');
end

function crs = resolveCrs(crs, R)
%RESOLVECRS  The caller's, or one centred on the map.
if isstruct(crs)
    return
end
if ~isempty(crs)
    crs = geo.crs(crs, CenterLongitude = mean(R.LonLim));
    return
end
crs = geo.crs("equirectangular", CenterLongitude = mean(R.LonLim));
end

function v = fieldOr(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end
