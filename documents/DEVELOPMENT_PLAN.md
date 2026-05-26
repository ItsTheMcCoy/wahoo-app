# Wahoo App — Development Plan

Current state of the project and the path forward. Updated as phases complete.

## Project Goal

Build an Android game implementing the Wahoo board game. Online multiplayer, learn-as-you-go hobby project.

## Tech Stack

- **Engine:** Godot 4 (chosen for free licensing, Python-like GDScript, strong 2D support, and a built-in high-level multiplayer API)
- **Rules engine prototype:** Python (current phase)
- **Target platform:** Android (with desktop for development)
- **Multiplayer transport:** Godot ENet to start (LAN); decision on internet play deferred to Phase 5

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
- Startup replay and computer self-play options
- Auto-roll toggle across prompts
- Project reorganized into package layout (`wahoo/` + `tests/`)

**Repo status:** Local and GitHub are now synchronized on `main`.

**Remaining for phase completion:**
- Play 2-3 full games through `python -m wahoo.play` to surface any rule edge cases not covered by tests
- Keep docs current as rules/UI evolve

### Phase 1b — Python AI Opponents — *In progress*

Build and validate computer opponents in the Python prototype before the Godot port. This serves two goals: makes the console game immediately playable for solo testing, and produces a validated algorithm + scenario tests that port mechanically to GDScript in Phase 3.

The full design framework, strategy dimensions, playstyle profiles, and scenario probes are in `documents/AI_Stragegy_Spec.md` (filename currently misspelled). The metric/logging schema for evaluating AI quality is in `documents/wahoo_strategy_metric_tracking_agent_spec.md`.

**Tier 1 — Random (baseline)**
- `RandomPlayer` in `wahoo/ai.py`: `choose_move(state, player, roll, moves) -> Move` picks uniformly at random
- Wire into `play.py` as a selectable player type per slot (human / random / greedy)
- Confirms the game loop is AI-compatible without any heuristic noise

