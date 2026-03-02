/**
 * NullSec Client Cleanup
 * ────────────────────────
 * Fixes: M4 (Ancient Polyfills — html5shiv + respond.js from 2013)
 *        M5 (No sitemap.xml)
 *
 * Provides:
 * - Script to detect and remove outdated polyfills
 * - Runtime check for unnecessary legacy code
 *
 * @audit hackercord-audit.md — Finding M4, M5
 * @priority P2 (5 min + 15 min)
 */

'use strict';

// ─── Polyfill Detector ──────────────────────────────────────────────────────

const LEGACY_SCRIPTS = [
  { name: 'html5shiv', patterns: ['html5shiv', 'html5shim'], since: 2013, reason: 'HTML5 elements supported since IE9+' },
  { name: 'respond.js', patterns: ['respond.min.js', 'respond.js'], since: 2013, reason: 'Media queries supported since IE9+' },
  { name: 'es5-shim', patterns: ['es5-shim', 'es5-sham'], since: 2015, reason: 'ES5 supported in all modern browsers' },
  { name: 'json2.js', patterns: ['json2.js', 'json3.js'], since: 2013, reason: 'JSON native since IE8+' },
  { name: 'selectivizr', patterns: ['selectivizr'], since: 2014, reason: 'CSS3 selectors native in all modern browsers' },
  { name: 'PIE.js', patterns: ['PIE.js', 'PIE.htc'], since: 2015, reason: 'CSS3 properties native in all modern browsers' },
  { name: 'Modernizr', patterns: ['modernizr'], since: 2020, reason: 'Use @supports CSS rule instead' },
];

/**
 * Scan the current page for legacy polyfill scripts.
 * @returns {Array<{name: string, element: HTMLElement, reason: string}>}
 */
function detectLegacyScripts() {
  if (typeof document === 'undefined') return [];

  const scripts = document.querySelectorAll('script[src]');
  const found = [];

  for (const script of scripts) {
    const src = script.getAttribute('src')?.toLowerCase() || '';
    for (const legacy of LEGACY_SCRIPTS) {
      if (legacy.patterns.some(p => src.includes(p))) {
        found.push({
          name: legacy.name,
          src: script.getAttribute('src'),
          element: script,
          reason: legacy.reason,
          unmaintainedSince: legacy.since,
        });
      }
    }
  }

  return found;
}

/**
 * Remove detected legacy scripts from the page.
 */
function removeLegacyScripts() {
  const found = detectLegacyScripts();

  for (const item of found) {
    item.element.remove();
    console.log(`[NullSec] Removed legacy polyfill: ${item.name} (${item.reason})`);
  }

  return found.length;
}

// ─── Conditional IE comment cleaner ─────────────────────────────────────────

/**
 * Remove IE conditional comments from HTML.
 * HackerCord likely has <!--[if lt IE 9]> blocks wrapping polyfills.
 */
function removeIEConditionals(html) {
  if (typeof html !== 'string') return html;
  // Remove <!--[if ... ]> ... <![endif]-->
  return html.replace(/<!--\[if[^\]]*\]>[\s\S]*?<!\[endif\]-->/gi, '');
}

// ─── Browser Support Check ──────────────────────────────────────────────────

function getBrowserSupport() {
  const support = {
    es2020: typeof globalThis !== 'undefined' && typeof BigInt !== 'undefined',
    esModules: 'noModule' in HTMLScriptElement.prototype,
    customElements: 'customElements' in window,
    webComponents: 'attachShadow' in Element.prototype,
    cssGrid: CSS.supports('display', 'grid'),
    cssVariables: CSS.supports('color', 'var(--test)'),
    fetch: 'fetch' in window,
    webCrypto: 'crypto' in window && 'subtle' in window.crypto,
    webRTC: 'RTCPeerConnection' in window,
    webSocket: 'WebSocket' in window,
    serviceWorker: 'serviceWorker' in navigator,
  };

  const allSupported = Object.values(support).every(Boolean);
  return { ...support, allModernAPIs: allSupported };
}

// ─── Report Generator ───────────────────────────────────────────────────────

function generateCleanupReport() {
  const legacyScripts = detectLegacyScripts();
  const browserSupport = typeof document !== 'undefined' ? getBrowserSupport() : {};

  return {
    timestamp: new Date().toISOString(),
    auditor: 'NullSec',
    legacyScripts: legacyScripts.map(s => ({
      name: s.name,
      src: s.src,
      reason: s.reason,
      unmaintainedSince: s.unmaintainedSince,
    })),
    browserSupport,
    recommendations: [
      legacyScripts.length > 0
        ? `Remove ${legacyScripts.length} legacy polyfills (${legacyScripts.map(s => s.name).join(', ')})`
        : 'No legacy polyfills detected ✓',
      'Add sitemap.xml (see config/sitemap.xml)',
      'Add robots.txt with sitemap reference',
      'Consider using <script type="module"> for ES module loading',
    ],
  };
}

// ─── Export ─────────────────────────────────────────────────────────────────

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    detectLegacyScripts,
    removeLegacyScripts,
    removeIEConditionals,
    getBrowserSupport,
    generateCleanupReport,
    LEGACY_SCRIPTS,
  };
} else {
  window.NullSecCleanup = {
    detectLegacyScripts,
    removeLegacyScripts,
    removeIEConditionals,
    getBrowserSupport,
    generateCleanupReport,
  };
}
