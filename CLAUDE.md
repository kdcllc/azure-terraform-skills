This repository is **azure-terraform-skills**, a [skills.sh](https://skills.sh/) pack.

- Product skills: `skills/terraform-azure`, `skills/terraform-azure-modules`, `skills/terraform-azure-pipelines`, `skills/terraform-azure-upgrade`
- Historical source material (not installed): `_unpacked/`
- Do not add `SKILL.md` at the repository root (that path is discovered by the Skills CLI)
- Release: `bash scripts/release.sh <X.Y.Z>` bumps `metadata.version` in all four SKILL.md files, validates, commits, and tags `vX.Y.Z`; a `## [X.Y.Z]` entry must already be committed in `CHANGELOG.md`. Never hand-edit versions or tag manually — see `VERSIONING.md`.

Install: `npx skills add kdcllc/azure-terraform-skills` (pin with `#vX.Y.Z`)
