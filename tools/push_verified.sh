#!/usr/bin/env bash
# push_verified.sh - push a branch, then PROVE the remote moved.
#
# WHY THIS EXISTS. Three times in one session (22-Aug-2026) a command's
# OUTPUT was read as evidence that its SIDE EFFECT had happened, and all
# three were pushes or writes that silently did not occur:
#
#   1. A `git push` whose exit status was never checked; the echo that
#      followed it printed regardless.
#   2. A Python `write_text` that never ran, because an assert fired
#      first. The commit that followed claimed a repair that was not in
#      the tree.
#   3. A bridge push piped through `tail`, which DOES NOT EXIST ON
#      WINDOWS. The pipeline failed, the commit never left the machine,
#      and the histories diverged.
#
# Case 3 is the general trap and the reason a pipeline is forbidden here:
# in a pipe, `$?` is the exit status of the LAST command, so a failing
# `git push` piped into anything successful reports success. `set -o
# pipefail` fixes it in bash and is unavailable in the Windows shell the
# bridge uses. So: no pipeline, and an independent read-back afterwards.
#
# THE READ-BACK IS THE POINT. Exit status says the command believed it
# worked. Comparing the remote's SHA to local HEAD says the remote
# actually moved. Those are different claims, and only the second is the
# one anybody cares about.
#
# Usage:  tools/push_verified.sh <branch> [remote]
#
# geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)
set -euo pipefail

branch="${1:?usage: push_verified.sh <branch> [remote]}"
remote="${2:-origin}"

local_sha="$(git rev-parse HEAD)"

# No pipeline on this line. See above.
git push "$remote" "$branch"

# Independent read-back. `git ls-remote` asks the SERVER, rather than
# trusting the local remote-tracking ref, which the push itself just
# wrote and which would therefore agree with a push that half-failed.
remote_sha="$(git ls-remote "$remote" "refs/heads/$branch" | cut -f1)"

if [ -z "$remote_sha" ]; then
    echo ">>> FAILED: $remote has no branch $branch after a push that"
    echo ">>> reported success. Do not proceed as if it landed."
    exit 1
fi
if [ "$remote_sha" != "$local_sha" ]; then
    echo ">>> FAILED: remote is at ${remote_sha:0:8}, local HEAD is at"
    echo ">>> ${local_sha:0:8}. The push did not land what you think it did."
    exit 1
fi

echo "verified: $remote/$branch is at ${local_sha:0:8}, read back from the server"
