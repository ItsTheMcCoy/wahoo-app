# Wahulo: Marble Mayham — Development Plan

Current state of the project and the path forward. Updated as phases complete.

## Session Note

**Deployment:** `wahulo.com` is live on Netlify. Domain purchased in Cloudflare; Cloudflare Pages is blocked by a per-file size limit (index.wasm ~36 MiB vs 25 MiB limit), so Netlify is the active host. DNS routes correctly; HTTPS confirmed on desktop and mobile.

**Loading screen and assets (complete as of 2026-05-31):** The default Godot boot splash has been replaced with a branded loading experience — dark felt-textured background, Wahulo wordmark, and an amber progress bar. A custom HTML shell (`godot/custom_html_shell.html`) persists the branding across Godot re-exports. All launch assets are in place: app icon, favicon, Apple touch icon, boot splash, OG/social preview image, and the felt background tile. `project.godot` is wired to the branded icon and boot splash. Open Graph meta tags are in the HTML shell. See `documents/ASSET_DESIGN_GUIDE.md` for the full visual design system.

**In-game branding (complete as of 2026-05-31):** The game title "WAHULO" now appears in three in-game locations in the Godot scene (`godot/scenes/Main.tscn`): as a gold label at the top of the side panel (visible throughout play), as a header above "Game Setup" in the setup overlay (seen before each game), and as a header above the winner announcement in the win overlay (seen at game end). All three use the gold color `#c8922a` from the design guide.

**Latest test snapshot (2026-06-01):** Godot smoke suite remains `51/51 passed`. Python suite currently reports `100 collected`, `20 failed`, `80 passed` because `wahoo/profiles_manager.json` overrides builtin profile names expected by several AI/self-play/play tests.

**Multiplayer backend status (2026-06-01):** Phase 4a has an initial Node.js WebSocket relay implementation under `server/`. It supports room creation/joining, host-only AI seat configuration, spectator joins, chat relay, server-side rolls, legal-move validation, state broadcasts, basic reconnect handling, room expiry, and a Render deployment config. The relay test suite passes locally with `npm test` (`8/8` Node tests passing). The next multiplayer work is Godot client integration: network wrapper, home/lobby UI, and server-authoritative online turn flow.

**Netlify owner-task status (2026-06-01):** Netlify is the active static host. The repo now includes `netlify.toml` with `publish = "godot/build/web"` and a catch-all rewrite to `/index.html` so future `/join/<code>` multiplayer deep links can load the Godot app. Owner-facing Netlify dashboard tasks and walkthrough steps are tracked in `documents/MULTIPLAYER_PLAN.md` under "Owner Task Tracking" and "Step 5: Verify Netlify Static Hosting for the Game Client". Update those sections whenever new implementation details change what the owner must do.

## Project Goal

Build a browser-based game for Wahulo: Marble Mayham (a Wahoo-style marble race), playable on any device (Windows, Mac, Android, iPhone, iPad) via a shared URL. Public domain: wahulo.com (purchased via Cloudflare). Online multiplayer, learn-as-you-go hobby project.

## Tech Stack

- **Engine:** Godot 4.6.3 (free licensing, Python-like GDScript, strong 2D support)
- **Rules engine prototype:** Python (Phases 1–1b)
- **Primary target platform:** Web/HTML5 (playable in any browser, shareable by URL — no install required)
- **Multiplayer transport:** WebSocket relay server (Node.js + `ws`); server-authoritative game state
- **Server hosting:** Render free tier for the relay server (current plan; custom domain managed in Cloudflare DNS)
- **Client hosting:** Netlify (active production hosting due to Cloudflare Pages file-size limit)
- **iOS/Android native builds:** Out of scope — browser covers all mobile devices without an Apple Developer account or per-platform distribution

## User Feedback

This section tracks feedback to address before advancing any in-progress phases.

