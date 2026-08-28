# v2.1.0 Release Candidate Verification Report

Status: **FINAL ADVERSARIAL REVIEW IN PROGRESS**

Original creator and project architect: **Ofir Israeli**

## Why the prior READY state was reopened

A final adversarial architecture review intentionally invalidated the previous release-candidate approval after identifying additional hardening opportunities. The previous SHA/CI evidence is historical only and MUST NOT be treated as approval for the current working tree.

## Final hardening added after the previous candidate

- instruction firewall separating untrusted project content from QA authority
- schema-v3 run/evidence validation with real preserved-evidence existence checks
- current-run authorization-chain validation for every automatic remediation
- permission-policy schema v2 with canonical managed boundaries
- exact pre-mutation target-path authorization and post-mutation scope matching
- protected QA/VCS/CI/credential path surfaces, path canonicalization, junction/symlink/hardlink defenses
- Windows/Unix overlap-race hardening and atomic scheduler state writes
- portable Windows process-tree timeout termination
- installer/updater/rollback path-redirection hardening
- deterministic clean-Git-HEAD package provenance/reproducibility checks
- commit-SHA-pinned GitHub Actions and owner-only manual release publication

## Current evidence state

Local expanded PowerShell and shell self-tests, Target Scope Red-Team, Windows native lifecycle suites, and portable timeout/process-tree tests have passed on the uncommitted hardening working tree. A new clean candidate commit, reproducible package proof, cross-version package upgrade tests, and Windows/Ubuntu/macOS CI are still required before this report may return to READY.

## Release boundary

This report does **not** authorize publication. Until the final candidate is re-verified, the following remain prohibited:

- merge to `main`
- create tag `v2.1.0`
- create/publish GitHub Release `v2.1.0`

The final candidate SHA, CI run and package SHA-256 will be recorded only after the hardened working tree is committed and re-verified.
