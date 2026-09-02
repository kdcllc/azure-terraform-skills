#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/release.sh <MAJOR.MINOR.PATCH>
# Bumps metadata.version in every SKILL.md, re-validates the pack, commits
# the bump (when it changes anything), and creates annotated tag v<version>.
# Never pushes; a '## [X.Y.Z]' CHANGELOG.md entry must already be committed.

PACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

fail() {
  echo "error: $*" >&2
  exit 1
}

SKILL_PATHS=(
  skills/terraform-azure/SKILL.md
  skills/terraform-azure-modules/SKILL.md
  skills/terraform-azure-pipelines/SKILL.md
  skills/terraform-azure-upgrade/SKILL.md
)

NEW_VERSION="${1:-}"
[[ -n "$NEW_VERSION" ]] || fail "usage: scripts/release.sh <MAJOR.MINOR.PATCH>"
[[ "$NEW_VERSION" =~ $SEMVER_RE ]] || fail "not MAJOR.MINOR.PATCH: ${NEW_VERSION}"
TAG="v${NEW_VERSION}"

branch="$(git -C "$PACK_ROOT" rev-parse --abbrev-ref HEAD)"
[[ "$branch" == "master" ]] || fail "releases are tagged on master (currently on: ${branch})"

if git -C "$PACK_ROOT" rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  fail "tag already exists: ${TAG}"
fi

# Working tree must be clean; the CHANGELOG entry is committed beforehand,
# so the release commit contains exactly the four SKILL.md bumps.
dirty="$(git -C "$PACK_ROOT" status --porcelain)"
[[ -z "$dirty" ]] || fail "working tree not clean; commit or stash first"

grep -qE "^## \[${NEW_VERSION//./\\.}\]" "${PACK_ROOT}/CHANGELOG.md" \
  || fail "CHANGELOG.md has no '## [${NEW_VERSION}]' entry — write and commit it first"

bump_skill_version() {
  local full="$1" tmp="$1.tmp"
  awk -v ver="$NEW_VERSION" '
    /^---$/ && fence < 2 { fence++; print; next }
    fence == 1 && /^metadata:/ { in_meta = 1; print; next }
    fence == 1 && in_meta && /^[^[:space:]]/ { in_meta = 0 }
    fence == 1 && in_meta && $1 == "version:" {
      sub(/version:.*/, "version: \"" ver "\"")
      replaced = 1
    }
    { print }
    END { exit replaced ? 0 : 1 }
  ' "$full" >"$tmp" || { rm -f "$tmp"; fail "no metadata.version line found: ${full}"; }
  mv "$tmp" "$full"
}

for rel in "${SKILL_PATHS[@]}"; do
  bump_skill_version "${PACK_ROOT}/${rel}"
done

bash "${PACK_ROOT}/scripts/check-skill-pack.sh" "$PACK_ROOT"

git -C "$PACK_ROOT" add "${SKILL_PATHS[@]}"
if ! git -C "$PACK_ROOT" diff --cached --quiet; then
  git -C "$PACK_ROOT" commit -m "release: ${TAG}"
fi
git -C "$PACK_ROOT" tag -a "$TAG" -m "azure-terraform-skills ${TAG}"

echo "created ${TAG}. inspect with: git show ${TAG}"
echo "publish with:"
echo "  git push origin master ${TAG}"
