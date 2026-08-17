#!/usr/bin/env bash
set -uo pipefail

# Mechanical ceiling on pull request size.
#
# Thresholds are calibrated against this repository's own history rather than
# picked: across 96 merged pull requests the median was 4 changed files and 236
# added lines, p90 was 15 files and 1,748 lines, p95 was 18 files and 2,877
# lines. A ceiling of 20 files or 2,000 added lines flags 9% of that history and
# catches every batch that actually caused an incident -- including the one that
# reached CONFLICTING at +11,667/-456 across 31 files while holding the only
# copy of a binary's source.
#
# usage: check-pr-size.sh <base-sha> <head-sha>
# env:   PR_SIZE_ESCAPE_LABELS  newline- or comma-separated labels on the PR
#        PR_SIZE_MAX_FILES      override for tests
#        PR_SIZE_MAX_ADDITIONS  override for tests

MAX_FILES=${PR_SIZE_MAX_FILES:-20}
MAX_ADDITIONS=${PR_SIZE_MAX_ADDITIONS:-2000}
ESCAPE_LABEL=oversized-pr-accepted

base=${1:-}
head=${2:-}
if [[ -z "$base" || -z "$head" ]]; then
  echo "check-pr-size: usage: check-pr-size.sh <base-sha> <head-sha>" >&2
  exit 64
fi

# Generated and vendored content is not review surface and does not create
# conflict surface a human resolves, so it does not count against the budget.
is_excluded() {
  case "$1" in
    *.lock|*.sum|go.sum|package-lock.json|pnpm-lock.yaml|yarn.lock) return 0 ;;
    vendor/*|*/vendor/*|third_party/*|*/third_party/*) return 0 ;;
    testdata/*|*/testdata/*|*.golden|*.snap) return 0 ;;
    *) return 1 ;;
  esac
}

merge_base=$(git merge-base "$base" "$head" 2>/dev/null) || merge_base=$base

files=0
additions=0
while IFS=$'\t' read -r added _removed path; do
  [[ -n "${path:-}" ]] || continue
  is_excluded "$path" && continue
  files=$((files + 1))
  # A binary file reports "-" rather than a count.
  [[ "$added" =~ ^[0-9]+$ ]] && additions=$((additions + added))
done < <(git diff --numstat "$merge_base" "$head" 2>/dev/null)

echo "pr-size: $files changed files (max $MAX_FILES), $additions added lines (max $MAX_ADDITIONS), excluding generated and vendored paths"

if ((files <= MAX_FILES)) && ((additions <= MAX_ADDITIONS)); then
  echo "pr-size: within budget"
  exit 0
fi

# The escape hatch is a label, so taking it is a recorded, reviewable act rather
# than an environment variable nobody sees.
if [[ -n "${PR_SIZE_ESCAPE_LABELS:-}" ]]; then
  while IFS= read -r label; do
    label=${label//,/}
    label=$(printf '%s' "$label" | tr -d '[:space:]')
    if [[ "$label" == "$ESCAPE_LABEL" ]]; then
      echo "pr-size: over budget, but the '$ESCAPE_LABEL' label is present; allowing"
      exit 0
    fi
  done < <(printf '%s\n' "${PR_SIZE_ESCAPE_LABELS//,/$'\n'}")
fi

echo "pr-size: over budget." >&2
echo "pr-size: split this pull request, or apply the '$ESCAPE_LABEL' label and say in the description why it cannot be split." >&2
echo "pr-size: a batch this size is the shape that reaches CONFLICTING and strands the only copy of its own source." >&2
exit 1
