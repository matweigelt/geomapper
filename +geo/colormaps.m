function out = colormaps(cmd, a, b, options)
%GEO.COLORMAPS  Presets, discretisation, and truecolor mapping in one place.
%
%   SYNTAX
%     NAMES = GEO.COLORMAPS("names")
%     CMAP  = GEO.COLORMAPS("get", NAME)
%     CMAP  = GEO.COLORMAPS("get", NAME, N)
%     CMAP  = GEO.COLORMAPS("discretize", CMAP, NLEVELS)
%     RGB   = GEO.COLORMAPS("truecolor", Z, CMAP, Name, Value)
%
%   DESCRIPTION
%     Merges v1's geoColormapPreset, geoDiscretizeColormap and
%     geoMapToTruecolor. They were three functions with one subject, and
%     the truecolor one could not see the discretisation the caller had
%     applied, so under/over colours landed on the wrong side of a level
%     boundary.
%
%     WHICH PRESETS EXIST, AND WHY THREE OF V1'S ARE GONE. v1 offered
%     viridis, magma, cividis, turbo, parula and jet. Four of those are
%     available in base MATLAB and are DELEGATED to it: parula, jet, turbo
%     and gray come from MATLAB itself, so this toolbox neither copies nor
%     maintains them.
%
%     VIRIDIS, MAGMA AND CIVIDIS ARE NOT PORTED. They exist only as
%     third-party tabulated data, and reproducing those tables here would
%     be copying somebody else's work into this repository - which the
%     handover forbids in the same breath as it asks for an original
%     ramp. Callers who need them can pass their own Nx3 array anywhere a
%     preset name is accepted, so nothing is lost except the spelling.
%     Recorded as a deliberate change to v1's option surface.
%
%     THE DIVERGING RAMP IS ORIGINAL, generated here, not a reproduction
%     of anybody's table. It runs blue-white-red through a
%     lightness-monotone path on each half, so the two limbs read as
%     equally strong and zero sits at the lightest point - which is the
%     property a signed anomaly field needs and which a hue-only ramp
%     does not have.
%
%   INPUTS
%     cmd  (1,1) string  "names" | "get" | "discretize" | "truecolor".
%     a                  "get": the preset name. "discretize": an Nx3
%                        colormap. "truecolor": the data array Z.
%     b                  "get": N, the number of rows [256].
%                        "discretize": the number of levels.
%                        "truecolor": an Nx3 colormap or a preset name.
%
%   OPTIONS  (truecolor only)
%     CLim        (1,2) double   [auto]  Data limits mapped to the ends.
%     UnderColor  (1,3) double   []      Colour below CLim(1).
%     OverColor   (1,3) double   []      Colour above CLim(2).
%     Mask        logical        []      True where MaskColor applies.
%     MaskColor   (1,3) double   [0.7 0.7 0.7]
%     NaNColor    (1,3) double   [1 1 1]
%     Shade       double         []      Multiplicative shade in [0,1],
%                                        same size as Z. From GEO.HILLSHADE.
%
%   OUTPUTS
%     "names"       (1,:) string
%     "get"         (N,3) double in [0,1]
%     "discretize"  (N,3) double, N unchanged, values quantised
%     "truecolor"   (M,N,3) double
%
%   ACCURACY
%     SHADE COMPOSITION IS EXACTLY rgb .* Shade, broadcast over the third
%     dimension, and it is asserted exactly rather than to a tolerance:
%     with Shade = 0.5 every channel is exactly halved. There is no
%     gamma, no blend curve and no clamping in the composition, because
%     any of those would make the shade unrecoverable from the output.
%     What stops shadows going black is the Ambient floor INSIDE
%     GEO.HILLSHADE, which is where that decision belongs.
%
%   ERRORS
%     Specification:
%       geo:colormaps:UnknownPreset  - no such preset name
%       geo:colormaps:NotAColormap   - a colormap argument is not Nx3 in
%                                      [0, 1]
%       geo:colormaps:ShadeMismatch  - Shade is not the same size as Z
%
%   EXAMPLE
%     cmap = geo.colormaps("get", "divergent", 256);
%     rgb  = geo.colormaps("truecolor", Z, cmap, ...
%                          CLim = geo.symmetricLimits(Z), Shade = s);
%
%   LIMITATIONS
%     The diverging ramp is designed by construction, not by a measured
%     perceptual model: it is lightness-monotone on each limb, which is
%     the property that matters here, but it has not been checked against
%     a CIE appearance model and is not claimed to be perceptually
%     uniform.
%
%   See also GEO.HILLSHADE, GEO.SYMMETRICLIMITS, GEO.QUANTILE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    cmd (1,1) string {mustBeMember(cmd, ...
        ["names" "get" "discretize" "truecolor"])}
    a = []
    b = []
    options.CLim (1,2) double = [NaN NaN]
    options.UnderColor double = []
    options.OverColor double = []
    options.Mask = []
    options.MaskColor (1,3) double = [0.7 0.7 0.7]
    options.NaNColor (1,3) double = [1 1 1]
    options.Shade double = []
end

switch cmd
    case "names"
        out = presetNames();

    case "get"
        n = 256;
        if ~isempty(b), n = b; end
        out = preset(string(a), n);

    case "discretize"
        mustBeColormap(a);
        out = discretize(a, b);

    otherwise
        out = truecolor(a, b, options);
end
end

% ======================================================================
function names = presetNames()
%PRESETNAMES  One authority on what exists.
names = ["divergent" "sequential" "parula" "jet" "turbo" "gray"];
end

