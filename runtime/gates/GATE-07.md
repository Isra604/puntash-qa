# GATE-07 — Safety, Policy and Business Rule Enforcement

## Purpose

Prove explicit safety, policy, eligibility and business rules are enforced consistently.

## Project-adaptive check families

Allow/deny rules; precedence; policy boundaries; restricted states; fail-safe behavior; rule conflicts; bypass attempts; policy traceability.

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

Relevant lenses: LENS-02, LENS-07, LENS-08, LENS-09

Restriction/safety authority includes privacy ownership boundaries, AI/tool authority boundaries and accessible error/denial behavior. A restriction that works only in one UI path or leaks data through another surface is not sufficient.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `config/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
