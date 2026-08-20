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

check_banned_strings
