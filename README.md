# Universal Comprehensive QA Gate System

A portable, repository-aware QA operating system for AI coding agents and human QA teams.

It is designed to enter an unfamiliar project, discover how the project works, build a project-specific QA profile, execute a stable 25-gate quality model plus 9 mandatory cross-cutting reliability lenses, preserve evidence, identify cross-gate root causes, perform only explicitly safe remediation, revalidate changes, and produce a complete audit-ready report.

## Creator and attribution

**Original creator and project architect: Ofir Israeli**  
Copyright © 2026 Ofir Israeli.

Licensed under the MIT License. The copyright and permission notice must be preserved in copies or substantial portions of the Software. See `LICENSE`, `NOTICE`, and `CREDITS.md`.

## What makes it portable

The 25 gates are universal responsibility domains. Version 2.0.0 added 9 mandatory cross-cutting reliability lenses so important concerns cannot be hidden inside a broad gate: Test Trustworthiness, Privacy/Data Lifecycle, Compatibility/Upgrade Safety, Time/Locale/Precision/Encoding, Third-Party Failure/Quota Reality, Resource/Cost Exhaustion, AI Quality/Model Risk, Accessibility Depth, and Change Blast Radius. The checks inside each gate are selected dynamically from the project that is discovered. A web application, API, mobile app, CLI, data pipeline, infrastructure repository, automation project, or mixed monorepo can therefore use the same QA architecture without pretending that every check is relevant.

The system never turns an unexecuted or irrelevant check into a PASS. It uses PASS, FAIL, BLOCKED, NOT_RUN, and NOT_APPLICABLE with evidence.

## Human acceptance before installation

Current installers require affirmative human acceptance before the installer writes the QA runtime into a target project. v2.1.0 uses Terms version 1.1.0 so scheduled execution and persistent remediation authority are presented explicitly to upgraders.

- Windows uses an interactive GUI showing the legal documents, three explicit attestations, the exact phrase `I ACCEPT`, and a manual `Accept & Install` button.
- macOS/Linux refuses non-interactive execution and requires a natural person to review the terms and manually answer the acceptance prompts.
- There is no official silent, `--yes`, `--accept`, unattended, CI, or AI-agent acceptance path.
- A local acceptance receipt records the package/terms versions, timestamp, acceptance method, and SHA-256 hashes of the legal documents. The installer does not transmit that receipt.

An AI agent may inspect the package, explain it, and launch the installer, but the package instructions prohibit the AI agent from accepting the terms on behalf of a person.

## Install into any project

Windows Easy Start (recommended):

1. Extract the release ZIP.
2. Double-click `START_HERE_WINDOWS.cmd`.
3. Choose the target project folder.
4. Review and accept the mandatory human terms.

PowerShell remains available for advanced/manual installation:

```powershell
.\scripts\install.ps1 -ProjectPath "C:\path\to\project"
```

macOS/Linux:

```bash
./scripts/install.sh /path/to/project
```

The installer creates one self-contained folder in the target project:

```text
.comprehensive-qa/
```

It does not alter product source code, dependencies, CI/CD, database schema, deployment configuration, or Git history.

## QA Doctor

Version 1.3.0 runs a safe local QA Doctor readiness scan after installation. It records project/tooling signals in `.comprehensive-qa/state/QA_DOCTOR.json` and `.md`. Doctor output is only a discovery hint and never a QA PASS result.

## Start the agent

Open `.comprehensive-qa/START_HERE.md` for the simplest handoff. Give the QA-capable agent filesystem access to the project, then instruct it:

```text
Read .comprehensive-qa/AGENT_INSTRUCTIONS.md in full. Perform the discovery phase first. Do not assume the stack, product contract, test commands, environments, or authority boundaries. Build the project QA profile, map all 25 gates and all 9 reliability lenses, classify evidence assurance, then execute the authorized QA cycle and preserve evidence exactly as instructed.
```

For ChatGPT Projects, `CHATGPT_PROJECT_INSTRUCTIONS.md` contains a copy-ready project instruction block.

## Required agent capabilities

Minimum useful mode:
- recursive file/folder reading
- Git state inspection
- ability to read project documentation and configuration

Strong mode:
- safe shell/test execution
- structured Git diff/status
- browser automation for UI projects
- application logs/metrics access
- database/infrastructure connectors when authorized
- write access for delegated low-risk remediation

If a capability is unavailable, the affected gate becomes BLOCKED, NOT_RUN, or NOT_APPLICABLE. The system must never fabricate evidence.

## Package layout

