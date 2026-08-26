# v2.0.0 Reliability & Professional QA Architecture

Status: IN PROGRESS
Target release: v2.0.0
Started: 2026-08-26
Owner / original creator and project architect: Ofir Israeli

## Purpose

v2.0.0 strengthens the existing 25-gate model without inflating it into dozens of overlapping gates. The canonical 25 gates remain the responsibility domains. A new mandatory cross-cutting reliability layer ensures important concerns cannot be hidden inside a broad gate and accidentally receive shallow coverage.

## Non-negotiable design rules

- Keep exactly 25 canonical gates.
- Add 9 cross-cutting QA lenses with explicit applicability and evidence.
- A relevant lens may never disappear merely because a related gate exists.
- Missing capability/evidence never becomes PASS.
- Test results used as decisive PASS evidence must themselves be trustworthy enough for that conclusion.
- Coverage percentage alone is never proof of behavioral correctness.
- AI-specific QA is conditional on discovered AI/ML/LLM behavior; it is not forced onto irrelevant projects.
- Preserve reports, evidence, history and dashboard records across updates.
- No telemetry is added in v2.0.0.
- All completed implementation phases must be recorded here and in Git before continuing.

## Canonical cross-cutting lenses

1. LENS-01 Test Trustworthiness & Oracle Integrity
2. LENS-02 Privacy & Data Lifecycle
3. LENS-03 Compatibility, Migration & Upgrade Safety
4. LENS-04 Time, Locale, Precision & Encoding
5. LENS-05 Third-Party Failure, Quota & Dependency Reality
6. LENS-06 Resource, Capacity & Cost Exhaustion
7. LENS-07 AI Quality, Model Risk & Non-Determinism
8. LENS-08 Accessibility Depth & Assistive Interaction
9. LENS-09 Change Impact, Dependency Reach & Blast Radius

## Evidence assurance model

Every material gate/lens conclusion will classify current evidence as:

- STRONG — current, direct, reproducible evidence adequate for the conclusion.
- MODERATE — useful direct evidence with bounded gaps; PASS only where the missing depth is not material.
- WEAK — partial/indirect/stale/heuristic evidence; cannot support a material PASS by itself.
- INSUFFICIENT — no adequate evidence; relevant status must be BLOCKED or NOT_RUN rather than PASS.

## Implementation phases

### Phase 0 — Durable control plane
Status: COMPLETE
- Create dedicated `feature/v2-reliability` branch.
- Create this durable implementation file.
- Create machine/human readable checkpoint state.
- Define phase completion rules.

### Phase 1 — Reliability architecture
Status: COMPLETE
- Add 9 authoritative lens specifications.
- Add lens applicability/mapping configuration.
- Add evidence-assurance rules and templates.
- Add lens finding identity rules.
- Add project-profile lens discovery fields.

### Phase 2 — Deepen the 25 gates
Status: COMPLETE
- Strengthen gates that own or consume lens evidence.
- Make test trustworthiness decisive for regression PASS evidence.
- Explicitly deepen privacy/data lifecycle, compatibility, time/locale, third-party, cost/resource, AI, accessibility and blast-radius responsibilities.
- Preserve the 25-gate count.

### Phase 3 — Runtime execution contract
Status: IN PROGRESS
- Update authoritative agent instructions with mandatory lens workflow.
- Add lens applicability decision phase.
- Add evidence-strength ceiling rules.
- Add cross-gate/lens correlation and closure rules.
- Add risk-based test depth and bounded rerun/flakiness logic.

### Phase 4 — Reporting and dashboard
Status: NOT_STARTED
- Extend Project QA Profile with lens applicability and risk inventory.
- Extend daily report with compact lens summary and evidence assurance.
- Upgrade Dashboard run schema to preserve lens history.
- Add calm dashboard reliability-lens view without information overload.
- Preserve historical v1 dashboard records gracefully.

### Phase 5 — Discovery and tooling
Status: NOT_STARTED
- Enhance QA Doctor with privacy/AI/i18n/third-party/compatibility/resource/accessibility signals.
- Update installer/verify/update/rollback for lens/runtime additions.
- Preserve local-only/no-telemetry behavior.

### Phase 6 — Self-QA and release gates
Status: NOT_STARTED
- Require exactly 25 gates and exactly 9 lenses.
- Test lens mapping integrity and status semantics.
- Test evidence-assurance PASS ceilings.
- Test schema compatibility and dashboard history.
- Run Windows, Ubuntu and macOS CI.
- Expand secret/integrity/package checks.

### Phase 7 — Independent red-team
Status: NOT_STARTED
- Attempt to produce false PASS with untrusted tests.
- Attempt to hide a relevant concern behind a broad gate.
- Attempt NOT_APPLICABLE misuse.
- Attempt stale-evidence PASS.
- Attempt lens/gate contradictory states.
- Test old v1.4.0 -> v2.0.0 update preservation.
- Test rollback v2.0.0 -> v1.4.0 behavior.
- Test public anonymous package/checksum/update detection.

### Phase 8 — Release
Status: NOT_STARTED
- Final cross-platform CI PASS.
- Mark all prior phases complete.
- Merge controlled v2 branch into main.
- Tag `v2.0.0`.
- Release ZIP + SHA-256 + release manifest.
- Verify public anonymous download and checksum.
- Verify v1.4.0 detects v2.0.0 update.

## Resume rule

When resuming work, read this file and `docs/V2_CHECKPOINT.json` first. Continue from the first phase whose status is not COMPLETE. Do not repeat completed destructive or expensive checks unless a later change invalidated their evidence.

## Completion log

No phase is considered COMPLETE until implementation, tests/evidence, checkpoint update and Git commit are all present.

### 2026-08-26 — Phase 0 COMPLETE
- Dedicated branch `feature/v2-reliability` created and pushed.
- Durable implementation plan and machine-readable checkpoint committed.
- Resume rule established: read plan + checkpoint first; do not repeat completed work unless invalidated.

### 2026-08-26 — Phase 1 COMPLETE
- Added 9 authoritative cross-cutting lens specifications under `runtime/lenses/`.
- Added `runtime/config/reliability.yaml` with 25+9 model, evidence assurance ceilings, lens status rules, finding ID patterns and test-trustworthiness rules.
- Added Lens Evaluation and Evidence Assurance templates.
- Extended Project QA Profile with lens applicability, reliability risk inventory, test trustworthiness profile and assurance overrides.
- Upgraded default runtime config to reliability model version 2.
- Validation evidence: exactly 9 lenses, numbering 01-09, all gate references bounded to 01-25, required applicability/assurance/status contracts present.

### 2026-08-26 — Phase 2 COMPLETE
- Deepened all 25 canonical gate files with explicit v2 cross-cutting reliability obligations.
- Preserved canonical gate count at exactly 25.
- Added gate-specific lens relationships and evidence-assurance ceilings.
- Gate 04 now forbids material PASS based on WEAK/INSUFFICIENT decisive regression tests and rejects coverage-only confidence.
- Gate 12 explicitly covers privacy lifecycle, migration, precision/time and resource pressure.
- Gate 15 requires real accessibility depth for human UI and rejects scanner-only proof.
- Gate 16 requires AI-specific eval/non-determinism/injection/model-drift evidence when applicable.
- Gate 24 requires representative upgrade/rollback and release-risk evidence.
- Gate 25 requires all nine lens decisions and blocks complete DoD PASS when applicable lens evidence is missing.
- Validation evidence: 25/25 gates contain one v2 reliability section and evidence-assurance rule; critical-gate content assertions passed.
