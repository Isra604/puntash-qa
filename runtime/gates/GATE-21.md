# GATE-21 — Static Security and Software Supply Chain

## Purpose

Detect source, dependency and build-chain risks without intrusive runtime attacks.

## Project-adaptive check families

SAST; secrets scanning; dependency/SCA; lockfiles; vulnerable packages; provenance; SBOM readiness; unsafe config; insecure defaults; build integrity.

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

Relevant lenses: LENS-01, LENS-05, LENS-06, LENS-07, LENS-09

Static security/supply-chain conclusions must account for test-tool trust, dependency/vendor reality, resource abuse paths, AI package/model supply chain and blast radius of dependency updates. Scanner success alone is not a security PASS.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `gates/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
