# Updates and Releases

The installed QA runtime can check GitHub Releases for a newer stable version.

## User experience

On Windows, `tools/check-update.ps1` checks the latest release. When a newer version exists and an interactive desktop is available, the user receives an update prompt. Choosing **Yes** starts the updater.

The updater:
1. downloads the release manifest and ZIP;
2. verifies SHA-256 before extraction;
3. validates that the package contains all 25 gate files;
4. requires manual human approval;
5. requires renewed clickwrap acceptance if the Terms version changed;
6. creates a full backup of `.comprehensive-qa` outside the installed runtime;
7. updates only managed QA runtime files;
8. preserves profile, reports, evidence, artifacts, remediation, dispositions and state;
9. validates the new runtime;
10. restores managed files from backup if validation fails.

`tools/rollback.ps1` can restore the managed runtime from the most recent update backup while preserving reports and evidence created later.

## Private development channel

While the GitHub repository is private, update checks/downloads require GitHub authentication with access to `Isra604/comprehensive-qa-gate-system`. This is intentional during private development. When the repository becomes public, the same Windows update checker can use GitHub's public API without authentication.

## Release process

The repository workflow `.github/workflows/release.yml` runs when a version tag such as `v1.2.0` is pushed. It verifies that the tag matches `VERSION`, builds the ZIP, emits SHA-256 and `release-manifest.json`, and creates the GitHub Release.