1. ✅ Standard vs Training game mode: reasoning prompts only in Training mode.
2. ✅ Turn numbers in each turn header.
3. ✅ AI difficulty / profile menus now show sub-menus with descriptions; profiles listed easiest → hardest.
4. ✅ Fixed 2s AI delay after each AI move and roll when humans are present.
5. ✅ Human seats prompt for a player name during setup (max 12 characters).
6. ✅ Player labels show color + name/profile throughout gameplay.
7. ✅ Board renderer spacing tightened; no extra blank lines between rows.
8. ✅ Inter-row spacer lines added so vertical spacing matches horizontal.
9. ✅ Python board base layout adjusted: Yellow shifted up/right, Green shifted left, trailing blank rows removed.
10. During human vs AI play, AI profiles will land on an opponent's base exit (when opponent has marbles in base) or opponent's center exit (when opponent has a marble in the center), even when less risky moves are available. All AI profiles should factor in whether landing on those squares is riskier than the alternatives.
11. Yellow player name text collides with Yellow base positions on board; adjust label placement while preserving other player label placement.
12. ✅ Godot loading screen: replaced default Godot splash with branded HTML shell (felt background, wordmark, amber progress bar). All launch assets implemented: icon, favicon, touch icon, boot splash, OG image. Custom HTML shell persists across re-exports. See `documents/ASSET_DESIGN_GUIDE.md`.
13. Mobile UX pass: improve portrait and landscape readability/layout (board scale, side-panel text size and length), and evaluate fullscreen options to recover mobile browser address-bar screen space.

## Phase Summary

### Phase 1 — Rules Engine (Python) — *Complete*

Python rules engine, console game loop, replay recording/playback, per-seat player configuration, Standard vs Training game modes, AI delay, human name prompts, board renderer polish.

### Phase 1b — Python AI Opponents — *Mostly complete; minor remaining work*

All 8 AI profiles, `compute_features()` (10 features), `RandomPlayer`, `GreedyPlayer` with win guardrail, `ExpectimaxPlayer`, full 6-probe scenario test suite, headless self-play runner with seat-rotation benchmarking, stat tracking with CSV export, turn-detail recording, human-like profile training infrastructure.

**Remaining:** Build a stronger sprinter-beating candidate via overnight tuning runs; build a richer human-like profile after more training games.

### Phase 2a — Godot Bootstrap — *Complete*

GDScript port of rules engine, 27 parity smoke tests, HTML5 export validated on desktop and mobile browsers, mobile text readability fixes.

### Phase 2b — Visual Board — *Complete*

Board-left / info-panel-right layout, graphical board with marble rendering, tap-to-move selection, lift-and-place movement animation (style presets: subtle/arcade/cinematic), dynamic marble shadow, landing impact pulse, current-player indicator, turn announcements, and win screen. Visual polish passes added warm tabletop realism: layered wood board surface, external board/marble textures, cavity/ambient depth cues, lane shadowing, and improved side-panel readability/contrast. Initial Phase 2b validation: 32/32 Godot smoke checks and 80 Python tests.

### Phase 3a — GDScript AI Engine — *Complete*

Full `wahoo_ai.gd` port: all 10 features, 9 profile weight dicts, `RandomPlayer`, `GreedyPlayer`, `make_profiles()` factory. 44/44 smoke checks pass (32 rules/layout + 12 AI load).

### Phase 3b — AI Parity Smoke Tests — *Complete*

All 6 scenario probes from `test_ai.py` ported to `wahoo_ai_smoke.gd` and passing headlessly. Current total Godot smoke count: 51/51.

### Phase 3c — Game Loop AI Integration — *Complete*

Per-seat AI profile dropdowns in setup overlay, AI auto-play with delays, Roll/tap-target disable during animation, save/load with seat config, opening-roll phase, game menu.

### Phase 3d — Expectimax Port (Stretch) — *Deferred*

Port `ExpectimaxPlayer` to GDScript and add as a seat option. Deferred pending performance validation — one-ply lookahead may cause visible frame stalls on Web/WASM.

### Phase 3e — End Turn Gate — *Complete*

Removed move-reveal highlights (restores physical board feel); added explicit End Turn button that enables after the human player completes a move.

### Phase 3f — Layout Redesign — *Complete*

Two-column layout (board left, info panel right), Unicode die faces, 14-frame die animation, Mobile-sized tap targets, DieFrame panel for dominant die display.

### Phase 3g — Mobile Polish & Opening Phase UX — *Complete*

Font and tap-target pass to meet 48dp/44pt minimums; Status log repositioned above die frame; opening-roll phase redesigned with sequential per-player messages; TurnLabel updates to rolling player during opening phase.

### Phase 4 — Internet Multiplayer — *In progress*

Full design and step-by-step implementation plan: **[MULTIPLAYER_PLAN.md](MULTIPLAYER_PLAN.md)**

