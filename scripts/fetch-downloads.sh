#!/usr/bin/env bash
# Download every pinned third-party file into downloads/, checksum-verified.
# Official sources first, the project's GitHub release (v1.0.0) as fallback
# (see docs/mirror.md).
#
# Usage: scripts/fetch-downloads.sh            # everything
#        scripts/fetch-downloads.sh NAME...    # only these (names as in SHA256SUMS)
#        scripts/fetch-downloads.sh --list

set -euo pipefail
# shellcheck source=lib/fetch.sh
. "$(dirname "$0")/lib/fetch.sh"

if [ "${1:-}" = "--list" ]; then
    printf '%s\n' "${ARTIFACTS[@]}"; exit 0
fi

command -v curl >/dev/null || { echo "curl not found." >&2; exit 1; }

NAMES=("$@")
[ ${#NAMES[@]} -gt 0 ] || NAMES=("${ARTIFACTS[@]}")

failed=0
for n in "${NAMES[@]}"; do
    fetch_artifact "$n" || failed=$((failed + 1))
done

echo
if [ $failed -eq 0 ]; then
    echo "All files present and verified in downloads/."
else
    echo "$failed file(s) could not be fetched. See docs/mirror.md for manual sources." >&2
    exit 1
fi
