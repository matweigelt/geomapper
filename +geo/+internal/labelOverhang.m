function over = labelOverhang(axH)
%LABELOVERHANG  How far the graticule's labels reach past the plotted map.
%
%   SYNTAX
%     OVER = GEO.INTERNAL.LABELOVERHANG(AXH)
%
%   DESCRIPTION
%     Returns, in figure points, how far the graticule's tick labels
%     extend beyond GEO.INTERNAL.PLOTTEDBOX on each of the four sides.
%     An element placed OUTSIDE the map - a colorbar, and nothing else
%     today - adds the relevant entry to its own gap, so it clears the
%     labels instead of landing on them.
%
%     THE DEFECT IT CLOSES (PV-152). GEO.COLORBAR anchored to the plotted
%     box, which is the map. The graticule's labels sit outside the map by
%     LabelGap times the diagonal, so "southoutside" put the bar's tick
%     numbers straight through the longitude label row. Measured on the
%     toolbox's own showcase call - a GRACE field on Robinson with
%     graticule, frame, colorbar and title - **six pairs of overlapping
%     text**, five of them colorbar against graticule:
%
%       "-0.5" x "180deg"          15.9 x 4.3 pt
%       "0.5"  x "180deg"          13.5 x 4.3 pt
%       "-0.5" x "90degS"           9.6 x 5.2 pt
%       "EWH residual [m]" x "0deg" 9.0 x 2.2 pt
%       "0"    x "0deg"             5.2 x 4.3 pt
%
%     WHY IT IS A FUNCTION AND NOT FOUR LINES IN GEO.COLORBAR. It is the
%     same question GEO.INSET, GEO.SCALEBAR and a future outside-placed
%     element will each have to ask, and PLOTTEDBOX's own help records
%     what happened last time this class of geometry was written per
%     caller: five copies in v1, two more in v2 before the duplicate check
%     rejected them.
%
%     WHY IT READS THE REGISTRY RATHER THAN THE AXES. Asking the axes for
%     every Text child would sweep up the title, the scale bar's caption
%     and any text the caller added. The graticule registers what it drew;
%     this reads that. The labels of a graticule that was never drawn are
%     legitimately absent, and the answer is then zero on all four sides
%     rather than an error - a map without a graticule has nothing to
%     clear.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  The map axes.
%
%   OUTPUTS
%     over  (1,4) double  Points past the plotted box on the
%                         [left right bottom top] sides. Never negative:
%                         a label inside the box overhangs by nothing.
%
%   ACCURACY
%     Exact given the text extents MATLAB reports. The data-to-points
%     mapping is linear and taken from PLOTTEDBOX against the axes limits,
%     which is the same rectangle the map is drawn into, so no second
%     aspect-ratio computation enters here.
%
%     IT IS ONLY AS GOOD AS THE EXTENTS, and those are not final until the
%     text has been laid out. Callers that have just created the labels
%     must let the graphics system settle first; GEO.COLORBAR does.
%
%   ERRORS
%     (none raised; an absent graticule is a legitimate zero)
%
%   EXAMPLE
%     over = geo.internal.labelOverhang(axH);
%     pos(2) = box(2) - gap - over(3) - height;   % clear the bottom row
%
%   LIMITATIONS
%     Rotated labels are measured by their axis-aligned bounding box,
%     which over-reports. The graticule draws none today.
%
%   See also GEO.INTERNAL.PLOTTEDBOX, GEO.COLORBAR, GEO.GRATICULE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
end

over = [0 0 0 0];
g = geo.internal.layout("data", axH, "graticule");
if isempty(g) || ~isfield(g, 'Labels') || isempty(g.Labels)
    return
end

box = geo.internal.plottedBox(axH);

% THE EXTENT IS MEASURED IN POINTS, NEVER DERIVED FROM THE LIMITS.
% The first version of this function mapped the label's data-unit Extent
% onto PLOTTEDBOX linearly, on the assumption that PLOTTEDBOX is the
% rectangle the axis limits map onto. IT IS NOT: it is the rectangle the
% MAP occupies, and with GEO.FRAME widening the limits after the graticule
% has drawn, the two differ enough to matter. Measured on the showcase
% call, the derived figure said the labels reached 6.9 pt below the map
% and they reached 44.8 - so the colorbar was moved by a seventh of what
% it needed and the overlap survived, slightly rearranged. This is
% CODING_GUIDE R3 exactly: a property is read from the object, never
% inferred from a convention about how the object was built.
%
% Setting Units mutates the text, so every label is restored on every
% path, including an error one. A diagnostic that leaves the figure
% reconfigured is worse than no diagnostic.
prior = get(axH, 'Units');
restoreAxes = onCleanup(@() set(axH, 'Units', prior));
set(axH, 'Units', 'points');
ap = get(axH, 'Position');

for t = reshape(g.Labels, 1, [])
    if ~isgraphics(t, 'text')
        continue
    end
    u = get(t, 'Units');
    restoreText = onCleanup(@() set(t, 'Units', u));
    set(t, 'Units', 'points');
    e = get(t, 'Extent');            % points, from the axes origin
    clear restoreText                %#ok<CLEAR> restore before the next
    x0 = ap(1) + e(1);
    y0 = ap(2) + e(2);
    over(1) = max(over(1), box(1) - x0);
    over(2) = max(over(2), (x0 + e(3)) - (box(1) + box(3)));
    over(3) = max(over(3), box(2) - y0);
    over(4) = max(over(4), (y0 + e(4)) - (box(2) + box(4)));
end
end
