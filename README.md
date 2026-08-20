# azure-terraform-skills

[![skills.sh](https://skills.sh/b/kdcllc/azure-terraform-skills)](https://skills.sh/kdcllc/azure-terraform-skills)

Installable [Agent Skills](https://skills.sh/) that teach an agent how to create well-defined Azure Terraform **modules**, **environment stacks**, and **CI pipelines** in a *consumer* repository — and how to **upgrade existing modules** to bounded azurerm 5.x. This repo is the pack, not a module library.

Install:

```bash
npx skills add kdcllc/azure-terraform-skills
```

Install one skill:

```bash
npx skills add kdcllc/azure-terraform-skills --skill terraform-azure
```

There is no separate publish command. When this git remote is reachable, `npx skills add` is the channel ([skills.sh docs](https://skills.sh/docs), [Skills CLI](https://github.com/vercel-labs/skills)).

## Skills

| Skill | Use when |
| --- | --- |
| **terraform-azure** | Operator menu: new module, stack, pipeline, state bootstrap, Azure OIDC, or upgrade existing modules. Azure CLI only; stop at `terraform plan`. |
| **terraform-azure-modules** | Create or update one reusable module under `modules/<name>/` (`providers.tf`, `organization_name` naming). |
| **terraform-azure-pipelines** | Copy GitHub Actions, Azure DevOps, or GitLab templates that `fmt` / `validate` / `plan` (apply is opt-in). |
| **terraform-azure-upgrade** | Inventory existing modules, bump bounded azurerm 5.x pins, apply **current** HashiCorp schema docs, stop at validate. |

Each skill folder is self-contained (`SKILL.md` plus `templates/`, `scripts/`, `references/`, or `assets/` as needed). After install, the agent copies those files into the consumer repo.

## What the agent creates (in the consumer repo)

- Modules: `modules/<name>/`
- Stacks: `resources/environments/<env>/<resource>/` (optional region folder)
- Pipelines: `.github/workflows/`, `pipelines/azure_dev_ops/`, or `.gitlab/pipelines/`

Naming: `{resource-type}-{organization_name}-{resource}-{environment}` (example: `rg-acme-webapp-dev`). Provider file is **`providers.tf`**. Stacks use an empty `backend "azurerm" {}`; pipelines inject state settings.

## Scripts (safety)

`skills/terraform-azure/scripts/` run **Azure CLI (`az`)** only:

- `bootstrap-tfstate.sh` / `.ps1` — create state resource group, storage account, and container (not Terraform-managed)
- `create-azure-oidc.sh` / `.ps1` — Entra app + federated credential for GitHub, Azure DevOps, or GitLab

They never run `azd`, `terraform apply`, or `terraform destroy`. Read them before executing. Do not commit secrets, storage keys, or populated backend-config files.

## Layout

```
skills/
  terraform-azure/
  terraform-azure-modules/
  terraform-azure-pipelines/
  terraform-azure-upgrade/
scripts/check-skill-pack.sh
_unpacked/                    # historical source material; not installed
```

The Skills CLI discovers `SKILL.md` under `skills/` (recommended) and other repo-root agent paths. Product skills live only in `skills/`. `_unpacked/` holds the previous module library, host pipelines, orchestration kit, and Copilot overlay so they are not packaged.

## Validate this pack

```bash
bash scripts/check-skill-pack.sh
```

List what the CLI would install (must be the four product skills only):

```bash
npx skills add . --list
```

## License

MIT. See [LICENSE](LICENSE).

## Deep dive

End-to-end consumer walkthroughs: [docs/deep-dive.md](docs/deep-dive.md) (minimal resource-group stack, Microsoft Foundry + Container Apps chat, then upgrading existing modules).
