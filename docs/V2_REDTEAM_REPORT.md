# v2.0.0 Independent Red-Team Report

Status: PASS AFTER HARDENING
Date: 2026-08-27
Target: PUNTASH QA — Universal Comprehensive QA Gate System v2.0.0

## Purpose

Attempt to make the v2 QA architecture produce or preserve misleading confidence, especially false PASS, shallow NOT_APPLICABLE decisions, stale evidence, gate/lens contradictions, unsafe upgrade state, or incomplete rollback.

## Attacks and results

1. **PASS with WEAK evidence** — REJECTED.
2. **PASS with stale evidence** — initially accepted by the early validator design; fixed. PASS/FAIL now requires `evidence_freshness: CURRENT` plus non-empty `evidence_refs`.
3. **PASS without evidence references** — initially not mechanically prevented; fixed and REJECTED.
4. **NOT_APPLICABLE with rationale but no supporting evidence** — early validator only required a sentence; fixed. N/A now requires `applicability_evidence` as well as rationale.
5. **Hide a cross-cutting concern by omitting a lens** — REJECTED; exactly 9 lens decisions are mandatory.
6. **Gate 04 PASS while LENS-01 is FAIL** — early validator only protected Gate 25; fixed. Core gate/lens contradictions now require explicit reviewed non-material exception evidence, while Gate 25 has no exception.
7. **Decisive automated tests without an explicit Test Trustworthiness result** — fixed and REJECTED.
8. **Overall STRONG while a component conclusion is MODERATE/WEAK** — fixed. Run-level assurance cannot exceed the weakest gate/lens/applicable test-trustworthiness assurance.
9. **Duplicate/missing gate identity** — REJECTED; exact unique gate set 1..25 required.
10. **Rollback v2 -> v1.4 leaving v2-only tools behind** — real defect found. Managed `tools/` is now replaced atomically during rollback/failure recovery, preventing validator/tool residue.
11. **Direct v1.4 -> v2 update layout** — PASS. The released v1.4 updater recursively replaces `gates/`, so nested `gates/lenses/`, reliability policy and reliability map arrive without a bridge release.
12. **Preservation during v1.4 -> v2 -> v1.4 simulation** — PASS for reports/history, evidence, state, profile and owner `config/default.yaml`.
13. **Terms-version behavior** — PASS. v1.4 and v2 both use Terms 1.0.0, so v2 does not create an artificial Terms-version change.
14. **Public anonymous release channel** — PASS on the current stable release before v2 publication: unauthenticated GitHub API, ZIP download and SHA-256 verification all succeeded.

## Permanent regression protection

- `scripts/v2-red-team.py` runs false-PASS attacks.
- `scripts/v2-upgrade-red-team.ps1` runs v1.4 -> v2 -> rollback filesystem preservation tests without bypassing human clickwrap.
- Pull-request CI runs Windows, Ubuntu and macOS self-QA; Windows also runs the upgrade/rollback red-team.
- Release workflow repeats package self-test and upgrade/rollback red-team before publishing a tag.

## Important limitation

A mechanical validator can require current evidence references, but it cannot prove that an AI agent is truthful about the semantic meaning of a referenced artifact. The authoritative agent contract therefore still requires direct evidence inspection, source-of-truth comparison and contradiction analysis. v2 reduces false confidence mechanically; it does not pretend schema validation can replace professional evidence review.

## Evidence

- Pull-request CI run `33068760738`: Windows PASS, Ubuntu PASS, macOS PASS; Windows v2 upgrade/rollback red-team PASS.
- Local false-PASS suite: all malicious cases rejected and valid STRONG fixture accepted.
- Local upgrade simulation: v1.4 -> v2 -> rollback PASS with preservation markers intact.
- Public anonymous baseline: API PASS, ZIP PASS, SHA-256 PASS for v1.4.0 before v2 release.
