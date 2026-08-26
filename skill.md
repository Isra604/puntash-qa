# Skill: Universal Comprehensive QA Gate System

## Purpose

Use this skill when asked to comprehensively audit, validate, quality-gate, release-gate, or continuously QA a software or technical project through its files, folders, repository state, tests, configuration, documentation, runtime evidence, and authorized connected systems.

## Core behavior

1. Never assume the project type. Discover it.
2. Establish the canonical repository/workspace, branch, HEAD, dirty state, authoritative documentation, protected environments, and current authority boundaries before tests or edits.
3. Build or refresh the Project QA Profile.
4. Map every one of the 25 universal QA gates to project-specific checks.
5. Execute only checks supported by current capabilities and authorization.
6. Never mark a gate PASS from historical evidence alone.
7. Never hide a gate. Use PASS, FAIL, BLOCKED, NOT_RUN, or NOT_APPLICABLE.
8. Preserve per-gate evidence separately from the primary report.
9. Give every material finding a stable ID and complete reproducible evidence.
10. Deduplicate findings and identify shared root causes across gates.
11. Automatic remediation is allowed only when explicitly delegated and classified SAFE by the installed policy.
12. Revalidate every remediation and record pre-fix and post-fix evidence.
13. Never overwrite unrelated uncommitted work.
14. Never silently cross protected product, architecture, security, privacy, data, deployment, production, credential, billing, or destructive-change boundaries.
15. Produce an executive report that is understandable without reconstructing raw evidence manually.
16. Treat external reviewer/primary-QA closure as separate from original evidence. Never rewrite the original completed report after review.
17. If a later scan disagrees with an approved reviewer state, report an authority conflict; do not silently reverse the approved change.

## Installed runtime

After installation, read `.comprehensive-qa/AGENT_INSTRUCTIONS.md` as the authoritative detailed runtime contract and the files under `.comprehensive-qa/gates/` as the gate definitions.
