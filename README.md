# Wahoo Text Game

Console-based Python prototype of Wahoo for 4 players. The current project phase is validating the rules engine, replay support, simple computer self-play, and the first AI strategy module before porting the game to Godot 4 for Android.

## Current State

Implemented:

- Package layout under `wahoo/` with `game_state.py`, `rules.py`, `play.py`, and `ai.py`.
- 4-player Wahoo rules engine with legal move generation and move application.
- Console game loop with ASCII board rendering.
- Human pass-and-play mode.
- Per-seat player configuration in `wahoo/play.py`, with each slot set to `human` or a named AI profile.
- Computer self-play mode with setup choices: one difficulty for all seats, one profile for all seats, or per-seat mixed setup.
- Headless self-play CLI runner in `wahoo/selfplay.py` for N-game AI balance checks and seat-rotated profile benchmarking.
- Replay recording to sequential `game*.json` files and replay/continue support.
- Auto-roll toggle using `/auto`.
- AI strategy module in `wahoo/ai.py` containing:
  - `RandomPlayer`
  - `GreedyPlayer`
  - `ExpectimaxPlayer` (one-ply with reroll-aware lookahead)
  - `human_like` profile support (loaded from `wahoo/human_like_profile.json` when present)
  - 10-feature move scoring
  - 8 named greedy profiles plus `human_like`, `random`, and `expectimax` in `PROFILES`
- Test suites in `tests/test_wahoo.py` and `tests/test_ai.py`.
- AI scenario probes 1-6 in `tests/test_ai.py`:
  - win guardrail
  - center temptation
  - capture vs deploy
  - finish or fight
  - center denial
  - threat escape
- Stage 2 baseline benchmark cycle completed across seeds `20260526`-`20260530` with Stage 3 candidates selected as `sprinter`, `gambler`, and `expectimax` (see `documents/AI_BENCHMARK_RESULTS.md`).

Not implemented yet:

- Godot project files and Android build/export setup.

## Requirements

- Python 3.10+
- `pytest` for the full test suite

## Run the Game

From the project folder:

```powershell
python -m wahoo.play
```

Important: run this from the repository root (`Wahoo-app`), not from inside `wahoo/`.
If you are currently inside `wahoo/`, use:

```powershell
python play.py
```

Startup flow:

- ASCII-art intro is shown first.
- Choose one intro menu option:
  - `S` start a new game and configure each seat as human or AI
  - `C` run computer self-play and choose one of:
    - one difficulty for all seats
    - one profile for all seats
    - per-seat mixed setup
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

Human move reasoning capture:

- When a human turn has multiple legal moves and you choose manually, the game offers an optional free-text reasoning prompt.
- Press Enter to skip, or enter any note.
- The note is saved in replay history as human context and explicitly marked as non-optimal (`human_reasoning_non_optimal: true`).
- This supports future AI-behavior modeling without labeling human notes as best-play targets.

## Export Human Reasoning Data

Export recorded human reasoning notes into JSONL for downstream analysis or training prep:

```powershell
python -m wahoo.reasoning_export --input game2.json --output human_reasoning_examples.jsonl
```

You can also batch-export from multiple replays:

```powershell
python -m wahoo.reasoning_export --input-glob "game*.json" --output human_reasoning_examples.jsonl
```

Each JSONL row includes:

- source file and entry index
- player and roll
- reasoning text
- explicit non-optimal label (`human_reasoning_non_optimal: true`, `is_optimal_target: false`)
- state before/after
- legal move list
- inferred chosen move (when inferable from state transition)

## Train a Human-Like Profile

Fit weights from replay files that include human reasoning notes and `turn_detail` candidate features:

```powershell
python -m wahoo.human_profile --input wahoo/game1.json --output wahoo/human_like_profile.json
```

Batch mode:

```powershell
python -m wahoo.human_profile --input-glob "wahoo/game*.json" --output wahoo/human_like_profile.json
```

Optional tuning flags:

- `--scale 2.0` multiplies learned preference deltas before applying them to baseline weights.
- `--floor 0.0` sets the minimum allowed weight value.

Output file (`wahoo/human_like_profile.json`) contains:

- sample count used for fitting
- decision-type distribution for included turns
- per-feature average chosen-vs-alternative deltas
- final weight vector

At runtime, `wahoo/ai.py` auto-loads this file if it exists and registers `human_like` in `PROFILES`.

AI player behavior:

- New games can mix human seats with profiles from `wahoo.ai.PROFILES`.
- AI seats always auto-roll and choose moves through their configured profile.
- Computer self-play starts with auto-roll ON and now supports profile/difficulty selection before the run starts.

