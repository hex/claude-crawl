#!/usr/bin/env bash
# ABOUTME: Discovers all URLs on a domain via Firecrawl Map API.
# ABOUTME: Returns a list of URLs, optionally filtered by search query.
set -euo pipefail

usage() {
  echo "Usage: fc-map.sh <url> [-o <output-file>] [--search <query>] [--limit <n>] [--subdomains]"
  exit 1
}

url=""
output=""
search=""
limit=100
subdomains=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    --search) search="$2"; shift 2 ;;
    --limit) limit="$2"; shift 2 ;;
    --subdomains) subdomains=true; shift ;;
    -h|--help) usage ;;
    *) [[ -z "$url" ]] && url="$1" || usage; shift ;;
  esac
done

[[ -z "$url" ]] && usage

if [[ -z "${FIRECRAWL_API_KEY:-}" ]]; then
  echo "Error: FIRECRAWL_API_KEY is required." >&2
  exit 2
fi

body=$(jq -n \
  --arg url "$url" \
  --argjson limit "$limit" \
  --argjson subdomains "$subdomains" \
  '{url: $url, limit: $limit, includeSubdomains: $subdomains}')

if [[ -n "$search" ]]; then
  body=$(echo "$body" | jq --arg search "$search" '.search = $search')
fi

response=$(curl -sS --max-time 30 \
  -X POST "https://api.firecrawl.dev/v1/map" \
  -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$body")

if ! echo "$response" | jq -e '.success' > /dev/null 2>&1; then
  echo "Error: Firecrawl map failed:" >&2
  echo "$response" | jq -r '.error // .' >&2
  exit 1
fi

urls=$(echo "$response" | jq -r '.links[]')
count=$(echo "$response" | jq '.links | length')
echo "Found ${count} URLs" >&2

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  echo "$response" | jq '.links' > "$output"
  echo "$output"
else
  echo "$urls"
fi
