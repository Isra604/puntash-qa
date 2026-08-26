# GATE-22 — Dynamic Security and Threat Modeling

## Purpose

Validate runtime security boundaries and model credible threats without unauthorized penetration activity.

## Project-adaptive check families

AuthN/AuthZ runtime checks; input/output security; session/cookie/header controls; common web/API risks; threat model; STRIDE where useful; abuse cases; exposed attack surface.

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

Relevant lenses: LENS-01, LENS-02, LENS-05, LENS-07, LENS-09

Dynamic security/authz must include privacy isolation and AI/prompt/tool boundary attacks when applicable, plus dependency credential expiry/revocation. Security automation needs trustworthy oracles and evidence that negative access actually remained denied across state transitions.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `gates/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
