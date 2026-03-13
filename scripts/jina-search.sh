#!/usr/bin/env bash
# ABOUTME: Searches the web via Jina Search and returns results as JSON.
# ABOUTME: Outputs to file (-o) or stdout. Minimum 10K tokens per call.
set -euo pipefail

usage() {
  echo "Usage: jina-search.sh <query> [-o <output-file>] [-n <count>]"
  exit 1
}

query=""
output=""
count=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    -n) count="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) [[ -z "$query" ]] && query="$1" || usage; shift ;;
  esac
done

[[ -z "$query" ]] && usage

encoded_query=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$query")

headers=(-H "Accept: application/json" -H "X-Retain-Images: none")

if [[ -n "${JINA_AI_API_KEY:-}" ]]; then
  headers+=(-H "Authorization: Bearer ${JINA_AI_API_KEY}")
else
  echo "Warning: No JINA_AI_API_KEY set. Rate limited to 20 RPM." >&2
fi

if [[ "$count" -ne 5 ]]; then
  headers+=(-H "X-Max-Results: ${count}")
fi

response=$(curl -sS --max-time 30 "${headers[@]}" "https://s.jina.ai/${encoded_query}")

if echo "$response" | head -1 | grep -q '"code"'; then
  echo "Error: Jina Search API error:" >&2
  echo "$response" >&2
  exit 2
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  echo "$response" > "$output"
  echo "$output"
else
  echo "$response"
fi
