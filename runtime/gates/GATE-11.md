# GATE-11 — Identity, Authentication, Authorization and Sync

## Purpose

Validate identity lifecycle, access enforcement and synchronization across clients/services.

## Project-adaptive check families

Sign-in/out; session lifecycle; role/permission enforcement; tenant/user isolation; sync conflict; token/session expiry; account linkage; anonymous/auth transitions.

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

Relevant lenses: LENS-02, LENS-03, LENS-04, LENS-09

Profile/auth/sync QA must cover privacy lifecycle, account ownership transitions, mixed-version/schema behavior, locale/time effects and conflict resolution. Sync success must not resurrect deleted or stale private state.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `config/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
