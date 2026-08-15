% geoMap — cartographic visualisation in base MATLAB
% Version 2.0.0-alpha.0 15-Aug-2026
%
%   THIS FILE IS THE VERSION AUTHORITY.
%
%   README.md, CHANGELOG.md, CITATION.cff, geoMap.prj and info.xml are
%   CHECKED against the line above by tools/geoMapAudit.m; none of them is
%   independently maintained. One authority per fact: a version kept in
%   two places disagrees with itself, and the disagreement surfaces at
%   release, which is the worst moment to discover it.
%
%   The patch component tracks the count of verified test points
%   (handover §6.7). It moves when the evidence moves, so a pure rename
%   correctly bumps nothing. The -alpha.n suffix carries until Stage F.
%
%   The function list below is DELIBERATELY SHORT: +geo does not exist
%   yet. Stage F deliverable 6 grows this into the layer-grouped list
%   whose one-line summaries must match each function's H1 exactly,
%   verified by TestContentsConsistency. Until then this file exists for
%   the version alone, and says so rather than implying a complete
%   catalogue.
%
%   Instruments (Stage 0)
%     rungeoMapTests       - the one project runner; its count is authoritative
%     GeoMapTestCase       - shared base class and the only timing instrument
%     geoMapAudit          - the static audit; a gate, not a report
%     geoMapAuditFixtures  - the fault-injection trees the audit is proved on
%     makeManifest         - regenerate MANIFEST.txt over the tree
%     verifyManifest       - verify the tree against MANIFEST.txt
%
%   See also RUNGEOMAPTESTS, GEOMAPAUDIT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)
