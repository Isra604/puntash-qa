#!/usr/bin/env bash
set -euo pipefail
PROJECT="${1:-}"
OUTPUT="${2:-}"
if [[ -z "$PROJECT" ]]; then
  INSTALL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  PROJECT="$(cd "$INSTALL_ROOT/.." && pwd)"
fi
PROJECT="$(cd "$PROJECT" && pwd)"
if [[ -z "$OUTPUT" ]]; then
  INSTALL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  OUTPUT="$INSTALL_ROOT/state"
fi
mkdir -p "$OUTPUT"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
find "$PROJECT" \( -name .git -o -name .comprehensive-qa -o -name .comprehensive-qa-backups -o -name node_modules -o -name vendor -o -name dist -o -name build -o -name target -o -name .venv -o -name venv -o -name __pycache__ \) -prune -o -type f -print 2>/dev/null | head -n 5000 > "$TMP" || true
COUNT="$(wc -l < "$TMP" | tr -d ' ')"
has_match(){ grep -Eiq "$1" "$TMP"; }
json_bool(){ if "$@"; then printf true; else printf false; fi; }
GIT=false; if command -v git >/dev/null 2>&1 && git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then GIT=true; fi
TESTS=false; if has_match '/(test|tests|__tests__|spec|specs)/|(^|/)[^/]*(test|spec)\.[^/]+$'; then TESTS=true; fi
DB=false; if has_match '/(migrations?|prisma|supabase|database|db)/|\.sql$|schema\.(prisma|sql)$'; then DB=true; fi
E2E=false; if has_match 'playwright\.config|cypress\.config|/e2e/|selenium|webdriver'; then E2E=true; fi
CI=false; [[ -d "$PROJECT/.github/workflows" || -f "$PROJECT/.gitlab-ci.yml" || -f "$PROJECT/azure-pipelines.yml" ]] && CI=true
CONTAINERS=false; [[ -f "$PROJECT/Dockerfile" ]] && CONTAINERS=true; if has_match 'docker-compose|compose\.ya?ml$'; then CONTAINERS=true; fi
INFRA=false; if has_match '\.tf$|/(helm|k8s|kubernetes|terraform|infrastructure|infra)/'; then INFRA=true; fi
PRIVACY=false; if has_match '/(privacy|consent|retention|accounts?|profiles?|users?|analytics)(/|[._-])'; then PRIVACY=true; fi
COMPAT=false; if has_match '/(migrations?|openapi|swagger|proto|versioning|upgrades?|rollback)(/|[._-])|\.(proto|avsc)$'; then COMPAT=true; fi
LOCALE=false; if has_match '/(i18n|l10n|locales?|translations?|rtl|timezone|timezones|currencies)(/|[._-])'; then LOCALE=true; fi
THIRDPARTY=false; if has_match '/(integrations?|webhooks?|oauth|stripe|twilio|sendgrid|sentry|openai|anthropic|bedrock|gemini)(/|[._-])'; then THIRDPARTY=true; fi
RESOURCE=false; if $INFRA || $CONTAINERS || has_match '/(load|stress|soak|benchmarks?|capacity|queues?|workers?|k6|jmeter|locust)(/|[._-])'; then RESOURCE=true; fi
AI=false; if has_match '/(prompts?|llm|openai|anthropic|bedrock|gemini|ollama|langchain|huggingface)(/|[._-])'; then AI=true; fi
A11Y=false; if has_match '/(a11y|accessibility|axe|wcag|aria)(/|[._-])'; then A11Y=true; fi
MANIFESTS=false; if has_match '/(package\.json|pyproject\.toml|requirements\.txt|go\.mod|Cargo\.toml|pom\.xml|build\.gradle|build\.gradle\.kts|Gemfile|composer\.json|mix\.exs|Package\.swift)$'; then MANIFESTS=true; fi
escape_json(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
TOOLS=""; for t in git node npm pnpm yarn python3 python dotnet java mvn gradle go cargo rustc docker podman bash pwsh; do if command -v "$t" >/dev/null 2>&1; then TOOLS="${TOOLS}${TOOLS:+, }$t"; fi; done
cat > "$OUTPUT/QA_DOCTOR.json" <<EOF
{
  "schema_version": 2,
  "doctor_version": "2.0",
  "status": "READY_FOR_AGENT_DISCOVERY",
  "project_path": "$(escape_json "$PROJECT")",
  "scanned_files": $COUNT,
  "scan_file_limit": 5000,
  "signals": {
    "git_repository": $GIT,
    "tests": $TESTS,
    "build_or_manifest": $MANIFESTS,
    "database_or_schema": $DB,
    "browser_e2e": $E2E,
    "ci": $CI,
    "containers": $CONTAINERS,
    "infrastructure": $INFRA
  },
  "reliability_lens_hints": {
    "LENS-01_test_trustworthiness": $TESTS,
    "LENS-02_privacy_data_lifecycle": $PRIVACY,
    "LENS-03_compatibility_upgrade": $COMPAT,
    "LENS-04_time_locale_precision_encoding": $LOCALE,
    "LENS-05_third_party_failure_quota": $THIRDPARTY,
    "LENS-06_resource_capacity_cost": $RESOURCE,
    "LENS-07_ai_quality_model_risk": $AI,
    "LENS-08_accessibility_depth": $A11Y,
    "LENS-09_change_blast_radius": $GIT
  },
  "reliability_hint_meaning": "Discovery hints only. False means no simple local signal was found, not NOT_APPLICABLE. The agent must make all 9 lens decisions from direct evidence.",
  "local_tools_text": "$(escape_json "$TOOLS")",
  "note": "QA Doctor output is a pre-discovery hint set, not a QA verdict or PASS evidence."
}
EOF
cat > "$OUTPUT/QA_DOCTOR.md" <<EOF
# QA Doctor Readiness Report

Status: READY_FOR_AGENT_DISCOVERY
Project: $PROJECT
Files sampled: $COUNT / limit 5000

## Signals
- Git repository: $GIT
- Tests: $TESTS
- Build/package manifest: $MANIFESTS
- Database/schema: $DB
- Browser/E2E: $E2E
- CI: $CI
- Containers: $CONTAINERS
- Infrastructure: $INFRA

## v2 Reliability lens discovery hints
- LENS-01 Test trustworthiness: $TESTS
- LENS-02 Privacy/data lifecycle: $PRIVACY
- LENS-03 Compatibility/upgrade: $COMPAT
- LENS-04 Time/locale/precision/encoding: $LOCALE
- LENS-05 Third-party failure/quota: $THIRDPARTY
- LENS-06 Resource/capacity/cost: $RESOURCE
- LENS-07 AI quality/model risk: $AI
- LENS-08 Accessibility depth: $A11Y
- LENS-09 Change blast radius: $GIT

A false hint is not proof of NOT_APPLICABLE. All 9 lenses still require an evidence-based decision by the QA agent.

## Local tools detected
$TOOLS

This is a pre-discovery readiness report, not a QA verdict. The AI agent must verify all relevant facts from direct current evidence.
EOF
echo "QA_DOCTOR_STATUS=READY_FOR_AGENT_DISCOVERY"
echo "QA_DOCTOR_SCANNED_FILES=$COUNT"
echo "QA_DOCTOR_JSON=$OUTPUT/QA_DOCTOR.json"
echo "QA_DOCTOR_RELIABILITY_HINTS=9"
