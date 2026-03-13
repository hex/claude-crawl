#!/usr/bin/env bash
# ABOUTME: Starts an async crawl job via Firecrawl API.
# ABOUTME: Supports --wait to block until complete, downloading results to output directory.
set -euo pipefail

usage() {
  echo "Usage: fc-crawl.sh <url> [-o <output-dir>] [--max-pages <n>] [--max-depth <n>]"
  echo "       [--include <glob>] [--exclude <glob>] [--wait] [--interval <seconds>]"
  exit 1
}

url=""
output_dir=""
max_pages=10
max_depth=3
include=""
exclude=""
wait_mode=false
interval=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output_dir="$2"; shift 2 ;;
    --max-pages) max_pages="$2"; shift 2 ;;
    --max-depth) max_depth="$2"; shift 2 ;;
    --include) include="$2"; shift 2 ;;
    --exclude) exclude="$2"; shift 2 ;;
    --wait) wait_mode=true; shift ;;
    --interval) interval="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) [[ -z "$url" ]] && url="$1" || usage; shift ;;
  esac
done

[[ -z "$url" ]] && usage

if [[ -z "${FIRECRAWL_API_KEY:-}" ]]; then
  echo "Error: FIRECRAWL_API_KEY is required." >&2
  exit 2
fi

domain=$(echo "$url" | sed 's|https\?://||' | sed 's|/.*||')
[[ -z "$output_dir" ]] && output_dir=".claude-crawl/crawls/fc-${domain}-$(date +%s)"
mkdir -p "$output_dir"

body=$(jq -n \
  --arg url "$url" \
  --argjson limit "$max_pages" \
  --argjson maxDepth "$max_depth" \
  '{url: $url, limit: $limit, maxDepth: $maxDepth, scrapeOptions: {formats: ["markdown"]}}')

if [[ -n "$include" ]]; then
  body=$(echo "$body" | jq --arg pat "$include" '.includePaths = [$pat]')
fi

if [[ -n "$exclude" ]]; then
  body=$(echo "$body" | jq --arg pat "$exclude" '.excludePaths = [$pat]')
fi

# Start crawl
response=$(curl -sS --max-time 30 \
  -X POST "https://api.firecrawl.dev/v1/crawl" \
  -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$body")

if ! echo "$response" | jq -e '.success' > /dev/null 2>&1; then
  echo "Error: Firecrawl crawl start failed:" >&2
  echo "$response" | jq -r '.error // .' >&2
  exit 1
fi

job_id=$(echo "$response" | jq -r '.id')
echo "Crawl job started: ${job_id}" >&2

if ! $wait_mode; then
  echo "Poll with: fc-crawl.sh --poll ${job_id}"
  echo "$job_id"
  exit 0
fi

# Poll for completion
while true; do
  status_response=$(curl -sS --max-time 30 \
    -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
    "https://api.firecrawl.dev/v1/crawl/${job_id}")

  status=$(echo "$status_response" | jq -r '.status')
  completed=$(echo "$status_response" | jq -r '.completed // 0')
  total=$(echo "$status_response" | jq -r '.total // "?"')

  case "$status" in
    completed)
      # Save all results
      page_count=$(echo "$status_response" | jq '.data | length')
      for ((i = 0; i < page_count; i++)); do
        page_url=$(echo "$status_response" | jq -r ".data[$i].metadata.sourceURL // .data[$i].metadata.url // \"page-${i}\"")
        slug=$(echo "$page_url" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/-/g' | cut -c1-80)
        markdown=$(echo "$status_response" | jq -r ".data[$i].markdown // empty")
        [[ -n "$markdown" ]] && echo "$markdown" > "${output_dir}/${slug}.md"
      done

      echo "$status_response" | jq '{status, total, completed, creditsUsed}' > "${output_dir}/manifest.json"
      echo "Completed. Saved ${page_count} pages to ${output_dir}/" >&2
      exit 0
      ;;
    scraping|waiting)
      echo "Status: ${status} (${completed}/${total}). Waiting ${interval}s..." >&2
      sleep "$interval"
      ;;
    failed|cancelled)
      echo "Error: Crawl ${status}." >&2
      echo "$status_response" | jq -r '.error // .' >&2
      exit 1
      ;;
  esac
done
