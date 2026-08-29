# PUNTASH QA v2.2.0 — Dashboard Human Usability Review

Original creator and project architect: Ofir Israeli
Copyright © 2026 Ofir Israeli

Status: **LOCAL PASS — FINAL CANDIDATE CI PENDING**

## Purpose

This review is release-blocking. The default Dashboard must be understandable and safely operable without requiring knowledge of Git, JSON, Policy schemas, Gate IDs, scheduler internals, authorization IDs, command-line tools or PUNTASH QA implementation details.

The product may retain all professional technical detail, but that information belongs in **Details**, not in the primary operating surface.

## Required user questions

A user should be able to answer these without opening Details:

1. Is my project okay right now?
2. What did PUNTASH QA notice?
3. What should I do next?
4. Is a scan running?
5. When will the next automatic scan run?
6. What is PUNTASH QA allowed to change by itself?
7. Does PUNTASH QA need my decision?
8. Why does it need my decision, what files are involved, and can the change be undone?
9. Is the project still covered by the latest verified scan?
10. Is PUNTASH QA itself healthy?
11. Is this Dashboard sending my project data somewhere?

## Primary navigation language

The default navigation is task-oriented:

- Home
- Scan
- Things to review
- Activity
- What PUNTASH can change
- Automatic scans
- Your decisions
- Project health
- Ready to release?
- Fix PUNTASH QA
- Ask PUNTASH
- Settings & privacy

Internal screen IDs can remain `findings`, `permissions`, `schedule`, `approvals`, `release`, and `recovery`; those are implementation details and are not the user-facing labels.

## Plain-language rules

In Overview, do not require the user to understand:

- `policy_revision`
- `request_id`
- `authorization_id`
- executor configuration
- JSON or schema terminology
- Git HEAD or SHA hashes
- cron / Task Scheduler internals
- Owner Policy internals
- Control tokens
- telemetry terminology

Technical details remain available under **Details**.

## Findings / Things to review

A card answers:

- what PUNTASH QA noticed;
- why it matters;
- what the user can do next;
- how serious it is;
- where proof is available.

If a report contains only highly technical prose, Overview does not dump that raw text into the primary explanation. It uses a safe generic explanation and leaves the original record in Details.

## Decisions

The primary decision card says:

- what PUNTASH QA wants to change;
- why;
- which files;
- how risky;
- whether it can be undone;
- whether the expected result was checked;
- proof.

The exact request shown to the user is bound to `request_hash`. A changed or duplicated request fails closed and cannot be approved from stale UI.

## Errors and recovery

Primary toasts/errors explain the meaning and next action instead of exposing internal error names. Technical error text is reserved for Details.

A recovery may report partial success: if permissions were returned to a safe state but external scheduler cleanup is still pending, the Dashboard must say exactly that. It must never claim that automatic scans are off without proof.

## Release readiness

A historical green report is not enough. The Dashboard only says Ready when the latest validated result still covers the current project state. A new commit or uncovered working-tree change invalidates Ready and Project Health instructs the user to scan again. Git projects use current HEAD plus clean working-tree proof. Non-Git projects use the schema-v4 `PUNTASH_SOURCE_V1` project fingerprint captured from the final verified project state; a file change invalidates Ready until a new verified scan records a matching snapshot.

## Multi-window behavior

Two Dashboard windows cannot race mutations or scans into contradictory state. Policy, Scheduler, Recovery and Approval are serialized across processes. Manual scans use the shared OS scan lock, and every Dashboard sees the shared active scan state.

## Automated usability evidence

`scripts/v2.2-dashboard-usability-red-team.py` verifies:

- plain-language primary labels;
- technical identifiers hidden from Overview;
- Overview as the default mode;
- local-command fields restricted to Details;
- raw state restricted to Details;
- every primary screen has a plain-language explanation;
- old jargon labels do not return.

`scripts/v2.2-dashboard-browser-smoke.py` opens the real Dashboard in a Chromium browser against a real local Control Center and verifies:

- JavaScript executes;
- all primary navigation is rendered;
- onboarding is rendered in plain language;
- technical identifiers are absent from rendered Overview;
- desktop render is non-blank;
- mobile render is non-blank.

Local result:

```text
V22_DASHBOARD_USABILITY_RESULT=PASS
V22_BROWSER_SMOKE_RESULT=PASS
```

## Final acceptance

Local human-usability review is PASS. Final release approval still requires the final committed candidate to pass Windows, Ubuntu and macOS CI, reproducible package build, upgrade/rollback tests and final artifact audit.
