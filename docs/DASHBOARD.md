# Local QA Dashboard

Version 1.4.0 introduced the calm local-first dashboard. Version 2.0.0 adds Reliability Assurance: 9 cross-cutting lens statuses plus evidence-assurance history without turning the first screen into a technical wall.

## Principles

- Local only by default. No account, cloud upload, analytics, tracking, or telemetry.
- The first screen is intentionally concise: health, coverage, urgent findings, trend, changes, gate map and recent history.
- Colors have stable meaning: green PASS/resolved, red FAIL/Critical/High, amber BLOCKED/Medium, blue NOT_RUN/Low, gray NOT_APPLICABLE.
- Historical runs are preserved as individual JSON records under `reports/dashboard/`.
- The dashboard never replaces the evidence report. It is a navigation and comprehension layer over structured QA summaries.
- v2 runs add all 9 reliability lens statuses and STRONG/MODERATE/WEAK/INSUFFICIENT evidence assurance.
- Legacy v1.x run records remain readable and are labeled as legacy rather than falsely showing missing lenses as failures.

## Open on Windows

Double-click:

```text
.comprehensive-qa\OPEN_DASHBOARD.cmd
```

The launcher refreshes local dashboard data and opens `dashboard/index.html` in the default browser.

## History contract

Each completed QA cycle writes one immutable structured run file:

```text
reports/dashboard/RUN-YYYYMMDD-HHMMSS.json
```

The v2 run contains project/commit identity, all 25 gate statuses, all 9 reliability lens statuses, evidence assurance, test-trustworthiness summary, finding summaries, material findings and explicit gate/lens/assurance changes from the prior run. `tools/dashboard-refresh.ps1` or `tools/dashboard-refresh.sh` rebuilds `dashboard/data.js` from those records without sending data anywhere.

## Health and coverage

Dashboard **QA Health** is a presentation metric, not a product-certification score:

```text
PASS / (PASS + FAIL + BLOCKED)
```

NOT_APPLICABLE and NOT_RUN are excluded from health. Coverage is shown separately so incomplete execution cannot look equivalent to a fully-tested project.

## Evidence freshness and assurance in v2
A v2 PASS/FAIL run record is valid only when it references current evidence. NOT_APPLICABLE requires current applicability evidence. The dashboard shows the recorded assurance but never upgrades it; overall assurance cannot exceed the weakest gate/lens/test-trustworthiness assurance.
