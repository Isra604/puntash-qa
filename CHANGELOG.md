# Changelog

## 2.1.0 - RELEASE CANDIDATE / NOT YET PUBLIC

- Added explicit owner-controlled remediation presets: REPORT_ONLY, SAFE_FIXES and ACTIVE_REMEDIATION.
- Added a mechanical `authorize-change` decision engine required before automatic product mutation.
- Added immutable hard boundaries so agents cannot self-authorize high-impact/protected categories.
- Added persistent owner-policy audit history and blocked agent self-elevation.
- Added opt-in Scheduled QA with Windows Task Scheduler, Unix cron, and AGENT_MANAGED platform mode.
- Added overlap locks, timeout/status records and local scheduler logs.
- Scheduled runs now revalidate the current human Terms receipt and human-approved owner policy on every invocation.
- Added local Dashboard Control Center for permission/schedule configuration with loopback-only binding and per-session tokens.
- Restricted unauthenticated dashboard serving to dashboard assets only; report access is token-authenticated and constrained to the local reports tree.
- Added cross-platform direct-upgrade compatibility from v2.0.0 without a bridge release.
- Added safe rollback behavior that preserves owner policy/history while pausing scheduled execution.
- Added Windows/native and portable Control Center red-team coverage, executor injection/secret checks, receipt/policy tamper checks and traversal tests.
- Updated Terms/Data Responsibility/Human Acceptance notices to version 1.1.0 for scheduled execution and persistent remediation authority.

## 2.0.0 - 2026-08-27

- Added 9 mandatory cross-cutting reliability lenses while preserving exactly 25 canonical gates.
- Added evidence assurance levels and PASS ceilings to prevent false confidence from weak evidence.
- Added Test Trustworthiness rules for oracle quality, flakiness, isolation, mocks, test data and defect sensitivity.
- Deepened privacy/data lifecycle, compatibility/upgrades, time/locale/precision, third-party failure, resource/cost, AI risk, accessibility and blast-radius QA.
- Added v2 reporting/dashboard history for lens status and assurance.
- Preserved v1.4 updater compatibility by packaging v2 lens/policy files under the already-managed `gates/` tree.
- Added structured-run validators that require exactly 25 gates + 9 lenses and reject stale/missing evidence PASS states.
- Added current evidence-reference requirements for PASS/FAIL and applicability-evidence requirements for NOT_APPLICABLE.
- Added machine-readable core gate/lens contradiction rules and overall-assurance anti-overstatement checks.
- Added permanent false-PASS red-team and v1.4 -> v2 -> rollback preservation tests to CI/release gates.
- Fixed rollback/update-failure managed-tool residue by atomically replacing the managed tools directory.

## 1.4.0 - 2026-08-26

- Added a local-first visual QA Dashboard with calm responsive light/dark themes.
- Added persistent structured run history and run selector.
- Added QA Health and separate execution coverage metrics to avoid misleading confidence.
- Added prioritized attention view, 25-gate status map, finding filters and gate details.
- Added run-to-run change summaries, resolved/new finding tracking and health trend.
- Added Windows one-click dashboard launcher plus Windows/Unix refresh tools.
- Dashboard remains local with no telemetry, cloud account or project-data upload.

## 1.3.0 - 2026-08-26

- Added Easy Start Windows folder-picker launcher.
- Added cross-platform QA Doctor readiness reports.
- Added installed START HERE and agent-specific quick guides.
- Added deterministic self-tests and Windows/Linux/macOS GitHub Actions QA.
- Added durable product roadmap for v1.4 dashboard and deferred opt-in telemetry.
- Updated release workflow baseline for self-tested releases.
- Made legal-document SHA-256 validation deterministic across operating systems.


## 1.2.1 - 2026-08-26

- Switched the official update channel from private to public GitHub Releases.
- Public update checks and release downloads no longer require GitHub authentication.
- Performed pre-publication secret/history review and privacy hardening.

## 1.2.0 - 2026-08-26

- Added private GitHub Releases development channel.
- Added interactive Windows update notification, updater and rollback tools.
- Added release-manifest and SHA-256 verification.
- Added full pre-update backup and preservation of QA reports/evidence/profile/state.
- Added renewed human Terms acceptance when Terms version changes.
- Added GitHub Actions tag-based release packaging.

## 1.1.0 — 2026-08-26

- Added mandatory human acceptance before installation.
- Added Windows interactive clickwrap GUI with three attestations, exact `I ACCEPT` phrase, and manual `Accept & Install` click.
- Added non-interactive refusal and manual acceptance workflow for macOS/Linux shell installation.
- Added `TERMS_OF_USE.md`, `DISCLAIMER.md`, `DATA_RESPONSIBILITY_NOTICE.md`, and `HUMAN_ACCEPTANCE.md`.
- Added local `HUMAN_ACCEPTANCE_RECEIPT.json` with Terms version and SHA-256 document hashes.
- Added `LEGAL_MANIFEST.json` for package-level legal-document integrity.
- Added agent precondition: AI/automation may not accept terms or fabricate the receipt on a human's behalf.
- Preserved MIT licensing, creator attribution, and first-run attribution notice.

## 1.0.1 — 2026-08-26

- Added creator attribution, MIT license, NOTICE, CREDITS, and first-run attribution.

## 1.0.0 — 2026-08-26

- Initial portable Universal Comprehensive 25-Gate QA system.
