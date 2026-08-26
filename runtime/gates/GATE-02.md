# GATE-02 — Static Code Quality, Type Safety and Build

## Purpose

Prove the project can be statically analyzed and built using its own supported toolchain.

## Project-adaptive check families

Compile/build; type checks; lint/static analysis; syntax validation; generated-code consistency; build warnings/errors; toolchain/version compatibility.

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

Relevant lenses: LENS-01, LENS-03, LENS-09

Build/type/lint success is not proof of behavioral correctness. If tests are used here as supporting evidence, consume LENS-01. Identify version/toolchain drift and compatibility-sensitive compiler/runtime changes.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `config/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
