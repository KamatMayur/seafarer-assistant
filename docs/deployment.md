# Deployment runbook (tester server)

Target: one Ubuntu 24.04 server running `infra/docker-compose.yml` (Postgres, migrations, API, worker, Caddy with
automatic HTTPS). Status: **written, not yet executed** – the compose stack has never been built. Expect to fix
small things on the first run and update this file.

## 0. Before you start
- Server: 2 vCPU / 4 GB, Ubuntu 24.04 (see `docs/hosting-options.md`).
- DNS: an `A` record `api.<domain>` → server IP (Caddy needs it to issue the certificate).
- Email: SMTP host/port/user/key and a verified sender address (Brevo).
- Decide: operator name and privacy contact email for the privacy notice.

## 1. Server basics (as root, once)
```bash
apt update && apt -y upgrade
adduser --disabled-password --gecos "" deploy && usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh && cp ~/.ssh/authorized_keys /home/deploy/.ssh/ && chown -R deploy:deploy /home/deploy/.ssh
ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp && ufw --force enable
apt -y install ca-certificates curl git gnupg unattended-upgrades
curl -fsSL https://get.docker.com | sh && usermod -aG docker deploy
timedatectl set-timezone Asia/Kolkata
```
**Oracle Cloud (free option):** the default user is `ubuntu` (use it instead of creating `deploy`), and ports 80/443
must also be opened in the subnet's VCN security list and in iptables – see `docs/hosting-options.md`.

Then log in as `deploy`. (Disable password SSH login once key login works.)

## 2. Code and settings
```bash
sudo mkdir -p /srv && sudo chown deploy /srv && cd /srv
git clone https://github.com/KamatMayur/seafarer-assistant.git && cd seafarer-assistant
cp infra/.env.prod.example infra/.env.prod && chmod 600 infra/.env.prod
python3 -c "import secrets;print(secrets.token_urlsafe(48))"   # run 3x: POSTGRES_PASSWORD, SA_JWT_SECRET, SA_ADMIN_TOKEN
nano infra/.env.prod
```
Fill in: `SA_DOMAIN=api.<domain>`, the three secrets, `SA_SCRAPER_CONTACT`, all `SA_SMTP_*`
(`SA_SMTP_FROM` = the verified sender), `SA_ADMIN_ALERT_EMAIL`, `SA_OPERATOR_NAME`, `SA_PRIVACY_CONTACT`,
`SA_HOSTING_DESCRIPTION`.

## 3. Start
```bash
docker compose -f infra/docker-compose.yml --env-file infra/.env.prod up -d --build
docker compose -f infra/docker-compose.yml ps          # db healthy, migrate exited 0, api healthy, worker + caddy up
curl -s https://api.<domain>/healthz                     # {"status":"ok"}
curl -s https://api.<domain>/readyz                      # {"status":"ready"}
```
Open `https://api.<domain>/privacy` and check the operator and contact are filled in.

## 4. Admin account and real data
```bash
C="docker compose -f infra/docker-compose.yml"
$C exec api python -m sa_backend.admin.manage create you@<domain> --role owner   # scan the TOTP secret into an authenticator
$C exec worker sa-scraper scrape
$C exec worker sa-scraper process --limit 500 --since $(date -d '6 months ago' +%F)   # ~30–40 min
$C exec worker sa-scraper status
```
Log in at `https://api.<domain>/admin`. Once your account exists, the shared `SA_ADMIN_TOKEN` stops working.

## 5. Backups (nightly, encrypted, 14 days)
```bash
sudo sh -c 'python3 -c "import secrets;print(secrets.token_urlsafe(32))" > /root/.sa-backup-pass && chmod 600 /root/.sa-backup-pass'
sudo crontab -e
# 15 2 * * *  cd /srv/seafarer-assistant && BACKUP_PASSPHRASE_FILE=/root/.sa-backup-pass infra/backup.sh
```
Store the passphrase somewhere safe **off the server** (a password manager). Test a restore once (command in
`infra/backup.sh`). Also enable the provider's weekly droplet snapshots if cheap.

## 6. Check before inviting testers
- [ ] Sign up from the app with a real email: code arrives, profile saves, feed fills with matching circulars.
- [ ] `/admin`: sources all "ok", no unexpected admin events, review queue looks sane.
- [ ] Report a problem from the app → appears under Admin → Feedback.
- [ ] Stop the worker for a moment (`$C stop worker`), start again: no duplicate alerts.
- [ ] Reboot the server: everything comes back by itself.
- [ ] Build the installer: `cd app; .\build_tester.ps1 -ApiBase https://api.<domain> -Version 0.2.0`.

## Updating later
```bash
cd /srv/seafarer-assistant && git pull
docker compose -f infra/docker-compose.yml --env-file infra/.env.prod up -d --build   # runs migrations first
```

## Logs
`docker compose -f infra/docker-compose.yml logs -f api` (or `worker`, `caddy`). Unexpected API errors and scraper
failures also appear on the admin dashboard and, if configured, by email.
