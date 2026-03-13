---
description: Initialize claude-crawl for this project. Validates API keys and creates output directory.
allowed-tools: Bash
---

Run setup for claude-crawl:

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-auth.sh --verbose` and show the output.
2. Create the output directory structure:
   ```bash
   mkdir -p .claude-crawl/{reads,searches,crawls,extractions,reranks,ground,screenshots,pdfs}
   ```
3. Add `.claude-crawl/` to `.gitignore` if it exists and the entry is not already there.
4. Report which services are available based on check-auth output, and how to set any missing keys:
   - `export JINA_AI_API_KEY=...` — for Jina Reader, Search, Reranker, Grounding
   - `export FIRECRAWL_API_KEY=...` — for Firecrawl scrape, crawl, map, search
   - `export CLOUDFLARE_API_TOKEN=...` and `export CLOUDFLARE_ACCOUNT_ID=...` — for Cloudflare Browser Rendering
