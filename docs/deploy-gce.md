# Deploying the backend to GCP Compute Engine

Runbook for running the NestJS backend on a single `e2-micro` VM: source pulled
from GitHub, built on the box, kept alive by PM2, with Caddy in front for
automatic HTTPS. Postgres lives off-box (Neon), so the VM only runs Node and
Caddy.

Why a VM rather than Cloud Run: the price tick runs as an in-process timer
([`price-tick.service.ts`](../backend/src/scoring/price-tick.service.ts)) and
banks points every time it fires. It needs a process that is always alive with
CPU. A VM gives that by default; Cloud Run needs `--min-instances=1
--no-cpu-throttling` and fails silently without both.

---

## ⚠️ The one that will quietly corrupt your data

**PM2 must run exactly one instance.** The scoring loop is a timer inside the
process, not a job queue. Start two instances and every tick fires twice, so
every player banks their points twice and the leaderboard is wrong in a way
nothing will alert you to.

Never `pm2 start -i 2`, never `-i max`, never cluster mode. Fork mode, one
instance. §9 does this correctly — just don't "optimise" it later.

---

## 0. Before you start

**Push the repo to GitHub.** It has no remote yet (`git remote -v` is empty), so
there is nothing to clone. Create the public repo and push `master`.

Before you push, confirm the environment file is still ignored — it holds your
database URL and your token-signing secret:

```bash
git check-ignore backend/.env      # must print the path
```

If that prints nothing, stop and fix it before pushing anywhere public.

**Fix these values.** You will type them into the server's `.env` in §7, not
copy the local file up.

