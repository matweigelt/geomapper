#!/usr/bin/env python3
"""oracle_sync - the oracle register against the tree that cites it.

WHY THIS EXISTS.  HANDOVER Part 3 is the register of what this project
checks itself against.  Every other gate in the tree reads code
(``mcheck``), provenance (``provenance_audit``) or the stage ledger
(``ledger_sync``).  **None of them reads Part 3**, and on 22-Aug-2026 four
of its twelve rows were wrong across a released version:

  * **O2** read open while ``mirror/acceptance.json`` cited it as the
    source of two frozen acceptance criteria.
  * **O7** named ``gdalwarp -r average`` as certifying conservative mass
    closure.  It cannot: it takes an unweighted mean of the source centres
    in a target cell, and on a geographic grid cell area goes as cos(phi).
  * **O8** read open while a whole mirror module existed to fill it and CI
    proved its route on every push.
  * **O12** read open while the v1 probes had run twice.

A register nobody checks is worse than no register, because an empty row
is read as a known gap rather than as a lie.  This is debt V12.

WHAT IT CHECKS, and why each rule is refutable rather than decorative:

  1. The Part 3 table parses at all, and every row has an id and a status.
  2. Status is exactly one of the two permitted marks.  A row with prose
     where its status should be is a row nobody can act on.
  3. A CONFIRMED row carries a date.  "Confirmed" with no date cannot be
     re-derived, and BEST_PRACTICE requires a measurement to carry when it
     was taken.
  4. Every oracle id cited anywhere in the tree EXISTS in the register.
     Catches a citation surviving a row's removal or rename.
  5. **An OPEN row that the tree cites must say why the citation is not
     consumption.**  This is the rule that would have caught all four
     defects above, and it is deliberately answered AT THE ROW rather than
     in an allow-list here: an allow-list is a second authority, and it
     rots exactly like the register it would be guarding.  A row may
     discharge the finding by containing the marker CITED-NOT-CONSUMED
     together with its reason.

WHAT IT CANNOT DO, stated so its silence is not over-read: it cannot tell
whether an oracle was configured correctly, whether the comparison it
certifies is the one the row claims, or whether a CONFIRMED row's date is
true.  It reads text.  Only a run reads behaviour.

geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

CONFIRMED = "\u2611"      # ballot box with check
OPEN = "\u2610"           # ballot box
DATE = re.compile(r"\b\d{1,2}-[A-Z][a-z]{2}-\d{4}\b")
ROW = re.compile(r"^\|\s*\*\*(O\d{1,2})\*\*\s*\|(.*)\|\s*$")
# The same pattern for whole-text substitution. WITHOUT re.M the anchors
# bind to the start and end of the ENTIRE string, so ROW.sub() over a
# document removes nothing and silently returns it unchanged. That is not
# hypothetical: the self-test below used ROW.sub() to plant its third
# defect, planted nothing, and PASSED ANYWAY for two runs because the
# register was dirty and check() was returning real findings. The
# injection was vacuous and the dirt was hiding it. It surfaced the moment
# the register came clean - which is the argument for running a self-test
# against a HEALTHY tree as well as a broken one.
ROW_MULTILINE = re.compile(ROW.pattern, re.M)
CITE = re.compile(r"\bO(\d{1,2})\b")
EXEMPT_MARK = "CITED-NOT-CONSUMED"

# Where a citation counts. Deliberately narrow: prose in the handover and
# the records file cites oracles constantly and is not consumption.
SEARCH = ["tests", "mirror", "+geo", "tools", "docbuild"]
SUFFIX = {".m", ".py", ".json"}


def part3(text: str) -> str:
    """Part 3 alone.

    SCOPING THIS WAS A FINDING ON THE GATE'S OWN FIRST RUN. Part 10.2
    discusses the same oracle ids in a table of the same shape, and an
    unscoped parser read those discussion rows as register rows - so O7
    was reported both statusless and open, which is not a state any row
    can be in. A gate whose own output is self-contradictory is telling
    you about itself, not about the tree.
    """
    start = text.find("## Part 3")
    if start < 0:
        return ""
    end = text.find("\n## Part ", start + 1)
    return text[start:end if end > 0 else len(text)]


def parse_register(text: str):
    """Rows of the Part 3 table, in file order."""
    rows = []
    for n, line in enumerate(part3(text).splitlines(), 1):
        m = ROW.match(line)
        if m:
            rows.append({"id": m.group(1), "line": n, "body": m.group(2)})
    return rows


def citations(root: Path):
    """id -> sorted list of files citing it, excluding the register itself."""
    found: dict[str, set[str]] = {}
    for folder in SEARCH:
        base = root / folder
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix not in SUFFIX:
                continue
            if path.name == "oracle_sync.py":
                # This file names the ids it was written for. Counting its
                # own prose as consumption would make every row it
                # documents look consumed - an instrument reporting on
                # itself rather than on the tree.
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for m in CITE.finditer(text):
                found.setdefault("O" + m.group(1), set()).add(
                    str(path.relative_to(root)).replace("\\", "/"))
    return {k: sorted(v) for k, v in found.items()}


def check(root: Path, handover_text: str | None = None,
          cited_override: dict[str, list[str]] | None = None):
    """Findings as a list of strings. Empty means the register agrees.

    CITED_OVERRIDE exists so the self-test can run on an INLINE FIXTURE
    rather than on the real tree, which is the whole repair described in
    SELF_TEST below.
    """
    findings: list[str] = []
    hv = root / "HANDOVER.md"
    text = handover_text if handover_text is not None else hv.read_text(
        encoding="utf-8", errors="replace")

    rows = parse_register(text)
    if not rows:
        return ["HANDOVER.md: the Part 3 oracle register did not parse. "
                "Either it is gone or its row format changed; both are "
                "findings, because this gate then checks nothing."]

    known = {r["id"] for r in rows}
    cited = citations(root) if cited_override is None else cited_override

    for r in rows:
        body, rid = r["body"], r["id"]
        nc = body.count(CONFIRMED)
        no = body.count(OPEN)
        if nc + no == 0:
            findings.append(
                f"{rid}: no status mark. A row nobody can act on.")
            continue
        if nc and no:
            findings.append(
                f"{rid}: carries both marks. A status is one value.")
            continue
        if nc and not DATE.search(body):
            findings.append(
                f"{rid}: confirmed with no date. A measurement that does "
                f"not say when it was taken cannot be re-derived.")
        if no and rid in cited and EXEMPT_MARK not in body:
            findings.append(
                f"{rid}: marked OPEN but cited in {', '.join(cited[rid])}. "
                f"Either the row is stale, or the citation is not "
                f"consumption - say which IN THE ROW, with the marker "
                f"{EXEMPT_MARK} and a reason.")

    for rid, files in cited.items():
        if rid not in known:
            findings.append(
                f"{rid}: cited in {', '.join(files)} but absent from the "
                f"register. A citation outliving its row points at nothing.")
    return findings


def self_test(root: Path) -> bool:
    """Fault injection on an INLINE FIXTURE, never on the real tree.

    THIS IS THE SECOND VERSION, AND THE FIRST ONE'S FAILURE IS THE REASON
    FOR THIS ONE. The first self-test mutated the REAL HANDOVER.md and
    asserted that check() then reported something. That is unfalsifiable
    whenever the tree is already dirty: check() returns findings about
    the tree's own faults no matter whether the mutation applied. One of
    the three mutations did not apply - a re.sub without re.M, whose
    anchors bound to the whole string - and the case passed anyway for
    two runs. It surfaced only when the register came clean and the
    findings stopped.

    The three older gates in this folder do not have this hole, and the
    reason is worth copying rather than restating: mcheck,
    provenance_audit and ledger_sync all build a SMALL FIXTURE and mutate
    that, with a healthy case asserted to be silent. A no-op mutation on
    a fixture yields no findings, so the case fails loudly. The fixture
    is not a convenience - it is what makes the injection falsifiable.

    A guard asserting "the mutation changed the text" was considered and
    rejected as the primary repair: it patches this instance and leaves
    the structure that produced it, and a guard is not a fix. It is kept
    as a second, cheap assertion because it names the exact defect.
    """
    ok = True
    healthy = (
        "## Part 3 - Oracle register\n"
        "| id | Oracle | Type | Certifies | Consumed by | Status |\n"
        "| **O1** | thing | analytic | a claim | Stage A | "
        + CONFIRMED + " 15-Aug-2026 |\n"
        "| **O2** | thing | toolkit | a claim | Stage B | " + OPEN + " |\n"
        "## Part 4 - next\n")
    cited_none: dict[str, list[str]] = {}
    cited_o2 = {"O2": ["tests/TestX.m"]}

    cases = [
        ("false positive on an agreeing register", healthy, cited_none, None),
        ("confirmed row with no date",
         healthy.replace(" 15-Aug-2026", ""), cited_none, "no date"),
        ("open row that the tree cites",
         healthy, cited_o2, "marked OPEN but cited"),
        ("citation with no row",
         healthy, {"O9": ["mirror/x.py"]}, "absent from the register"),
        ("a row carrying both marks",
         healthy.replace("| " + OPEN + " |", "| " + OPEN + CONFIRMED + " |"),
         cited_none, "both marks"),
        ("the register removed",
         ROW_MULTILINE.sub("", healthy), cited_none, "did not parse"),
    ]
    for name, text, cited, expect in cases:
        if expect is not None and text == healthy and cited is cited_none:
            print(f"  self-test: FAIL - the injection for '{name}' changed "
                  f"nothing, so the case proves nothing")
            return False
        found = check(root, text, cited)
        if expect is None and found:
            print(f"  self-test: FAIL - fires on a healthy register: {found}")
            return False
        if expect is not None and not any(expect in f for f in found):
            print(f"  self-test: FAIL - silent on '{name}'")
            return False

    # An exempted citation must be forgiven, or the marker is decorative.
    exempt = healthy.replace("| " + OPEN + " |",
                             "| " + OPEN + " " + EXEMPT_MARK + ": reason |")
    if check(root, exempt, cited_o2):
        print("  self-test: FAIL - the exemption marker was not honoured")
        return False

    print(f"  self-test: PASS ({len(cases) - 1} planted defects on an "
          f"inline fixture, each caught; healthy case silent)")
    return ok


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    print("oracle_sync - the register against the tree that cites it")
    print("=" * 60)
    if not self_test(root):
        return 2
    findings = check(root)
    print()
    print(f"  disagreements : {len(findings)}")
    for f in findings:
        print(f"    ! {f}")
    if findings:
        print()
        print("  An empty row is read as a known gap. A row that is wrong")
        print("  is read the same way and is not one, which is why this")
        print("  gate exists (debt V12).")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
