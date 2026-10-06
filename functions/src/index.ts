import { onRequest } from 'firebase-functions/v2/https';
import { defineString } from 'firebase-functions/params';

/**
 * Serves the Flutter app shell with per-page Open Graph tags.
 *
 * A link crawler does not run Flutter, so everything it reads has to already
 * be in the HTML. Firebase Hosting rewrites `/managers/**` and `/leagues/**`
 * here (see firebase.json); this fetches the published `index.html`, asks the
 * API for that page's title and description, swaps the four fallback tags, and
 * serves the result. The player gets the identical app either way — only the
 * tags in the head differ.
 */

const APP_ORIGIN = defineString('APP_ORIGIN', {
  default: 'https://app.formation.titalabs.xyz',
  description: 'Origin serving the built Flutter web app.',
});

const API_ORIGIN = defineString('API_ORIGIN', {
  default: 'https://api.formation.titalabs.xyz',
  description: 'Origin of the NestJS API that serves /og/* previews.',
});

interface Preview {
  title: string;
  description: string;
}

/** The app shell, cached between invocations so a warm instance skips the fetch. */
let shell: { html: string; fetchedAt: number } | null = null;
const SHELL_TTL_MS = 10 * 60_000;
const UPSTREAM_TIMEOUT_MS = 3_000;

async function appShell(): Promise<string> {
  const now = Date.now();
  if (shell && now - shell.fetchedAt < SHELL_TTL_MS) return shell.html;

  // `/index.html` is a real file in the deployed site, and Hosting only
  // applies rewrites when nothing static matches — so this cannot recurse
  // back into this function.
  const response = await fetchWithTimeout(`${APP_ORIGIN.value()}/index.html`);
  if (!response.ok) throw new Error(`App shell returned ${response.status}`);

  const html = await response.text();
  shell = { html, fetchedAt: now };
  return html;
}

/**
 * Asks the API for a page's preview, or null if it cannot say.
 *
 * A deleted league, a cold database or a slow network all land here, and all
 * mean the same thing: serve the app with its generic tags rather than an
 * error page. The link still works; it just unfurls as "Formation".
 */
async function preview(path: string): Promise<Preview | null> {
  const match = /^\/(managers|leagues)\/([^/?#]+)/.exec(path);
  if (!match) return null;

  const [, kind, rawId] = match;
  // Only the shapes the API issues: ids are UUIDs, so anything else is a probe.
  if (!/^[0-9a-zA-Z_-]{1,64}$/.test(rawId)) return null;

  try {
    const url = `${API_ORIGIN.value()}/og/${kind}/${encodeURIComponent(rawId)}`;
    const response = await fetchWithTimeout(url);
    if (!response.ok) return null;

    const body = (await response.json()) as Partial<Preview>;
    if (typeof body.title !== 'string' || typeof body.description !== 'string') {
      return null;
    }
    return { title: body.title, description: body.description };
  } catch {
    return null;
  }
}

function fetchWithTimeout(url: string): Promise<Response> {
  return fetch(url, { signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS) });
}

/** Escapes a value for an HTML attribute. */
function attr(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Replaces the content of one meta tag, matched on its `property` or `name`.
 *
 * Rewriting the existing tags rather than appending new ones matters: a
 * crawler that sees two `og:title` tags is free to pick either, and several
 * pick the first.
 */
function setMeta(html: string, key: string, value: string): string {
  const pattern = new RegExp(
    `(<meta\\s+(?:property|name)=["']${key}["']\\s+content=["'])[^"']*(["']\\s*/?>)`,
    'i',
  );
  return html.replace(pattern, `$1${attr(value)}$2`);
}

export const ogRender = onRequest(
  { region: 'us-central1', memory: '256MiB', maxInstances: 10, invoker: 'public' },
  async (request, response) => {
    let html: string;
    try {
      html = await appShell();
    } catch (error) {
      // Without the shell there is nothing to serve at all. A redirect sends
      // the visitor to a working app, losing only the rich preview.
      console.error('Could not fetch the app shell', error);
      response.redirect(302, `${APP_ORIGIN.value()}/index.html`);
      return;
    }

    const page = await preview(request.path);
    if (page) {
      for (const key of ['og:title', 'twitter:title']) {
        html = setMeta(html, key, page.title);
      }
      for (const key of ['og:description', 'twitter:description', 'description']) {
        html = setMeta(html, key, page.description);
      }
      html = setMeta(html, 'og:url', `${APP_ORIGIN.value()}${request.path}`);
    }

    response
      .status(200)
      .set('content-type', 'text/html; charset=utf-8')
      // Short, because a rank changes every tick. Long enough that a link
      // shared into a busy channel is rendered once, not once per client.
      .set('cache-control', 'public, max-age=120, s-maxage=300')
      .send(html);
  },
);
