# PUNTASH QA — Dashboard Release Master Work Plan

**Document role:** Canonical source of truth for the next PUNTASH QA release focused exclusively on the Dashboard and human-friendly control experience.

**Product:** PUNTASH QA
**Subtitle:** Universal Comprehensive QA Gate System
**Release version:** 2.2.0
**Workstream:** Dashboard-only release
Original creator and project architect: Ofir Israeli
Copyright © 2026 Ofir Israeli

---

## 1. Purpose of this document

This file is the mandatory execution plan for the Dashboard release.

It exists so that no requirement, product decision, safety constraint, UX goal, or feature discussed for this release is lost while implementation progresses.

Before starting a new implementation stage, the working agent must read this document and use it as the release checklist. When a requirement is implemented, tested, changed, rejected, or superseded, this document must be updated with the evidence and decision.

The release is not complete merely because the Dashboard looks better. It is complete only when the Dashboard becomes the practical operating surface for PUNTASH QA.

---

## 2. Release vision

PUNTASH QA already has a powerful QA engine. This release turns the Dashboard into the human-friendly operating system for that engine.

The Dashboard must allow a person to understand and safely control PUNTASH QA without needing to:

- open a terminal for normal operation
- edit JSON or YAML
- understand internal Gate IDs
- understand scheduler implementation details
- understand authorization internals
- read raw logs to know what happened
- know how PUNTASH QA works internally before making a safe decision

The governing product statement for this release is:

> **A user should never need to open a terminal, edit JSON, understand a Gate ID, or know how PUNTASH QA works internally in order to control it safely.**

Technical details must remain available for advanced users and auditing, but they belong behind a secondary **Technical details** layer rather than in the primary user flow.

---

## 3. Scope boundary

This release is intentionally focused on the Dashboard.

### In scope

- Dashboard information architecture
- Dashboard visual hierarchy and navigation
- Plain-language status and explanations
- GUI control over existing safe PUNTASH QA capabilities
- SCAN NOW
- scan progress and live state
- scheduled scan management
- permissions and remediation-policy control
- owner approval flows
- findings and explanations
- remediation history
- before/after views
- undo where technically safe and supported
- activity timeline
- health history
- changes since previous scan
- recovery and self-diagnosis surfaces
- release-readiness view
- onboarding
- overview/details split
- evidence and technical-details access
- dashboard accessibility and responsive behavior
- safe API/control endpoints required by the Dashboard
- Dashboard-specific QA, security and adversarial testing

### Not a goal of this release

- adding unrelated QA gates simply to increase capability count
- redesigning the underlying 25-gate / 9-lens QA model unless Dashboard work exposes a real correctness blocker
- changing protected authorization boundaries to make the UI easier
- weakening Owner Policy or Permission Policy for convenience
- replacing evidence requirements with cosmetic status indicators
- turning the Dashboard into a developer console
- exposing secrets, raw credentials, private tokens, or protected policy internals
- making the Dashboard dependent on cloud telemetry

---

## 4. Core UX principles

### 4.1 Start with the answer, not the internals

The Home screen must answer, in this order:

1. What is the state of my project?
2. Is there anything I need to care about?
3. What did PUNTASH QA do?
4. What can I do now?

Internal Gate/Lens identifiers are secondary metadata.

### 4.2 Plain language only

Primary UI copy must use short, direct, understandable language.

Avoid unnecessarily formal English, jargon, or internal architecture vocabulary.

Prefer:

- `Needs attention`
- `Could not verify`
- `Safe to continue`
- `PUNTASH QA needs your approval`
- `No problem found`
- `Not checked yet`
- `This change can be undone`

Avoid as primary UI language:

- `POLICY_INVALID`
- `MATERIAL_PASS_FORBIDDEN`
- `authorization_id`
- `AGENT_MANAGED_ACTIVE`
- raw enum values
- raw Gate IDs

Those may appear under **Technical details**.

### 4.3 No patronizing user modes

Do not label people as Beginner, Basic, Non-technical, Expert, or similar.

Use only:

- **Overview** — what the user needs to know and control
- **Details** — deeper evidence and technical information

