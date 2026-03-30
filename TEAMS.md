# 👥 Team Achievements

Team achievements add collaborative goals and friendly competition to Claude Cheevos. Join a team to unlock exclusive achievements that reward collective productivity.

---

## Quick Start

### Creating or Joining a Team

```bash
# Install with team membership
bash install.sh \
  --token <your-api-token> \
  --api-url <leaderboard-api-url> \
  --team-id <team-uuid> \
  --team-name "Squad Jackal"

# Update existing installation to join a team
bash install.sh \
  --team-id <team-uuid> \
  --team-name "Squad Jackal"
```

Your team membership is stored in `~/.claude/achievements/leaderboard.conf`:

```bash
TEAM_ID=uuid-here
TEAM_NAME=Squad Jackal
```

### Viewing Team Progress

```bash
# See your contribution to team goals
~/.claude/achievements/cheevos team-stats
```

---

## How It Works

When you join a team, here's what happens:

1. **Installation**: Running `install.sh` with `--team-id` and `--team-name` adds these fields to your `leaderboard.conf`
2. **Local Tracking**: The `cheevos team-stats` command shows your individual progress toward team goals (no backend required)
3. **API Sync**: When enabled, `cheevos leaderboard-sync` includes your `team_id` in the payload sent to the leaderboard API
4. **Backend Aggregation** (pending): The API will sum stats across all team members and unlock team achievements when thresholds are met

**Current state:**
- ✅ Client-side implementation complete
- ✅ Team ID sent in leaderboard sync
- ✅ Local team stats display working
- ⏳ Backend aggregation logic pending
- ⏳ Team leaderboard UI pending

---

## How Team Achievements Work

There are **three types** of team achievements:

### 1. **Collaborative Achievements**
**Every team member** must reach the threshold individually.

- **Squad Goals** — All team members hit 100 sessions
  - *Unlocks when:* Every member has `sessions >= 100`
  - *Points:* 500 pts

These achievements require **full team participation**. They unlock when the entire team reaches a milestone together.

### 2. **Aggregate Achievements**
Team **totals** are summed across all members.

- **Knowledge Share** — Team reads 10,000 files collectively (+750 pts)
- **Code Factory** — Team writes 5,000 files collectively (+600 pts)
- **Review Board** — Team completes 100 code reviews (+400 pts)
- **Powerhouse Team** — Team total score exceeds 50,000 pts (+1000 pts)
- **Token Titans** — Team consumes 100M tokens (+800 pts)
- **Late Night Crew** — Team has 50+ midnight sessions (+300 pts)

### 3. **Competitive Achievements**
Based on **leaderboard rank**.

- **Top Squad** — #1 team on leaderboard for 7 consecutive days (+2000 pts, secret)

---

## Current Implementation Status

✅ **Client-side ready:**
- Team ID and name stored in `leaderboard.conf`
- `cheevos team-stats` shows local progress toward team goals
- Team achievements defined in definitions.json with `"team": true` flag
- Leaderboard sync sends `team_id` in API payloads

⏳ **Backend pending:**
- Team creation and management endpoints
- Team aggregation logic (sum member stats)
- Team leaderboard UI
- Team dashboard with member progress

---

## Backend API Specification

The following endpoints will be added to support team features:

```
POST   /teams                    # Create a new team
GET    /teams/{id}               # Get team details
GET    /teams/{id}/members       # List team roster
GET    /teams/leaderboard        # Team rankings
PUT    /teams/{id}/members/{uid} # Add a member to a team
```

**Database schema:**

```sql
CREATE TABLE Teams (
    team_id UUID PRIMARY KEY,
    team_name VARCHAR(255),
    created_at TIMESTAMP,
    total_score INT COMPUTED,
    member_count INT COMPUTED
);

CREATE TABLE TeamMembers (
    team_id UUID REFERENCES Teams(team_id),
    user_id UUID REFERENCES Users(user_id),
    joined_at TIMESTAMP,
    PRIMARY KEY (team_id, user_id)
);
```

---

## Business Value

**For Organizations:**
- Track team productivity across Claude Code usage
- Foster collaboration through shared goals
- Identify power users via team contribution metrics
- Competitive motivation through team rankings

**For Individual Users:**
- Social accountability — teammates keep you active
- Shared celebration — unlock achievements together
- Friendly competition — climb leaderboards as a team
- Viral growth — recruit coworkers to improve team rank

---

## Migration & Compatibility

**Existing users** can join teams at any time:

```bash
bash install.sh --team-id <team-id> --team-name "Team Name"
```

**Fully backward compatible:**
- Installations without teams continue to work normally
- Team fields are optional in leaderboard.conf
- API payload includes team_id only if set
- Individual achievements are never affected by team membership

---

## Technical Details

### Data Flow

```
User runs install.sh --team-id X --team-name Y
    ↓
leaderboard.conf updated with TEAM_ID and TEAM_NAME
    ↓
cheevos team-stats reads conf + encrypted state
    ↓
Displays individual stats and team achievement progress
    ↓
On achievement unlock, cheevos leaderboard-sync reads conf
    ↓
Includes team_id in JSON payload to API
    ↓
Backend (when implemented) aggregates team member stats
    ↓
Backend unlocks team achievements when thresholds met
```

### Files Modified

**Client-side changes (v2.0.0):**
- `install.sh` — Added `--team-id` and `--team-name` argument parsing
- `go/internal/defs/defs.go` — Added `Team` and `TeamAggregate` fields to Achievement struct
- `go/cmd/cheevos/subcmd/leaderboard_sync.go` — Added `TeamID` to leaderboard conf and API payload
- `go/cmd/cheevos/subcmd/show.go` — Added "Team Achievements" category
- `go/cmd/cheevos/subcmd/team_stats.go` — New subcommand to display team progress
- `go/cmd/cheevos/main.go` — Registered `team-stats` subcommand
- `data/definitions.json` — Added 8 team achievements

### Backward Compatibility

**Guaranteed compatibility:**
- Empty `TEAM_ID` = no team functionality (existing behavior preserved)
- API payload with empty `team_id` field = ignored by backend
- All individual achievements work identically with or without team membership
- Uninstalling or leaving a team doesn't affect individual progress

### Leaderboard API Payload

**Before (individual only):**
```json
{
  "username": "alice",
  "score": 1500,
  "unlock_count": 42,
  "last_updated": "2026-03-30T20:00:00Z"
}
```

**After (with team):**
```json
{
  "username": "alice",
  "score": 1500,
  "unlock_count": 42,
  "last_updated": "2026-03-30T20:00:00Z",
  "team_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

The `team_id` field is omitted if not set, maintaining full backward compatibility.

---

## FAQ

**Q: Can I be on multiple teams?**  
A: Currently no — each user has one `TEAM_ID` at a time.

**Q: Do team achievements affect my personal score?**  
A: No. Team achievements have their own point values that contribute to the **team's total score**, not individual scores.

**Q: What happens if I leave a team?**  
A: Your past contributions remain in the team's history, but future activity won't count toward team goals.

**Q: Can teams have any size?**  
A: Yes. Some achievements (like "Squad Goals") work best with 5+ members, but teams of any size can unlock aggregate achievements.

**Q: Are team achievements retroactive?**  
A: When you join a team, your **current stats** count toward team totals. For example, if you already have 1,000 files read, that counts immediately.

---

**Team achievements transform Claude Cheevos from an individual tool into a collaborative platform. Join a team and unlock together!** 🤝🏆
