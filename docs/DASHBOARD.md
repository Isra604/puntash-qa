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
- **Things to review** — plain-language explanations of what PUNTASH QA noticed, why it matters, what to do next, and proof when available.
- **Activity** — scan history, permission/schedule changes and authorized remediation history.
- **What PUNTASH can change** — Observe only, Fix safe things, or More active protection, explained without internal policy names.
- **Automatic scans** — turn automatic checking on/off, choose days/time, and choose where scans run.
- **Your decisions** — changes that need a human decision, including what changes, why, how risky it is, whether it can be undone, and proof.
- **Project health** — health history and what changed since the previous scan.
- **Ready to release?** — evidence-based Ready / Not yet / Could not verify, including whether the project changed after the verified scan.
- **Fix PUNTASH QA** — problems with PUNTASH QA itself, explained in plain language with the safest next action.
- **Ask PUNTASH** — deterministic search over local QA information; no external AI call.
- **Settings & privacy** — version, Terms status and data-sharing information; raw technical state stays in Details mode.

## SCAN NOW

SCAN NOW never simulates a scan. It starts a real manual runner only when Owner Policy contains a valid `LOCAL_COMMAND` executor. If the project is configured for `AGENT_MANAGED`, the Dashboard explains that the external AI/platform must start the run. If no runner is configured, it directs the user to **Automatic scans**.

Manual and scheduled runs share the same OS-level overlap lock. A manual run does not increase remediation authority. It uses the same Terms validation, Owner Policy, timeout and process-tree safety contract as scheduled runs.

## What PUNTASH can change

The Dashboard maps the canonical presets to plain language:

- `REPORT_ONLY` → **Observe only**
- `SAFE_FIXES` → **Fix safe things**
- `ACTIVE_REMEDIATION` → **More active protection**

The canonical Permission Policy remains immutable authority. Protected categories, credentials, QA/CI/VCS authority, production/destructive boundaries and non-reversible automatic changes cannot be enabled from the Dashboard.

## Your decisions

`state/APPROVAL_REQUESTS.jsonl` may contain bounded pending owner decisions. The Dashboard displays the finding, risk, reason, exact target paths, reversibility and evidence. Approving a request does **not** execute the mutation. It calls the canonical `authorize-change` engine and records the resulting Authorization ID only if that engine returns ALLOW.

Decision audit records are appended to `state/OWNER_APPROVAL_DECISIONS.jsonl`. Stale policy revisions and repeated decisions are rejected.

## Proof viewer

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

## Ready to release?

Ready is not calculated from a cosmetic score. The current structured run must be complete, pass the canonical run validator, and still match the project that exists now. In a Git project, PUNTASH QA requires the scanned commit to match the current commit and requires no uncovered working-tree changes. If the project changed after the verified scan, the Dashboard says **Scan again** rather than keeping an old Ready result. Missing or invalid proof becomes **Could not verify**, never Ready.

## Fix PUNTASH QA

The recovery flow is fail closed. Damaged permission settings block automatic change authority. The safe recovery action resets to **Observe only** and disables automatic scans through the canonical policy tool.

Recovery does not claim success unless automatic-scan cleanup is also verified. If permissions are safe but an external/platform schedule still needs cleanup, the Dashboard says so explicitly instead of claiming that automatic scans are fully off.

The Dashboard never accepts Terms on behalf of a user. Terms recovery remains a human installer/update action.

## Human-language and multi-window safety

Overview is the default mode. Internal identifiers such as policy revisions, request IDs, authorization IDs, executor fields, raw JSON, Git hashes and scheduler internals are kept in **Details**. Primary navigation uses task-oriented names such as **Things to review**, **What PUNTASH can change**, **Your decisions** and **Fix PUNTASH QA**.

Approval decisions are bound to a SHA-256 hash of the exact request shown to the user. If the request changes or a duplicate request ID appears, the Dashboard refuses the decision and requires a refresh.

Dashboard mutations are serialized with an OS-level cross-process lock. Two Control Center windows therefore cannot race a Policy/Scheduler/Recovery/Approval transaction into inconsistent state. Manual scans also use the shared OS scan lock, so a second Dashboard cannot overwrite the active scan status.

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
