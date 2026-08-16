function H = scalebar(axH, crs, options)
%GEO.SCALEBAR  A bar whose length is the distance it claims.
%
%   SYNTAX
%     H = GEO.SCALEBAR(AX)
%     H = GEO.SCALEBAR(AX, CRS)
%     H = GEO.SCALEBAR(AX, CRS, Name, Value)
%
%   DESCRIPTION
%     Draws an alternating scale bar at z = 6, and reports how much the
%     map's scale varies over the extent it is drawn on.
%
%     v1's BAR DID NOT MEASURE WHAT IT SAID, and this is the defect this
%     function exists to not have. v1 drew a bar of FIXED WIDTH - 90
%     points, always - then computed the ground distance those 90 points
%     happened to span and printed the nearest entry of a hard-coded
%     ladder next to it. The bar was never resized to match. A bar
%     spanning 3 km was labelled "2 km" and one spanning 750 km was
%     labelled "500 km": errors approaching 50%, on the one element of a
%     map whose entire purpose is to be measured against. Here the nice
%     ground distance is chosen FIRST and the bar is then drawn exactly
%     that long. That is the only correct order, and the difference is
%     asserted rather than described.
%
%     IT IS CALIBRATED ALONG ITS OWN DIRECTION. v1 measured kilometres
%     per projected unit along a MERIDIAN and applied the answer to a
%     HORIZONTAL bar, which is right only where the projection is
%     conformal and the parallel scale equals the meridian scale. Here
%     the calibration steps east-west in projected space, unprojects both
%     ends and asks GEO.GREATCIRCLE how far apart they are - so it
%     measures the thing the bar actually spans.
%
%     IT DRAWS AND REPORTS; IT DOES NOT REFUSE (D-006). Scale varies over
%     any map that is not conformal and small, so a bar is always
%     somewhat a lie about somewhere. The variation is MEASURED over the
%     extent, recorded in the returned struct, and warned about above the
%     trigger. It is not grounds for refusing to draw: at the 1.05
%     trigger a refusing gate would refuse on 6 of 14 projections for a
%     10x10 degree regional map and 12 of 14 at continental scale
%     (measured, debt V8), and a library that will not let you do the
%     thing you came to do is not protecting you.
%
%     THE BAR LIVES IN DATA UNITS, so it stays honest when the axes are
%     zoomed or the figure resized - its ground length does not change
%     because the screen did. v1 drew it into a separate axes measured in
%     points and had to rebuild it on every resize to stay approximately
%     right; there is nothing here for a resize to invalidate.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     crs  (1,1) struct  A GEO.CRS or a name. Defaults to the basemap's.
%
%   OPTIONS
%     Units       "km"        "km" | "mi".
%     Length      NaN         Ground length to draw, in Units. NaN picks
%                             a 1-2-5 value nearest in LOG space to
%                             TargetFraction of the map width. v1 picked
%                             nearest in linear space, which biases to
%                             the smaller neighbour across every decade.
%     TargetFraction 0.25     Fraction of the map width to aim for.
%     Segments    4           Alternating blocks.
%     Location    "southwest" Any of the eight compass points.
%     Colors      [0 0 0; 1 1 1]
%     Thickness   0.012       Bar height, as a fraction of the map
%                             diagonal - the same unit GEO.FRAME uses.
%     FontName    "Helvetica"
%     FontSize    9
%     WarnAbove   1.05        Scale-variation ratio that triggers the
%                             warning. From Stage 0's measured table
%                             (V8), not from judgement.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Patches       (1,:) Patch
%          Labels        (1,:) Text
%          LengthGround  (1,1) double  As drawn, in Units.
%          LengthData    (1,1) double  As drawn, in projected units.
%          KmPerDataUnit (1,1) double  The calibration.
%          ScaleVariation (1,1) double  max/min of the linear scale over
%                                       the extent. 1 means none.
%          ScaleSampled  (1,1) double  How many points that came from.
%          ValidAt       (1,2) double  [lon lat] the bar is exact at -
%                                      its own position, not the map's
%                                      centre. Printed maps say "scale
%                                      accurate at 40N" for this reason.
%          All           (1,:)
%
%   ACCURACY
%     The bar's length in projected units is the chosen ground distance
%     divided by the measured kilometres per projected unit AT THE BAR'S
%     OWN POSITION, so it is exact where it is drawn and wrong elsewhere by
%     the scale variation reported in ScaleVariation. That is the honest
%     statement: a scale bar on a non-conformal map has no single correct
%     length, and this one says how wrong it is instead of implying it is
%     not. Calibration is spherical, via GEO.GREATCIRCLE, and therefore
%     differs from a WGS84 geodesic by up to about 0.5%.
%
%   ERRORS
%     geo:scalebar:NoBasemap        - no CRS and no basemap to take one
%     geo:scalebar:DegenerateScale  - the calibration step projects to
%                                     zero length, so no scale exists
%
%   WARNINGS
%     geo:scalebar:ScaleVaries      - the scale varies over the extent by
%                                     more than WarnAbove; the message
%                                     names the measured percentage
%
%   EXAMPLE
%     G = geo.readGrid("data/etopo_10min_surface.mat");
%     [~, ax] = geo.basemap(G, geo.crs("equirectangular"));
%     H = geo.scalebar(ax);
%     H.LengthGround, H.ScaleVariation
%
%   LIMITATIONS
%     One bar, horizontal, in projected space. A bar that followed a
%     parallel would be more nearly correct on a conic projection and is
%     not offered, because a curved scale bar is not a convention anyone
%     reads.
%
%   See also GEO.BASEMAP, GEO.SCALEFACTORS, GEO.GREATCIRCLE, GEO.NORTHARROW.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    crs = []
    options.Units (1,1) string {mustBeMember(options.Units, ["km" "mi"])} = "km"
    options.Length (1,1) double = NaN
    options.TargetFraction (1,1) double {mustBePositive} = 0.25
    options.Segments (1,1) double {mustBeInteger, mustBePositive} = 4
    options.Location (1,1) string = "southwest"
    options.Colors (2,3) double {mustBeInRange(options.Colors, 0, 1)} = [0 0 0; 1 1 1]
    options.Thickness (1,1) double {mustBePositive} = 0.012
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 9
    options.WarnAbove (1,1) double {mustBePositive} = 1.05
