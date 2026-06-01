# Netlify Preview-First Deployment Workflow (Wahulo)

Last reviewed: 2026-05-31

Goal: day-to-day changes should go to preview URLs, while production at wahulo.com changes only when you explicitly release.

This guide is specific to this repository:
- Repo: ItsTheMcCoy/wahoo-app
- Static publish directory: godot/build/web
- Public production domains: wahulo.com and www.wahulo.com
- Active production host: Netlify

## 1) One-time setup in Netlify UI

### 1.1 Confirm production branch and build settings

1. Open your site in Netlify.
2. Go to Project configuration -> Build & deploy -> Continuous deployment.
3. In Branches and deploy contexts, select Configure.
4. Confirm Production branch is main.
5. In Build settings, confirm:
   - Build command: blank (or a no-op if required by UI)
   - Publish directory: godot/build/web

Why: only pushes/merges to main should target your public URL.

### 1.2 Enable preview channels

1. Stay in Project configuration -> Build & deploy -> Continuous deployment -> Branches and deploy contexts.
2. Confirm Deploy Previews are enabled.
   - Netlify normally enables these by default for pull requests.
3. Set Branch deploys to one of these:
   - Let me add individual branches: recommended for control
   - All: easiest, but can generate more previews than needed
4. If using individual branches, add a pattern such as feature/* and optionally qa or staging.
5. Save.

Why: this gives you non-production URLs for daily iteration.

### 1.3 Optional but recommended: branded preview domains

Use this only if your preview links need to look cleaner than netlify.app links.

1. Go to Domain management -> Automatic deploy subdomains.
2. Select Edit custom domains.
3. Add a custom domain for Deploy Previews and/or Branch deploys.
4. Save.

Important: this requires Netlify DNS for the chosen domain/subdomain.

### 1.4 Optional safety switch: lock production auto-publishing

If you want zero accidental production updates from main while still allowing builds:

1. Go to Deploys tab.
2. Select Lock to stop auto publishing.
3. Keep working normally on previews.
4. When ready to release, unlock and publish intentionally.

Behavior note: when locked, Netlify still builds deploys, but does not auto-publish to the main site URL.

## 2) Git workflow that keeps day-to-day work on preview only

### 2.1 Daily branch workflow

1. Create a feature branch from main.
2. Make your changes.
3. If you changed Godot gameplay/UI/assets, re-export web build into godot/build/web.
4. Commit and push branch.
5. Open a PR to main.
6. Use the Deploy Preview URL from the PR for testing and sharing.

Result: collaborators see updates on deploy-preview-<PR number> URLs, not wahulo.com.

### 2.2 If you want a stable QA URL before PR merge

1. Keep using the same long-lived branch (example: qa).
2. Ensure qa is included in Branch deploys.
3. Push commits to qa.
4. Test on qa--<site>.netlify.app (or your configured branch subdomain).

Result: one stable preview URL that updates each commit.

## 3) Controlled release process (when you want public update)

Use one of these release methods.

### Method A: Merge-based release (simple)

1. Verify Deploy Preview is good.
2. Merge PR into main.
3. Netlify creates a production deploy from main.
4. Confirm the new deploy is published at wahulo.com.

Use this when production auto-publishing is not locked.

### Method B: Locked production + manual publish (maximum control)

1. Keep production locked while developing.
2. Merge PR into main (build can run, but site stays pinned).
3. On Deploys page, open the specific successful deploy.
4. Select Publish deploy when you want it public.

Use this when you want explicit release timing.

### Method C: Rollback if needed

1. Open Deploys.
2. Open a previous successful deploy.
3. Select Publish deploy.

This is instant because Netlify re-publishes an existing atomic deploy.

## 4) Guardrails to avoid unnecessary deploy usage

### 4.1 Skip deploy for housekeeping commits

Use one of these in commit message when you do not need branch/production deploy:
- [skip netlify]
- [skip ci]

Netlify behavior:
- On branch/main pushes, deploy is skipped.
- On PRs, putting this in PR title skips Deploy Preview generation for that PR.

### 4.2 Do not use Stop builds for normal preview-first workflow

Stopping builds disables all deploy types:
- production deploys
- deploy previews
- branch deploys

Only use Stop builds for temporary freeze situations.

### 4.3 Keep preview access private when needed

If preview URLs should not be public, enable password protection for Deploy Previews and/or branch deploys.

## 5) Recommended default settings for this project

If you want a practical default with minimal surprises:

1. Production branch: main.
2. Deploy Previews: enabled.
3. Branch deploys: individual branches only, set feature/* and qa.
4. Production lock: enabled during active development weeks, disabled only for release windows.
5. Release rule: only merge to main when you intend to release.

## 6) Day-to-day checklist (copy/paste)

1. Start branch from main.
2. Code changes.
3. Re-export godot/build/web if Godot files changed.
4. Push branch.
5. Open/refresh PR.
6. Validate Deploy Preview URL.
7. Merge only when release-ready.
8. If production locked: manually Publish deploy when ready.

## 7) Troubleshooting quick map

Issue: No Deploy Preview appears on PR.
- Check Branches and deploy contexts -> Deploy Previews is enabled.
- Confirm PR base branch is production branch or a branch-deploy-enabled branch.

Issue: Branch URL not updating.
- Check branch is included in Branch deploy controls.
- Push a new commit to that branch.

Issue: Production changed unexpectedly.
- Check whether deploy lock was off.
- Check whether main received a merge/push.

Issue: Too many builds.
- Reduce branch deploy scope to individual branches only.
- Use [skip netlify] for non-preview-worthy commits.

## 8) Official docs referenced

- Deploy overview: https://docs.netlify.com/deploy/deploy-overview/
- Deploy Previews: https://docs.netlify.com/deploy/deploy-types/deploy-previews/
- Branch deploys: https://docs.netlify.com/deploy/deploy-types/branch-deploys/
- Manage deploys (lock/publish/rollback/skip): https://docs.netlify.com/deploy/manage-deploys/manage-deploys-overview/
- Stop or activate builds: https://docs.netlify.com/build/configure-builds/stop-or-activate-builds/
- Ignore builds: https://docs.netlify.com/build/configure-builds/ignore-builds/
- Automatic deploy subdomains: https://docs.netlify.com/manage/domains/manage-domains/automatic-deploy-subdomains/
