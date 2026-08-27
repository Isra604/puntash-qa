# Claude Code Quick Start

Start Claude Code in the target project and provide:

```text
Read .comprehensive-qa/START_HERE.md and .comprehensive-qa/AGENT_INSTRUCTIONS.md in full. Read .comprehensive-qa/state/QA_DOCTOR.json if present as non-authoritative discovery hints. Perform Phase 0, Discovery, Project QA Profile construction and the 25-gate QA cycle. Use direct evidence, preserve artifacts and respect remediation/protected-boundary rules.
```


v2.1 rule: read `state/OWNER_POLICY.json` before remediation. If it is unconfigured, remain REPORT_ONLY and ask the owner about scheduling/remediation preferences. Before every automatic product mutation, require an ALLOW from the installed `authorize-change` tool. Scheduling never grants remediation authority.
