#!/usr/bin/env python3
"""makeOracleFixtures - build the shipped GSHHG fixture subset, reproducibly.

A fixture nobody can rebuild is a magic file. This script is the rule that
made the three binaries in tests/data/oracle, so a later reader can check
them rather than trust them, and can rebuild them against a newer GSHHG
release without guessing what was done the first time.

WHAT IT DOES NOT DO. It does not generate data. Every byte written is a
byte read out of the published archive, in its original order. gshhs_c.b
is copied whole; the other two are cut at a record boundary, which for
this format yields a shorter but entirely valid file.

FORMAT. A GSHHG binary is a flat stream of records. Each record is a
44-byte header of eleven big-endian int32 - id, n, flag, west, east,
south, north, area, area_full, container, ancestor - followed by n point
pairs of two big-endian int32 in microdegrees. The polygon level is the
low byte of flag. Nothing else is needed to find a record boundary.

SELF-CHECK. Every file written is re-parsed and must consume to its own
last byte. A prefix that leaves a ragged tail is not a valid file, and
the only way to know is to read it back.

USAGE
    python3 tools/makeOracleFixtures.py path/to/gshhg-bin-2.3.7.zip

geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)
"""
from __future__ import annotations
import hashlib, pathlib, struct, sys, zipfile

HEADER = 44
OUT = pathlib.Path(__file__).resolve().parent.parent / "tests" / "data" / "oracle"
# name -> level-1 point target, or None for "copy the whole file"
WANTED = {"gshhs_c.b": None, "gshhs_l.b": 20_000, "gshhs_i.b": 60_000}


def records(b: bytes):
    """(offset, size, level, npoints) for every complete record in b."""
    out, i = [], 0
    while i + HEADER <= len(b):
        h = struct.unpack(">11i", b[i:i + HEADER])
        n = h[1]
        size = HEADER + 8 * n
        if i + size > len(b):
            break                      # ragged tail: not a record
        out.append((i, size, h[2] & 255, n))
        i += size
    return out


def cut(b: bytes, target: int) -> tuple[bytes, int, int]:
    """The shortest prefix ending on a record boundary past `target` L1 points."""
    l1 = 0
    for k, (off, size, level, n) in enumerate(records(b)):
        if level == 1:
            l1 += n
        if l1 >= target:
            return b[:off + size], k + 1, l1
    raise SystemExit(f"only {l1} level-1 points in the whole file; "
                     f"target {target} is unreachable")


def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    z = zipfile.ZipFile(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "COPYING.LESSERv3").write_bytes(z.read("COPYING.LESSERv3"))

    for name, target in WANTED.items():
        src = z.read(name)
        if target is None:
            out, npoly, l1 = src, len(records(src)), \
                sum(n for _, _, lv, n in records(src) if lv == 1)
            rule = "complete published file"
        else:
            out, npoly, l1 = cut(src, target)
            rule = "byte-exact prefix"
        (OUT / name).write_bytes(out)

        # Self-check: it must consume to its own last byte.
        r = records(out)
        consumed = sum(s for _, s, _, _ in r)
        state = "CLEAN" if consumed == len(out) else "RAGGED"
        print(f"{name:12s} {rule:26s} {len(out):9d} B  {npoly:5d} poly  "
              f"L1={l1:7d}  {state}")
        if state != "CLEAN":
            print("  REFUSING: the prefix does not end on a record boundary.")
            return 1
        print(f"  sha256 out {sha(out)}")
        print(f"  sha256 src {sha(src)}")
    print("\nUpdate tests/data/oracle/PROVENANCE.md with the digests above.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
