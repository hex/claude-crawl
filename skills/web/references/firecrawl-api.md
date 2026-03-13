# Firecrawl REST API Reference

**Base URL:** `https://api.firecrawl.dev/v1`

**Auth:** `Authorization: Bearer $FIRECRAWL_API_KEY`

## Scrape: `POST /v1/scrape`

Single page extraction with JavaScript rendering.

**Request:**
```json
{
  "url": "https://example.com",
  "formats": ["markdown"],
  "onlyMainContent": true,
  "waitFor": 2000,
  "includeTags": ["article", "main"],
  "excludeTags": ["nav", "footer"],
  "timeout": 30000
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "markdown": "# Page Title\n...",
    "metadata": {
      "title": "...",
      "sourceURL": "...",
      "statusCode": 200
    }
  }
}
```

## Crawl: `POST /v1/crawl`

Async multi-page crawl. Returns job ID, poll for results.

**Request:**
```json
{
  "url": "https://example.com",
  "limit": 10,
  "maxDepth": 3,
  "includePaths": ["/docs/*"],
  "excludePaths": ["/blog/*"],
  "scrapeOptions": {
    "formats": ["markdown"],
    "onlyMainContent": true
  }
}
```

**Response (start):**
```json
{
  "success": true,
  "id": "job_id_here"
}
```

**Poll: `GET /v1/crawl/{job_id}`**

```json
{
  "status": "completed|scraping|waiting|failed|cancelled",
  "completed": 15,
  "total": 20,
  "creditsUsed": 15,
  "data": [
    {
      "markdown": "...",
      "metadata": {"sourceURL": "...", "title": "..."}
    }
  ]
}
```

## Map: `POST /v1/map`

Discover all URLs on a domain without scraping content.

**Request:**
```json
{
  "url": "https://example.com",
  "limit": 100,
  "includeSubdomains": false,
  "search": "optional filter query"
}
```

**Response:**
```json
{
  "success": true,
  "links": [
    "https://example.com/page1",
    "https://example.com/page2"
  ]
}
```

## Search: `POST /v1/search`

Web search with optional full-page scraping of results.

**Request:**
```json
{
  "query": "search terms",
  "limit": 5,
  "scrapeOptions": {
    "formats": ["markdown"]
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "url": "...",
      "title": "...",
      "description": "...",
      "markdown": "..."
    }
  ]
}
```

## Error Handling

All endpoints return `{"success": false, "error": "message"}` on failure.

Common error codes:
- 401: Invalid or missing API key
- 402: Insufficient credits
- 429: Rate limited
- 500: Server error
