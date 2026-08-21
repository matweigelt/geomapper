# Shipped oracle fixtures — provenance

**These are real third-party data, not synthetic stand-ins.** Every byte here
came out of a published distribution and none of it was generated. A fixture
that a test can pass against because this project also wrote it verifies
nothing; that is why nothing in this folder is constructed.

Built by [`tools/makeOracleFixtures.py`](../../../tools/makeOracleFixtures.py),
which is in the repository so the subset is reproducible rather than a
mystery someone once made.

---

## Why this folder exists

Audit finding **A-6**: CI filtered 24 of 491 points on every green run, and
**18 of them were the whole real-data I/O tier** — the tests that discharged
debt V3 and filled oracles O5 and O6. They ran only on the bridge machine,
whose data pool is a local `E:` drive, and both hosts printed the same
six-line green gate in the same words.

`TestC1_io`'s help block said the data were *"not redistributable"*. **That
was read, not checked.** The licences say otherwise, and are quoted below.

---

## Source and licence

| | |
|---|---|
| Product | **GSHHG** — A Global Self-consistent, Hierarchical, High-resolution Geography Database |
| Authors | Paul Wessel (SOEST, University of Hawai'i) and Walter H. F. Smith (NOAA Geosciences Lab) |
| Version | **2.3.7**, released 15-Jun-2017 |
| Archive | `gshhg-bin-2.3.7.zip`, 118 617 033 bytes, from `https://www.soest.hawaii.edu/pwessel/gshhg/` |
| Licence | **GNU Lesser General Public License**. From the project page: *starting with version 2.2.2, GSHHG has been released under the GNU Lesser General Public License.* |
| Licence text | `COPYING.LESSERv3` in this folder, verbatim from the archive |
| Retrieved | 21-Aug-2026 |

**Cite as:** Wessel, P., and W. H. F. Smith (1996), A global self-consistent,
hierarchical, high-resolution shoreline database, *J. Geophys. Res.*, 101(B4),
8741–8743.

---

## What is here, and how each file was made

| file | bytes | rule | polygons | L1 points |
|---|---|---|---|---|
| `gshhs_c.b` | 182 724 | **complete published file, unmodified** | 1 781 | 7 270 |
| `gshhs_l.b` | 186 924 | byte-exact **prefix** at a record boundary | 15 | 20 186 |
| `gshhs_i.b` | 535 212 | byte-exact **prefix** at a record boundary | 3 | 66 885 |

**The prefix rule.** A GSHHG binary is a flat stream of records, each a
44-byte header of eleven big-endian `int32` followed by `n` point pairs. A
prefix cut at a record boundary is therefore a *valid GSHHG file* containing
the first N polygons and nothing else — no re-encoding, no re-ordering, no
rounding. Each prefix was cut at the first record boundary past 20 000
(`l`) and 60 000 (`i`) level-1 points, and each was then re-parsed to prove
it consumes to its own last byte with nothing ragged left over.

**What a prefix is not.** GSHHG is sorted by decreasing polygon area, so a
prefix holds the largest landmasses and drops the small ones. It exercises
the reader's format handling at each resolution. **It is not the full
product and no reference count may be asserted against it.**

## SHA-256

```
dd0e9e2f8f121b6ae6a421afd1259ab369c2bac7f741a430db5438820c35aee9  gshhs_c.b   (= published file)
333330f307e198e17fe8143933a09bf9270cf1b159abd810546a96873d2a8e8f  gshhs_l.b   (prefix)
9d9c53e2150ff0d65f3c160a3741a98255d0c02392eb3706c24cd2f5c60572f9  gshhs_i.b   (prefix)
```

Of the published sources:

```
7aaa356af4e8d06438319a5c756545325b40fd9080871216d52d377d8a7f6b15  gshhs_l.b   (full, 1 212 340 bytes)
7d44bf4e16efe6056ff9d147ac0af189bbf0c16a31608426ef63ff8a91c418db  gshhs_i.b   (full, 5 516 184 bytes)
```

---

## Precedence, and why it matters

`TestC1_io.dataFile` resolves in this order:

1. `DataRoot` — the full products on the bridge machine. **Always preferred.**
2. This folder.
3. Neither: the point **filters**, loudly, and is never reported as passed.

The order is not a convenience. `gshhs_c.b` here is the complete published
file, so a reference count asserted against it is the same measurement on
either host — but `gshhs_l.b` and `gshhs_i.b` are prefixes, and a test that
asserted a whole-product number against a prefix would be measuring the
fixture. Preferring the pool means the bridge keeps measuring the real
thing, and CI measures the reader.

## Still not here

**ETOPO 2022 v1 60 s** (`surface` and `bed`) is ~450 MB per file. There is no
subset of it that is both small and still global, and the five tests that use
it assert global cell-centring, dimension order and a reduction against the
grid it came from. A decimated copy would change what those tests mean while
still looking like a pass, so none is shipped and they stay pinned to the
pool.

**Natural Earth `ne_10m_coastline.shp`** (6 806 860 bytes, **public domain** —
*"No permission is needed to use Natural Earth"*) is redistributable and is
the next fixture to add; it needs a shapefile subsetter and its own
confirming run.

---

*geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)*
