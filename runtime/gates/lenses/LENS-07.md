# LENS-07 — AI Quality, Model Risk & Non-Determinism

## Purpose

Apply dedicated QA when discovery finds AI/ML/LLM behavior so model variability, prompt/data attacks and provider drift are tested as product risks rather than ordinary deterministic code.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-05, GATE-06, GATE-07, GATE-08, GATE-09, GATE-13, GATE-14, GATE-16, GATE-17, GATE-18, GATE-19, GATE-21, GATE-22, GATE-24, GATE-25

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families when applicable
- Eval-set quality: representative, adversarial, edge and regression examples with versioned expectations.
- Non-determinism: repeat sampling where variability matters; distinguish acceptable variation from contract violation.
- Hallucination/fabrication and unsupported-confidence behavior.
- Prompt injection, indirect injection, instruction hierarchy and tool/data exfiltration boundaries.
- Context/privacy leakage across users, sessions, tenants, documents or retrieved sources.
- Structured-output/schema validity and recovery from malformed model output.
- Provider/model/version drift and behavior change after model upgrades.
- Safety/policy bypass appropriate to the product's risk domain.
- Retrieval grounding, stale knowledge and citation/source correctness when applicable.
- Token/context-window truncation, long-context degradation and fallback behavior.
- Model/provider outage, rate limit, latency and cost ceilings.
- Human override/review requirements for high-impact AI decisions.

### Applicability rule
If discovery finds no AI/ML/LLM inference or AI-generated product behavior, mark this lens NOT_APPLICABLE with evidence. Do not invent AI requirements for ordinary software.

## Evidence assurance

Classify the lens evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT. WEAK/INSUFFICIENT evidence cannot support a material PASS. MODERATE evidence may support PASS only when the remaining gap is explicitly shown to be non-material for the current project/risk.

## Required lens output

- status: PASS / FAIL / BLOCKED / NOT_RUN / NOT_APPLICABLE
- applicability rationale and evidence
- evidence assurance: STRONG / MODERATE / WEAK / INSUFFICIENT
- gates affected/consuming this lens
- checks executed
- checks skipped and reason
- findings and stable IDs
- remediation, if authorized
- post-fix/retest evidence
- remaining uncertainty/risk
