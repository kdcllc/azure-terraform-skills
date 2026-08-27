# AI conventions freeze

One-page layout and naming rules for agents and skills. Later skills must not re-export contradictions of these rules.

Companion: [operating-process.md](operating-process.md). Module file templates live in this skill's `templates/module/` folder.

## Stacks: one domain per stack

**A stack owns exactly one domain.** Never author a single stack that provisions a resource group *and* a virtual network *and* a key vault *and* a container registry. That mega-stack shape is the most common failure of this pack — it couples unrelated lifecycles into one state file and one blast radius.

Terraform is written **once per domain** and reused across environments; only tfvars vary:

```
resources/<domain>/
  main.tf            # module blocks for THIS domain only
  data.tf            # lookups of resources owned by OTHER domains
  variables.tf
  providers.tf
  backend.tf
  stack-decision.md
  envs/
    dev.tfvars       # one file per environment
    prod.tfvars
```

Working directory is `resources/<domain>/`. Terraform runs there for every environment; `-var-file` and the injected backend key select the environment.

```bash
cd resources/networking
terraform plan -var-file=envs/dev.tfvars
```

**Rejected layouts:** `resources/environments/<env>/<resource>/` (superseded), flat `resources/<resource>/` with no domain meaning, `infra/resources/`, and any layout that duplicates `.tf` per environment.

## Domain catalog

Map every requested Azure resource onto exactly one domain folder before writing files. Tier is dependency order — a stack may read from lower tiers, never from equal or higher.

| Tier | Domain folder | Typical Azure resources |
| --- | --- | --- |
| 1 | `resource-group` | `azurerm_resource_group` |
| 2 | `networking` | virtual network, subnets, NSGs, private DNS zones, private endpoints |
| 2 | `identity` | user-assigned managed identities, role assignments |
| 2 | `observability` | Log Analytics workspace, Application Insights |
| 3 | `key-vaults` | key vault, key vault secrets |
| 3 | `container-registry` | container registry |
| 3 | `storage` | storage accounts, blob containers |
| 3 | `databases` | SQL, PostgreSQL, Cosmos DB |
| 4 | `container-apps` | Container Apps environment, container apps |
| 4 | `app-services` | service plans, web apps, function apps |

Operators may add rows. Agents may **not** invent a folder name when a catalog row already covers the resource, and may not merge two rows into one stack.

## Cross-stack references: data blocks only

A stack reads another domain's resources with an **azurerm `data` block**, never with module outputs, never with `terraform_remote_state`, never with a hardcoded ID pasted into tfvars.

Because naming is deterministic (see below), a downstream stack reconstructs an upstream name from the **same three variables it already declares** — no extra inputs, no state coupling:

```hcl
# resources/key-vaults/data.tf
data "azurerm_resource_group" "this" {
  name = "rg-${var.organization_name}-${var.resource}-${var.environment}"
}

data "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.organization_name}-${var.resource}-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
}
```

**No exceptions.** If azurerm publishes no data source for a resource type, its dependents belong in the **same stack** as that resource — do not reach for `terraform_remote_state` to work around the gap.

Stack `outputs.tf` is optional and for humans and pipeline logs only. It is never a cross-stack contract.

## Module library

Reusable modules stay under `modules/<snake_name>/` with `main.tf`, `variables.tf`, `output.tf` or `outputs.tf`, and **`providers.tf`**.

| Rule | Standard | Rejected alias |
| --- | --- | --- |
| Provider versions file | `providers.tf` | `provider.tf` |

**This library standard is `providers.tf` only.** Do not create `provider.tf`.

### Module source depth (frozen — one row)

Every stack sits at `resources/<domain>/`, so the depth never varies:

```hcl
source = "../../modules/<name>"
```

## Resource naming

One canonical pattern (README token `{resource-type}` is the Azure abbreviation — `rg`, `kv`, `aca`, …):

```
{resource-type}-{organization_name}-{resource}-{environment}
```

Live shape:

```hcl
name = "rg-${var.organization_name}-${var.resource}-${var.environment}"
```

`var.resource` is the **workload** (`webapp`, `chat`) and stays identical across every domain stack for that workload. The domain lives in the folder and the state key, **never** in the resource name — `kv-acme-webapp-dev`, not `kv-acme-key-vaults-dev`.

Holding `resource` constant is what makes the data-block rule work: every stack can derive every other stack's names.

Do not document a second naming pattern.

**Superseded (do not use):** `kv-${environment}-${resource}` / `kv-${var.environment}-${var.resource}` — missing `organization_name` and wrong segment order.

## State keys

One state file per stack per environment:

```
tfstate.{resource}.{domain}.{environment}
```

Example: `tfstate.webapp.networking.dev`. Append `.{region}` when region-in-key is chosen.

## Backend (stacks)

`backend.tf` uses an empty block; the pipeline injects storage settings. No secrets or hardcoded account names in repo code:

```hcl
terraform {
  backend "azurerm" {}
}
```

## Create-time options

When adding a **new stack**, ask before creating files: which domains are in scope; environments; Azure region (`location`); subscription (current `az account` or another subscription/tenant); and whether region appears in the tfvars filename, resource name, state key, several, or none. **`location` is always** a stack variable and is always passed into modules.

Full menu, tooling, region rules, provider registration, and `stack-decision.md` keys: [operating-process.md](operating-process.md).

## Quick checklist for agents

1. Map requested resources onto the **domain catalog** — one stack per domain, never a mega-stack.
2. New stack → `resources/<domain>/` with `.tf` once and one `envs/<env>.tfvars` per environment.
3. Cross-domain reads → azurerm `data` blocks only; no `terraform_remote_state`, no cross-stack module outputs.
4. Module source → `../../modules/<name>`.
5. Provider file → `providers.tf`, never `provider.tf`.
6. Names → `{resource-type}-{organization_name}-{resource}-{environment}`, `resource` = workload.
7. State key → `tfstate.{resource}.{domain}.{environment}`.
8. Backend → empty `backend "azurerm" {}`.
