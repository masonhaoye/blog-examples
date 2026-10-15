#!/bin/bash
# Fails if the repository tracks something that must not be published: files that belong to one
# machine or one run, local paths, email addresses, tokens and keys, Slack IDs, UUIDs such as session
# or simulator IDs, and links to the owner's other repositories.
#
# Usage: .github/scripts/check-public.sh   (from anywhere inside the repository)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

status=0
self=.github/scripts/check-public.sh

# Prints the tracked lines matching an extended regular expression, except in this script. No \b:
# macOS's regular expressions don't support it.
find_lines() {
    git grep -n -I -E "$@" -- . ":!$self" || true
}

report() {
    local what=$1 found=$2
    if [[ -n $found ]]; then
        echo "check-public: $what" >&2
        echo "$found" | sed 's/^/  /' >&2
        status=1
    fi
}

report "files that belong to one machine or one run:" \
    "$(git ls-files | grep -E '(^|/)(\.DS_Store$|xcuserdata/|DerivedData/|[^/]+\.xcresult/|[^/]+\.trace$)' || true)"
report "local paths (write ~/ or a placeholder instead):" \
    "$(find_lines '(/Users/|/home/)[A-Za-z0-9._-]+')"
report "email addresses (use example.com):" \
    "$(find_lines -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' | grep -v -E '@example\.(com|org|net)$|noreply' || true)"
report "tokens or private keys:" \
    "$(find_lines 'gh[oprsu]_[A-Za-z0-9]{20,}|github_pat_|xox[abprs]-|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY')"
report "Slack IDs:" \
    "$(find_lines '(^|[^A-Za-z0-9])[CDGUW]0[A-Z0-9]{7,10}([^A-Za-z0-9]|$)')"
report "UUIDs, such as session or simulator IDs (use a placeholder like <UDID>):" \
    "$(find_lines -i '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')"
report "links to other repositories of the owner:" \
    "$(find_lines -o 'github\.com[/:]masonhaoye/[A-Za-z0-9_.-]+' | grep -v -E 'masonhaoye/blog-examples(\.git)?$' || true)"

if [[ $status -eq 0 ]]; then
    echo "check-public: nothing to remove"
fi
exit $status
