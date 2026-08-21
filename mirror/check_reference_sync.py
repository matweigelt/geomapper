#!/usr/bin/env python3
"""check_reference_sync — the committed reference must be what the mirror computes.

WHY THIS EXISTS. Audit finding A-2. The MATLAB `reference` tier asserts
against geomap_mirror/out/reference_values.json, a CHECKED-IN artefact.
CI regenerates that file in a separate job, on a fresh checkout, and
uploads it as an artefact; the MATLAB job reads the committed copy. The
two never met, and check_acceptance.py validates the fresh file, never
the committed one.

So the independence of oracles O1 and O4 was real when it was
established and has since been frozen into a file, with nothing checking
the file is still what the oracle says. Measured, in a fully green tree
(PV-132): GDAL 3.10.3 -> 3.12.4 and the regrid mass-closure floor
2.150e-14 -> 3.9363e-14, both legs green because neither was looking.

HOW IT RUNS. After `python -m geomap_mirror.references`, which OVERWRITES
the working-tree copy. This compares that against the committed blob via
`git show`. No second mirror run, so it costs nothing.

THE DEFAULT IS EXACT. Measured across two environments and two GDAL
versions, 40 of 48 values are bit-identical. Anything else is a claim
that needs a reason, and the reasons live in DRIFT.md - a register, not
a tolerance, because one global tolerance would have to be as loose as
the loosest row and would then wave through a projection value that had
moved by a factor of two.

Self-tested: run with --selftest, which the main path invokes first. A
check without a fixture proving it fires is not a check.

geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)
"""
from __future__ import annotations
import json
import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
REF = HERE / "geomap_mirror" / "out" / "reference_values.json"
RELPATH = "mirror/geomap_mirror/out/reference_values.json"

# Each row of DRIFT.md, as the check reads it. The prose there is the
# authority a human reads; this is the same rule a script can run, and
# the two are checked against each other by rowsAgreeWithRegister.
#
#   pattern      matched against the slash path of the leaf
#   kind         "provenance" reported and never asserted
#                "bound"      absolute ceiling, whatever it moved from
#                "relative"   relative change ceiling
REGISTER = [
    # Anchored on a path SEGMENT, not on the start of the path: the
    # real leaves live under /values/..., and the first draft's ^/ made
    # every rule dead while the self-test fixtures happened to look the
    # same shape. The self-test caught it before CI did, which is what
    # it is for.
    (re.compile(r"/version$"), "provenance", None),
    (re.compile(r"(^|/)oracle_gdal"), "provenance", None),
    (re.compile(r"(^|/)regrid_mass_closure_floor(/|$)"), "bound", 1e-13),
    (re.compile(r"(^|/)equal_area_integral(/|$)"), "relative", 1e-9),
]


def leaves(x, path=""):
    """Every scalar or string in a nested structure, with its path."""
    if isinstance(x, dict):
        for k in x:
            yield from leaves(x[k], f"{path}/{k}")
    elif isinstance(x, list):
        for i, v in enumerate(x):
            yield from leaves(v, f"{path}[{i}]")
    else:
        yield path, x


def classify(path):
    for pat, kind, bound in REGISTER:
        if pat.search(path):
            return kind, bound
    return None, None


def compare(committed: dict, fresh: dict):
    """Problems, and the registered movements, as two lists."""
    problems, moved = [], []
    a = dict(leaves(committed))
    b = dict(leaves(fresh))

    for p in sorted(set(a) | set(b)):
        if p not in a:
            problems.append(f"{p}: present in the fresh run, absent from the "
                            f"committed file - the mirror grew a value that "
                            f"was never committed")
            continue
        if p not in b:
            problems.append(f"{p}: committed but the fresh run does not "
                            f"produce it - the file is stale, or a "
                            f"measurement was withdrawn")
            continue
        x, y = a[p], b[p]
        if x == y:
            continue
        kind, bound = classify(p)
        if kind is None:
            problems.append(f"{p}: {x!r} committed, {y!r} measured, and no "
                            f"row in DRIFT.md permits it to move")
        elif kind == "provenance":
            moved.append(f"{p}: {x!r} -> {y!r}  (provenance)")
        elif kind == "bound":
            if not isinstance(y, (int, float)) or abs(y) > bound:
                problems.append(f"{p}: measured {y!r}, above its registered "
                                f"bound {bound:g}")
            else:
                moved.append(f"{p}: {x!r} -> {y!r}  (bound {bound:g})")
        elif kind == "relative":
            rel = abs(y - x) / max(abs(x), 1e-300)
            if rel > bound:
                problems.append(f"{p}: moved {rel:.3e} relative, above its "
                                f"registered bound {bound:g}")
            else:
                moved.append(f"{p}: {x!r} -> {y!r}  (rel {rel:.2e})")
    return problems, moved


