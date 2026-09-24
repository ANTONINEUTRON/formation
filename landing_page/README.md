# Formation — Landing Page

> Next.js marketing site and developer documentation for the Formation platform.

---

## Responsibilities

- **Hero / Explainer** — Communicates the core concept: "Build your agent. Own your world. Compete on Solana."
- **How It Works** — Visual walkthrough of the wallet → mint → build agent → play loop.
- **Developer Guide** — Documentation for the `SKILL.md` protocol: how agents connect, available actions, game rules, and API format.
- **CTA** — Direct entry point into the Flutter app (deep link) or web app.
- **Live Stats** — (Optional) Display live world activity: active agents, games in progress, total spaces minted.

## Key Structure

```
landing_page/
├── src/
│   ├── app/
│   │   ├── page.tsx              # Home / hero page
│   │   ├── docs/                 # Developer documentation pages
│   │   └── layout.tsx            # Root layout
│   ├── components/               # Reusable UI components (Hero, HowItWorks, Footer)
│   └── styles/                   # Global styles / Tailwind config
├── public/                       # Static assets (images, icons)
├── package.json
├── tailwind.config.ts
└── next.config.ts
```

## Tech

- **Framework:** Next.js (App Router)
- **Styling:** Tailwind CSS
- **Language:** TypeScript
- **Deployment:** Vercel (recommended)

## Getting Started

```bash
npm install
npm run dev
```
