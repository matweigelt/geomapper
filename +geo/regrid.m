function out = regrid(src, lonQ, latQ, options)
%GEO.REGRID  Resample a grid, periodically, and conservatively if asked.
%
%   SYNTAX
%     G2 = GEO.REGRID(G, LONQ, LATQ)
%     G2 = GEO.REGRID(G, LONQ, LATQ, Method = "conservative")
%
%   DESCRIPTION
%     Ported from v1's geoResampleGrid with two upgrades: it is periodic
%     in longitude, and it can conserve mass.
%
%     F4, PERIODICITY. v1 rewrapped and sorted its longitudes, then built
%     a griddedInterpolant with 'nearest' extrapolation - so a query past
%     the last column returned the value AT that column rather than
%     interpolating across the seam. Measured on the installed v1: a query
%     at longitude 179.5 on a 0:359 source returned the value at 179
%     exactly, where the correct bilinear answer is the midpoint between
%     179 and -180. Silently, with no NaN and no warning. The repair is to
%     pad one wrapped column on each side before interpolating, and it
%     applies only when the source actually spans the circle - which
%     GEO.GRID has already measured into IsGlobalLon.
%
%     CONSERVATIVE REGRIDDING, and why bilinear is not enough. Bilinear
%     resampling of a mass field does not conserve mass: the total after
%     resampling differs from the total before, so a coarsened EWH map no
%     longer integrates to the same water. First-order area-weighted
%     remapping does conserve, exactly in exact arithmetic. The weight of
%     a source cell in a target cell is (longitude overlap) x (overlap in
%     SIN latitude), which is the true spherical cell area and is
%     separable - so the two-dimensional weight matrix is never formed,
%     and the remap is two sparse products.
%
%     WEIGHTING LATITUDE IN DEGREES INSTEAD OF SIN(LATITUDE) is the
%     classic error here. It over-weights polar cells by 1/cos(lat) and
%     conserves nothing, and it is invisible on a regional map. The
%     mirror's analytic check discriminates the two by twelve orders of
%     magnitude and is what certifies this implementation.
%
%   INPUTS
%     src   (1,1) struct  A GEO.GRID.
%     lonQ  (1,:) double  Target longitudes, ascending.
%     latQ  (:,1) double  Target latitudes.
%
%   OPTIONS
%     Method  (1,1) string  ["bilinear"]  "bilinear" | "conservative" |
%                                         "nearest".
%
%   OUTPUTS
%     out  (1,1) struct  A GEO.GRID on the target axes, carrying the
%                        source's Source and Units.
%
%   ACCURACY
%     MASS CLOSURE, conservative method: better than 1e-13 relative. That
%     tolerance is MEASURED, not chosen - handover debt V7 forbade
%     asserting the document's 1e-12 guess. The mirror measured the
%     achievable double-precision floor at production size,
%     2161x4321 -> 181x361, over three summation orders: pairwise
%     2.15e-14, naive 1.65e-14, correctly-rounded 6.48e-15. The asserted
%     tolerance sits one decade above the worst, which is TIGHTER than the
%     guess it replaced.
%
%     The weights are certified against an analytic oracle: for a field
%     affine in (lon, sin lat) the area-weighted cell mean has a closed
%     form, reproduced to 7.1e-15.
%
%     SEAM, bilinear: a 0:359 source queried at -0.5 returns the exact
%     midpoint of its two straddling columns, to 1e-12. v1 fails this.
%
%   ERRORS
%     Input geometry:
%       geo:regrid:NotAGrid        - src is not a GEO.GRID
%       geo:regrid:NonUniformAxis  - conservative regridding needs uniform
%                                    axes to derive cell edges from
%     Method is validated by MUSTBEMEMBER in the ARGUMENTS block, so an
%     unknown one fails with MATLAB's own identifier and a message that
%     lists the three. No geo:* twin is coined for it.
%
%   EXAMPLE
%     G2 = geo.regrid(G, -179.5:179.5, (-89.5:89.5).', ...
%                     Method = "conservative");
%
%   LIMITATIONS
%     Rectilinear to rectilinear only. The conservative path derives cell
%     EDGES by bisecting the given centres, so it assumes the axes are
%     cell centres of a uniform grid; a grid whose cells vary in width is
%     rejected rather than silently mis-weighted.
%
%   See also GEO.GRID, GEO.HILLSHADE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    src (1,1) struct
    lonQ (1,:) double {mustBeReal}
    latQ (:,1) double {mustBeReal}
    options.Method (1,1) string ...
        {mustBeMember(options.Method, ...
            ["bilinear" "conservative" "nearest"])} = "bilinear"
