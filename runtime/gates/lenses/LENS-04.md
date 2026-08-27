# LENS-04 — Time, Locale, Precision & Encoding

## Purpose

Expose defects caused by clocks, time zones, calendars, localization, text encodings, numeric precision, currency and sorting/normalization rules.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-05, GATE-06, GATE-09, GATE-10, GATE-11, GATE-12, GATE-13, GATE-14, GATE-15, GATE-16, GATE-17

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families
- Time zones, UTC/local conversion, DST transitions, leap years, month/year boundaries and clock skew when relevant.
- Locale-sensitive formatting/parsing for dates, numbers, currency and decimal separators.
- Rounding, floating point/decimal precision, money arithmetic and cumulative error.
- Unicode normalization, combining characters, emoji, surrogate pairs, non-Latin text and invalid encoding input.
- RTL/LTR/bidirectional content when a human interface or generated text supports it.
- Case folding, collation, sorting, search and uniqueness rules across locales.
- Extremely long strings, empty/whitespace-only text, control characters and line endings.
- Stable IDs and serialization across platforms/encodings.

### Applicability rule
Do not force every sub-check on every project. The lens is applicable whenever product behavior depends materially on time, human-readable text, numbers/currency, internationalization, cross-platform files or locale-sensitive ordering.

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
