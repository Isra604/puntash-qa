# GATE-20 — Observability, Monitoring and Service Objectives

## Purpose

Ensure operators can detect, explain and respond to failures using trustworthy telemetry.

## Project-adaptive check families

Logging; metrics; traces; correlation IDs; health/synthetic checks; dashboards/alerts; SLI/SLO; error budget; MTTR signals; sensitive-data logging controls.

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

Relevant lenses: LENS-02, LENS-05, LENS-06, LENS-09

Observability QA includes privacy-safe logs/traces, dependency/cost saturation signals and operator visibility of resource exhaustion. Logging more data is not automatically better observability if it leaks sensitive data or creates unbounded cost.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `config/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
