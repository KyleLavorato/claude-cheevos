# leaderboard-ui — Generic GitHub Pages Leaderboard

A clean, responsive leaderboard UI for the Claude Code Achievement System.
Fetches scores from the `service-claude-cheevo` API and auto-refreshes every 30 seconds.

## Files

```
docs/
├── index.html   — Table: rank, username, score, achievements, last-active
├── style.css    — Dark theme; gold/silver/bronze top-3 highlight; responsive
└── app.js       — API_URL + API_TOKEN constants; fetch + sort + render; 30s refresh
```

## Setup: GitHub Pages

1. **Deploy the CloudFormation stack** in `../microservice/` and note the `ApiUrl` output.

2. **Edit `docs/app.js`** — replace the two constants at the top:
   ```javascript
   const API_URL   = 'https://YOUR-ID.execute-api.us-east-1.amazonaws.com/prod';
   const API_TOKEN = 'your-strong-secret-token';
   ```

3. **Push to your repo** (must be a private repo if embedding the token).

4. **Enable GitHub Pages:**
   - Go to repo **Settings → Pages**.
   - Source: **Deploy from a branch** → branch `main` → folder `/docs`.
   - Save. GitHub will publish to `https://<org>.github.io/<repo>/`.

5. **Navigate to the Pages URL** — the leaderboard loads automatically.

## Configuration Reference

| Constant | Description |
|---|---|
| `API_URL` | Base URL from CloudFormation `ApiUrl` output (no trailing slash) |
| `API_TOKEN` | Bearer token; must match `service-claude-cheevo/api-token` in Secrets Manager |
| `REFRESH_INTERVAL` | Auto-refresh in ms (default: `30_000`) |

## Local Development

Open `docs/index.html` directly in a browser. Because the API requires CORS, you'll need
to either use a local proxy or temporarily allow the browser to skip CORS checks:

```bash
# Quick local server (Python 3)
python3 -m http.server 8080 --directory docs
# Then open http://localhost:8080
```

Set `API_URL` to the deployed API URL — the stack sends `Access-Control-Allow-Origin: *`
so cross-origin requests from `localhost` work fine.

## Customisation

The top-3 rows get gold/silver/bronze highlight via `.rank-1`, `.rank-2`, `.rank-3` CSS
classes. Add more columns by extending the `<thead>` in `index.html` and the `tr.innerHTML`
template in `app.js`.

Auto-refresh timing (`REFRESH_INTERVAL`) can be increased to reduce API Gateway call volume.
At 300 concurrent viewers refreshing every 30s, that's 600 req/min — well within the
default API Gateway throttle (10,000 req/s burst).
