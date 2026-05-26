# Wahoo App — Development Plan

Current state of the project and the path forward. Updated as phases complete.

## Project Goal

Build a browser-based game implementing the Wahoo board game, playable on any device (Windows, Mac, Android, iPhone, iPad) via a shared URL. Online multiplayer, learn-as-you-go hobby project.

## Tech Stack

- **Engine:** Godot 4 (chosen for free licensing, Python-like GDScript, strong 2D support, and a built-in high-level multiplayer API)
- **Rules engine prototype:** Python (current phase)
- **Primary target platform:** Web/HTML5 (playable in any browser, shareable by URL — no install required)
- **Secondary target platform:** Desktop (Windows/macOS) for development and testing convenience
- **Multiplayer transport:** WebRTC via Godot's `WebRTCMultiplayerPeer`; requires a lightweight signaling server to broker initial peer connections
- **Signaling server hosting:** Free tier on Railway or Render (sufficient for small friend groups)
- **iOS/Android native builds:** Out of scope — browser covers all mobile devices without requiring Apple Developer account or per-platform distribution management

## Phase Status

### Phase 1 — Rules Engine (Python) — *In progress*

Core game logic and a console-mode game loop, no graphics.

**Done:**
- Board geometry and per-player constants (`wahoo/game_state.py`)
- `legal_moves()` and `apply_move()` (`wahoo/rules.py`)
- Console pass-and-play game loop (`wahoo/play.py`)
- Expanded rule/behavior test suite (`tests/test_wahoo.py`)
- Spec doc for AI development (`RULES.md`)
- Player-facing rules (`HOW_TO_PLAY.md`)
- Home-entry capture bug fix
- `pending_roll` cleanup
- Replay recording and playback support
- Replay-by-index load with back/next navigation and decision-view resume
- Startup replay and computer self-play options
- Auto-roll toggle across prompts
- Project reorganized into package layout (`wahoo/` + `tests/`)
- Per-seat player configuration in `wahoo/play.py`; each slot can be `human` or a profile from `wahoo.ai.PROFILES`
- Optional human move reasoning capture for manual multi-option choices (stored as non-optimal context)
- `wahoo/reasoning_export.py` JSONL exporter for human reasoning samples

**Repo status:** Local and GitHub are now synchronized on `main`.

**Remaining for phase completion:**
- Play 2-3 full games through `python -m wahoo.play` (run from repo root; if inside `wahoo/`, use `python play.py`) to surface any rule edge cases not covered by tests
- Play 2-3 full games to produce reasoning data
- Keep docs current as rules/UI evolve

### Phase 1b — Python AI Opponents — *In progress*

Build and validate computer opponents in the Python prototype before the Godot port. This serves two goals: makes the console game immediately playable for solo testing, and produces a validated algorithm + scenario tests that port mechanically to GDScript in Phase 3.

The full design framework, strategy dimensions, playstyle profiles, and scenario probes are in `documents/AI_Strategy_Spec.md`. The metric/logging schema for evaluating AI quality is in `documents/wahoo_strategy_metric_tracking_agent_spec.md`.

**Tier 1 — Random (baseline)**
- `RandomPlayer` in `wahoo/ai.py`: `choose_move(state, player, roll, moves) -> Move` picks uniformly at random
- Wire into `play.py` as a selectable player type per slot (human / random / greedy)
- Confirms the game loop is AI-compatible without any heuristic noise

