# Human Acceptance Requirement

**Acceptance protocol version:** 1.0.0

Installation through the distributed installer requires affirmative acceptance by a **natural person** who represents that they are authorized to accept the package terms for themselves or the organization/project owner they represent.

## AI and automation may not accept

An AI agent, coding agent, bot, automation platform, unattended script, CI runner, or other software tool is not authorized by this distribution to accept the installation terms on behalf of a human.

An AI agent may:
- inspect the package
- explain the terms
- launch the installer for the human
- tell the human where manual action is required

It must not claim that it accepted the terms for the human.

## Windows acceptance

The official Windows installer requires an interactive GUI. Before any project files are written, the person must:

1. Review the displayed package terms and notices.
2. Confirm they are a human authorized to accept.
3. Confirm they have read and accept the License, Terms of Use, Disclaimer, and Data Responsibility Notice.
4. Confirm they understand suitability, permissions, backups, and use remain their responsibility.
5. Type exactly `I ACCEPT`.
6. Click `Accept & Install`.

Declining or closing the dialog aborts installation before the package writes to the target project.

## macOS/Linux acceptance

The shell installer refuses non-interactive stdin/stdout. A natural person must review the displayed terms, answer the human-authorization prompts, and manually type `I ACCEPT`. There is intentionally no official `--yes`, `--accept`, `--silent`, CI, or unattended bypass.

## Technical limitation

Software cannot prove with absolute certainty that a physical human, rather than a sufficiently privileged automation tool, generated an input event. This protocol creates an explicit human-attestation and affirmative-consent workflow; it is not biometric or identity verification.
