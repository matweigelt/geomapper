#!/usr/bin/env python3
"""ledger_sync - the handover's STATUS must agree with the records' EVIDENCE.

WHY THIS EXISTS, measured rather than imagined. On 21-Aug-2026 a fresh
session opened `HANDOVER.md` - the file whose own first page says "it is
the only place a status lives" - and read that Stage 0 was in progress and
Stages D, E and F had not started. All three were finished, executed and
merged; `RECORDS.md` carried R-012 through R-025 for them and the change
log carried C-100 through C-169. Debts V4, V7 and V9 were recorded as
discharged in the records and still listed as open debts in Part 0.

The status had migrated into the change log and the evidence file, which
is BEST_PRACTICE 6.1 inverted: the evidence file grew a status and the
status file kept none. Nothing was red. Every gate was green, because
every gate looked at code and no gate looked at the document set. A reader
picking the project up that morning would have concluded that half of it
was unbuilt (finding PV-130).

WHAT IT CHECKS. Four rules, stated as rules and not as a list of names -
PV-128's lesson, that a name-list forbids only the instances somebody
thought of, and the twelfth stage will not be in it:

  1. A stage with a records entry is not "not started".
     Evidence exists; the ledger denies it.
  2. A debt the records call discharged is not left un-annotated in
     Part 0. A discharged debt still printed as open costs the next
     session the work of re-discharging it.
  3. A checkpoint with a records entry is not left unticked in Part 1.2.
  4. A stage marked done cites a records entry. The converse rule: a
     status with no evidence behind it is the failure the first three
     exist to prevent, arriving from the other direction.
  5. A records entry the ledger cites exists. Rules 1-4 all read from
     records to ledger, so none of them can see a citation that points
     at nothing - and revision 3.1's own first draft cited R-026 before
     R-026 was written.

WHAT IT DOES NOT CHECK. Whether the status is TRUE - only whether the two
files agree. Two documents can agree and both be wrong; that is what the
green gate and its counts are for. This check closes the gap where they
disagree and nothing notices, which is the gap that was actually open.

Static, runtime-free, and therefore in the first CI job. It needs no
MATLAB, which is the point: it is a check on the documents, and the
documents drift hardest in exactly the sessions where MATLAB is not
reachable.

Self-tested: run with --selftest, which the main path invokes first. A
check without a fixture proving it fires is not a check.

geoMap v2.0 | 21-Aug-2026 | Claude Opus 5 (Anthropic)
"""
from __future__ import annotations
import pathlib
import re
import sys

# A records heading: "## R-014 - Stage D, checkpoint D.2, 20-Aug-2026, ..."
# The stage letter is captured, and the checkpoint when the entry names
# one. The template entry in RECORDS.md writes "Stage <X>", which this
# deliberately does not match: a template is not evidence.
# THE STAGE ALPHABET WAS [0A-F] AND STAGE G OUTGREW IT (22-Aug-2026).
# R-033 was written, the ledger cited it, and this gate reported the
# citation as pointing at nothing - correctly, from its own point of
# view, and wrongly about the tree. A hardcoded alphabet fails silently
# exactly once per stage, at the moment a new stage opens, which is the
# moment the record matters most. [0A-Z] never needs editing again; a
# bogus letter shows up as a record nobody cites, which the other half
# of this gate already catches.
RE_RECORD = re.compile(
    r"^##\s+R-(\d+)\s*[-\u2013\u2014]+\s*Stage\s+([0A-Z])\b"
    r"(?:[^\n]*?checkpoint\s+([0A-F]\.\d[a-z]?))?",
    re.IGNORECASE | re.MULTILINE)

# "V4 discharged", "**V9 discharged**", "| V9 | discharged at E.1c |".
# Bounded to a short span so a sentence mentioning V7 and, forty words
# later, some unrelated discharge cannot be read as a claim about V7.
RE_DISCHARGED = re.compile(
    r"V(\d+)\**\s*(?:\|\s*)?\**[^.\n|]{0,40}?discharged", re.IGNORECASE)

# Part 1.1 stage row: first cell is the stage, bold or plain.
RE_STAGE_ROW = re.compile(r"^\|\s*\**([0A-F])\**\s*\|(.*)$", re.MULTILINE)

# Part 1.2 checkpoint row: "| B | B.1 | contents | status |".
RE_CKPT_ROW = re.compile(
    r"^\|\s*\**[0A-F]\**\s*\|\s*\**([0A-F]\.\d[a-z]?)\**\s*\|(.*)$",
    re.MULTILINE)

# Part 0 debt row: "| V4 | claim | why | discharged by | severity |".
RE_DEBT_ROW = re.compile(r"^\|\s*\**V(\d+)\**\s*\|(.*)$", re.MULTILINE)

NOT_STARTED = "\u2610 not started"      # checkbox + words
DONE = "\u2611"                          # ticked box
OPEN_BOX = "\u2610"


def section(text: str, start: str, stop: str) -> str:
    """Text between two headings, or "" when the opening heading is absent."""
    i = text.find(start)
    if i < 0:
        return ""
    j = text.find(stop, i + len(start))
    return text[i:j if j > 0 else len(text)]