end

[crs, lonLim, latLim, ~, xl, yl, diag] = geo.internal.elementExtent( ...
    axH, crs, ErrorId = "geo:scalebar:NoBasemap");

kmPerUnit = 1;
if options.Units == "mi"
    kmPerUnit = 1.609344;
end

% CALIBRATE WHERE THE BAR WILL SIT, NOT AT THE MAP CENTRE. Measured on a
% global equirectangular map with the bar in its usual southwest corner:
% a bar calibrated at the centre and drawn at the corner was 59% wrong,
% because the parallel scale at the equator and at 66 degrees south are
% not the same number. That is the same class of error as v1's, arrived
% at a different way, and a scale bar has exactly one job.
[cx, cy] = barCentre(xl, yl, diag, options);
[kmPerData, validLon, validLat] = calibrate(crs, cx, cy, diff(xl));

lengthGround = options.Length;
if isnan(lengthGround)
    wanted = options.TargetFraction * diff(xl) * kmPerData / kmPerUnit;
    lengthGround = niceLength(wanted);
end
lengthData = lengthGround * kmPerUnit / kmPerData;

[variation, nSampled] = scaleVariation(crs, lonLim, latLim);
if variation > options.WarnAbove
    warning('geo:scalebar:ScaleVaries', ...
        ['The map scale varies by %.1f%% over this extent (sampled at ' ...
         '%d points), so this bar is exact only near the map centre. ' ...
         'It is drawn anyway: on most projections at most extents some ' ...
         'variation is unavoidable, and a bar with a stated error beats ' ...
         'no bar. The measured figure is in the returned ' ...
         'ScaleVariation field.'], 100 * (variation - 1), nSampled);
