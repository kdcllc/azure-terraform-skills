# Terraform Azure operating process

Human operators and the `/terraform-azure` skill share this contract. Later tasks, skills, and agents must not invent a second layout, require Azure Developer CLI, or skip ask-at-create-time questions.

**Layout freeze:** [ai-conventions.md](ai-conventions.md)

## Workstation tools

| Tool | Required | Notes |
| --- | --- | --- |
| **Azure CLI (`az`)** | Yes | Only Azure command-line this toolkit requires. Authenticate with `az login`; select subscription with `az account set`. |
| **Terraform 1.15.x** | Yes | CI pins the same line. Match library provider bounds (`azurerm` `>= 5.0.0, < 6.0.0`). |
| **Git** | Yes | Version control for modules, stacks, and pipelines. |
| **bash** or **PowerShell 7** | Yes | Run bootstrap scripts and local validation. |
| **`gh`** | Optional | GitHub Actions workflows and OIDC setup. |
| **`az devops`** | Optional | Azure DevOps pipelines and service connections. |
| **GitLab CLI (`glab`)** | Optional | GitLab CI when that host is used. |

**Azure CLI (`az`) only.** Do **not** use Azure Developer CLI (`azd`) for bootstrap, provisioning, pipelines, skills, or developer setup. `azd` must not appear as a dependency, example command, or menu item.

## `/terraform-azure` menu

The skill exposes five entry points. Each follows this document and the validation ladder below.

| Menu item | Delivers | Primary path |
| --- | --- | --- |
| **New module (interface)** | Reusable library module | `modules/<name>/` |
| **New stack (class)** | Environment root consuming a module | `resources/environments/<env>/<resource>/` |
| **New pipeline** | CI for fmt / validate / plan / apply | Azure DevOps, GitHub Actions, or GitLab CI templates |
| **Bootstrap state storage** | One-shot out-of-band state RG + storage + container | Checked-in `az` / PowerShell scripts (not Terraform-managed) |
| **Create Azure connections** | Service connections / OIDC for CI | Host-specific (`az devops`, `gh`, GitLab variables) |

Skills and agents may run menu flows through **tier 2 (plan)** only. They never run `terraform apply` or `terraform destroy`.

## Interface vs class

| Term | Meaning | Location |
| --- | --- | --- |
| **Interface (module)** | Reusable Terraform module for one primary Azure resource type | `modules/<name>/` |
| **Class (stack)** | Environment-specific root module that consumes library modules via relative `source` | `resources/environments/...` |

### Interface files (`modules/<name>/`)

Every library module includes:

- `main.tf` — resource definitions
- `variables.tf` — inputs (`organization_name`, `resource`, `environment`, `location`, …)
- `output.tf` or `outputs.tf` — IDs and names for composition
- `providers.tf` — bounded `required_providers` (not `provider.tf`)

Library modules do **not** declare a backend.

### Class files (environment stack)

Every stack includes at minimum:

- `main.tf` — `module` blocks with relative `source`
- `variables.tf` — stack inputs including **`location`**
- `providers.tf` — root `provider "azurerm"` with explicit `resource_provider_registrations`
- `backend.tf` — empty `backend "azurerm" {}` (pipeline or CLI injects settings)
- `<env>.tfvars` — environment values (optional but typical)

## Stack layout (canonical path)

**Default (canonical):**

```
resources/environments/<env>/<resource>/
```

**Optional region folder** (opt-in extension only — still under `resources/environments/`):

```
resources/environments/<env>/<region>/<resource>/
```

**Rejected:** flat `resources/<resource>/`. Do not create or document that layout.

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

## Ask at create time

When creating a **new stack (class)**, the operator or `/terraform-azure` skill **must ask** before writing files:

1. **Environment** — e.g. `dev`, `test`, `prod` (folder segment `<env>`).
2. **Azure region (location)** — e.g. `eastus`, `westeurope` (Azure location string).
3. **Subscription** — current `az account show` subscription, or another subscription/tenant ID the stack will target.
4. **Region in layout** — whether `<region>` appears in the folder path, in the resource name/state key, both, or neither.

**location is always** a stack variable (`variables.tf`) and **is always** passed into every module block, even when region is neither in the folder path nor in the resource name. Modules never infer region from path alone.

Record answers in **`stack-decision.md`** beside the stack (see below).

## Naming and state keys

Default Azure resource name pattern:

```
{resource-type}-{organization_name}-{resource}-{environment}
```