## Run Headless Self-Play

For AI balance checks without board rendering or prompts:

```powershell
python -m wahoo.selfplay --games 50 --seed 20260525
```

Useful options:

- `--players balanced,assassin,tortoise,random` sets Red, Green, Yellow, and Blue profiles.
- `--max-turns 20000` changes the per-game safety cap.
- `--list-profiles` prints available AI profile names.

Benchmark mode (rank profiles with seat-rotation):

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,assassin,tortoise,sprinter,expectimax --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 100 --seed 20260526
```

- `--benchmark-profiles` sets candidate profiles to rank.
- `--benchmark-opponents` sets exactly three fixed opponents.
- `--benchmark-games-per-seat` controls games per seat per candidate.

The runner reports completed/unfinished games, wins by seat/profile, average turns, average rolls, and average captures.
Benchmark mode prints a leaderboard with per-seat win breakdown for each candidate profile.

## Tune A Profile To Beat Sprinter

For automated search over GreedyPlayer weights and phase weights, use:

```powershell
python scripts/tune_profile_against_sprinter.py --generations 8 --population-size 20 --elite-count 4 --games-per-seat 15 --max-turns 20000 --search-seeds 20260601,20260602,20260603 --holdout-seeds 20260526,20260527,20260528,20260529,20260530 --checkpoint-json documents/sprinter_tuning_checkpoint.json --output-json documents/sprinter_tuning_results.json --output-md documents/sprinter_tuning_results.md
```

Primary references for this workflow:
- `documents/AI_SPRINTER_BEATING_TRAINING_PLAN.md`
- `documents/AI_TESTING_PLAN.md`
- `documents/AI_BENCHMARK_RESULTS.md`

Outputs:
- `documents/sprinter_tuning_checkpoint.json` (generation checkpoints)
- `documents/sprinter_tuning_results.json` (machine-readable best-candidate results)
- `documents/sprinter_tuning_results.md` (human-readable summary)

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

To jump straight to a specific recorded board-state index and continue from there:

```powershell
python -m wahoo.play replay game3.json 61
```

You can also pick `R` from the startup menu and then enter a filename.
In interactive replay mode, after entering a filename, you can optionally enter an index to load directly (press Enter to use the latest state).

When loading by index, you can navigate before continuing:

- `B` goes to the previous recorded entry.
- `N` goes to the next recorded entry.
- `D` toggles decision view for turn entries (board state before that turn's move, with the recorded roll loaded).
- `C` continues from the currently shown view.
- `E` exits replay.

Decision view is useful for debugging move selection bugs because continue will prompt the same player with the saved roll.

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
- If you loaded a specific index, continuation starts from that exact snapshot instead of the final entry.

## Tests

Run the full test suite with:

```powershell
python -m pytest tests/
```

Test counts change as new coverage is added. Use the command output as the source of truth for the current pass count.

You can still run the legacy rule/behavior test harness directly:

```powershell
python -m tests.test_wahoo
```

## Documentation Map

- `documents/RULES.md` — authoritative rules and implementation notes.
- `documents/HOW_TO_PLAY.md` — player-facing rules summary.
- `documents/DEVELOPMENT_PLAN.md` — phase roadmap and current project status.
- `documents/AI_PLAYER_BUILD_PLAN.md` — AI implementation plan and remaining AI work.
- `documents/AI_TESTING_PLAN.md` — step-by-step protocol for benchmarking, robustness checks, and pairwise AI profile evaluation.
- `documents/AI_SPRINTER_BEATING_TRAINING_PLAN.md` — objective function, acceptance gates, and automated tuning workflow to surpass sprinter.
- `documents/AI_Strategy_Spec.md` — strategy dimensions and scenario probe bank.
- `documents/STAT_TRACKING_PLAN.md` — planned stat tracking module and recording extensions.
- `documents/wahoo_strategy_metric_tracking_agent_spec.md` — detailed metric tracking plan for strategy analysis.
- `wahoo/reasoning_export.py` — JSONL exporter for human move reasoning notes.
- `wahoo/human_profile.py` — trainer that fits a `human_like` profile from replay reasoning data.
- `scripts/tune_profile_against_sprinter.py` — random-plus-mutation tuning harness with checkpointing and holdout evaluation.

## Notes

- Game history is recorded after each resolved roll/move.
- Replay is useful for reproducing specific board states and verifying rule behavior.
- Generated `game*.json` files and `__pycache__/` files should not be committed even if they appear in a local working archive.
