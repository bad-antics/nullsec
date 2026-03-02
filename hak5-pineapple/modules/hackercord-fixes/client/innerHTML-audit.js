/**
 * NullSec innerHTML Audit Guard
 * ───────────────────────────────
 * Fixes: H4 (innerHTML + User Data — 8+ locations in chat.js rely on esc() everywhere)
 *
 * Runtime protection that:
 * 1. Overrides Element.innerHTML setter to auto-sanitize
 * 2. Provides a safe rendering API
 * 3. Logs violations for auditing
 *
 * @audit hackercord-audit.md — Finding H4
 * @priority P2 (2 hours)
 */

'use strict';

// ─── HTML Sanitizer ─────────────────────────────────────────────────────────

// Allowed tags and attributes (whitelist approach)
const ALLOWED_TAGS = new Set([
  'a', 'abbr', 'b', 'blockquote', 'br', 'code', 'dd', 'div', 'dl', 'dt',
  'em', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr', 'i', 'img', 'li',
  'ol', 'p', 'pre', 'small', 'span', 'strong', 'sub', 'sup', 'table',
  'tbody', 'td', 'th', 'thead', 'tr', 'u', 'ul', 'details', 'summary',
  'mark', 'del', 'ins', 'kbd', 'samp', 'var', 'time',
]);

const ALLOWED_ATTRS = new Set([
  'href', 'src', 'alt', 'title', 'class', 'id', 'width', 'height',
  'target', 'rel', 'datetime', 'open',
]);

// Attributes that can contain URLs (need protocol validation)
const URL_ATTRS = new Set(['href', 'src']);
const SAFE_PROTOCOLS = new Set(['http:', 'https:', 'mailto:']);

/**
 * Sanitize HTML string, removing dangerous elements and attributes.
 * Uses the DOM parser approach (works in browser).
 */
function sanitizeHTML(dirty) {
  if (typeof dirty !== 'string') return '';
  if (!dirty.includes('<')) return dirty;  // Plain text, no HTML

  // Use DOMParser if available (browser)
  if (typeof DOMParser !== 'undefined') {
    const doc = new DOMParser().parseFromString(dirty, 'text/html');
    sanitizeNode(doc.body);
    return doc.body.innerHTML;
  }

  // Fallback: aggressive escape
  return escapeHTML(dirty);
}

function sanitizeNode(node) {
  const children = [...node.childNodes];
  for (const child of children) {
    if (child.nodeType === 1) { // Element
      const tag = child.tagName.toLowerCase();
      if (!ALLOWED_TAGS.has(tag)) {
        // Remove dangerous elements entirely (script, iframe, object, embed, etc.)
        if (['script', 'iframe', 'object', 'embed', 'form', 'input', 'textarea',
             'select', 'button', 'style', 'link', 'meta', 'base'].includes(tag)) {
          child.remove();
          continue;
        }
        // Unwrap unknown elements (keep their text content)
        while (child.firstChild) {
          child.parentNode.insertBefore(child.firstChild, child);
        }
        child.remove();
        continue;
      }

      // Remove dangerous attributes
      const attrs = [...child.attributes];
      for (const attr of attrs) {
        const name = attr.name.toLowerCase();
        if (!ALLOWED_ATTRS.has(name)) {
          // Block all event handlers (onclick, onload, onerror, etc.)
          if (name.startsWith('on') || name === 'style') {
            child.removeAttribute(attr.name);
            continue;
          }
          child.removeAttribute(attr.name);
          continue;
        }
        // Validate URL attributes
        if (URL_ATTRS.has(name)) {
          try {
            const url = new URL(attr.value, 'https://hackercord.com');
            if (!SAFE_PROTOCOLS.has(url.protocol)) {
              child.removeAttribute(attr.name);
            }
          } catch {
            child.removeAttribute(attr.name);
          }
        }
      }

      // Force external links to be safe
      if (tag === 'a') {
        child.setAttribute('rel', 'noopener noreferrer nofollow');
        child.setAttribute('target', '_blank');
      }

      // Recursively sanitize children
      sanitizeNode(child);
    }
  }
}

function escapeHTML(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// ─── innerHTML Interceptor ──────────────────────────────────────────────────

const violations = [];

/**
 * Monkey-patch innerHTML to auto-sanitize and log violations.
 * Call this early in app initialization.
 */
function installInnerHTMLGuard() {
  if (typeof Element === 'undefined') return;

  const descriptor = Object.getOwnPropertyDescriptor(Element.prototype, 'innerHTML');
  if (!descriptor) return;

  const originalSet = descriptor.set;

  Object.defineProperty(Element.prototype, 'innerHTML', {
    ...descriptor,
    set(value) {
      // Check for dangerous patterns
      if (typeof value === 'string' && containsDangerousHTML(value)) {
        const location = new Error().stack?.split('\n')[2]?.trim() || 'unknown';
        const violation = {
          timestamp: Date.now(),
          location,
          original: value.substring(0, 200),
          element: this.tagName,
        };
        violations.push(violation);

        if (violations.length <= 100) {
          console.warn(
            `[NullSec innerHTML Guard] Dangerous HTML intercepted at ${location}`,
            '\nOriginal:', value.substring(0, 100) + '...',
          );
        }

        // Sanitize before setting
        value = sanitizeHTML(value);
      }
      return originalSet.call(this, value);
    },
  });

  console.log('[NullSec] innerHTML guard installed — auto-sanitizing user content');
}

function containsDangerousHTML(html) {
  if (!html) return false;
  return /<script/i.test(html)
    || /on\w+\s*=/i.test(html)     // onclick=, onerror=, onload=, etc.
    || /javascript:/i.test(html)
    || /<iframe/i.test(html)
    || /<object/i.test(html)
    || /<embed/i.test(html)
    || /<form/i.test(html)
    || /data:text\/html/i.test(html)
    || /<svg.*on/i.test(html)       // SVG event handlers
    || /<math/i.test(html);         // MathML injection
}

/**
 * Get collected violations for auditing.
 */
function getViolations() {
  return [...violations];
}

// ─── Safe Render API ────────────────────────────────────────────────────────

/**
 * Safely render user content into an element.
 * This is the recommended replacement for innerHTML with user data.
 *
 * Usage:
 *   // Instead of: element.innerHTML = userMessage;
 *   NullSec.safeRender(element, userMessage);
 */
function safeRender(element, html) {
  if (!element) return;
  element.innerHTML = sanitizeHTML(html);
}

/**
 * Create element from template with safe interpolation.
 *
 * Usage:
 *   const el = NullSec.safeTemplate(
 *     '<div class="msg"><b>{username}</b>: {content}</div>',
 *     { username: user.name, content: message.text }
 *   );
 */
function safeTemplate(template, data) {
  let result = template;
  for (const [key, value] of Object.entries(data)) {
    const escaped = escapeHTML(String(value));
    result = result.replace(new RegExp(`\\{${key}\\}`, 'g'), escaped);
  }
  return result;
}

// ─── Export ─────────────────────────────────────────────────────────────────

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    sanitizeHTML,
    escapeHTML,
    installInnerHTMLGuard,
    getViolations,
    safeRender,
    safeTemplate,
  };
} else {
  window.NullSecSanitizer = {
    sanitizeHTML,
    escapeHTML,
    installInnerHTMLGuard,
    getViolations,
    safeRender,
    safeTemplate,
  };
  // Auto-install guard
  installInnerHTMLGuard();
}
