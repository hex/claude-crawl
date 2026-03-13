# Jina AI API Reference

## Reader (r.jina.ai)

**Endpoint:** `GET https://r.jina.ai/{url}`

No URL encoding needed — append the URL directly.

**Headers:**
| Header | Purpose |
|--------|---------|
| `Authorization: Bearer $JINA_AI_API_KEY` | Auth (optional — 20 RPM without, 500 RPM with) |
| `X-Return-Format: markdown` | Output format (default: markdown) |
| `X-Timeout: 30` | Max wait in seconds |
| `X-Target-Selector: .main-content` | Extract specific CSS element |
| `X-Wait-For-Selector: .loaded` | Wait for dynamic content |
| `X-Remove-Selector: .nav,.footer` | Exclude elements |
| `X-With-Generated-Alt: true` | Generate image alt text |

**Rate limits:**
- No key: 20 RPM
- Free key: 500 RPM
- Paid key: 500 RPM
- Premium: 5,000 RPM

**Token cost:** Based on output length.

**Cannot:** Access login-gated content, bypass anti-bot systems, translate content.

---

## Search (s.jina.ai)

**Endpoint:** `GET https://s.jina.ai/{query}`

**Headers:**
| Header | Purpose |
|--------|---------|
| `Authorization: Bearer $JINA_AI_API_KEY` | Auth |
| `Accept: application/json` | JSON response format |

**Cost:** Minimum 10,000 tokens per request regardless of response size. Batch searches
rather than making many small ones.

Returns top 5 results with URL, title, and content.

---

## Reranker (api.jina.ai)

**Endpoint:** `POST https://api.jina.ai/v1/rerank`

**Request body:**
```json
{
  "model": "jina-reranker-v2-base-multilingual",
  "query": "search query",
  "documents": ["doc 1 text", "doc 2 text"],
  "top_n": 5,
  "return_documents": true
}
```

**Models:**
| Model | Context | Strengths |
|-------|---------|-----------|
| `jina-reranker-v3` | 131K tokens | Listwise scoring, SOTA multilingual |
| `jina-reranker-v2-base-multilingual` | 1K tokens | 100+ languages, fast |
| `jina-reranker-m0` | 10K tokens | Multimodal (text + image) |

**Response:** `results[]` with `index`, `relevance_score`, and optionally `document`.

**Rate limits:** 100 RPM free, 500 RPM paid.

**Token cost:** Based on input length (unlike Reader which counts output).

---

## Grounding (g.jina.ai)

**Endpoint:** `POST https://g.jina.ai`

(Migrating to `POST https://deepsearch.jina.ai/v1/chat/completions`)

**Request body:**
```json
{
  "statement": "The claim to verify"
}
```

**Response:**
```json
{
  "data": {
    "factuality": 0.95,
    "result": true,
    "reason": "Explanation of verdict",
    "references": [
      {"url": "...", "keyQuote": "...", "isSupportive": true}
    ]
  }
}
```

**Performance:** ~30 seconds per call, ~300K tokens consumed. Up to 30 references.

**F1 score:** 0.92 (vs Gemini Flash 0.84, GPT-4o 0.72).

**Cost:** ~$0.006 per request at $0.02/1M tokens.

**Not suitable for:** Opinions, hypotheticals, future events, or claims without web evidence.
