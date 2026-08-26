# START HERE

Universal Comprehensive QA Gate System

Original creator and project architect: Ofir Israeli.

## If you are the project owner

1. Confirm this folder is inside the project you intended to protect with QA.
2. Review `state/QA_DOCTOR.md` if it exists. It is a readiness scan, not a QA verdict.
3. Open an AI coding/QA agent that has access to this project.
4. Give the agent the startup instruction below.

```text
Read .comprehensive-qa/START_HERE.md, .comprehensive-qa/AGENT_INSTRUCTIONS.md, and .comprehensive-qa/state/QA_DOCTOR.json if it exists. Treat QA Doctor output only as discovery hints. Perform Phase 0 and Discovery before testing. Build or refresh the Project QA Profile, map all 25 gates, execute only checks supported by current evidence and available capabilities, and never claim PASS without current evidence. Do not modify product code unless the project owner has explicitly authorized an allowed remediation mode.
```

## Agent-specific quick guides

See `agent-guides/` for short startup notes for:
- ChatGPT
- Codex
- Claude Code
- Cursor
- generic AI coding/QA agents

## Important

The QA system does not grant an AI agent new permissions. The agent can only inspect, test or change what its environment already allows. Missing capabilities must become BLOCKED/NOT_RUN where appropriate, never fabricated PASS evidence.
