---
name: terraform-azure
description: >-
  Guides operators through the Terraform Azure operating process — new library
  modules, environment stacks, CI pipelines (Azure DevOps, GitHub Actions,
  GitLab), remote-state bootstrap, and Azure OIDC connections — using Azure CLI
  only and stopping at plan. Use when scaffolding or walking through module,
  stack, pipeline, bootstrap, or connection work in a consumer Azure Terraform
  repository.
license: MIT
---

# Terraform Azure (`terraform-azure`)

Human operators and agents share one contract: [references/operating-process.md](references/operating-process.md). Layout freeze: [references/ai-conventions.md](references/ai-conventions.md).

**Workstation tools:** Azure CLI (`az`), Terraform **1.15.8**, Git, bash or PowerShell 7. Optional: `gh`, `az devops`, `glab`.

For extra **file-shape** patterns only (not version pins), read sibling skills on demand:

- [../terraform-azure-modules/SKILL.md](../terraform-azure-modules/SKILL.md) — library module layout
- [../terraform-azure-pipelines/SKILL.md](../terraform-azure-pipelines/SKILL.md) — pipeline layout

After writing HCL, run **tier 1** (`terraform fmt -check`, `terraform init -backend=false`, `terraform validate`) in the module or stack directory. Never run a full-library sweep from this skill.

This skill ships templates under [templates/](templates/) and helper scripts under [scripts/](scripts/). Paths below are **relative to this skill folder** unless they name a path in the **consumer** repository (`modules/`, `resources/environments/`, `.github/workflows/`, `pipelines/`).

## Step 0 — Ask which menu item

**Before any scaffolding**, present the five-item menu and ask which path to take:

| # | Menu item | Delivers |
| --- | --- | --- |
| **1** | **New module (interface)** | Reusable library module under `modules/<name>/` |
| **2** | **New stack (class)** | Environment root under `resources/environments/...` |
| **3** | **New pipeline** | CI for fmt / validate / plan (ADO + GHA + GitLab) |
| **4** | **Bootstrap state storage** | One-shot remote state RG + storage + container |
| **5** | **Create Azure connections** | OIDC / service connections for CI |

Do not assume a menu choice. Wait for the operator to pick **1–5**, then follow only that section.

---

## Must NOT (binding prohibitions)

This skill and agents using it **must not**:

- Run or instruct **Azure Developer CLI** (`azd`) — including deploy/up workflows, package-manager invocation, or adding it as a documented dependency.
- Run **`terraform apply`** or **`terraform destroy`** — stop at tier 2 (plan). Apply and destroy are for humans or gated CI only.
- Reference host-specific editor extension tool IDs — name documentation tools by role only.
- Inline a second bootstrap implementation — use the checked-in scripts (menu items 4 and 5).
- Create a populated `resources/environments/` tree during skill authoring; templates only unless the operator chose menu item 2 and confirmed paths.
- Use filename **`provider.tf`** — this library standard is **`providers.tf`** only.

---

## Menu 1 — New module (interface)

**Target (consumer repo):** `modules/<snake_name>/` — one primary Azure resource type per folder.

Read [../terraform-azure-modules/SKILL.md](../terraform-azure-modules/SKILL.md) for file-shape details, then follow this section.

### Reuse first

List `modules/` in the **consumer** repository. If a sibling already covers the resource, **update that module** instead of duplicating.

### Files (from this skill's templates)

Copy and adapt from [templates/module/](templates/module/):

| File | Template |
| --- | --- |
| `main.tf` | `templates/module/main.tf.tmpl` |
| `variables.tf` | `templates/module/variables.tf.tmpl` (must include `organization_name`) |
| `outputs.tf` or `output.tf` | `templates/module/outputs.tf.tmpl` — match sibling modules in the consumer repo |
| `providers.tf` | `templates/module/providers.tf.tmpl` |

**Required conventions:**

- **`providers.tf`** with `azurerm` `>= 5.0.0, < 6.0.0` and `required_version = ">= 1.9.0, < 2.0.0"`.
- **`organization_name`** variable on every library module.
- **No** `provider.tf` filename.
- **No** `backend.tf` on library modules.
- **No** `resource_provider_registrations` on library modules — that belongs on environment stacks only.

### Naming

Canonical pattern (one pattern only):

```
{resource-type}-{organization_name}-{resource}-{environment}
```

Example: `rg-acme-webapp-dev` (`rg` = resource-type abbreviation).

Use placeholders like `acme` in examples — never real org names, subscription IDs, or keys.

### Validation (tier 1)

```bash
terraform fmt -check -diff modules/<name>
cd modules/<name> && terraform init -backend=false && terraform validate
```

---

## Menu 2 — New stack (class)

**Target (consumer repo):** environment-specific root module consuming library modules via relative `source`.

### Ask at create time (required)

Before writing files, ask:

