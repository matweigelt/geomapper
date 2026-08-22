function rects = textRects(handles)
%TEXTRECTS  Text extents as rectangles in figure points.
%
%   SYNTAX
%     RECTS = GEO.INTERNAL.TEXTRECTS(HANDLES)
%
%   DESCRIPTION
%     One row per handle, `[x y w h]` in figure points, measured rather
%     than derived. Deleted handles and non-text handles give a row of
%     NaN so the result lines up with the input and a caller never has to
%     track which handles survived.
%
%     WHY MEASURED AND NOT DERIVED, which is the whole reason this
%     function exists. The obvious way to place text against a map is to
%     read the Extent in data units and scale it by the axes limits onto
%     GEO.INTERNAL.PLOTTEDBOX. That was written, shipped and wrong: the
%     plotted box is the rectangle the MAP occupies, GEO.FRAME widens the
%     limits after GEO.GRATICULE has already drawn its labels, and the two
%     rectangles then disagree. Measured on the showcase call, the derived
%     figure said the labels reached 6.9 pt below the map when they
%     reached 44.8 - a factor of six and a half, in the direction that
%     leaves the defect looking mostly fixed. CODING_GUIDE R3: a property
%     is read from the object, never inferred from a convention about how
%     the object was built.
%
%     IT RESTORES WHAT IT CHANGES. Reading an extent in points means
%     setting Units, which mutates the object. Every handle is restored
%     through a cleanup object on every path, including an error one, so
%     a caller cannot leave a figure reconfigured by having measured it.
%
%   INPUTS
%     handles  (1,:) matlab.graphics.Graphics  Text handles, or anything;
%                                              non-text entries give NaN.
%
%   OUTPUTS
%     rects  (N,4) double  [x y w h] per handle, figure points. NaN rows
%                          for handles that are gone or are not text.
%
%   ACCURACY
%     Exact given the extents MATLAB reports. Those are not final until
%     the graphics system has laid the text out, so a caller that has just
%     created the text must let it settle first - GEO.GRATICULE does,
%     immediately before it resolves collisions.
%
%   ERRORS
%     (none raised)
%
%   EXAMPLE
%     r = geo.internal.textRects(labels);
%     overlaps = r(1,1) < r(2,1) + r(2,3) && r(2,1) < r(1,1) + r(1,3);
%
%   LIMITATIONS
%     Rotated text is measured by its axis-aligned bounding box, which
%     over-reports. Nothing in this toolbox rotates a label today.
%
%   See also GEO.INTERNAL.LABELOVERHANG, GEO.GRATICULE, GEO.COLORBAR.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    handles (1,:) = matlab.graphics.GraphicsPlaceholder.empty
end

rects = nan(numel(handles), 4);
for k = 1:numel(handles)
    t = handles(k);
    if ~isgraphics(t, 'text')
        continue
    end
    ax = ancestor(t, 'axes');
    if isempty(ax)
        continue
    end
    priorAx = get(ax, 'Units');
    priorT = get(t, 'Units');
    restore = onCleanup(@() set([ax t], {'Units'}, {priorAx; priorT}));
    set(ax, 'Units', 'points');
    set(t, 'Units', 'points');
    e = get(t, 'Extent');
    ap = get(ax, 'Position');
    rects(k, :) = [ap(1) + e(1), ap(2) + e(2), e(3), e(4)];
    clear restore
end
end
