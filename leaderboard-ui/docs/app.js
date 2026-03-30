// ─── Configuration ────────────────────────────────────────────────────────────
// Replace these two constants with your deployed values before enabling GitHub Pages.
// The token is embedded here because this repo is private (internal use only).
const API_URL   = 'https://YOUR_API_GATEWAY_URL/prod';
const API_TOKEN = 'YOUR_TOKEN_HERE';

// Auto-refresh interval in milliseconds (15 minutes)
const REFRESH_INTERVAL = 900_000;

// ─── State ────────────────────────────────────────────────────────────────────
let allUsers = [];

// ─── DOM refs ─────────────────────────────────────────────────────────────────
const loading    = document.getElementById('loading');
const table      = document.getElementById('leaderboard');
const tbody      = document.getElementById('leaderboard-body');
const statsEl    = document.getElementById('stats');
const statusEl   = document.getElementById('status');
const emptyEl    = document.getElementById('empty');
const searchEl   = document.getElementById('search-input');
const refreshBtn = document.getElementById('refresh-btn');
const noResults  = document.getElementById('no-results');

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

function escapeHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

// ─── Render ───────────────────────────────────────────────────────────────────

function renderStats(users) {
    const totalUnlocks = users.reduce((sum, u) => sum + (Number(u.unlock_count) || 0), 0);
    statPlayers.textContent  = users.length;
    statTopScore.textContent = users.length > 0 ? formatScore(users[0].score) : '—';
    statUnlocks.textContent  = totalUnlocks.toLocaleString();
}

function renderRows(users, query) {
    tbody.innerHTML = '';
    noResults.classList.add('hidden');

    if (users.length === 0) {
        if (query) {
            noResults.textContent = query;
            noResults.classList.remove('hidden');
        }
        return;
    }

    users.forEach((user, idx) => {
        const rank = idx + 1;
        const tr   = document.createElement('tr');
        tr.className = `rank-${rank}`;
        if (query) tr.classList.add('search-match');

        tr.innerHTML = `
            <td class="rank-cell">${rankEmoji(rank)}</td>
            <td class="username-cell">${escapeHtml(user.username || '(unknown)')}</td>
            <td class="score-cell">${formatScore(user.score)}</td>
            <td class="unlock-cell">${Number(user.unlock_count) || 0}</td>
            <td class="date-cell">${formatDate(user.last_updated)}</td>
        `;
        tbody.appendChild(tr);
    });
}

function render(users) {
    if (!users || users.length === 0) {
        table.classList.add('hidden');
        statsEl.classList.add('hidden');
        emptyEl.classList.remove('hidden');
        return;
    }

    emptyEl.classList.add('hidden');
    table.classList.remove('hidden');
    statsEl.classList.remove('hidden');

    renderStats(users);
    renderRows(users, '');
}

// ─── Search ───────────────────────────────────────────────────────────────────

function applySearch() {
    const query = searchEl.value.trim().toLowerCase();
    if (!allUsers.length) return;

    emptyEl.classList.add('hidden');
    table.classList.remove('hidden');

    if (!query) {
        renderRows(allUsers, '');
        return;
    }

    const filtered = allUsers.filter(u =>
        (u.username || '').toLowerCase().includes(query)
    );

    renderRows(filtered, query);
}

searchEl.addEventListener('input', applySearch);

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
        allUsers = data.users || [];
        render(allUsers);

        // Re-apply any active search after data refresh
        if (searchEl.value.trim()) applySearch();
    } catch (err) {
        showError(`Failed to load leaderboard: ${err.message}`);
    }
}

// ─── Manual refresh ───────────────────────────────────────────────────────────

refreshBtn.addEventListener('click', () => {
    if (refreshBtn.classList.contains('spinning')) return;
    refreshBtn.classList.add('spinning');
    refreshBtn.textContent = '↻ refreshing...';
    fetchLeaderboard().finally(() => {
        refreshBtn.classList.remove('spinning');
        refreshBtn.textContent = '↻ refresh';
    });
});

// ─── Init ─────────────────────────────────────────────────────────────────────

fetchLeaderboard();
setInterval(fetchLeaderboard, REFRESH_INTERVAL);
