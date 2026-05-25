# Wahoo Game Project

## Project Goal

Android board game implementing Wahoo (marble race). Currently in the Python prototype phase — building and validating game logic, AI players, and stat tracking before porting to Godot 4.

## Codebase Overview

```
wahoo/
  game_state.py   — Board model: GameState, Location types, helper functions
  rules.py        — legal_moves() and apply_move() — the canonical rules engine
  play.py         — Console game loop, rendering, human/computer input
  ai.py           — AI player classes (TO BE CREATED)
  selfplay.py     — Headless N-game runner for win-rate analysis (TO BE CREATED)
  stats.py        — Per-game stat tracking and CSV export (TO BE CREATED)
tests/
  test_wahoo.py   — Existing rule and behavior test suite
  test_ai.py      — AI scenario probe suite (TO BE CREATED)
documents/
  RULES.md                    — Authoritative game rules spec. If code and spec disagree, spec wins.
  AI_PLAYER_BUILD_PLAN.md     — Full implementation spec for ai.py, selfplay.py, test_ai.py
  STAT_TRACKING_PLAN.md       — Full implementation spec for stats.py and recording extensions
  AI_Strategy_Spec.md         — Strategy dimensions, playstyle profiles, scenario probe bank
  DEVELOPMENT_PLAN.md         — Overall project roadmap
```

Run tests with: `python -m pytest tests/`
Run the game with: `python -m wahoo.play`

## Architecture Contracts — Read Before Writing Any Code

### Player interface (every AI class must implement this exactly)

```python
def choose_move(self, state: GameState, player: int, roll: int, moves: list) -> dict:
```

- `state` — current game state. **Never mutate it directly. Always call `state.clone()` first.**
- `player` — seat index 0–3
- `roll` — die value that generated the move list
- `moves` — non-empty list from `legal_moves(state, player, roll)`
- Returns one move dict from `moves`

### Move dict format (from rules.py)

```python
{
    "marble": int,            # marble id 0..3
    "dest": tuple,            # location tuple e.g. ("TRACK", 14) or ("HOME", 2)
    "kind": str,              # "exit_base" | "advance" | "enter_center" |
                              # "exit_center" | "enter_home" | "advance_home"
    "captures": tuple | None, # (player, marble_id) sent to base, or None
}
```

### Location tuple format (from game_state.py)

```python
("BASE",)       # marble in start pen
("TRACK", i)    # on loop at absolute index i (0..55)
("HOME", j)     # in home row at slot j (0..3), 0=entry, 3=deepest
("CENTER",)     # in center hole
```

### Key constants

```python
LOOP_SIZE = 56
SEGMENT_LEN = 14          # each player owns 14 squares
HOME_SLOTS = 4
MARBLES_PER_PLAYER = 4
NUM_PLAYERS = 4
base_exit(p)   = p * 14   # where player p's marbles enter the loop
home_entry(p)  = (p * 14 - 1) % 56   # square before own base-exit; forced home turn
center_exit_dest(p) = ((p-1) % 4) * 14 + 5   # where center marble lands on roll 1
```

## Implementation Plans

Two detailed specs drive all new code. **Read them before writing anything in ai.py or stats.py.**

### AI_PLAYER_BUILD_PLAN.md covers

- `RandomPlayer` — `random.choice(moves)`
- `GreedyPlayer(weights, phase_weights)` — scores moves via `compute_features()`, hard-rule win guardrail
- `compute_features(state, player, roll, move, all_moves)` — returns 10-key float dict
- `compute_exposure(state, player, loop_idx)` — capture threat helper
- `_marble_progress(state, player, marble_id)` — progress helper (0.0–1.0)
- 8 named profile weight vectors (Sprinter, Swarm, Assassin, Shortcut Gambler, Tortoise, Gatekeeper, Endgame Engineer, Balanced Pragmatist)
- `PROFILES` dict mapping name strings to pre-configured `GreedyPlayer` instances
- Phase modifiers: early/mid/late based on marbles-in-home count
- `play.py` refactor: `settings["players"]` list replaces `settings["computer_self_play"]` bool
- `selfplay.py`: `python -m wahoo.selfplay --games N --players p0 p1 p2 p3`
- 6 scenario probe tests in `tests/test_ai.py`

### STAT_TRACKING_PLAN.md covers

- Extended JSON recording: new `turn_detail` event type with full candidate move list and feature vectors
- `TurnRecord`, `PlayerGameStats`, `GameSummary` dataclasses
- `compute_turn_record()` — called in `take_turn()` after move selection, before `apply_move()`
- `compile_game_stats(recording)` — computes aggregated stats from a recording dict
- `print_game_report()` and `append_stats_csv()` — post-game output
- Per-player style vector: average feature values on discretionary turns (2+ legal moves)
- CSV schema: one row per player per game, accumulates across all games

## Critical Invariants — Enforce These in All Code

**GreedyPlayer must be fully deterministic.** Given the same state and roll, it must always return the same move. Tie-breaking resolves to the first move in the list. Do not add any randomness to GreedyPlayer.

