# Generic AI Agent Quick Start

The agent must have filesystem access to the target project. Then provide:

```text
Read .comprehensive-qa/START_HERE.md, .comprehensive-qa/AGENT_INSTRUCTIONS.md and state/QA_DOCTOR.json if present. Treat Doctor output only as hints. Perform Phase 0 and Discovery, build the Project QA Profile, map all 25 gates + 9 reliability lenses and execute the strongest safe checks your actual tools permit. Preserve evidence, report missing capabilities honestly and do not mutate protected project areas without explicit authority.
```


v2.1 rule: read `state/OWNER_POLICY.json` before remediation. If it is unconfigured, remain REPORT_ONLY and ask the owner about scheduling/remediation preferences. Before every automatic product mutation, require an ALLOW from the installed `authorize-change` tool. Scheduling never grants remediation authority.
