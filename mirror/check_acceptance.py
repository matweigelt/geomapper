#!/usr/bin/env python3
"""check_acceptance — compare a mirror run against the frozen criteria.

The frozen numerical criterion is what makes this pipeline a scientific
instrument rather than a formality: it can reject a wrong algorithm before
any human reads the diff.

Two rules this script exists to enforce:

  1. FIXTURE PRESENCE IS ASSERTED, NEVER ASSUMED. A missing reference file
     fails loudly here. The silent-assume form is how a mistyped fixture
     name filtered a chain test out for seven minor versions in a
     reference project, indistinguishable from passing.

  2. A TOLERANCE IS NEVER WIDENED TO MAKE A RUN PASS. If a value drifts,
     decompose the residual first. A criterion loosened until green is an
     instrument destroyed in place.

Exit codes: 0 all criteria met; 1 one or more breaches; 2 the run itself
could not be read (missing or malformed fixture).

geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
"""
from __future__ import annotations
import json, pathlib, sys

HERE = pathlib.Path(__file__).parent
REF = HERE / "geomap_mirror" / "out" / "reference_values.json"
ACC = HERE / "acceptance.json"


def die(code, msg):
    print(f"\nFAILED: {msg}")
    sys.exit(code)


def main():
    print("check_acceptance — frozen criteria vs this run")
    print("=" * 68)

    # --- 1. Fixture presence, asserted ---------------------------------
    for p, what in ((REF, "mirror output"), (ACC, "frozen criteria")):
        if not p.exists():
            die(2, f"{what} not found at {p}. This is not a skip condition: "
                   f"a run that cannot find its fixture must fail loudly, "
                   f"never pass quietly.")
    ref = json.loads(REF.read_text())
    acc = json.loads(ACC.read_text())
    vals = ref["values"]

    breaches, checked = [], 0

    # --- 2. Count reconciliation ---------------------------------------
    expected_n = acc["expected_value_count"]
    actual_n = len(vals)
    print(f"\n[count] recorded {actual_n}, expected {expected_n}")
    if actual_n != expected_n:
        breaches.append(
            f"value count {actual_n} != expected {expected_n}. A count that "
            f"moves without a stated reason means a measurement was added "
            f"or lost; reconcile before reading anything else.")

    # --- 3. The mirror's own findings ----------------------------------
    # references.py compares against the HANDOVER's quoted values, four of
    # which are known-wrong and deliberately not fixed in that file - the
    # findings are the record. So findings are reported, not failed on.
    print(f"\n[mirror findings vs handover] {len(ref['findings'])} "
          f"(known and recorded in RECORDS.md R-002; not a gate)")
    for f in ref["findings"]:
        print(f"    - {f['label']}: quoted {f['quoted']}, "
              f"measured {f['measured']:.10g}")

    # --- 4. Point values ------------------------------------------------
    print("\n[point values]")
    for key, spec in acc["point_values"].items():
        if key not in vals:
            breaches.append(f"{key}: absent from this run")
            continue
        got = vals[key]["measured"]
        err = abs(got - spec["expected"])
        ok = err <= spec["tol"]
        checked += 1
        print(f"  {'ok ' if ok else 'BAD'} {key:34s} {got:>18.12g} "
              f"(err {err:.2e} / tol {spec['tol']:.0e})")
        if not ok:
            breaches.append(
                f"{key}: {got:.12g} vs frozen {spec['expected']:.12g}, "
                f"err {err:.3e} > tol {spec['tol']:.0e}. Source: {spec['source']}")

    # --- 5. Analytic invariants ----------------------------------------
    print("\n[analytic invariants, upper bounds]")
    sf = vals.get("scale_factors", {})
    for key, bound in acc["invariants_max"].items():
        if key.startswith("_"):
            continue
        if key not in sf:
            breaches.append(f"invariant {key}: absent from this run")
            continue
        got = sf[key]
        ok = got <= bound
        checked += 1
        print(f"  {'ok ' if ok else 'BAD'} {key:34s} {got:.3e} "
              f"(bound {bound:.0e})")
        if not ok:
            breaches.append(f"invariant {key}: {got:.3e} > {bound:.0e}")

    # --- 6. Equal-area integral ----------------------------------------
    print("\n[equal-area integral, relative error vs 4*pi]")
    ea = vals.get("equal_area_integral", {})
    for key, bound in acc["equal_area_max_relative_error"].items():
        if key.startswith("_"):
            continue
        if key not in ea:
            breaches.append(f"equal-area {key}: absent from this run")
            continue
        got = ea[key]["rel_error_vs_4pi"]
        ok = got <= bound
        checked += 1
        print(f"  {'ok ' if ok else 'BAD'} {key:34s} {got:.3e} "
              f"(bound {bound:.0e})")
        if not ok:
            breaches.append(f"equal-area {key}: {got:.3e} > {bound:.0e}")

    # --- 7. Round trips and oracle agreement, all 16 --------------------
    print("\n[round trips and oracle agreement, per projection]")
    rt = vals.get("round_trips", {})
    pj = acc["proj_max_abs_diff"]
    for key, bound in acc["round_trip_max_deg_error"].items():
        if key.startswith("_"):
            continue
        if key not in rt:
            breaches.append(f"round trip {key}: absent from this run")
            continue
        e = rt[key]
        got = e["max_deg_error"]
        ok = got <= bound
        checked += 1
        pbound = pj.get(key, pj["default"])
        pgot = e.get("proj_max_abs_diff")
        pok = True if pgot is None else pgot <= pbound
        if pgot is not None:
            checked += 1
        print(f"  {'ok ' if ok and pok else 'BAD'} {key:22s} "
              f"rt {got:.2e} (<= {bound:.0e})   "
              f"proj {'n/a' if pgot is None else format(pgot, '.2e')} "
              f"(<= {pbound:.0e})")
        if not ok:
            breaches.append(f"round trip {key}: {got:.3e} > {bound:.0e}")
        if not pok:
            breaches.append(
                f"oracle agreement {key}: {pgot:.3e} > {pbound:.0e}")

    # --- 8. Pinned defect regressions -----------------------------------
    print("\n[pinned v1 defect regressions]")
    for key, spec in acc.get("regressions", {}).items():
        if key.startswith("_"):
            continue
        if key not in vals:
            breaches.append(f"regression {key}: absent from this run")
            continue
        got = bool(vals[key].get(spec["must_be_true"], False))
        checked += 1
        print(f"  {'ok ' if got else 'BAD'} {key:34s} {got}")
        if not got:
            breaches.append(f"regression {key} REINSTATED. {spec['meaning']}")

    # --- 9. Verdict -----------------------------------------------------
    print("\n" + "=" * 68)
    print(f"  criteria checked : {checked}")
    print(f"  breaches         : {len(breaches)}")
    if breaches:
        print("\n  A breach is a FINDING, not a threshold to adjust.")
        print("  Diagnose in this order: configuration, criterion, code.\n")
        for b in breaches:
            print(f"    ! {b}")
        return 1
    print("\n  All frozen criteria met.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
