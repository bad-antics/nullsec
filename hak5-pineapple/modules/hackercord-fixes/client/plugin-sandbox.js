/**
 * NullSec Plugin Sandbox
 * ───────────────────────
 * Fixes: C6 (Unsafe Plugin System — runs in main JS context, full DOM access,
 *         can steal tokens, fetch() with credentials)
 *
 * Replaces direct plugin execution with:
 * - iframe sandbox (srcdoc, sandbox="allow-scripts")
 * - Communication via postMessage API only
 * - No access to parent DOM, cookies, localStorage, or credentials
 * - Resource limits: max plugins, message rate limiting
 *
 * @audit hackercord-audit.md — Finding C6
 * @priority P1 (1-2 days)
 */

'use strict';

// ─── Sandbox Configuration ──────────────────────────────────────────────────

const SANDBOX_CONFIG = {
  maxPlugins: 10,
  messageRateLimit: 50,      // max messages per second per plugin
  maxMessageSize: 64 * 1024, // 64KB per message
  allowedAPIs: [
    'sendMessage',           // Send chat message
    'onMessage',             // Receive chat messages
    'getServerInfo',         // Read-only server info
    'getUserInfo',           // Current user info (sanitized)
    'showNotification',      // Show toast notification
    'createUI',              // Render HTML in sandboxed area
    'storage.get',           // Plugin-scoped storage
    'storage.set',           // Plugin-scoped storage
  ],
  blockedAPIs: [
    'fetch',                 // No direct network access
    'XMLHttpRequest',        // No direct network access
    'document.cookie',       // No cookie access
    'localStorage',          // No storage access (JWT was here!)
    'sessionStorage',
    'eval',
    'Function',
    'importScripts',
  ],
};

// ─── Sandboxed iframe Template ──────────────────────────────────────────────

function createSandboxHTML(pluginCode, pluginId) {
  return `<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Security-Policy"
  content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline';">
</head>
<body>
<div id="plugin-root"></div>
<script>
(function() {
  'use strict';

  // ── Blocked globals ──────────────────────────────────────
  // Prevent plugin from accessing dangerous APIs
  delete window.fetch;
  delete window.XMLHttpRequest;
  delete window.WebSocket;
  delete window.EventSource;
  delete window.importScripts;

  Object.defineProperty(window, 'opener', { value: null });
  Object.defineProperty(window, 'parent', { value: null });
  Object.defineProperty(window, 'top', { value: window });
  Object.defineProperty(document, 'cookie', { get: () => '', set: () => {} });

  // ── NullSec Plugin API (postMessage bridge) ──────────────
  const _pending = new Map();
  let _msgId = 0;
  const _handlers = {};

  const HackerCord = {
    pluginId: '${pluginId}',

    // Send a request to the host
    _call(method, args) {
      return new Promise((resolve, reject) => {
        const id = ++_msgId;
        _pending.set(id, { resolve, reject, ts: Date.now() });
        window.parent.postMessage({
          type: 'nullsec_plugin_call',
          pluginId: '${pluginId}',
          id, method, args
        }, '*');
        // Timeout after 10s
        setTimeout(() => {
          if (_pending.has(id)) {
            _pending.delete(id);
            reject(new Error('Plugin API call timed out'));
          }
        }, 10000);
      });
    },

    sendMessage(channel, text) { return this._call('sendMessage', { channel, text }); },
    onMessage(callback) { _handlers['message'] = callback; },
    getServerInfo() { return this._call('getServerInfo', {}); },
    getUserInfo() { return this._call('getUserInfo', {}); },
    showNotification(text) { return this._call('showNotification', { text }); },
    createUI(html) {
      const root = document.getElementById('plugin-root');
      if (root) root.innerHTML = html;
    },
    storage: {
      get(key) { return HackerCord._call('storage.get', { key }); },
      set(key, value) { return HackerCord._call('storage.set', { key, value }); },
    },
  };

  // Handle responses from host
  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.pluginId !== '${pluginId}') return;

    if (data.type === 'nullsec_plugin_response') {
      const pending = _pending.get(data.id);
      if (pending) {
        _pending.delete(data.id);
        if (data.error) pending.reject(new Error(data.error));
        else pending.resolve(data.result);
      }
    }

    if (data.type === 'nullsec_plugin_event') {
      const handler = _handlers[data.event];
      if (handler) handler(data.payload);
    }
  });

  // Make API available to plugin
  window.HackerCord = Object.freeze(HackerCord);

  // ── Execute plugin code ──────────────────────────────────
  try {
    ${pluginCode}
  } catch (e) {
    window.parent.postMessage({
      type: 'nullsec_plugin_error',
      pluginId: '${pluginId}',
      error: e.message
    }, '*');
  }
})();
<\/script>
</body>
</html>`;
}