def check(handover: str, records: str) -> list[str]:
    problems: list[str] = []

    rec_stages, rec_ckpts, rec_of_stage = set(), set(), {}
    for m in RE_RECORD.finditer(records):
        stage = m.group(2).upper()
        rec_stages.add(stage)
        rec_of_stage.setdefault(stage, []).append("R-" + m.group(1))
        if m.group(3):
            rec_ckpts.add(m.group(3).upper())

    discharged = {m.group(1) for m in RE_DISCHARGED.finditer(records)}

    # 1.1 and 1.2 are read separately: a checkpoint row's first cell is
    # also a stage letter, so one span would let "B | B.1" be read as a
    # stage row and reported for citing no records entry.
    stages = section(handover, "### 1.1", "### 1.2")
    ckpts = section(handover, "### 1.2", "### 1.3")
    debts = section(handover, "## Part 0", "## Part 1")

    # Rule 1 and rule 4 read the same rows.
    for m in RE_STAGE_ROW.finditer(stages):
        stage, row = m.group(1).upper(), m.group(2)
        if NOT_STARTED in row and stage in rec_stages:
            problems.append(
                f"Part 1.1: stage {stage} is '{NOT_STARTED}', but RECORDS.md "
                f"carries {', '.join(rec_of_stage[stage])} for it. Evidence "
                f"exists and the ledger denies it.")
        if DONE in row and not re.search(r"R-\d+", row):
            problems.append(
                f"Part 1.1: stage {stage} is marked done but cites no "
                f"records entry. A status with no evidence behind it.")

    # Rule 3.
    for m in RE_CKPT_ROW.finditer(ckpts):
        ckpt, row = m.group(1).upper(), m.group(2)
        if OPEN_BOX in row and ckpt in rec_ckpts:
            problems.append(
                f"Part 1.2: checkpoint {ckpt} is unticked, but RECORDS.md "
                f"carries an entry for it.")

    # Rule 5. Added in the same round that needed it: revision 3.1's own
    # first draft cited R-026 in the ledger before R-026 was written. The
    # four rules above all read from records to ledger, so none of them
    # could see a citation pointing at nothing.
    have = {"R-" + m.group(1) for m in RE_RECORD.finditer(records)}
    for span, where in ((stages, "Part 1.1"), (ckpts, "Part 1.2")):
        for cited in sorted(set(re.findall(r"R-\d+", span))):
            if cited not in have:
                problems.append(
                    f"{where}: cites {cited}, which has no entry in "
                    f"RECORDS.md.")

    # Rule 2.
    for m in RE_DEBT_ROW.finditer(debts):
        num, row = m.group(1), m.group(2)
        if num in discharged and "discharged" not in row.lower():
            problems.append(
                f"Part 0: debt V{num} is listed with no discharge note, but "
                f"RECORDS.md declares it discharged. A discharged debt "
                f"printed as open costs the next session the work twice.")

    return problems


def selftest() -> bool:
    ok = True
    healthy_h = (
        "## Part 0\n"
        "| V1 | claim | why | how | High |\n"
        "| V4 | ~~claim~~ **DISCHARGED 15-Aug** | why | how | - |\n"
        "## Part 1\n### 1.1\n"
        "| **A** | thing | - | A | \u2611 done | 15-Aug | R-006 |\n"
        "| **D** | thing | - | B | \u2610 not started | - | - |\n"
        "### 1.2 Checkpoint ledger\n"
        "| B | B.1 | stuff | \u2611 138 points |\n"
        "### 1.3\n")
    healthy_r = (
        "## R-006 \u2014 Stage A, 15-Aug-2026, tier A\n"
        "**V4 discharged.**\n"
        "## R-002 \u2014 Stage B, checkpoint B.1, 15-Aug-2026, tier A\n")

    cases = [
        ("false positive on an agreeing pair", healthy_h, healthy_r, None),
        ("rule 1 (stage has evidence, ledger says not started)",
         healthy_h,
         healthy_r + "## R-014 \u2014 Stage D, 20-Aug-2026, tier A\n",
         "stage D is"),
        ("rule 2 (debt discharged in records, open in Part 0)",
         healthy_h.replace("~~claim~~ **DISCHARGED 15-Aug**", "claim"),
         healthy_r, "debt V4"),
        ("rule 3 (checkpoint has evidence, ledger unticked)",
         healthy_h.replace("\u2611 138 points", "\u2610"),
         healthy_r, "checkpoint B.1"),
        ("rule 4 (stage done, no records entry cited)",
         healthy_h.replace("15-Aug | R-006", "15-Aug | -"),
         healthy_r, "cites no records entry"),
        ("rule 5 (ledger cites a records entry that does not exist)",
         healthy_h.replace("15-Aug | R-006", "15-Aug | R-099"),
         healthy_r, "R-099"),
    ]
    for name, h, r, expect in cases:
        found = check(h, r)
        if expect is None and found:
            print(f"  SELFTEST FAIL: {name}: {found}")
            ok = False
        if expect is not None and not any(expect in f for f in found):
            print(f"  SELFTEST FAIL: {name}: check did not fire")
            ok = False

    # The template entry in RECORDS.md must not be read as evidence.
    if check(healthy_h, healthy_r + "## R-00n \u2014 Stage <X>, <date>\n"):
        print("  SELFTEST FAIL: the entry template was read as evidence")
        ok = False

    print(f"  self-test: {'PASS' if ok else 'FAIL'}")
    return ok


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    print("ledger_sync \u2014 handover status vs records evidence")
    print("=" * 60)
    if not selftest():
        print("\nSELF-TEST FAILED. No claim from this run may be believed.")
        return 2

    h, r = root / "HANDOVER.md", root / "RECORDS.md"
    if not (h.exists() and r.exists()):
        print(f"\n  ! HANDOVER.md or RECORDS.md missing under {root}")
        return 1

    problems = check(h.read_text(encoding="utf-8"),
                     r.read_text(encoding="utf-8"))
    print(f"\n  disagreements : {len(problems)}")
    for p in problems:
        print(f"    ! {p}")
    if problems:
        print("\n  The two files disagree. Neither is presumed right; the")
        print("  green gate and its counts decide, and then BOTH are moved.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
