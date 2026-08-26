# LENS-03 — Compatibility, Migration & Upgrade Safety

## Purpose

Prove that change over time is safe for persisted data, APIs, clients, schemas, configuration and rollback paths.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-10, GATE-11, GATE-12, GATE-14, GATE-19, GATE-23, GATE-24, GATE-25

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families
- Backward/forward compatibility of public APIs, events, files, schemas and stored representations.
- Old client/new server and new client/old server combinations where supported.
- Database/schema migration preconditions, ordering, idempotency and partial-failure behavior.
- Upgrade from supported prior versions, not only clean installation.
- Rollback after code-only change and after data/schema change; explicitly identify irreversible migrations.
- Feature-flag/config rollout compatibility and mixed-version operation during staged deployments.
- Serialization/deserialization compatibility, enum expansion, optional/required fields and default changes.
- Cache/index/job compatibility across versions.
- Deprecation windows and third-party API version changes.
- Restore of older backups into newer software when that scenario is supported.

### PASS ceiling
Clean-install success alone cannot prove upgrade safety. If an existing user/data path can encounter the change, at least one representative upgrade/migration path must be evidenced or the risk remains explicit.

## Evidence assurance

Classify the lens evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT. WEAK/INSUFFICIENT evidence cannot support a material PASS. MODERATE evidence may support PASS only when the remaining gap is explicitly shown to be non-material for the current project/risk.

## Required lens output

- status: PASS / FAIL / BLOCKED / NOT_RUN / NOT_APPLICABLE
- applicability rationale and evidence
- evidence assurance: STRONG / MODERATE / WEAK / INSUFFICIENT
- gates affected/consuming this lens
- checks executed
- checks skipped and reason
- findings and stable IDs
- remediation, if authorized
- post-fix/retest evidence
- remaining uncertainty/risk
