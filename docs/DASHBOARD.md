# Local QA Dashboard

Version 1.4.0 adds a calm, local-first dashboard designed for project owners who want useful QA visibility without reading a large technical report.

## Principles

- Local only by default. No account, cloud upload, analytics, tracking, or telemetry.
- The first screen is intentionally concise: health, coverage, urgent findings, trend, changes, gate map and recent history.
- Colors have stable meaning: green PASS/resolved, red FAIL/Critical/High, amber BLOCKED/Medium, blue NOT_RUN/Low, gray NOT_APPLICABLE.
- Historical runs are preserved as individual JSON records under `reports/dashboard/`.
- The dashboard never replaces the evidence report. It is a navigation and comprehension layer over structured QA summaries.

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

The run contains project/commit identity, all 25 gate statuses, finding summaries, material findings and explicit changes from the prior run. `tools/dashboard-refresh.ps1` or `tools/dashboard-refresh.sh` rebuilds `dashboard/data.js` from those records without sending data anywhere.

## Health and coverage

Dashboard **QA Health** is a presentation metric, not a product-certification score:

```text
PASS / (PASS + FAIL + BLOCKED)
```

NOT_APPLICABLE and NOT_RUN are excluded from health. Coverage is shown separately so incomplete execution cannot look equivalent to a fully-tested project.
