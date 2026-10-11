/**
 * The fallback card: a small self-contained page the model writes when none
 * of the native cards fit (a timeline, a matrix, a custom diagram).
 *
 * The page is untrusted, so it is made inert before it leaves the server:
 *   - Anything that can load or send something is stripped: external
 *     scripts, frames, objects, forms, links, base tags, meta refreshes, and
 *     any src/href/action pointing at a URL. Event handlers stay, since a
 *     button toggling a view is the point; they can't reach anything.
 *   - A Content-Security-Policy forbidding every network request is put
 *     first in <head>, so even something that slips past the stripping
 *     can't fetch or leak.
 *   - The app shows it in a sandbox (an iframe without same-origin on web, a
 *     WebView that blocks all navigation on Android), with no bridge back.
 */
export const HTML_MAX_BYTES = 30_000;
const MIN_HEIGHT = 120;
const MAX_HEIGHT = 640;

const CSP =
  "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:; " +
  "connect-src 'none'; form-action 'none'; frame-src 'none'; base-uri 'none'";

export interface HtmlCardDto {
  type: 'html';
  title: string;
  html: string;
  height: number;
}

/** Null when there's nothing safe and useful left to show. */
export function sanitizeHtmlCard(raw: { title?: unknown; html?: unknown; height?: unknown }): HtmlCardDto | null {
  if (typeof raw.html !== 'string') return null;
  let html = raw.html;
  if (Buffer.byteLength(html, 'utf8') > HTML_MAX_BYTES) return null;

  html = html
    // Elements that load, embed or navigate.
    // Opening and closing tags go separately; anything between is left as text.
    .replace(/<\s*\/?\s*(iframe|frame|frameset|object|embed|applet|form|base|link|portal)\b[^>]*>/gi, '')
    .replace(/<\s*meta\b[^>]*http-equiv[^>]*>/gi, '')
    .replace(/<\s*script\b[^>]*\bsrc\s*=[^>]*>[\s\S]*?<\/\s*script\s*>/gi, '')
    // Attributes that point anywhere: src/href/action/formaction/poster/srcset/xlink:href.
    .replace(
      /\s(src|href|action|formaction|poster|srcset|xlink:href|background|ping)\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi,
      (match, _attr: string, value: string) => (/^["']?\s*data:image\//i.test(value) ? match : ''),
    )
    // CSS that fetches.
    .replace(/url\(\s*(['"]?)(?!data:)[^)]*\1\s*\)/gi, 'none')
    .replace(/@import[^;]+;/gi, '');

  if (!/<[a-z]/i.test(html)) return null;

  const head = `<meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="${CSP}">` +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<style>html,body{margin:0;background:transparent;color:#EDF2EC;font-family:system-ui,sans-serif;font-size:14px}</style>';
  const document = /<head[^>]*>/i.test(html)
    ? html.replace(/<head[^>]*>/i, (tag) => `${tag}${head}`)
    : `<!doctype html><html><head>${head}</head><body>${html}</body></html>`;

  const requested = typeof raw.height === 'number' ? raw.height : 320;
  return {
    type: 'html',
    title: typeof raw.title === 'string' && raw.title.trim() ? raw.title.trim().slice(0, 60) : 'Custom view',
    html: document,
    height: Math.min(MAX_HEIGHT, Math.max(MIN_HEIGHT, Math.round(requested))),
  };
}
