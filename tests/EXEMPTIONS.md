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
| geo.basemap | precision | The claim is geometric and is asserted under `contract` at TolGeom, per handover 2.3.2. The numerical claims it composes - projection, hillshade, colour mapping - are asserted where they are made, in Stages B and C. |
| geo.basemap | vectorisation | One call draws into one axes. There is no batched form to compare a loop against. |
| geo.graticule | precision | Same as geo.basemap: geometric, asserted under `contract`. The two closed-form assertions (0-meridian x, Mollweide span) run there at 1e-9 rather than at a drawing tolerance. |
| geo.graticule | vectorisation | One call draws into one axes. |
| geo.graticule | robustness | **NOT EXEMPT** - listed here only to record that it was considered and rejected. Its degenerate cases run inside geo.basemap's rows, because a graticule with no basemap raises before it draws. |
| geo.frame | precision | Geometric, asserted under `contract` by patch count and under `metamorphic` by the resize invariant. |
| geo.frame | vectorisation | One call draws into one axes. |
| geo.internal.layout | precision | A registry stores and returns rectangles unchanged. There is no arithmetic to bound; that it does not alter them is asserted under `contract`. |
| geo.internal.layout | vectorisation | Its interface is one command at a time by construction. |
| geo.internal.layout | reference | No external authority certifies a figure resize registry. |
| geo.internal.layout | speed | Its cost is a struct-array append against a graphics redraw that dominates it by orders of magnitude; a ratio would measure MATLAB's renderer. |
| geo.coastline | precision | The coordinates are GEO.READCOASTLINE's, asserted exact for shapefiles in Stage C, passed through GEO.PROJECT, certified against PROJ. This function adds no arithmetic of its own to bound. |
| geo.coastline | vectorisation | One call draws into one axes. |
| geo.northarrow | precision | The bearing is a central difference of GEO.PROJECT and inherits its measured 1e-8; the claim asserted under `reference` is the stronger one, that north is measured AT the arrow rather than once for the map. |
| geo.northarrow | vectorisation | One call draws one glyph. |
| geo.scalebar | precision | Its numerical claim - that the bar is as long as it says - is asserted under `reference` by walking the drawn bar, which is a stronger instrument than a tolerance on an intermediate. |
| geo.internal.projectPolyline | precision | It projects and decides; the projection's accuracy is GEO.PROJECT's and is asserted there, and the decision is a boolean asserted under `contract`. |
| geo.internal.projectPolyline | vectorisation | It IS the vectorised form; there is no scalar version to compare a loop against. |
| geo.scalebar | vectorisation | One call draws one bar. |
| geo.internal.projectPolyline | reference | No external authority certifies where a projection's branch cuts lie; the criterion is behavioural - a segment that will not shrink - and is asserted under `contract` and `robustness`. |
| geo.internal.projectPolyline | speed | Its cost is dominated by GEO.PROJECT, which has its own budgets; a ratio here would measure that function twice. |
| geo.internal.plottedBox | precision | Exact arithmetic on a Position and two axis limits; that it is exact is asserted under `contract` at 1e-9, which is the whole claim. |
| geo.internal.plottedBox | vectorisation | One axes per call. |
| geo.internal.plottedBox | reference | No external authority certifies MATLAB's own letterboxing; the assertion is against the arithmetic it must satisfy. |
| geo.internal.plottedBox | speed | Two property reads and a division. A budget would measure the timer. |
| geo.internal.plottedBox | metamorphic | Its output is a pure function of the axes state; there is no invariance to state to assert. |
| geo.internal.plottedBox | robustness | A degenerate aspect returns the axes rectangle, which is asserted under `contract`; there is no other degenerate input, because the argument block rejects anything that is not an axes. |
| geo.overlayPolygons | precision | Its two numerical claims - that a polygon takes exactly the basemap's colour for its value, and that a seam-crossing polygon's parts total exactly its own width - are asserted under `reference` at 0 and 1e-9. A separate precision row would assert the same two things less directly. |
| geo.overlayPolygons | vectorisation | One call draws one polygon set; the per-polygon loop IS the interface. |
| geo.stipple | precision | The marks sit at projected cell centres and inherit GEO.PROJECT's accuracy; the claim that matters is determinism, asserted under `metamorphic` as bit-identical output. |
| geo.stipple | vectorisation | One call marks one mask. |
| geo.overlayContours | precision | Vertices are CONTOURC's, unmodified; this function projects them and decides where to break, and both are asserted behaviourally. |
| geo.overlayContours | vectorisation | One call contours one field. |
| geo.overlayTrack | precision | Its numerical claim - the wiggle amplitude is exactly Obs times Scale - is asserted under `reference` at 1e-12 relative, which is the same assertion a precision row would make. |
| geo.overlayTrack | vectorisation | One call draws one track; the per-run loop IS the interface. |
| geo.overlayPoints | precision | Its numerical claim - a legend circle has its own marker's radius - is asserted under `reference` at exactly 0 points. |
| geo.overlayPoints | vectorisation | One call draws one point set, in one Scatter object. |
| geo.colorbar | precision | Its one geometric claim - a tick sits at the exact fraction along the bar - is asserted under `reference` at TolGeom. Everything else it does is layout, which has no correct answer to be precise about. |
| geo.colorbar | vectorisation | One call draws one bar. |
| geo.inset | precision | Geometric, asserted under `robustness` by the extent outline closing exactly. The projection's own accuracy is GEO.PROJECT's. |
| geo.inset | vectorisation | One call draws one locator. |
| geo.inset | reference | No external authority certifies a locator globe's appearance; its projection is Stage B's and is certified there. |
| geo.internal.avoidRectCollisions | precision | Rectangle edges are compared and added exactly; the only constant is a 4-point clearance, which is a typographic choice and not a measurement. There is no error to bound. |
| geo.internal.avoidRectCollisions | reference | Ported verbatim from v1, which is the thing being replaced and is not an authority on correctness. Its geometry is asserted directly under `contract`. |
| geo.internal.avoidRectCollisions | vectorisation | Moves one rectangle. |
| geo.internal.avoidRectCollisions | speed | At most eight passes over a handful of rectangles; a budget would measure the timer. |
| geo.internal.avoidRectCollisions | metamorphic | Order-dependent BY DESIGN - it is a greedy solver and obstacle order changes the result. Asserting a permutation invariance would assert something false. |

## Reserved rows, to be filled at their stage

These are anticipated in the handover (Part 2.3.2) but must not be
pre-approved before the function exists and the claim can be checked.

| Function | Category | Reason | Status |
|---|---|---|---|
| L3 graphics elements | vectorisation | No batched form; each call draws into one axes. | **filled 16-Aug-2026**, per function above |
| L3/L4 graphics | precision | The claim is geometric, asserted under contract with TolGeom. | **filled 16-Aug-2026** for D.1; D.2/D.3 rows follow at their checkpoints |
| geo.cache | metamorphic | Its observable is a hit or a miss, which has no invariance to state. | **withdrawn 15-Aug-2026**: a metamorphic test DID exist - the cache is transparent, so a cached read equals an uncached one. The exemption was false. |
| geo.export | reference | No external authority certifies a PDF's byte content. | pending Stage E |
