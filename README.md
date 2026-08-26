# Universal Comprehensive QA Gate System

A portable, repository-aware QA operating system for AI coding agents and human QA teams.

It is designed to enter an unfamiliar project, discover how the project works, build a project-specific QA profile, execute a stable 25-gate quality model, preserve evidence, identify cross-gate root causes, perform only explicitly safe remediation, revalidate changes, and produce a complete audit-ready report.

## What makes it portable

The 25 gates are universal responsibility domains. The checks inside each gate are selected dynamically from the project that is discovered. A web application, API, mobile app, CLI, data pipeline, infrastructure repository, automation project, or mixed monorepo can therefore use the same QA architecture without pretending that every check is relevant.

The system never turns an unexecuted or irrelevant check into a PASS. It uses PASS, FAIL, BLOCKED, NOT_RUN, and NOT_APPLICABLE with evidence.

## Install into any project

Windows PowerShell:

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

## Start the agent

Give the QA-capable agent filesystem access to the project, then instruct it:

```text
Read .comprehensive-qa/AGENT_INSTRUCTIONS.md in full. Perform the discovery phase first. Do not assume the stack, product contract, test commands, environments, or authority boundaries. Build the project QA profile, map all 25 gates, then execute the authorized QA cycle and preserve evidence exactly as instructed.
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
- `runtime/gates/` — the 25 gate specifications.
- `runtime/templates/` — report, evidence, finding, profile, remediation and closure templates.
- `runtime/config/default.yaml` — default policy and status model.
- `scripts/install.ps1` / `install.sh` — project installer.
- `scripts/verify-install.ps1` / `verify-install.sh` — installation verification.
- `docs/OPERATING_MODEL.md` — detailed lifecycle.
- `docs/TOOL_REQUIREMENTS.md` — capability model.

## Safety principle

Discovery and reporting are always separated from mutation. Automatic remediation is opt-in and bounded. Protected changes are reported with evidence and authority requirements instead of being silently changed.

Version: 1.0.0