def rowsAgreeWithRegister(text: str) -> list[str]:
    """DRIFT.md must describe the rows this file enforces, and no others.

    One authority per fact means the prose and the code cannot drift
    apart either. Counted rather than parsed word for word: the register
    has four rules and the table must have four rows.
    """
    rows = [l for l in text.splitlines()
            if l.startswith("|") and "|" in l[1:]
            and not l.startswith("| key pattern")
            and not re.match(r"^\|\s*-+", l)]
    if len(rows) != len(REGISTER):
        return [f"DRIFT.md lists {len(rows)} rows, the check enforces "
                f"{len(REGISTER)}. One authority per fact."]
    return []


def selftest() -> bool:
    ok = True
    base = {"values": {"a": 1.0, "equal_area_integral": {"t": 2.0},
                       "regrid_mass_closure_floor": {"measured": 2e-14},
                       "g": {"version": "3.10.3"}}}

    def clone(**kw):
        import copy
        d = copy.deepcopy(base)
        for k, v in kw.items():
            path = k.split(".")
            t = d["values"]
            for p in path[:-1]:
                t = t[p]
            t[path[-1]] = v
        return d

    cases = [
        ("identical", base, None),
        ("unregistered value moved", clone(a=1.5), "no row in DRIFT.md"),
        ("provenance moved", clone(**{"g.version": "3.12.4"}), None),
        ("floor moved but under bound",
         clone(**{"regrid_mass_closure_floor.measured": 3.9e-14}), None),
        ("floor above bound",
         clone(**{"regrid_mass_closure_floor.measured": 2e-13}),
         "above its registered bound"),
        ("integral within relative bound",
         clone(**{"equal_area_integral.t": 2.0 + 2e-10}), None),
        ("integral beyond relative bound",
         clone(**{"equal_area_integral.t": 2.2}), "above its registered"),
    ]
    for name, fresh, expect in cases:
        problems, _ = compare(base, fresh)
        if expect is None and problems:
            print(f"  SELFTEST FAIL: {name}: {problems}")
            ok = False
        if expect is not None and not any(expect in p for p in problems):
            print(f"  SELFTEST FAIL: {name}: check did not fire")
            ok = False

    grew = {"values": dict(base["values"], b=1.0)}
    if not any("never committed" in p for p in compare(base, grew)[0]):
        print("  SELFTEST FAIL: a new value was not reported")
        ok = False
    if not any("stale" in p for p in compare(grew, base)[0]):
        print("  SELFTEST FAIL: a withdrawn value was not reported")
        ok = False

    print(f"  self-test: {'PASS' if ok else 'FAIL'}")
    return ok


def main() -> int:
    print("check_reference_sync — committed reference vs the mirror")
    print("=" * 60)
    if not selftest():
        print("\nSELF-TEST FAILED. No claim from this run may be believed.")
        return 2

    if not REF.exists():
        print(f"\n  ! {RELPATH} is absent. Run the mirror first.")
        return 1
    try:
        raw = subprocess.run(["git", "show", f"HEAD:{RELPATH}"],
                             capture_output=True, text=True, check=True,
                             cwd=HERE.parent).stdout
    except (subprocess.CalledProcessError, FileNotFoundError) as err:
        print(f"\n  ! cannot read the committed copy ({err}). This check "
              f"needs a git working tree.")
        return 1

    problems, moved = compare(json.loads(raw), json.loads(REF.read_text()))
    problems += rowsAgreeWithRegister((HERE / "DRIFT.md").read_text())

    if moved:
        print(f"\n  registered movement ({len(moved)}), reported not asserted:")
        for m in moved:
            print(f"    - {m}")

    print(f"\n  unregistered differences : {len(problems)}")
    for p in problems:
        print(f"    ! {p}")
    if problems:
        print("\n  The committed reference is not what the mirror computes.")
        print("  Either commit the regenerated file, or add the row in")
        print("  DRIFT.md that says why the value is allowed to move.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