### 4.4 Explain decisions in context

Wherever a user may need to make a decision, provide a short explanation next to that decision.

The Dashboard must repeatedly answer:

- What is this?
- Why does it matter?
- What will PUNTASH QA do?
- What can go wrong?
- Can this be undone?
- Does this require my approval?

### 4.5 Safety is never hidden for simplicity

Simplifying language must not simplify away risk.

The Dashboard may hide technical implementation details, but it must never hide:

- whether a change will modify files
- whether approval is required
- whether a change is reversible
- risk level
- protected-boundary status
- whether verification succeeded or failed
- whether evidence is incomplete

### 4.6 Local-first remains mandatory

Dashboard controls remain local and loopback-bound unless a future explicitly approved release changes that architecture.

No telemetry is added by this release.

---

## 5. Mandatory Dashboard information architecture

The release should converge on the following top-level experience.

### 5.1 Home / Overview

Purpose: answer "What is happening with my project?" immediately.

Required content:

- overall project health
- last scan time
- next scheduled scan
- current scan state if one is running
- number of items needing attention
- number of unresolved blockers
- number of safe automatic fixes completed
- release-readiness summary
- prominent **SCAN NOW** action
- recent activity summary

Example language:

```text
Your project looks good.
The last scan finished 18 minutes ago.
2 things are worth reviewing.
Nothing currently blocks your work.
```

Health states must be meaningful, not merely color-coded.

Possible primary states:

- Good
- Needs attention
- Action required
- Scan in progress
- Could not fully verify
- Not scanned yet

Color is supplemental, never the only signal.

---

## 6. SCAN NOW

A prominent **SCAN NOW** control is mandatory.

### Requirements

- Available from Home without navigating into technical settings.
- Must not silently bypass scheduler/authorization safety rules.
- Must refuse or explain clearly when a scan cannot start.
- Must prevent accidental overlapping runs using existing locking guarantees.
- Must expose progress in human language.
- Must expose cancel/stop only if cancellation is technically safe and correctly implemented.
- Must return the user to a clear scan summary at completion.

### Live progress experience

Do not show raw console output as the primary experience.

Example:

```text
PUNTASH QA is scanning your project

Checking project structure...
Checking security...
Checking tests...
Checking risky changes...
Preparing your report...

14 of 25 checks complete
```

Advanced logs may be available under **Technical details**.

---

## 7. "What is PUNTASH QA doing right now?"

A persistent live-status surface is required while work is active.

It should show:

- current action
- start time
- current stage/check group
- progress when determinable
- whether PUNTASH QA is only checking or also applying an approved remediation
- whether user action is required

It must never claim percentage precision that the engine cannot actually calculate.

---

## 8. Human-readable checks instead of Gate-first UI

The 25 canonical gates remain authoritative internally.

The default Dashboard should organize them into understandable areas such as:

- Security
- Tests
- Project structure
- Dependencies
- Reliability
- Data protection
- Release safety
- Change safety
- Configuration
- Operational health

Each user-facing check must answer:

- **What does this check?**
- **Why does it matter?**
- **What did PUNTASH QA find?**

Internal IDs such as `GATE-17` remain visible in **Technical details** for auditability.

---

## 9. Findings experience

Every finding must follow the primary pattern:

> **What happened → Why it matters → What can be done**

Example:

```text
A dependency may be outdated

Why this matters:
It could cause compatibility problems later.

Recommended action:
Update the dependency after verifying compatibility.

Risk: Medium
PUNTASH QA has not changed anything yet.
```

Potential actions:

- Fix safely
- Approve change
- Do not approve
- Leave it for now
- Explain
- View evidence
- Technical details

Only actions actually supported by the authorization model may be shown.

---

## 10. Explain control

An **Explain** action should be available throughout the Dashboard where useful.

Required contexts include:

- findings
- permissions
- scheduled scans
- approval requests
- blocked states
- release readiness
- recovery errors
- automatic fixes
- unfamiliar quality checks

The explanation must be contextual and short by default.

Example:

