# Cloudflare Application Setup Guide (Wahulo)

Last reviewed: 2026-05-30
Scope: Cloudflare Pages app + domain + DNS + TLS for this repository

This guide is written for your current state:
- Domain purchased in Cloudflare: `wahulo.com`
- Pages creation path confirmed via `Create application` -> `Looking to deploy pages? Get started`
- GitHub repository to connect: `ItsTheMcCoy/wahoo-app`
- Relay server planned on Render: `relay.wahulo.com`
- Current blocker: Cloudflare Pages rejects `godot/build/web/index.wasm` (~36 MiB) because Pages supports files up to 25 MiB.

## 1. Confirm Account And Zone Health

1. Log in to Cloudflare and open your account dashboard.
2. Go to `Domain Registration` and confirm `wahulo.com` is active.
3. Check your account email is verified.
4. If prompted by ICANN, complete registrant email verification immediately.

Why this matters:
- Cloudflare Registrar can place domains on hold if registrant verification is not complete.

## 2. Create Pages Project And Connect GitHub (Correct UI Path)

Current UI path (Cloudflare docs):
- `Workers & Pages` -> `Create application` (defaults to Worker)
- On that page, click `Looking to deploy pages? Get started`
- In `Get started with Pages`, choose `Import an existing Git repository`

Recommended choice for your project:
- Yes, choose `Import an existing Git repository` (not drag-and-drop), because you want automatic deploys from GitHub.

Steps:
1. `Workers & Pages` -> `Create application`.
2. Click the small-text link: `Looking to deploy pages? Get started`.
3. In `Get started with Pages`, click `Import an existing Git repository`.
2. Choose `GitHub` and authorize Cloudflare Pages.
3. Select repository `ItsTheMcCoy/wahoo-app`.
4. Confirm production branch is `main`.

If already connected, verify:
1. Open project -> `Deployments`.
2. Confirm recent commits from `main` are appearing.
3. Open latest deployment and verify status is `Success`.

## 3. Set Build And Output Configuration For This Repo

This repository already contains exported web artifacts in `godot/build/web`.

Recommended project settings:
1. Project -> `Settings` -> `Builds & deployments`.
2. Production branch: `main`.
3. Build command:
   - Preferred: leave blank (no build step).
   - If UI requires a command, use: `exit 0`.
4. Build output directory: `godot/build/web`.
5. Root directory (advanced): leave empty unless you intentionally want a subfolder root.

Deploy check:
1. Trigger a deployment (new commit or `Retry deployment`).
2. Confirm deployment log completes and `pages.dev` URL loads.

## 4. Attach Custom Domains To The Pages Project

Current UI path (Cloudflare docs):
- `Workers & Pages` -> project -> `Custom domains` -> `Set up a domain`

Steps:
1. Add `wahulo.com`.
2. Add `www.wahulo.com`.
3. Wait for domain status to become active.

Important behavior from current docs:
- Add domains in the Pages UI first.
- Do not only create DNS records manually without adding domains in Pages UI, or the domain can fail to resolve correctly.

## 5. Verify DNS Records In The Zone

Current UI path:
- `DNS` -> `Records`

Confirm:
1. Record exists for apex (`@`) pointing to Pages-managed target.
2. Record exists for `www` pointing to Pages-managed target.
3. Record for relay exists:
   - Type: `CNAME`
   - Name: `relay`
   - Target: your Render host (example: `wahoo-relay.onrender.com`)

Proxy guidance during setup:
1. For Pages records, keep default unless troubleshooting.
2. For relay record, start with `DNS only` while validating Render custom domain.
3. After stable behavior, you can evaluate proxied mode if needed.

## 6. Configure Render Custom Domain For Relay

In Render:
1. Open relay service -> `Settings` -> `Custom Domains`.
2. Add `relay.wahulo.com`.
3. Confirm certificate provisioning completes.

In client config:
1. Use `wss://relay.wahulo.com` as the WebSocket endpoint.

## 7. Set SSL/TLS Mode Safely

Current UI path:
- `SSL/TLS` -> `Overview`

Recommended:
1. Use `Automatic SSL/TLS` if available.
2. If using custom mode, use `Full (strict)` when origin certificates are valid.
3. Avoid `Flexible` for this architecture.

## 8. End-To-End Verification Checklist

Run these checks in order:

1. DNS resolution
   - `nslookup wahulo.com`
   - `nslookup www.wahulo.com`
   - `nslookup relay.wahulo.com`
2. Pages site
   - `https://wahulo.com` loads
   - `https://www.wahulo.com` loads (or redirects as configured)
3. Relay origin
   - `https://relay.wahulo.com` returns expected service response
4. App runtime
   - Game loads on desktop and mobile
   - WebSocket connection succeeds to `wss://relay.wahulo.com`

## 9. Fast Troubleshooting (Latest Known UI/Behavior)

### A. Build failed
1. Project -> `Deployments` -> `View details` -> `Build log`.
2. Re-check build command and output directory.
3. If Git authorization looks broken, re-authorize Cloudflare Pages GitHub app.

### B. Custom domain stuck on Verifying
1. Ensure no Access policy, redirect rule, or Worker blocks `/.well-known/acme-challenge/*`.
2. Check CAA records if present; allow certificate issuance for Cloudflare-supported CAs.
3. If zone hold is enabled, release zone hold during domain attach flow.

### C. `pages.dev` works but custom domain fails
1. Check DNS records in `DNS` -> `Records`.
2. Temporarily set related records to `DNS only` for diagnosis.
3. Remove conflicting cache/page rules if they override expected behavior.

## 10. Operational Guardrails

1. Keep deployment source of truth as `main` branch.
2. Do not manually repoint Pages DNS records away and back unless necessary; this can temporarily deactivate domains.
3. Record each infra change (DNS, SSL mode, custom domains, Render endpoint) in `documents/DEVELOPMENT_PLAN.md`.

## 11. Netlify Fallback (Current Practical Path)

Because the current Godot `index.wasm` exceeds Cloudflare Pages per-file limits, use Netlify for the static client while keeping Cloudflare for domain and DNS.

Steps:
1. In Netlify, create/import site from GitHub repo `ItsTheMcCoy/wahoo-app`.
2. Build command: leave blank.
3. Publish directory: `godot/build/web`.
4. Deploy and verify the Netlify URL loads.
5. In Cloudflare DNS, point `wahulo.com`/`www` to Netlify targets per Netlify domain instructions.
6. Keep relay DNS as `relay.wahulo.com` -> Render host.

Verification:
1. `https://wahulo.com` loads the game.
2. `https://www.wahulo.com` loads or redirects as expected.
3. `https://relay.wahulo.com` responds.
4. In-game WebSocket traffic succeeds to `wss://relay.wahulo.com`.

## Official References Used (Latest UI-Oriented Docs)

- Cloudflare Pages Git integration:
  - https://developers.cloudflare.com/pages/get-started/git-integration/
- Cloudflare Pages custom domains:
  - https://developers.cloudflare.com/pages/configuration/custom-domains/
- Cloudflare Pages build configuration:
  - https://developers.cloudflare.com/pages/configuration/build-configuration/
- Cloudflare Pages debugging:
  - https://developers.cloudflare.com/pages/configuration/debugging-pages/
- Cloudflare DNS record management:
  - https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/
- Cloudflare SSL/TLS encryption modes:
  - https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/
- Cloudflare Registrar domain registration behavior:
  - https://developers.cloudflare.com/registrar/get-started/register-domain/
