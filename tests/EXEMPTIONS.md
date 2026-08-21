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
| geo.internal.sha256OfText | metamorphic | A hash has no invariance worth asserting beyond determinism, which is covered under `contract`. Re-read 20-Aug-2026 when the function moved into +geo (PV-127) and still true: SHA-256 is deliberately not homomorphic, so there is no relation between the digest of a part and the digest of the whole to assert. |
| geo.internal.sha256OfText | speed | Not on any hot path. `geo.cache` calls it once per coastline key, against a read that takes orders of magnitude longer. A budget would measure the JVM. |
| geo.internal.sha256OfText | precision | Exact by construction, and asserted against the NIST vectors rather than against itself under `reference`. |
| geo.internal.sha256OfText | vectorisation | Single char-vector interface. There is no array-of-strings form, and adding one to satisfy a category would be inventing an interface nothing calls. |
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
| build_help | precision | Its one number — the fraction of documented arguments rendered — is a COUNT of strings found in files, asserted under `reference` at exactly 0 missing. A count has no error to bound; it is right or it is wrong. |
| build_help | vectorisation | It walks 43 functions once and writes 46 files. There is no batched form of "render the manual", and a second one would be a second renderer. |
| build_help | speed | It runs once per release, takes a few seconds, and its cost is dominated by `checkcode` on the examples — which is MATLAB's, not ours. A budget here would measure the Code Analyzer. |
| geo.internal.hasParallelPool | precision | It returns a logical. There is no number and therefore no error to bound. |
| geo.internal.hasParallelPool | vectorisation | One question, one answer. |
| geo.panel | precision | Its two numbers — the map heights agreeing and the series box matching — are asserted under `reference`, the first at v1's 2% visual threshold and the second at 1e-12. The 2% is deliberately not tightened: it is the point at which a reader stops seeing two panels as the same size, not a measurement. |
| geo.panel | vectorisation | One call draws one figure; the per-tile loop is the layout. |
| geo.series | precision | Its one numerical claim — the drawn ordinate is Obs plus Offset — is asserted under `reference` at exactly 0, on the stack `geo.timeseries` builds, because that is where an offset means anything. A precision test here would assert the same addition through one less layer. |
| geo.series | vectorisation | Draws one series. The band's per-run loop IS the interface: a run is a stretch with data in it, and there is no batched form of "one station". |
| geo.series | speed | Its cost is one `plot3` and one `patch` per run. Budgeted where the total is, in `geo.timeseries`. |
| geo.series | metamorphic | Its invariances are the gap rule's, and the gap rule is `geo.splitTracks`', asserted there. What this adds — that the band breaks where the line does — is asserted under `robustness` because it is a statement about one drawing, not about two. |
| geo.timeseries | precision | Its two numbers, the ordinate and the spacing, are asserted under `reference` at 0 and 1e-12. There is no third claim for a precision test to make. |
| geo.timeseries | vectorisation | One call draws one stack; the per-station loop is the stack. |
| geo.trackmap | precision | Its one number - the pad - is exact and asserted under `reference` at 1e-12 relative. Everything else on the figure belongs to an element. |
| geo.trackmap | vectorisation | One call draws one map. |
| geo.pointmap | precision | As `geo.trackmap`: the same resolver, the same claim, asserted once for both. |
| geo.pointmap | vectorisation | One call draws one map. |
| geo.pointmap | speed | Budgeted once, in `geo.trackmap`, because the two share every line that costs anything. Timing both would time `geo.map` twice. |
| geo.internal.mapBackdrop | precision | Its one numerical claim — the pad — is asserted under `reference` at 1e-12 relative, on the limits both fronts return, because that is where a reader looks for it. The arithmetic itself is `geo.region`'s: this function chooses which spec form to hand it and deliberately owns no second padding rule. |
| geo.internal.mapBackdrop | vectorisation | Resolves one extent and reads one window. |
| geo.internal.mapBackdrop | speed | Its cost is `geo.readGrid`'s and `geo.regrid`'s, budgeted where those are. What it adds is four comparisons. |
| geo.internal.splitOptions | precision | Partitions a list by name equality. No arithmetic. |
| geo.internal.splitOptions | vectorisation | Walks one option list once. |
| geo.internal.splitOptions | speed | At most a few dozen names, once per figure. |
| geo.internal.splitOptions | reference | Nothing external certifies how a name-value list should be partitioned; the partition IS the specification and is asserted under `contract`. |
| geo.internal.withData | precision | Writes absent struct fields. No arithmetic. |
| geo.internal.withData | vectorisation | One struct. |
| geo.internal.withData | speed | One struct. |
| geo.internal.withData | reference | As `splitOptions`: the merge rule is the specification. |
| geo.internal.backdropOptions | precision | A list of names. |
| geo.internal.backdropOptions | vectorisation | A list of names. |
| geo.internal.backdropOptions | speed | A list of names. |
| geo.internal.backdropOptions | reference | A list of names, and the only claim about it - that it has no duplicates and that both fronts use it rather than a literal - is asserted under `contract`. |
| geo.internal.backdropOptions | robustness | Takes no input, so there is no malformed one to survive. |
| geo.internal.backdropOptions | metamorphic | A constant. There is no input to vary. |
| geo.internal.dataFile | precision | Returns a path. A path is right or it is not. |
| geo.internal.dataFile | vectorisation | One name. |
| geo.internal.dataFile | speed | One `fileparts`. |
| geo.internal.dataFile | metamorphic | Its output depends only on the name, and that it is independent of the MATLAB path is the whole point - asserted under `reference`, which is the stronger statement. |
| geo.internal.v1Options | precision | It moves names and carries values across unchanged. There is no arithmetic and therefore no error to bound; the one value it rewrites, `Illuminate` to a `Hillshade` string, is a substitution asserted exactly under `contract`. |
| geo.internal.v1Options | vectorisation | Walks one option list once. |
| geo.internal.v1Options | speed | It runs once per figure over at most 120 names, against a map that takes seconds to draw. A budget here would measure the timer. |
| geo.internal.v1OptionTable | precision | A table of strings. |
| geo.internal.v1OptionTable | vectorisation | A table of strings. |
| geo.internal.v1OptionTable | speed | A table of strings, built once. |
| geo.internal.v1OptionTable | metamorphic | It is a constant. There is no input to vary. |
| geo.internal.v1OptionTable | robustness | It takes no input, so there is no malformed one to survive. Its own consistency — every row present, unique, and pointing at an option that exists — is asserted under `contract`. |
| geo.v1.imagesc | precision | Three lines of forwarding. Every number belongs to `geo.map` and its elements. |
| geo.v1.imagesc | vectorisation | One call draws one map. |
| geo.v1.imagesc | speed | Budgeted where the cost is, in `geo.map`. |
| geo.v1.imagesc | metamorphic | Its invariances are the translator's and are asserted there; it adds no state of its own. |
| geo.v1.imagesc | reference | v1 is the thing being replaced and is not an authority on correctness — several of its pictures were wrong, which is why v2 exists. That the OPTION NAMES match v1 exactly is asserted under `contract` against v1's own source, which is the only claim v1 can certify. |
| geo.map | precision | It computes nothing. Every number on the figure belongs to an element and is asserted where that element is; what a front can get wrong is COMPOSITION, which is asserted under `reference` against the same map built by hand. A precision test here would re-assert geo.basemap's arithmetic through one more layer. |
| geo.map | vectorisation | One call draws one map. Several maps side by side are `geo.panel`. |
| geo.title | precision | Its one number - the clearance above the map - is exact arithmetic on the plotted box and is asserted under `reference` at 1e-9 relative. There is no second, finer claim. |
| geo.title | vectorisation | Draws one title. The multi-line form is one Text object, not a loop. |
| geo.title | speed | One Text object and one Extent read. A budget would measure the renderer's text metrics, which are not ours; the front's total cost is budgeted once, in `geo.map`. |
| geo.title | metamorphic | Its observable is a position, which is a function of the plotted box alone. The invariance worth asserting - that a resize re-places it - is the layout manager's and is asserted there. |
| geo.export | precision | Its numerical claim - the page is the size that was asked for - is asserted under `reference` against the produced file, at 0.05 cm and 1 px. There is no second, finer claim for a precision test to make. |
| geo.export | vectorisation | The batch form IS the vectorised form, and it is asserted under `contract` and `metamorphic` rather than timed: a batch of N writes N files, and no arithmetic is repeated per file that could be lifted out of a loop. |
| geo.internal.writeFigureFile | precision | It selects an instrument and writes a file. It computes nothing, so there is no error to bound; the size claim belongs to `geo.export`, which owns the page. |
| geo.internal.writeFigureFile | reference | Its output IS a file written by MATLAB's own exporters. Certifying it against an external authority would certify PRINT, not this. The one thing it decides - which route each extension takes - is asserted under `contract` on the returned method. |
| geo.internal.writeFigureFile | vectorisation | Writes one file. |
| geo.internal.writeFigureFile | speed | One disk write through the graphics stack; a budget here would measure PRINT and the filesystem. The wrapper's own cost is budgeted once, in `geo.export`. |
| geo.internal.writeFigureFile | metamorphic | Determinism is asserted where it is observable, on the produced image, under `geo.export`'s metamorphic tests. |

