#!/usr/bin/env bash
# ABOUTME: Reranks a set of documents against a query using Jina Reranker.
# ABOUTME: Reads documents from JSON file, outputs scored results sorted by relevance.
set -euo pipefail

usage() {
  echo "Usage: jina-rerank.sh <query> -d <documents-json-file> [-o <output-file>] [--top-n <n>]"
  exit 1
}

query=""
docs_file=""
output=""
top_n=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) docs_file="$2"; shift 2 ;;
    -o) output="$2"; shift 2 ;;
    --top-n) top_n="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) [[ -z "$query" ]] && query="$1" || usage; shift ;;
  esac
done

[[ -z "$query" || -z "$docs_file" ]] && usage

if [[ -z "${JINA_AI_API_KEY:-}" ]]; then
  echo "Error: JINA_AI_API_KEY is required for reranking." >&2
  exit 2
fi

if [[ ! -f "$docs_file" ]]; then
  echo "Error: Documents file not found: ${docs_file}" >&2
  exit 1
fi

documents=$(cat "$docs_file")

body=$(jq -n \
  --arg query "$query" \
  --arg model "jina-reranker-v2-base-multilingual" \
  --argjson top_n "$top_n" \
  --argjson documents "$documents" \
  '{
    model: $model,
    query: $query,
    documents: $documents,
    top_n: $top_n,
    return_documents: true
  }')

response=$(curl -sS --max-time 30 \
  -X POST "https://api.jina.ai/v1/rerank" \
  -H "Authorization: Bearer ${JINA_AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$body")

if echo "$response" | jq -e '.detail' > /dev/null 2>&1; then
  echo "Error: Jina Reranker API error:" >&2
  echo "$response" | jq -r '.detail' >&2
  exit 2
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  echo "$response" > "$output"
  echo "$output"
else
  echo "$response"
fi
