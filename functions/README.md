# Share previews — written, not wired up

`ogRender` serves the Flutter app shell with per-page Open Graph tags, so a
link to `/managers/<id>` unfurls with that player's name and rank instead of
the generic site card.

**It is deliberately not deployed.** Nothing references it: there is no
`functions` block in `firebase.json`, no rewrite pointing at it, and
`scripts/deploy-web.ps1` does not build or deploy it. Cloud Functions require
the Blaze plan, and the web app does not need them to work — every shared link
resolves correctly today and unfurls using the fallback `og:*` tags in
`app/web/index.html`.

The code is kept because the problem it solves is real and the solution is
already tested: the regex that rewrites the head was verified against a real
`flutter build web` output.

## Why a function at all

A crawler fetches the URL and parses the HTML. It never runs Flutter, so
anything it should read has to be in the document as served — and it has to
differ per URL, which one static `index.html` cannot do. Something server-side
must rewrite the head.

Firebase Hosting's `rewrites` can only target a path in the same site, a Cloud
Function, or a Cloud Run service. There is no proxy-to-origin option, so
Hosting cannot hand `/managers/**` to the API on the GCE VM. A function was the
cheapest thing Hosting can actually route to.

## Picking this up later

Two routes, and the second is probably better:

**1. Deploy this function.** Needs Blaze on `formation-cbf24`. Restore to
`firebase.json`:

```json
"rewrites": [
  { "source": "/managers/**", "function": "ogRender" },
  { "source": "/leagues/**",  "function": "ogRender" },
  { "source": "**", "destination": "/index.html" }
]
```

```json
"functions": [
  { "source": "functions", "codebase": "default",
    "ignore": ["node_modules", ".git", "*.local"] }
]
```

Then deploy `--only hosting:app,functions:ogRender`. Order matters: deploying
hosting with those rewrites while the function does not exist breaks those
paths outright, which is worse than a generic preview.

**2. Serve the previews from the VM instead.** The link handed to people does
not have to be the app's URL. A route on the API — say
`go.formation.titalabs.xyz/managers/<id>` — can return a small HTML document
with the right tags and redirect a real browser on to
`app.formation.titalabs.xyz/managers/<id>`. No Blaze, no function, and it sits
next to the data it reads: `GET /og/managers/:id` in `backend/src/og/` already
returns exactly the title and description such a page needs, and is already
unauthenticated and rate-limited for this purpose.

The cost is a less pretty share URL and one redirect hop.

## Running it locally, if you do revisit it

```bash
npm install
npm run build
npm run serve     # firebase emulators:start --only functions
```

It reads two params, both defaulted: `APP_ORIGIN` (where the built app is
served) and `API_ORIGIN` (the NestJS API).
