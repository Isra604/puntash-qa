# PUNTASH QA Dashboard

PUNTASH QA v2.2.0 turns the local Dashboard into the main day-to-day control surface for the QA system. The Dashboard is designed to explain what is happening before exposing technical detail.

## Main idea

A user should be able to answer three questions from Home:

1. What is the state of my project?
2. What did PUNTASH QA do or find?
3. What can I safely do next?

The Dashboard does not replace evidence or authority controls. It is a safe human interface over the same canonical runtime tools used by the CLI/agent workflows.

## Main screens

- **Home** — project health, latest scan, attention items, next automatic scan, release readiness and recent activity.
- **Scan** — SCAN NOW, live status and real progress only when progress can be proven.
- **Findings** — plain-language finding explanations, evidence and the 25 quality checks.
- **Activity** — scan history, permission/schedule changes and authorized remediation history.
- **Permissions** — Observe only, Fix safe things, or More active protection.
- **Schedule** — automatic scan on/off, frequency, time, selected days and runner setup.
- **Approvals** — exact owner decisions for queued changes.
- **Project health** — health history and what changed since the previous scan.
- **Release readiness** — evidence-based Ready / Not yet / Could not fully verify.
- **Recovery** — fail-closed setup problems with safe recovery actions.
- **Ask PUNTASH** — deterministic search over local QA information; no external AI call.
- **Settings & about** — version, Terms status, privacy and technical raw state in Details mode.

## SCAN NOW

SCAN NOW never simulates a scan. It starts a real manual runner only when Owner Policy contains a valid `LOCAL_COMMAND` executor. If the project is configured for `AGENT_MANAGED`, the Dashboard explains that the external AI/platform must start the run. If no runner is configured, it directs the user to Schedule & setup.

Manual and scheduled runs share the same OS-level overlap lock. A manual run does not increase remediation authority. It uses the same Terms validation, Owner Policy, timeout and process-tree safety contract as scheduled runs.

## Permissions

The Dashboard maps the canonical presets to plain language:

- `REPORT_ONLY` → **Observe only**
- `SAFE_FIXES` → **Fix safe things**
- `ACTIVE_REMEDIATION` → **More active protection**

The canonical Permission Policy remains immutable authority. Protected categories, credentials, QA/CI/VCS authority, production/destructive boundaries and non-reversible automatic changes cannot be enabled from the Dashboard.

## Approval Queue

`state/APPROVAL_REQUESTS.jsonl` may contain bounded pending owner decisions. The Dashboard displays the finding, risk, reason, exact target paths, reversibility and evidence. Approving a request does **not** execute the mutation. It calls the canonical `authorize-change` engine and records the resulting Authorization ID only if that engine returns ALLOW.

Decision audit records are appended to `state/OWNER_APPROVAL_DECISIONS.jsonl`. Stale policy revisions and repeated decisions are rejected.

## Evidence viewer

The authenticated evidence API permits bounded reads only from preserved QA roots:

```text
evidence/
artifacts/
profile/
reports/
remediation/
dispositions/
```

Traversal, absolute paths, state files, symlink/reparse escapes, unsafe extensions and oversized files are rejected. SVG is intentionally not rendered.

## Release readiness

Ready is not calculated from a cosmetic score. The current structured run must have all 25 gates and 9 lenses, no FAIL/BLOCKED/NOT_RUN state and pass the canonical run validator. Missing evidence becomes **Could not fully verify**, never Ready.

## Recovery

The Recovery Center is fail closed. A damaged Owner Policy blocks automatic change authority. The safe recovery action resets to the shipped Owner Policy template with **Observe only** and automatic scans disabled, then applies it through Policy Manager.

The Dashboard never accepts Terms on behalf of a user. Terms recovery remains a human installer/update action.

## Local security model

- Control server binds only to `127.0.0.1`.
- A random per-session token is required for every API.
- The token is delivered in the URL fragment and removed from the address bar immediately after bootstrap.
- Static HTTP serving exposes only `dashboard/index.html`; `state/` and `data.js` are not served.
- `file://` opening remains a read-only view.
- No Dashboard telemetry or hosted account is added.
- API bodies and evidence reads are bounded.
- No Control endpoint accepts an arbitrary shell command, arbitrary filesystem path, arbitrary URL or raw HTML.

## Windows

Double-click:

```text
.comprehensive-qa\OPEN_DASHBOARD.cmd
```

This starts the native Windows loopback Control Center.

## macOS / Linux

When Python 3 is available:

```text
.comprehensive-qa/tools/open-dashboard.sh
```

## Structured history

Completed runs stay immutable under:

```text
reports/dashboard/*.json
```

`dashboard-refresh.ps1` / `.sh` build schema-v3 `dashboard/data.js` atomically for read-only/offline viewing.
