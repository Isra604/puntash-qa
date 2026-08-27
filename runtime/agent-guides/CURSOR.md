# Cursor Quick Start

Open the project in Cursor and provide the agent:

```text
Read .comprehensive-qa/START_HERE.md and .comprehensive-qa/AGENT_INSTRUCTIONS.md in full before acting. Read state/QA_DOCTOR.json if present, verify its hints, perform Phase 0 and Discovery, then map and execute all 25 gates that current capabilities support. Never turn an unexecuted check into PASS.
```


v2.1 rule: read `state/OWNER_POLICY.json` before remediation. If it is unconfigured, remain REPORT_ONLY and ask the owner about scheduling/remediation preferences. Before every automatic product mutation, require an ALLOW from the installed `authorize-change` tool. Scheduling never grants remediation authority.
