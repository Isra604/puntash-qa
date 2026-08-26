# GATE-12 — Database Integrity and Consistency

## Purpose

Validate schema-level and application-level data integrity without unsafe mutation.

## Project-adaptive check families

Constraints; relationships; consistency; nullability; uniqueness; referential integrity; migration state; read/write contracts; transaction boundaries; query correctness.

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

Relevant lenses: LENS-02, LENS-03, LENS-04, LENS-06, LENS-09

Database integrity explicitly consumes privacy lifecycle, migration/compatibility, precision/time and capacity lenses. Test deletion/resurrection, migration idempotency/partial failure, numeric/time semantics, uniqueness/collation and connection/lock pressure where material.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `config/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
