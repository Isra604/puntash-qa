# LENS-05 — Third-Party Failure, Quota & Dependency Reality

## Purpose

Validate behavior when external vendors, APIs, identity providers, model providers, networks and managed services are slow, unavailable, rate-limited, changed or partially wrong.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-03, GATE-05, GATE-06, GATE-14, GATE-17, GATE-18, GATE-19, GATE-20, GATE-22, GATE-24, GATE-25

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families
- Timeouts, retries, exponential backoff/jitter and retry storms.
- Rate limits, quotas, daily/monthly caps and concurrency limits.
- Slow, partial, malformed, stale and semantically invalid responses.
- Vendor outage and degraded-mode/fallback behavior.
- Authentication expiry, revoked permissions, rotated credentials and scope changes without exposing credentials.
- API deprecation/version drift and undocumented response additions.
- Webhook/event duplication, loss, reordering and delayed delivery.
- Billing/paid-call failure boundaries and runaway paid usage.
- Vendor SLA/SLO mismatch with product promises.
- Recovery when dependency service returns after an outage.

### PASS ceiling
A happy-path live call is not sufficient integration proof for a critical dependency. At least the material failure modes supported by project capabilities must be exercised or explicitly BLOCKED/NOT_RUN.

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
