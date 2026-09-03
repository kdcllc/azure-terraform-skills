# Changelog

All notable changes to this skills pack. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning policy: [VERSIONING.md](VERSIONING.md) — one pack-level semver, released as git tags `vX.Y.Z`.

Consumers: before re-adding with a new tag, read the target version's entry,
especially its **Upgrade notes**.

## [Unreleased]

### Added

- `terraform-azure-pipelines`: **destroy is now a standard action on every host**, offered
  in the action dropdown and gated by a confirmation input separate from the action itself
  (`confirm_destroy` / `confirmDestroy` / `CONFIRM_DESTROY=DESTROY`). Picking `destroy`
  alone fails the run before checkout or any credential is used. A destroy run plans with
  `-destroy -out=…` and applies that saved plan, so the log shows exactly what was removed.
- `assets/examples/terraform-domain.yaml`: per-domain GitHub Actions caller. The default
  GitHub layout is now one `terraform-<domain>.yaml` per stack over one shared
  `tf-deploy-base.yaml`.
- Azure DevOps: `terraformAction` (`plan` | `apply` | `destroy`) and `confirmDestroy`
  parameters; the plan is saved with `-out=tfplan` and the execute step applies that file
  instead of re-planning.

### Changed

- **`terraform fmt -check -recursive` now fails the job on every host.** `tf-deploy-base.yaml`
  loses its `continue-on-error: true`, and the Azure DevOps template gains a format step it
  never had. `check-skill-pack.sh` enforces this: an asset without the step, or carrying
  `continue-on-error: true` / `allow_failure: true`, fails validation.

### Fixed

- `tf-deploy-base.yaml`: the job summary reported `Plan step was skipped` on every run —
  `steps.plan.outputs.exit_code` was read but never written. Plan now runs with
  `-detailed-exitcode` and publishes `exit_code` / `has_changes`; apply and destroy are
  skipped when there are no changes.
- `terraform-stack.yaml` read dispatch values through `github.event.inputs`, which returns
  the string `"false"` for an unticked checkbox — truthy, and it would have defeated the
  destroy confirmation. All inputs now read from the `inputs` context, which is populated
  for both `workflow_call` and `workflow_dispatch`.
- `assets/examples/dev-azure-pipelines.yaml` passed `tfvarsFile: <env>/<env>.tfvars`,
  contradicting the frozen `envs/<env>.tfvars` layout.

### Upgrade notes

- **Unformatted Terraform now fails CI.** Run `terraform fmt -recursive` and commit before
  taking this version, or the first pipeline run after upgrading will fail at the format
  step.
- Consumers who copied the old `terraform-stack.yaml` should re-copy it along with
  `tf-deploy-base.yaml`; the two changed together.
- No new federated credential is needed — `tf-deploy-base.yaml` is still a single job with
  no `environment:` key, so its OIDC subject is unchanged.

## [1.0.0] - 2026-08-31

### Added

- First versioned release: skills `terraform-azure` (orchestrator),
  `terraform-azure-modules`, `terraform-azure-pipelines`, `terraform-azure-upgrade`.
- Pins shipped in templates and assets: azurerm `>= 5.0.0, < 6.0.0`,
  Terraform `required_version = ">= 1.9.0, < 2.0.0"`, CI Terraform CLI `1.15.8`.
- Every `SKILL.md` carries `metadata.version` matching the release tag.

### Upgrade notes

- None (first release).
