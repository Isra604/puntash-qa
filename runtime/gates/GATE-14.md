# GATE-14 — Integration Testing

## Purpose

Verify contracts between modules, services, external providers and infrastructure boundaries.

## Project-adaptive check families

Service-to-service; API contracts; database adapters; queues/events; external provider adapters; mocks versus real contract; retries/timeouts; serialization.

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

Relevant lenses: LENS-01, LENS-03, LENS-05, LENS-07, LENS-09

Integration QA must exercise compatibility and dependency reality: malformed/partial/slow/rate-limited responses, version drift, duplicate/reordered events and contract changes. Integration mocks cannot replace material live/representative contract evidence without an explicit assurance reduction.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `gates/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