**Tier 2 — Greedy heuristic**
- `GreedyPlayer`: score each legal move with a hand-crafted utility function
- Hard rule: always take an immediate winning move (overrides all heuristic weights)
- Feature handles from `RULES.md` §8.3 and `AI_Stragegy_Spec.md`:
  - Captures (weight by victim's progress — high-progress captures score higher)
  - Center entry (high value; tempered by whether the marble has used its window)
  - Net square advancement toward home
  - Capture exposure penalty (landing squares reachable by opponents on next turn)
  - Home-lane progress (weighted higher late-game via phase modifier)
- Validate against the scenario probe bank in `AI_Stragegy_Spec.md` §Validation

**Tier 2b — Named playstyle profiles (optional)**
- Profiles (Sprinter, Assassin, Tortoise, Balanced Pragmatist, etc.) are weight vectors over the 10 strategy dimensions defined in `AI_Stragegy_Spec.md`
- Wire into `GreedyPlayer` as configurable weight sets; one profile = one constructor argument
- Enables human vs. distinct AI personalities in the console game

**Tier 3 — One-ply expectimax (optional/stretch)**
- For each legal move, simulate all 6 die outcomes for the opponent's next turn, assume opponent plays greedy-best, and pick the move maximizing expected own score
- Requires threading re-rolls correctly; `GameState.clone()` already exists for this
- See `RULES.md` §8.6 for implementation notes

**Self-play and validation infrastructure**
- Self-play runner: run N games between configurable AI slots, collect win-rate stats
- Scenario probe runner: feed hand-crafted states from `AI_Stragegy_Spec.md` and assert profile-typical choices at the expected frequency
- Log format from `wahoo_strategy_metric_tracking_agent_spec.md` (game/player/turn tables) for post-hoc strategy analysis

**Done:**
- `wahoo/ai.py` — complete: `_marble_progress()`, `compute_exposure()`, `_loc_progress()`, `_self_block_count()`, `compute_features()` (all 10 features), `_game_phase()`, `DEFAULT_PHASE_WEIGHTS`, all 8 profile weight dicts, `RandomPlayer`, `GreedyPlayer` with win guardrail, `PROFILES` registry
- `tests/test_ai.py` — probe 1 (win guardrail) written; all profiles pass
- `tests/test_ai.py` — probe 2 (center temptation) written; shortcut-friendly profiles prefer center, Swarm deploys, Tortoise avoids center
- `tests/test_ai.py` — probe 3 (capture vs deploy) written; Assassin and Gatekeeper capture, Swarm deploys

**Remaining:**
- `tests/test_ai.py` probes 4–6 (finish or fight, center denial, threat escape)
- Refactor `play.py`: replace `computer_self_play` bool with `players` list; add per-slot AI dispatch
- `wahoo/selfplay.py` headless N-game runner
- Run 50-game self-play to verify win-rate balance across profiles
- `wahoo/stats.py` with `TurnRecord`, `PlayerGameStats`, `GameSummary`
- Hook `compute_turn_record()` into `play.py`'s `take_turn()`
- Optional: `ExpectimaxPlayer` (stretch goal)

### Phase 2a — Godot Bootstrap — *Not started*

Port the rules engine to Godot. No graphics yet — just confirm the engine runs on a phone.

- Install Godot 4 and complete the official "Your First 2D Game" tutorial
- Port `wahoo/game_state.py` and `wahoo/rules.py` to GDScript (mechanical translation, languages are similar)
- Port `tests.py` and verify all tests pass in GDScript
- Build a minimal Godot project with a "Roll" button and text output of game state
- Configure Android export (SDK install, signing keys, deployment) — fiddly setup done once now rather than at the end
- Deploy to a phone and confirm it runs

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

The full design framework, strategy dimensions, playstyle profiles, scenario probes, and logging schema are in `documents/AI_Stragegy_Spec.md` and `documents/wahoo_strategy_metric_tracking_agent_spec.md`. The Python prototype in Phase 1b is the reference implementation — if behavior differs in Godot, the Python behavior wins.

### Phase 4 — LAN Multiplayer — *Not started*

Network play over a local network.

- Godot high-level multiplayer with ENet
- Host/join by IP address (host starts a game, others connect with the host's IP)
- Synchronize game state across clients
- Handle turn ordering across the network
- Disconnect/reconnect handling (at least graceful failure)

This covers "playing with family in the same house" with zero infrastructure cost. Sufficient for v1.

### Phase 5 — Decide Next Direction — *Not started*

After Phase 4 is working, decide whether to ship as LAN-only v1, or invest further. Three realistic options:

- **Tier A (already built):** LAN play. Done after Phase 4.
- **Tier B:** Room-code internet play. One player hosts a public game, shares a code, others join. Requires either a relay server (Nakama free tier exists) or peer-to-peer with NAT traversal. Significant additional work.
- **Tier C:** Full matchmaking ("find me a random opponent"). Requires accounts, backend, queueing. Real product work, likely overscoped for a hobby project.

Decision deferred until Phase 4 is functional and the appetite for further work is clear.

## Cross-Cutting Concerns

**Cross-device development.** Code lives in `https://github.com/ItsTheMcCoy/wahoo-app`. Edit on any device, push to the repo, pull from any other device.

**Rules vs. code consistency.** `RULES.md` is the authoritative spec. If the code and the spec disagree, the spec wins and the code should be fixed. This matters most when AI assistants (Cowork, Claude Code) work on the project — they should read the spec first.

**Visual layout is a rendering concern, not a rules concern.** The rules engine uses abstract `Location` values (`BASE`, `TRACK(i)`, `HOME(j)`, `CENTER`). Pixel coordinates and screen geometry belong in a separate layout module added in Phase 2b. This keeps the rules code portable and unaffected by UI changes.

**Android export should happen early, not at the end.** Originally planned as Phase 5; moved up to Phase 2a so deployment issues surface before the project gets large. Phone-specific bugs (input handling, screen sizes, performance) are easier to find when the codebase is small.

## File Inventory

Current files in the project:

| File | Purpose | Status |
|------|---------|--------|
| `wahoo/game_state.py` | Data model: locations, GameState, constants | In repo |
| `wahoo/rules.py` | `legal_moves()` and `apply_move()` | In repo |
| `wahoo/play.py` | Console game loop | In repo |
| `tests/test_wahoo.py` | Rule and behavior test suite | In repo |
| `README.md` | Run/test instructions and current features | In repo |
| `documents/RULES.md` | Authoritative rules spec; §8 covers AI design notes | In repo |
| `documents/HOW_TO_PLAY.md` | Player-facing rules summary | In repo |
| `documents/AI_Stragegy_Spec.md` | Full AI design: 10 strategy dimensions, 8 playstyle profiles, scenario probe bank, logging schema (filename currently misspelled) | In repo |
| `documents/AI_PLAYER_BUILD_PLAN.md` | Implementation spec for `wahoo/ai.py`: class interfaces, feature formulas, profile weights, test plan | In repo |
| `documents/STAT_TRACKING_PLAN.md` | Per-game/player/turn stat tracking design: extended recording schema, `wahoo/stats.py` plan, CSV export, style vector analysis | In repo |
| `documents/wahoo_strategy_metric_tracking_agent_spec.md` | Metric tracking plan spec: data tables, decision/capture/shortcut logging, analysis guidance | In repo |
| `documents/DEVELOPMENT_PLAN.md` | This document | In repo |
| `.gitignore` | Standard Python + Godot ignores + generated game history files | In repo |
