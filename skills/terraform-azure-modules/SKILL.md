---
name: terraform-azure-modules
description: >-
  Creates or updates a reusable Azure Terraform module under modules/<name>/
  using azurerm, providers.tf, and canonical naming with organization_name.
  Use when asked to create module folders, author or change an Azure Terraform
  module, apply Azure resource naming, or wrap an azurerm resource as a library
  module.
license: MIT
---

# Terraform Azure modules

Playbook for **one reusable module** under `modules/<snake_name>/` in the **consumer** repository. This skill does **not** author environment stacks, CI pipelines, or live Azure changes.

## Read on demand

Load these only when needed (do not paste them into this playbook):

- [reference.md](reference.md) — Azure resource abbreviation table, file templates, and name character-set exceptions.
- [../terraform-azure/references/ai-conventions.md](../terraform-azure/references/ai-conventions.md) — layout freeze (`providers.tf`, naming, env-stack paths).
- [../terraform-azure/templates/module/](../terraform-azure/templates/module/) — copy these templates into the consumer module folder.

Environment stacks (`resources/environments/<env>/<resource>/`) are a different workflow — use the sibling `terraform-azure` skill (menu 2).

## When to use

- Create a new library module for an Azure resource type that is not already under `modules/`.
- Update an existing library module in place (do **not** duplicate it).
- Apply or correct Azure resource **naming** on a module.

Do **not** use this skill to bulk-rewrite a consumer’s `modules/` tree.

## Tools (by role)

Name documentation tools by **role**, never by host-specific IDs:

- **Query current azurerm provider docs** for the resource schema, arguments, and current provider behavior.
- **Search Microsoft Learn** for Azure resource abbreviations, naming limits, and service constraints.

If those roles are unavailable, use the HashiCorp Registry azurerm docs and Microsoft Learn in the browser. Do not invent editor-specific tool names.

## Steps

### 1. Reuse first

List `modules/` in the consumer repo. If a sibling already covers the resource, **update that module**. Compose with `source =` relative paths (for example `../../modules/key_vault`). Never re-implement a resource that already has a module.

### 2. Name the folder

Create `modules/<snake_name>/` using snake_case (`key_vault`, `resource_group`). One primary Azure resource type per module.

### 3. Files

Copy from [../terraform-azure/templates/module/](../terraform-azure/templates/module/) and match siblings in the consumer repo. Required files:

| File | Role |
| --- | --- |
| `main.tf` | Resource definitions |
| `variables.tf` | Inputs |
| `output.tf` **or** `outputs.tf` | Outputs — match siblings |
| `providers.tf` | Terraform + provider versions (**never** `provider.tf`) |

Reusable modules do **not** need `backend.tf`. That file belongs to environment stacks.

Templates also live in [reference.md](reference.md).

### 4. Research the resource

Before writing HCL:

1. Query current azurerm provider docs for the resource type.
2. Search Microsoft Learn if abbreviations or name length/charset rules are unclear.
3. Read [reference.md](reference.md) for the abbreviation used in the resource name and output.

Prefer **azurerm**. Use **azapi** only when azurerm cannot represent the resource; add a comment on the `azapi` block explaining why.

### 5. Naming

Canonical pattern (one pattern only):

```
{abbr}-{organization_name}-{resource}-{environment}
```

Live shape:

```hcl
name = "rg-${var.organization_name}-${var.resource}-${var.environment}"
name = "kv-${var.organization_name}-${var.resource}-${var.environment}"
```

`organization_name` is a **required** variable (no default). Also require `resource` and `environment` unless a sibling of the same type omits them.

**Forbidden (superseded):** `kv-${environment}-${resource}` and `kv-${var.environment}-${var.resource}` — missing `organization_name` and wrong segment order. Do not emit that pattern.

If Azure rejects hyphens or the name length, see the character-set exceptions in [reference.md](reference.md). Still include organization, resource, and environment; do not revert to the superseded pattern.

### 6. Providers

Pin:

```hcl
azurerm = {
  source  = "hashicorp/azurerm"
  version = ">= 5.0.0, < 6.0.0"
}

required_version = ">= 1.9.0, < 2.0.0"
```

Match that constraint unless the target repository already uses a stricter floor inside 5.x. Include `provider "azurerm" { features {} }` in `providers.tf`. Do **not** set `resource_provider_registrations` on library modules.

### 7. Variables, outputs, secrets

- Parameterize configurable values. Do **not** hardcode secrets, subscription IDs, tenant IDs, or access keys.
- Mark secret inputs `sensitive = true`.
- Prefer Microsoft abbreviations as output names (`kv`, `rg`, `ca`) when siblings do; otherwise match the sibling’s output style.
- Place `source` first in any `module` block that composes another library module.

### 8. Format and validate (never apply)

From `modules/<snake_name>/`:

```bash
terraform fmt
terraform init -backend=false && terraform validate
```

Stop there. **Never apply** and never destroy. Do not mutate live Azure from this skill.

## Checklist

- [ ] Folder is `modules/<snake_name>/` with `main.tf`, `variables.tf`, `output.tf` or `outputs.tf`, and `providers.tf`
- [ ] Name is `{abbr}-${var.organization_name}-${var.resource}-${var.environment}`
- [ ] `organization_name` is required; superseded `kv-${environment}-${resource}` is absent
- [ ] Provider is azurerm (or azapi with a why-comment); version `>= 5.0.0, < 6.0.0`
- [ ] No hardcoded secrets, subscription IDs, or access keys
- [ ] `terraform fmt` and `terraform init -backend=false && terraform validate` succeeded in the module dir
