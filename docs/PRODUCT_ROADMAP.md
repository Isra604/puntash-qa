# Product Roadmap

This file is the durable product roadmap for the Universal Comprehensive QA Gate System.

Current public release at roadmap creation: v1.2.1.

## v1.3.0 — Easy Start

Status: COMPLETED

Goal: turn the project from an expert-oriented QA runtime package into a product that a non-programmer can install and hand to an AI agent with minimal setup.

### 1. Friendly installation
- Add a Windows one-click entry point.
- Let the user choose the target project with a folder picker instead of typing `-ProjectPath`.
- Preserve the mandatory human legal acceptance gate.
- Never guess or scan the disk for a target project without user selection.
- Show a clear success/failure result.

### 2. QA Doctor
- Run a safe local readiness scan after installation.
- Detect project languages, package/build manifests, Git, test signals, CI, database/schema signals, browser/E2E signals, container/infrastructure signals and locally available toolchains.
- Write machine-readable and human-readable Doctor results under `.comprehensive-qa/state/`.
- Treat Doctor output as discovery hints only, never as QA PASS evidence.

### 3. START HERE agent experience
- Install a single `.comprehensive-qa/START_HERE.md` entry point.
- Include copy-ready startup guidance for ChatGPT, Codex, Claude Code, Cursor and generic AI coding agents.
- Make the agent read Doctor output and authoritative QA instructions before beginning Discovery.

### 4. QA of the QA system
- Add deterministic package self-tests.
- Validate exactly 25 gates, version consistency, legal manifest integrity, JSON validity, PowerShell/Bash syntax, update tooling, Doctor tooling, agent guides and package contents.
- Add secret-signature checks.
- Add GitHub Actions self-QA on Windows, Linux and macOS.
- Keep release publication blocked if package self-tests fail.

### 5. Platform quality
- Preserve Windows GUI installation.
- Preserve interactive terminal installation on macOS/Linux.
- Validate macOS/Linux shell paths in CI.
- Keep Windows update/rollback safeguards intact.

## v1.4.0 — Local QA Dashboard

Status: COMPLETED

Goal: make QA status understandable to project owners and managers without requiring them to read long Markdown reports.

Delivered scope:
- Local dashboard generated from structured QA run history.
- QA Health plus separate execution coverage so BLOCKED/NOT_RUN cannot be hidden.
- Gate counts: PASS / FAIL / BLOCKED / NOT_RUN / NOT_APPLICABLE.
- Finding counts by severity.
- Current unresolved findings.
- Health trend and explicit run-to-run new/resolved/gate-status changes.
- Last run, installed QA version and known update status.
- Links to reports/evidence stored locally.
- No cloud account required for the basic dashboard.


## v2.0.0 — Reliability & Professional QA Architecture

Status: COMPLETED

Goal: reduce false confidence and make the 25-gate QA model materially harder to pass with shallow, stale, contradictory, or untrustworthy evidence.

Delivered scope:
- Exactly 25 canonical Gates retained.
- 9 mandatory cross-cutting Reliability Lenses.
- STRONG / MODERATE / WEAK / INSUFFICIENT evidence assurance model with PASS ceilings.
- Current evidence references required for structured PASS/FAIL conclusions.
- Applicability evidence required for NOT_APPLICABLE decisions.
- Test Trustworthiness and oracle/flakiness/mock/data/defect-sensitivity review.
- Machine run validator and gate/lens contradiction checks.
- v2 lens/assurance history in the local dashboard while preserving v1 history.
- Permanent false-PASS Red-Team regression suite.
- Permanent v1.4 -> v2 -> rollback preservation test.
- Windows, Ubuntu and macOS CI/release gating.

## Adoption metrics / optional telemetry

Status: DEFERRED UNTIL EXPLICIT PRIVACY DESIGN

Goal: allow the creator to understand real adoption, not only GitHub download counts.

If implemented, telemetry must be explicitly opt-in and privacy-minimal. Candidate metrics:
- anonymous install event
- active installed version
- update success/failure count
- operating-system family
- optional uninstall/deactivation event if technically meaningful

Never collect by default:
- project source code
- project names or paths
- repository URLs
- usernames
- machine names
- credentials or tokens
- QA findings/evidence
- customer/business data

Before telemetry ships:
- define exact data schema and retention
- update privacy/data notices as needed
- require explicit user choice
- provide a simple disable path
- document endpoint ownership/security
- validate legal/privacy implications before broad distribution

## Later product backlog

These ideas remain deliberately after the milestones above:
- native signed installer/package instead of script-first installation
- signed release artifacts in addition to SHA-256
- package-manager distribution where appropriate
- macOS/Linux updater parity with Windows
- optional scheduled QA runs
- optional scheduled update checks outside agent sessions
- exportable executive reports
- configurable organization policies and gate profiles
- pluggable project-type adapters while keeping the canonical 25-gate model
- localization of installer and user-facing guides

## Roadmap rule

A future version may refine this roadmap, but completed or intentionally deferred items should not be silently removed. Record superseding decisions in `CHANGELOG.md` and this file.
