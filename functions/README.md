# Share previews

`ogRender` serves the Flutter app shell with per-page Open Graph tags, so a
link to `/managers/<id>` unfurls with that player's name and rank (and a
`/leagues/<id>` link with that league's) instead of the generic site card.

**It is wired up.** `firebase.json` rewrites `/managers/**` and `/leagues/**` on
the `app` hosting target to this function, and `scripts/deploy-web.ps1`
compiles it and deploys it together with hosting
(`--only hosting:app,functions:ogRender`). Cloud Functions need the **Blaze
plan** on `formation-cbf24`.

Deploy the two together. Hosting with those rewrites in place while the
function doesn't exist breaks `/managers/**` and `/leagues/**` outright, which
is worse than a generic preview. If Blaze isn't available, take the two
rewrites and the `functions` block back out of `firebase.json` and the
function's steps out of the deploy script; links then unfurl with the fallback
`og:*` tags in `app/web/index.html`.

## Why a function at all

A crawler fetches the URL and parses the HTML. It never runs Flutter, so
anything it should read has to be in the document as served — and it has to
differ per URL, which one static `index.html` cannot do. Something server-side
must rewrite the head.

Firebase Hosting's `rewrites` can only target a path in the same site, a Cloud
Function, or a Cloud Run service. There is no proxy-to-origin option, so
Hosting cannot hand `/managers/**` to the API on the GCE VM. A function was the
cheapest thing Hosting can actually route to.

The function reads the title and description from the API's public
`GET /og/managers/:id` and `GET /og/leagues/:id` (`backend/src/og/`), which are
unauthenticated and rate-limited for this purpose. The regex that rewrites the
head was verified against a real `flutter build web` output.

## Without Blaze

The link handed to people doesn't have to be the app's URL. A route on the
API — say `go.formation.titalabs.xyz/managers/<id>` — can return a small HTML
document with the right tags and redirect a real browser on to
`app.formation.titalabs.xyz/managers/<id>`. No function needed, at the cost of
a less pretty share URL and one redirect hop.

## Running it locally

```bash
npm install
npm run build
npm run serve     # firebase emulators:start --only functions
```

It reads two params, both defaulted: `APP_ORIGIN` (where the built app is
served) and `API_ORIGIN` (the NestJS API).
