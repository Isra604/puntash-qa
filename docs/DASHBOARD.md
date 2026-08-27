# Local QA Dashboard

Version 1.4.0 introduced the calm local-first dashboard. Version 2.0.0 adds Reliability Assurance. Version 2.1.0 adds a compact owner Control Center for remediation permissions and scheduled QA without turning the first screen into a settings wall.

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

## v2.1 Control Center

The normal dashboard remains concise and shows only two additional status cards: **Agent permissions** and **Scheduled QA**. Detailed choices stay behind `Settings`.

On Windows, `.comprehensive-qa\OPEN_DASHBOARD.cmd` starts a local Control Center. On macOS/Linux, use `.comprehensive-qa/tools/open-dashboard.sh` when Python 3 is available. The Control Center:
- binds only to `127.0.0.1` on an ephemeral/local port
- creates a random per-session control token
- never adds telemetry or a hosted account
- keeps direct `file://` dashboard opening read-only
- serves only dashboard assets without authentication
- requires the session token for policy/scheduler APIs and full-report access
- limits full-report access to `.comprehensive-qa/reports/` and safe text/JSON extensions

The permission/schedule setting is stored locally as `state/OWNER_POLICY.json`; changes append audit metadata to `state/OWNER_POLICY_HISTORY.jsonl`. Scheduler status and run logs remain local under `state/`.

A saved schedule is not equivalent to an active schedule. The dashboard distinguishes OFF, NEEDS_EXECUTOR, NEEDS_PLATFORM_ACTIVATION, ACTIVE, AGENT_MANAGED_ACTIVE and failure/last-run status.
