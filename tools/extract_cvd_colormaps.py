#!/usr/bin/env python3
"""extract_cvd_colormaps — regenerate data/cvd_colormaps.txt.

Ships beside the data it produces so a reader can REGENERATE rather than
trust. The tables are viridis, magma and cividis, all three CC0
public-domain dedications; see the generated file's header and LICENSE
for attribution.

Not run by CI: it needs matplotlib, which is not a dependency of this
project and must not become one. Run it by hand when the tables need
refreshing, and commit the diff.

geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)
"""
import pathlib
import numpy as np
import matplotlib
from matplotlib import colormaps

NAMES = ["viridis", "magma", "cividis"]
OUT = pathlib.Path(__file__).resolve().parent.parent / "data" / "cvd_colormaps.txt"

HEADER = """# geoMap v2 - colour-vision-deficiency-safe colormap tables
#
# PROVENANCE, so this file can be regenerated rather than trusted:
#   extracted from matplotlib {ver} by
#   tools/extract_cvd_colormaps.py, 15-Aug-2026, 256 rows each,
#   sampled at linspace(0, 1, 256).
#
# LICENCE. All three are CC0 1.0 public-domain dedications, so there is
# no legal restriction on including them here. Credit is appreciated by
# their authors and is given in LICENSE and in geo.colormaps' help:
#
#   viridis, magma  Stefan van der Walt and Nathaniel Smith (with Eric
#                   Firing for viridis), released CC0 via BIDS/colormap.
#   cividis         Nunez JR, Anderton CR, Renslow RS (2018), PLoS ONE
#                   13(7): e0199239, CC0 via PLOS open access.
#
# WHY THESE THREE AND NOT A HAND-ROLLED SUBSTITUTE. All three are
# designed to stay monotone in perceived lightness AND to remain
# readable under the common forms of colour vision deficiency; cividis
# is optimised for it specifically. That is a measured perceptual
# property this project cannot reproduce by construction, so the honest
# choice is to use the published tables and say where they came from.
#
# Format: one colormap per block, "# name <rows>", then rows of R G B in
# [0, 1]. Plain text so a diff is readable and the numbers auditable.
"""


def main():
    lines = [HEADER.format(ver=matplotlib.__version__)]
    for n in NAMES:
        c = colormaps[n](np.linspace(0, 1, 256))[:, :3]
        lines.append(f"# {n} {c.shape[0]}")
        for row in c:
            lines.append(" %.6f %.6f %.6f" % tuple(row))
    OUT.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUT} ({len(NAMES)} colormaps, 256 rows each)")


if __name__ == "__main__":
    main()
