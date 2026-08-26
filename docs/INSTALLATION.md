# Installation Guide

**Original creator and project architect: Ofir Israeli**  
Copyright © 2026 Ofir Israeli. Licensed under the MIT License.

The installer displays creator attribution during installation and installs a one-time first-activation notice for the QA agent. Redistribution should keep `LICENSE`, `NOTICE`, and `CREDITS.md` with the package.

## Option A — Windows

1. Extract the package anywhere outside the target project.
2. Open PowerShell in the package directory.
3. Run:

```powershell
.\scripts\install.ps1 -ProjectPath "C:\path\to\target-project"
```

4. Verify:

```powershell
.\scripts\verify-install.ps1 -ProjectPath "C:\path\to\target-project"
```

5. Give your AI QA agent access to the target project and send:

```text
Read .comprehensive-qa/AGENT_INSTRUCTIONS.md in full. Perform Discovery first. Build the Project QA Profile from direct evidence. Then map and run all 25 gates. Do not modify product code unless I explicitly authorize safe automatic remediation.
```

## Option B — macOS/Linux

```bash
./scripts/install.sh /path/to/target-project
./scripts/verify-install.sh /path/to/target-project
```

Then use the same agent instruction above.

## Option C — ChatGPT Project

1. Install `.comprehensive-qa` in the repository or upload the installed runtime files to the ChatGPT Project.
2. Copy the contents of `CHATGPT_PROJECT_INSTRUCTIONS.md` into the Project instructions if desired.
3. Ensure ChatGPT has a connected tool capable of reading the actual project files. For executable QA, provide safe command/test access; for browser or live-system gates, connect the corresponding authorized tools.
4. Start with Discovery.

## Important limitation

The package defines the QA intelligence, process, gates, evidence model and remediation rules. It does not itself grant filesystem, shell, browser, database, cloud, or deployment access. Those capabilities must be available to the AI environment in which it runs. Without them, affected gates are reported honestly as BLOCKED/NOT_RUN rather than fabricated as PASS.