```text
Why does PUNTASH QA need this permission?

It found a small problem in one configuration file.
Fixing it would change that file, so your current settings require approval first.
The proposed change is reversible.
```

---

## 11. Permissions Center

The Dashboard must provide safe GUI control over the current Owner Policy / remediation presets.

Primary choices should be understandable descriptions rather than internal preset names.

Recommended user-facing presentation:

### Observe only

PUNTASH QA checks the project but does not change files automatically.

### Fix safe things

PUNTASH QA may automatically fix small, reversible problems that meet the configured safety rules.

### More active protection

PUNTASH QA may also perform additional reversible remediation permitted by the owner policy, while protected areas still require explicit owner approval.

The exact mapping to canonical presets must remain deterministic and documented.

### Mandatory transparency

The Permissions Center must always show a human-readable "PUNTASH QA will never automatically change" section covering protected categories such as:

- production authority
- credentials/secrets
- QA authority and policy
- CI/CD authority
- version-control metadata
- other canonical protected boundaries

Do not make policy choices look like casual preferences. The UI must communicate that they change what PUNTASH QA is allowed to modify.

---

## 12. Schedule Builder

Scheduling must be controllable without exposing cron syntax or OS Task Scheduler details.

Required GUI controls:

- automatic scans ON/OFF
- frequency
- time
- day(s) where applicable
- next run time
- scheduler health
- active platform/backend state in plain language
- clear cleanup/deactivation state when required

Example:

```text
Run automatically   ON
How often?          Every day
At what time?       03:00
Next scan           Tomorrow at 03:00
```

Technical scheduler IDs and signatures belong under **Technical details**.

All existing fail-closed scheduler lifecycle behavior must remain intact.

---

## 13. Activity Timeline

A chronological activity timeline is mandatory.

The user should be able to answer "What has PUNTASH QA been doing?" without reading reports.

Example:

```text
22:41  Scan completed
22:38  One safe configuration issue fixed
22:35  Scan started
Yesterday  No issues found
Tuesday    Permissions changed to Fix safe things
```

Each event should open into additional context and evidence where available.

Include events for:

- scan started/completed/failed/blocked
- finding opened/resolved
- automatic remediation performed
- owner approval granted/denied
- permission-policy changes
- scheduler changes
- recovery actions
- rollback/undo events

---

## 14. Before / After remediation view

Automatic changes must be understandable after they happen.

Required presentation:

```text
PUNTASH QA changed one file.

Before:
The configuration allowed an unsafe value.

After:
The value is now restricted.

Verified after change: Yes
Reversible: Yes
```

Where safe rollback support actually exists, present an **Undo** action.

Never show Undo if the system cannot guarantee the required rollback semantics.

Technical diff may be available under **Technical details**.

---

## 15. Owner approval screens

Owner approval must have a dedicated, safe decision screen.

Required fields in plain language:

- what PUNTASH QA wants to change
- exact target file(s)
- why it wants to change them
- finding being addressed
- risk
- whether expected behavior is proven
- whether the change is reversible
- what verification will occur after the change

Example:

```text
PUNTASH QA needs your approval

It wants to change:
src/config.ts

Why:
To fix "Unsafe configuration value".

Risk: Low
Can this be undone? Yes

[ Approve ]   [ Do not approve ]
```

The GUI must call the canonical authorization machinery. It must not create a second, weaker authorization path.

---

## 16. Project Health History

Provide an understandable health history over time.

The purpose is not to create a vanity score. It is to explain trend and change.

Example:

```text
Mon   Good
Tue   Good
Wed   Needs attention
Thu   Good
Fri   Good
```

When health changes, explain why:

> Your project changed to "Needs attention" because two new findings appeared after Wednesday's changes.

Avoid invented precision such as a 93/100 score unless a future documented scoring model has real meaning and validation.

---

## 17. "What changed since my last scan?"

This is a mandatory comparison view.

Possible summary:

```text
Since the previous scan:

14 files changed
2 dependencies changed
1 new QA finding
3 previous findings were resolved
No new security problem was detected
```

The comparison must distinguish between observed project changes and PUNTASH QA remediation changes.

