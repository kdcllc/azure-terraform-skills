# AI conventions freeze

One-page layout and naming rules for agents and skills. Later skills must not re-export contradictions of these rules.

Companion: [operating-process.md](operating-process.md). Module file templates live in this skill's `templates/module/` folder.

## Environment stacks

Environment-specific Terraform lives under:

```
resources/environments/<env>/<resource>/
```

Create that directory tree when adding a new stack; do not assume it already exists on disk. This task does not create the tree — real work does.

**Rejected layout:** flat `resources/<resource>/`.

## Module library

Reusable modules stay under `modules/<name>/` with `main.tf`, `variables.tf`, `output.tf` or `outputs.tf`, and **`providers.tf`**.

| Rule | Standard | Rejected alias |
| --- | --- | --- |
| Provider versions file | `providers.tf` | `provider.tf` |

**This library standard is `providers.tf` only.** Do not create `provider.tf`.

## Resource naming

One canonical pattern (README token `{resource-type}` is the Azure abbreviation — `rg`, `kv`, `aca`, …):

```
{resource-type}-{organization_name}-{resource}-{environment}
```

Live shape:

```hcl
name = "rg-${var.organization_name}-${var.resource}-${var.environment}"
```

Do not document a second naming pattern.

**Superseded (do not use):** `kv-${environment}-${resource}` / `kv-${var.environment}-${var.resource}` — missing `organization_name` and wrong segment order.

## Backend (environment stacks)

`backend.tf` uses an empty block; the pipeline injects storage settings. No secrets or hardcoded account names in repo code:

```hcl
terraform {
  backend "azurerm" {}
}
```

## Create-time options

When adding a **new stack**, ask before creating files: environment; Azure region (`location`); subscription (current `az account` or another subscription/tenant); and whether region appears in the folder path, resource name, state key, both, or neither. **`location` is always** a stack variable and is always passed into modules.

Full menu, tooling, region-folder rules, state keys, provider registration, and `stack-decision.md` keys: [operating-process.md](operating-process.md).

## Quick checklist for agents

1. New stack → `resources/environments/<env>/<resource>/` (create if missing).
2. Provider file → `providers.tf`, never `provider.tf`.
3. Names → `{resource-type}-{organization_name}-{resource}-{environment}`.
4. Backend → empty `backend "azurerm" {}`.
