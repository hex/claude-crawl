#!/usr/bin/env bash
# ABOUTME: Polls a Cloudflare crawl job for results and downloads pages.
# ABOUTME: Supports --wait to block until complete, with automatic pagination.
set -euo pipefail

usage() {
  echo "Usage: cf-crawl-poll.sh <job-id> [-o <output-dir>] [--wait] [--interval <seconds>]"
  exit 1
}

job_id=""
output_dir=""
wait_mode=false
interval=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output_dir="$2"; shift 2 ;;
    --wait) wait_mode=true; shift ;;
    --interval) interval="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) [[ -z "$job_id" ]] && job_id="$1" || usage; shift ;;
  esac
done

[[ -z "$job_id" ]] && usage

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "Error: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID are required." >&2
  exit 2
fi

[[ -z "$output_dir" ]] && output_dir=".claude-crawl/crawls/cf-${job_id}"
mkdir -p "$output_dir"

api_base="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/browser-rendering/crawl/${job_id}"

poll_once() {
  local cursor="${1:-}"
  local url="$api_base"
  [[ -n "$cursor" ]] && url="${url}?cursor=${cursor}"

  curl -sS --max-time 30 \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    "$url"
}

save_records() {
  local response="$1"
  local count
  count=$(echo "$response" | jq '.result.records // [] | length')

  for ((i = 0; i < count; i++)); do
    local record
    record=$(echo "$response" | jq ".result.records[$i]")
    local page_url
    page_url=$(echo "$record" | jq -r '.url')
    local status
    status=$(echo "$record" | jq -r '.status')

    if [[ "$status" != "completed" ]]; then
      continue
    fi

    # Sanitize URL to filename
    local slug
    slug=$(echo "$page_url" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/-/g' | cut -c1-80)

    # Save markdown if present
    local markdown
    markdown=$(echo "$record" | jq -r '.markdown // empty')
    if [[ -n "$markdown" ]]; then
      echo "$markdown" > "${output_dir}/${slug}.md"
    fi

    # Save html if present
    local html
    html=$(echo "$record" | jq -r '.html // empty')
    if [[ -n "$html" ]]; then
      echo "$html" > "${output_dir}/${slug}.html"
    fi

    # Save json if present
    local json
    json=$(echo "$record" | jq '.json // empty')
    if [[ "$json" != "null" && -n "$json" ]]; then
      echo "$json" > "${output_dir}/${slug}.json"
    fi
  done

  echo "$count"
}

total_saved=0

while true; do
  response=$(poll_once "")
  job_status=$(echo "$response" | jq -r '.result.status // .status // "unknown"')

  case "$job_status" in
    completed|errored|cancelled_by_user|cancelled_due_to_timeout|cancelled_due_to_limits)
      # Fetch all pages with pagination
      cursor=""
      while true; do
        page_response=$(poll_once "$cursor")
        saved=$(save_records "$page_response")
        total_saved=$((total_saved + saved))

        cursor=$(echo "$page_response" | jq -r '.result.cursor // empty')
        [[ -z "$cursor" ]] && break
      done

      # Write manifest
      echo "$response" | jq '{status: .result.status, total_pages: .result.total // 0}' > "${output_dir}/manifest.json"
      echo "Status: ${job_status}. Saved ${total_saved} pages to ${output_dir}/" >&2
      [[ "$job_status" == "completed" ]] && exit 0 || exit 1
      ;;
    running|queued)
      if $wait_mode; then
        echo "Status: ${job_status}. Waiting ${interval}s..." >&2
        sleep "$interval"
      else
        echo "Status: ${job_status}. Use --wait to block until complete."
        exit 0
      fi
      ;;
    *)
      echo "Error: Unknown job status: ${job_status}" >&2
      echo "$response" >&2
      exit 1
      ;;
  esac
done
