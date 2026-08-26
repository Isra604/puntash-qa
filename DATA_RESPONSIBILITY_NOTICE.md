# Privacy and Data Responsibility Notice

**Version:** 1.0.0

The QA package itself does not create a hosted service, account system, analytics service, telemetry backend, or data-upload endpoint. The distributed installer is designed to operate locally.

## Local acceptance record

To document affirmative installation consent, the installer stores a local acceptance receipt in:

`.comprehensive-qa/state/HUMAN_ACCEPTANCE_RECEIPT.json`

The receipt may contain:
- package version
- terms version
- acceptance timestamp
- project installation path
- local operating-system account name
- local machine/host name
- acceptance method
- an attestation that the accepting person represented they were a human authorized to accept
- SHA-256 hashes of the legal documents presented

The installer does **not** transmit this receipt to Ofir Israeli or to any server operated by this package.

## Project data

The QA agent may inspect project files, source code, logs, configuration, test results, or connected systems only to the extent the user gives the AI environment those capabilities. The project owner is responsible for deciding what data may be exposed to an AI provider, plugin, connector, shell, browser, database, cloud tool, or third-party service.

## Secrets and personal data

Users should avoid exposing secrets, private keys, passwords, tokens, regulated personal data, confidential customer data, or unrelated sensitive information unless the chosen environment is explicitly authorized and appropriate for that data.

The QA instructions direct agents to prefer metadata, redacted evidence, and credential-safe access rather than broadly reading secrets.

## Responsibility for third-party processing

If the user operates the package through an AI platform or connects external services, data handling may be governed by those providers' privacy terms, data-processing agreements, retention policies, and security controls. The package creator does not control those third-party systems.
