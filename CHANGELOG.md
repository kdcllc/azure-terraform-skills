# Changelog

All notable changes to this skills pack. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning policy: [VERSIONING.md](VERSIONING.md) — one pack-level semver, released as git tags `vX.Y.Z`.

Consumers: before re-adding with a new tag, read the target version's entry,
especially its **Upgrade notes**.

## [Unreleased]

## [1.0.0] - 2026-08-31

### Added

- First versioned release: skills `terraform-azure` (orchestrator),
  `terraform-azure-modules`, `terraform-azure-pipelines`, `terraform-azure-upgrade`.
- Pins shipped in templates and assets: azurerm `>= 5.0.0, < 6.0.0`,
  Terraform `required_version = ">= 1.9.0, < 2.0.0"`, CI Terraform CLI `1.15.8`.
- Every `SKILL.md` carries `metadata.version` matching the release tag.

### Upgrade notes

- None (first release).