end

geo.internal.mustBeIdentity(src, "geo.grid", 'geo:regrid:NotAGrid');

if options.Method == "conservative"
    Zi = conservative(src, lonQ, latQ);
else
    Zi = pointwise(src, lonQ, latQ, options.Method);
end

out = geo.grid(lonQ, latQ, Zi, Source = src.Source, Units = src.Units);
end

% ======================================================================
function Zi = pointwise(src, lonQ, latQ, method)
%POINTWISE  Bilinear or nearest, with the seam padded when it exists.
lon = src.Lon(:).';
lat = src.Lat(:);
Z = src.Z;

% Latitude must ascend for griddedInterpolant; a descending axis is
% legitimate input and is flipped here, not at the caller.
if lat(end) < lat(1)
    lat = flipud(lat);
    Z = flipud(Z);
end

% F4: pad one wrapped column each side, but only if the source really
% closes the circle. IsGlobalLon was MEASURED by geo.grid from the
% coordinate vector, so this decision is not a guess either.
if src.IsGlobalLon
    step = abs(src.LonStep);
    lon = [lon(end) - 360, lon, lon(1) + 360];
    Z = [Z(:, end), Z, Z(:, 1)];
    % A source stored 0:360 repeats its seam; the pad then duplicates a
    % coordinate and griddedInterpolant refuses. Drop the duplicate.
    keep = [true, diff(lon) > step * 1e-6];
    lon = lon(keep);
    Z = Z(:, keep);
end

% The PUBLIC name is "bilinear", because that is what it is called on a
% two-dimensional grid and what v1's users will look for. MATLAB's
% interpolant calls the same thing 'linear'. Translated here, once,
% rather than exposing MATLAB's spelling in this toolbox's option list.
if method == "bilinear"
    mlMethod = 'linear';
else
    mlMethod = char(method);
end
F = griddedInterpolant({lat, lon(:)}, Z, mlMethod, 'none');
[LQ, AQ] = meshgrid(lonQ, latQ);
% Queries are wrapped into the source's own window, so a caller asking
% for -0.5 against a 0:359 source lands inside the padded hull.
LQ = geo.wrapLongitude(LQ, mean(lon([1 end])));
Zi = F(AQ, LQ);
end

function Zi = conservative(src, lonQ, latQ)
%CONSERVATIVE  First-order area-weighted remap. Separable by construction.
srcLonE = edgesOf(src.Lon(:).', 'geo:regrid:NonUniformAxis');
srcLatE = edgesOf(src.Lat(:).', 'geo:regrid:NonUniformAxis');
dstLonE = edgesOf(lonQ, 'geo:regrid:NonUniformAxis');
dstLatE = edgesOf(latQ(:).', 'geo:regrid:NonUniformAxis');

% Latitude overlap in SIN latitude: true spherical cell area. Weighting
% in degrees over-weights polar cells by 1/cos(lat) and conserves nothing.
Wlat = overlap(sind(srcLatE), sind(dstLatE));
Wlon = overlap(srcLonE, dstLonE);

Z = src.Z;
gap = isnan(Z);
Zf = Z;
Zf(gap) = 0;

num = Wlat * Zf * Wlon.';
% NaN sources are excluded and the weights renormalised, so a partly
% masked target cell reports the mean of what it actually saw rather
% than a value diluted towards zero by the gap.
den = Wlat * double(~gap) * Wlon.';
Zi = num ./ den;
Zi(den <= 0) = NaN;
end

function W = overlap(srcE, dstE)
%OVERLAP  Sparse (P,M) matrix of 1-D interval overlap lengths.
lo = max(dstE(1:end-1).', srcE(1:end-1));
hi = min(dstE(2:end).', srcE(2:end));
W = sparse(max(hi - lo, 0));
end

function e = edgesOf(c, errId)
%EDGESOF  Cell edges from centres, uniformity asserted not assumed.
d = diff(c);
if ~all(abs(d - d(1)) <= abs(d(1)) * 1e-9)
    error(errId, ...
        ['Conservative regridding derives cell edges by bisecting the ' ...
         'centres, which assumes a uniform axis. This one varies from ' ...
         '%g to %g. A non-uniform axis is rejected rather than ' ...
         'mis-weighted silently.'], min(d), max(d));
end
e = [c(1) - d(1)/2, c + d(1)/2];
end
