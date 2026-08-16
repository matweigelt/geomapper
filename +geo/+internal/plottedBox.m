function box = plottedBox(axH)
%GEO.INTERNAL.PLOTTEDBOX  Where the map really is, in figure points.
%
%   SYNTAX
%     BOX = GEO.INTERNAL.PLOTTEDBOX(AX)
%
%   DESCRIPTION
%     An axes under `axis equal` does not fill its own Position: it
%     letterboxes, centring a box of the data's aspect ratio inside the
%     one it was given. Anything positioned in figure points against the
%     MAP - a colorbar beside it, a locator inset in its corner - has to
%     know the plotted rectangle rather than the axes rectangle, or it
%     will sit against empty space on two sides.
%
%     THIS FUNCTION EXISTS BECAUSE THE AUDIT DEMANDED IT, FOUR TIMES.
%     v1 carried this computation verbatim in `geoGmtColorbar`, in both
%     copies of `localAddHalfColorbar`, in `localAddDualScaleColorbar`
%     and in `localAddMapInset` - five copies - and its own comments
%     record two more in `geoScaleBar` and `geoNorthArrow`. That is
%     defect F6 at its purest. v2 wrote it twice, in GEO.COLORBAR and
%     GEO.INSET, and the duplicate-local-function check rejected the
%     second within the same round.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes
%
%   OUTPUTS
%     box  (1,4) double  [x y w h] in FIGURE POINTS, lower-left origin.
%                        The axes Position itself when the data aspect
%                        is not usable, which is the honest fallback:
%                        without a ratio there is no letterboxing to
%                        correct for.
%
%   ACCURACY
%     Exact arithmetic on the axes Position and its data limits. The
%     units switch is done and undone around the read, so an axes in
%     normalized units is returned to normalized units.
%
%   ERRORS
%     (none; a degenerate aspect returns the axes rectangle unchanged)
%
%   EXAMPLE
%     box = geo.internal.plottedBox(ax);
%     cbPos = [box(1), box(2) - 20, box(3), 12];
%
%   LIMITATIONS
%     Assumes `axis equal`, which every map axes in this toolbox uses.
%     On an axes with a free aspect ratio the plotted box IS the axes
%     box, and that is what comes back - correct, but for a different
%     reason than the one this function is about.
%
%   See also GEO.COLORBAR, GEO.INSET, GEO.INTERNAL.ELEMENTEXTENT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
end

u = get(axH, 'Units');
set(axH, 'Units', 'points');
pos = get(axH, 'Position');
set(axH, 'Units', u);

dataAspect = diff(xlim(axH)) / diff(ylim(axH));
boxAspect = pos(3) / pos(4);
if ~isfinite(dataAspect) || dataAspect <= 0 || ~isfinite(boxAspect)
    box = pos;
    return
end
if dataAspect > boxAspect
    w = pos(3);
    h = w / dataAspect;
else
    h = pos(4);
    w = h * dataAspect;
end
box = [pos(1) + (pos(3) - w) / 2, pos(2) + (pos(4) - h) / 2, w, h];
end