---

## 18. Release readiness

Provide a direct answer to:

```text
Ready to release?
```

Possible states:

- Ready
- Not yet
- Could not fully verify

If not ready, show the reasons and direct navigation to them.

Example:

```text
Not yet

2 things still need attention before release.
[ View them ]
```

This view must derive from real gate/lens/evidence state. It may not turn incomplete verification into a reassuring green state.

---

## 19. Recovery Center

The Dashboard must explain problems with PUNTASH QA itself in plain language.

Examples include:

- Owner Policy invalid
- scheduler registration inconsistent
- legal acceptance invalid/stale
- evidence store inaccessible
- runtime state corrupt
- Control Center unable to bind safely

Example:

```text
PUNTASH QA needs attention

Your permission settings could not be verified.
No automatic changes will be made until this is fixed.

[ Repair safely ]
```

The Recovery Center must preserve fail-closed behavior.

A one-click repair is allowed only where the existing recovery contract can prove it is safe and owner-authorized.

---

## 20. First-run onboarding

Do not create a long tutorial.

The first-run experience should explain the product in a few steps:

```text
PUNTASH QA checks your project using 25 quality gates.
It will not make protected changes without your approval.
You can start in Observe only and change this later.

[ Start first scan ]
```

First-run onboarding should also establish:

- current permission mode
- whether automatic scans should be enabled
- what SCAN NOW does
- where findings and history will appear

Human Terms acceptance remains a separate protected legal step and must not be auto-accepted by onboarding.

---

## 21. Overview and Details modes

### Overview

Shows:

- health
- plain-language findings
- scan controls
- schedule controls
- permissions
- approval requests
- recent activity
- release readiness
- recovery state

### Details

Shows deeper information such as:

- Gate ID
- Lens ID
- authorization ID
- policy revision
- evidence refs
- raw report
- technical diff
- JSON where appropriate
- scheduler signatures/IDs

The same underlying source of truth must power both modes.

---

## 22. Ask PUNTASH / Dashboard search

Design the Dashboard so it can support a natural question/search surface.

Target user questions include:

- Why is my project yellow?
- What changed today?
- What did PUNTASH QA fix?
- Is anything blocking a release?
- Why does this need my approval?
- When is the next scan?
- What does this check mean?

### Release requirement

At minimum, this release should provide a useful searchable/navigable information surface.

A true AI conversational layer is optional for this release and must not be added unless it can be done without weakening local privacy, authorization boundaries, determinism, or release scope.

The UI should be architected so a future conversational layer can be added cleanly.

---

## 23. Status language contract

Raw status enums remain canonical internally, but the Dashboard must translate them.

Examples:

| Internal state | Primary user-facing language |
|---|---|
| `PASS` | Checked and verified / No problem found |
| `FAIL` | Problem found |
| `BLOCKED` | Could not complete this check |
| `NOT_RUN` | Not checked yet |
| `NOT_APPLICABLE` | This check does not apply here |
| `POLICY_INVALID` | Permission settings could not be verified |
| scheduler cleanup required | Automatic scans are off, but cleanup is still required |

Every translation must preserve the original meaning. Do not turn uncertainty into success.

---

## 24. Dashboard control coverage requirement

Every existing user-relevant PUNTASH QA capability must be reviewed and classified into one of these categories:

1. **Direct Dashboard control**
2. **Dashboard control requiring Owner approval**
3. **Dashboard view only — protected action cannot be initiated automatically**
4. **Technical/internal capability intentionally not exposed as a user control**

A release-blocking coverage matrix must be created before implementation is declared complete.

Initial capability inventory includes at least:

- manual scan
- scheduled scan enable/disable
- schedule frequency/time
- scheduler lifecycle state
- permission preset changes
- custom permission settings where safely supportable
- remediation authorization
- finding disposition where supported
- automatic remediation visibility
- remediation rollback/undo where supported
- reports/history
- evidence viewing
- policy health
- scheduler health
- Terms/acceptance status display
- release readiness
- recovery actions
- update availability/status where appropriate
- Dashboard/Control Center status

