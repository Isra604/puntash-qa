# v2.1.0 Automation & Agent Permission Control Center

Status: READY FOR OWNER RELEASE APPROVAL
Target release: v2.1.0
Owner / original creator and project architect: Ofir Israeli

## Goal

Add user-controlled scheduled QA and explicit agent remediation permissions without weakening v2.0.0 reliability, human acceptance, privacy, or protected-boundary safeguards.

## Design principles

- Scheduling is opt-in. No background task is created without explicit human approval.
- Agent permissions are explicit, persistent, visible in the dashboard and may never be self-elevated by the agent.
- A configured permission preset is a maximum authority ceiling, not an instruction that every possible change must be made.
- Protected/high-impact categories remain approval-gated even in the broadest remediation preset.
- Scheduled QA may run automatically only when an actual executor is configured. Schedule intent without an executor must be shown as BLOCKED/NEEDS EXECUTOR rather than pretending automation is active.
- Dashboard control API binds to loopback only, uses an ephemeral port and per-session control token, and sends no data to the network.
- Existing file-only dashboard remains readable if opened directly, but policy mutation requires the local Control Center launcher.
- Owner policy/history/state survive update and rollback.
- No telemetry is added.

## User-facing permission presets

1. REPORT_ONLY — inspect, test, preserve evidence and report; no product remediation.
2. SAFE_FIXES — may automatically perform only LOW change-risk, reversible, unambiguous fixes outside protected boundaries.
3. ACTIVE_REMEDIATION — may automatically perform LOW/MEDIUM change-risk fixes supported by evidence; HIGH/PROTECTED changes still require explicit owner approval.
4. CUSTOM — owner-selected categories/limits, always capped by hard safety boundaries.

Severity and change risk are independent. A Critical finding may have a low-risk fix, and a Low finding may require a high-risk architectural change. Permission enforcement is based on change risk/category/authority, not finding severity alone.

## Schedule model

- Disabled by default.
- Daily local-time schedule is the primary simple mode.
- Optional weekday/custom recurrence can be added without changing policy schema.
- Executor modes:
  - UNCONFIGURED — schedule cannot execute.
  - LOCAL_COMMAND — OS scheduler invokes a human-approved local agent/CLI command.
  - AGENT_MANAGED — an AI platform with native scheduling owns execution; local package records and displays policy/status only.
- Local-command execution never uses `eval`/`Invoke-Expression`; executable and argument list are invoked structurally.
- Overlapping scheduled runs are prevented by a lock.

## Phases

### Phase 0 — Durable plan and branch
Status: COMPLETE
- Dedicated `feature/v2.1-control-center` branch.
- Durable implementation/checkpoint files.

### Phase 1 — Owner policy and permission engine
Status: COMPLETE
- Add owner policy schema/template.
- Add immutable hard-boundary permission policy.
- Add policy validator/manager.
- Update authoritative agent instructions and first-run behavior.

### Phase 2 — Scheduler/executor
Status: COMPLETE
- Windows Task Scheduler support.
- Portable scheduled-run contract and overlap lock.
- Unix cron support where available.
- Explicit executor readiness/status.

### Phase 3 — Dashboard Control Center
Status: COMPLETE
- Loopback-only local control server.
- Schedule and permissions UI.
- Read-only fallback when opened directly.
- Compact current status on main dashboard.

### Phase 4 — Install/update/rollback integration
Status: COMPLETE
- Initialize owner policy safely.
- Preserve owner policy/scheduler state.
- Agent asks owner if policy still unconfigured.
- Never fabricate an owner choice.

### Phase 5 — Red-team and CI
Status: COMPLETE
- Attempt agent self-elevation.
- Attempt protected change under ACTIVE_REMEDIATION.
- Attempt schedule enable without human policy approval.
- Attempt command injection in local executor.
- Attempt network bind beyond loopback.
- Test update/rollback preservation and dashboard read-only fallback.

### Phase 6 — Release
Status: READY FOR OWNER APPROVAL
- Cross-platform CI: COMPLETE on the release candidate.
- Merge to main: BLOCKED pending explicit owner approval.
- Tag/release v2.1.0: BLOCKED pending explicit owner approval.
- Anonymous public download/SHA/update detection verification: POST-RELEASE step, not executable before owner approval.

## Resume rule

Read this file and `docs/V2_1_CHECKPOINT.json`; continue from the first incomplete phase.

