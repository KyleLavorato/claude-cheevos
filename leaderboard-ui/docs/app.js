// ─── Configuration ────────────────────────────────────────────────────────────
// Replace these two constants with your deployed values before enabling GitHub Pages.
// The token is embedded here because this repo is private (internal use only).
const API_URL   = 'https://YOUR_API_GATEWAY_URL/prod';
const API_TOKEN = 'YOUR_TOKEN_HERE';

// Auto-refresh interval in milliseconds
const REFRESH_INTERVAL = 30_000;

// ─── DOM refs ─────────────────────────────────────────────────────────────────
const loading   = document.getElementById('loading');
const table     = document.getElementById('leaderboard');
const tbody     = document.getElementById('leaderboard-body');
const statsEl   = document.getElementById('stats');
const statusEl  = document.getElementById('status');
const emptyEl   = document.getElementById('empty');

const statPlayers  = document.getElementById('stat-players');
const statTopScore = document.getElementById('stat-top-score');
const statUnlocks  = document.getElementById('stat-total-unlocks');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatScore(n) {
    return Number(n).toLocaleString();
}

function formatDate(iso) {
    if (!iso) return '—';
    try {
        const d = new Date(iso);
        return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
    } catch (_) {
        return iso;
    }
}

function rankEmoji(rank) {
    if (rank === 1) return '🥇';
    if (rank === 2) return '🥈';
    if (rank === 3) return '🥉';
    return String(rank);
}

function showError(msg) {
    statusEl.textContent = msg;
    statusEl.className   = 'status error';
}

function clearError() {
    statusEl.className = 'status hidden';
}

// ─── Render ───────────────────────────────────────────────────────────────────

function render(users) {
    tbody.innerHTML = '';

    if (!users || users.length === 0) {
        table.classList.add('hidden');
        statsEl.classList.add('hidden');
        emptyEl.classList.remove('hidden');
        return;
    }

    emptyEl.classList.add('hidden');
    table.classList.remove('hidden');
    statsEl.classList.remove('hidden');

    // Stats row
    const totalUnlocks = users.reduce((sum, u) => sum + (Number(u.unlock_count) || 0), 0);
    statPlayers.textContent  = users.length;
    statTopScore.textContent = formatScore(users[0].score);
    statUnlocks.textContent  = totalUnlocks.toLocaleString();

    users.forEach((user, idx) => {
        const rank = idx + 1;
        const tr   = document.createElement('tr');
        tr.className = `rank-${rank}`;

        tr.innerHTML = `
            <td class="rank-cell">${rankEmoji(rank)}</td>
            <td>${escapeHtml(user.username || '(unknown)')}</td>
            <td class="score-cell">${formatScore(user.score)}</td>
            <td class="unlock-cell">${Number(user.unlock_count) || 0}</td>
            <td class="date-cell">${formatDate(user.last_updated)}</td>
        `;
        tbody.appendChild(tr);
    });
}

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

// ─── Fetch ────────────────────────────────────────────────────────────────────

async function fetchLeaderboard() {
    try {
        const resp = await fetch(`${API_URL}/users`, {
            headers: { 'Authorization': `Bearer ${API_TOKEN}` },
        });

        if (!resp.ok) {
            showError(`API error: ${resp.status} ${resp.statusText}`);
            return;
        }

        const data = await resp.json();
        clearError();
        loading.classList.add('hidden');
        render(data.users || []);
    } catch (err) {
        showError(`Failed to load leaderboard: ${err.message}`);
    }
}

// ─── Init ─────────────────────────────────────────────────────────────────────

fetchLeaderboard();
setInterval(fetchLeaderboard, REFRESH_INTERVAL);