1. **Environment** — e.g. `dev`, `test`, `prod` (folder segment `<env>`).
2. **Azure region (location)** — e.g. `eastus`, `westeurope`.
3. **Subscription** — current `az account show` subscription, or another subscription ID the stack will target.
4. **Region in layout** — whether `<region>` appears in the **folder path**, in the **resource name**, in the **state key**, both, or neither.

**location is always** a stack variable in `variables.tf` and **location is always** passed into every `module` block, even when region is neither in the folder path nor in the resource name. Modules never infer region from path alone.

### Directory layout

**Default (canonical):**

```
resources/environments/<env>/<resource>/
```

**Optional region folder** (only when operator chose region-in-path):

```
resources/environments/<env>/<region>/<resource>/
```

**Rejected:** flat `resources/<resource>/` — do not create or document that layout.

Create the directory tree when adding a real stack; this skill ships templates only.

### Relative module `source` (frozen)

| Stack path | Module `source` |
| --- | --- |
| `resources/environments/<env>/<resource>/` | `source = "../../../modules/<name>"` |
| `resources/environments/<env>/<region>/<resource>/` | `source = "../../../../modules/<name>"` |

Example (default depth):

```hcl
module "resource_group" {
  source = "../../../modules/resource_group"

  organization_name = var.organization_name
  resource          = var.resource
  environment       = var.environment
  location          = var.location
  tags              = var.tags
}
```

### Stack files (from this skill's templates)

Copy and adapt from [templates/stack/](templates/stack/):

| File | Template |
| --- | --- |
| `main.tf` | `templates/stack/main.tf.tmpl` — adjust `source` depth per table above |
| `variables.tf` | `templates/stack/variables.tf.tmpl` — **must** declare `location` |
| `providers.tf` | `templates/stack/providers.tf.tmpl` — sets `resource_provider_registrations = "legacy"` |
| `backend.tf` | `templates/stack/backend.tf.tmpl` — empty `backend "azurerm" {}` |
| `<env>.tfvars` | `templates/stack/dev.tfvars.tmpl` — e.g. `dev.tfvars` |

### Stack decision record

Write **`stack-decision.md`** beside the stack using [templates/stack-decision.md](templates/stack-decision.md). Required keys:

| Key | Description |
| --- | --- |
| `env` | Environment segment |
| `region` | Azure region slug if used in path/name/key; empty if not |
| `location` | Azure location string (always used as stack variable) |
| `subscription_id` | Placeholder `00000000-0000-0000-0000-000000000000` — not a real secret |
| `region_in_path` | `true` / `false` |
| `region_in_name` | `true` / `false` |
| `state_key` | e.g. `tfstate.webapp.dev` or `tfstate.webapp.dev.eastus` |
| `working_directory` | Repo-relative stack root |
| `module_source` | e.g. `../../../modules/resource_group` |

Default state key: `tfstate.{resource}.{environment}`. Append `.{region}` when region-in-key is chosen.

Do **not** store storage account keys, SAS tokens, or client secrets in this file.

### Root provider

Stack `providers.tf` **must** set `resource_provider_registrations` explicitly (default `"legacy"` in template). Use `"none"` only when a platform team has pre-registered providers. **Forbidden:** `skip_provider_registration`.

### Validation

Tier 1 (no Azure credentials):

```bash
terraform fmt -check -diff resources/environments/<env>/<resource>
cd resources/environments/<env>/<resource> && terraform init -backend=false && terraform validate
```

Tier 2 (plan only — requires `az login`):

```bash
cd <working_directory>
terraform init \
  -backend-config=resource_group_name=<RG> \
  -backend-config=storage_account_name=<SA> \
  -backend-config=container_name=tfstate \
  -backend-config=key=<state_key from stack-decision.md> \
  -backend-config=use_oidc=true \
  -backend-config=use_azuread_auth=true
terraform plan -var-file=<env>.tfvars
```

Stop at plan. Do not apply or destroy.

---

## Menu 3 — New pipeline

Read [../terraform-azure-pipelines/SKILL.md](../terraform-azure-pipelines/SKILL.md) and **copy assets** from that sibling skill into the consumer repo. Do not invent YAML; do not copy older Terraform pins.

Wire CI for an existing stack. Read values from the stack's **`stack-decision.md`**:

- `working_directory` → pipeline working directory
- `state_key` → backend blob key
- `<env>.tfvars` filename → tfvars parameter

**Terraform CLI pin:** **1.15.8**.

### Azure DevOps

Copy `../terraform-azure-pipelines/assets/azure-pipelines.yaml` to `pipelines/azure_dev_ops/shared/azure-pipelines.yaml` in the consumer repo. Copy `../terraform-azure-pipelines/assets/examples/dev-azure-pipelines.yaml` as a starting wrapper under `pipelines/azure_dev_ops/<env>/`.