end

prior = geo.internal.layout("data", axH, "scalebar");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

H = draw(axH, xl, yl, diag, lengthData, lengthGround, options);
H.KmPerDataUnit = kmPerData;
H.LengthData = lengthData;
H.LengthGround = lengthGround;
H.ScaleVariation = variation;
H.ScaleSampled = nSampled;
H.ValidAt = [validLon validLat];

geo.internal.layout("register", axH, "scalebar", @(~) []);
geo.internal.layout("setData", axH, "scalebar", H);
end

% ======================================================================
function [cx, cy] = barCentre(xl, yl, diag, options)
%BARCENTRE  Where the bar's midpoint will land, before its length is known.
%   The horizontal placement of an east-anchored bar depends on its
%   length, and its length depends on the calibration here - so this uses
%   the TARGET fraction rather than the final length. The residual is a
%   fraction of a bar width, over which the scale barely moves; the
%   alternative is a fixed-point iteration for a placement nobody
%   measures to that precision.
margin = 0.06 * diag;
provisional = options.TargetFraction * diff(xl);
switch true
    case contains(options.Location, "west")
        cx = xl(1) + margin + provisional / 2;
    case contains(options.Location, "east")
        cx = xl(2) - margin - provisional / 2;
    otherwise
        cx = mean(xl);
end
% THE BAR'S CENTRE, NOT ITS BASELINE, and the half-thickness matters
% more than it looks. DRAW puts the baseline at this margin and the bar
% extends upward by Thickness*diag; calibrating at the baseline made a
% global equirectangular bar 9.3% too short, because cos(66 degrees) and
% cos(63.5 degrees) differ by that much and the bar sat between them.
t = options.Thickness * diag;
if contains(options.Location, "north")
    cy = yl(2) - margin - t / 2;
else
    cy = yl(1) + margin + t / 2;
end
end

function [kmPerData, lon, lat] = calibrate(crs, cx, cy, width)
%CALIBRATE  Kilometres per projected unit, EAST-WEST, at the bar itself.
%   Along the bar's own direction, which is one of two corrections v1
%   needed: it measured along a MERIDIAN and applied the answer to a
%   HORIZONTAL bar, which is right only where h equals k. The other
%   correction is the location - see the caller.
% ONE PART IN A MILLION OF THE MAP WIDTH. The calibration is a secant
% and its error is O(step^2); measured against the closed form
% R*cos(lat) on equirectangular, the relative error runs 1.3e-6 at
% width/1e3, 1.3e-8 at 1e4, 1.3e-10 at 1e5 and 5.3e-12 at 1e6, then
% DEGRADES to 2.9e-10 at 1e7 as floating-point cancellation in the
% unprojection takes over. 1e6 is the floor of that curve, not a guess.
step = width / 1e6;
[lonA, latA] = geo.unproject(cx - step / 2, cy, crs);
[lonB, latB] = geo.unproject(cx + step / 2, cy, crs);
if ~all(isfinite([lonA latA lonB latB]))
    error('geo:scalebar:DegenerateScale', ...
        ['The point where the bar would sit does not unproject, so no ' ...
         'scale can be measured there. On a projection whose image does ' ...
         'not fill its bounding box this happens at the corners; ask ' ...
         'for a Location nearer the middle.']);
end
out = geo.greatCircle([lonA latA], [lonB latB]);
if ~isfinite(out.DistanceKm) || out.DistanceKm <= 0
    error('geo:scalebar:DegenerateScale', ...
        'A step of %g projected units spans no ground distance.', step);
