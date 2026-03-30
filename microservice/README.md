# service-claude-cheevo — Leaderboard Microservice

Self-contained CloudFormation stack for the Claude Code Achievement leaderboard.
All Lambda code is inline in the template — no build step required.

## Architecture

```
Client (leaderboard-ui)
  └─ HTTPS → API Gateway (Regional)
               ├─ Lambda Authorizer  ←─ Secrets Manager (bearer token)
               └─ Lambda Handler     ←─ DynamoDB (user scores)
```

**Resources created** (all prefixed `service-claude-cheevo`):

| Resource | Type |
|---|---|
| `service-claude-cheevo-users` | DynamoDB table (PAY_PER_REQUEST, PITR enabled) |
| `service-claude-cheevo/api-token` | Secrets Manager secret |
| `service-claude-cheevo-lambda-role` | IAM role |
| `service-claude-cheevo-authorizer` | Lambda — TOKEN authorizer (300s TTL cache) |
| `service-claude-cheevo-api` | Lambda — REST handler |
| `service-claude-cheevo-api` | API Gateway RestApi |

## Prerequisites

- AWS CLI configured with credentials that have CloudFormation, IAM, Lambda, API Gateway,
  DynamoDB, and Secrets Manager permissions.
- `aws` CLI v2.

## Deploy

The stack auto-generates a cryptographically random 48-character bearer token in Secrets
Manager at deploy time. No token needs to be supplied — retrieve it afterward (see below).

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name service-claude-cheevo \
  --parameter-overrides Environment=prod \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

> `CAPABILITY_NAMED_IAM` is required because the template creates a named IAM role.

### Get the API URL and token

After deploy, retrieve both values and keep them — they don't change:

```bash
# API URL (paste into app.js and install.sh --api-url)
aws cloudformation describe-stacks \
  --stack-name service-claude-cheevo \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text

# Bearer token (use with install.sh --token and app.js API_TOKEN)
aws secretsmanager get-secret-value \
  --secret-id service-claude-cheevo/api-token \
  --query SecretString \
  --output text
```

### Smoke test

```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name service-claude-cheevo \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id service-claude-cheevo/api-token \
  --query SecretString \
  --output text)

# List users (empty on fresh deploy)
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/users" | jq .

# Create/update a user
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","score":500,"unlock_count":12,"last_updated":"2026-01-01T00:00:00Z"}' \
  "$API_URL/users/$(uuidgen | tr '[:upper:]' '[:lower:]')" | jq .

# List again — alice should appear
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/users" | jq .

# Delete alice (use the user_id returned above; simulates uninstall)
ALICE_ID=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/users" \
  | jq -r '.users[] | select(.username=="alice") | .user_id')
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
  "$API_URL/users/$ALICE_ID" | jq .

# Verify alice is gone
curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/users" | jq .
```

## Update / Redeploy

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name service-claude-cheevo \
  --capabilities CAPABILITY_NAMED_IAM
```

The existing Secrets Manager secret (and its generated token) is preserved across redeployments
because CloudFormation only replaces the secret if the resource itself is replaced.

## Teardown

```bash
aws cloudformation delete-stack --stack-name service-claude-cheevo
```

> DynamoDB PITR is enabled — export data before teardown if you need it.

## API Reference

All routes require `Authorization: Bearer <token>` except OPTIONS preflight.

### GET /users

Returns all users sorted by score descending. Only leaderboard fields are returned
(no full attribute dump). Response is ≤ ~50 KB for 300 users.

**Response 200:**
```json
{
  "users": [
    {
      "user_id": "uuid",
      "username": "alice",
      "score": 1200,
      "unlock_count": 30,
      "last_updated": "2026-03-15T10:00:00Z"
    }
  ]
}
```

### GET /users/{userId}

Returns a single user by UUID.

**Response 200:** User object (same fields as above).
**Response 404:** `{"error": "User not found"}`

### PUT /users/{userId}

Creates or replaces a user record. All four non-key fields are required.

**Request body:**
```json
{
  "username": "alice",
  "score": 1200,
  "unlock_count": 30,
  "last_updated": "2026-03-15T10:00:00Z"
}
```

**Response 200:** `{"ok": true}`
**Response 400:** `{"error": "Missing fields: [...]"}`

### DELETE /users/{userId}

Removes a user record entirely. Called by `uninstall.sh` when leaderboard sync is enabled,
so the player disappears from the leaderboard when they uninstall cheevos.
Idempotent — deleting a non-existent user returns 200.

**Response 200:** `{"ok": true}`

### DynamoDB Schema

| Attribute | Type | Notes |
|---|---|---|
| `user_id` | String (PK) | UUID generated at install |
| `username` | String | Truncated to 64 chars |
| `score` | Number | Achievement points |
| `unlock_count` | Number | Achievements unlocked |
| `last_updated` | String | ISO 8601 UTC timestamp |