**Tier 2 — Greedy heuristic**
- `GreedyPlayer`: score each legal move with a hand-crafted utility function
- Hard rule: always take an immediate winning move (overrides all heuristic weights)
- Feature handles from `RULES.md` §8.3 and `AI_Strategy_Spec.md`:
  - Captures (weight by victim's progress — high-progress captures score higher)
  - Center entry (high value; tempered by whether the marble has used its window)
  - Net square advancement toward home
  - Capture exposure penalty (landing squares reachable by opponents on next turn)
  - Home-lane progress (weighted higher late-game via phase modifier)
- Validate against the scenario probe bank in `AI_Strategy_Spec.md` §Validation

**Tier 2b — Named playstyle profiles (optional)**
- Profiles (Sprinter, Assassin, Tortoise, Balanced Pragmatist, etc.) are weight vectors over the 10 strategy dimensions defined in `AI_Strategy_Spec.md`
- Wire into `GreedyPlayer` as configurable weight sets; one profile = one constructor argument
- Enables human vs. distinct AI personalities in the console game

**Tier 3 — One-ply expectimax (optional/stretch)**
- For each legal move, simulate all 6 die outcomes for the opponent's next turn, assume opponent plays greedy-best, and pick the move maximizing expected own score
- Requires threading re-rolls correctly; `GameState.clone()` already exists for this
- See `RULES.md` §8.6 for implementation notes

**Self-play and validation infrastructure**
- Self-play runner: run N games between configurable AI slots, collect win-rate stats
- Scenario probe runner: feed hand-crafted states from `AI_Strategy_Spec.md` and assert profile-typical choices at the expected frequency
- Log format from `wahoo_strategy_metric_tracking_agent_spec.md` (game/player/turn tables) for post-hoc strategy analysis

**Done:**
- `wahoo/ai.py` — complete: `_marble_progress()`, `compute_exposure()`, `_loc_progress()`, `_self_block_count()`, `compute_features()` (all 10 features), `_game_phase()`, `DEFAULT_PHASE_WEIGHTS`, all 8 profile weight dicts, `RandomPlayer`, `GreedyPlayer` with win guardrail, `PROFILES` registry
- `tests/test_ai.py` — probe 1 (win guardrail) written; all profiles pass
- `tests/test_ai.py` — probe 2 (center temptation) written; shortcut-friendly profiles prefer center, Swarm deploys, Tortoise avoids center
- `tests/test_ai.py` — probe 3 (capture vs deploy) written; Assassin and Gatekeeper capture, Swarm deploys
- `tests/test_ai.py` — probe 4 (finish or fight) written; Engineer, Tortoise, and Balanced prefer home progress; Assassin and Gatekeeper capture
- `tests/test_ai.py` — probe 5 (center denial) written; Gatekeeper and Assassin bump opponent from center
- `tests/test_ai.py` — probe 6 (threat escape) written; Tortoise and Gatekeeper move away from capture danger
- `wahoo/play.py` — `settings["players"]` list, per-slot human/AI dispatch, AI auto-roll, and startup `configure_players()` implemented
- `[C] Computer self-play` now maps all four seats to the `balanced` AI profile for backward-compatible startup behavior
- `wahoo/selfplay.py` — headless N-game AI runner with configurable profile slots, deterministic seed support, max-turn safety cap, compact win-rate summary, and seat-rotated profile benchmark mode
- `tests/test_selfplay.py` — self-play CLI/function coverage added
- 50-game balanced-vs-balanced-vs-balanced-vs-balanced smoke check re-run after gameplay bug fix with seed `20260525`: 50/50 games completed; wins Red 11, Green 14, Yellow 12, Blue 13 (avg turns 1219.4, avg rolls 1462.9, avg captures 249.0)
- Benchmark mode added: `--benchmark-profiles`, `--benchmark-opponents`, `--benchmark-games-per-seat` for fair profile ranking via seat rotation
- `wahoo/stats.py` — implemented `TurnRecord`, `PlayerGameStats`, `GameSummary`, `compute_turn_record()`, `compile_game_stats()`, `print_game_report()`, and `append_stats_csv()`
- `wahoo/play.py` — turn-detail events (`event.type = "turn_detail"`) now recorded alongside existing turn events; recording header upgraded to version 2 with `players`; post-game stats report + CSV append integrated
- `tests/test_stats.py` — stats module and CSV/output behavior coverage added
- `wahoo/ai.py` — `ExpectimaxPlayer` implemented (one-ply, reroll-aware lookahead), registered as `expectimax` in `PROFILES`

**Remaining:**
- Build a human-like profile after additional games are played with recorded human reasoning
- Encode observed human tendencies as measurable targets for profile adjustments
- Add a tuning script after the human-like profile exists to search/refine weight variants against benchmark opponents

### Phase 2a — Godot Bootstrap — *Not started*

Port the rules engine to Godot. No graphics yet — confirm the engine runs correctly on desktop and exports to a browser.

- Install Godot 4 and complete the official "Your First 2D Game" tutorial
- Port `wahoo/game_state.py` and `wahoo/rules.py` to GDScript (mechanical translation, languages are similar)
- Port `tests/test_wahoo.py` scenarios and verify all rule behaviors pass in GDScript
- Build a minimal Godot project with a "Roll" button and text output of game state — run on desktop first
- Configure HTML5 export — fiddly setup done once now rather than at the end
- Load the exported build in a desktop browser and a mobile browser; confirm input and layout are functional

### Phase 2b — Visual Board — *Not started*

Replace text output with a real graphical board. Hot-seat 4-player on one device.

- Add a layout module mapping `Location` → pixel coordinates (kept separate from rules code)
- Draw the plus-shaped board, base clusters, home rows, center hole, and track squares
- Render marbles with player colors
- Highlight legal-move destinations after a roll
- Tap-to-move interaction
- Animate marble movement
- Roll button, current-player indicator, turn announcements
- Win screen

### Phase 3 — Single-Device AI (Godot) — *Not started*

Port the validated Python AI from Phase 1b into GDScript and wire it into the Godot game.

- Translate `wahoo/ai.py` (`RandomPlayer`, `GreedyPlayer`) to GDScript — mechanical translation, same algorithm
- Per-slot AI selection in the Godot UI (human or one of the AI tiers)
- Port the scenario probe tests to GDScript to confirm parity with Python behavior
- Optional: named playstyle profiles (Sprinter, Assassin, Tortoise, etc.) as selectable AI personalities
- Optional: one-ply expectimax if greedy feels too weak

The full design framework, strategy dimensions, playstyle profiles, scenario probes, and logging schema are in `documents/AI_Strategy_Spec.md` and `documents/wahoo_strategy_metric_tracking_agent_spec.md`. The Python prototype in Phase 1b is the reference implementation — if behavior differs in Godot, the Python behavior wins.

### Phase 4 — Internet Multiplayer — *Not started*

Network play over the internet via WebRTC, accessible from the browser with no install required.

- Deploy a lightweight signaling server (e.g., on Railway or Render free tier) to broker WebRTC peer connections
- Implement Godot's `WebRTCMultiplayerPeer` for peer-to-peer game state sync after signaling
- Room-code lobby: host creates a game and shares a short code; others enter the code to join
- Synchronize game state across clients with authoritative host
- Handle turn ordering across the network
- Disconnect/reconnect handling (at least graceful failure — show a "player disconnected" state)

This covers "share a URL and a room code with friends" with minimal infrastructure cost. Sufficient for v1.

### Phase 5 — Decide Next Direction — *Not started*

After Phase 4 is working, decide whether to ship as-is or invest further. Three realistic options:

- **Tier A (already built):** Browser game with room-code multiplayer, shareable by URL. Done after Phase 4.
- **Tier B:** Persistent hosting with a stable public URL. Move the game and signaling server to a proper host (e.g., a cheap VPS or static host + serverless signaling) so friends always have a reliable link rather than a dev server. Low complexity, mostly ops work.
- **Tier C:** Accounts, game history, leaderboards. Real product work — likely overscoped for a hobby project but possible if appetite exists.

Decision deferred until Phase 4 is functional and the appetite for further work is clear.

## Cross-Cutting Concerns

**Cross-device development.** Code lives in `https://github.com/ItsTheMcCoy/wahoo-app`. Edit on any device, push to the repo, pull from any other device. The browser-first target means friends on any platform (Windows, Mac, Android, iPhone, iPad) can play via a shared URL with no install required.

**No iOS/Android native builds.** Native mobile builds are out of scope — the browser covers all mobile devices without requiring an Apple Developer account or per-platform distribution. If this changes, iOS requires a Mac and $99/yr Apple Developer account; Android APK sideloading is feasible but unnecessary if the web version is sufficient.

**Rules vs. code consistency.** `RULES.md` is the authoritative spec. If the code and the spec disagree, the spec wins and the code should be fixed. This matters most when AI assistants (Cowork, Claude Code) work on the project — they should read the spec first.

**Visual layout is a rendering concern, not a rules concern.** The rules engine uses abstract `Location` values (`BASE`, `TRACK(i)`, `HOME(j)`, `CENTER`). Pixel coordinates and screen geometry belong in a separate layout module added in Phase 2b. This keeps the rules code portable and unaffected by UI changes.

**HTML5 export should be confirmed early, not at the end.** Configured in Phase 2a so browser-specific issues (input handling, viewport scaling, mobile layout) surface before the project gets large. Browser bugs are easier to find when the codebase is small.

## File Inventory

Current files in the project:

| File | Purpose | Status |
|------|---------|--------|
| `wahoo/game_state.py` | Data model: locations, GameState, constants | In repo |
| `wahoo/rules.py` | `legal_moves()` and `apply_move()` | In repo |
| `wahoo/play.py` | Console game loop | In repo |
| `wahoo/selfplay.py` | Headless N-game AI self-play CLI runner + profile benchmark mode | In repo |
| `wahoo/reasoning_export.py` | Export human move-reasoning examples from replays to JSONL | In repo |
| `tests/test_wahoo.py` | Rule and behavior test suite | In repo |
| `tests/test_reasoning_export.py` | Reasoning export utility tests | In repo |
| `README.md` | Run/test instructions and current features | In repo |
| `documents/RULES.md` | Authoritative rules spec; §8 covers AI design notes | In repo |
| `documents/HOW_TO_PLAY.md` | Player-facing rules summary | In repo |
| `documents/AI_Strategy_Spec.md` | Full AI design: 10 strategy dimensions, 8 playstyle profiles, scenario probe bank, logging schema | In repo |
| `documents/AI_PLAYER_BUILD_PLAN.md` | Implementation spec for `wahoo/ai.py`: class interfaces, feature formulas, profile weights, test plan | In repo |
| `documents/STAT_TRACKING_PLAN.md` | Per-game/player/turn stat tracking design: extended recording schema, `wahoo/stats.py` plan, CSV export, style vector analysis | In repo |
| `documents/wahoo_strategy_metric_tracking_agent_spec.md` | Metric tracking plan spec: data tables, decision/capture/shortcut logging, analysis guidance | In repo |
| `documents/DEVELOPMENT_PLAN.md` | This document | In repo |
| `.gitignore` | Standard Python + Godot ignores + generated game history files | In repo |
