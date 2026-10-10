# Hosting for the tester phase – options and recommendation

Prices checked on 10-Oct-2026 from public pricing pages and price trackers (sources at the end). They change;
confirm on the provider's page before paying. All are monthly, excluding GST unless stated.

## What the server has to run
Postgres, the API, the scraper worker and Caddy (HTTPS) – `infra/docker-compose.yml`. Load for 5–50 testers is
tiny; **2 vCPU / 4 GB RAM / ~80 GB disk** is comfortable (and leaves room for the Phase 3 translation model).

## A. Server (pick one)
| Option | Location | 2 vCPU / 4 GB price | Notes |
|---|---|---|---|
| **DigitalOcean Basic Droplet** | **Bangalore** | ~**$24 / month** | Simple dashboard, 4 TB transfer included. Data stays in India. |
| AWS Lightsail | Mumbai | ~$24 / month (IPv4) | Same price; transfer allowance in Mumbai is reported as half the listed amount. More complex account. |
| Hetzner Cloud CX23 | Germany / Finland only | ~€5.49 / month + IPv4 (~€6) | About a quarter of the price. Data in the EU, not India; ~150 ms further from Indian users (fine for this app). The x86 line has had stock shortages. |

**Recommendation: DigitalOcean, Bangalore, Basic 2 vCPU / 4 GB.** It keeps seafarers' data in India (the simplest
story for the privacy notice and DPDP), and the dashboard is the easiest to hand over. If cost matters more
during testing, Hetzner CX23 works the same way; set `SA_HOSTING_DESCRIPTION` accordingly ("a cloud server in
Germany").

## B. Domain
A `.in` domain costs roughly **$4–10 per year** at Indian registrars (e.g. HIOX, BigRock); the first year is often
cheaper, so compare the **renewal** price. Add 18% GST. You need it for HTTPS and for sending email from your
own address. The API would live at e.g. `api.yourname.in`.

## C. Email (sign-in codes + email alerts)
| Option | Free tier | Notes |
|---|---|---|
| **Brevo** | **300 emails / day**, SMTP included, no card | Free plan adds a small "Sent with Brevo" footer. Plenty for testers. |
| Resend | 3,000 / month, max 100 / day | Developer-friendly; the 100/day cap could be hit on a busy day. |
| AWS SES | Pay per email (very cheap) | Requires leaving the SES sandbox (approval). Good later. |

**Recommendation: Brevo free plan** now; move to a paid plan or SES at launch.

## D. What you will do (about 30 minutes) and what I will do
1. You: create the DigitalOcean account (card needed), create a Droplet: Ubuntu 24.04, Bangalore, Basic
   2 vCPU / 4 GB, SSH key or password. Send me its IP address (not the password).
2. You: buy the domain; I give you the one DNS record to add (`api` → the server IP).
3. You: create the Brevo account, verify the domain (Brevo shows 2–3 DNS records), create an SMTP key.
4. Me: follow `docs/deployment.md` – install, configure, start, create your admin account, load the real data,
   check HTTPS, backups and health, then build the tester installer pointing at `https://api.<domain>`.

## Monthly cost for the test
About **$24 (server) + ~$1 (domain) + $0 (email) ≈ $25 / month** with DigitalOcean, or **≈ $8 / month** with Hetzner.

## Completely free option ($0 / month)
| Part | Free choice | Notes |
|---|---|---|
| Server | **Oracle Cloud Always Free**, Ampere A1 (ARM), Ubuntu 24.04 | Pick **Mumbai or Hyderabad as home region** at sign-up (free compute must be in the home region). Allowance cut in June 2026 to 2 OCPU / 12 GB (still plenty); up to 200 GB disk. Card needed for verification, not charged unless upgraded. Creation can fail with "out of host capacity" – retry later / another availability domain. Near-idle instances may be reclaimed (the worker keeps it busy). All our images (python:3.12-slim, pgvector/pgvector:pg16, caddy:2) are multi-arch, so the compose file runs on ARM unchanged. |
| Address + HTTPS | **DuckDNS** subdomain, e.g. `seafarer-test.duckdns.org` | Caddy issues the certificate. No domain purchase. |
| Email | A **dedicated Gmail account** + app password (`smtp.gmail.com:587`, STARTTLS) | ~500 recipients/day. Never the owner's personal Gmail. Brevo's free plan works too once a domain exists. |
| Installer signing | Existing self-signed test certificate | Testers trust it once (see the install guide). |

Oracle extra step: open TCP 80 and 443 in the VCN security list (Networking → the subnet's security list → ingress rules) **and** on the server (`sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT`, then `sudo netfilter-persistent save`); Oracle's Ubuntu images block them by default.

Fallback with no card: run the backend on the owner's PC (as `demo.ps1`) and expose it with Tailscale Funnel (free, fixed `https://<name>.ts.net`). Works only while the PC is on, and data sits on a personal machine – fine for a one-week trial, not a proper test.

Avoid for this app: Render / Koyeb / Supabase / Neon free tiers (services sleep, free databases expire or pause, no free always-on worker).

## Sources
- DigitalOcean: https://www.digitalocean.com/pricing/droplets ; Bangalore listing: https://pcr.cloud-mercato.com/providers/digitalocean/flavors/s-2vcpu-4gb
- AWS Lightsail: https://cloudburn.io/blog/amazon-lightsail-pricing ; transfer: https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-faq-data-transfer-allowance.html
- Hetzner: https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/ ; https://www.cloudhim.com/cloud-costs/hetzner-cx22-pricing-2026
- Brevo: https://www.brevo.com/products/transactional-email/ ; Resend: https://nuntly.com/resend-pricing
- .in domains: https://domainoffer.net/tld/in
- Oracle Always Free: https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm ; 2026 cut: https://infoq.com/news/2026/07/oracle-cloud-free-tier-limits/
- Gmail SMTP limits: https://serversmtp.com/limits-of-gmail-smtp-server/