The release is not complete if a normal user must use a terminal for a routine capability that can safely and correctly be represented in the Dashboard.

---

## 25. Dashboard security invariants

The Dashboard release must preserve or strengthen all v2.1.0 safety boundaries.

Mandatory invariants include:

- loopback-only control service
- authenticated control endpoints
- control token removed from URL after bootstrap
- no secrets in static Dashboard data
- no direct serving of protected `state/`
- no arbitrary filesystem reads
- report path containment
- XSS-safe rendering
- no command injection
- no `shell=True` / unsafe eval path
- Owner Policy remains canonical authority
- Permission Policy remains canonical ceiling
- Target Scope authorization remains mandatory
- protected paths cannot be auto-remediated through the GUI
- Dashboard cannot self-elevate permissions
- scheduling cannot grant remediation authority
- recovery remains fail-closed
- all automatic changes remain reversible where required by policy
- evidence reality checks remain intact
- untrusted project content never becomes Dashboard/agent authority

Any new Dashboard API endpoint must receive threat modeling and negative tests before release.

---

## 26. Accessibility and usability requirements

The Dashboard must be usable without relying only on color.

Required considerations:

- clear focus states
- keyboard navigation for primary actions
- readable contrast
- meaningful labels for controls
- responsive layout
- no essential information hidden only in hover states
- confirmation for consequential actions
- clear disabled-state explanations
- understandable empty states
- understandable loading states
- understandable failure states
- no modal overload

The Dashboard should remain functional on common desktop browser sizes. Mobile responsiveness should be improved where practical, but desktop is the primary operating environment unless product requirements change.

---

## 27. Copy and terminology rules

Primary UI language must be concise, plain English.

### Rules

- Prefer one idea per sentence.
- Prefer common words over formal synonyms.
- Explain unavoidable QA terminology the first time it appears.
- Do not expose internal enum names as user copy.
- Do not write paragraphs where one sentence is enough.
- Do not say a check is safe when it is merely incomplete.
- Distinguish `not found` from `not checked`.
- Distinguish `blocked` from `failed`.
- Distinguish `recommended` from `required`.
- Distinguish `PUNTASH QA changed` from `project changed`.
- Do not imply an automatic fix was performed unless authorization and post-change evidence prove it.

Every major screen should undergo a dedicated copy review before release.

---

## 28. Proposed screen map

The working screen map is:

1. **Home**
2. **Scan / Live scan**
3. **Findings**
4. **Activity**
5. **Permissions**
6. **Schedule**
7. **Project health**
8. **Release readiness**
9. **Recovery**
10. **Settings / About**
11. **Details / Evidence** as contextual secondary surfaces rather than a developer-first landing area

This map may be refined during information-architecture work, but all capabilities in this document must remain covered.

---

## 29. Implementation stages

### Stage 0 — Baseline and capability inventory

Deliverables:

- inventory all existing Dashboard features
- inventory all existing runtime capabilities
- map each capability to the four Dashboard-control categories
- document existing API/control endpoints
- document current Dashboard data sources
- record baseline screenshots and behavior
- identify missing UI controls and unsafe direct-control candidates

Exit gate:

- complete capability coverage matrix exists
- no current capability is forgotten

### Stage 1 — Information architecture and UI state model

Deliverables:

- final navigation model
- Home hierarchy
- Overview/Details contract
- status translation table
- copy guidelines implemented as shared constants/data where practical
- canonical Dashboard state model

Exit gate:

- every current runtime state has a safe user-facing representation

### Stage 2 — Home + SCAN NOW + live scan

Deliverables:

- Home summary
- SCAN NOW
- scan-start API
- overlap protection integration
- live scan state
- progress messaging
- completion summary
- blocked/failure states

Exit gate:

- a user can run a scan and understand its outcome without terminal/log access

### Stage 3 — Findings + Explain + evidence

Deliverables:

- plain-language finding cards
- what/why/action structure
- Explain interaction
- evidence viewer
- technical-details layer

Exit gate:

- findings can be understood and investigated without raw report reading

### Stage 4 — Permissions Center

