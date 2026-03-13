#!/usr/bin/env bash
# ABOUTME: Validates API keys for all claude-crawl services.
# ABOUTME: Reports which services are available and which keys are missing.
set -euo pipefail

verbose=false
[[ "${1:-}" == "--verbose" ]] && verbose=true

ok=0
total=0
missing=()

check_key() {
  local name="$1" var="$2" service="$3"
  total=$((total + 1))
  if [[ -n "${!var:-}" ]]; then
    ok=$((ok + 1))
    $verbose && echo "[OK] ${name}: ${service}"
  else
    missing+=("${var}")
    $verbose && echo "[MISSING] ${name}: Set ${var} to enable ${service}"
  fi
}

check_key "Jina AI" "JINA_AI_API_KEY" "Reader, Search, Reranker, Grounding"
check_key "Firecrawl" "FIRECRAWL_API_KEY" "Scrape, Crawl, Map, Search"
check_key "Cloudflare Token" "CLOUDFLARE_API_TOKEN" "Browser Rendering (crawl, screenshot, PDF, JSON extraction)"
check_key "Cloudflare Account" "CLOUDFLARE_ACCOUNT_ID" "Browser Rendering (required with token)"

echo "claude-crawl: ${ok}/${total} services configured."

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing: ${missing[*]}"
  echo "Note: Jina Reader works without a key at 20 RPM. Set JINA_AI_API_KEY for 500 RPM."
fi
