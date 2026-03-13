#!/usr/bin/env bash
# ABOUTME: Fetches a URL and converts it to clean markdown via Jina Reader.
# ABOUTME: Outputs to file (-o) or stdout. Warns on thin content suggesting JS rendering.
set -euo pipefail

usage() {
  echo "Usage: jina-read.sh <url> [-o <output-file>] [--timeout <seconds>] [--selector <css>]"
  exit 1
}

url=""
output=""
timeout=30
selector=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    --timeout) timeout="$2"; shift 2 ;;
    --selector) selector="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) [[ -z "$url" ]] && url="$1" || usage; shift ;;
  esac
done

[[ -z "$url" ]] && usage

headers=(-H "X-Return-Format: markdown" -H "X-Timeout: ${timeout}")

if [[ -n "${JINA_AI_API_KEY:-}" ]]; then
  headers+=(-H "Authorization: Bearer ${JINA_AI_API_KEY}")
fi

if [[ -n "$selector" ]]; then
  headers+=(-H "X-Target-Selector: ${selector}")
fi

response=$(curl -sS --max-time $((timeout + 5)) "${headers[@]}" "https://r.jina.ai/${url}")
http_status=$?

if [[ $http_status -ne 0 ]]; then
  echo "Error: curl failed with exit code ${http_status}" >&2
  exit 1
fi

# Check for API errors
if echo "$response" | head -1 | grep -q '"code"'; then
  echo "Error: Jina Reader API error:" >&2
  echo "$response" >&2
  exit 2
fi

# Thin content detection
word_count=$(echo "$response" | wc -w | tr -d ' ')
has_headings=$(echo "$response" | grep -c '^#' || true)

if [[ "$word_count" -lt 100 && "$has_headings" -eq 0 ]]; then
  echo "Warning: Thin content (${word_count} words, no headings) — page may require JS rendering. Try firecrawl scrape." >&2
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  echo "$response" > "$output"
  echo "$output"
else
  echo "$response"
fi