Deliverables:

- human-readable modes
- current effective permissions
- protected-boundary explanation
- safe preset changes through canonical Policy Manager
- confirmation and audit trail
- policy-invalid recovery state

Exit gate:

- no weaker parallel policy path exists

### Stage 5 — Schedule Builder

Deliverables:

- enable/disable
- frequency/time/day controls
- next-run display
- platform activation/update/deactivation states
- cleanup-required explanation
- scheduler recovery guidance

Exit gate:

- normal scheduling tasks require no cron/Task Scheduler knowledge

### Stage 6 — Approval and remediation controls

Deliverables:

- approval queue
- exact target-path display
- risk/reversibility/evidence summary
- Approve / Do not approve actions
- canonical authorization integration
- before/after remediation view
- Undo where proven safe

Exit gate:

- GUI cannot bypass v2.1 authorization invariants

### Stage 7 — Activity, history and "what changed"

Deliverables:

- activity timeline
- scan history
- health history
- remediation history
- previous-scan comparison
- project-vs-PUNTASH change distinction

Exit gate:

- a user can explain what PUNTASH QA has done over time

### Stage 8 — Release readiness + Recovery Center

Deliverables:

- Ready to release state
- blockers/reasons
- navigation to unresolved items
- policy/scheduler/runtime recovery cards
- fail-closed repair actions where supported

Exit gate:

- no false-green release readiness state is possible

### Stage 9 — Onboarding + search/Ask surface + polish

Deliverables:

- short first-run onboarding
- first scan path
- search / Ask PUNTASH navigation surface
- responsive layout refinement
- accessibility review
- full copy review
- empty/loading/error states

Exit gate:

- first-time use is understandable without documentation

### Stage 10 — Final Dashboard adversarial QA

Mandatory attack areas:

- authorization bypass via UI
- policy elevation through UI
- scheduler authority confusion
- CSRF-like local control misuse where applicable
- token leakage
- URL/history leakage
- XSS from project-controlled content
- HTML injection from findings/evidence
- path traversal through evidence/report viewers
- symlink/junction path escape
- arbitrary command execution through GUI inputs
- overlapping scans
- double-click/double-submit races
- stale-state actions
- stale approval reuse
- interrupted scan recovery
- corrupt policy/scheduler state
- huge/hostile log or evidence rendering
- malformed JSON/report data
- accessibility regressions
- misleading PASS/health copy
- permission mode mismatch between UI and canonical policy

Exit gate:

- Windows, Ubuntu and macOS CI pass all Dashboard and existing system tests
- final package audit passes
- no known Dashboard release blocker remains

---

## 30. Definition of Done

The Dashboard release is complete only when all items below are true.

### Product

- [x] Home answers project status immediately.
- [x] SCAN NOW exists and is safe.
- [x] Live scan status is understandable.
- [x] Findings use what/why/action language.
- [x] Explain exists in the required contexts.
- [x] Permissions are controllable through GUI.
- [x] Schedule is controllable through GUI.
- [x] Approval requests are understandable and mechanically safe.
- [x] Activity timeline exists.
- [x] Before/after remediation view exists.
- [x] Undo is shown only where proven safe.
- [x] Project health history exists.
- [x] Changes since last scan are understandable.
- [x] Release readiness exists and cannot false-PASS.
- [x] Recovery Center exists.
- [x] First-run onboarding exists.
- [x] Overview / Details separation exists.
- [x] Search / Ask surface exists at the agreed release scope.
- [x] Every user-relevant existing PUNTASH QA capability has a documented Dashboard treatment.

### Language and usability

- [x] Primary copy is plain English.
- [x] Internal enums are not primary UI copy.
- [x] Technical details remain accessible.
- [x] Color is not the only status signal.
- [x] Consequential actions explain impact before execution.
- [x] Empty, loading, blocked and error states are understandable.
- [x] Keyboard/focus/accessibility review is complete.

### Security and correctness

