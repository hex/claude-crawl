# Cloudflare Browser Rendering API Reference

**Base URL:** `https://api.cloudflare.com/client/v4/accounts/{CLOUDFLARE_ACCOUNT_ID}/browser-rendering`

**Auth:** `Authorization: Bearer $CLOUDFLARE_API_TOKEN` (requires Browser Rendering - Edit permission)

## Crawl Endpoint

### Start Crawl: `POST .../crawl`

**Request body:**
```json
{
  "url": "https://example.com",
  "limit": 10,
  "depth": 3,
  "formats": ["markdown"],
  "render": true,
  "source": "all",
  "options": {
    "includeExternalLinks": false,
    "includeSubdomains": false,
    "includePatterns": ["**/docs/**"],
    "excludePatterns": ["**/blog/**"]
  }
}
```

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `url` | string | required | Starting URL |
| `limit` | number | 10 | Max pages (hard cap: 100,000) |
| `depth` | number | 100,000 | Link depth from start URL |
| `source` | string | `all` | URL discovery: `all`, `sitemaps`, `links` |
| `formats` | array | `["html"]` | `html`, `markdown`, `json` |
| `render` | boolean | `true` | Headless Chromium JS execution |
| `maxAge` | number | 86400 | Cache age in seconds (max: 604,800) |
| `jsonOptions.prompt` | string | — | AI extraction prompt (requires `json` in formats) |

**Response:** Returns job ID. Poll with GET.

### Poll: `GET .../crawl/{job_id}`

**Query params:** `cursor`, `limit`, `status` (filter by per-URL status)

**Response:**
```json
{
  "result": {
    "status": "running|completed|errored|cancelled_by_user",
    "records": [
      {
        "url": "https://...",
        "status": "completed|disallowed|skipped|errored",
        "markdown": "...",
        "html": "...",
        "json": {},
        "metadata": {"httpStatus": 200, "title": "..."}
      }
    ],
    "cursor": "pagination_token"
  }
}
```

Responses exceeding 10 MB are paginated via `cursor`.

### Cancel: `DELETE .../crawl/{job_id}`

## Single-Page Endpoints

All accept POST with `{"url": "...", "render": true}` plus endpoint-specific options.

| Endpoint | Returns | Extra options |
|----------|---------|---------------|
| `/markdown` | Clean markdown text | — |
| `/content` | Raw rendered HTML | — |
| `/screenshot` | PNG image (binary) | `screenshotOptions: {fullPage: true}` |
| `/pdf` | PDF document (binary) | — |
| `/json` | AI-extracted structured data | `jsonOptions: {prompt: "..."}` |
| `/links` | JSON array of URLs on page | — |
| `/scrape` | Element-level HTML | `elements: [{selector: "..."}]` |

**Common options for all single-page endpoints:**
```json
{
  "url": "...",
  "render": true,
  "gotoOptions": {"waitUntil": "networkidle2", "timeout": 30000},
  "waitForSelector": {"selector": ".content", "timeout": 10000, "visible": true},
  "rejectResourceTypes": ["image", "media", "font", "stylesheet"],
  "userAgent": "custom UA string",
  "cookies": [{"name": "...", "value": "...", "domain": "..."}],
  "authenticate": {"username": "...", "password": "..."},
  "setExtraHTTPHeaders": {"X-Custom": "value"}
}
```

## Limits

- **Free plan:** 10 minutes browser time per day
- **`render: false` mode:** Currently free (beta), will move to Workers pricing
- **AI extraction (`json`):** Uses Workers AI credits separately
- **Job max runtime:** 7 days before auto-cancellation
- **Results retained:** 14 days after completion
- **Browser time header:** `X-Browser-Ms-Used` in response
