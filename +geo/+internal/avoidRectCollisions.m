function rect = avoidRectCollisions(rect, obstacles, moveDir, options)
%GEO.INTERNAL.AVOIDRECTCOLLISIONS  Slide a rectangle clear of others.
%
%   SYNTAX
%     RECT = GEO.INTERNAL.AVOIDRECTCOLLISIONS(RECT, OBSTACLES, MOVEDIR)
%     RECT = GEO.INTERNAL.AVOIDRECTCOLLISIONS(..., Bounds = BOUNDSRECT)
%
%   DESCRIPTION
%     Moves RECT along MOVEDIR until it no longer overlaps any of
%     OBSTACLES, then clamps it into BOUNDS if one is given. Used to keep
%     a scale bar off a north arrow, a north arrow off the frame, and
%     both off a colorbar.
%
%     PORTED FROM v1 DELIBERATELY UNCHANGED. Its geometry was reviewed
%     during the v1 audit and found correct, and it is the only piece of
%     v1's five plumbing functions that survives intact - the other four
%     are replaced by GEO.INTERNAL.LAYOUT because their callback chaining
%     was structurally unfixable. Three behaviours below look like bugs
%     and are not; they are recorded here so that a later reader does not
%     "fix" them into something worse.
%
%     TOUCHING IS NOT OVERLAPPING. The test is strict (`> 0`), so a
%     rectangle flush against the frame band is accepted rather than
%     pushed off it. A bar that sits exactly on the neatline is a
%     cartographic convention, not a collision.
%
%     THE LOOP GIVES UP AFTER EIGHT PASSES AND RETURNS WHAT IT HAS. With
%     enough obstacles there may be nowhere to go, and a function that
%     errored there would refuse to draw a map over a layout preference.
%     §4.5: a library that will not let you do the thing you came to do
%     is not protecting you.
%
%     THE BOUNDS CLAMP CAN REINTRODUCE AN OVERLAP, and is applied last on
%     purpose. A partially overlapping annotation inside its container
%     beats a clean one shoved outside it, where the reader will not
%     find it at all.
%
%   INPUTS
%     rect       (1,4) double  [x y w h], lower-left origin, in points.
%     obstacles  (N,4) double  Rectangles to avoid. May be 0x4.
%     moveDir    (1,2) double  Direction to slide. Need not be a unit
%                              vector; it is normalised here. Callers
%                              pass axis-aligned directions - see
%                              LIMITATIONS for why a diagonal
%                              under-clears.
%
%   OPTIONS
%     Bounds  (1,4) double  []  Container to stay inside, or empty for an
%                               unbounded placement. A name-value rather
%                               than a fourth positional argument: D-003
%                               caps public arity at three, and this
%                               function exists partly as the counter-
%                               example to v1's geoNorthArrow, which took
%                               fifteen (F7).
%
%   OUTPUTS
%     rect  (1,4) double  The moved rectangle. Same units as the input.
%
%   ACCURACY
%     Exact arithmetic on rectangle edges; no tolerance anywhere. The
%     clearance added beyond mere non-overlap is 4 points, which is a
%     typographic choice rather than a measurement and is stated as such.
%
%   ERRORS
%     geo:avoidRectCollisions:ZeroDirection    - moveDir is [0 0], which
%                                                names no direction
%     geo:avoidRectCollisions:InvalidObstacles - obstacles is not N-by-4
%     geo:avoidRectCollisions:InvalidBounds    - boundsRect is not one row
%
%   EXAMPLE
%     bar = [20 20 120 14];
%     bar = geo.internal.avoidRectCollisions(bar, [10 10 100 40], [0 1]);
%     bar = geo.internal.avoidRectCollisions(bar, [], [0 1], ...
%                                            Bounds = [0 0 400 300]);
%
%   LIMITATIONS
%     A DIAGONAL MOVEDIR UNDER-CLEARS. The shift magnitude is the full
%     one-dimensional clearance along the dominant axis, but it is
%     applied along the whole direction vector, so a 45-degree move
%     achieves only 1/sqrt(2) of it on the axis that mattered. Every
%     caller in this toolbox passes an axis-aligned direction. Left as
%     found rather than corrected, because correcting it would change
%     placements that were tuned against this behaviour.
%
%     Also: moveDir(2) is tested first and wins outright, so a direction
%     with both components non-zero is treated as vertical.
%
%   See also GEO.INTERNAL.LAYOUT, GEO.SCALEBAR, GEO.NORTHARROW.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    rect (1,4) double {mustBeReal}
    obstacles double {mustBeReal}
    moveDir (1,2) double {mustBeReal}
    options.Bounds double {mustBeReal} = []
end
boundsRect = options.Bounds;

if norm(moveDir) == 0
    error('geo:avoidRectCollisions:ZeroDirection', ...
        'moveDir must not be the zero vector: it names no direction.');
end
if ~isempty(obstacles) && size(obstacles, 2) ~= 4
    error('geo:avoidRectCollisions:InvalidObstacles', ...
        'obstacles must be N-by-4 [x y w h] rows, or empty; it is %dx%d.', ...
        size(obstacles, 1), size(obstacles, 2));
end
if ~isempty(boundsRect) && ~isequal(size(boundsRect), [1 4])
    error('geo:avoidRectCollisions:InvalidBounds', ...
        'Bounds must be a single [x y w h] row, or empty; it is %dx%d.', ...
        size(boundsRect, 1), size(boundsRect, 2));
end

moveDir = moveDir / norm(moveDir);
gapPt = 4;                          % typographic clearance, points
for iter = 1:8                      %#ok<NASGU> named for the reader
    moved = false;
    for i = 1:size(obstacles, 1)
        ob = obstacles(i, :);
        overlapX = min(rect(1) + rect(3), ob(1) + ob(3)) - max(rect(1), ob(1));
        overlapY = min(rect(2) + rect(4), ob(2) + ob(4)) - max(rect(2), ob(2));
        if overlapX <= 0 || overlapY <= 0
            continue                % touching counts as clear
        end
        if moveDir(2) > 0
            shift = (ob(2) + ob(4)) - rect(2) + gapPt;
        elseif moveDir(2) < 0
            shift = rect(2) + rect(4) - ob(2) + gapPt;
        elseif moveDir(1) > 0
            shift = (ob(1) + ob(3)) - rect(1) + gapPt;
        else
            shift = rect(1) + rect(3) - ob(1) + gapPt;
        end
        rect(1:2) = rect(1:2) + moveDir .* shift;
        moved = true;
    end
    if ~moved
        break
    end
end

if ~isempty(boundsRect)
    rect(1) = min(max(rect(1), boundsRect(1)), ...
                  boundsRect(1) + boundsRect(3) - rect(3));
    rect(2) = min(max(rect(2), boundsRect(2)), ...
                  boundsRect(2) + boundsRect(4) - rect(4));
end
end
