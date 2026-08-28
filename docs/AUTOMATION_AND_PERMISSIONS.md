# Automation & Agent Permissions — v2.1

Status: release candidate documentation. Public v2.1.0 publication requires explicit owner approval.

## Safe default

A new or upgraded runtime never infers permission from installation. Until the owner explicitly chooses otherwise:

```text
Permissions: REPORT_ONLY
Scheduled QA: OFF
```

Legal Terms acceptance and operational authorization are separate decisions.

## Permission presets

### REPORT_ONLY
The agent may inspect, execute authorized QA checks, preserve evidence and report findings. It may not remediate product code/configuration.

### SAFE_FIXES
Automatic remediation is limited to LOW change-risk, reversible, unambiguous changes with expected behavior proven by current evidence.

### ACTIVE_REMEDIATION
LOW/MEDIUM change-risk remediation can be automatic when evidence proves expected behavior. HIGH and PROTECTED changes still require explicit owner approval.

Severity is not change risk. A Critical defect can have a LOW-risk fix; a Low-severity finding can require a protected architectural change.

## Mechanical authorization

Agent instructions alone are not the enforcement point. Before every automatic product mutation, the agent must invoke `tools/authorize-change.ps1` or `tools/authorize-change.sh` with the proposed change risk/category and relevant attestations. No ALLOW means no automatic mutation. Every ALLOW returns an AUTHORIZATION_ID that must be recorded with the remediation evidence; automatic changes must be reversible.

Hard boundaries override every preset, including architecture, public API contracts, security/privacy policy, authentication/authorization semantics, database schema/migrations, production data, credentials, deployments/production, billing/paid calls and destructive actions.

The agent may always act more conservatively than the configured ceiling and may never self-elevate. Owner-policy mutation requires explicit owner approval and is recorded in `state/OWNER_POLICY_HISTORY.jsonl`.

## Scheduling

Scheduling is opt-in and does not grant remediation permission. Supported executor modes:
- `UNCONFIGURED` — schedule intent can be saved but cannot run.
- `LOCAL_COMMAND` — a human-approved executable/argument list is launched structurally; no eval/Invoke-Expression/shell string execution.
- `AGENT_MANAGED` — an AI platform/native scheduler owns execution and the runtime records activation/status.

Windows uses Task Scheduler. Unix platforms use cron when available. Scheduled runners prevent overlap, enforce a bounded timeout, retain local stdout/stderr, prune scheduler logs with a bounded retention policy (30 days by default), and re-check the current Human Acceptance receipt plus human-approved Owner Policy on every invocation.

Do not store passwords, tokens, private keys or credentials in OWNER_POLICY.

## Dashboard Control Center

The interactive Control Center binds only to `127.0.0.1`, uses an ephemeral port and generates a per-session token. Direct file opening remains read-only. Unauthenticated static serving is restricted to dashboard assets; authenticated report access is restricted to `.comprehensive-qa/reports/`. The package adds no telemetry.

## Update and rollback

The v2.1 package preserves reports, evidence, state, owner policy and policy history. Rollback pauses scheduled execution before restoring an older managed runtime so a stale OS task cannot continue calling removed tools. The owner policy remains available for audit/reconfiguration.

Upgrading from Terms 1.0.0 to v2.1 Terms 1.1.0 requires renewed human acceptance through the updater before the new package is applied.

## Trust boundary

OWNER_POLICY, audit history and the local control token are application-level safety controls. They are not a cryptographic defense against malware, an administrator, or another process that already has unrestricted write/control access to the project and user account. Protect the workstation, repository and executor environment accordingly.

## Target-path authorization
Automatic remediation is exact-file scoped. Before mutation, the agent must submit every intended project-relative target path to `authorize-change`. QA authority/VCS/CI/credential paths, traversal, absolute paths and symlink/junction targets are denied. The final run record must prove that `files_changed` exactly matches the authorized target set.
