# Give This QA System to Another Project Owner

**Original creator and project architect: Ofir Israeli.** Copyright © 2026 Ofir Israeli. Licensed under MIT; keep `LICENSE`, `NOTICE`, and `CREDITS.md` with redistributed copies.

Send the recipient the ZIP file from `dist/`.

They extract it outside their project and run the installer against the project they want audited.

## Windows

```powershell
.\scripts\install.ps1 -ProjectPath "C:\path\to\their-project"
.\scripts\verify-install.ps1 -ProjectPath "C:\path\to\their-project"
```

## macOS / Linux

```bash
./scripts/install.sh /path/to/their-project
./scripts/verify-install.sh /path/to/their-project
```

After installation, they give their AI QA agent access to the project and send exactly this instruction:

```text
Read .comprehensive-qa/AGENT_INSTRUCTIONS.md in full. Perform Discovery first. Build the Project QA Profile from direct evidence. Map every one of the 25 QA gates to this project, then execute the strongest authorized comprehensive QA cycle. Never mark unavailable checks as PASS. Preserve per-gate evidence and produce the complete report. Do not modify product code unless I explicitly authorize SAFE automatic remediation.
```

## What happens next

The system first learns the repository instead of assuming what it contains. It maps languages, frameworks, architecture, tests, databases, APIs, environments, dependencies, product-critical journeys, security boundaries, observability, release process, and existing quality evidence.

It then creates a project-specific profile inside:

```text
.comprehensive-qa/profile/PROJECT_QA_PROFILE.md
```

All 25 universal gates remain visible. Their internal checks adapt to the discovered project. Gates that cannot run are BLOCKED or NOT_RUN. Truly irrelevant checks are NOT_APPLICABLE with evidence. Nothing is silently converted to PASS.

Reports and evidence stay inside `.comprehensive-qa`, separate from product code.

## Capabilities

The quality of execution depends on the tools given to the AI agent. File access enables repository analysis. Shell access enables builds and tests. Browser access enables real UI/E2E testing. Authorized database/cloud/log access strengthens data, infrastructure and observability gates. Write access enables owner-delegated SAFE remediation.

The package never grants those permissions by itself; it governs how the agent uses permissions that the project owner has provided.
