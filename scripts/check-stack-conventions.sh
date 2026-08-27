#!/usr/bin/env bash
# Guards the stack-decomposition contract: one domain per stack, .tf written
# once per domain, per-environment tfvars, and cross-stack reads through
# azurerm data blocks only.
#
# Run standalone or via scripts/check-skill-pack.sh.
set -euo pipefail

PACK_ROOT="${1:-.}"
SKILLS_DIR="${PACK_ROOT}/skills"

fail() {
  echo "error: $*" >&2
  exit 1
}

CONVENTIONS="${SKILLS_DIR}/terraform-azure/references/ai-conventions.md"
PROCESS="${SKILLS_DIR}/terraform-azure/references/operating-process.md"
MAIN_SKILL="${SKILLS_DIR}/terraform-azure/SKILL.md"
STACK_MAIN="${SKILLS_DIR}/terraform-azure/templates/stack/main.tf.tmpl"
STACK_DATA="${SKILLS_DIR}/terraform-azure/templates/stack/data.tf.tmpl"
STACK_TFVARS="${SKILLS_DIR}/terraform-azure/templates/stack/dev.tfvars.tmpl"

# 1. The freeze documents must still carry the decomposition rules. If someone
#    edits these headings away, the agent loses the behaviour.
require_string() {
  local file="$1" needle="$2"
  [[ -f "$file" ]] || fail "missing file: ${file#"${PACK_ROOT}/"}"
  LC_ALL=C grep -qF -- "$needle" "$file" ||
    fail "${file#"${PACK_ROOT}/"} must document: ${needle}"
}

require_string "$CONVENTIONS" 'one domain per stack'
require_string "$CONVENTIONS" 'Domain catalog'
require_string "$CONVENTIONS" 'data blocks only'
require_string "$CONVENTIONS" '../../modules/<name>'
require_string "$CONVENTIONS" 'tfstate.{resource}.{domain}.{environment}'
require_string "$CONVENTIONS" 'envs/'

require_string "$PROCESS" 'One domain per stack'
require_string "$PROCESS" 'Cross-stack references'
require_string "$PROCESS" 'tfstate.{resource}.{domain}.{environment}'

require_string "$MAIN_SKILL" 'Rule 0 — decompose before you write'
require_string "$MAIN_SKILL" 'Domain catalog'
require_string "$MAIN_SKILL" 'Rule 2 — cross-stack reads are data blocks only'

require_string "$STACK_MAIN" 'ONE DOMAIN PER STACK'
require_string "$STACK_DATA" 'terraform_remote_state'
require_string "$STACK_TFVARS" 'envs/dev.tfvars'

# 2. No shipped template, asset, or example may contain a live
#    terraform_remote_state block. Prose that forbids it is fine.
if grep -rEn 'data[[:space:]]+"terraform_remote_state"' "$SKILLS_DIR" 2>/dev/null; then
  fail "terraform_remote_state block found under skills/ — cross-stack reads are azurerm data blocks only"
fi

# 3. Superseded module source depth. Every stack now sits at resources/<domain>/,
#    so the only correct depth is ../../modules/.
if grep -rEn '\.\./\.\./\.\./modules' "$SKILLS_DIR" 2>/dev/null; then
  fail "superseded module source depth under skills/ — stacks at resources/<domain>/ use ../../modules/<name>"
fi

# 3b. Per-environment tfvars live in ONE envs/ folder per stack. The earlier
#     folder-per-environment shape (dev/dev.tfvars) must not reappear.
if grep -rEn '<env>/<env>\.tfvars|[^s]/dev/dev\.tfvars|[[:space:]]dev/dev\.tfvars|"dev/dev\.tfvars"' "$SKILLS_DIR" 2>/dev/null; then
  fail "folder-per-environment tfvars found under skills/ — use one envs/<env>.tfvars per stack"
fi

# 4. The superseded resources/environments/ layout may only appear where it is
#    being rejected. Anywhere else it would read as guidance.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if ! grep -qE 'superseded|Rejected|Do not use|do not use' <<<"$line"; then
    fail "resources/environments/ referenced outside a rejection: ${line}"
  fi
done < <(grep -rn 'resources/environments/' "$SKILLS_DIR" 2>/dev/null || true)

echo "stack conventions OK"