function cmap = preset(name, n)
switch lower(name)
    case "divergent"
        cmap = divergingRamp(n);
    case "sequential"
        cmap = sequentialRamp(n);
    case "parula"
        cmap = parula(n);
    case "jet"
        cmap = jet(n);
    case "turbo"
        cmap = turbo(n);
    case "gray"
        cmap = gray(n);
    otherwise
        error('geo:colormaps:UnknownPreset', ...
            ['"%s" is not a preset. The presets are: %s. viridis, magma ' ...
             'and cividis were in v1 and are NOT ported: they exist only ' ...
             'as third-party tabulated data, and this toolbox generates ' ...
             'rather than copies. Pass your own Nx3 array instead - ' ...
             'anywhere a name is accepted, an array is too.'], ...
            name, strjoin(presetNames(), ', '));
end
end

function cmap = divergingRamp(n)
%DIVERGINGRAMP  Original blue-white-red, lightness-monotone on each limb.
%   Generated, not a reproduction of anybody's table. Zero sits at the
%   lightest point, so a signed field reads symmetrically about it, and
%   each limb rises monotonically in saturation as it falls in lightness.
t = linspace(-1, 1, n).';
s = abs(t);                       % 0 at the centre, 1 at the ends
% Lightness falls from 1 at the centre to 0.35 at the ends, smoothly, so
% neither limb dominates the other by brightness alone.
L = 1 - 0.65 * s.^0.9;
cold = t < 0;
r = L;  g = L;  bl = L;
% Cold limb: hold blue, withdraw red and green together.
r(cold)  = L(cold)  .* (1 - 0.95 * s(cold));
g(cold)  = L(cold)  .* (1 - 0.55 * s(cold));
% Warm limb: hold red, withdraw green and blue together.
g(~cold) = L(~cold) .* (1 - 0.62 * s(~cold));
bl(~cold) = L(~cold) .* (1 - 0.95 * s(~cold));
cmap = min(max([r g bl], 0), 1);
end

function cmap = sequentialRamp(n)
%SEQUENTIALRAMP  Original light-to-dark blue, monotone in lightness.
t = linspace(0, 1, n).';
L = 1 - 0.85 * t;
cmap = min(max([L .* (1 - 0.75 * t), L .* (1 - 0.35 * t), L], 0), 1);
end

function cmapOut = discretize(cmapIn, nLevels)
%DISCRETIZE  Quantise into nLevels evenly sized bands, keeping the rows.
%   The row count is unchanged so a caller can swap a continuous map for
%   a discrete one without touching CLim or the colourbar.
if isempty(nLevels) || nLevels < 1
    cmapOut = cmapIn;
    return
end
n = size(cmapIn, 1);
idx = min(floor((0:n-1).' / n * nLevels), nLevels - 1);
% Sample each band at its CENTRE, not its edge: an edge sample makes the
% first and last bands half a band darker or lighter than the rest.
pick = round((idx + 0.5) / nLevels * (n - 1)) + 1;
cmapOut = cmapIn(pick, :);
end

function rgb = truecolor(Z, cmap, options)
%TRUECOLOR  Map a scalar field to RGB, with gaps, masks and shade.
if isstring(cmap) || ischar(cmap)
    cmap = preset(string(cmap), 256);
elseif isempty(cmap)
    cmap = preset("divergent", 256);
end
mustBeColormap(cmap);
Z = double(Z);

lim = options.CLim;
if any(isnan(lim))
    lim = [min(Z(:), [], 'omitnan'), max(Z(:), [], 'omitnan')];
    if ~all(isfinite(lim)) || lim(2) <= lim(1)
        lim = [0 1];
    end
end

n = size(cmap, 1);
t = (Z - lim(1)) / (lim(2) - lim(1));
idx = min(max(round(t * (n - 1)) + 1, 1), n);
idx(~isfinite(Z)) = 1;                    % placeholder; overwritten below

rgb = reshape(cmap(idx(:), :), [size(Z) 3]);

% Under and over BEFORE the gap and mask colours, because a value can be
% out of range and missing, and missing wins.
if ~isempty(options.UnderColor)
    rgb = paint(rgb, Z < lim(1), options.UnderColor);
end
if ~isempty(options.OverColor)
    rgb = paint(rgb, Z > lim(2), options.OverColor);
end
if ~isempty(options.Mask)
    rgb = paint(rgb, logical(options.Mask), options.MaskColor);
end
rgb = paint(rgb, ~isfinite(Z), options.NaNColor);

if ~isempty(options.Shade)
    if ~isequal(size(options.Shade), size(Z))
        error('geo:colormaps:ShadeMismatch', ...
            'Shade is %s but Z is %s.', ...
            mat2str(size(options.Shade)), mat2str(size(Z)));
    end
    % Exactly rgb .* Shade, broadcast. No gamma, no blend curve, no
    % clamp: any of those would make the shade unrecoverable from the
    % output. The Ambient floor lives in geo.hillshade.
    rgb = rgb .* options.Shade;
end
end

function rgb = paint(rgb, mask, colour)
%PAINT  Set every masked pixel to one colour, across all three channels.
if ~any(mask(:))
    return
end
for c = 1:3
    ch = rgb(:, :, c);
    ch(mask) = colour(c);
    rgb(:, :, c) = ch;
end
end

function mustBeColormap(c)
if ~isnumeric(c) || ~isreal(c) || ndims(c) ~= 2 || size(c, 2) ~= 3 || ...
        isempty(c) || any(c(:) < 0) || any(c(:) > 1)
    error('geo:colormaps:NotAColormap', ...
        'A colormap must be a non-empty Nx3 real array with values in [0, 1].');
end
end
