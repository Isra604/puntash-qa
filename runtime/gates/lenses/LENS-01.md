# LENS-01 — Test Trustworthiness & Oracle Integrity

## Purpose

Ensure the tests used to justify QA conclusions are themselves capable of detecting meaningful defects and are not silently flaky, stale, over-mocked, order-dependent, disabled, or based on weak oracles.

## Canonical gate relationships

Primary/adjacent gate mapping: GATE-04, GATE-02, GATE-03, GATE-13, GATE-14, GATE-15, GATE-16, GATE-17, GATE-18, GATE-19, GATE-21, GATE-22, GATE-24, GATE-25

This mapping prevents ownership gaps but does not transfer the lens away from the run-wide cross-cutting evaluation. A gate PASS cannot be used as proof that this lens was evaluated.

## Applicability decision

The agent must record APPLICABLE or NOT_APPLICABLE with current evidence. If applicable but execution cannot be completed, use BLOCKED or NOT_RUN rather than silently omitting the lens.

## Required checks

### Mandatory check families
- Test inventory and ownership: identify suites, scopes, skipped/disabled/quarantined tests, stale baselines and generated tests.
- Oracle integrity: verify assertions check intended behavior rather than implementation trivia, status-code-only success, snapshot churn, or self-fulfilling mocks.
- Flakiness and repeatability: rerun decisive high-risk suites when practical; inspect intermittent failures, retries and timing sensitivity.
- Isolation/order independence: detect shared mutable state, test pollution, dependence on execution order, clock/network randomness and non-hermetic fixtures.
- Mock/stub fidelity: confirm mocks do not remove the failure modes the test claims to cover; require real integration evidence where contract risk is material.
- Test-data representativeness: include realistic, negative, boundary and historically failing data, not only happy-path fixtures.
- Defect sensitivity: use mutation testing when project-native and affordable; otherwise use targeted sentinel/defect-injection reasoning to prove critical tests would fail when behavior is broken.
- Coverage interpretation: statement/branch/path coverage is supporting evidence only. High coverage may never substitute for valid behavioral assertions.
- False-positive/false-negative risk: identify suites that can pass while behavior is wrong or fail because of environment noise.
- Historical defect locks: material fixed regressions should gain a durable regression check when technically appropriate.

### PASS ceiling
If automated test output is decisive evidence for a material gate, this lens must be evaluated at adequate depth. A material gate may not be marked PASS solely from a suite whose trustworthiness is WEAK or INSUFFICIENT. If reruns or stronger oracles are infeasible, document the limitation and lower evidence assurance.

## Evidence assurance

Classify the lens evidence as STRONG, MODERATE, WEAK, or INSUFFICIENT. WEAK/INSUFFICIENT evidence cannot support a material PASS. MODERATE evidence may support PASS only when the remaining gap is explicitly shown to be non-material for the current project/risk.

## Required lens output

- status: PASS / FAIL / BLOCKED / NOT_RUN / NOT_APPLICABLE
- applicability rationale and evidence
- evidence assurance: STRONG / MODERATE / WEAK / INSUFFICIENT
- gates affected/consuming this lens
- checks executed
- checks skipped and reason
- findings and stable IDs
- remediation, if authorized
- post-fix/retest evidence
- remaining uncertainty/risk
