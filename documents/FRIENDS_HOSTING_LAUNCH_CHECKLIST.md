# Friends Hosting Launch Checklist

Audience: small private group of friends
Goal: lowest cost, easiest maintenance, reliable sharing link

## Recommended Stack

1. Domain registrar: Cloudflare Registrar or Porkbun
2. Static hosting: Cloudflare Pages (or Netlify free tier)
3. SSL: included by host
4. Backend: none initially unless you need real-time multiplayer services

Why this stack:

1. Godot HTML5 export is static content and works well on CDN hosting.
2. Cost is usually near zero except domain renewal.
3. You avoid lock-in from bundled website-builder plans.

## Cost Expectation

1. Domain: typically 10-20 USD per year
2. Hosting/CDN/SSL: usually 0 USD at small scale
3. Optional backend later: 0-25 USD per month to start

## Full Launch Checklist

## 1) Buy and secure the domain

1. Buy one domain (prefer .com if available).
2. Enable WHOIS privacy.
3. Enable account 2FA.
4. Turn on registrar lock/domain lock.

## 2) Create hosting project

1. Create a Cloudflare account.
2. Open Pages and create a new project.
3. Connect your repo, or choose manual upload.

## 3) Export Godot web build

1. Export HTML5 build to a dedicated folder.
2. Confirm output contains expected web files:
   - index.html
   - game JavaScript file(s)
   - game package file (.pck)
   - asset files/icons as needed
3. Test build in a browser before upload.

## 4) Deploy

Git-based deploy:

1. Set build command to none (if already pre-exported).
2. Set output directory to your web build folder.
3. Deploy and open the temporary host URL.

Manual deploy:

1. Upload/drag-drop the exported folder in Pages.
2. Open the temporary host URL.

## 5) Attach custom domain

1. In hosting settings, add your domain.
2. Let the platform create DNS records.
3. Wait for SSL provisioning.
4. Verify:
   - apex domain (example.com)
   - www redirect (optional)

## 6) Reliability settings

1. Force HTTPS.
2. Keep CDN caching enabled for static assets.
3. Use cache-busting on releases (versioned file names or query parameters).
4. Keep one known-good prior export for quick rollback.

## 7) Private-friends access options

1. Simple: share the URL only in your private chat.
2. Light gate: add an in-game shared room code.
3. Strong gate (optional): email allowlist via Cloudflare Access.

## 8) Release routine

1. Export new build.
2. Deploy.
3. Smoke test on desktop and mobile.
4. Share short release notes with friends.
5. Roll back to prior build if needed.

## 15-Minute Quick Start

1. Buy domain with privacy enabled.
2. Create Cloudflare Pages project.
3. Upload existing Godot web export.
4. Confirm temporary URL works on phone.
5. Attach custom domain.
6. Confirm HTTPS works.
7. Share link with friend group.

## Future Upgrade Trigger

Add backend hosting only when one of these is true:

1. You need persistent player accounts.
2. You need matchmaking/lobbies.
3. You need authoritative real-time game state.
4. You need analytics beyond basic page metrics.

Until then, keep architecture simple: domain + static hosting.