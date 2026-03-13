#!/usr/bin/env bash
# ABOUTME: PreToolUse hook that intercepts WebFetch calls and redirects to Jina Reader.
# ABOUTME: Set CLAUDE_CRAWL_NO_INTERCEPT=1 to disable.
set -euo pipefail

# Opt-out mechanism
[[ "${CLAUDE_CRAWL_NO_INTERCEPT:-0}" == "1" ]] && exit 0

input=$(cat)

url=$(echo "$input" | jq -r '.tool_input.url // empty')
[[ -z "$url" ]] && exit 0

# Don't intercept local resources
case "$url" in
  file://*|http://localhost*|http://127.0.0.1*|http://0.0.0.0*)
    exit 0
    ;;
esac

# Don't intercept binary files
case "$url" in
  *.pdf|*.png|*.jpg|*.jpeg|*.gif|*.svg|*.zip|*.tar*|*.gz|*.mp4|*.mp3|*.wav)
    exit 0
    ;;
esac

# Fetch via Jina Reader
slug=$(echo "$url" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/-/g' | cut -c1-60)
output_file=".claude-crawl/reads/${slug}.md"
mkdir -p ".claude-crawl/reads"

if "${CLAUDE_PLUGIN_ROOT}/scripts/jina-read.sh" "$url" -o "$output_file" 2>/dev/null; then
  jq -n \
    --arg msg "WebFetch intercepted by claude-crawl. Clean markdown saved to ${output_file}. Read that file instead." \
    '{
      hookSpecificOutput: {
        permissionDecision: "deny",
        permissionDecisionReason: $msg
      }
    }'
else
  # Jina failed — let WebFetch proceed normally
  exit 0
fi
