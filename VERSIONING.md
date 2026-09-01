# Versioning

This pack has **one version**. All four skills release in lockstep as an
annotated git tag `vX.Y.Z` on `master`, and the same version is mirrored into
every `skills/*/SKILL.md` frontmatter as:

```yaml
metadata:
  version: "X.Y.Z"
```

Installed skills are file copies with no git context — `metadata.version` is
how a consumer tells what they have on disk. `scripts/check-skill-pack.sh`
enforces that all four skills carry the same version and that `CHANGELOG.md`
has a matching `## [X.Y.Z]` entry.

Consumers pin with:

```bash
npx skills add kdcllc/azure-terraform-skills#vX.Y.Z
```

The Skills CLI records the ref in its lockfile and `npx skills update`
re-downloads from that ref, so pinned installs stay on their tag until the
consumer deliberately re-adds with a newer one.

## What bumps what

| Bump | When (any of) |
| --- | --- |
| **MAJOR** | azurerm major bound changes in templates/references (e.g. `>= 5.0.0, < 6.0.0` → `>= 6.0.0, < 7.0.0`); Terraform `required_version` major change; a skill is renamed or removed; a template/asset file consumers copy is renamed, removed, or changes its parameter contract; naming or layout conventions change (`{abbr}-{organization_name}-{resource}-{environment}`, `modules/`, `resources/environments/<env>/<resource>/`) in a way that invalidates repos built with prior guidance; `bootstrap-tfstate.*` / `create-azure-oidc.*` change documented arguments or behavior. |
| **MINOR** | New skill, template, asset, or reference doc; additive guidance or a new operator-menu option; Terraform CLI pin bump to a new minor line (e.g. 1.15.x → 1.16.x); azurerm lower-bound tightening within the major. |
| **PATCH** | Typos, wording clarifications, formatting; fixes to scripts or templates that change no interface; Terraform CLI patch bump (e.g. 1.15.8 → 1.15.9). |

Changes only to repo-internal files (`scripts/`, `.github/`, `docs/`, README)
ship nothing to consumers and need no release; they ride along with the next
one.

## Release checklist

1. Add a `## [X.Y.Z] - YYYY-MM-DD` entry to `CHANGELOG.md` (with
   `### Upgrade notes` if consumers must act) and commit it.
2. Run `bash scripts/release.sh X.Y.Z` — bumps `metadata.version` in all four
   `SKILL.md` files, re-validates the pack, commits the bump, and creates
   annotated tag `vX.Y.Z`. It never pushes.
3. Inspect `git show vX.Y.Z`, then push with the command the script prints
   (`git push origin master vX.Y.Z`). Pushing the tag is the publish event:
   the release workflow creates a GitHub Release from the changelog entry,
   and consumers can pin the new tag.
