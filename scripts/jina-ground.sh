#!/usr/bin/env bash
# ABOUTME: Verifies a factual statement against live web sources via Jina Grounding.
# ABOUTME: Returns factuality score, verdict, reason, and supporting/contradicting references.
set -euo pipefail

usage() {
  echo "Usage: jina-ground.sh <statement> [-o <output-file>]"
  exit 1
}

statement=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) [[ -z "$statement" ]] && statement="$1" || usage; shift ;;
  esac
done

[[ -z "$statement" ]] && usage

if [[ -z "${JINA_AI_API_KEY:-}" ]]; then
  echo "Error: JINA_AI_API_KEY is required for grounding." >&2
  exit 2
fi

echo "Grounding claim against web sources (may take ~30s)..." >&2

body=$(jq -n --arg statement "$statement" '{statement: $statement}')

response=$(curl -sS --max-time 60 \
  -X POST "https://g.jina.ai" \
  -H "Authorization: Bearer ${JINA_AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$body")

if echo "$response" | jq -e '.code' > /dev/null 2>&1; then
  echo "Error: Jina Grounding API error:" >&2
  echo "$response" | jq -r '.message // .detail // .' >&2
  exit 2
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  echo "$response" > "$output"
  echo "$output"
else
  echo "$response"
fi
