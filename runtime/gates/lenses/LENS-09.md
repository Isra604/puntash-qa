# LENS-09 — Change Impact, Dependency Reach & Blast Radius

## Purpose

Determine what a change could have broken beyond the file or test that directly changed, and select regression depth from dependency reach and risk.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-01, GATE-02, GATE-03, GATE-04, GATE-05, GATE-06, GATE-07, GATE-08, GATE-09, GATE-10, GATE-11, GATE-12, GATE-13, GATE-14, GATE-15, GATE-16, GATE-17, GATE-18, GATE-19, GATE-20, GATE-21, GATE-22, GATE-23, GATE-24, GATE-25

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families
- Diff/change inventory since the accepted baseline: code, config, dependencies, schema, infra, feature flags and generated artifacts.
- Dependency reach: callers, consumers, shared libraries, APIs/events, database objects, caches, jobs and deployment/config relationships.
- Behavioral contracts touched directly or indirectly.
- Adjacent gates/lenses requiring revalidation because of the change.
- High-risk shared primitives and single points of failure.
- Migration/rollback blast radius.
- Security/privacy/authorization boundary changes caused indirectly by refactors/config changes.
- Test selection adequacy: prove the chosen regression set covers plausible impact, not just modified files.
- Unknown reach: if dependency impact cannot be established, lower assurance rather than assuming locality.

### Applicability rule
Always evaluate the lens decision. If there is no meaningful change since the accepted baseline, it may be NOT_APPLICABLE for change-impact execution with evidence of the unchanged baseline. Any material change makes it applicable.

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
