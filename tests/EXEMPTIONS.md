# Test-category exemptions

An exemption is a claim that the test is **impossible**, not that it is
inconvenient. One row per function per category, each with a reason. The
runner reads this file and reports any uncovered category not listed here
as a gap.

Mechanically enforced: **`contract` may not be exempted for any function
that validates its arguments.** Argument validation runs before the body,
so a rejected call is refutable in microseconds however expensive a
successful one is. Two exemptions in a reference project reasoned from an
expensive *success* to an impossible test and were wrong when written.

Re-read at every stage boundary (obligation OB-5). An exemption that has
become false is a finding.

| Function | Category | Reason |
|---|---|---|
| GeoMapTestCase | vectorisation | A test-harness class has no batched form. |
| GeoMapTestCase | metamorphic | No invariance to state; its observable is a qualified assertion. |
| geoMapTestRecord | vectorisation | Accumulator with a scalar interface. |
| geoMapTestRecord | metamorphic | Order of records is meaningful, so no permutation invariance exists. |
| geoMapTestRecord | speed | Its cost is a cell append; a budget would measure the timer. |
| geoMapTestRecord | reference | No external authority certifies an in-process store. |
| geoMapTestRecord | precision | No numerical claim. |
| verifyManifest | vectorisation | Operates on one tree. |
| verifyManifest | metamorphic | File order in the manifest is fixed by the generator. |
| verifyManifest | speed | I/O bound on a fixture of a few files; a ratio would measure the filesystem cache. |
| verifyManifest | precision | No numerical claim; the hash comparison is exact by construction. |
| sha256OfText | metamorphic | A hash has no invariance worth asserting beyond determinism, covered under contract. |
| sha256OfText | speed | Not on any hot path. |
| sha256OfText | precision | Exact by construction. |
| sha256OfText | vectorisation | Single char-vector interface. |
| geoMapAudit | precision | No numerical claim; its criterion is behavioural and is asserted under contract and reference. |
| geoMapAudit | vectorisation | Operates on one tree. There is no batched form to compare against. |
| geoMapAudit | speed | Its cost is dominated by file I/O and by MATLAB's Code Analyzer, neither of which this project owns; a ratio would measure the filesystem cache and the analyser's version. |
| geoMapAuditFixtures | precision | Writes text. No numerical claim exists to bound. |
| geoMapAuditFixtures | vectorisation | Builds one tree per call by construction; a batched form would defeat the one-defect-per-fixture rule. |
| geoMapAuditFixtures | speed | Not on any hot path; it runs once per audit invocation. |
| geoMapAuditFixtures | metamorphic | Its observable is a directory of files with one planted defect. No invariance applies. |
| v1_defect_probes | precision | Its numbers come from v1, which is the subject, not a claim of this project. The tolerances that matter are asserted in Stage B against the oracles. |
| v1_defect_probes | vectorisation | Eighteen distinct probes, each with its own call. There is no batched form. |
| v1_defect_probes | speed | Measures a tree that will be deleted at Stage F. A budget would outlive its subject. |
| v1_defect_probes | metamorphic | The probes assert what v1 does at named points; there is no invariance of v1's behaviour to assert. |
| v1_option_inventory | precision | Extracts names. No numerical claim. |
| v1_option_inventory | vectorisation | Reads five files once. No batched form. |
| v1_option_inventory | speed | Runs once per stage boundary at most. |
| v1_option_inventory | metamorphic | Its observable is a name mapping; permuting the input files changes only the recorded order of the Fronts column, which is meaningful and therefore not an invariance. |

## Reserved rows, to be filled at their stage

These are anticipated in the handover (Part 2.3.2) but must not be
pre-approved before the function exists and the claim can be checked.

| Function | Category | Reason | Status |
|---|---|---|---|
| L3 graphics elements | vectorisation | No batched form; each call draws into one axes. | pending Stage D |
| L3/L4 graphics | precision | The claim is geometric, asserted under contract with TolGeom. | pending Stage D |
| geo.cache | metamorphic | Its observable is a hit or a miss, which has no invariance to state. | pending Stage C |
| geo.export | reference | No external authority certifies a PDF's byte content. | pending Stage E |