**Win guardrail overrides everything.** Before scoring any features, `GreedyPlayer.choose_move()` must check for an immediate win and return it unconditionally. No style weight should ever prevent a winning move from being taken.

**Never mutate the input GameState.** Any code that needs to simulate a move outcome must call `state.clone()` first. `apply_move()` mutates in place.

**All 10 features must be in approximately 0.0–1.0 range.** Strict bounds are not enforced but consistent relative scaling within each feature is required. If one feature is 0–100 and another is 0–1, the profile weight dot product becomes meaningless.

**No circular imports.** `ai.py` may import from `game_state.py` and `rules.py`. `play.py` may import from `ai.py`. `ai.py` must never import from `play.py`.

**`legal_moves()` is the canonical move generator.** AI code must call it rather than re-implementing move generation.

## Build Order for AI System (Sequential — Dependencies Matter)

1. `compute_exposure()` and `_marble_progress()` helpers in `ai.py`
2. `compute_features()` — all 10 features using those helpers
3. `RandomPlayer` and `GreedyPlayer` with Balanced Pragmatist weights only
4. `tests/test_ai.py` probe 1: win guardrail — run and confirm passing
5. Probe 2: center temptation — run and confirm
6. Remaining probes 3–6
7. Remaining 7 profile weight dicts; add to `PROFILES`
8. Refactor `play.py`: replace `computer_self_play` bool with `players` list; add per-slot dispatch
9. `wahoo/selfplay.py` headless runner
10. Run 50-game self-play, verify rough win-rate balance across profiles
11. `wahoo/stats.py` with `TurnRecord`, `PlayerGameStats`, `GameSummary`
12. Hook `compute_turn_record()` into `play.py`'s `take_turn()`
13. `ExpectimaxPlayer` (stretch goal, after everything else is stable)

## The 10 Strategy Features (Summary)

| Key  | What it measures | Quick formula |
|------|-----------------|---------------|
| DEP  | Deployment / exit pressure | 1.0 if kind == "exit_base" |
| RUN  | Single-runner bias | 1.0 if moved marble is the furthest-progress marble |
| SPR  | Spread portfolio | 1.0 - RUN |
| CAP  | Capture aggression | victim's progress score (0–1), 0 if no capture |
| SAFE | Safety first | reduction in capture exposure after move, centered at 0.5 |
| CTR  | Shortcut eagerness | 1.0 if kind == "enter_center" |
| DEN  | Center denial | 1.0 if enter_center AND captures an opponent from center |
| FLOW | Flow control | reduction in own self-blocking after move, centered at 0.5 |
| HOME | Home-lane engineering | (dest_slot + 1) / 4 for HOME moves, 0 otherwise |
| FIN  | Finish-over-fight | 1.0 for home moves in finish-vs-fight states, 0 otherwise |

Full formulas and helper implementations are in `documents/AI_PLAYER_BUILD_PLAN.md` §6.

## Profile Weight Table

| Profile             | DEP | RUN | SPR | CAP | SAFE | CTR | DEN | FLOW | HOME | FIN |
|---------------------|-----|-----|-----|-----|------|-----|-----|------|------|-----|
| Sprinter            | 0.4 | 1.0 | 0.2 | 0.4 | 0.2  | 0.9 | 0.3 | 0.4  | 0.5  | 0.9 |
| Swarm               | 1.0 | 0.2 | 1.0 | 0.5 | 0.4  | 0.4 | 0.4 | 0.8  | 0.5  | 0.6 |
| Assassin            | 0.5 | 0.4 | 0.4 | 1.0 | 0.2  | 0.5 | 0.9 | 0.5  | 0.3  | 0.4 |
| Shortcut Gambler    | 0.7 | 0.8 | 0.3 | 0.6 | 0.1  | 1.0 | 0.6 | 0.2  | 0.4  | 0.5 |
| Tortoise            | 0.4 | 0.3 | 0.6 | 0.2 | 1.0  | 0.1 | 0.5 | 0.9  | 0.9  | 0.8 |
| Gatekeeper          | 0.5 | 0.3 | 0.5 | 0.7 | 0.7  | 0.4 | 1.0 | 0.8  | 0.5  | 0.6 |
| Endgame Engineer    | 0.4 | 0.4 | 0.5 | 0.2 | 0.8  | 0.2 | 0.3 | 1.0  | 1.0  | 1.0 |
| Balanced Pragmatist | 0.6 | 0.5 | 0.6 | 0.6 | 0.6  | 0.5 | 0.6 | 0.7  | 0.7  | 0.7 |

## Phase Modifiers (Additive on Top of Profile Weights)

```python
DEFAULT_PHASE_WEIGHTS = {
    "early": {"DEP": 0.30, "SPR": 0.20},           # 0 marbles in home
    "mid":   {"CAP": 0.10, "CTR": 0.10},            # 1 marble in home
    "late":  {"HOME": 0.40, "FIN": 0.50, "SAFE": 0.20},  # 2+ marbles in home
}
```