// ─── Plugin Host (manages sandboxed iframes) ────────────────────────────────

class PluginHost {
  constructor(container) {
    this.container = container || document.body;
    this.plugins = new Map(); // pluginId → { iframe, config, messageCount }
    this.apiHandlers = {};

    // Listen for plugin messages
    window.addEventListener('message', (event) => this._onMessage(event));
  }

  /**
   * Load a plugin in a sandboxed iframe.
   */
  load(pluginId, code, options = {}) {
    if (this.plugins.size >= SANDBOX_CONFIG.maxPlugins) {
      throw new Error(`Maximum ${SANDBOX_CONFIG.maxPlugins} plugins allowed`);
    }

    if (this.plugins.has(pluginId)) {
      this.unload(pluginId);
    }

    const iframe = document.createElement('iframe');
    iframe.setAttribute('sandbox', 'allow-scripts');  // NO allow-same-origin!
    iframe.style.cssText = options.visible
      ? 'width:100%;height:200px;border:1px solid #333;'
      : 'display:none;width:0;height:0;';

    const html = createSandboxHTML(code, pluginId);
    iframe.srcdoc = html;

    this.container.appendChild(iframe);
    this.plugins.set(pluginId, {
      iframe,
      config: options,
      messageCount: 0,
      lastReset: Date.now(),
    });

    console.log(`[NullSec] Plugin loaded in sandbox: ${pluginId}`);
  }

  /**
   * Unload a plugin and destroy its iframe.
   */
  unload(pluginId) {
    const plugin = this.plugins.get(pluginId);
    if (plugin) {
      plugin.iframe.remove();
      this.plugins.delete(pluginId);
      console.log(`[NullSec] Plugin unloaded: ${pluginId}`);
    }
  }

  /**
   * Register host-side API handler.
   */
  registerAPI(method, handler) {
    if (!SANDBOX_CONFIG.allowedAPIs.includes(method)) {
      throw new Error(`API method '${method}' is not in the allowlist`);
    }
    this.apiHandlers[method] = handler;
  }

  /**
   * Send event to a specific plugin.
   */
  sendEvent(pluginId, event, payload) {
    const plugin = this.plugins.get(pluginId);
    if (plugin) {
      plugin.iframe.contentWindow?.postMessage({
        type: 'nullsec_plugin_event',
        pluginId,
        event,
        payload,
      }, '*');
    }
  }

  /**
   * Broadcast event to all plugins.
   */
  broadcast(event, payload) {
    for (const [pluginId] of this.plugins) {
      this.sendEvent(pluginId, event, payload);
    }
  }

  // ── Internal message handler ──────────────────────────────

  async _onMessage(event) {
    const data = event.data;
    if (!data?.type?.startsWith('nullsec_plugin_')) return;

    const pluginId = data.pluginId;
    const plugin = this.plugins.get(pluginId);
    if (!plugin) return;

    // Verify message comes from the right iframe
    if (event.source !== plugin.iframe.contentWindow) return;

    // Rate limiting
    const now = Date.now();
    if (now - plugin.lastReset > 1000) {
      plugin.messageCount = 0;
      plugin.lastReset = now;
    }
    plugin.messageCount++;
    if (plugin.messageCount > SANDBOX_CONFIG.messageRateLimit) {
      console.warn(`[NullSec] Plugin ${pluginId} rate limited`);
      return;
    }

    if (data.type === 'nullsec_plugin_call') {
      const handler = this.apiHandlers[data.method];
      try {
        if (!handler) throw new Error(`Unknown API: ${data.method}`);
        if (!SANDBOX_CONFIG.allowedAPIs.includes(data.method)) {
          throw new Error(`Blocked API: ${data.method}`);
        }
        const result = await handler(data.args, pluginId);
        plugin.iframe.contentWindow?.postMessage({
          type: 'nullsec_plugin_response',
          pluginId, id: data.id, result,
        }, '*');
      } catch (err) {
        plugin.iframe.contentWindow?.postMessage({
          type: 'nullsec_plugin_response',
          pluginId, id: data.id, error: err.message,
        }, '*');
      }
    }

    if (data.type === 'nullsec_plugin_error') {
      console.error(`[NullSec] Plugin ${pluginId} error:`, data.error);
    }
  }

  destroy() {
    for (const [pluginId] of this.plugins) {
      this.unload(pluginId);
    }
    window.removeEventListener('message', this._onMessage);
  }
}

// ─── Export ─────────────────────────────────────────────────────────────────

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { PluginHost, SANDBOX_CONFIG, createSandboxHTML };
} else {
  window.NullSecPluginHost = PluginHost;
}
