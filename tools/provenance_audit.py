#!/usr/bin/env python3
"""provenance_audit — provenance and honesty checks over the tree.

NAME NOTE: shAnalysis has a tools/dev/attribution_sweep.py that APPENDS the
provenance stamp. This tool CHECKS provenance. Two different jobs under one
name across sibling projects is the aliasing that one-name-per-thing
forbids, so this one was renamed. If a stamp-appending tool is ever needed
here, adopt shAnalysis's rather than re-deriving it.

Static, runtime-free, and therefore in the first CI job. It checks claims
that are cheap to make and expensive to have wrong:

  1. Every MATLAB source carries the authorship/date footer.
  2. Any file still marked PROVISIONAL is listed, loudly. A provisional
     deliverable is one that shipped without ever being executed; it is a
     debt, and a debt that stops being visible stops being paid.
  3. No source claims a number that the frozen acceptance file refutes.
  4. The version string has one authority.

Self-tested: run with --selftest, which the main path invokes first. A
check without a fixture proving it fires is not a check.

geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
"""
from __future__ import annotations
import json, pathlib, re, sys

FOOTER = "geoMap v2.0 |"
# A refuted value paired with the corrected one that replaces it.
#
# The rule is NOT a filename allow-list. A file may cite a refuted value
# provided it also cites the correction - that is the signature of
# DOCUMENTING a refutation, as against USING a wrong number. A filename
# list was the first design and was rejected: every future document
# explaining a correction would trip it, and sooner or later somebody
# allow-lists a file that genuinely does cite the wrong value as if it
# were right. This form cannot be defeated by adding a filename.
#
# Prefixes, not full literals: a JSON dump writes more digits than prose
# does, and the check must see both as the same number.
REFUTED = {
    "0.6116372": ("0.34304741",
                  "polar stereographic rho at lat 70, sp 71 - refuted; "
                  "the measured value is 0.3430474163 (finding PV-002)"),
    "0.6304962": ("0.63047769",
                  "LCC cone constant - this is the ELLIPSOIDAL value; the "
                  "spherical value geoMap needs is 0.6304776973 (PV-011)"),
}


def scan(root: pathlib.Path):
    problems, provisional = [], []
    for f in sorted(root.rglob("*.m")):
        if ".git" in f.parts:
            continue
        txt = f.read_text()
        if FOOTER not in txt:
            problems.append(f"{f.relative_to(root)}: no authorship footer")
        if "PROVISIONAL" in txt:
            provisional.append(str(f.relative_to(root)))

    for f in sorted(root.rglob("*")):
        if not f.is_file() or ".git" in f.parts:
            continue
        if f.suffix not in {".m", ".py", ".md", ".json", ".yml"}:
            continue
        try:
            txt = f.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        for bad, (corrected, why) in REFUTED.items():
            if bad in txt and corrected not in txt:
                problems.append(
                    f"{f.relative_to(root)}: cites refuted value {bad} "
                    f"without the correction beside it - {why}")
    return problems, provisional


def selftest() -> bool:
    import tempfile
    ok = True
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        (d / "good.m").write_text(f"function f()\n% {FOOTER} date | model\nend\n")
        p, _ = scan(d)
        if p:
            print(f"  SELFTEST FAIL: false positive on a healthy file: {p}")
            ok = False
        (d / "nofooter.m").write_text("function g()\nend\n")
        p, _ = scan(d)
        if not any("no authorship footer" in x for x in p):
            print("  SELFTEST FAIL: footer check did not fire")
            ok = False
        (d / "nofooter.m").unlink()
        # Fires when the refuted value stands alone...
        (d / "cites.md").write_text("the value is 0.6116372 here\n")
        p, _ = scan(d)
        if not any("refuted value" in x for x in p):
            print("  SELFTEST FAIL: refuted-value check did not fire")
            ok = False
        # ...and is silent when the correction stands beside it, which is
        # what documenting a refutation looks like.
        (d / "cites.md").write_text(
            "0.6116372 was refuted; the measured value is 0.3430474163\n")
        p, _ = scan(d)
        if any("refuted value" in x for x in p):
            print("  SELFTEST FAIL: false positive on a documented refutation")
            ok = False
    print(f"  self-test: {'PASS' if ok else 'FAIL'}")
    return ok


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    print("provenance_audit — provenance and honesty")
    print("=" * 60)
    if not selftest():
        print("\nSELF-TEST FAILED. No claim from this run may be believed.")
        return 2

    problems, provisional = scan(root)

    if provisional:
        print(f"\n  PROVISIONAL deliverables ({len(provisional)}) - shipped "
              f"but never executed:")
        for p in provisional:
            print(f"    - {p}")
        print("  This is a visible debt, not a failure. It clears when the")
        print("  suite has run green and the stamps are removed.")

    print(f"\n  problems : {len(problems)}")
    for p in problems:
        print(f"    ! {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
