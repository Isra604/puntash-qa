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
Status: COMPLETE
- Update authoritative agent instructions with mandatory lens workflow.
- Add lens applicability decision phase.
- Add evidence-strength ceiling rules.
- Add cross-gate/lens correlation and closure rules.
- Add risk-based test depth and bounded rerun/flakiness logic.

### Phase 4 — Reporting and dashboard
Status: COMPLETE
- Extend Project QA Profile with lens applicability and risk inventory.
- Extend daily report with compact lens summary and evidence assurance.
- Upgrade Dashboard run schema to preserve lens history.
- Add calm dashboard reliability-lens view without information overload.
- Preserve historical v1 dashboard records gracefully.

### Phase 5 — Discovery and tooling
Status: COMPLETE
- Enhance QA Doctor with privacy/AI/i18n/third-party/compatibility/resource/accessibility signals.
- Update installer/verify/update/rollback for lens/runtime additions.
- Preserve local-only/no-telemetry behavior.

### Phase 6 — Self-QA and release gates
Status: COMPLETE
- Require exactly 25 gates and exactly 9 lenses.
- Test lens mapping integrity and status semantics.
- Test evidence-assurance PASS ceilings.
- Test schema compatibility and dashboard history.
- Run Windows, Ubuntu and macOS CI.
- Expand secret/integrity/package checks.

### Phase 7 — Independent red-team
Status: COMPLETE
- Attempt to produce false PASS with untrusted tests.
- Attempt to hide a relevant concern behind a broad gate.
- Attempt NOT_APPLICABLE misuse.
- Attempt stale-evidence PASS.
- Attempt lens/gate contradictory states.
- Test old v1.4.0 -> v2.0.0 update preservation.
- Test rollback v2.0.0 -> v1.4.0 behavior.
- Test public anonymous package/checksum/update detection.

### Phase 8 — Release
Status: IN PROGRESS
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
- Added 9 authoritative cross-cutting lens specifications under `runtime/gates/lenses/`.
- Added `runtime/gates/reliability.yaml` with 25+9 model, evidence assurance ceilings, lens status rules, finding ID patterns and test-trustworthiness rules.
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

### 2026-08-26 — Phase 3 COMPLETE
- Added mandatory Phase 3A lens applicability workflow and Phase 3B evidence-assurance/PASS-ceiling workflow to authoritative agent instructions.
- Added explicit STRONG/MODERATE/WEAK/INSUFFICIENT semantics and high-risk evidence expectations.
- Added decisive-test trustworthiness rules, bounded rerun guidance, mutation-testing preference/fallback and coverage-only prohibition.
- Added risk-based QA depth driven by consequence and LENS-09 blast radius.
- Added cross-gate/cross-lens contradiction resolution rules.
- Added lens-owned stable finding IDs without duplicating one defect under gate and lens identities.
- Updated completion contract: 25 gate statuses + 9 lens statuses + assurance classifications are required.
- Updated portable skill, ChatGPT project instructions and START_HERE to enforce v2 runtime behavior.
- Validation evidence: authoritative runtime tokens, skill numbering 1-21, ChatGPT lens/assurance/trust requirements all passed.

### 2026-08-26 — Phase 4 COMPLETE
- Upgraded dashboard run schema to v2 with 9 lens records, evidence-assurance summary, test-trustworthiness record and lens/assurance change history.
- Extended daily report with compact Reliability Lens Summary, Evidence Assurance Summary, Test Trustworthiness section and PASS-ceiling record.
- Added calm Dashboard Reliability Assurance strip: one overall assurance card plus 9 clickable lens chips, without changing gate-health scoring.
- Added lens detail modal and lens-owned finding display.
- Added lens and assurance changes to What Changed history.
- Preserved legacy v1.x dashboard records; they display as Legacy rather than being misclassified as missing/failing v2 lenses.
- Updated Dashboard documentation for v2 privacy/local-only and history semantics.
- Validation evidence: v2 schema contract PASS, JS syntax PASS, mixed v1/v2 history refresh PASS.

### v1.4 updater compatibility layout
During Phase 5, the reliability files were deliberately located under the existing managed `gates/` tree: `gates/lenses/` and `gates/reliability.yaml`. The v1.4.0 updater already replaces the full `gates/` directory recursively, so an existing v1.4.0 installation can receive the complete v2 reliability architecture without requiring an intermediate bridge release or a second updater pass. This supersedes only the physical Phase-1 path, not the completed lens semantics.

### 2026-08-26 — Phase 5 COMPLETE
- Moved canonical lens definitions to `runtime/gates/lenses/` and reliability policy to `runtime/gates/reliability.yaml` specifically to preserve direct upgrade compatibility with the already-released v1.4 updater, which recursively replaces the complete `gates/` tree.
- Set branch package metadata to target version `2.0.0`; Terms remain `1.0.0`.
- Regenerated deterministic legal manifest for package version 2.0.0 without changing legal document content or Terms version.
- Upgraded QA Doctor schema/version to 2.0 on PowerShell and shell implementations.
- Added conservative discovery hints for all 9 reliability lenses; false hints explicitly do not mean NOT_APPLICABLE.
- Updated v2 updater to validate 25 gates + 9 lenses + reliability policy for v2 packages and post-update state.
- Updated install verification scripts to require the v2 reliability model.
- Validation evidence: PowerShell Doctor 9/9 hints PASS, Git Bash Doctor 9/9 hints PASS, PowerShell syntax PASS, v1.4 updater gate-tree recursive-copy proof PASS.

### 2026-08-27 — Phase 6 COMPLETE
- Added cross-platform v2 structured-run validators for PowerShell and Python/shell environments.
- Validator requires exactly 25 gates + 9 reliability lenses for schema-v2 runs.
- Enforced evidence-assurance PASS ceilings: WEAK/INSUFFICIENT cannot PASS; MODERATE PASS requires explicit non-material gap attestation.
- Enforced Gate-25 closure consistency against unresolved applicable lenses.
- Expanded Windows/Unix self-QA for lens count, policy integrity, Doctor v2 hints, validator negative cases, dashboard v1/v2 compatibility, secret scanning and package contents.
- Hardened Unix lens numbering and Python-runtime probing.
- Draft PR #1 opened only to exercise pull-request CI; no merge performed.
- CI evidence: Windows PASS, Ubuntu PASS, macOS PASS on run 33067591254.

### 2026-08-27 — Phase 7 COMPLETE
- Added permanent false-PASS red-team suite and hardened v2 based on defects it exposed.
- PASS/FAIL now requires current evidence references; stale evidence alone is mechanically rejected.
- NOT_APPLICABLE now requires both rationale and applicability evidence.
- Added machine-readable blocking gate/lens map and explicit contradiction-exception contract; Gate 25 remains strict with no unresolved-lens exception.
- Made Test Trustworthiness decision mandatory and prevented decisive-suite PASS without adequate trust evidence.
- Prevented run-level overall assurance from overstating the weakest component assurance.
- Found and fixed rollback/update-failure tool residue by atomically replacing managed tools directories.
- Added permanent v1.4 -> v2 -> v1.4 upgrade/rollback red-team with reports/history/evidence/state/config preservation.
- CI run 33068760738: Windows, Ubuntu and macOS PASS; Windows upgrade/rollback red-team PASS.
- Public anonymous baseline: GitHub release API, ZIP and SHA-256 PASS before v2 publication.
- Detailed evidence and limitations recorded in `docs/V2_REDTEAM_REPORT.md`.