## Reserved rows, to be filled at their stage

These are anticipated in the handover (Part 2.3.2) but must not be
pre-approved before the function exists and the claim can be checked.

| Function | Category | Reason | Status |
|---|---|---|---|
| L3 graphics elements | vectorisation | No batched form; each call draws into one axes. | **filled 16-Aug-2026**, per function above |
| L3/L4 graphics | precision | The claim is geometric, asserted under contract with TolGeom. | **filled 16-Aug-2026** for D.1; D.2/D.3 rows follow at their checkpoints |
| geo.cache | metamorphic | Its observable is a hit or a miss, which has no invariance to state. | **withdrawn 15-Aug-2026**: a metamorphic test DID exist - the cache is transparent, so a cached read equals an uncached one. The exemption was false. |
| geo.export | reference | No external authority certifies a PDF's byte content. | **withdrawn 16-Aug-2026**: the exemption was false. Nothing certifies the *content*, but the file's own MediaBox certifies its *size*, and the size is the claim. `geo.export` has four reference tests. |
| geo.internal.mapBoundary | vectorisation | One extent has one boundary. There is no batched form of "where this map is". |
| geo.internal.mapBoundary | precision | It introduces no arithmetic of its own: the coordinates are GEO.PROJECT's, certified against PROJ as oracle O4. The one number it does introduce is the coincidence tolerance, and that is a threshold separating two measured populations sixteen orders apart - asserted under `contract` as a decision, not under `precision` as an accuracy. |
| geo.internal.clipToBoundary | vectorisation | One polyline, one boundary. Clipping several against the same ring is the caller's loop, and a batched form would only move it. |

