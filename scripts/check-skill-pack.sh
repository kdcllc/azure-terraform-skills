#!/usr/bin/env bash
set -euo pipefail

# Optional first argument: pack root (default: current working directory).
PACK_ROOT="${1:-.}"

fail() {
  echo "error: $*" >&2
  exit 1
}

REQUIRED_PATHS=(
  skills/terraform-azure/SKILL.md
  skills/terraform-azure/references/operating-process.md
  skills/terraform-azure/references/ai-conventions.md
  skills/terraform-azure/references/azure-connections.md
  skills/terraform-azure/templates/module/providers.tf.tmpl
  skills/terraform-azure/templates/stack/backend.tf.tmpl
  skills/terraform-azure/scripts/bootstrap-tfstate.sh
  skills/terraform-azure/scripts/bootstrap-tfstate.ps1
  skills/terraform-azure/scripts/create-azure-oidc.sh
  skills/terraform-azure/scripts/create-azure-oidc.ps1
  skills/terraform-azure-modules/SKILL.md
  skills/terraform-azure-modules/reference.md
  skills/terraform-azure-pipelines/SKILL.md
  skills/terraform-azure-upgrade/SKILL.md
  skills/terraform-azure-upgrade/reference.md
  skills/terraform-azure-pipelines/assets/tf-deploy-base.yaml
  skills/terraform-azure-pipelines/assets/terraform-stack.yaml
  skills/terraform-azure-pipelines/assets/azure-pipelines.yaml
  skills/terraform-azure-pipelines/assets/gitlab-ci-terraform-template.yml
)

SKILL_PATHS=(
  skills/terraform-azure/SKILL.md
  skills/terraform-azure-modules/SKILL.md
  skills/terraform-azure-pipelines/SKILL.md
  skills/terraform-azure-upgrade/SKILL.md
)

UNDISCOVERED_ROOT_SKILL_DIRS=(
  .agents/skills
  .claude/skills
  .cursor/skills
  .github/skills
)

BANNED_PATTERN='vscode/|chrisdias\.|SugarBreeze|SB Corporate'
MAX_SKILL_LINES=500

CHANGELOG_FILE="CHANGELOG.md"
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
PACK_VERSION=""

# Canonical pins shipped to consumers; every duplicate below must agree.
# Bumping one is a release decision (see VERSIONING.md) — change the constant
# and the validator forces every copy to follow.
AZURERM_PIN='>= 5.0.0, < 6.0.0'
TF_REQ_PIN='>= 1.9.0, < 2.0.0'
TF_CLI_PIN='1.15.8'

AZURERM_PIN_FILES=(
  skills/terraform-azure/SKILL.md
  skills/terraform-azure/references/operating-process.md
  skills/terraform-azure/templates/module/providers.tf.tmpl
  skills/terraform-azure/templates/stack/providers.tf.tmpl
  skills/terraform-azure-modules/SKILL.md
  skills/terraform-azure-modules/reference.md
  skills/terraform-azure-upgrade/SKILL.md
  skills/terraform-azure-upgrade/reference.md
  docs/deep-dive.md
)

TF_REQ_PIN_FILES=(
  skills/terraform-azure/SKILL.md
  skills/terraform-azure/templates/module/providers.tf.tmpl
  skills/terraform-azure/templates/stack/providers.tf.tmpl
  skills/terraform-azure-modules/SKILL.md
  skills/terraform-azure-modules/reference.md
  skills/terraform-azure-upgrade/SKILL.md
  skills/terraform-azure-upgrade/reference.md
  docs/deep-dive.md
)

TF_CLI_PIN_FILES=(
  skills/terraform-azure/SKILL.md
  skills/terraform-azure-pipelines/SKILL.md
  skills/terraform-azure-pipelines/assets/tf-deploy-base.yaml
  skills/terraform-azure-pipelines/assets/azure-pipelines.yaml
  skills/terraform-azure-pipelines/assets/gitlab-ci-terraform-template.yml
  skills/terraform-azure-pipelines/assets/examples/dev-azure-pipelines.yaml
  skills/terraform-azure-upgrade/SKILL.md
  docs/deep-dive.md
)

check_required_paths() {
  local rel full
  for rel in "${REQUIRED_PATHS[@]}"; do
    full="${PACK_ROOT}/${rel}"
    if [[ ! -e "$full" ]]; then
      fail "missing required path: ${rel}"
    fi
  done
}

check_no_root_skill_md() {
  if [[ -f "${PACK_ROOT}/SKILL.md" ]]; then
    fail "SKILL.md at repository root is discovered by the Skills CLI; keep skills under skills/<name>/"
  fi
}