`{resource-type}` is the Azure CAF abbreviation (`rg`, `kv`, `aca`, …). Example: `rg-acme-webapp-dev`.

If the operator chooses **region-in-name**, append `-{region}` as an **allowed suffix of the same pattern** (Azure-legal, lowercase), e.g. `rg-acme-webapp-dev-eastus`. This is not a second naming scheme.

Default remote state blob key:

```
tfstate.{resource}.{environment}
```

If **region-in-key** is chosen, append `.{region}`: `tfstate.webapp.dev.eastus`.

One state file per stack (one blob key per working directory).

## Root provider: `resource_provider_registrations`

Environment-stack `provider "azurerm"` **must** set `resource_provider_registrations` explicitly. On azurerm 5.x, provider registration no longer happens implicitly.

- **Templates / first-time stacks:** default to `"legacy"` so a non-expert first `plan` behaves like azurerm 4.x.
- **Production / pre-registered subscriptions:** use `"none"` when a platform team has already registered required resource providers.

**Forbidden:** `skip_provider_registration` (removed in azurerm 5.x).

```hcl
provider "azurerm" {
  features {}

  resource_provider_registrations = "legacy" # or "none" when RPs are pre-registered
}
```

## Stack decision record

Each new stack includes **`stack-decision.md`** in its working directory. Required keys (YAML front matter or equivalent structured block):

| Key | Description |
| --- | --- |
| `env` | Environment segment (`dev`, `prod`, …) |
| `region` | Azure region slug if used in path/name/key; empty if not |
| `location` | Azure location string always used as stack variable |
| `subscription_id` | Target subscription GUID — use placeholder `00000000-0000-0000-0000-000000000000`, not a real secret |
| `region_in_path` | `true` / `false` — `resources/environments/<env>/<region>/<resource>/` |
| `region_in_name` | `true` / `false` — `-{region}` suffix on resource names |
| `state_key` | Blob key, e.g. `tfstate.webapp.dev` or `tfstate.webapp.dev.eastus` |
| `working_directory` | Repo-relative path to the stack root |
| `module_source` | Relative path to consumed module, e.g. `../../../modules/resource_group` |

Do **not** store storage account keys, SAS tokens, or client secrets in this file.

Example:

```yaml
---
env: dev
region: eastus
location: eastus
subscription_id: "00000000-0000-0000-0000-000000000000"
region_in_path: false
region_in_name: false
state_key: tfstate.webapp.dev
working_directory: resources/environments/dev/webapp
module_source: ../../../modules/resource_group
---
# Stack decision record — human-readable notes optional below.
```

## Validation ladder

Run checks in order. Stop on first failure.

| Tier | Who | Commands / scope |
| --- | --- | --- |
| **1 — Offline** | Humans, skills, CI | `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`, `terraform test` with `mock_provider` when tests exist. Optional static scan (TFLint / Trivy / Checkov). No Azure credentials required. |
| **2 — Plan** | Humans, skills, CI | `terraform init` with injected backend config, then `terraform plan`. Requires authenticated Azure access. On azurerm 5.x, optional enhanced / preflight validation at plan time. |
| **3 — Apply** | Humans or gated CI only | `terraform apply` behind manual approval. **Skills and unattended agents never apply or destroy.** |

Portable skills and `/terraform-azure` stop at tier 2.

### Library check (consumer modules)

In the consumer repository, run tier 1 on each module or stack you just authored (`terraform fmt -check`, `terraform init -backend=false`, `terraform validate`). No Azure credentials, `az`, or `azd` are involved. Include this check in tier 1 before tier 2.

## Backend (reminder)

Stacks use an empty backend block; pipelines inject storage settings at init:

```hcl
terraform {
  backend "azurerm" {}
}
```

Bootstrap the state storage account **out of band** with Azure CLI (`az`) — see **Bootstrap state storage** menu item. Never commit real account names, keys, or populated backend-config files.

## Quick checklist

1. Pick a menu item (module, stack, pipeline, bootstrap, connections).
2. For stacks: ask environment, location, subscription, and region-in-path/name/key choices; write `stack-decision.md`.
3. Use canonical path `resources/environments/<env>/<resource>/` unless region folder was chosen.
4. Set `source = "../../../modules/<name>"` (or `../../../../modules/<name>` for region folder).
5. Declare `location` on the stack and pass it into every module.
6. Set `resource_provider_registrations` on root `provider "azurerm"`.
7. Run tier 1, then tier 2; leave tier 3 to humans or approved CI.
