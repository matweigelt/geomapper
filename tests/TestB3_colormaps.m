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

        function theDroppedV1PresetsFailWithAnExplanation(tc)
            % viridis, magma and cividis are third-party tabulated data
            % and are deliberately not reproduced here. The error says so
            % and says what to do instead, because a caller porting a v1
            % script will hit exactly this.
            for nm = ["viridis" "magma" "cividis"]
                tc.verifyError(@() geo.colormaps("get", nm), ...
                    'geo:colormaps:UnknownPreset', nm);
            end
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