| Variable | Why it matters |
|---|---|
| `AUTH_SECRET` | Signs every bearer token. 32+ random bytes, never derived from anything public: `node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"` |
| `ADMIN_KEY` | `/admin/*` can force ticks and settle leagues: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` |
| `SOLANA_RPC_URL` | The public endpoint rate-limits, and every tick reads balances per player. Use a Helius key. |
| `JUPITER_FEE_ACCOUNT` | Must be a USDC **token account** you control, not a wallet address. Empty means fees are off — your revenue silently disabled. |
| `PRICE_TICK_MINUTES` | The heartbeat: prices recorded *and* points banked on it. `5` keeps the board alive; `60` makes it look frozen. |

`backend/.env.example` is the current list. `TEST_DATABASE_URL` is for the test
suites only and does not belong on the server.

---

Everything up to §5 is done in the GCP Console in a browser. From §5 onward you
are on the VM over SSH, and every block is something you paste into that shell.

## 1. Enable Compute Engine

The API is off by default on a new project — this is the error you get if you
skip it.

> **Console → APIs & Services → Library**
> Search **Compute Engine API** → **Enable**

It takes a couple of minutes to propagate. Make sure the project picker at the
top of the console is on the project you intend to use before you click.

## 2. Create the VM

> **Console → Compute Engine → VM instances → Create instance**

| Field | Value |
|---|---|
| Name | `formation-api` |
| Region / Zone | `us-central1` / `us-central1-a` |
| Machine configuration | Series **E2**, machine type **e2-micro** |
| Boot disk → Change | **Debian GNU/Linux 12 (bookworm)**, size **30 GB**, type **Balanced** → change to **Standard persistent disk** |
| Firewall | tick **Allow HTTP traffic** and **Allow HTTPS traffic** |

Then **Create**.

Two things that decide whether this is free: `e2-micro` is only in the free tier
in `us-west1`, `us-central1` and `us-east1`, and the free disk allowance is
**30 GB of standard** persistent disk. The console defaults the disk to Balanced,
which is not covered — change it.

Ticking the two firewall boxes creates the `http-server` / `https-server` rules
and tags for you, so there is no separate firewall step. Port 3000 stays closed
to the internet, which is what you want: Caddy reaches Node over localhost, and
the only thing guarding `/admin/*` is a header.

## 3. Make the IP static

The VM is created with an ephemeral address that changes on every stop/start.
The app compiles `API_URL` in at build time, so a changed address means
rebuilding the APK — pin it now.

> **Console → VPC network → IP addresses → External IP addresses**
> Find the row for `formation-api` → set **Type** from *Ephemeral* to **Static**
> → give it a name → **Reserve**

Copy the address; you need it in the next step.

## 4. DNS

At your domain registrar, point a subdomain at that address:

```
api.<your-domain>.   A   <STATIC_IP>
```

**Wait for it to resolve before you install Caddy in §10.** Certificate issuance
fails if the name doesn't resolve yet, and a failed attempt can rate-limit you.
Check from your own machine:

```bash
nslookup api.<your-domain>
```

## 5. Base setup on the VM

> **Console → Compute Engine → VM instances → SSH**

That button opens a browser terminal on the box. Everything from here down is
pasted into it.

```bash
# Swap first. e2-micro has 1GB of RAM and you are about to run a TypeScript
# build on it — see the note in §6.
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h                      # confirm swap is listed

# Node 24 — the backend is ESM and expects a modern runtime.
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs git
node -v                      # expect v24.x

sudo npm install -g pm2
```

## 6. Clone and build

```bash
sudo mkdir -p /opt/formation && sudo chown $USER:$USER /opt/formation
git clone https://github.com/<you>/<repo>.git /opt/formation
cd /opt/formation/backend

# Dev dependencies are required here: `nest build` is one of them.
npm ci
npm run build
```

> **On 1GB of RAM this is the step that fails.** `nest build` is a TypeScript
> compile and will lean hard on swap. If it gets killed, give the compiler a
> ceiling so it collects rather than ballooning:
>
> ```bash
> NODE_OPTIONS=--max-old-space-size=768 npm run build
> ```
>
> If it still dies, build once on your own machine and `scp -r dist` up to
> `/opt/formation/backend/`. Nothing else in this runbook changes.

Once `dist/` exists you can reclaim the build-only packages:

```bash
npm prune --omit=dev
```

Do that **after** a successful build, never before — and note that `npm ci` on
the next deploy puts them back.

## 7. The environment file

```bash
nano /opt/formation/backend/.env
```

Type in the values from §0. `main.ts` calls `process.loadEnvFile()`, which reads
`.env` **relative to the working directory** — which is exactly why §9 pins
PM2's `cwd`. Get that wrong and the app starts with no configuration and cannot
reach the database.

```bash
chmod 600 /opt/formation/backend/.env
```

## 8. Run migrations

Seven migrations exist, and only `001_init.sql` has ever been applied to the
production database. Continuous scoring, leagues, notifications, follows and
profiles all live in `002`–`007`, so this is required, not optional.

```bash
cd /opt/formation/backend && node dist/scripts/migrate.js
```

It records what it applied in `schema_migrations` and is safe to re-run.

## 9. PM2

Use an ecosystem file rather than a long command line: it pins the working
directory and the instance count, and it is what `pm2 save` writes down.

```bash
nano /opt/formation/backend/ecosystem.config.cjs
```

```js
// .cjs because the backend is an ESM package and PM2 reads this with require().
module.exports = {
  apps: [
    {
      name: 'formation',
      script: 'dist/main.js',
      cwd: '/opt/formation/backend',   // process.loadEnvFile() depends on this
      instances: 1,                    // see the warning at the top of this file
      exec_mode: 'fork',
      autorestart: true,
      max_memory_restart: '400M',
      env: { NODE_ENV: 'production' },
    },
  ],
};
```

```bash
cd /opt/formation/backend
pm2 start ecosystem.config.cjs
pm2 save                     # remember this process list across reboots
pm2 startup                  # prints a sudo command — run exactly what it prints
```

`pm2 startup` does not install anything itself; it echoes a command you must run
with sudo. Skip that and the app will not come back after a reboot.

Day to day:

```bash
pm2 status
pm2 logs formation --lines 100
pm2 monit
```

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
api.<your-domain> {
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
sudo journalctl -u caddy -f      # watch the certificate being issued
```

Caddy obtains and renews the Let's Encrypt certificate itself. Nothing else to
configure, no cron to add.

## 11. Smoke test

```bash
curl https://api.<your-domain>/xstocks | head -c 200          # live prices
curl https://api.<your-domain>/league/football | head -c 200  # the ladder
curl "https://api.<your-domain>/league/football?period=weekly" | head -c 200

# Force one tick, then confirm points were banked.
curl -X POST https://api.<your-domain>/admin/tick \
  -H "x-admin-key: <ADMIN_KEY>"
```

Then check the timer runs on its own: wait `PRICE_TICK_MINUTES`, hit
`/league/football` again, and see whether the numbers moved. If `/admin/tick`
works but nothing changes unprompted, the interval isn't firing — look in
`pm2 logs formation` for `Price tick failed`.

## 12. Point the app at it

```bash
cd app
flutter build apk --release \
  --dart-define=API_URL=https://api.<your-domain> \
  --dart-define=ADMIN_KEY=<ADMIN_KEY>
```

Release builds enforce HTTPS-only — the cleartext exemption in
`android/app/src/debug/AndroidManifest.xml` applies to debug builds only, which
is exactly why Caddy is here.

---

## Redeploying

```bash
cd /opt/formation
git pull
cd backend
npm ci                     # restores the dev dependencies you pruned
npm run build
node dist/scripts/migrate.js
npm prune --omit=dev
pm2 reload formation       # waits for the new process before retiring the old
pm2 logs formation --lines 50
```

`pm2 reload` rather than `restart`: reload brings the replacement up first, so
there is no window where the API is down.

## When something breaks

| Symptom | Where to look |
|---|---|
| 502 from Caddy | Node is down. `pm2 status`, then `pm2 logs formation`. |
| Starts then exits immediately | Almost always `.env` — wrong `cwd`, or `DATABASE_URL` unreachable from the VM. |
| Certificate never issues | DNS. `dig +short api.<your-domain>` must return your static IP, and 80/443 must be open. |
| Points banked twice | More than one PM2 instance. `pm2 status` must show exactly one. |
| Board frozen, `/admin/tick` works | The interval isn't running. Check the logs for `Price tick failed`, and whether the RPC is rate-limiting. |
| Build killed on the VM | Out of memory. Confirm swap with `free -h`, then use the `NODE_OPTIONS` ceiling in §6. |