Summary of sub-phases:
- **4a:** Node.js WebSocket relay server — initial implementation complete locally; room management, spectator support, chat relay, server-side rolls, move validation, basic reconnect handling, room expiry, tests, and Render config are in repo. Remaining 4a work is deployment verification on Render.
- **4b:** Godot home screen, network wrapper, lobby scene (host + guest views), AI seat configuration in lobby — next active work
- **4c:** Online game flow — server-driven turns, AI seats via host client, disconnect/reconnect handling
- **4d:** Domain and DNS in Cloudflare, static hosting on Netlify (current fallback path), relay server on Render with custom subdomain, HTTPS/WSS
- **4e:** Polish — deep link joining, spectator mode, in-game chat refinements, recap page

### Phase 5 — Decide Next Direction — *Not started*

After Phase 4, decide whether to ship as-is (Tier A — browser game with room codes) or invest further:
- **Tier B:** Stable persistent hosting, reliable public URL. Mostly ops work.
- **Tier C:** Accounts, game history, leaderboards. Real product scope.

Decision deferred until Phase 4 is functional and appetite for further work is clear.

---

## Cross-Cutting Concerns

**Cross-device development.** Code lives in `https://github.com/ItsTheMcCoy/wahoo-app`. Edit on any device, push to the repo, pull from any other device.

**No iOS/Android native builds.** The browser covers all mobile devices without an Apple Developer account.

**Rules vs. code consistency.** `RULES.md` is the authoritative spec. If the code and the spec disagree, the spec wins and the code should be fixed.

**Visual layout is a rendering concern, not a rules concern.** The rules engine uses abstract `Location` values (`BASE`, `TRACK(i)`, `HOME(j)`, `CENTER`). Pixel coordinates belong in the layout module.

**HTML5 export confirmed early.** Browser-specific issues surface before the project gets large.

**Web deployment hygiene.** Whenever Godot gameplay or UI files change (`godot/scenes/*.tscn`, `godot/scripts/*.gd`, or relevant assets), perform a fresh Web export to `godot/build/web` and commit those export artifacts before pushing. Netlify deploys from `godot/build/web`, so missing re-exports can cause hosted behavior to lag behind local behavior.

## File Inventory