### 2026-08-27 — Phase 1 COMPLETE
- Added OWNER_POLICY schema/template with safe unconfigured REPORT_ONLY default.
- Added managed permission policy with REPORT_ONLY, SAFE_FIXES, ACTIVE_REMEDIATION and CUSTOM presets.
- Hard boundaries override every preset; HIGH/PROTECTED cannot be auto-authorized.
- Added PowerShell/Python policy managers and append-only policy history.
- Policy mutation requires explicit owner approval source; agent instructions forbid self-elevation.
- Executor credentials/tokens are rejected from OWNER_POLICY.
- Red-team evidence: self-elevation blocked, custom HIGH blocked, secret persistence blocked, audit history PASS.

### 2026-08-27 — Phase 2 COMPLETE
- Added owner-approved scheduled-run runners for PowerShell and Python/Unix.
- Scheduled runner rechecks Human Acceptance + OWNER_POLICY on every invocation and blocks overlap with a lock.
- Added structured local executor invocation without eval/Invoke-Expression and local stdout/stderr logs.
- Added Windows Task Scheduler registration/removal and Unix cron registration where available.
- Added AGENT_MANAGED mode with explicit NEEDS_PLATFORM_ACTIVATION vs ACTIVE state.
- Real Windows Task Scheduler registration/removal PASS without Administrator.
- Runner Human Acceptance gate PASS; Unix syntax contract PASS.

### 2026-08-27 — Phase 3 COMPLETE
- Added loopback-only Windows Dashboard Control Center with ephemeral/random port support and per-session token.
- Added local CSP/no-store headers and token-gated mutation APIs.
- Dashboard main screen now shows compact Agent Permissions and Scheduled QA cards.
- Settings UI exposes the three simple owner presets requested: Report only, Safe fixes, Active remediation.
- Scheduling UI supports simple Daily/Weekdays setup plus executor state; advanced weekly/custom policy remains available in OWNER_POLICY.
- Direct file opening remains read-only and still displays policy/scheduler state from dashboard data.
- Control Center mutation delegates to the already-validated policy manager and scheduler rather than duplicating permission logic.
- Validation: PowerShell parse PASS, dashboard JS PASS, loopback lifecycle PASS, safe initial policy PASS, read-only data/fallback PASS.

### 2026-08-27 — Phase 4 COMPLETE
- Fresh installs initialize an unconfigured REPORT_ONLY owner policy with scheduling disabled; no owner choice is fabricated.
- Direct v2.0.0 -> v2.1.0 compatibility preserved despite the already-released v2.0 updater not knowing new config/prompts paths: compatibility copies live under the v2.0-managed `templates/` tree and runtime tools fall back to them.
- Dashboard refresh safely materializes OWNER_POLICY after a direct v2.0 update, so the old updater's post-update refresh completes initialization.
- Owner policy, audit history, reports, evidence, profile and state survive update/rollback.
- Rollback pauses/removes scheduled execution before restoring an older runtime; owner choices remain preserved for a future re-upgrade/reactivation.
- Added portable Python loopback Control Center and shell launcher for macOS/Linux in addition to Windows PowerShell control server.
- Added mechanical `authorize-change` decision engine; automatic remediation requires an explicit ALLOW based on owner preset, change risk, category, expected-behavior proof, reversibility where required, and hard boundaries.
- Validation: direct released-v2.0 updater layout simulation PASS; portable Control Center token/mutation/shutdown PASS; mechanical permission Red-Team PASS.


### 2026-08-28 — Phase 5 COMPLETE / release candidate validated
- Functional candidate SHA: `63d662314bd7680a1a17dc9299e438fcc818e0f7`.
- GitHub Actions run `33124840958`: Windows PASS, Ubuntu PASS, macOS PASS.
- CI logs independently confirmed execution and PASS evidence for timeout/process-tree termination, rollback scheduler safety, native Windows authorization, Windows scheduler lifecycle, Windows Control Center, portable Control Center, policy fuzzing, AGENT_MANAGED runtime lifecycle, concurrency, Unix fake-crontab scheduler tests, v1.4 -> v2.1 rollback, and v2.0 -> v2.1 rollback.
- Legal-document bytes are deterministic UTF-8/LF and SHA-256 matches the Git index and `LEGAL_MANIFEST.json`.
- Local final package self-test, both upgrade/rollback paths, rollback scheduler safety, and 60-second process-tree timeout test all PASS.
- Repository secret scan and private-project isolation scan PASS.
- No merge, tag, or public v2.1.0 release was performed. Publication authority remains with the owner.
