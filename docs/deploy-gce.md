# Deploying the backend to GCP Compute Engine

Runbook for putting the NestJS backend on a single `e2-micro` VM with Caddy in
front for automatic HTTPS. Postgres lives off-box (Neon), so the VM only runs
Node and Caddy.

Why a VM rather than Cloud Run: the price tick and gameweek processing run as
in-process timers ([`price-tick.service.ts`](../backend/src/scoring/price-tick.service.ts)).
They need a process that is always alive with CPU. A VM gives that by default;
Cloud Run needs `--min-instances=1 --no-cpu-throttling` and fails silently
without both.

---

## 0. Before you start: fix these secrets

Do not deploy the current `backend/.env` as-is.

| Variable | Problem | Action |
|---|---|---|
| `AUTH_SECRET` | The current value is a rearrangement of the `JUPITER_FEE_ACCOUNT` address, which is public on-chain in every swap. It is guessable, and it signs every bearer token. | Replace with 32+ random bytes: `openssl rand -base64 48` |
| `ADMIN_KEY` | `dev-admin-key`. `/admin/*` can force gameweek advances and duel settlements. | Replace with `openssl rand -hex 32` |
| `SOLANA_RPC_URL` | Public `api.mainnet-beta.solana.com` rate-limits, and every tick reads balances per user. | Use a Helius (or similar) key |
| `PRICE_TICK_MINUTES` | `60` means the leaderboard only moves hourly. | `5` for a lively board without hammering the RPC |

`JUPITER_FEE_ACCOUNT` must be a **USDC token account** you control, not a wallet
address — Jupiter rejects the swap otherwise, and that is where your revenue
comes from. Verify it before demoing.

---

## 1. Project, region, static IP

Pick one of `us-west1`, `us-central1` or `us-east1` — `e2-micro` is in the GCP
free tier only in those regions.

```bash
gcloud config set project <PROJECT_ID>
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

gcloud compute addresses create formation-api --region us-central1
gcloud compute addresses describe formation-api --region us-central1 --format='value(address)'
```

Reserve the address **before** creating the VM. An ephemeral IP changes on every
stop/start, and the app compiles `API_URL` in at build time, so a changed
address means rebuilding the APK.

## 2. Create the VM

```bash
gcloud compute instances create formation-api \
  --machine-type=e2-micro \
  --image-family=debian-12 --image-project=debian-cloud \
  --boot-disk-size=30GB --boot-disk-type=pd-standard \
  --address=$(gcloud compute addresses describe formation-api --region us-central1 --format='value(address)') \
  --tags=http-server,https-server
```

30GB `pd-standard` is the free-tier disk ceiling.

## 3. Firewall

Open only 80 and 443. Caddy terminates TLS and proxies to Node on localhost, so
port 3000 must never be reachable from the internet — it has no auth in front of
`/admin/*` other than the header.

```bash
gcloud compute firewall-rules create allow-http-https \
  --allow=tcp:80,tcp:443 --target-tags=http-server,https-server
```

## 4. DNS

Point an A record at the static IP and let it propagate before installing Caddy —
certificate issuance fails if the name doesn't resolve yet.

```
api.formation.app.   A   <STATIC_IP>
```

## 5. Base setup on the VM

```bash
gcloud compute ssh formation-api
```

```bash
# Swap: e2-micro has 1GB RAM and `npm ci` can OOM without it.
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Node 24 — match your local major version; the backend is ESM.
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs

sudo mkdir -p /opt/formation && sudo chown $USER:$USER /opt/formation
```

## 6. Deploy the build

Build on your machine, ship `dist/` plus the manifests, and install runtime
dependencies **on the VM**.

> Do not copy `node_modules` from Windows. Several dependencies resolve
> platform-specific binaries; installing on the box avoids silent runtime
> failures.

```bash
# local
cd backend
npm run build
tar czf deploy.tgz dist package.json package-lock.json migrations
gcloud compute scp deploy.tgz formation-api:/opt/formation/
```

```bash
# on the VM
cd /opt/formation
tar xzf deploy.tgz && rm deploy.tgz
npm ci --omit=dev
```

## 7. Environment file

```bash
nano /opt/formation/.env
```

Paste your `.env` with the secrets from §0 replaced. Then lock it down:

```bash
chmod 600 /opt/formation/.env
```

`main.ts` calls `process.loadEnvFile()`, which reads `.env` **relative to the
working directory** — so the systemd unit below must set `WorkingDirectory`, or
the app will start with no configuration and fail to reach the database.

## 8. Run migrations

The substitutions/transfers work added `002_substitutions.sql`, so this is
required, not optional:

```bash
cd /opt/formation && node dist/scripts/migrate.js
```

It records applied files in `schema_migrations` and is safe to re-run.

## 9. systemd service

```bash
sudo nano /etc/systemd/system/formation.service
```

```ini
[Unit]
Description=Formation API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=formation
WorkingDirectory=/opt/formation
ExecStart=/usr/bin/node dist/main.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
sudo useradd --system --no-create-home formation
sudo chown -R formation:formation /opt/formation
sudo systemctl daemon-reload
sudo systemctl enable --now formation
sudo systemctl status formation
```

Logs: `sudo journalctl -u formation -f`

## 10. Caddy

```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update && sudo apt-get install -y caddy
```

```bash
sudo nano /etc/caddy/Caddyfile
```

```caddyfile
api.formation.app {
	reverse_proxy localhost:3000
	encode gzip

	log {
		output file /var/log/caddy/formation.log
		format json
	}
}
```

```bash
sudo systemctl reload caddy
```

Caddy obtains and renews the Let's Encrypt certificate automatically. Nothing
else to configure.

## 11. Smoke test

```bash
curl https://api.formation.app/xstocks | head -c 200          # live prices
curl https://api.formation.app/league/football | head -c 200  # seeded ladder
curl "https://api.formation.app/league/football?period=weekly" | head -c 200

# Crons: force one tick, then confirm a gameweek row exists.
curl -X POST https://api.formation.app/admin/tick -H "x-admin-key: <ADMIN_KEY>"
```

If `/admin/tick` works but the board never moves on its own, the timer isn't
running — check `journalctl -u formation` for `Price tick failed`.

## 12. Point the app at it

```bash
cd app
flutter build apk --release \
  --dart-define=API_URL=https://api.formation.app \
  --dart-define=ADMIN_KEY=<ADMIN_KEY>
```

Release builds enforce HTTPS-only (the cleartext exemption is debug-only, see
`android/app/src/debug/AndroidManifest.xml`), which is exactly why Caddy is here.

## Redeploying

```bash
# local
cd backend && npm run build
tar czf deploy.tgz dist package.json package-lock.json migrations
gcloud compute scp deploy.tgz formation-api:/tmp/

# on the VM
cd /opt/formation && sudo tar xzf /tmp/deploy.tgz
sudo chown -R formation:formation /opt/formation
npm ci --omit=dev && node dist/scripts/migrate.js
sudo systemctl restart formation
```
