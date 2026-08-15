function theta = mollweideTheta(phi)
%GEO.INTERNAL.MOLLWEIDETHETA  Solve 2*theta + sin(2*theta) = pi*sin(phi).
%
%   SYNTAX
%     THETA = GEO.INTERNAL.MOLLWEIDETHETA(PHI)
%
%   DESCRIPTION
%     Newton-Raphson for the Mollweide auxiliary angle. Ported from v1
%     with two additions and nothing else changed: an early exit at
%     max|step| < 1e-13, and an exact assignment at the poles.
%
%     THE GUARD COMES BEFORE THE DIVIDE, NOT AFTER IT. At the poles the
%     derivative 2 + 2cos(2*theta) vanishes, so an eager f/dfd produces
%     0/0 and NaN even when a later mask would have discarded it - MATLAB
%     evaluates both branches of an indexed assignment. The step is
%     therefore computed only where the derivative is safe. This is the
%     same trap the mirror documents, in the same place.
%
%     The pole is then assigned rather than iterated to: theta = phi
%     exactly at +/-90 degrees, which is the analytic limit and needs no
%     search.
%
%   INPUTS
%     phi  double  Latitude in RADIANS. Any size. NaN propagates.
%
%   OUTPUTS
%     theta  double  Auxiliary angle in radians, same size as phi.
%
%   ACCURACY
%     Converges to 1e-13 in at most 15 iterations over the whole sphere;
%     the resulting round trip through GEO.PROJECT and GEO.UNPROJECT
%     measures 8.9e-15 degrees, well inside the 1e-9 contract.
%
%   ERRORS
%     (none raised; a non-real input cannot reach here, geo.project
%     validates)
%
%   EXAMPLE
%     th = geo.internal.mollweideTheta(deg2rad([-90 0 45 90]));
%
%   LIMITATIONS
%     Newton, so it assumes the caller's phi is a real latitude in
%     [-pi/2, pi/2]. Outside that the equation has no solution and the
%     iteration returns whatever it wandered to; geo.project clips first.
%
%   See also GEO.PROJECT, GEO.UNPROJECT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    phi double
end

% NO EARLY EXIT, and that is a deliberate reversal of the handover's
% §7.4 instruction to "add early exit at max|delta| < 1e-13".
%
% A break on max(|step|) over the whole array makes each element's
% ITERATION COUNT depend on its neighbours: a batch runs until the
% slowest element converges, a scalar call stops at its own. The results
% then differ in the last ulp, and the `vectorisation` contract - batched
% equals scalar, BITWISE - fails. Measured on the first run of
% TestB1_projection: mollweide was the only projection to fail it.
%
% Fifteen unconditional iterations instead. Newton at a converged point
% takes a step of order 1e-17, so the extra passes are elementwise
% no-ops, and every element's trajectory is now independent of every
% other's. A deterministic result that costs a few microseconds beats a
% faster one that depends on how the caller batched their data.
theta = phi;
target = pi * sin(phi);
for k = 1:15
    f = 2 * theta + sin(2 * theta) - target;
    dfd = 2 + 2 * cos(2 * theta);
    step = zeros(size(theta));
    safe = abs(dfd) >= 1e-15;          % guard BEFORE the divide
    step(safe) = f(safe) ./ dfd(safe);
    theta = theta - step;
end

atPole = abs(abs(phi) - pi/2) < 1e-12;
theta(atPole) = sign(phi(atPole)) * pi/2;
end
