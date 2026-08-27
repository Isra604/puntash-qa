# LENS-08 — Accessibility Depth & Assistive Interaction

## Purpose

Ensure accessibility is a real user-journey requirement rather than a superficial automated scan.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-15, GATE-05, GATE-06, GATE-07, GATE-09, GATE-16, GATE-24

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families when a human UI is present
- Keyboard-only operation and logical focus order.
- Visible focus and no keyboard traps.
- Semantic names/roles/states and screen-reader announcement behavior.
- Form labels, validation/error association and dynamic status announcements.
- Contrast and non-color-only meaning.
- Zoom/reflow/responsive readability at relevant magnification.
- Reduced motion and animation sensitivity where applicable.
- Touch target sizing and alternative interaction paths where applicable.
- RTL/bidirectional accessibility when supported.
- Representative automated accessibility tooling plus manual/behavioral checks; automated scanner success alone is not sufficient.

### Applicability rule
For API/CLI/infrastructure projects with no human visual/interactive surface, this lens may be NOT_APPLICABLE with evidence. For any human-facing UI, at least keyboard, semantics and error feedback require explicit evaluation.

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
