#!/usr/bin/env bash
# ABOUTME: Starts an async crawl job via Cloudflare Browser Rendering.
# ABOUTME: Returns a job ID for polling with cf-crawl-poll.sh.
set -euo pipefail

usage() {
  echo "Usage: cf-crawl-start.sh <url> [--max-pages <n>] [--max-depth <n>] [--format markdown|html|json]"
  echo "       [--no-render] [--ai-prompt <prompt>] [--include <glob>] [--exclude <glob>]"
  exit 1
}

url=""
max_pages=10
max_depth=3
formats='["markdown"]'
render=true
ai_prompt=""
include_pattern=""
exclude_pattern=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-pages) max_pages="$2"; shift 2 ;;
    --max-depth) max_depth="$2"; shift 2 ;;
    --format)
      case "$2" in
        markdown) formats='["markdown"]' ;;
        html) formats='["html"]' ;;
        json) formats='["json"]' ;;
        all) formats='["html","markdown"]' ;;
        *) echo "Error: Unknown format: $2" >&2; exit 1 ;;
      esac
      shift 2 ;;
    --no-render) render=false; shift ;;
    --ai-prompt) ai_prompt="$2"; shift 2 ;;
    --include) include_pattern="$2"; shift 2 ;;
    --exclude) exclude_pattern="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) [[ -z "$url" ]] && url="$1" || usage; shift ;;
  esac
done

[[ -z "$url" ]] && usage

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "Error: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID are required." >&2
  exit 2
fi

body=$(jq -n \
  --arg url "$url" \
  --argjson limit "$max_pages" \
  --argjson depth "$max_depth" \
  --argjson formats "$formats" \
  --argjson render "$render" \
  '{url: $url, limit: $limit, depth: $depth, formats: $formats, render: $render}')

# Add optional fields
if [[ -n "$ai_prompt" ]]; then
  body=$(echo "$body" | jq --arg prompt "$ai_prompt" '. + {jsonOptions: {prompt: $prompt}}')
  body=$(echo "$body" | jq '.formats += ["json"]')
fi

if [[ -n "$include_pattern" ]]; then
  body=$(echo "$body" | jq --arg pat "$include_pattern" '.options.includePatterns = [$pat]')
fi

if [[ -n "$exclude_pattern" ]]; then
  body=$(echo "$body" | jq --arg pat "$exclude_pattern" '.options.excludePatterns = [$pat]')
fi

api_url="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/browser-rendering/crawl"

response=$(curl -sS --max-time 30 \
  -X POST "$api_url" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$body")

if ! echo "$response" | jq -e '.success' > /dev/null 2>&1; then
  echo "Error: Cloudflare API error:" >&2
  echo "$response" | jq -r '.errors[]?.message // .' >&2
  exit 1
fi

job_id=$(echo "$response" | jq -r '.result.id // .id // empty')

if [[ -z "$job_id" ]]; then
  echo "Error: No job ID in response:" >&2
  echo "$response" >&2
  exit 1
fi

echo "Crawl job started: ${job_id}"
echo "Poll with: cf-crawl-poll.sh ${job_id} --wait"
echo "$job_id"
