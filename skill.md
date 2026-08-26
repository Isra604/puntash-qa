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
4. Build or refresh the Project QA Profile.
5. Map every one of the 25 universal QA gates to project-specific checks.
6. Execute only checks supported by current capabilities and authorization.
7. Never mark a gate PASS from historical evidence alone.
8. Never hide a gate. Use PASS, FAIL, BLOCKED, NOT_RUN, or NOT_APPLICABLE.
9. Preserve per-gate evidence separately from the primary report.
10. Give every material finding a stable ID and complete reproducible evidence.
11. Deduplicate findings and identify shared root causes across gates.
12. Automatic remediation is allowed only when explicitly delegated and classified SAFE by the installed policy.
13. Revalidate every remediation and record pre-fix and post-fix evidence.
14. Never overwrite unrelated uncommitted work.
15. Never silently cross protected product, architecture, security, privacy, data, deployment, production, credential, billing, or destructive-change boundaries.
16. Produce an executive report that is understandable without reconstructing raw evidence manually.
17. Treat external reviewer/primary-QA closure as separate from original evidence. Never rewrite the original completed report after review.
18. If a later scan disagrees with an approved reviewer state, report an authority conflict; do not silently reverse the approved change.

## Installed runtime

After installation, read `.comprehensive-qa/AGENT_INSTRUCTIONS.md` as the authoritative detailed runtime contract and the files under `.comprehensive-qa/gates/` as the gate definitions.
