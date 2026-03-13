---
name: web
description: |
  This skill should be used for any web content operation: fetching URLs, searching the web,
  scraping JavaScript-heavy pages, crawling multi-page sites, mapping site URLs, taking
  screenshots, rendering pages as PDF, extracting structured data, reranking search results,
  and fact-checking claims against live web sources.

  This skill covers tasks like "read this page", "search for X", "crawl the docs at Y",
  "is Z true?", "find all pages on this domain", "take a screenshot of this URL",
  "save this page as a PDF", "list all links on this site", "get me structured data from
  this URL", "discover all URLs on this domain", or "what does this sitemap contain?".
---

# Web Content Operations

All web operations use shell scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Output goes to
`.claude-crawl/` in the project root to protect the context window from large content.

Before any operation: `mkdir -p .claude-crawl/{reads,searches,crawls,extractions,reranks,ground,screenshots,pdfs}`

WebFetch calls are automatically intercepted and routed through Jina Reader for cleaner
markdown output. Set `CLAUDE_CRAWL_NO_INTERCEPT=1` to disable this behavior and use
WebFetch directly. Run `check-auth.sh --verbose` to see which services are available.

## Routing Table

Choose the right tool based on what you have and what you need:

```
HAVE                      NEED                        USE
─────────────────────────────────────────────────────────────────────
Topic/question            Search results              jina-search.sh or fc-search.sh
URL, static page          Clean markdown              jina-read.sh
URL, JS-heavy/SPA         Rendered content            fc-scrape.sh
URL, need visual capture  Screenshot or PDF           cf-page.sh --format screenshot|pdf
URL, need structured data JSON extraction (AI)        cf-page.sh --format json --ai-prompt "..."
Domain                    All URLs on site            fc-map.sh
Multiple URLs, bulk       Multi-page content          cf-crawl-start.sh or fc-crawl.sh
Statement/claim           Fact verification           jina-ground.sh
Multiple results          Ranked by relevance         jina-rerank.sh
```

### How to decide between similar tools

**Search**: Use `jina-search.sh` for general web search (fast, returns full content). Use
`fc-search.sh` when you need Firecrawl-specific features like `--scrape` (auto-scrapes each
result) or want an alternative search provider.

**Single page fetch**: Start with `jina-read.sh` — it's fastest and cheapest. If the result
is thin (< 100 words, no headings — the script warns you), escalate to `fc-scrape.sh` which
renders JavaScript. If you need Cloudflare's AI extraction or screenshots, use `cf-page.sh`.

**Multi-page crawl**: Use `fc-crawl.sh` for quick exploratory crawls (simpler API, good error
messages). Use `cf-crawl-start.sh` + `cf-crawl-poll.sh` for large-scale crawls (up to 100K
pages, async job model, built-in AI extraction via `--format json`).

## Script Reference

All scripts accept `-h` for usage help. Common patterns:
- `-o <file>` — write output to file (otherwise stdout)
- Exit code 2 — auth failure (missing API key). Report the missing key to the user.
- Exit code 1 — operation error (rate limit, timeout, etc.)

### Jina AI Scripts (JINA_AI_API_KEY — optional for reader, required for rerank/ground)

| Script | Purpose | Key flags |
|--------|---------|-----------|
| `jina-read.sh <url>` | URL to markdown | `-o`, `--timeout`, `--selector <css>` |
| `jina-search.sh <query>` | Web search | `-o`, `-n <count>` |
| `jina-rerank.sh <query> -d <docs.json>` | Score documents by relevance | `-o`, `--top-n <n>` |
| `jina-ground.sh <statement>` | Fact-check against web (~30s) | `-o` |

### Cloudflare Scripts (CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID required)

| Script | Purpose | Key flags |
|--------|---------|-----------|
| `cf-page.sh <url> --format <fmt>` | Single page (markdown/html/screenshot/pdf/json/links) | `-o`, `--ai-prompt`, `--no-render`, `--wait-for <sel>` |
| `cf-crawl-start.sh <url>` | Start async crawl job | `--max-pages`, `--max-depth`, `--format`, `--include`, `--exclude` |
| `cf-crawl-poll.sh <job-id>` | Poll crawl job for results | `-o <dir>`, `--wait`, `--interval <sec>` |

