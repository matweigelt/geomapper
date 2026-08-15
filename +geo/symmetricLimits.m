function lim = symmetricLimits(Z, p)
%GEO.SYMMETRICLIMITS  Colour limits symmetric about zero, for signed fields.
%
%   SYNTAX
%     LIM = GEO.SYMMETRICLIMITS(Z)
%     LIM = GEO.SYMMETRICLIMITS(Z, P)
%
%   DESCRIPTION
%     Returns [-a a] with a the P-th percentile of |Z|. For a signed
%     anomaly field - an EWH trend, a mascon solution, anything where the
%     sign carries the meaning - asymmetric limits put zero somewhere
%     other than the middle of a diverging colormap, so the colour that
%     means "no change" lands on a value that is not no change.
%
%     THE DEFAULT IS THE 98th PERCENTILE, not the maximum. A single
%     outlying mascon would otherwise set the scale for the whole map and
%     flatten everything else to the middle colour. 98 is v1's choice,
%     carried forward.
%
%     A DEGENERATE FIELD GETS [-0.5 0.5], not [0 0]. An all-zero or
%     constant field has no spread, and a zero-width colour range makes
%     every renderer behave differently; the arbitrary half-unit is
%     visibly arbitrary, which is better than a limit that looks
%     meaningful and is not.
%
%   INPUTS
%     Z  double        Any size. Non-finite elements ignored.
%     p  (1,1) double  [98]  Percentage in [0, 100].
%
%   OUTPUTS
%     lim  (1,2) double  [-a a], strictly increasing.
%
%   ACCURACY
%     Exact given GEO.QUANTILE; no arithmetic of its own beyond a sign.
%
%   ERRORS
%     Value validity:
%       geo:quantile:PercentOutOfRange - raised by GEO.QUANTILE for a p
%                                        outside [0, 100]
%
%   EXAMPLE
%     clim(geo.symmetricLimits(trendField));      % zero in the middle
%
%   LIMITATIONS
%     Symmetric by construction, so a field that is genuinely one-sided -
%     an absolute mass, a depth - is the wrong subject for it. Use
%     GEO.QUANTILE directly for those.
%
%   See also GEO.QUANTILE, GEO.COLORMAPS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    Z double
    p (1,1) double {mustBeReal} = 98
end

a = geo.quantile(abs(Z), p);
if ~isfinite(a) || a <= 0
    lim = [-0.5 0.5];
    return
end
lim = [-a a];
end
