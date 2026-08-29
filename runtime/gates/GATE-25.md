# GATE-25 — Architecture, Risk, Technical Debt and Traceability

## Purpose

Identify systemic structural risks and ensure work is auditable from requirement through incident and closure.

## Project-adaptive check families

Architecture review; SPOF; FMEA; risk register; dependency risk; capacity architecture; technical debt; audit trail; RTM/traceability; Definition of Done; incident/postmortem/RCA readiness.

## Execution rules

- Select only checks justified by current project discovery.
- Prefer project-native deterministic checks and existing accepted baselines.
- Preserve exact current evidence.
- Do not infer PASS from old reports alone.
- If applicable checks cannot execute, use BLOCKED or NOT_RUN with reason.
- If discovery proves this responsibility has no meaningful applicability, use NOT_APPLICABLE with evidence.
- Record all material findings with stable IDs and link supporting artifacts.
- Verify current-run schema automatic-remediation accounting: every automatic mutation is declared and linked to a unique current-run ALLOW Authorization ID with preserved pre/post evidence.
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

Relevant lenses: LENS-01, LENS-02, LENS-03, LENS-04, LENS-05, LENS-06, LENS-07, LENS-08, LENS-09

This gate is the final cross-cutting consistency check. All nine lens decisions must be visible. Resolve or explicitly block contradictions between gates/lenses, verify change blast radius, systemic risk, technical debt and Definition of Done. Missing applicable lens evidence prevents a complete architecture/DoD PASS.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `gates/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