- `skill.md` — portable behavior specification.
- `CHATGPT_PROJECT_INSTRUCTIONS.md` — copy-ready project instructions.
- `runtime/AGENT_INSTRUCTIONS.md` — authoritative installed runtime behavior.
- `runtime/gates/` — the 25 gate specifications plus the v2 reliability policy/map and 9 lens specifications.
- `runtime/templates/` — report, evidence, finding, profile, remediation and closure templates.
- `runtime/config/default.yaml` — default policy and status model.
- `scripts/install.ps1` / `install.sh` — project installer.
- `scripts/verify-install.ps1` / `verify-install.sh` — installation verification.
- `docs/OPERATING_MODEL.md` — detailed lifecycle.
- `docs/TOOL_REQUIREMENTS.md` — capability model.
- `LICENSE` — MIT software license and warranty/liability disclaimer.
- `TERMS_OF_USE.md` — affirmative installation terms and responsibility allocation.
- `DISCLAIMER.md` — QA/AI/production risk disclaimer.
- `DATA_RESPONSIBILITY_NOTICE.md` — local receipt and project-data responsibility notice.
- `HUMAN_ACCEPTANCE.md` — mandatory natural-person acceptance protocol.
- `LEGAL_MANIFEST.json` — SHA-256 manifest of the presented legal documents.


## v2 reliability model

Version 2.0.0 is a reliability-focused major release. It keeps exactly 25 canonical gates and adds 9 mandatory cross-cutting lens decisions. Every material conclusion is classified as STRONG, MODERATE, WEAK, or INSUFFICIENT evidence. WEAK/INSUFFICIENT evidence cannot support material PASS, MODERATE PASS requires an explicit non-material gap attestation, and PASS/FAIL structured records require current evidence references. NOT_APPLICABLE requires current applicability evidence rather than a label alone.

Test results used as decisive evidence are themselves subject to Test Trustworthiness review: oracle quality, flakiness, isolation, skipped/quarantined tests, mock fidelity, test-data relevance and defect sensitivity. Coverage percentage alone is never behavioral proof.

A machine validator checks the 25+9 run contract and rejects false-confidence states such as stale-evidence PASS, missing lenses, unsupported N/A, inflated overall assurance, and silent core gate/lens contradictions. See `docs/V2_RELIABILITY_IMPLEMENTATION.md` and `docs/V2_REDTEAM_REPORT.md`.

## Local dashboard

Version 1.4.0 adds a private local dashboard with QA Health, execution coverage, a calm 25-gate map, prioritized findings, run-to-run changes, health trend and persistent run history. On Windows, open `.comprehensive-qa/OPEN_DASHBOARD.cmd` after a QA cycle. The dashboard reads local structured run records only and does not add telemetry or upload project data. See `docs/DASHBOARD.md`.

## v2.1 automation and owner control

Version 2.1.0 adds an owner-controlled Automation & Permission Control Center while preserving the v2 reliability model. New installations remain **REPORT_ONLY with scheduling OFF** until the owner makes a separate operational choice; legal acceptance alone never grants remediation or scheduling authority.

Permission presets:
- `REPORT_ONLY` — inspect, test and report; no product remediation.
- `SAFE_FIXES` — only LOW change-risk, reversible, unambiguous fixes with proven expected behavior.
- `ACTIVE_REMEDIATION` — LOW/MEDIUM change-risk remediation may be automatic, but HIGH/PROTECTED changes still require explicit owner approval.

Before every automatic product mutation the agent must use the mechanical `authorize-change` decision tool. Hard boundaries cover architecture, public API contracts, authentication/authorization semantics, privacy/security policy, database schema/migrations, production data, credentials, deployments/production, paid operations and destructive actions. The agent may act more conservatively than the policy but may never self-elevate.

Scheduled QA is opt-in. Windows supports Task Scheduler; macOS/Linux use cron where available; AI platforms with their own scheduler can use `AGENT_MANAGED`. A saved schedule is never shown as active until an executable scheduler/executor is actually available. Scheduled runs revalidate the current human Terms receipt and human-approved owner policy on every invocation.

The dashboard Settings panel controls these choices through a loopback-only (`127.0.0.1`) Control Center with a per-session token. The package adds no telemetry. See `docs/AUTOMATION_AND_PERMISSIONS.md`.

## Updates

Version 1.2.0 adds a GitHub Releases update channel. On Windows, installed projects can check for a newer version, show the project owner an update prompt, verify the downloaded package with SHA-256, create a backup, preserve QA data, update managed runtime files, and roll back if validation fails. See `docs/UPDATES.md`.

This repository is public. Update checks and release downloads work anonymously through GitHub Releases; GitHub CLI authentication is not required for normal public updates.

## Safety principle

Discovery and reporting are always separated from mutation. Automatic remediation is opt-in and bounded. Protected changes are reported with evidence and authority requirements instead of being silently changed.

Version: 2.1.0 release candidate (not yet publicly released)
