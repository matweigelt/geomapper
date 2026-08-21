#!/usr/bin/env bash
# Run every gate locally, byte-identical to CI.
#
# CI is the shared instrument, not the only one. A contributor who cannot
# reproduce the gates locally ships guesses and polls. Run this to zero
# BEFORE pushing; let CI confirm rather than discover.
#
# The MATLAB gate is skipped automatically when no matlab binary is on the
# PATH - and it says so LOUDLY. A silently skipped gate is worse than an
# absent one: it looks exactly like a passing one.
#
# geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
run () { echo; echo "=== $1 ==="; shift; "$@" || { echo ">>> GATE FAILED"; fail=1; }; }

run "1/5 structural check"        python3 tools/mcheck.py .
run "2/5 provenance audit"        python3 tools/provenance_audit.py .
# The document set is checked with the code, not after it. A status
# that has stopped matching its evidence is invisible to every other
# gate here, because every other gate looks at code (PV-130).
run "3/5 ledger sync"             python3 tools/ledger_sync.py .
run "4/5 mirror"                  bash -c "cd mirror && python3 -m geomap_mirror.gdal_oracle && python3 -m geomap_mirror.references && python3 check_acceptance.py"

echo; echo "=== 5/5 MATLAB suite ==="
if command -v matlab >/dev/null 2>&1; then
  # geoMapAudit runs FIRST and with its self-test on. It is the only gate
  # here that proves every one of its checks against a planted defect
  # before reporting, and a red audit then costs seconds rather than a
  # full suite run.
  matlab -batch "addpath(pwd); geoMapSetup; ok=geoMapAudit(); exit(~ok)" || { echo ">>> GATE FAILED"; fail=1; }
  matlab -batch "addpath(pwd); geoMapSetup; makeManifest; ok=rungeoMapTests(\"all\"); exit(~ok)" || { echo ">>> GATE FAILED"; fail=1; }
else
  echo ">>> SKIPPED: no 'matlab' on PATH."
  echo ">>> This gate did NOT run. Do not read the summary below as if it did."
  fail=$((fail==0 ? 0 : fail))
  skipped=1
fi

echo; echo "============================================"
if [ "$fail" -eq 0 ]; then
  echo " local gates: PASS${skipped:+ (MATLAB gate SKIPPED - incomplete)}"
else
  echo " local gates: FAIL"
fi
echo "============================================"
exit $fail
