#!/usr/bin/env bash
# ABOUTME: Scrapes a single page via Firecrawl API with JS rendering.
# ABOUTME: Returns clean markdown. Use for JS-heavy pages where Jina Reader returns thin content.
set -euo pipefail

usage() {
  echo "Usage: fc-scrape.sh <url> [-o <output-file>] [--format markdown|html] [--wait-for <ms>]"
  exit 1
}

url=""
output=""
format="markdown"
wait_for=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    --format) format="$2"; shift 2 ;;
    --wait-for) wait_for="$2"; shift 2 ;;
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
  --arg fmt "$format" \
  --argjson wait "$wait_for" \
  '{url: $url, formats: [$fmt], onlyMainContent: true}')

if [[ "$wait_for" -gt 0 ]]; then
  body=$(echo "$body" | jq --argjson wait "$wait_for" '.waitFor = $wait')
fi

response=$(curl -sS --max-time 60 \
  -X POST "https://api.firecrawl.dev/v1/scrape" \
  -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$body")

if ! echo "$response" | jq -e '.success' > /dev/null 2>&1; then
  echo "Error: Firecrawl scrape failed:" >&2
  echo "$response" | jq -r '.error // .' >&2
  exit 1
fi

content=$(echo "$response" | jq -r ".data.${format} // .data.content // empty")

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  echo "$content" > "$output"
  echo "$output"
else
  echo "$content"
fi
