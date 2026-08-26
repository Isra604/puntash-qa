# Tool Requirements and Capability Degradation

The QA package defines behavior; the host agent supplies capabilities.

## Level 1 — Read-only orientation
Required:
- recursive project file/folder access
- file reading
- Git metadata/status access or equivalent

Can produce:
- architecture/documentation/configuration findings
- static project mapping
- gate applicability
- partial evidence report

Cannot honestly PASS gates that require executable/runtime proof.

## Level 2 — Local execution
Adds:
- shell/command execution
- dependency/toolchain access
- test/build runners

Can produce:
- type/build/test evidence
- deterministic regression
- local integration/performance/security-static results

## Level 3 — Interactive application QA
Adds:
- browser/device automation or equivalent UI control

Can produce:
- real E2E
- cross-browser/device evidence
- accessibility/interaction evidence

## Level 4 — Connected environment QA
Adds, only when authorized:
- logs/metrics/traces
- database read access
- infrastructure/configuration read access
- deployment/provider connectors

Can produce:
- stronger observability, data, drift, resilience and readiness evidence

## Level 5 — Safe remediation
Adds:
- controlled write/edit and Git branch/worktree capability

Can perform:
- owner-delegated SAFE remediation only

## Hard rule

Missing capability reduces the status to BLOCKED/NOT_RUN/NOT_APPLICABLE where appropriate. Capability absence never becomes evidence of PASS.
