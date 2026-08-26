# GATE-01 — Canonical Truth and Governance Integrity

## Purpose

Establish one current source of project truth and detect contradictions between repository state, documentation, environments, ownership and declared process.

## Project-adaptive check families

Repository identity; branch/HEAD/dirty state; authoritative docs; stale/conflicting status; environment boundaries; ownership/approval rules; configuration truth.

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

Relevant lenses: LENS-09, LENS-02, LENS-03

Treat the accepted change baseline, reliability policy, lens applicability map, authority boundaries and contradictory documentation as canonical-governance evidence. A run with missing mandatory lens decisions is incomplete, not a governance PASS.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `gates/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
