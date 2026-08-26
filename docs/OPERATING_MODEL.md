# Operating Model

## 1. Install

Install the runtime into a target repository as `.comprehensive-qa`.

## 2. Discover before testing

The first cycle is a project-orientation cycle. It builds `profile/PROJECT_QA_PROFILE.md` from direct evidence. This is what makes the QA system portable rather than hard-coded to one stack.

## 3. Map the 25 gates

All gates stay visible, but their internal checks are adapted. Example:

- In a web application, GATE-15 may use browser E2E, responsive and accessibility checks.
- In a CLI-only repository, browser checks are NOT_APPLICABLE, while terminal E2E still belongs to the same gate.
- In an infrastructure repository, GATE-12 may focus on state/config integrity rather than an application database.

## 4. Run evidence-producing checks

Existing project-native tests are preferred. The QA system may add temporary inspection scripts when necessary, but must not pretend temporary heuristics are equivalent to accepted product tests.

## 5. Correlate, do not just list

A strong report identifies a shared root cause when five gates fail because of the same missing dependency or configuration error. It also distinguishes a blocked test environment from a proven product regression.

## 6. Remediate only by authority

Default: report only.

Optional `safe_auto`: unambiguous, reversible, bounded changes only. Anything protected or ambiguous is routed for review.

## 7. Revalidate

Every fix must have post-fix evidence. A changed file without validation is an unresolved remediation, not a closed finding.

## 8. Preserve the audit trail

Never rewrite completed reports after external review. Reviewer dispositions and later remediation belong in separate records. Recurrence of a previously closed issue is explicitly identified as recurrence.

## 9. Repeatable daily or release use

After discovery is stable, later cycles refresh only what changed plus the minimum evidence necessary to prove current gate status. Full deep cycles can be scheduled daily, nightly, per release, or on demand depending on project cost and runtime.
