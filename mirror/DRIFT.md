# Reference drift register

**Every value that may differ between one environment and another, with the
bound it must stay inside and the condition that closes the row.**

Audit finding **A-2**: the `reference` tier asserts against
`geomap_mirror/out/reference_values.json` — a **checked-in artefact** — while
CI regenerates that file in a separate job, on a fresh checkout, and uploads
it as an artefact. The two never met. The independence of oracles O1 and O4
was real when it was established and has since been **frozen into a file**,
and the freshness of that file was unchecked.

It is not hypothetical. Re-running the mirror in a second environment moved
values in a fully green tree (PV-132): GDAL 3.10.3 → 3.12.4, and the regrid
mass-closure floor 2.150e-14 → 3.936e-14. Both legs stayed green because
neither was looking.

`check_reference_sync.py` closes that. It compares the file the mirror has
just written against the one in the repository, and **an unregistered
difference is red**. The default is exact: measured across two environments
and two GDAL versions, **40 of 48 values are bit-identical**, so anything else
is a claim that needs a reason.

## Why a register and not a tolerance

A single global tolerance would have to be as loose as the loosest value here
— 8.3e-1 for the mass-closure floor — and would then wave through a
projection value that had moved by a factor of two. The rows below say which
value may move, why the arithmetic permits it, and what the bound is a
statement *about*.

## What may move

| key pattern | why it moves | bound | closes when |
|---|---|---|---|
| `*/version` | The GDAL version stamped beside each measurement that used it. Provenance, not a measurement. | reported, never asserted | never — it is provenance |
| `*/route` | Which GDAL entry point served the measurement: `cli` where the runner has root and installs `gdal-bin`, `ctypes` where a sandbox reaches the libgdal bundled in the rasterio wheel. **Both routes are deliberate** — `requirements.txt` says so — and which one ran is recorded with every number precisely so the two can be compared rather than assumed equivalent. | reported, never asserted | never — it is provenance |
| `oracle_gdal`, `oracle_gdal_self_test` | The route's own provenance block and its self-test on an analytically known plane. A version change is **information, recorded with every number**; treating it as a failure would make every runner image bump a red gate. | reported, never asserted | never — it is provenance |
| `regrid_mass_closure_floor/*` | The achievable floor of an area-weighted remap is a summation-order question, and the order is the numpy build's, not the algorithm's. Measured 2.150e-14 and 3.936e-14 in two environments. | **≤ 1e-13**, the `TolMass` it feeds. The bound is the tolerance the toolbox actually asserts, not the value last seen — a floor that stays a decade under its tolerance is doing its job however it moves. | never — but a floor that ever **exceeds** `TolMass` is a finding, not a re-derivation (§4.6) |
| `round_trips/*` | A **maximum over 10 000 sampled residuals**, so it is a noise statistic and not a constant: the largest of ten thousand last-bit errors moves with the libm underneath it. Measured across two hosts: polar stereographic 8.88e-16 → 6.66e-16, transverse Mercator 5.97e-13 → 4.26e-13. | **≤ 1e-8**, the loosest frozen round-trip criterion (`acceptance.json`, Lambert azimuthal). Deliberately generous here, because **`check_acceptance.py` already asserts each projection against its own bound** — this row answers "may it move", that file answers "is it small enough", and duplicating the second would give one fact two authorities. | never |
| `equal_area_integral/*` | A quadrature sum over 10⁶ samples, so the last bits follow the numpy/scipy build. Measured drift 5.6e-12 and 1.4e-16 relative. | **1e-9 relative** — three orders above the observed drift, three below the 1e-6 the suite asserts these against, so it can move freely without ever reaching the claim it supports. | never |

## What may not

Everything else, exactly. The projection kernels, the published point values,
the round trips, the domain limits, the scale factors and the wrap
formulation are arithmetic on a sphere; they do not depend on which machine
evaluates them, and a difference in any of them means either the mirror
changed or the oracle did.

Adding a row is a decision. If a value has started to drift, the first
question is whether the drift is a property of the arithmetic or a defect
that has just become visible — and the second is whether the tolerance the
suite asserts it against is still honest.

---

*geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)*
