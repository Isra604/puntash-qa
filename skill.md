# Skill: PUNTASH QA

**Universal Comprehensive QA Gate System**

**Original creator and project architect:** Ofir Israeli  
**Copyright:** © 2026 Ofir Israeli  
**License:** MIT

## Purpose

Use this skill when asked to comprehensively audit, validate, quality-gate, release-gate, or continuously QA a software or technical project through its files, folders, repository state, tests, configuration, documentation, runtime evidence, and authorized connected systems.

## Core behavior

1. Before execution, verify the installed human-acceptance receipt exists and corresponds to the current Terms version when unattended/scheduled execution is involved. Never accept installation terms or fabricate acceptance on behalf of a human.
2. Never assume the project type. Discover it.
3. Establish canonical repository/workspace, branch, HEAD, dirty state, authoritative documentation, protected environments, and authority boundaries before tests or edits.
4. Build or refresh the Project QA Profile, including reliability risk inventory and test-trustworthiness profile.
5. Map all 25 universal QA gates to project-specific checks.
6. Evaluate all 9 cross-cutting reliability lenses with explicit applicability, status and evidence assurance.
7. Before mutation, read OWNER_POLICY. If missing/unconfigured, remain REPORT_ONLY and ask the owner for schedule/remediation preferences; never self-elevate.
8. Treat remediation permission as a maximum authority ceiling based on change risk, not finding severity.
9. Before every automatic product mutation, invoke the installed `authorize-change` tool. No explicit ALLOW means no automatic mutation.
10. Scheduling is opt-in, separate from remediation authority, and only active when an actual executor/scheduler is configured.
11. Execute only checks supported by current capabilities and authorization.
12. Never mark a gate or lens PASS from historical evidence alone.
13. Evidence assurance is mandatory: STRONG / MODERATE / WEAK / INSUFFICIENT. WEAK or INSUFFICIENT evidence cannot support a material PASS.
14. When automated tests are decisive PASS evidence, evaluate Test Trustworthiness; coverage alone is never sufficient proof.
15. Never hide a gate or lens. Use PASS, FAIL, BLOCKED, NOT_RUN, or NOT_APPLICABLE.
16. Preserve per-gate and per-lens evidence separately from the primary report.
17. Give every material finding one stable primary ID and complete reproducible evidence; link affected gates/lenses instead of duplicating findings.
18. Deduplicate findings and identify shared root causes across gates and lenses.
19. Automatic remediation is allowed only when explicitly delegated and mechanically authorized under the installed policy.
20. Revalidate every remediation and record pre-fix and post-fix evidence.
21. Never overwrite unrelated uncommitted work.
22. Never silently cross protected product, architecture, security, privacy, data, deployment, production, credential, billing, or destructive-change boundaries.
23. Produce an executive report understandable without reconstructing raw evidence manually.
24. Treat external reviewer/primary-QA closure as separate from original evidence; never rewrite the immutable completed report after review.
25. If a later scan disagrees with an approved reviewer state, report an authority conflict; do not silently reverse the approved change.

## Installed runtime

After installation, read `.comprehensive-qa/AGENT_INSTRUCTIONS.md` as the authoritative detailed runtime contract, `.comprehensive-qa/gates/reliability.yaml` as the reliability policy, and the files under `.comprehensive-qa/gates/` and `.comprehensive-qa/gates/lenses/` as the canonical gate/lens definitions.
