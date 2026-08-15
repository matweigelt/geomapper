function out = cache(cmd, key, value)
%GEO.CACHE  Session cache for parsed and projected coastlines.
%
%   SYNTAX
%     V = GEO.CACHE("get", KEY)
%     GEO.CACHE("put", KEY, VALUE)
%     GEO.CACHE("clear")
%     S = GEO.CACHE("stats")
%
%   DESCRIPTION
%     Stops a coastline being re-read and re-projected on every plot
%     (defect F14: v1 had no cache at all, and "persistent" appears zero
%     times in its 36 files). Full-resolution GSHHG takes seconds to
%     parse; a four-panel figure paid that four times.
%
%     KEYS ARE STRUCTS, NEVER CONCATENATED STRINGS. The key for a parsed
%     coastline is its resolved absolute path, its file modification time
%     and a hash of the options; for a projected one, that plus the CRS.
%     Composing those into "path|mtime|opts" and splitting them back apart
%     is exactly what §2.7 forbids - a path containing the separator would
%     silently collide with a different file. The struct is hashed once,
%     as a whole, and never parsed.
%
%     A CACHE IS A PRESERVING MECHANISM, and §F4 says those are precisely
%     the mechanisms that destroy. Three hazards are therefore handled
%     explicitly rather than hoped away:
%
%       eviction        LRU at 20 entries. Stated, bounded, and tested.
%       changed mtime   A file edited on disk yields a different key, so
%                       the stale entry is never returned - it simply
%                       ages out. Nothing has to notice the edit.
%       failed parse    NOTHING IS STORED until the value exists. A
%                       reader that throws half way leaves no entry, so a
%                       retry re-reads rather than returning a truncated
%                       coastline forever. This is the one that would
%                       have been quietest, and it has its own test.
%
%   INPUTS
%     cmd    (1,1) string  "get" | "put" | "clear" | "stats".
%     key    (1,1) struct  Any struct; hashed as a whole.
%     value                Anything, for "put".
%
%   OUTPUTS
%     "get"    the stored value, or [] on a miss.
%     "stats"  (1,1) struct: Entries, Hits, Misses, Bound.
%
%   ACCURACY
%     No numerical claim. The cache is required to be TRANSPARENT: reading
%     twice through it must be ISEQUALN to reading twice with it cleared
%     in between. That is the property that matters, and it is the
%     metamorphic test in TestC1_io.
%
%   ERRORS
%     Argument validation:
%       geo:cache:BadCommand - cmd is not one of the four
%
%   EXAMPLE
%     k = struct('path', p, 'mtime', d.datenum, 'levels', 1);
%     xy = geo.cache("get", k);
%     if isempty(xy)
%         xy = geo.readCoastline(p, Levels = 1);
%         geo.cache("put", k, xy);          % only AFTER it succeeded
%     end
%
%   LIMITATIONS
%     Session-scoped and in-memory: CLEAR ALL empties it, and nothing
%     persists between MATLAB sessions. Bounded by ENTRY COUNT, not by
%     bytes, so twenty full-resolution coastlines is a large amount of
%     memory; a caller holding several should clear between figures.
%
%   See also GEO.READCOASTLINE, GEO.READGRID.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    cmd (1,1) string
    key = []
    value = []
end

persistent KEYS VALUES AGE HITS MISSES TICK
if isempty(HITS)
    KEYS = strings(1, 0);
    VALUES = {};
    AGE = [];
    HITS = 0;
    MISSES = 0;
    TICK = 0;
end
BOUND = 20;

switch cmd
    case "get"
        h = hashKey(key);
        i = find(KEYS == h, 1);
        if isempty(i)
            MISSES = MISSES + 1;
            out = [];
            return
        end
        HITS = HITS + 1;
        TICK = TICK + 1;
        AGE(i) = TICK;                  % least-recently-USED, not inserted
        out = VALUES{i};

    case "put"
        h = hashKey(key);
        TICK = TICK + 1;
        i = find(KEYS == h, 1);
        if isempty(i)
            if numel(KEYS) >= BOUND
                [~, oldest] = min(AGE);
                KEYS(oldest) = [];
                VALUES(oldest) = [];
                AGE(oldest) = [];
            end
            i = numel(KEYS) + 1;
        end
        KEYS(i) = h;
        VALUES{i} = value;
        AGE(i) = TICK;
        out = [];

    case "clear"
        KEYS = strings(1, 0);
        VALUES = {};
        AGE = [];
        HITS = 0;
        MISSES = 0;
        TICK = 0;
        out = [];

    case "stats"
        out = struct('Entries', numel(KEYS), 'Hits', HITS, ...
                     'Misses', MISSES, 'Bound', BOUND);

    otherwise
        error('geo:cache:BadCommand', ...
            '"%s" is not one of "get", "put", "clear", "stats".', cmd);
end
end

% ======================================================================
function h = hashKey(key)
%HASHKEY  One hash of the WHOLE key struct. Never a parsed composite.
%   The struct is serialised by MATLAB, not by string concatenation, so a
%   path that happens to contain a separator character cannot collide
%   with a different file's key (§2.7).
h = string(sha256OfText(char(mat2str(getByteStreamFromArray(key)))));
end
