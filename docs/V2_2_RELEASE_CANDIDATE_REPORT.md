# PUNTASH QA v2.2.0 — Dashboard Release Candidate Report

Original creator and project architect: Ofir Israeli
Copyright © 2026 Ofir Israeli

Status: **READY_FOR_OWNER_RELEASE_APPROVAL**

## Scope completed

Dashboard v2.2.0 is the primary human operating surface for PUNTASH QA while preserving the v2.1 safety, evidence, authorization, scheduling, Terms, rollback and release invariants.

Implemented and locally verified: Home, SCAN NOW, live scan state, Things to review + Explain/Proof, What PUNTASH can change, Automatic scans, Your decisions, remediation views, activity/history, project health, changes since prior scan, Ready to release?, Fix PUNTASH QA, onboarding, Overview/Details and Ask PUNTASH.

## Final hardening findings closed

The previous READY state was deliberately revoked and the Dashboard was attacked again. The review found and fixed: unvalidated Home health, stale release readiness after project changes, approval TOCTOU/duplicate-ID ambiguity, Recovery scheduler false-success, cross-process Dashboard mutation races, cross-window SCAN NOW status races, excessive engineering jargon in Overview, stale endpoint documentation, and missing/incorrectly timed non-Git project freshness snapshots.

New schema-v4 runs bind `project.fingerprint` to the **final project state actually verified**, after authorized remediation and required revalidation. Git projects additionally require the scanned HEAD to match current HEAD and no uncovered working-tree changes before Ready can be shown.

## Hardened local release-gate evidence

- PowerShell self-test after final hardening: PASS
- Shell self-test after final hardening: PASS
- v2.1 regression/adversarial suites: PASS
- v2.2 portable Dashboard red-team: PASS
- v2.2 Windows-native Dashboard red-team: PASS
- v2.2 final portable adversarial suite: PASS
- v2.2 final Windows adversarial suite: PASS
- Human-usability red-team: PASS
- Real Chromium desktop/mobile smoke: PASS
- Git freshness invalidation: PASS
- Non-Git fingerprint freshness invalidation/restoration: PASS
- Python ↔ PowerShell fingerprint parity: PASS
- Windows authorization/path/scheduler/rollback/timeout: PASS
- Portable timeout/process-tree: PASS
- Verify-install on paths containing spaces, Windows + shell: PASS
- v1.4 → v2.2 → rollback: PASS
- v2.0 → v2.2 → rollback: PASS
- v2.1 → v2.2 → rollback: PASS
- Clean-HEAD package self-test: PASS
- Reproducible package: PASS
- Secret scan: PASS
- Private-project isolation: PASS

Hardened implementation commit:

```text
7b8c943fc27a1807a737f78f156d8a938c4965ca
```

Hardened implementation tree:

```text
5d47b7418f836a22d54fb4049f04304a85ed654a
```

Clean-HEAD reproducible implementation ZIP SHA-256:

```text
985848238008F11B310A310548F7D8635EDD9D0269AA6B6CE7C53F6EFDEDBAD7
```

This implementation ZIP hash is evidence for the hardened implementation commit. The final docs-only closure commit changes package bytes, so the final release-candidate ZIP is rebuilt and hashed only after the exact closure HEAD passes CI.

## Cross-platform CI

The earlier CI run `33220885792` on `d0eeb4e7cd093227a804df8849d18b3b9a147b09` remains historical pre-hardening evidence only.

The exact final closure-HEAD CI run and final ZIP SHA/provenance are intentionally recorded in the Draft PR #4 conversation **after** this report is committed. This avoids an evidence-only commit changing the very HEAD and ZIP bytes being attested. The required final jobs remain:

```text
Windows = PASS
Ubuntu  = PASS
macOS   = PASS
```

The final artifact SHA/provenance is recorded outside the commit on Draft PR #4 so the evidence does not create a self-referential package change.

## Publication boundary

No merge to `main`, no `v2.2.0` tag and no public GitHub Release are authorized by this report. Explicit owner release approval remains required after fresh CI and final artifact audit.
