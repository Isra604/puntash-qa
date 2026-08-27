# GATE-24 — Release, Rollback, Configuration Drift and Production Readiness

## Purpose

Determine whether a change can be released and safely reversed under controlled configuration.

## Project-adaptive check families

Release checklist; build artifacts; migrations readiness; config parity/drift; feature flags; rollback path; release blockers; production readiness; change management.

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

Relevant lenses: LENS-01, LENS-03, LENS-05, LENS-06, LENS-07, LENS-08, LENS-09

Release readiness must explicitly consume upgrade/migration compatibility, dependency quota/version risk, resource/cost limits, AI/model drift, accessibility regressions and change blast radius. Clean install/build success cannot substitute for representative upgrade and rollback evidence.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `gates/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
