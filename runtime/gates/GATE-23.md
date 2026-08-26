# GATE-23 — Backup, Restore, Disaster Recovery and Continuity

## Purpose

Prove recoverability rather than merely assuming backups exist.

## Project-adaptive check families

Backup existence/freshness; integrity; restore drill evidence; RPO/RTO; restore dependencies; rollback data safety; disaster scenarios; business continuity; recovery ownership.

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

Relevant lenses: LENS-02, LENS-03, LENS-06, LENS-09

Backup/restore/DR must include privacy deletion retention, schema/version compatibility and capacity/resource feasibility. A backup that exists but cannot restore within required semantics—or resurrects forbidden data—is not a PASS.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `gates/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
