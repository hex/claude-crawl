#!/usr/bin/env bash
# ABOUTME: Fetches a single page via Cloudflare Browser Rendering.
# ABOUTME: Supports markdown, html, screenshot, pdf, json (AI extraction), and links formats.
set -euo pipefail

usage() {
  echo "Usage: cf-page.sh <url> --format <markdown|html|screenshot|pdf|json|links>"
  echo "       [-o <output-file>] [--ai-prompt <prompt>] [--no-render] [--wait-for <selector>]"
  exit 1
}

url=""
format=""
output=""
ai_prompt=""
render=true
wait_for=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) format="$2"; shift 2 ;;
    -o) output="$2"; shift 2 ;;
    --ai-prompt) ai_prompt="$2"; shift 2 ;;
    --no-render) render=false; shift ;;
    --wait-for) wait_for="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) [[ -z "$url" ]] && url="$1" || usage; shift ;;
  esac
done

[[ -z "$url" || -z "$format" ]] && usage

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "Error: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID are required." >&2
  exit 2
fi

api_base="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/browser-rendering"

# Build request body
body=$(jq -n --arg url "$url" --argjson render "$render" '{url: $url, render: $render}')

if [[ -n "$wait_for" ]]; then
  body=$(echo "$body" | jq --arg sel "$wait_for" '.waitForSelector = {selector: $sel, timeout: 10000}')
fi

case "$format" in
  markdown)
    endpoint="${api_base}/markdown"
    ;;
  html)
    endpoint="${api_base}/content"
    ;;
  screenshot)
    endpoint="${api_base}/screenshot"
    ;;
  pdf)
    endpoint="${api_base}/pdf"
    ;;
  json)
    endpoint="${api_base}/json"
    if [[ -z "$ai_prompt" ]]; then
      echo "Error: --ai-prompt is required for json format." >&2
      exit 1
    fi
    body=$(echo "$body" | jq --arg prompt "$ai_prompt" '.jsonOptions = {prompt: $prompt}')
    ;;
  links)
    endpoint="${api_base}/links"
    ;;
  *)
    echo "Error: Unknown format: ${format}" >&2
    usage
    ;;
esac

# Binary formats need different curl handling
if [[ "$format" == "screenshot" || "$format" == "pdf" ]]; then
  [[ -z "$output" ]] && output=".claude-crawl/${format}s/$(echo "$url" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/-/g' | cut -c1-60).${format}"
  mkdir -p "$(dirname "$output")"
  curl -sS --max-time 60 \
    -X POST "$endpoint" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    -o "$output"
  echo "$output"
else
  response=$(curl -sS --max-time 60 \
    -X POST "$endpoint" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$body")

  if echo "$response" | jq -e '.errors[0]' > /dev/null 2>&1; then
    echo "Error: Cloudflare API error:" >&2
    echo "$response" | jq -r '.errors[]?.message // .' >&2
    exit 1
  fi

  if [[ -n "$output" ]]; then
    mkdir -p "$(dirname "$output")"
    echo "$response" > "$output"
    echo "$output"
  else
    echo "$response"
  fi
fi
