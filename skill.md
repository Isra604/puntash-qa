# Skill: Universal Comprehensive QA Gate System

**Original creator and project architect:** Ofir Israeli  
**Copyright:** © 2026 Ofir Israeli  
**License:** MIT

## Purpose

Use this skill when asked to comprehensively audit, validate, quality-gate, release-gate, or continuously QA a software or technical project through its files, folders, repository state, tests, configuration, documentation, runtime evidence, and authorized connected systems.

## Core behavior

1. Before execution, verify the installed human-acceptance receipt exists. Never accept installation terms or fabricate acceptance on behalf of a human.
2. Never assume the project type. Discover it.
3. Establish the canonical repository/workspace, branch, HEAD, dirty state, authoritative documentation, protected environments, and current authority boundaries before tests or edits.
4. Build or refresh the Project QA Profile, including reliability risk inventory and test-trustworthiness profile.
5. Map every one of the 25 universal QA gates to project-specific checks.
6. Evaluate all 9 cross-cutting reliability lenses with explicit applicability, status and evidence assurance.
7. Execute only checks supported by current capabilities and authorization.
8. Never mark a gate or lens PASS from historical evidence alone.
9. Evidence assurance is mandatory: STRONG / MODERATE / WEAK / INSUFFICIENT. WEAK or INSUFFICIENT evidence cannot support a material PASS.
10. When automated tests are decisive PASS evidence, evaluate Test Trustworthiness; coverage alone is never sufficient proof.
11. Never hide a gate or lens. Use PASS, FAIL, BLOCKED, NOT_RUN, or NOT_APPLICABLE.
12. Preserve per-gate and per-lens evidence separately from the primary report.
13. Give every material finding one stable primary ID and complete reproducible evidence; link affected gates/lenses instead of duplicating findings.
14. Deduplicate findings and identify shared root causes across gates and lenses.
15. Automatic remediation is allowed only when explicitly delegated and classified SAFE by the installed policy.
16. Revalidate every remediation and record pre-fix and post-fix evidence.
17. Never overwrite unrelated uncommitted work.
18. Never silently cross protected product, architecture, security, privacy, data, deployment, production, credential, billing, or destructive-change boundaries.
19. Produce an executive report that is understandable without reconstructing raw evidence manually.
20. Treat external reviewer/primary-QA closure as separate from original evidence. Never rewrite the original completed report after review.
21. If a later scan disagrees with an approved reviewer state, report an authority conflict; do not silently reverse the approved change.

## Installed runtime

After installation, read `.comprehensive-qa/AGENT_INSTRUCTIONS.md` as the authoritative detailed runtime contract, `.comprehensive-qa/gates/reliability.yaml` as the reliability policy, and the files under `.comprehensive-qa/gates/` and `.comprehensive-qa/gates/lenses/` as the canonical gate/lens definitions.
