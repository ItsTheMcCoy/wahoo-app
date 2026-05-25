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
- Board geometry and per-player constants (`game_state.py`)
- `legal_moves()` and `apply_move()` (`rules.py`)
- Console pass-and-play game loop (`play.py`)
- 20-test rule suite (`tests.py`)
- Spec doc for AI development (`RULES.md`)
- Player-facing rules (`HOW_TO_PLAY.md`)
- Home-entry capture bug fix
- `pending_roll` cleanup

**Pending in repo:** The home-entry fix and cleanup are in local files but not yet pushed to GitHub. Repo still shows original 2-commit state.

**Remaining for phase completion:**
- Push the corrected code and docs to the repo
- Play 2–3 full games through `play.py` to surface any rule edge cases not covered by tests
- Add a `README.md` to the repo root with "how to run" instructions

### Phase 2a — Godot Bootstrap — *Not started*

Port the rules engine to Godot. No graphics yet — just confirm the engine runs on a phone.

- Install Godot 4 and complete the official "Your First 2D Game" tutorial
- Port `game_state.py` and `rules.py` to GDScript (mechanical translation, languages are similar)
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

### Phase 3 — Single-Device AI — *Not started*

Computer opponents so the game is playable solo.

- Difficulty tier 1: random legal move (baseline)
- Difficulty tier 2: greedy heuristic (prefer captures, shortcut, home progress, account for capture exposure)
- AI selection per player slot (human or one of the AI tiers)
- Optional: tier 3 one-ply expectimax if the heuristic AI feels too weak

See `RULES.md` §8 for the AI design framework.

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

**Cross-device development.** Code lives in `https://github.com/ItsTheMcCoy/wahoo-app`. Edit on any device, push to the repo, pull from any other device. Claude can read the repo but not write to it; pushes happen via desktop git client, GitHub Desktop, or GitHub web UI.

**Rules vs. code consistency.** `RULES.md` is the authoritative spec. If the code and the spec disagree, the spec wins and the code should be fixed. This matters most when AI assistants (Cowork, Claude Code) work on the project — they should read the spec first.

**Visual layout is a rendering concern, not a rules concern.** The rules engine uses abstract `Location` values (`BASE`, `TRACK(i)`, `HOME(j)`, `CENTER`). Pixel coordinates and screen geometry belong in a separate layout module added in Phase 2b. This keeps the rules code portable and unaffected by UI changes.

**Android export should happen early, not at the end.** Originally planned as Phase 5; moved up to Phase 2a so deployment issues surface before the project gets large. Phone-specific bugs (input handling, screen sizes, performance) are easier to find when the codebase is small.

## File Inventory

Current files in the project:

| File | Purpose | Status |
|------|---------|--------|
| `game_state.py` | Data model: locations, GameState, constants | In repo (pre-fix version); local has cleanup |
| `rules.py` | `legal_moves()` and `apply_move()` | In repo (pre-fix version); local has home-entry fix |
| `play.py` | Console game loop | In repo, unchanged |
| `tests.py` | Rule test suite | In repo (15 tests); local has 20 tests including home-entry coverage |
| `RULES.md` | Detailed spec for AI development | Not yet in repo |
| `HOW_TO_PLAY.md` | Player-facing rules summary | Not yet in repo |
| `DEVELOPMENT_PLAN.md` | This document | Not yet in repo |
| `.gitignore` | Standard Python + Godot ignores | In repo |
