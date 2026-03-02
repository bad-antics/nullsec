/* ═══════════════════════════════════════════════════════════════════════════
   NullSec WebTools — Core JavaScript
   HTMX helpers, API client, WebSocket terminal, notifications, polling
   ═══════════════════════════════════════════════════════════════════════════ */

const NS = {
    // ── API Client ──────────────────────────────────────────────────────────
    async api(endpoint, opts = {}) {
        const defaults = {
            headers: { 'Content-Type': 'application/json' },
        };
        const config = { ...defaults, ...opts };
        if (opts.body && typeof opts.body === 'object') {
            config.body = JSON.stringify(opts.body);
        }
        try {
            const res = await fetch(endpoint, config);
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            return await res.json();
        } catch (err) {
            console.error(`[NS] API error: ${endpoint}`, err);
            NS.notify(err.message, 'error');
            throw err;
        }
    },

    async get(endpoint) { return NS.api(endpoint); },
    async post(endpoint, body) { return NS.api(endpoint, { method: 'POST', body }); },

    // ── Notifications ───────────────────────────────────────────────────────
    notify(msg, type = 'info') {
        const container = document.getElementById('notifications') || NS._createNotifContainer();
        const el = document.createElement('div');
        el.className = `notif notif-${type}`;
        el.innerHTML = `<span>${msg}</span><button onclick="this.parentElement.remove()">&times;</button>`;
        container.appendChild(el);
        setTimeout(() => el.remove(), 5000);
    },

    _createNotifContainer() {
        const c = document.createElement('div');
        c.id = 'notifications';
        c.style.cssText = 'position:fixed;top:70px;right:24px;z-index:999;display:flex;flex-direction:column;gap:8px;width:320px;';
        document.body.appendChild(c);
        return c;
    },

    // ── Polling Engine ──────────────────────────────────────────────────────
    _polls: {},

    poll(id, endpoint, callback, interval = 10000) {
        if (NS._polls[id]) clearInterval(NS._polls[id]);
        const tick = async () => {
            try {
                const data = await NS.get(endpoint);
                callback(data);
            } catch (_) {}
        };
        tick();
        NS._polls[id] = setInterval(tick, interval);
    },

    stopPoll(id) {
        if (NS._polls[id]) {
            clearInterval(NS._polls[id]);
            delete NS._polls[id];
        }
    },

    stopAllPolls() {
        Object.keys(NS._polls).forEach(id => NS.stopPoll(id));
    },

    // ── Formatters ──────────────────────────────────────────────────────────
    formatBytes(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    },

    formatUptime(seconds) {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor((seconds % 86400) / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (d > 0) return `${d}d ${h}h`;
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    },

    progressClass(pct) {
        if (pct > 90) return 'danger';
        if (pct > 70) return 'warn';
        return '';
    },

    // ── DOM Helpers ─────────────────────────────────────────────────────────
    $(sel) { return document.querySelector(sel); },
    $$(sel) { return document.querySelectorAll(sel); },

    html(sel, content) {
        const el = typeof sel === 'string' ? NS.$(sel) : sel;
        if (el) el.innerHTML = content;
    },

    show(sel) { NS.$(sel)?.classList.remove('hidden'); },
    hide(sel) { NS.$(sel)?.classList.add('hidden'); },

    // ── Cluster Exec ────────────────────────────────────────────────────────
    async execOnNode(nodeName, command) {
        NS.notify(`Executing on ${nodeName}...`, 'info');
        const data = await NS.post('/cluster/api/exec', { node: nodeName, command });
        return data;
    },

    async execOnAll(command) {
        NS.notify('Broadcasting command to all nodes...', 'info');
        const data = await NS.post('/cluster/api/exec-all', { command });
        return data;
    },

    // ── Network Scan ────────────────────────────────────────────────────────
    async scanTarget(target, ports) {
        NS.notify(`Scanning ${target}...`, 'info');
        const data = await NS.post('/network/api/scan', { target, ports });
        return data;
    },

    async discoverSubnet(subnet, port) {
        NS.notify(`Discovering ${subnet}...`, 'info');
        const data = await NS.post('/network/api/discover', { subnet, port: parseInt(port) });
        return data;
    },

    // ── WebSocket Terminal ──────────────────────────────────────────────────
    terminal: {
        ws: null,
        buffer: '',
        onData: null,

        connect(nodeName) {
            const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
            const url = `${proto}//${location.host}/terminal/ws/${nodeName}`;
            
            if (NS.terminal.ws) NS.terminal.disconnect();
            
            NS.terminal.ws = new WebSocket(url);
            
            NS.terminal.ws.onopen = () => {
                NS.notify(`Connected to ${nodeName}`, 'success');
                if (NS.terminal.onData) NS.terminal.onData(`\r\n[Connected to ${nodeName}]\r\n`);
            };
            
            NS.terminal.ws.onmessage = (e) => {
                if (NS.terminal.onData) NS.terminal.onData(e.data);
            };
            
            NS.terminal.ws.onclose = () => {
                NS.notify(`Disconnected from ${nodeName}`, 'info');
                if (NS.terminal.onData) NS.terminal.onData(`\r\n[Connection closed]\r\n`);
            };
            
            NS.terminal.ws.onerror = (err) => {
                NS.notify('Terminal connection error', 'error');
            };
        },

        send(data) {
            if (NS.terminal.ws?.readyState === WebSocket.OPEN) {
                NS.terminal.ws.send(data);
            }
        },

        disconnect() {
            if (NS.terminal.ws) {
                NS.terminal.ws.close();
                NS.terminal.ws = null;
            }
        }
    },

    // ── Payload Search ──────────────────────────────────────────────────────
    async searchPayloads(query) {
        const data = await NS.get(`/payloads/api/list?search=${encodeURIComponent(query)}`);
        return data;
    },

    // ── Loot Browser ────────────────────────────────────────────────────────
    async browseLoot(payloadName) {
        return NS.get(`/loot/api/files/${encodeURIComponent(payloadName)}`);
    },

    async readLoot(payloadName, filename) {
        return NS.get(`/loot/api/read/${encodeURIComponent(payloadName)}/${encodeURIComponent(filename)}`);
    },

    // ── Active Page ─────────────────────────────────────────────────────────
    initNav() {
        const path = location.pathname;
        NS.$$('.nav-links a').forEach(a => {
            a.classList.remove('active');
            const href = a.getAttribute('href');
            if (path === href || (href !== '/' && path.startsWith(href))) {
                a.classList.add('active');
            }
        });
    },

    // ── Init ────────────────────────────────────────────────────────────────
    init() {
        NS.initNav();
        // Global status poll
        NS.poll('status', '/api/dashboard/stats', (data) => {
            const dot = NS.$('.status-dot');
            const txt = NS.$('.status-text');
            if (dot && txt) {
                const online = data.nodes_online || 0;
                const total = data.total_nodes || 0;
                dot.className = `status-dot ${online > 0 ? 'online' : 'offline'}`;
                txt.textContent = `${online}/${total} nodes`;
            }
        }, 15000);
    }
};

// Notification styles injected
const notifStyle = document.createElement('style');
notifStyle.textContent = `
.notif {
    background: #111; border: 1px solid #222; border-radius: 6px;
    padding: 10px 14px; display: flex; justify-content: space-between;
    align-items: center; font-size: 12px; animation: slideIn 0.2s;
}
.notif button { background:none; border:none; color:#888; cursor:pointer; font-size:16px; }
.notif-info { border-left: 3px solid #00aaff; }
.notif-success { border-left: 3px solid #00ff88; }
.notif-error { border-left: 3px solid #ff4444; }
.notif-warn { border-left: 3px solid #ffcc00; }
@keyframes slideIn { from { transform: translateX(100%); opacity:0; } to { transform: translateX(0); opacity:1; } }
.hidden { display: none !important; }
`;
document.head.appendChild(notifStyle);

// Boot
document.addEventListener('DOMContentLoaded', NS.init);
