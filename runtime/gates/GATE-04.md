# GATE-04 — Core Deterministic Regression

## Purpose

Protect previously accepted behavior with repeatable deterministic tests.

## Project-adaptive check families

Unit/component/regression suites; known baselines; prior defect tests; golden/snapshot contracts when appropriate; deterministic assertions.

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

Relevant lenses: LENS-01, LENS-09

This gate is the primary consumer of LENS-01. Inventory skipped/quarantined tests, validate oracles, flakiness, order isolation, mock fidelity and defect sensitivity. Coverage alone never satisfies this gate. If decisive regression tests have WEAK/INSUFFICIENT trustworthiness, material PASS is forbidden.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `config/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