Parameterize from the decision record. Use placeholder names like `acme` — never real subscription IDs or keys in committed YAML.

### GitHub Actions

Copy `../terraform-azure-pipelines/assets/tf-deploy-base.yaml` to `.github/workflows/tf-deploy-base.yaml` and `../terraform-azure-pipelines/assets/terraform-stack.yaml` to `.github/workflows/terraform-stack.yaml`.

Caller workflow example:

```yaml
name: Terraform Webapp Dev

on:
  pull_request:
    paths:
      - 'resources/environments/dev/webapp/**'
  workflow_dispatch:

jobs:
  terraform:
    uses: ./.github/workflows/terraform-stack.yaml
    with:
      working_directory: resources/environments/dev/webapp
      tfvars_file: dev.tfvars
      terraform_action: plan
      environment: dev
      backend_state_key: tfstate.webapp.dev
    secrets: inherit
```

Default `terraform_action` is **plan**. Apply is opt-in only — this skill never triggers apply.

Backend storage settings come from repository/environment **variables** (`TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`), not hardcoded in workflows.

### GitLab CI

Copy `../terraform-azure-pipelines/assets/gitlab-ci-terraform-template.yml` to `.gitlab/pipelines/gitlab-ci-terraform-template.yml`. Pin image `hashicorp/terraform:1.15.8`.

Set from the decision record and CI/CD variables:

```yaml
variables:
  TF_ROOT: "resources/environments/dev/webapp"
  TFSTATE_KEY: "tfstate.webapp.dev"
```

Backend init flags must include `use_oidc=true` and `use_azuread_auth=true`. Never commit account names, keys, or subscription IDs.

### Pipeline validation

Confirm fmt, init, validate, and plan stages reference the decision-record paths. Do not run apply from this skill.

---

## Menu 4 — Bootstrap state storage

**Do not inline bootstrap logic.** Run or instruct the script in **this skill folder**:

```bash
chmod +x scripts/bootstrap-tfstate.sh
./scripts/bootstrap-tfstate.sh --help
```

```powershell
./scripts/bootstrap-tfstate.ps1 -Help
```

**Prerequisites:** `az` on PATH; `az login`; `az account set` to the target subscription.

Example (placeholders):

```bash
./scripts/bootstrap-tfstate.sh \
  --resource-group-name rg-acme-tfstate-dev \
  --location eastus \
  --storage-account-name stacmetfstatedev \
  --container-name tfstate \
  --resource webapp \
  --environment dev
```

The script creates RG, storage account, and container out of band and prints suggested `terraform init -backend-config` flags with Entra ID auth — no access keys.

Record printed values in host secrets/variables for pipelines; never commit keys or populated backend-config files.

---

## Menu 5 — Create Azure connections

**Do not reimplement OIDC setup.** Run or instruct the script in **this skill folder**:

```bash
chmod +x scripts/create-azure-oidc.sh
./scripts/create-azure-oidc.sh --help
```

```powershell
./scripts/create-azure-oidc.ps1 -Help
```

Follow the runbook: [references/azure-connections.md](references/azure-connections.md).

**Prerequisites:** `az login`; bootstrap complete when assigning state-container RBAC.

### Host summary

| Host | Script `--host` | Notes |
| --- | --- | --- |
| **GitHub Actions** | `github` | `--github-org`, `--github-repo`, `--github-environment` |
| **Azure DevOps** | `ado` | Draft ARM service connection in ADO UI first; copy **Issuer** and **Subject identifier** into `--ado-issuer` / `--ado-subject` |
| **GitLab** | `gitlab` | `--gitlab-project-path` |

Pass state container details when bootstrap exists:

```bash
./scripts/create-azure-oidc.sh --host github \
  --github-org myorg --github-repo myrepo --github-environment prod \
  --state-resource-group rg-acme-tfstate-prod \
  --state-storage-account stacmetfstateprod \
  --assign-state-role
```

Store output client/tenant/subscription IDs in the host secret store — never in git.

---

## Quick checklist

1. Ask which menu item (**1–5**).
2. **Module:** `modules/<name>/`, templates in this skill, `providers.tf`, `organization_name`, no backend.
3. **Stack:** ask env, location, subscription, region-in-path/name/key; **location is always** on stack and in every module block; write `stack-decision.md`; `source = "../../../modules/<name>"` or `"../../../../modules/<name>"`.
4. **Pipeline:** copy sibling `terraform-azure-pipelines` assets; parameterize from decision record; Terraform **1.15.8**.
5. **Bootstrap:** `scripts/bootstrap-tfstate.sh` or `.ps1` in this skill folder.
6. **Connections:** `scripts/create-azure-oidc.sh` or `.ps1` + [references/azure-connections.md](references/azure-connections.md).
7. Validate tier 1, then tier 2 (plan). **Never apply or destroy.**
