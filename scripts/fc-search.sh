#!/usr/bin/env bash
# ABOUTME: Searches the web via Firecrawl Search API.
# ABOUTME: Returns search results with optional full page scraping (--scrape).
set -euo pipefail

usage() {
  echo "Usage: fc-search.sh <query> [-o <output-file>] [-n <count>] [--scrape]"
  exit 1
}

query=""
output=""
count=5
scrape=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    -n) count="$2"; shift 2 ;;
    --scrape) scrape=true; shift ;;
    -h|--help) usage ;;
    *) [[ -z "$query" ]] && query="$1" || usage; shift ;;
  esac
done

[[ -z "$query" ]] && usage

if [[ -z "${FIRECRAWL_API_KEY:-}" ]]; then
  echo "Error: FIRECRAWL_API_KEY is required." >&2
  exit 2
fi

body=$(jq -n \
  --arg query "$query" \
  --argjson limit "$count" \
  --argjson scrape "$scrape" \
  '{query: $query, limit: $limit}')

if $scrape; then
  body=$(echo "$body" | jq '.scrapeOptions = {formats: ["markdown"]}')
fi

response=$(curl -sS --max-time 30 \
  -X POST "https://api.firecrawl.dev/v1/search" \
  -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$body")

if ! echo "$response" | jq -e '.success' > /dev/null 2>&1; then
  echo "Error: Firecrawl search failed:" >&2
  echo "$response" | jq -r '.error // .' >&2
  exit 1
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  echo "$response" > "$output"
  echo "$output"
else
  echo "$response"
fi
