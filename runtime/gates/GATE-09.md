# GATE-09 — Data, Content and Localization Quality

## Purpose

Validate correctness, completeness, semantic quality, formatting and locale/language behavior of product data and content.

## Project-adaptive check families

Data quality; encoding; locale/time/currency; translation/localization; text fallbacks; content completeness; parsing/serialization; semantic consistency.

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

Relevant lenses: LENS-04, LENS-07, LENS-08, LENS-09

Data/language quality explicitly includes Unicode, normalization, bidi/RTL, locale formatting, precision and AI-generated language risks where applicable. Visual correctness without semantic/data correctness is insufficient.

### Evidence-assurance rule

Classify current evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT under `gates/reliability.yaml`. If a relevant lens exposes a material contradiction or gap that directly affects this gate, the gate cannot remain PASS until the contradiction is resolved or its status is lowered appropriately. A gate PASS never substitutes for the required run-wide lens evaluation.
