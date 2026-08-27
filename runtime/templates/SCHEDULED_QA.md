# Scheduled Comprehensive QA Run

This run was started by an owner-approved schedule.

1. Read `.comprehensive-qa/AGENT_INSTRUCTIONS.md` in full.
2. Verify Human Acceptance and OWNER_POLICY before substantive execution.
3. Run the comprehensive QA cycle using all 25 gates + 9 reliability lenses and current evidence.
4. Respect the configured remediation permission ceiling. Scheduling never grants remediation authority. Before every automatic product mutation, provide the Finding ID, bounded change summary, current evidence references, change risk/category, expected-behavior proof and reversibility proof to the installed `authorize-change` tool. Require an explicit ALLOW and record its AUTHORIZATION_ID. Irreversible automatic changes are never authorized.
5. Validate the structured run record, refresh the local dashboard, and preserve immutable evidence/history.
6. If required capabilities or authorization are unavailable, record BLOCKED/NOT_RUN rather than fabricating PASS.
