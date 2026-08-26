# LENS-02 — Privacy & Data Lifecycle

## Purpose

Validate the complete lifecycle of personal, sensitive and customer data beyond ordinary security controls: collection, use, storage, sharing, retention, deletion, export, logs and backups.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-07, GATE-10, GATE-11, GATE-12, GATE-20, GATE-22, GATE-23, GATE-24, GATE-25

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families
- Data inventory/classification: identify personal, sensitive, regulated, secret and customer-confidential data handled by the system.
- Collection minimization and purpose: detect fields/events collected without a current product purpose.
- Storage and propagation: map databases, files, caches, analytics, logs, traces, queues, search indexes, object stores and third parties.
- Retention and expiry: verify documented retention against actual cleanup/TTL behavior where evidence exists.
- Deletion semantics: account/item deletion must address derived copies, caches, indexes, asynchronous jobs and restoration/resurrection risks.
- Backup lifecycle: determine whether deleted/expired data can reappear after restore and whether backup retention is understood.
- Export/access/correction behavior when the product promises it.
- Logging/observability privacy: prevent secrets, tokens, full payloads or unnecessary PII from leaking into logs/traces/errors.
- Third-party disclosure and consent/notice signals when applicable.
- Tenant/user isolation and data ownership transitions, including account merge/transfer scenarios.

### PASS ceiling
A security PASS does not imply privacy PASS. If material personal/sensitive data exists and lifecycle evidence is missing for a required stage, this lens is BLOCKED/NOT_RUN or FAIL as evidence warrants; it is not silently covered by authentication or encryption checks.

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
