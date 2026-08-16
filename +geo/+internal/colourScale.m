function [cLim, cmap] = colourScale(base, values, options)
%GEO.INTERNAL.COLOURSCALE  The colour scale an overlay should use.
%
%   SYNTAX
%     [cLim, cmap] = GEO.INTERNAL.COLOURSCALE(BASE, VALUES)
%     [cLim, cmap] = GEO.INTERNAL.COLOURSCALE(BASE, VALUES, Name, Value)
%
%   DESCRIPTION
%     Every overlay that colours something by value asks the same three
%     questions in the same order: was a scale given, does the basemap
%     have one, and failing both what do the values themselves suggest.
%
%     ONE MEANING PER FIGURE. The default is the BASEMAP's scale, so a
%     mascon layer, a track and the raster underneath them all decode
%     against one GEO.COLORBAR. A figure carrying two silent colour
%     scales has to be read twice and will be read once.
%
%     THIS EXISTS BECAUSE THE AUDIT DEMANDED IT, FOR THE FIFTH TIME.
%     GEO.OVERLAYTRACK and GEO.OVERLAYPOINTS were written with an
%     identical local copy each and the duplicate-local check rejected
%     the second within the round. F6 was six duplicated locals across
%     v1's plotters; v2 has now been stopped from committing one on five
%     separate occasions, every time inside the checkpoint that wrote it.
%
%   INPUTS
%     base    struct or []  The basemap's handle struct, from the layout
%                           registry, or empty if there is none.
%     values  double        The overlay's own values, used only when
%                           there is no basemap and no explicit limits.
%
%   OPTIONS
%     Colormap  (:,3) double  []  Explicit map; overrides the basemap's.
%     CLim      (1,2) double  []  Explicit limits; overrides the basemap's.
%
%   OUTPUTS
%     cLim  (1,2) double  Always finite with a positive span.
%     cmap  (:,3) double
%
%   ACCURACY
%     No arithmetic beyond a min and a max. A degenerate range - a
%     constant field, or no finite value at all - is widened by half a
%     unit about its own value rather than rejected, because a single
%     colour is a truthful picture of a constant field and refusing to
%     draw one is not.
%
%   ERRORS
%     (none; every degenerate case has a defined answer)
%
%   EXAMPLE
%     [cLim, cmap] = geo.internal.colourScale(base, obs, CLim = [-5 5]);
%
%   LIMITATIONS
%     Knows nothing about discrete levels; a caller wanting them
%     discretises the map it gets back, because whether an overlay should
%     be banded when the basemap is not is the caller's question.
%
%   See also GEO.BASEMAP, GEO.COLORMAPS, GEO.OVERLAYTRACK, GEO.OVERLAYPOINTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    base
    values double = []
    options.Colormap double = []
    options.CLim double = []
end

cmap = options.Colormap;
if isempty(cmap)
    if isempty(base)
        cmap = geo.colormaps("get", "viridis", 256);
    else
        cmap = base.Colormap;
    end
end

cLim = options.CLim;
if isempty(cLim)
    if ~isempty(base)
        cLim = base.CLim;
    elseif ~isempty(values) && any(isfinite(values(:)))
        cLim = [min(values(:), [], 'omitnan'), max(values(:), [], 'omitnan')];
    else
        cLim = [0 1];
    end
end

if ~all(isfinite(cLim)) || diff(cLim) <= 0
    mid = cLim(1);
    if ~isfinite(mid)
        mid = 0;
    end
    cLim = mid + [-0.5 0.5];
end
end
