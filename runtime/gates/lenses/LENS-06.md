# LENS-06 — Resource, Capacity & Cost Exhaustion

## Purpose

Prevent systems that are functionally correct at small scale from failing through memory, disk, connections, queues, logs, retries, cloud spend or AI/API cost growth.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-17, GATE-18, GATE-19, GATE-20, GATE-21, GATE-24, GATE-25

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families
- Memory growth/leaks, file-descriptor/socket/connection exhaustion and thread/process growth.
- Disk/object-store growth, temporary-file cleanup and unbounded cache/index/log accumulation.
- Queue/backlog growth, worker saturation and recovery after backlog.
- Database connection pools, lock pressure, transaction growth and hot partitions/keys.
- Retry amplification, fan-out and cascading resource consumption.
- Cloud/service/API/LLM token or request cost ceilings and pathological expensive inputs.
- Capacity assumptions, limits and graceful rejection/backpressure.
- Soak behavior for leaks that short tests miss.
- Observability volume/cost and log storms.

### PASS ceiling
Latency PASS does not imply capacity/cost PASS. For materially metered or bounded resources, identify at least the governing limit/budget and evidence behavior near it or state the gap.

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