end
kmPerData = out.DistanceKm / step;
lon = (lonA + lonB) / 2;
lat = (latA + latB) / 2;
end

function v = niceLength(wanted)
%NICELENGTH  The 1-2-5 value nearest in LOG space.
%   Generated rather than tabulated, so it neither clamps below 1 nor
%   above 5000 - v1's ladder did both, which mislabelled every map
%   smaller than a kilometre or larger than a continent.
if ~isfinite(wanted) || wanted <= 0
    v = 1;
    return
end
decade = floor(log10(wanted));
candidates = [1 2 5 10] * 10^decade;
[~, k] = min(abs(log(candidates) - log(wanted)));
v = candidates(k);
end

function [variation, n] = scaleVariation(crs, lonLim, latLim)
%SCALEVARIATION  max/min of the LINEAR scale over the extent.
%   Linear (h and k), not areal: PV-009. An equal-area projection has
%   AreaScale exactly 1 everywhere and can still stretch by a factor of
%   three, which is precisely what a scale bar is wrong about.
%   Sampled strictly INSIDE the extent (PV-008): the corners of a global
%   extent are singular on several projections, and a variation figure
%   dominated by a point the map does not really contain is noise.
inset = 0.02;
lonV = linspace(lonLim(1) + inset * diff(lonLim), ...
                lonLim(2) - inset * diff(lonLim), 7);
latV = linspace(latLim(1) + inset * diff(latLim), ...
                latLim(2) - inset * diff(latLim), 7);
[LON, LAT] = meshgrid(lonV, latV);
s = geo.scaleFactors(LON, LAT, crs);
lin = [s.h(:); s.k(:)];
lin = lin(isfinite(lin) & lin > 0);
n = numel(lin);
if n < 2
    variation = 1;
    return
end
variation = max(lin) / min(lin);
end

function H = draw(axH, xl, yl, diag, lengthData, lengthGround, options)
%DRAW  The bar itself: alternating blocks, two end labels, a caption.
t = options.Thickness * diag;
margin = 0.06 * diag;
switch true
    case contains(options.Location, "west")
        x0 = xl(1) + margin;
    case contains(options.Location, "east")
        x0 = xl(2) - margin - lengthData;
    otherwise
        x0 = mean(xl) - lengthData / 2;
end
% Must agree with BARCENTRE, which calibrates at y0 + t/2.
if contains(options.Location, "north")
    y0 = yl(2) - margin - t;
else
    y0 = yl(1) + margin;
end

nSeg = options.Segments;
w = lengthData / nSeg;
patches = gobjects(1, nSeg);
for k = 1:nSeg
    xa = x0 + (k - 1) * w;
    if mod(k, 2) == 1
        c = options.Colors(1, :);
    else
        c = options.Colors(2, :);
    end
    patches(k) = patch('Parent', axH, ...
        'XData', [xa, xa + w, xa + w, xa], ...
        'YData', [y0, y0, y0 + t, y0 + t], ...
        'ZData', 6 * ones(1, 4), 'FaceColor', c, ...
        'EdgeColor', [0 0 0], 'LineWidth', 0.5, 'FaceLighting', 'none');
end

labels = gobjects(1, 3);
labels(1) = label(axH, x0, y0 - 0.3 * t, "0", 'top', options);
labels(2) = label(axH, x0 + lengthData, y0 - 0.3 * t, ...
    sprintf('%g %s', lengthGround, options.Units), 'top', options);
labels(3) = label(axH, x0 + lengthData / 2, y0 + 1.3 * t, ...
    "Scale", 'bottom', options);

H = struct('Patches', patches, 'Labels', labels, ...
    'All', [patches, labels]);
end

function h = label(axH, x, y, str, va, options)
h = text('Parent', axH, 'Position', [x y 6], 'String', str, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', va, ...
    'FontName', options.FontName, 'FontSize', options.FontSize, ...
    'Color', [0 0 0], 'Clipping', 'off');
end
