# PUNTASH QA v2.2.0 — Dashboard Capability Coverage Matrix

Original creator and project architect: Ofir Israeli
Copyright © 2026 Ofir Israeli

Status: **IMPLEMENTED — LOCAL ADVERSARIAL QA VERIFIED**

This matrix is release-blocking. Every user-relevant capability is assigned a Dashboard treatment before v2.2.0 can be declared complete.

## Classification

1. **DIRECT** — safe routine control directly from Dashboard.
2. **OWNER_APPROVAL** — Dashboard can initiate/control only after an explicit human-owner confirmation.
3. **VIEW_ONLY_PROTECTED** — Dashboard explains and displays state, but the protected/external action is not executed by Dashboard.
4. **INTERNAL** — implementation detail intentionally not presented as a routine user control.

## Coverage matrix

| Capability | v2.1 surface | v2.2 treatment | Class | Safety / implementation rule |
|---|---|---|---|---|
| Overall project health | Dashboard | Home summary | DIRECT view | Derived only from latest structured run; no invented score |
| Manual full QA scan | Executor/agent | **SCAN NOW** + live status | DIRECT when LOCAL_COMMAND is configured; otherwise explanatory blocked/setup state | Must use shared overlap lock and existing executor contract |
| Manual scan progress | Logs/status | Human-readable live panel | DIRECT view | Do not invent percentage; show known state/check counts only |
| Scheduled scans enable/disable | Owner Policy + scheduler | Schedule Builder | OWNER_APPROVAL | Policy Manager remains canonical; scheduler cannot grant remediation authority |
| Frequency/time/day | Owner Policy | Schedule Builder | OWNER_APPROVAL | DAILY/WEEKDAYS/WEEKLY only; local time validation |
| Local scheduler apply/remove | scheduler tool | Schedule Builder action/result | OWNER_APPROVAL | Canonical scheduler tool only |
| External AGENT_MANAGED activation/update/deactivation | external AI platform | Status + exact guidance | VIEW_ONLY_PROTECTED | Dashboard cannot claim it changed an external platform |
| Permission preset | Owner Policy | Permissions Center | OWNER_APPROVAL | REPORT_ONLY / SAFE_FIXES / ACTIVE_REMEDIATION mapped to plain language |
| Custom permissions | Owner Policy | Details-only advanced editor where valid | OWNER_APPROVAL | Canonical policy validation and hard ceilings still apply |
| Protected boundaries | Permission Policy | Always-visible explanation | VIEW_ONLY_PROTECTED | Cannot be disabled from Dashboard |
| Automatic remediation authorization | authorize-change | Approval queue invokes canonical authorization for eligible queued requests | OWNER_APPROVAL | Exact target paths/evidence/current policy revision required |
| HIGH/PROTECTED remediation | owner/external decision | Explain why it cannot be auto-approved | VIEW_ONLY_PROTECTED | Dashboard does not create a bypass |
| Findings | Run record | Plain-language cards | DIRECT view | What / why / next action, technical IDs secondary |
| Finding evidence | Reports/evidence | Evidence viewer | DIRECT view | Contained reads only; allowlisted roots/extensions; no arbitrary filesystem access |
| Technical gate/lens detail | Run record | Details layer | DIRECT view | Same source of truth as Overview |
| Reports/history | reports/dashboard | Activity + run history | DIRECT view | Completed reports immutable |
| Remediation history | run automatic_remediation | Before/after/remediation cards | DIRECT view | Claims require authorization + post-fix evidence |
| Undo | no generic rollback contract | Hidden unless a record explicitly proves supported rollback | VIEW_ONLY_PROTECTED by default | Never show cosmetic Undo |
| Owner policy audit history | state history | Activity timeline | DIRECT view | Show bounded safe fields only |
| Authorization audit history | state history | Activity / technical details | DIRECT view | No secrets; decision IDs visible only in Details |
| Health history | run history | Project Health | DIRECT view | Trend states, not vanity score |
| Changes since last scan | run changes | Comparison view | DIRECT view | Distinguish project changes vs PUNTASH changes |
| Release readiness | latest run/lenses | Dedicated card/page | DIRECT view | Ready only from complete current evidence; incomplete => Could not fully verify |
| Policy health | Policy Manager | Recovery Center | DIRECT view | Invalid policy => fail closed |
| Scheduler health | scheduler status | Recovery Center/Schedule | DIRECT view | Raw states translated, raw IDs in Details |
| Human Terms status | acceptance receipt | Settings/Recovery status | DIRECT view | Dashboard never accepts Terms for user |
| Terms acceptance | installer | Explain only | VIEW_ONLY_PROTECTED | Human interactive installer/update flow only |
| Update availability | LAST_UPDATE_CHECK / update tool | Settings/About status | DIRECT view | Applying an update remains separate human-confirmed updater flow |
| Update execution | updater | Launch guidance/status, no silent update | VIEW_ONLY_PROTECTED | Existing human confirmation stays mandatory |
| QA Doctor status | QA Doctor state | Recovery / system health | DIRECT view | Discovery hints are never QA PASS |
| Control Center status | loopback server | Settings/About | DIRECT view | Loopback only, token auth, no telemetry |
| Raw JSON / scheduler signatures / authorization IDs | technical state | Details only | DIRECT view | Not primary copy |
| Internal lock files | runtime | Not exposed as user control | INTERNAL | OS locking remains authoritative |
| Permission Policy mutation | code-distributed canonical ceiling | Never editable from Dashboard | INTERNAL / VIEW_ONLY_PROTECTED | Prevent self-elevation |
| Static `state/` filesystem | runtime | Never directly served | INTERNAL | API returns bounded projections only |

## Existing control endpoints at v2.1 baseline

- `GET /api/dashboard-data`
- `GET /api/report?path=...`
- `GET /api/policy`
- `GET /api/scheduler`
- `POST /api/policy`
- `POST /api/shutdown`

All require the local control token except the static Dashboard HTML. The control service binds only to `127.0.0.1`.

## v2.2 API additions implemented

- `GET /api/overview` — safe consolidated Dashboard state.
- `GET /api/scan-status` — current/latest manual scan state.
- `POST /api/scan-now` — start canonical manual runner when executable.
- `GET /api/activity` — bounded activity timeline projection.
- `GET /api/diagnostics` — fail-closed system/recovery status.
- `GET /api/approvals` — bounded pending approval queue.
- `GET /api/evidence?path=...` — contained evidence/artifact/report viewer.
- `GET /api/release-readiness` — validator-backed release readiness projection.
- `POST /api/approval` — approve/deny an eligible exact queued request through canonical authorization rules.
- `POST /api/scheduler-action` — explicit canonical apply/remove only where appropriate.
- `POST /api/recovery/reset-policy` — owner-approved reset through canonical Policy Manager to safe Observe-only state.

No new endpoint may accept a raw shell command, arbitrary path, arbitrary URL, raw HTML, or an unbounded payload.

## Coverage conclusion

The v2.1 engine already provides the required authority primitives but not a complete human operating surface. The main missing pieces are manual-run orchestration, bounded Dashboard projections, approval-queue presentation, live status, plain-language navigation and recovery/readiness views. These treatments are implemented. Local portable and Windows-native Dashboard red-team suites pass; cross-platform CI remains the final release-candidate gate.
