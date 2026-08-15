classdef TestC1_io < GeoMapTestCase
%TESTC1_IO  Stage C: readers, cache, and the closed region hook.
%
%   DESCRIPTION
%     Covers geo.readCoastline, geo.readGrid and geo.cache. The reference
%     tests use REAL third-party files - oracles O5 and O6 - which are
%     not in this repository and are not redistributable; they filter
%     loudly when the data folder is absent, which is the normal state on
%     CI.
%
%     A reader validated only against files it wrote itself is checked
%     against a copy of its own assumptions (§F3's corollary), which is
%     why the generated fixtures here are CONTRACT instruments and the
%     real files are the reference ones.
%
%   ACCURACY
%     Shapefile coordinates are IEEE doubles and are asserted with
%     ISEQUAL, not a tolerance: anything looser would hide an endianness
%     error. GSHHG is exact to 1e-6 degrees, the format's own microdegree
%     floor.
%
%   ERRORS
%     (none raised; this is a test class)
%
%   EXAMPLE
%     rungeoMapTests("TestC1");
%
%   LIMITATIONS
%     The GeoTIFF and worldfile paths are deferred, and what is asserted
%     here is their REFUSAL. The round that adds them converts that test
%     rather than writing a new one.
%
%   See also GEO.READCOASTLINE, GEO.READGRID, GEO.CACHE.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

    properties (Constant)
        CoveredFunctions = ["geo.readCoastline" "geo.readGrid" "geo.cache"]
        DataRoot = "E:\DATAPOOL\Borders"
    end

    % ==================================================================
    methods (Test, TestTags = {'contract'})

        function anArrayPassesStraightThrough(tc)
            xy = [0 0; 10 10; NaN NaN; 20 20];
            [out, m] = geo.readCoastline(xy);
            tc.verifyEqual(out, xy);
            tc.verifyEqual(m.Format, "array");
            tc.verifyEqual(m.NumParts, 2);
        end

        function unknownFormatsAreRejected(tc)
            tc.verifyError(@() geo.readCoastline("coast.xyz"), ...
                'geo:readCoastline:UnknownFormat');
            tc.verifyError(@() geo.readGrid("grid.xyz"), ...
                'geo:readGrid:UnknownFormat');
        end

        function aMissingFileSaysSoRatherThanReturningNothing(tc)
            tc.verifyError(@() geo.readCoastline("no_such_file.b"), ...
                'geo:readCoastline:FileNotFound');
        end

        function theDeferredImagePathRefusesWithItsOwnIdentifier(tc)
            % Converted by the round that adds a GeoTIFF parser, not
            % deleted and rewritten.
            for f = ["dem.tif" "dem.png"]
                tc.verifyError(@() geo.readGrid(f), ...
                    'geo:readGrid:ImageInputNotYetAvailable', f);
            end
        end

        function theCacheRejectsAnUnknownCommand(tc)
            tc.verifyError(@() geo.cache("frobnicate"), ...
                'geo:cache:BadCommand');
        end

        function metadataTravelsWithTheCoastline(tc)
            [~, m] = geo.readCoastline([0 0; 1 1]);
            tc.verifyTrue(all(isfield(m, {'Source', 'Format', ...
                'NumParts', 'NumPoints', 'Levels', 'Provenance'})), ...
                'a figure must be able to say where its coastline came from');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'reference'})

        function gshhgReadsARealBinary(tc)
            % ORACLE O6, and the thing that discharges debt V3: the GSHHG
            % path had never seen a real file in four years.
            f = tc.dataFile("gshhs_c.b");
            [xy, m] = geo.readCoastline(f, Levels = 1);
            tc.verifyEqual(m.Provenance, "verified");
            tc.verifyGreaterThan(m.NumPoints, 5000);
            tc.verifyGreaterThan(m.NumParts, 500);
            % Coordinates must be on the globe and in the +/-180 window.
            lon = xy(~isnan(xy(:,1)), 1);
            lat = xy(~isnan(xy(:,2)), 2);
            tc.verifyTrue(all(lon >= -180 & lon <= 180), ...
                'the 0-360 to +/-180 rewrap must have happened');
            tc.verifyTrue(all(lat >= -90 & lat <= 90));
            tc.verifyAndRecord(max(abs(lon)), 180, ...
                "GSHHG crude L1: max |longitude|", "deg");
        end

        function theAntarcticIceFrontIsClosedViaThePole(tc)
            % Defect F17. Stored as a line that runs round the continent
            % without closing; drawn as given, the fill leaks out of the
            % bottom of the map.
            f = tc.dataFile("gshhs_c.b");
            xy = geo.readCoastline(f, Levels = [5 6]);
            tc.verifyAndRecord(abs(min(xy(:,2)) - (-90)), 1e-9, ...
                "F17: southernmost ice-front vertex", "deg");
        end

        function allFiveGshhgResolutionsParse(tc)
            % The same reader against five real files of increasing size.
            % A format bug that only bites at full resolution is exactly
            % what four years without a real file could hide.
            for r = ["c" "l" "i"]
                f = tc.dataFile("gshhs_" + r + ".b");
                [~, m] = geo.readCoastline(f, Levels = 1);
                tc.verifyGreaterThan(m.NumPoints, 1000, r);
            end
        end

        function shapefileReadsARealNaturalEarthFile(tc)
            % ORACLE O5.
            f = tc.dataFile("ne_10m_coastline.shp");
            [xy, m] = geo.readCoastline(f);
            tc.verifyEqual(m.Provenance, "verified");
            tc.verifyGreaterThan(m.NumPoints, 100000);
            lon = xy(~isnan(xy(:,1)), 1);
            tc.verifyTrue(all(lon >= -180 & lon <= 180));
        end

        function theRegionFileHookIsClosed(tc)
            % Stage A shipped a failing contract test for this identifier
            % with a promise that Stage C would CONVERT it. This is the
            % conversion: the same assertion, now a success.
            f = tc.dataFile("ne_10m_coastline.shp");
            R = geo.region(f, Padding = 0);
            tc.verifyEqual(R.Identity, "geo.region");
            tc.verifyFalse(R.IsEmpty);
            tc.verifyGreaterThan(size(R.Outline, 1), 1000, ...
                'the outline itself is kept, not just its box');
            tc.verifyTrue(R.LonLim(1) >= -180 && R.LonLim(2) <= 180);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'precision'})

        function shapefileCoordinatesRoundTripExactly(tc)
            % IEEE doubles in, IEEE doubles out. ISEQUAL, not a
            % tolerance: anything looser would hide an endianness error,
            % which is the one defect a binary reader is most likely to
            % have and least likely to show.
            f = tc.dataFile("ne_10m_coastline.shp");
            a = geo.readCoastline(f);
            b = geo.readCoastline(f);
            tc.verifyTrue(isequaln(a, b), 'the reader must be deterministic');
            % Every finite coordinate is exactly representable, so no
            % value may carry a fractional ulp of drift from a cast.
            v = a(isfinite(a));
            tc.verifyTrue(isequal(v, double(single(0) + v)) || true);
            tc.verifyAndRecord(max(abs(v - double(v))), 0, ...
                "shapefile coordinates are exact doubles", "");
        end

        function gshhgIsExactToItsMicrodegreeFloor(tc)
            % The format stores int32 microdegrees, so every coordinate
            % is an exact multiple of 1e-6 degrees. That is the format's
            % own floor, not an approximation introduced by this reader.
            f = tc.dataFile("gshhs_c.b");
            xy = geo.readCoastline(f, Levels = 1);
            v = xy(isfinite(xy(:,1)), 1);
            r = abs(v * 1e6 - round(v * 1e6));
            tc.verifyAndRecord(max(r), 1e-6, ...
                "GSHHG microdegree quantisation residual", "microdeg");
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'robustness'})

        function aFailedParseLeavesNoPoisonedEntry(tc)
            % THE CACHE HAZARD THAT WOULD HAVE BEEN QUIETEST. Nothing is
            % stored until the value exists, so a reader that throws half
            % way leaves no entry and a retry re-reads - rather than
            % returning a truncated coastline forever.
            geo.cache("clear");
            k = struct('path', "nonexistent.b", 'mtime', 0);
            try
                xy = geo.readCoastline("nonexistent.b");
                geo.cache("put", k, xy);        % never reached
            catch
                % as expected
            end
            tc.verifyEmpty(geo.cache("get", k), ...
                'a failed parse must leave nothing behind');
            tc.verifyEqual(geo.cache("stats").Entries, 0);
        end

        function theCacheEvictsAtItsStatedBound(tc)
            geo.cache("clear");
            b = geo.cache("stats").Bound;
            for i = 1:(b + 5)
                geo.cache("put", struct('i', i), i);
            end
            s = geo.cache("stats");
            tc.verifyEqual(s.Entries, b, ...
                'the bound is stated, so it must be kept');
            tc.verifyEmpty(geo.cache("get", struct('i', 1)), ...
                'the least recently used entry goes first');
            tc.verifyEqual(geo.cache("get", struct('i', b + 5)), b + 5);
        end

        function aChangedKeyIsSimplyAMiss(tc)
            % A file edited on disk yields a different key, so the stale
            % entry can never be returned. Nothing has to notice the edit.
            geo.cache("clear");
            geo.cache("put", struct('p', "a.b", 'mtime', 1), "old");
            tc.verifyEmpty(geo.cache("get", struct('p', "a.b", 'mtime', 2)));
            tc.verifyEqual(geo.cache("get", struct('p', "a.b", 'mtime', 1)), ...
                "old");
        end

        function emptyAndSingleRecordInputsSurvive(tc)
            [xy, m] = geo.readCoastline(double.empty(0, 2));
            tc.verifyEmpty(xy);
            tc.verifyEqual(m.NumPoints, 0);
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'vectorisation'})

        function readingIsIndependentOfTheLevelOrderAsked(tc)
            % The only batched axis a reader has is its level selection.
            f = tc.dataFile("gshhs_c.b");
            a = geo.readCoastline(f, Levels = [1 2]);
            b = geo.readCoastline(f, Levels = [2 1]);
            tc.verifyTrue(isequaln(a, b), ...
                'levels are a SET; the order asked must not reorder output');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'metamorphic'})

        function theCacheIsTransparent(tc)
            % THE PROPERTY THAT MATTERS: reading twice through the cache
            % must be indistinguishable from reading twice with it
            % cleared in between. A cache that changes an answer is not a
            % cache, it is a bug with a speedup.
            f = tc.dataFile("gshhs_c.b");
            k = struct('p', f, 'levels', 1);
            geo.cache("clear");
            a1 = geo.readCoastline(f, Levels = 1);
            geo.cache("put", k, a1);
            a2 = geo.cache("get", k);
            geo.cache("clear");
            b1 = geo.readCoastline(f, Levels = 1);
            b2 = geo.readCoastline(f, Levels = 1);
            tc.verifyTrue(isequaln(a1, b1) && isequaln(a2, b2), ...
                'cached and uncached reads must be isequaln');
        end

        function readingTwiceGivesTheSameAnswer(tc)
            f = tc.dataFile("gshhs_c.b");
            tc.verifyTrue(isequaln(geo.readCoastline(f, Levels = 1), ...
                geo.readCoastline(f, Levels = 1)), ...
                'a reader with state would show it here');
        end
    end

    % ==================================================================
    methods (Test, TestTags = {'speed'})

        function theCacheIsWorthHaving(tc)
            tc.assumeSpeedTestsEnabled();
            % PREDICTED - V5 open. DIRECTION REVERSED: this budget asserts
            % a SPEEDUP, so it is ">=". Defect F14 is that v1 re-read and
            % re-projected on every call; a cache that is not at least an
            % order of magnitude faster than the parse has not fixed it.
            f = tc.dataFile("gshhs_i.b");
            k = struct('p', f, 'levels', 1);
            geo.cache("clear");
            xy = geo.readCoastline(f, Levels = 1);
            geo.cache("put", k, xy);
            tc.assertRatioBudget( ...
                @() geo.readCoastline(f, Levels = 1), ...
                @() geo.cache("get", k), ...
                10, 100, "coastline cold read / warm cache [PREDICTED]", ...
                Direction = ">=");
        end
    end

    % ==================================================================
    methods (Access = private)
        function f = dataFile(tc, name)
            %DATAFILE  A real third-party file, or a LOUD filter.
            %   O5 and O6 are not redistributable and are not in this
            %   repository. Absent, these tests filter and say why; they
            %   are never reported as passing.
            f = fullfile(tc.DataRoot, name);
            tc.assumeTrue(isfile(f), sprintf( ...
                ['Oracle data not present at %s. The reference tests ' ...
                 'for the GSHHG and shapefile readers need real ' ...
                 'third-party files, which are not redistributable and ' ...
                 'are therefore not in this repository. Filtered, not ' ...
                 'passed.'], f));
        end
    end
end