### Firecrawl Scripts (FIRECRAWL_API_KEY required)

| Script | Purpose | Key flags |
|--------|---------|-----------|
| `fc-scrape.sh <url>` | Single page with JS rendering | `-o`, `--format`, `--wait-for <ms>` |
| `fc-crawl.sh <url>` | Multi-page crawl | `-o <dir>`, `--max-pages`, `--max-depth`, `--wait` |
| `fc-map.sh <url>` | Discover all URLs on domain | `-o`, `--search <query>`, `--limit`, `--subdomains` |
| `fc-search.sh <query>` | Web search | `-o`, `-n <count>`, `--scrape` |

## Output Management

All output goes to `.claude-crawl/` — never write web content inline in the conversation.

```
.claude-crawl/
├── reads/        # Single page fetches (jina-read, cf-page markdown, fc-scrape)
├── searches/     # Search results (jina-search, fc-search)
├── crawls/       # Multi-page crawl results (cf-crawl, fc-crawl)
├── extractions/  # AI-extracted JSON (cf-page --format json)
├── reranks/      # Reranked result sets (jina-rerank)
├── ground/       # Fact-check results (jina-ground)
├── screenshots/  # Visual captures (cf-page --format screenshot)
└── pdfs/         # PDF renders (cf-page --format pdf)
```

### Context window protection

- NEVER `cat` or `Read` an entire large output file
- Use `wc -l` first to check size
- Use `head -100` for summaries or `grep` for specific content
- For crawl results with many files, `ls` the directory and selectively read

## Parallelism

Run independent fetches in parallel with `&` and `wait`:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/jina-read.sh "https://url1" -o .claude-crawl/reads/page1.md &
${CLAUDE_PLUGIN_ROOT}/scripts/jina-read.sh "https://url2" -o .claude-crawl/reads/page2.md &
wait
```

## Async Crawl Pattern

Cloudflare crawls are async (start job, poll for results):

```bash
# Start
job_id=$(${CLAUDE_PLUGIN_ROOT}/scripts/cf-crawl-start.sh "https://docs.example.com" --max-pages 50)

# Poll until complete (blocks)
${CLAUDE_PLUGIN_ROOT}/scripts/cf-crawl-poll.sh "$job_id" --wait -o .claude-crawl/crawls/example/
```

Firecrawl crawls also support `--wait` for blocking mode.

## Utility Scripts

| Script | Purpose |
|--------|---------|
| `check-auth.sh [--verbose]` | Validates which API keys are set and which services are available |
| `webfetch-intercept.sh` | PreToolUse hook — intercepts WebFetch and routes through Jina Reader |

## Error Handling

If a script exits with code 2 (auth failure), run `check-auth.sh --verbose` and tell the user:
- `JINA_AI_API_KEY` — Jina Reader works without it at 20 RPM; required for Search, Reranker, and Grounding
- `FIRECRAWL_API_KEY` — required for all Firecrawl operations
- `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` — required for all Cloudflare operations

When one service is unavailable, fall back to another:
- No Firecrawl? Use Jina Reader for single pages, Cloudflare for crawls
- No Cloudflare? Use Firecrawl for crawls
- No Jina key? Jina Reader still works at 20 RPM; use Firecrawl search instead of Jina search

## Escalation Ladder

When the simple approach fails, escalate:

1. **jina-read.sh** — try this first for any URL (fast, cheap)
2. **fc-scrape.sh** — if Jina returns thin content (JS-heavy page)
3. **fc-map.sh** — to discover what pages exist on a domain
4. **fc-crawl.sh / cf-crawl-start.sh** — for bulk multi-page content
5. **cf-page.sh --format json** — for AI-powered structured extraction

## Extended Reference

For detailed API parameters and edge cases, see:
- **`references/jina-api.md`** — Jina Reader/Search/Reranker/Grounding endpoint details
- **`references/cloudflare-api.md`** — Cloudflare Browser Rendering full parameter reference
- **`references/firecrawl-api.md`** — Firecrawl REST API endpoint details
