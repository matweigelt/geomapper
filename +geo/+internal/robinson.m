function out = robinson(what, v)
%GEO.INTERNAL.ROBINSON  The Robinson table, and the only way to read it.
%
%   SYNTAX
%     XS  = GEO.INTERNAL.ROBINSON("x", ABSLAT)
%     YS  = GEO.INTERNAL.ROBINSON("y", ABSLAT)
%     LAT = GEO.INTERNAL.ROBINSON("latFromY", YS)
%     T   = GEO.INTERNAL.ROBINSON("table")
%
%   DESCRIPTION
%     Robinson is not a formula, it is a table (Snyder 1987 Table 27;
%     Snyder 1993), so the only design freedom is the interpolant. PCHIP
%     is used, matching the mirror, because it is monotone-preserving and
%     a spline is not: a spline through these nodes overshoots and puts
%     latitude 88 north of latitude 90.
%
%     THE INVERSE IS ROOT-FINDING ON THE FORWARD INTERPOLANT, NEVER PCHIP
%     ON THE SWAPPED TABLE, and the difference is not cosmetic. A swapped
%     table is a different curve between nodes; near the pole
%     dY/dlat is about 0.0048 per degree, so a 1e-3 discrepancy in the
%     interpolant becomes a 0.2 degree latitude error. Measured
%     (finding PV-004): the swapped-table shortcut gives a round-trip
%     error of 0.30 degrees, root-finding gives 1.4e-13. The handover's
%     original 5e-4 round-trip exception for Robinson was an artefact of
%     the prescribed method, not of the projection, and was withdrawn.
%
%     Bisection first because it is monotone by construction and cannot
%     fail, then Newton on the interpolant's own derivative for the last
%     few digits.
%
%   INPUTS
%     what  (1,1) string  "x" | "y" | "latFromY" | "table".
%     v     double        Absolute latitude in degrees for "x"/"y";
%                         a Y-table value for "latFromY". Unused for
%                         "table".
%
%   OUTPUTS
%     out   double        Interpolated value, or the 19x3 table
%                         [lat X Y] for "table".
%
%   ACCURACY
%     PCHIP reproduces its own nodes exactly; asserted at 1e-12 in the
%     mirror and again in TestB1_projection. The inverse converges to
%     1e-13 degrees, measured.
%
%   ERRORS
%     Argument validation:
%       geo:project:UnknownRobinsonQuery - `what` is not one of the four
%
%   EXAMPLE
%     xs = geo.internal.robinson("x", 50);   % 0.8679
%
%   LIMITATIONS
%     Defined on |lat| <= 90 only; the caller clamps. The table is
%     Snyder's, at 5-degree steps, and no finer sampling exists to check
%     it against - Robinson IS this table.
%
%   See also GEO.PROJECT, GEO.UNPROJECT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    what (1,1) string
    v double = []
end

persistent LAT X Y PX PY DPY
if isempty(LAT)
    LAT = (0:5:90).';
    X = [1.0000 0.9986 0.9954 0.9900 0.9822 0.9730 0.9600 0.9427 ...
         0.9216 0.8962 0.8679 0.8350 0.7986 0.7597 0.7186 0.6732 ...
         0.6213 0.5722 0.5322].';
    Y = [0.0000 0.0620 0.1240 0.1860 0.2480 0.3100 0.3720 0.4340 ...
         0.4958 0.5571 0.6176 0.6769 0.7346 0.7903 0.8435 0.8936 ...
         0.9394 0.9761 1.0000].';
    PX = pchip(LAT, X);
    PY = pchip(LAT, Y);
    DPY = fnderRobinson(PY);
end

switch what
    case "x"
        out = ppval(PX, min(max(v, 0), 90));
    case "y"
        out = ppval(PY, min(max(v, 0), 90));
    case "table"
        out = [LAT X Y];
    case "latFromY"
        out = latFromY(v, PY, DPY);
    otherwise
        error('geo:project:UnknownRobinsonQuery', ...
            '"%s" is not one of "x", "y", "latFromY", "table".', what);
end
end

% ======================================================================
function lat = latFromY(yy, PY, DPY)
%LATFROMY  Bisection to bracket, Newton to finish. See the help above.
lo = zeros(size(yy));
hi = 90 * ones(size(yy));
for k = 1:60
    mid = 0.5 * (lo + hi);
    below = (ppval(PY, mid) - yy) < 0;
    lo(below) = mid(below);
    hi(~below) = mid(~below);
    if max(hi(:) - lo(:)) < 1e-9
        break
    end
end
lat = 0.5 * (lo + hi);
for k = 1:5
    f = ppval(PY, lat) - yy;
    d = ppval(DPY, lat);
    step = zeros(size(f));
    ok = abs(d) >= 1e-12;
    step(ok) = f(ok) ./ d(ok);
    lat = min(max(lat - step, 0), 90);
    if max(abs(step(:))) < 1e-13
        break
    end
end
end

function dpp = fnderRobinson(pp)
%FNDERROBINSON  Derivative of a pp-form, without the Curve Fitting Toolbox.
%   FNDER lives in a toolbox this project may not assume (the whole point
%   of F1), so the polynomial coefficients are differentiated directly.
[br, cf, l, k, d] = unmkpp(pp);
if k == 1
    dpp = mkpp(br, zeros(l, 1), d);
    return
end
scale = (k-1):-1:1;
dpp = mkpp(br, cf(:, 1:k-1) .* scale, d);
end
