% geoMap — cartographic visualisation in base MATLAB
% Version 2.0.489-alpha.1 20-Aug-2026
%
%   THIS FILE IS THE VERSION AUTHORITY.
%
%   README.md, CHANGELOG.md, CITATION.cff, geoMap.prj and info.xml are
%   CHECKED against the line above by tools/geoMapAudit.m; none of them is
%   independently maintained. One authority per fact: a version kept in
%   two places disagrees with itself, and the disagreement surfaces at
%   release, which is the worst moment to discover it.
%
%   THE PATCH COMPONENT IS THE VERIFIED TEST-POINT COUNT (handover 6.7).
%   It moves when the EVIDENCE moves, so a pure rename correctly bumps
%   nothing and adding a checkpoint's tests bumps it by exactly what they
%   added. 489 is the count `rungeoMapTests("all")` reconciles three ways.
%   The -alpha.n suffix carries until the Stage F release checklist is
%   complete.
%
%   EVERY SUMMARY BELOW IS ITS FUNCTION'S H1 LINE, CHARACTER FOR
%   CHARACTER, and TestContentsConsistency asserts it. A contents file
%   that paraphrases is a second description of the same thing, which is
%   the F6 shape applied to prose: it will drift, and the drift is
%   invisible because both halves read plausibly.
%
%   THE GROUPING IS THE ARCHITECTURE. L1 values are validated once so
%   nothing re-checks them; L2 is arithmetic with no graphics; L3 draws
%   one thing into an axes; L4 orchestrates L3 and draws nothing itself -
%   a rule the audit enforces on every file marked L4-FRONT.
%
%   L1 — value structs, validated once
%     geo.crs              - Validated projection spec with a queryable domain.
%     geo.grid             - Validated lon/lat grid, checked once so nothing re-checks it.
%     geo.track            - Validated along-track series, NaN gaps preserved.
%     geo.points           - Validated scattered point set, with optional size and labels.
%     geo.region           - Resolve an area of interest into a padded box and outline.
%
%   L2 — numerics, no graphics
%     geo.project          - Forward projection, sixteen ways, NaN outside the domain.
%     geo.unproject        - Inverse projection for all sixteen. New in v2.
%     geo.scaleFactors     - Point distortion: h, k, area scale, max angular error.
%     geo.greatCircle      - Spherical distance, bearing and destination.
%     geo.splitAntimeridian - Break paths at the antimeridian, at the edge.
%     geo.splitTracks      - Split one continuous series into separate passes.
%     geo.wrapLongitude    - Wrap longitudes into a half-open window, exactly.
%     geo.regrid           - Resample a grid, periodically, and conservatively if asked.
%     geo.hillshade        - Analytic Horn hillshade with the spherical metric.
%     geo.quantile         - Type-7 interpolated quantiles, without a toolbox.
%     geo.symmetricLimits  - Colour limits symmetric about zero, for signed fields.
%     geo.niceTicks        - Round tick values, by a CEILING policy that never overshoots.
%     geo.colormaps        - Presets, discretisation, and truecolor mapping in one place.
%
%   L2 — reading
%     geo.readGrid         - Read a raster, or a window of one, into a validated GEO.GRID.
%     geo.readCoastline    - One coastline reader, replacing v1's four.
%     geo.cache            - Session cache for parsed and projected coastlines.
%
%   L3 — elements, one thing drawn into an axes
%     geo.basemap          - Draw a projected raster: one surface, no lights.
%     geo.graticule        - Meridians, parallels and their labels.
%     geo.frame            - The segmented neatline, at constant on-screen thickness.
%     geo.coastline        - Shorelines, rivers or an outline, projected and clipped.
%     geo.scalebar         - A bar whose length is the distance it claims.
%     geo.northarrow       - A north arrow pointing where north actually is.
%     geo.colorbar         - One colour scale, in four styles.
%     geo.inset            - A locator globe showing where the map is.
%     geo.title            - A map title, placed above the map and known to the layout.
%     geo.overlayPolygons  - A value per polygon: mascons, basins, tiles.
%     geo.stipple          - Mark where a field is significant, deterministically.
%     geo.overlayContours  - Contour lines of a field, projected and broken.
%     geo.overlayTrack     - An along-track series, as a wiggle or a coloured line.
%     geo.overlayPoints    - Scattered locations, coloured and optionally sized.
%     geo.series           - One time series: line, gaps, and an uncertainty band.
%
%   L4 — fronts, orchestration only
%     geo.map              - A finished map in one call.
%     geo.trackmap         - A track over topography, with the extent worked out for you.
%     geo.pointmap         - Scattered stations over topography, extent worked out for you.
%     geo.timeseries       - Several stations' records, stacked and labelled.
%     geo.panel            - Several maps and series in one figure, on one layout.
%     geo.export           - Write figures to files at an exact physical size.
%
%   Compatibility
%     geo.v1.imagesc       - v1's geoImagesc call, drawn by v2.
%
%   Instruments (not part of the toolbox)
%     rungeoMapTests       - the one project runner; its count is authoritative
%     GeoMapTestCase       - shared base class and the only timing instrument
%     geoMapAudit          - the static audit; a gate, not a report
%     geoMapAuditFixtures  - the fault-injection trees the audit is proved on
%     makeManifest         - regenerate MANIFEST.txt over the tree
%     verifyManifest       - verify the tree against MANIFEST.txt
%
%   See also RUNGEOMAPTESTS, GEOMAPAUDIT, GEO.MAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)