check_no_discovered_overlay() {
  local rel
  for rel in "${UNDISCOVERED_ROOT_SKILL_DIRS[@]}"; do
    if [[ -d "${PACK_ROOT}/${rel}" ]]; then
      fail "discovered skill container must not exist at pack root: ${rel} (move it under _unpacked/)"
    fi
  done
}

extract_frontmatter() {
  local file="$1"
  awk '
    /^---$/ {
      if (seen == 0) {
        seen = 1
        next
      }
      if (seen == 1) {
        exit
      }
    }
    seen == 1 { print }
  ' "$file"
}

check_skill_frontmatter() {
  local rel="$1"
  local full="${PACK_ROOT}/${rel}"
  local frontmatter

  frontmatter="$(extract_frontmatter "$full")"

  if ! grep -qE '^name:' <<<"$frontmatter"; then
    fail "missing name: in frontmatter: ${rel}"
  fi

  if ! grep -qE '^description:' <<<"$frontmatter"; then
    fail "missing description: in frontmatter: ${rel}"
  fi
}

extract_skill_version() {
  local file="$1"
  extract_frontmatter "$file" | awk '
    /^metadata:/ { in_meta = 1; next }
    in_meta && /^[^[:space:]]/ { in_meta = 0 }
    in_meta && $1 == "version:" {
      v = $2
      gsub(/"/, "", v)
      print v
      exit
    }
  '
}

check_skill_versions() {
  local rel full version
  for rel in "${SKILL_PATHS[@]}"; do
    full="${PACK_ROOT}/${rel}"
    version="$(extract_skill_version "$full")"
    if [[ -z "$version" ]]; then
      fail "missing metadata.version in frontmatter: ${rel}"
    fi
    if ! [[ "$version" =~ $SEMVER_RE ]]; then
      fail "metadata.version is not MAJOR.MINOR.PATCH: ${rel} (${version})"
    fi
    if [[ -z "$PACK_VERSION" ]]; then
      PACK_VERSION="$version"
    elif [[ "$version" != "$PACK_VERSION" ]]; then
      fail "skill version mismatch: ${rel} has ${version}, expected ${PACK_VERSION}"
    fi
  done
}

check_changelog_entry() {
  local full="${PACK_ROOT}/${CHANGELOG_FILE}"
  if [[ ! -f "$full" ]]; then
    fail "missing required path: ${CHANGELOG_FILE}"
  fi
  if ! grep -qE "^## \[${PACK_VERSION//./\\.}\]" "$full"; then
    fail "${CHANGELOG_FILE} has no '## [${PACK_VERSION}]' entry"
  fi
}

check_pin_consistency() {
  local rel full
  for rel in "${AZURERM_PIN_FILES[@]}"; do
    full="${PACK_ROOT}/${rel}"
    grep -qF "$AZURERM_PIN" "$full" || fail "azurerm pin drift (want '${AZURERM_PIN}'): ${rel}"
  done
  for rel in "${TF_REQ_PIN_FILES[@]}"; do
    full="${PACK_ROOT}/${rel}"
    grep -qF "$TF_REQ_PIN" "$full" || fail "required_version pin drift (want '${TF_REQ_PIN}'): ${rel}"
  done
  for rel in "${TF_CLI_PIN_FILES[@]}"; do
    full="${PACK_ROOT}/${rel}"
    grep -qF "$TF_CLI_PIN" "$full" || fail "terraform CLI pin drift (want '${TF_CLI_PIN}'): ${rel}"
  done
}

check_skill_line_cap() {
  local rel="$1"
  local full="${PACK_ROOT}/${rel}"
  local line_count

  line_count="$(wc -l <"$full" | tr -d ' ')"
  if (( line_count >= MAX_SKILL_LINES )); then
    fail "SKILL.md exceeds line cap (${MAX_SKILL_LINES}): ${rel} (${line_count} lines)"
  fi
}

check_banned_strings() {
  local skills_dir="${PACK_ROOT}/skills"
  local matches=""

  if [[ ! -d "$skills_dir" ]]; then
    fail "missing required path: skills"
  fi

  if command -v rg >/dev/null 2>&1; then
    matches="$(rg -n -e 'vscode/' -e 'chrisdias\.' -e 'SugarBreeze' -e 'SB Corporate' "$skills_dir" 2>/dev/null || true)"
  else
    matches="$(grep -rEn "$BANNED_PATTERN" "$skills_dir" 2>/dev/null || true)"
  fi

  if [[ -n "$matches" ]]; then
    fail "banned string found under skills/"
  fi
}

check_required_paths
check_no_root_skill_md
check_no_discovered_overlay

for rel in "${SKILL_PATHS[@]}"; do
  check_skill_frontmatter "$rel"
  check_skill_line_cap "$rel"
done

check_skill_versions
check_changelog_entry
check_pin_consistency
check_banned_strings
