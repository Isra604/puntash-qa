# GATE-16 — Verification, Validation, UAT and Domain Benchmark Readiness

## Purpose

Prove the implementation matches requirements and that the built product solves the intended domain problem with credible acceptance evidence.

## Project-adaptive check families

Requirements traceability; V&V; UAT evidence; realistic domain cases; benchmark sets; acceptance thresholds; human review needs; live-vs-mock readiness.

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

Relevant lenses: LENS-01, LENS-07, LENS-08, LENS-09

For AI-enabled products, LENS-07 is mandatory: versioned eval sets, repeat sampling where variability matters, hallucination/grounding, injection/context leakage, structured-output validity and provider/model drift. A few hand-picked successful examples cannot prove validation readiness.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `config/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