- [x] Loopback-only boundary remains intact.
- [x] Dashboard authentication remains intact.
- [x] Owner Policy remains canonical.
- [x] Permission Policy remains canonical.
- [x] Target Scope authorization remains mandatory.
- [x] Protected paths remain protected.
- [x] Scheduling cannot elevate remediation authority.
- [x] GUI cannot create synthetic/fake evidence.
- [x] GUI cannot reuse stale authorization improperly.
- [x] project-controlled text cannot execute or gain authority through rendering.
- [x] new control endpoints have negative security tests.
- [x] no XSS/path traversal/command injection blocker remains.

### QA and release

- [x] Existing 25 Gates still pass.
- [x] Existing 9 Reliability Lenses still pass.
- [x] Existing v2.1 adversarial suites still pass.
- [x] New Dashboard-specific adversarial suite passes.
- [ ] Windows CI passes.
- [ ] Ubuntu CI passes.
- [ ] macOS CI passes.
- [x] Upgrade/rollback compatibility decision is documented and tested.
- [ ] final release package provenance/reproducibility passes.
- [ ] final public artifact audit passes before closure.

---

## 31. Mandatory release evidence

The final Dashboard release report must include at least:

- implementation SHA
- final main SHA
- CI run IDs
- Windows result
- Ubuntu result
- macOS result
- Dashboard capability coverage matrix result
- Dashboard adversarial test result
- security review result
- accessibility/usability review result
- copy review result
- package SHA-256
- source commit/tree provenance
- public artifact verification
- open PR count
- working-tree state
- known residual risks, if any

No release may be described as complete while known blocking Dashboard findings remain open.

---

## 32. Change-control rule for this plan

This plan is the canonical release checklist.

During implementation:

- requirements may be refined when evidence proves a better design
- safety requirements may be strengthened at any time
- scope may not be silently dropped
- a removed requirement must be explicitly documented with rationale and owner decision when material
- newly discovered Dashboard risks must be added here before closure
- completed items must be backed by actual implementation/test evidence, not only marked complete in prose

---

## 32A. Live execution status

Current implementation branch: `feature/v2.2-dashboard-control-center`

Current release state: **IMPLEMENTATION_IN_PROGRESS**

Stage status:

- [x] Stage 0 — Baseline and capability inventory
- [x] Stage 1 — Information architecture and UI state model
- [x] Stage 2 — Home + SCAN NOW + live scan
- [x] Stage 3 — Findings + Explain + evidence
- [x] Stage 4 — Permissions Center
- [x] Stage 5 — Schedule Builder
- [x] Stage 6 — Approval and remediation controls
- [x] Stage 7 — Activity, history and what changed
- [x] Stage 8 — Release readiness + Recovery Center
- [x] Stage 9 — Onboarding + search/Ask surface + polish
- [ ] Stage 10 — Final Dashboard adversarial QA

Stage 0 evidence: `docs/V2_2_DASHBOARD_CAPABILITY_MATRIX.md`.

---

## 33. Starting checkpoint

Current product baseline:

```text
PUNTASH QA v2.1.0
RELEASED_PUBLICLY_VERIFIED
25 QA Gates
9 Reliability Lenses
Dashboard Control Center available
Owner Policy / Permission Policy / Scheduler / Authorization already implemented
```

Next release mission:

```text
Transform the existing Dashboard Control Center into the primary,
human-friendly operating surface for PUNTASH QA without weakening
any v2.1.0 safety, evidence, authorization, scheduling or release invariant.
```

Implementation has **not** started merely because this planning document exists.

The next action is to assign the release version and begin **Stage 0 — Baseline and capability inventory** on a dedicated implementation branch.

### v2.2 implementation evidence checkpoint — 2026-08-29

Stages 1–9 are implemented and locally verified. Stage 10 local adversarial QA is PASS on Windows, including the portable and native Control Center paths, authorization, path safety, scheduler lifecycle, rollback preflight, timeout/process-tree handling, v2.1 compatibility, and v2.1 → v2.2 upgrade/rollback.

Stage 10 remains open only for clean-HEAD reproducible-package proof and GitHub Actions Windows/Ubuntu/macOS evidence. Publication remains blocked pending explicit owner release approval.
