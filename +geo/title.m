function H = title(axH, str, options)
%GEO.TITLE  A map title, placed above the map and known to the layout.
%
%   SYNTAX
%     H = GEO.TITLE(AX, STR)
%     H = GEO.TITLE(AX, STR, Name, Value)
%
%   DESCRIPTION
%     Draws a title above the plotted map at z = 6, the frame level.
%
%     WHY THIS EXISTS AT ALL, when MATLAB has TITLE. Stage E's rule is
%     that an L4 front orchestrates public geo.* elements and owns no
%     drawing of its own, and the audit enforces it. GEO.MAP has to draw
%     a title - v1's Title option carries - and there was no element for
%     it, so the rule fired exactly as intended: the missing capability
%     belongs at L3, not inlined into the front. This is that
%     capability, and `title` joined the audit's banned list on the same
%     day so that no front can quietly acquire one later.
%
%     IT IS PLACED AGAINST THE MAP, NOT THE AXES, and the difference is
%     vertical rather than horizontal. Under `axis equal` an axes
%     letterboxes: it centres a box of the data's aspect ratio inside
%     the one it was given. The centring is symmetric, so the two boxes
%     share a horizontal centre and a title is never off to one side -
%     that was checked before it was claimed. What they do not share is
%     a TOP. Measured on a 2:1 world map in a default axes, the map's
%     top sits 53.03 points below the axes' top, so MATLAB's TITLE -
%     which anchors to the axes - floats half an inch above the map with
%     nothing in between. This anchors to the plotted box, which
%     GEO.INTERNAL.PLOTTEDBOX already computes for the frame, the
%     colorbar and the inset.
%
%     IT REGISTERS ITS FOOTPRINT, so a colorbar, inset, scale bar or
%     north arrow placed in a top corner is pushed clear of it rather
%     than drawn through it. That is the same mechanism every other
%     element uses and the reason a title is furniture rather than text.
%
%   INPUTS
%     axH  (1,1) matlab.graphics.axis.Axes  An axes with a basemap.
%     str  (1,:) string  One element per line. Empty removes the title.
%
%   OPTIONS
%     FontName    "Helvetica"
%     FontSize    13
%     FontWeight  "bold"      "normal" | "bold"
%     Color       [0 0 0]
%     Gap         0.03        Clearance above the map, as a fraction of
%                             the plotted diagonal.
%     Interpreter "none"      "none" | "tex" | "latex". "none" is the
%                             default deliberately: a station name with
%                             an underscore in it is a station name, not
%                             a subscript, and v1's titles went through
%                             TeX and silently ate them.
%
%   OUTPUTS
%     H  (1,1) struct  Fields:
%          Text   (1,1) Text
%          Rect   (1,4) double  Footprint in points, as registered.
%          All    (1,:)
%
%   ACCURACY
%     One geometric claim, asserted in points on the drawn object: the
%     clearance between the top of the plotted map and the title equals
%     Gap times the plotted diagonal. Measured at the default Gap on a
%     letterboxed world map: 34.29 points asked, 34.29 points drawn,
%     while the axes' own top was 53.03 points further up.
%
%   ERRORS
%     geo:title:NoBasemap - the axes carries no basemap to sit above
%
%   EXAMPLE
%     geo.title(ax, "GRACE mass trend, 2003-2016");
%     geo.title(ax, ["Equivalent water height" "cm/yr"], FontSize = 11);
%
%   LIMITATIONS
%     The title is drawn in axes data coordinates with clipping off, so
%     it lies above the axes box. A figure whose axes reaches the top of
%     the page will clip it; leave the default margins or export with a
%     Height that accounts for it.
%
%   See also GEO.MAP, GEO.FRAME, GEO.INTERNAL.LAYOUT, GEO.INTERNAL.PLOTTEDBOX.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    axH (1,1) matlab.graphics.axis.Axes
    str (1,:) string
    options.FontName (1,1) string = "Helvetica"
    options.FontSize (1,1) double {mustBePositive} = 13
    options.FontWeight (1,1) string {mustBeMember(options.FontWeight, ["normal" "bold"])} = "bold"
    options.Color (1,3) double {mustBeInRange(options.Color, 0, 1)} = [0 0 0]
    options.Gap (1,1) double {mustBeNonnegative} = 0.03
    options.Interpreter (1,1) string {mustBeMember(options.Interpreter, ["none" "tex" "latex"])} = "none"
end

[~, ~, ~, ~, ~, ~, diag] = geo.internal.elementExtent(axH, [], ...
    ErrorId = "geo:title:NoBasemap");

prior = geo.internal.layout("data", axH, "title");
if ~isempty(prior)
    delete(prior.All(isgraphics(prior.All)));
end

str = str(strlength(str) > 0);
if isempty(str)
    geo.internal.layout("remove", axH, "title");
    H = struct('Text', gobjects(1, 0), 'Rect', zeros(1, 4), ...
        'All', gobjects(1, 0));
    return
end

[xc, yTop] = mapTop(axH);
h = text(axH, xc, yTop + options.Gap * diag, 6, cellstr(str), ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', ...
    'FontName', char(options.FontName), ...
    'FontSize', options.FontSize, ...
    'FontWeight', char(options.FontWeight), ...
    'Color', options.Color, ...
    'Interpreter', char(options.Interpreter), ...
    'Clipping', 'off');

rect = footprint(axH, h);
geo.internal.layout("register", axH, "title", ...
    @(a) redraw(a, str, options));
geo.internal.layout("setRect", axH, "title", rect);

H = struct('Text', h, 'Rect', rect, 'All', h);
geo.internal.layout("setData", axH, "title", H);
end

% ======================================================================
function redraw(axH, str, options)
%REDRAW  On resize, re-place against the new plotted box.
%   The gap is a fraction of the diagonal, so it has to be recomputed
%   rather than remembered.
nv = namedargs2cell(options);
geo.title(axH, str, nv{:});
end

function [xc, yTop] = mapTop(axH)
%MAPTOP  Centre and top of the PLOTTED map, in data coordinates.
%   GEO.INTERNAL.PLOTTEDBOX is the project's authority on where the map
%   really is, and it answers in figure points because that is what a
%   colorbar and an inset need. A title is placed in data coordinates,
%   so its answer is converted back rather than recomputed - one
%   authority, two units, no second copy of the letterboxing rule (F6).
box = geo.internal.plottedBox(axH);
u = axH.Units;
axH.Units = 'points';
p = axH.Position;
axH.Units = u;
xl = axH.XLim;
yl = axH.YLim;
xc = xl(1) + (box(1) + box(3) / 2 - p(1)) / p(3) * (xl(2) - xl(1));
yTop = yl(1) + (box(2) + box(4) - p(2)) / p(4) * (yl(2) - yl(1));
end

function rect = footprint(axH, h)
%FOOTPRINT  The drawn extent in points, for the collision registry.
%   Read from the Text's own Extent in points rather than estimated from
%   the font size: a two-line title is not twice a one-line title, and
%   the renderer is the only authority on where the glyphs landed.
u = h.Units;
h.Units = 'points';
e = h.Extent;
h.Units = u;

au = axH.Units;
axH.Units = 'points';
p = axH.Position;
axH.Units = au;
rect = [p(1) + e(1), p(2) + e(2), e(3), e(4)];
end
