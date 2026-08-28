# Disclaimer and Risk Notice

**Version:** 1.1.0
**Copyright © 2026 Ofir Israeli**

The PUNTASH QA (Universal Comprehensive QA Gate System) is a software quality-assistance framework. It does not guarantee that software is defect-free, secure, compliant, performant, recoverable, accessible, suitable for production, or suitable for any particular business or technical purpose.

## Use at your own risk

Installation, configuration, execution, and reliance on outputs are performed at the user's own risk and under the user's control. The user is responsible for validating suitability before use and for reviewing findings, commands, proposed fixes, and remediation.

## AI limitations

When operated through an AI agent, results may be incomplete, incorrect, non-deterministic, or based on unavailable context. An AI agent can misunderstand source code, documentation, configuration, system state, business rules, or authority boundaries. Human review remains necessary where the potential impact warrants it.

## Scheduled and automated execution risk

If the owner enables scheduled QA or remediation, actions may be initiated later by an operating-system scheduler, AI platform, or local executor while the owner is not actively present. Failures can therefore occur unattended. The owner is responsible for selecting a suitable executor, limiting its permissions, monitoring costs and resource use, maintaining backups/rollback, and disabling schedules that are no longer appropriate. A configured permission preset is a maximum authority ceiling and is not a guarantee that an AI or third-party executor will comply correctly.

## No guarantee of detection

A PASS result means only that the checks actually executed under the available tools, evidence, configuration, and authority did not establish a blocking defect for that gate. It is not proof that no defect exists. BLOCKED, NOT_RUN, and NOT_APPLICABLE states must not be interpreted as successful testing.

## No professional certification

Outputs are not legal advice, compliance certification, penetration-test certification, security certification, accounting advice, regulated engineering approval, or any other professional certification.

## Production and data risk

Running commands, tests, migrations, scans, load tests, fault injection, security checks, or remediation against live systems can cause outages, data loss, corruption, cost, rate limiting, account suspension, credential exposure, or other harm. The user must decide which environments and permissions are appropriate and maintain backups and rollback capability.

## Third-party risk

Third-party packages, APIs, AI models, hosting providers, cloud systems, repositories, databases, and security tools operate independently. Their behavior, availability, pricing, security, and terms are outside the creator's control.

## Warranty and liability

The MIT License's warranty disclaimer and liability limitation apply. The `TERMS_OF_USE.md` contains additional responsibility and risk-allocation terms for users who affirmatively accept installation through the distributed installer. All exclusions and limitations apply only to the maximum extent permitted by applicable law.
