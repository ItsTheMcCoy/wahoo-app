# Wahoo Text Game

Console-based Python prototype of Wahoo for 4 players. The current project phase is validating the rules engine, replay support, simple computer self-play, and the first AI strategy module before porting the game to Godot 4 for Android.

## Current State

Implemented:

- Package layout under `wahoo/` with `game_state.py`, `rules.py`, `play.py`, and `ai.py`.
- 4-player Wahoo rules engine with legal move generation and move application.
- Console game loop with ASCII board rendering.
- Human pass-and-play mode.
- Per-seat player configuration in `wahoo/play.py`, with each slot set to `human` or a named AI profile.
- Computer self-play mode using the `balanced` AI profile for all four seats.
- Replay recording to sequential `game*.json` files and replay/continue support.
- Auto-roll toggle using `/auto`.
- AI strategy module in `wahoo/ai.py` containing:
  - `RandomPlayer`
  - `GreedyPlayer`
  - 10-feature move scoring
  - 8 named greedy profiles plus `random` in `PROFILES`
- Test suites in `tests/test_wahoo.py` and `tests/test_ai.py`.
- AI scenario probes 1-6 in `tests/test_ai.py`:
  - win guardrail
  - center temptation
  - capture vs deploy
  - finish or fight
  - center denial
  - threat escape

Not implemented yet:

- `wahoo/selfplay.py` headless N-game runner.
- `wahoo/stats.py` stat aggregation and CSV export.
- Godot project files and Android build/export setup.

## Requirements

- Python 3.10+
- `pytest` for the full test suite

## Run the Game

From the project folder:

```powershell
python -m wahoo.play
```

Startup flow:

- ASCII-art intro is shown first.
- Choose one intro menu option:
  - `S` start a new game and configure each seat as human or AI
  - `C` run computer self-play, where all players use the `balanced` AI profile
  - `R` replay a saved game
  - `E` exit
- Type `/auto` at supported prompts to toggle auto-roll on or off.
- Each player rolls once to determine who goes first.
- Highest roll starts. Play order then continues clockwise.

Auto-roll behavior:

- When auto-roll is ON, the game rolls automatically for turns.
- If a roll produces more than one legal move, a human game still requires manual move selection.
- Manual move choices are numbered `1..N`.
- `/auto` can be used during startup, replay prompts, and turn prompts.

AI player behavior:

- New games can mix human seats with profiles from `wahoo.ai.PROFILES`.
- AI seats always auto-roll and choose moves through their configured profile.
- Computer self-play starts with auto-roll ON and maps all four seats to `balanced`.

## Replay a Saved Game

Each new game writes its own history file automatically using a simple sequential name like:

```text
game1.json
game2.json
game3.json
```

To replay a saved game directly:

```powershell
python -m wahoo.play replay game3.json
```

You can also pick `R` from the startup menu and then enter a filename.

Replay behavior:

- Each recorded board state is displayed in order.
- The recorded event summary for that state is shown below the board.
- Press Enter to step to the next recorded state.
- `/auto` can still be toggled while stepping replay states.

## Continue a Replayed Game

At the end of replay, the game prompts you to either continue or exit replay.

- Enter `C` to continue the replayed game from its last saved state.
- Enter `E` to exit replay.

If you continue:

- The loaded game state becomes the active live game.
- New moves are appended to the same history JSON file.

## Tests

Run the full test suite with:

```powershell
python -m pytest tests/
```

At the time this documentation was synchronized, the suite contained 43 passing tests.

You can still run the legacy rule/behavior test harness directly:

```powershell
python -m tests.test_wahoo
```

## Documentation Map

- `documents/RULES.md` — authoritative rules and implementation notes.
- `documents/HOW_TO_PLAY.md` — player-facing rules summary.
- `documents/DEVELOPMENT_PLAN.md` — phase roadmap and current project status.
- `documents/AI_PLAYER_BUILD_PLAN.md` — AI implementation plan and remaining AI work.
- `documents/AI_Stragegy_Spec.md` — strategy dimensions and scenario probe bank. The filename currently contains the misspelling `Stragegy`.
- `documents/STAT_TRACKING_PLAN.md` — planned stat tracking module and recording extensions.
- `documents/wahoo_strategy_metric_tracking_agent_spec.md` — detailed metric tracking plan for strategy analysis.

## Notes

- Game history is recorded after each resolved roll/move.
- Replay is useful for reproducing specific board states and verifying rule behavior.
- Generated `game*.json` files and `__pycache__/` files should not be committed even if they appear in a local working archive.
