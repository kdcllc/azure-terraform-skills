# Changelog

All notable changes to this skills pack. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning policy: [VERSIONING.md](VERSIONING.md) — one pack-level semver, released as git tags `vX.Y.Z`.

Consumers: before re-adding with a new tag, read the target version's entry,
especially its **Upgrade notes**.

## [Unreleased]

## [2.0.0] - 2026-09-03

Two bodies of work: the **stack decomposition contract** (breaking) and a
**pipeline overhaul** (destroy gating, mandatory fmt, Node 24 actions).

### Changed — BREAKING: stack layout

- **Stacks are now one root module per domain.** `resources/<domain>/` holds `.tf` written
  **once**, with per-environment tfvars in `envs/<env>.tfvars` selected by `-var-file` and
  the injected backend key. The working directory is the domain folder for every
  environment.
- **`resources/environments/<env>/<resource>/` is superseded and rejected**, along with
  flat `resources/<resource>/`, `infra/resources/`, and any layout that duplicates `.tf`
  per environment. Repos built to v1.0.0 guidance are laid out the old way — see Upgrade
  notes.
- **A stack owns exactly one domain.** Mega-stacks that provision a resource group *and* a
  network *and* a key vault in one state file are rejected. Domains carry a dependency
  tier; a stack may read from lower tiers only.
- **Cross-domain reads are azurerm `data` blocks only** — never module outputs, never
  `terraform_remote_state`, never a hardcoded ID in tfvars. If azurerm publishes no data
  source for a type, its dependents belong in the same stack rather than reaching for
  `terraform_remote_state`.
- State keys take the shape `tfstate.{resource}.{domain}.{environment}`, with an optional
  `.{region}` segment.
- Resource naming (`{resource-type}-{organization_name}-{resource}-{environment}`) and the
  frozen module source (`../../modules/<name>`) are **unchanged**.

### Added — stacks

- `templates/stack/data.tf.tmpl` — the cross-domain lookup file every stack now carries.
- `stack-decision.md` per domain, recording the decomposition choice.
- `scripts/check-stack-conventions.sh`, run by `check-skill-pack.sh`, guarding the contract:
  one domain per stack, `.tf` once, per-environment tfvars, `data`-block composition only.

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

- **GitHub Actions bumped off the deprecated Node 20 runtime.** `tf-deploy-base.yaml` now
  uses `actions/checkout@v7`, `azure/login@v3`, `hashicorp/setup-terraform@v4`, and
  `actions/upload-artifact@v7` — all `node24`. Every input used is unchanged across the
  bump, so this is a drop-in replacement. `check-skill-pack.sh` rejects assets that
  reintroduce a Node 20-era major.
- Checkout now sets `persist-credentials: false`. Module sources are frozen to relative
  paths and no step pushes, so the job needs no git credential on disk. Flip it back only
  if a stack adopts a private git module source.
- `upload-artifact` now sets `if-no-files-found: error`; the default `warn` let a plan that
  produced no file upload nothing and still report success.
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

- **Existing stacks must be relaid out.** A v1.0.0 repo has
  `resources/environments/<env>/<resource>/` with `.tf` duplicated per environment. Moving
  to `resources/<domain>/` means: group resources onto domains, keep one copy of the `.tf`,
  turn the per-environment differences into `envs/<env>.tfvars`, and replace any
  cross-stack module output or `terraform_remote_state` read with an azurerm `data` block.
- **State keys move with the layout.** The new shape is
  `tfstate.{resource}.{domain}.{environment}`. A relaid-out stack points at a different
  blob than the one holding its current state — plan against the new key and confirm the
  diff is empty before applying, or migrate state deliberately. **Do not let a re-keyed
  stack plan a create-from-scratch over live infrastructure.**
- **One pipeline per domain stack.** Each domain has its own working directory and state
  key, so a single job can no longer cover several. Order runs by tier — a `data` block in
  a higher tier fails until its lower-tier stack has been applied, which is expected in a
  fresh environment, not a pipeline defect.
- **Unformatted Terraform now fails CI.** Run `terraform fmt -recursive` and commit before
  taking this version, or the first pipeline run after upgrading will fail at the format
  step.
- Consumers who copied the old `terraform-stack.yaml` should re-copy it along with
  `tf-deploy-base.yaml`; the two changed together.
- No new federated credential is needed — `tf-deploy-base.yaml` is still a single job with
  no `environment:` key, so its OIDC subject is unchanged.
- **Self-hosted runners need a runner release that ships Node 24.** GitHub-hosted runners
  already have it; an old self-hosted runner will fail to start the bumped actions rather
  than warn. Update the runner agent before taking this version.

## [1.0.0] - 2026-08-31

### Added

- First versioned release: skills `terraform-azure` (orchestrator),
  `terraform-azure-modules`, `terraform-azure-pipelines`, `terraform-azure-upgrade`.
- Pins shipped in templates and assets: azurerm `>= 5.0.0, < 6.0.0`,
  Terraform `required_version = ">= 1.9.0, < 2.0.0"`, CI Terraform CLI `1.15.8`.
- Every `SKILL.md` carries `metadata.version` matching the release tag.

### Upgrade notes

- None (first release).
