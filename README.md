# claude-crawl

Claude Code plugin for web search, fetch, and crawl operations via Jina AI, Cloudflare Browser Rendering, and Firecrawl.

## Features

- **Fetch** — Convert any URL to clean markdown via Jina Reader
- **Search** — Web search via Jina Search or Firecrawl
- **Scrape** — JavaScript-rendered page extraction via Firecrawl
- **Crawl** — Multi-page async crawling via Cloudflare (up to 100K pages) or Firecrawl
- **Map** — Discover all URLs on a domain via Firecrawl
- **Screenshot/PDF** — Visual page capture via Cloudflare Browser Rendering
- **Extract** — AI-powered structured data extraction via Cloudflare
- **Rerank** — Score and sort results by relevance via Jina Reranker
- **Ground** — Fact-check statements against live web sources via Jina Grounding
- **Deep Research** — Multi-source research agent (search, read, rerank, verify)

## Installation

### From Marketplace (Recommended)

```bash
# Add the hex-plugins marketplace
/plugin marketplace add hex/claude-marketplace

# Install claude-crawl
/plugin install claude-crawl
```

### Direct from GitHub

```bash
/plugin install hex/claude-crawl
```

## Configuration

Set API keys as environment variables. The plugin works with any subset of keys (degraded mode).

| Variable | Required For | How to Get |
|----------|-------------|------------|
| `JINA_AI_API_KEY` | Search, Reranker, Grounding (Reader works without at 20 RPM) | [jina.ai](https://jina.ai/?sui=apikey) |
| `FIRECRAWL_API_KEY` | Scrape, Crawl, Map, Search | [firecrawl.dev](https://firecrawl.dev) |
| `CLOUDFLARE_API_TOKEN` | Browser Rendering (crawl, screenshot, PDF, JSON extraction) | [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens) |
| `CLOUDFLARE_ACCOUNT_ID` | Browser Rendering (required with token) | [Cloudflare Dashboard](https://dash.cloudflare.com) |

Run `/claude-crawl:setup` after installation to validate keys and create the output directory.

### Optional

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CRAWL_NO_INTERCEPT=1` | Disable WebFetch interception (default: intercept enabled) |

## Components

### Skill: `web`

Activates for any web content operation. Routes requests through a decision table to the appropriate backend service.

### Agent: `deep-research`

Launches for thorough multi-source research tasks. Executes a pipeline: search (multiple angles) -> parallel read -> rerank -> optionally ground key claims -> synthesize.

### Command: `/claude-crawl:setup`

One-time project initialization. Validates API keys, creates `.claude-crawl/` output directory, updates `.gitignore`.

### Hooks

- **SessionStart** — Validates API keys and reports service availability
- **PreToolUse (WebFetch)** — Intercepts WebFetch calls and routes through Jina Reader for cleaner markdown output

## Scripts

All scripts are in `scripts/` and follow consistent conventions:
- `-o <file>` for file output, stdout otherwise
- `-h` for usage help
- Exit 0 = success, exit 1 = operation error, exit 2 = auth failure

| Script | Purpose |
|--------|---------|
| `jina-read.sh` | URL to markdown via Jina Reader |
| `jina-search.sh` | Web search via Jina Search |
| `jina-rerank.sh` | Document reranking via Jina Reranker |
| `jina-ground.sh` | Fact verification via Jina Grounding |
| `cf-crawl-start.sh` | Start async Cloudflare crawl job |
| `cf-crawl-poll.sh` | Poll and download Cloudflare crawl results |
| `cf-page.sh` | Single-page Cloudflare operations (markdown, screenshot, PDF, JSON, links) |
| `fc-scrape.sh` | Single-page scrape via Firecrawl |
| `fc-crawl.sh` | Multi-page crawl via Firecrawl |
| `fc-map.sh` | URL discovery via Firecrawl Map |
| `fc-search.sh` | Web search via Firecrawl |
| `check-auth.sh` | API key validation |
| `webfetch-intercept.sh` | WebFetch interception hook |

## Output

All web content is saved to `.claude-crawl/` in the project root (added to `.gitignore` automatically). Subdirectories: `reads/`, `searches/`, `crawls/`, `extractions/`, `reranks/`, `ground/`, `screenshots/`, `pdfs/`.

## License

MIT
