classdef TestB3_colormaps < GeoMapTestCase
%TESTB3_COLORMAPS  Stage B.3: presets, discretisation, truecolor, shade.
%
%   DESCRIPTION
%     Closes Stage B. The one claim that matters numerically is the shade
%     composition, which is asserted EXACTLY rather than to a tolerance -
%     any gamma or blend curve would make the shade unrecoverable from
%     the output, so "exactly halved" is the specification, not an
%     approximation of it.
%
%   ACCURACY
%     No external oracle: a colour ramp is a design choice, and no
%     authority outside this project certifies one. What IS asserted is
%     the arithmetic around it - composition, quantisation, and the order
%     in which gaps beat masks beat out-of-range.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestB3");
%
%   LIMITATIONS
%     Nothing here renders. Whether the ramp LOOKS right is Stage F's
%     rasterise-and-look check; whether it is monotone in lightness is
%     asserted here as arithmetic.
%
%   See also GEO.COLORMAPS, GEO.HILLSHADE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = "geo.colormaps"
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function everyPresetBuildsAtAnySize(tc)
            for nm = geo.colormaps("names")
                for n = [2 7 256]
                    c = geo.colormaps("get", nm, n);
                    tc.verifyEqual(size(c), [n 3], sprintf('%s at n=%d', nm, n));
                    tc.verifyTrue(all(c(:) >= 0 & c(:) <= 1), ...
                        sprintf('%s must stay inside the unit cube', nm));
                end
            end
        end

        function everyV1PresetNameStillWorks(tc)
            % All six of v1's survive, so a ported script keeps its
            % ColormapName. The three CVD tables are CC0 and attributed
            % in LICENSE; the other three come from base MATLAB.
            for nm = ["viridis" "magma" "cividis" "parula" "jet" "turbo"]
                c = geo.colormaps("get", nm, 32);
                tc.verifyEqual(size(c), [32 3], nm);
            end
            tc.verifyError(@() geo.colormaps("get", "atlantis"), ...
                'geo:colormaps:UnknownPreset');
        end

        function theCvdTablesAreVerbatimAtTheirNativeSize(tc)
            % 256 rows is the table itself, with no interpolation, so a
            % caller asking for the standard size gets the published
            % numbers unaltered.
            for nm = ["viridis" "magma" "cividis"]
                c = geo.colormaps("get", nm, 256);
                tc.verifyEqual(size(c), [256 3]);
                tc.verifyTrue(all(c(:) >= 0 & c(:) <= 1));
            end
            % Published first and last rows, as a fingerprint on the file.
            v = geo.colormaps("get", "viridis", 256);
            tc.verifyEqual(v(1,:), [0.267004 0.004874 0.329415], ...
                'AbsTol', 5e-7);
            cv = geo.colormaps("get", "cividis", 256);
            tc.verifyEqual(cv(1,:), [0 0.135112 0.304751], 'AbsTol', 5e-7);
        end

        function badColormapsAreRejected(tc)
            tc.verifyError(@() geo.colormaps("discretize", ones(4,2), 3), ...
                'geo:colormaps:NotAColormap');
            tc.verifyError(@() geo.colormaps("discretize", 2*ones(4,3), 3), ...
                'geo:colormaps:NotAColormap');
            tc.verifyError(@() geo.colormaps("truecolor", ones(3), ...
                ones(4,3), Shade = ones(2)), 'geo:colormaps:ShadeMismatch');
        end

        function truecolorReturnsAnImage(tc)
            Z = reshape(1:12, 3, 4);
            rgb = geo.colormaps("truecolor", Z, "divergent");
            tc.verifyEqual(size(rgb), [3 4 3]);
            tc.verifyTrue(all(rgb(:) >= 0 & rgb(:) <= 1));
        end

        function gapsBeatMasksBeatOutOfRange(tc)
            % The order is a contract: a value can be missing AND masked
            % AND out of range, and missing must win, or a gap draws as
            % data somebody chose a colour for.
            Z = [-5 0.5 5 NaN];
            mask = [false false false true];
            rgb = geo.colormaps("truecolor", Z, "divergent", ...
                CLim = [0 1], UnderColor = [1 0 0], OverColor = [0 1 0], ...
                Mask = mask, MaskColor = [0 0 1], NaNColor = [1 1 0]);
            tc.verifyEqual(squeeze(rgb(1,1,:)).', [1 0 0], 'under');
            tc.verifyEqual(squeeze(rgb(1,3,:)).', [0 1 0], 'over');
            tc.verifyEqual(squeeze(rgb(1,4,:)).', [1 1 0], ...
                'a NaN that is also masked is still a gap');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function theDivergingRampIsSymmetricAndLightestInTheMiddle(tc)
            % The property a signed anomaly field needs, and the reason
            % this ramp is generated rather than borrowed.
            c = geo.colormaps("get", "divergent", 257);
            L = mean(c, 2);
            [~, k] = max(L);
            tc.verifyEqual(k, 129, ...
                'the lightest row is the centre, so zero sits there');
            % Lightness falls monotonically towards both ends.
            tc.verifyTrue(all(diff(L(1:129)) >= -1e-12), 'cold limb rises');
            tc.verifyTrue(all(diff(L(129:end)) <= 1e-12), 'warm limb falls');
            % Cold end is bluest, warm end reddest.
            tc.verifyGreaterThan(c(1,3), c(1,1), 'cold end is blue');
            tc.verifyGreaterThan(c(end,1), c(end,3), 'warm end is red');
        end

        function theSequentialRampIsMonotoneInLightness(tc)
            L = mean(geo.colormaps("get", "sequential", 128), 2);
            tc.verifyTrue(all(diff(L) <= 1e-12), ...
                'a sequential ramp that is not monotone misreads as data');
        end

        function theCvdRampsRiseMonotonicallyInLightness(tc)
            % The property they were designed for, and the reason this
            % project uses the published tables rather than a substitute.
            %
            % THE QUANTITY IS CIELAB L*, NOT REC.601 LUMA, and the first
            % version of this test got that wrong. Rec.601 weights are a
            % broadcast-engineering approximation of luminance; these
            % colormaps are constructed uniform in PERCEPTUAL LIGHTNESS,
            % which is L* in CIELAB after the sRGB transfer function is
            % undone. Measured against Rec.601 luma, viridis reads a
            % maximum DECREASE of 1.70e-3 - it is genuinely not monotone
            % in that quantity, and the test failed correctly. Asserting
            % the right quantity is the repair; loosening the bound would
            % have been the instrument destroyed in place (§4.6).
            for nm = ["viridis" "magma" "cividis"]
                L = tc.cielabLightness(geo.colormaps("get", nm, 256));
                tc.verifyAndRecord(max(-diff(L)), 0, ...
                    "CIELAB L* monotonicity, " + nm, "L*");
                tc.verifyGreaterThan(L(end) - L(1), 50, ...
                    sprintf('%s must span most of the L* range', nm));
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'precision'})

        function shadeHalvesEveryChannelExactly(tc)
            % EXACT, not to a tolerance. The documented formula is
            % rgb .* Shade with no gamma and no blend curve, so a factor
            % of 0.5 must halve every channel bit-for-bit.
            Z = reshape(linspace(0, 1, 12), 3, 4);
            plain = geo.colormaps("truecolor", Z, "divergent");
            shaded = geo.colormaps("truecolor", Z, "divergent", ...
                Shade = 0.5 * ones(3, 4));
            tc.verifyTrue(isequal(shaded, plain * 0.5), ...
                'the composition must be exactly multiplicative');
            tc.verifyAndRecord(max(abs(shaded(:) - plain(:) * 0.5)), 0, ...
                "truecolor Shade = 0.5 composition", "");
        end

        function discretisationKeepsTheRowCountAndTheBandCount(tc)
            c = geo.colormaps("get", "divergent", 256);
            for nb = [2 5 16]
                d = geo.colormaps("discretize", c, nb);
                tc.verifyEqual(size(d), size(c), ...
                    'the row count is unchanged so CLim need not move');
                tc.verifyEqual(size(unique(d, 'rows'), 1), nb, ...
                    sprintf('exactly %d distinct colours', nb));
            end
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aConstantFieldDoesNotDivideByZero(tc)
            rgb = geo.colormaps("truecolor", 5*ones(3), "divergent");
            tc.verifyTrue(all(isfinite(rgb(:))), ...
                'a field with no spread still has to render');
        end

        function anAllNaNFieldIsAllGapColour(tc)
            rgb = geo.colormaps("truecolor", nan(2,2), "divergent", ...
                NaNColor = [0.2 0.4 0.6]);
            tc.verifyEqual(squeeze(rgb(1,1,:)).', [0.2 0.4 0.6]);
            tc.verifyEqual(squeeze(rgb(2,2,:)).', [0.2 0.4 0.6]);
        end

        function aTwoRowColormapStillWorks(tc)
            rgb = geo.colormaps("truecolor", [0 1], [0 0 0; 1 1 1], ...
                CLim = [0 1]);
            tc.verifyEqual(squeeze(rgb(1,1,:)).', [0 0 0]);
            tc.verifyEqual(squeeze(rgb(1,2,:)).', [1 1 1]);
        end

        function discretisingToOneLevelIsFlat(tc)
            d = geo.colormaps("discretize", geo.colormaps("get", ...
                "divergent", 64), 1);
            tc.verifyEqual(size(unique(d, 'rows'), 1), 1);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'vectorisation'})

        function truecolorMatchesPerPixelMapping(tc)
            rng(42, 'twister');
            Z = randn(8, 9);
            cmap = geo.colormaps("get", "divergent", 64);
            lim = [-2 2];
            batch = geo.colormaps("truecolor", Z, cmap, CLim = lim);
            one = zeros(8, 9, 3);
            for i = 1:8
                for j = 1:9
                    one(i,j,:) = geo.colormaps("truecolor", Z(i,j), ...
                        cmap, CLim = lim);
                end
            end
            tc.verifyTrue(isequal(batch, one), ...
                'a whole-array mapping must equal per-pixel calls, bitwise');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function shadingIsAssociativeWithItself(tc)
            % Shading by a then by b equals shading once by a.*b, which is
            % what "multiplicative with no curve" means operationally.
            Z = reshape(linspace(0, 1, 12), 3, 4);
            s1 = 0.8 * ones(3,4);
            s2 = 0.5 * ones(3,4);
            once = geo.colormaps("truecolor", Z, "divergent", ...
                Shade = s1 .* s2);
            twice = geo.colormaps("truecolor", Z, "divergent", ...
                Shade = s1) .* 0.5;
            tc.verifyAndRecord(max(abs(once(:) - twice(:))), 1e-15, ...
                "shade composition associativity", "");
        end

        function shiftingCLimShiftsTheColours(tc)
            % Mapping Z with limits L is the same as mapping Z+c with
            % limits L+c: the ramp knows only where a value sits BETWEEN
            % the limits, never its absolute magnitude.
            rng(42, 'twister');
            Z = randn(6, 7);
            a = geo.colormaps("truecolor", Z, "divergent", CLim = [-2 2]);
            b = geo.colormaps("truecolor", Z + 10, "divergent", ...
                CLim = [8 12]);
            tc.verifyAndRecord(max(abs(a(:) - b(:))), 1e-12, ...
                "truecolor invariance to a common offset", "");
        end

        function discretisingTwiceChangesNothing(tc)
            c = geo.colormaps("get", "divergent", 256);
            once = geo.colormaps("discretize", c, 8);
            twice = geo.colormaps("discretize", once, 8);
            tc.verifyTrue(isequal(twice, once), ...
                'quantising an already quantised ramp is a no-op');
        end
    end

    % ==================================================================
    methods (Access = private)
        function L = cielabLightness(~, rgb)
            %CIELABLIGHTNESS  L* from sRGB, without a toolbox.
            %   Undo the sRGB transfer function, take the D65 Y
            %   coordinate, then the CIELAB lightness curve. Written out
            %   rather than called from Image Processing, which this
            %   project does not depend on (defect F1's whole subject).
            c = rgb;
            lin = c / 12.92;
            hi = c > 0.04045;
            lin(hi) = ((c(hi) + 0.055) / 1.055).^2.4;
            Y = lin * [0.2126; 0.7152; 0.0722];      % D65 luminance
            f = Y.^(1/3);
            low = Y <= (6/29)^3;
            f(low) = Y(low) * (29/6)^2 / 3 + 4/29;
            L = 116 * f - 16;
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function shadingIsMarginalAgainstTheMappingItself(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED - V5 open. The CLAIM is that shading is cheap
            % against the colour lookup it decorates, so the budget is
            % against the same call WITHOUT Shade: same array, same
            % colormap, one extra multiply (D-016).
            rng(42, 'twister');
            Z = randn(2161, 1000);
            s = 0.5 * ones(size(Z));
            cmap = geo.colormaps("get", "divergent", 256);
            tc.assertRatioBudget( ...
                @() geo.colormaps("truecolor", Z, cmap, Shade = s), ...
                @() geo.colormaps("truecolor", Z, cmap), ...
                2.5, 1.4, ...
                "truecolor with Shade / without [PREDICTED]");
        end
    end
end