| File | Purpose | Status |
|------|---------|--------|
| `wahoo/game_state.py` | Data model: locations, GameState, constants | In repo |
| `wahoo/rules.py` | `legal_moves()` and `apply_move()` | In repo |
| `wahoo/play.py` | Console game loop | In repo |
| `wahoo/selfplay.py` | Headless N-game AI self-play CLI runner + profile benchmark mode | In repo |
| `wahoo/reasoning_export.py` | Export human move-reasoning examples from replays to JSONL | In repo |
| `wahoo/human_profile.py` | Fit a `human_like` AI profile from replay reasoning data | In repo |
| `wahoo/human_like_profile.json` | Generated/current human-like AI profile weights | In repo |
| `wahoo/profile_creator.py` | Profile creator/manager tool (UI + CLI: add/update/rename/disable/delete/restore) | In repo |
| `wahoo/profiles_manager.json` | Python runtime profile-manager config (aliases, disabled names, managed profiles) | In repo |
| `tests/test_wahoo.py` | Rule and behavior test suite | In repo |
| `tests/test_ai.py` | AI scenario probe coverage | In repo |
| `tests/test_reasoning_export.py` | Reasoning export utility tests | In repo |
| `tests/test_human_profile.py` | Human-like profile trainer tests | In repo |
| `tests/test_selfplay.py` | Self-play runner tests | In repo |
| `tests/test_stats.py` | Stat tracking tests | In repo |
| `README.md` | Run/test instructions and current features | In repo |
| `documents/RULES.md` | Authoritative rules spec; §8 covers AI design notes | In repo |
| `documents/HOW_TO_PLAY.md` | Player-facing rules summary | In repo |
| `documents/AI_Strategy_Spec.md` | Full AI design: 10 strategy dimensions, 8 playstyle profiles, scenario probe bank, logging schema | In repo |
| `documents/AI_PLAYER_BUILD_PLAN.md` | Implementation spec for `wahoo/ai.py`: class interfaces, feature formulas, profile weights, test plan | In repo |
| `documents/AI_TESTING_PLAN.md` | End-to-end benchmark protocol: baseline, robustness, pairwise confirmation, final ranking | In repo |
| `documents/AI_BENCHMARK_RESULTS.md` | Current AI benchmark results and profile rankings | In repo |
| `documents/AI_SPRINTER_BEATING_TRAINING_PLAN.md` | Training/tuning plan for a sprinter-beating profile | In repo |
| `documents/GRAPHICS_UPGRADE_PLAN.md` | Visual upgrade plan and implementation status for realism polish passes | In repo |
| `documents/STAT_TRACKING_PLAN.md` | Per-game/player/turn stat tracking design | In repo |
| `documents/wahoo_strategy_metric_tracking_agent_spec.md` | Metric tracking plan spec | In repo |
| `documents/DEVELOPMENT_PLAN.md` | This document — phase summary and cross-cutting concerns | In repo |
| `documents/MULTIPLAYER_PLAN.md` | Full multiplayer architecture, Godot client changes, domain purchase guide | In repo |
| `documents/stage3_mixed_opponent_results.md` | Mixed-opponent AI gauntlet results | In repo |
| `documents/stage4_pairwise_confirmation_results.md` | Pairwise AI confirmation results | In repo |
| `scripts/run_mixed_opponent_gauntlets.py` | Stage 3 mixed-opponent benchmark runner | In repo |
| `scripts/run_stage4_pairwise_confirmation.py` | Stage 4 pairwise confirmation benchmark runner | In repo |
| `scripts/tune_profile_against_sprinter.py` | Random-plus-mutation tuning harness for AI weights | In repo |
| `godot/project.godot` | Godot 4.6.3 project file; icon and boot splash wired to branded assets | In repo |
| `godot/icon.png` | 512×512 branded app icon | In repo |
| `godot/custom_html_shell.html` | Branded HTML export template with Godot placeholders; persists across re-exports | In repo |
| `godot/scenes/Main.tscn` | Board-first Godot scene | In repo |
| `godot/scripts/main.gd` | Scene controller: board, turn UI, AI dispatch, save/load, game menu | In repo |
| `godot/scripts/wahoo_board_view.gd` | Visual board surface, marble animation, and animation-style presets | In repo |
| `godot/scripts/wahoo_state.gd` | GDScript port of Python state model | In repo |
| `godot/scripts/wahoo_rules.gd` | GDScript port of Python rules engine | In repo |
| `godot/scripts/wahoo_rules_smoke.gd` | Godot parity smoke tests | In repo |
| `godot/scripts/wahoo_layout.gd` | Normalized visual board coordinate mapping | In repo |
| `godot/scripts/wahoo_layout_smoke.gd` | Godot smoke checks for layout mapping | In repo |
| `godot/scripts/wahoo_ai.gd` | GDScript AI engine: helpers, features, RandomPlayer, GreedyPlayer, 9 profile weight dicts | In repo |
| `godot/profiles_manager.json` | Bundled Godot/web profile-manager config used by setup profile list | In repo |
| `godot/scripts/wahoo_ai_smoke.gd` | GDScript AI scenario probes (6 parity checks) | In repo |
| `godot/scripts/run_smoke.gd` | Headless Godot smoke-test runner (51 checks) | In repo |
| `godot/assets/textures/board_wood.svg` | 1024×1024 procedural wood texture overlay | In repo |
| `godot/assets/textures/marble_gloss.svg` | 256×256 grayscale gloss mask for marble rendering | In repo |
| `godot/assets/textures/wahulo_wordmark.svg` | Scalable wordmark (text + 4 marbles); used in loading screen | In repo |
| `godot/assets/textures/wahulo_wordmark.png` | 1400×520 PNG version of wordmark | In repo |
| `godot/assets/textures/background_felt_tile_512.svg` | 512×512 tileable dark felt background tile | In repo |
| `godot/assets/textures/boot_splash.png` | 800×450 branded boot splash source (referenced by project.godot) | In repo |
| `godot/build/web/og_preview.png` | 1200×630 Open Graph / social preview image | In repo |
| `godot/export_presets.cfg` | Web export preset; references custom HTML shell | In repo |
| `godot/README.md` | Godot setup, validation, and next-phase notes | In repo |
| `documents/ASSET_DESIGN_GUIDE.md` | Complete visual design system: color palette, asset specs, style rules | In repo |
| `.gitignore` | Standard Python + Godot ignores + generated game history files | In repo |
