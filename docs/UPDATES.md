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

For v2.1, the updater also validates the 9 reliability lenses and Control Center/owner-policy assets. OWNER_POLICY, policy history, QA history/evidence and other state remain preserved. If a rollback is requested after scheduling has been enabled, the current local scheduled task is paused/removed before restoring the older managed runtime so an OS task cannot continue invoking tools that no longer exist.

`tools/rollback.ps1` can restore the managed runtime from the most recent update backup while preserving reports, evidence and owner-policy history created later. Scheduled execution is intentionally left paused after rollback until the owner reviews/reactivates it.

## Public update channel

The GitHub repository is public. Update checks and release downloads use GitHub's public API and public release assets without requiring repository access or GitHub authentication. GitHub CLI remains optional when present.

## Release process

The repository workflow `.github/workflows/release.yml` runs when a version tag such as `v1.2.0` is pushed. It verifies that the tag matches `VERSION`, builds the ZIP, emits SHA-256 and `release-manifest.json`, and creates the GitHub Release.

## v2.0.0 to v2.1.0 compatibility

The already-released v2.0.0 updater manages `templates/` and `tools/` recursively but does not know about new top-level config/prompt paths. v2.1 therefore carries compatibility copies of its permission policy and scheduled-run prompt inside those already-managed trees. The v2.1 tools resolve the canonical path first and the compatibility copy second. This allows a direct v2.0.0 -> v2.1.0 update without a bridge release.

Terms change from 1.0.0 to 1.1.0 in v2.1. The released v2.0 updater already contains renewed-Terms clickwrap behavior, so it must obtain fresh human acceptance before applying v2.1.
