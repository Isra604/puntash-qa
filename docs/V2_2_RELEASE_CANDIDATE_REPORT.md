# PUNTASH QA v2.2.0 — Dashboard Release Candidate Report

Original creator and project architect: Ofir Israeli
Copyright © 2026 Ofir Israeli

Status: **READY_FOR_OWNER_RELEASE_APPROVAL**

## Scope completed

Dashboard v2.2.0 is the primary human operating surface for PUNTASH QA while preserving all v2.1 safety, evidence, authorization, scheduling, Terms, rollback and release invariants.

Implemented and verified: Home, SCAN NOW, live scan state, Findings/Explain/Evidence, Permissions Center, Schedule Builder, approval queue, remediation views, activity/history, health history, changes since prior scan, release readiness, Recovery Center, onboarding, Overview/Details and Ask PUNTASH navigation/search.

## Local release-gate evidence

- Windows self-test: PASS
- v2.1 regression/adversarial suites: PASS
- v2.2 portable Dashboard red-team: PASS
- v2.2 Windows-native Dashboard red-team: PASS
- Windows authorization/path/scheduler/rollback/timeout: PASS
- Portable timeout/process-tree: PASS
- v1.4 → v2.2 → rollback: PASS
- v2.0 → v2.2 → rollback: PASS
- v2.1 → v2.2 → rollback: PASS
- Clean-HEAD package self-test: PASS
- Reproducible package: PASS
- Secret scan: PASS
- Private-project isolation: PASS

## Cross-platform CI

GitHub Actions run: `33220885792`
Tested commit: `d0eeb4e7cd093227a804df8849d18b3b9a147b09`

- Windows: PASS
- Ubuntu: PASS
- macOS: PASS

All required v2.2 Dashboard steps and retained v2.1 hardening steps completed successfully.

## Publication boundary

No merge to `main`, no `v2.2.0` tag and no public GitHub Release are authorized by this report. Explicit owner release approval remains required. The final branch HEAD receives one additional CI run after this report is committed; final artifact SHA/provenance is then recorded outside the commit without changing that tested HEAD.
