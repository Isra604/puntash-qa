# GATE-19 — Reliability, Resilience, Fault Injection, Idempotency and Concurrency

## Purpose

Validate predictable behavior when dependencies fail, retry, race or recover.

## Project-adaptive check families

Timeouts; dependency failure; retry/backoff; circuit behavior; partial failure; idempotency; duplicate delivery; race conditions; locks; recovery; graceful degradation.

## Execution rules

- Select only checks justified by current project discovery.
- Prefer project-native deterministic checks and existing accepted baselines.
- Preserve exact current evidence.
- Do not infer PASS from old reports alone.
- If applicable checks cannot execute, use BLOCKED or NOT_RUN with reason.
- If discovery proves this responsibility has no meaningful applicability, use NOT_APPLICABLE with evidence.
- Record all material findings with stable IDs and link supporting artifacts.
- If remediation is authorized, perform only SAFE bounded changes and revalidate this gate plus regression-sensitive adjacent gates.

## Required gate output

- status
- checks executed
- checks skipped and reason
- evidence paths/commands
- findings
- remediation performed
- post-fix validation
- remaining risk

## v2 cross-cutting reliability obligations

Relevant lenses: LENS-01, LENS-03, LENS-05, LENS-06, LENS-07, LENS-09

Reliability/resilience must include migration/mixed-version behavior, dependency outage/recovery, resource exhaustion and AI/provider failure modes. Verify idempotency/concurrency with meaningful state assertions rather than request success alone.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `config/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
