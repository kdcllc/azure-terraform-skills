---
name: terraform-azure-pipelines
description: >-
  Creates Terraform CI pipelines that fmt, validate, and plan Azure
  infrastructure with GitHub Actions reusable workflow_call workflows, Azure
  DevOps templates, or GitLab CI, using OIDC and parameterized backends. Use
  when creating a pipeline, adding Terraform CI, GitHub Actions, Azure DevOps,
  plan jobs, or OIDC for azurerm state.
license: MIT
---

# Terraform Azure pipelines

Author a **fmt → validate → plan** CI path for Azure Terraform in the **consumer** repository. Default action is **plan**. Apply is **opt-in and parameterized, never the default**, on every host.

**Copy YAML from [assets/](assets/).** Do not invent a second template and do not copy older Terraform pins. The assets pin Terraform **1.15.8** and Entra backend auth (`use_oidc=true`, `use_azuread_auth=true`).

Layout freeze: [../terraform-azure/references/ai-conventions.md](../terraform-azure/references/ai-conventions.md). Search Microsoft Learn for GitHub Actions Azure login (OIDC) and Azure Pipelines Terraform tasks. Query HashiCorp Terraform docs for `fmt`, `validate`, `plan`, and `-backend-config`. Name documentation tools by **role** only.

## When to use

- Creating or updating a pipeline that runs Terraform CI for an environment stack
- Adding GitHub Actions, Azure DevOps, or (optionally) GitLab jobs that plan Azure Terraform
- Wiring OIDC to Azure so init/plan can reach remote state without inline credentials

Do not use this skill to run `terraform apply` locally, to rewrite reusable modules under `modules/`, or to embed cloud secrets in YAML.

## Stack path and backend

Environment stacks live at:

```
resources/environments/<env>/<resource>/
```

Create that directory tree if it is missing. Do not use `infra/resources/` or a flat `resources/<resource>/` layout.

Point `working_directory` / `workingDirectory` at that path. Keep `backend.tf` empty so the pipeline injects storage settings:

```hcl
terraform {
  backend "azurerm" {}
}
```

Never put resource-group names, storage-account names, access keys, SAS tokens, or subscription IDs in the Terraform. Pass backend settings at init with `-backend-config=` or host variables/secrets.

## Apply policy (all hosts)

| Rule | Portable default |
| --- | --- |
| Default `terraform_action` / `terraformAction` | `plan` |
| `terraform fmt` or `fmt -check` | Required; **must fail the job** (no `continue-on-error`) |
| `terraform validate` | Required after init |
| `terraform plan` | Required |
| `terraform apply` | Only when the caller **explicitly** asks (`apply`); gated by input/parameter/condition or a manual stage |

Do not copy an always-apply template as the portable default. Destroy, if present, is also opt-in and never default.

## Secrets

- **Never** embed ARM access keys, SAS tokens, client secrets, or subscription/tenant ID **literals** in YAML or tfvars committed to the repo.
- GitHub: `permissions.id-token: write` plus repository/environment **secrets** (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) and OIDC (`ARM_USE_OIDC`).
- Azure DevOps: pass the **service connection name as a parameter**, not a hardcoded org/project string.
- Backend location (resource group, storage account, container, state key) comes from **parameters, variables, or secrets** — never hardcoded account names in the playbook.

## GitHub Actions (`workflow_call`)

Copy these files into the consumer repo:

| Skill asset | Consumer path |
| --- | --- |
| [assets/tf-deploy-base.yaml](assets/tf-deploy-base.yaml) | `.github/workflows/tf-deploy-base.yaml` |
| [assets/terraform-stack.yaml](assets/terraform-stack.yaml) | `.github/workflows/terraform-stack.yaml` |

The reusable job uses `on: workflow_call`. A thin caller may use `pull_request` or `workflow_dispatch` and **call** `terraform-stack.yaml`. Default action is `plan`. `fmt -check` is a hard failure. Configure `TFSTATE_*` as GitHub **variables** (or secrets). Do not inline those values in the workflow file.

### Caller

```yaml
name: Terraform CI

on:
  pull_request:
  workflow_dispatch:
    inputs:
      terraform_action:
        description: Terraform action
        type: choice
        options: [plan, apply]
        default: plan

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    uses: ./.github/workflows/terraform-stack.yaml
    with:
      working_directory: resources/environments/dev/example_stack
      tfvars_file: dev.tfvars
      terraform_action: ${{ github.event.inputs.terraform_action || 'plan' }}
      backend_state_key: tfstate.example_stack.dev
      environment: dev
    secrets: inherit
```

On `pull_request`, `github.event.inputs.terraform_action` is empty — the `|| 'plan'` keeps apply off. Production apply should use a GitHub Environment with required reviewers, still only when `terraform_action == 'apply'`.

## Azure DevOps (shared template)

Copy [assets/azure-pipelines.yaml](assets/azure-pipelines.yaml) to `pipelines/azure_dev_ops/shared/azure-pipelines.yaml`. Copy [assets/examples/dev-azure-pipelines.yaml](assets/examples/dev-azure-pipelines.yaml) to `pipelines/azure_dev_ops/<env>/` and fill service-connection / state-storage **parameters at queue time**.

Parameters: service connection, state key, `workingDirectory`, `tfvarsFile`, plus backend resource group / storage / container. **No hardcoded org or project names.** TerraformInstaller pin is **1.15.8**. Apply remains in the shared template but production should use an approval gate; default caller action is plan.

### Environment pipeline (extends template)

```yaml
trigger: none

parameters:
  - name: resource
    type: string
  - name: workingDirectory
    type: string
  - name: serviceConnection
    type: string
  - name: stateResourceGroup
    type: string
  - name: stateStorageAccount
    type: string
  - name: terraformAction
    type: string
    default: plan
    values:
      - plan
      - apply

extends:
  template: /pipelines/azure_dev_ops/shared/azure-pipelines.yaml
  parameters:
    backendServiceArm: ${{ parameters.serviceConnection }}
    backendAzureRmResourceGroupName: ${{ parameters.stateResourceGroup }}
    backendAzureRmStorageAccountName: ${{ parameters.stateStorageAccount }}
    backendAzureRmContainerName: tfstate
    backendAzureRmKey: tfstate.${{ parameters.resource }}.dev
    workingDirectory: ${{ parameters.workingDirectory }}
    tfvarsFile: dev.tfvars
    terraformAction: ${{ parameters.terraformAction }}
```

## GitLab (optional third host)

If the consumer uses GitLab, copy [assets/gitlab-ci-terraform-template.yml](assets/gitlab-ci-terraform-template.yml) to `.gitlab/pipelines/gitlab-ci-terraform-template.yml`. Image is `hashicorp/terraform:1.15.8`. Parameterize `TF_ROOT` as `resources/environments/<env>/<resource>/`. Apply is manual on `main`. Do **not** add a new GitLab file unless the consumer asked for GitLab.

## Agent checklist

1. Confirm the stack path `resources/environments/<env>/<resource>/` (create if missing) and empty `backend "azurerm" {}`.
2. **Copy assets** from this skill into the consumer repo (do not rewrite YAML from memory).
3. Choose host: GitHub Actions reusable `workflow_call`, or Azure DevOps `extends` template (GitLab only if asked).
4. Wire OIDC or a service-connection **parameter**; no key/SAS/subscription literals.
5. Parameterize backend `-backend-config` / template inputs from variables or parameters.
6. Require `terraform fmt` / `fmt -check` (fail closed), `validate`, and `plan`.
7. Default action `plan`; apply only when the caller sets `apply`.
8. Do not run `terraform apply` from the agent session.
