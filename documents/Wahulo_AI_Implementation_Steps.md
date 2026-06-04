# Wahulo AI — Implementation Steps

**Companion to `Wahulo_AI_Development_Plan.md`.** That document explains *what* to build and *why*; this one is the literal *how* — ordered steps, commands, file order, and Godot 4.6.3 editor navigation. UI navigation reflects current tooling (June 2026), not stale defaults.

**Conventions**
- `$` = a shell command. `▸` = a Godot editor action. `📄` = create/edit a file.
- Anything marked **(optional)** belongs to the RL track and is only needed for the "Master" tier.
- Run everything inside the **`wahulo-ai`** fork (see Phase 0), never the production game repo.
- Authoritative game behavior lives in `RULES.md`. If a step and `RULES.md` disagree, `RULES.md` wins.

---

## Phase 0 — Environment & repo setup

### 0.1 Fork the game into a separate AI project

The fork keeps ML dependencies and the replay viewer out of the shipping game while inheriting the real board scene + rules.

**On GitHub (web):**
1. Open the production `wahulo` repository.
2. Click **Fork** (top-right) → set owner → name it **`wahulo-ai`** → **Create fork**.

**Locally:**
```bash
$ git clone https://github.com/<you>/wahulo-ai.git
$ cd wahulo-ai
$ git remote add upstream https://github.com/<you>/wahulo.git   # to pull future game updates
$ git checkout -b ai-dev
```

Keep the fork current over time:
```bash
$ git fetch upstream && git rebase upstream/main
```

### 0.2 Confirm the Godot version

1. Open the project in **Godot 4.6.3** (the production version). Editor → **Help ▸ About** shows the version.
2. **For the RL track only:** you will also need the **.NET / mono** build of Godot 4.6.3 (download the ".NET" variant from godotengine.org), because in-engine ONNX inference requires C#/.NET. The standard build is fine for everything else, including the replay viewer.

### 0.3 Python lab environment

Stable-Baselines3 requires **Python 3.10+**.

```bash
$ cd wahulo-ai
$ python -m venv .venv
$ source .venv/bin/activate        # Windows: .venv\Scripts\activate
$ python -m pip install --upgrade pip

# Core lab deps (classical AI + tuning + tests):
$ pip install numpy optuna cma pytest

# RL track (optional, add later):
$ pip install "stable-baselines3>=2.0" sb3-contrib gymnasium

# Godot <-> Python RL bridge + ONNX (optional, RL track):
$ pip install godot-rl onnx onnxruntime
```

📄 Create `lab/requirements.txt` capturing pinned versions (`pip freeze > lab/requirements.txt`) so agents and CI reproduce the environment.

📄 Scaffold the package layout from §5.4 of the plan:
```bash
$ mkdir -p lab/{sim,ai,training,benchmarks,replays,parity} viewer tests
$ touch lab/__init__.py lab/sim/__init__.py lab/ai/__init__.py
```

---

## Phase 1 — Headless Python simulator

Goal: a fast, render-free Wahulo engine that is the single source of truth for the lab.

### 1.1 Game state & constants
📄 `lab/sim/game_state.py` — implement `GameState` (dataclass), `clone()`, `player_won()`, and the board constants/formulas exactly as in plan §7.0 (`base_exit`, `home_entry`, `center_exit_dest`, `center_entry_roll`).

### 1.2 Rules engine
📄 `lab/sim/rules.py` — implement, faithful to `RULES.md`:
- `legal_moves(state, player, roll) -> list[Move]` — handles base-exit (1/6 only), advance, self-block (no land/pass own marble), capture-on-land, optional center entry (`roll == 6 - offset`), center exit (1 only), forced home diversion, no home overshoot.
- `apply_move(state, move) -> GameState` — mutates and returns; sets `captures`, updates `center_occupant`.
- `initial_game_state(seed=None)`.

> Implement `legal_moves` once, carefully, with the complexity traps from plan §13 in front of you. Everything else in the lab depends on it being correct.

### 1.3 Turn loop
📄 `lab/sim/turn_loop.py` — `play_turn(state, player, chooser, rng)` that rolls, calls the chooser, applies the move, checks `player_won()` **before** handling re-rolls, and only advances the player on a non-6. `play_game(agents, seed) -> (winner, replay_events)` runs a full game and records the replay event list (§3.x below).

### 1.4 Rules unit tests
📄 `tests/test_rules.py` — assert each bullet in plan §9.1 (base-exit gating, blocking, capture-on-land-only, forced diversion, no overshoot, center optional/exit-on-1, 6-with-no-move still re-rolls, immediate win). Run:
```bash
$ pytest tests/test_rules.py -q
```

---

## Phase 2 — Rules parity (Python ↔ GDScript)

Goal: prove the headless sim matches the real game, so training transfers.

### 2.1 Trace format
📄 Define a JSON trace: `{seed, initial_state, events:[{player, roll, move}], final_states}`.

### 2.2 Headless Godot trace generator
▸ In `wahulo-ai`, add a Godot **headless** entry script that, given a seed, drives the GDScript rules through the same roll sequence and dumps the resulting legal-move sets + states to JSON.
```bash
# Godot 4.6.3 headless run:
$ godot --headless --path . --script res://tools/parity_dump.gd -- --seed 12345 --out parity/gd_12345.json
```

### 2.3 Comparison
📄 `lab/parity/test_parity.py` — for a batch of seeds, generate the Python trace, load the GDScript trace, and assert identical legal-move sets and resulting states at every step.
```bash
$ pytest lab/parity/test_parity.py -q
```
**Gate:** do not proceed past Phase 2 until parity is green. A divergence here invalidates every later metric.

---

## Phase 3 — Random agent, replay format & tournament harness

### 3.1 Strategy interface + random
📄 `lab/ai/base_strategy.py` — `Strategy` with `choose_move(state, player, roll, moves) -> Move`.
📄 `lab/ai/random_strategy.py` — `RandomStrategy` returning `random.choice(moves)`.

**Smoke test:**
```bash
$ python -m lab.benchmarks.run_tournament --agents random,random,random,random --games 10000 --seed 1
# Expect: 10,000 completed games, zero exceptions, zero illegal moves.
```

### 3.2 Replay (de)serialization
📄 `lab/sim/replay.py` — `write_replay(path, seed, lineup, events)` and a loader. Replays are what the Godot viewer consumes (Phase 6).

### 3.3 Tournament harness (with rigor)
📄 `lab/benchmarks/run_tournament.py` — all-pairs / round-robin with:
- **Seat rotation** (rotate each agent through all 4 seats; average) — neutralizes first-mover advantage.
- **Seeded** RNG; store seed + agent versions + commit + `RULES.md` version with results.
- **Wilson 95% CI** on each win-rate (plan §9.3); print CI alongside the rate.
📄 `lab/benchmarks/analyze_results.py` — summary table + significance flags.

```bash
$ python -m lab.benchmarks.run_tournament --agents random,greedy --games 4000 --rotate-seats --seed 7
```

---

## Phase 4 — Greedy heuristic (Easy/Medium tier)

### 4.1 Features & evaluation
📄 `lab/ai/features.py` — progress (use `marble_progress`), home_count, home_depth_total, base_count, track_count, center_own/opponent, capture_available, **corrected** `capture_exposure` (plan §7.1 — per-opponent survival product, via `legal_moves`), self_block_count.
📄 `lab/ai/evaluation.py` — `evaluate_state(state, ai_player, w)` subtracting the **max** (not average) opponent score (plan §7.2).

### 4.2 Greedy strategy
📄 `lab/ai/heuristic_strategy.py` — `score_move` + `choose_move_greedy` from plan §7.1; seed weights from Appendix A.

### 4.3 Validate
```bash
$ python -m lab.benchmarks.run_tournament --agents greedy,random,random,random --games 4000 --rotate-seats
# Gate: greedy beats random by a CI-clear margin.
```
📄 `tests/test_ai_heuristic.py` — always-take-win, forced-capture, never-illegal-center (plan §9.2).

---

## Phase 5 — Tune the heuristic (Medium → Hard)

📄 `lab/training/tune_weights.py`:
- Objective: win-rate of a candidate weight vector vs a **fixed panel** (`random + current-best + (later) expectimax`) over N seeded, seat-rotated games.
- Optimizer: **Optuna** (TPE) or **CMA-ES** over the ~10 weights.

```bash
$ python -m lab.training.tune_weights --trials 200 --games-per-trial 2000 --optimizer optuna
# Optuna dashboard (optional):
$ optuna-dashboard sqlite:///lab/training/wahulo.db
```
Persist the best weights as `lab/ai/weights_hard.json`. Regression gate before adopting: new weights win **≥55%** vs previous best over a seat-rotated ≥1000-game match (plan §9.4).

---

## Phase 6 — Godot ReplayViewer (watch lab games on the real board)

Goal: watch any lab game (self-play, benchmark, or a chosen matchup) inside the actual game. Standard Godot build is sufficient — no .NET needed here.

### 6.1 Scene
▸ **Scene ▸ New Scene** → add a root `Node2D` (or reuse the existing board scene as an instanced child so rendering matches the real game). Save as `viewer/replay_viewer.tscn`.
▸ Add child nodes: the **board scene instance**, a `Timer` (tick cadence), a `Label`/`Control` overlay (seat → tier, current roll, decision score), and playback buttons (`Button` nodes: Step, Play, 2×, 10×).

### 6.2 Script
📄 `viewer/replay_viewer.gd`:
- On ready, load a replay JSON (from `lab/replays/`) via `FileAccess`.
- Reconstruct each event and **animate** marble moves on the board using `Tween`/`AnimationPlayer` so it reads like real play.
- Drive cadence from the `Timer`; wire the buttons to step/scale speed.
- Show the overlay (which agent controls each seat, the roll, optional eval score).

### 6.3 Run
▸ Set `replay_viewer.tscn` as the scene and press **▶ Play Scene (F6)**. Point it at a replay file produced by:
```bash
$ python -m lab.benchmarks.run_tournament --agents greedy,greedy,random,random --games 1 --save-replay lab/replays/demo.json
```
You can now watch any lab game on the real board at adjustable speed.

---

## Phase 7 — Expectimax (Hard tier)

📄 `lab/ai/expectimax_strategy.py` — implement plan §7.2:
- **Paranoid** opponent model (opponents minimize your eval).
- d6 chance node (avg over 1..6); **bounded** re-roll recursion via `MAX_REROLL_DEPTH`; same player continues on a 6; check `player_won()` before re-roll.
- Search limits: `max_depth`, `max_reroll_chain`, `time_budget_ms`, optional transposition cache.

```bash
$ python -m lab.benchmarks.run_tournament --agents expectimax,hard_heuristic,random,random --games 4000 --rotate-seats
# Gate: expectimax matches/beats the tuned heuristic within the time budget.
```

---

## Phase 8 — MCTS (Expert tier)

📄 `lab/ai/mcts_strategy.py` — UCB1 selection, expansion with a sampled next roll (**same player on a 6**), heuristic-guided rollout to terminal or `ROLLOUT_CAP`, win/loss backprop per node perspective, pick most-visited child (plan §7.3). Budget-bind `MCTS_ITERS` to the per-move time budget (plan §9.5); profile on target hardware.

```bash
$ python -m lab.benchmarks.run_tournament --agents mcts,expectimax,hard_heuristic,random --games 2000 --rotate-seats
```

---

## Phase 9 — Port the shipped tiers to GDScript

The Python versions stay as reference/lab; the *game* runs cheap GDScript.

📄 In `game/ai/`: `strategy.gd` (interface), `heuristic_strategy.gd`, `expectimax_strategy.gd` (and `mcts_strategy.gd` if Expert ships). Mirror the tuned weights (`weights_hard.json`).
▸ Wire each difficulty in the game's settings UI to the matching GDScript strategy per AI seat. For smooth in-tier difficulty, implement the blend from plan §8 (random with probability `1 - skill`) or scale MCTS iterations.

**Parity test the port:** feed identical states to the Python reference and the GDScript port; assert identical chosen moves (deterministic strategies) or identical scores. Add to CI.

---

## Phase 10 — Reinforcement learning (optional "Master" tier)

Only if Phases 4–8 plateau below the strength you want, or you want emergent strategy. All training is offline in the headless sim; Godot is used only to **watch/run** the result.

### 10.1 Install the bridge & plugin (current navigation)
```bash
$ pip install godot-rl onnx onnxruntime          # already added in 0.3 if RL planned
```
▸ Install the Godot RL Agents **plugin**: open the editor → top-center **AssetLib** tab → search **"rl"** → install **Godot RL Agents** → **Project ▸ Project Settings ▸ Plugins** → enable it. (Alternatively clone `edbeeching/godot_rl_agents_plugin` into `addons/`.)
- For **in-engine ONNX inference** you must use the **.NET/mono** Godot build, and the plugin's `.csproj`/`.sln` must match your project.

### 10.2 Gymnasium env + action masking
📄 `lab/training/env.py` — `WahuloEnv(gym.Env)` (plan §7.4): learner is player 0; opponents auto-play from a pool; `action_masks()` returns the legal-move mask; `_observe()` returns the one-hot encoding (~1001 floats).
📄 `lab/training/rl_train.py`:
```python
from sb3_contrib import MaskablePPO
from sb3_contrib.common.wrappers import ActionMasker
env = ActionMasker(WahuloEnv(), lambda e: e.action_masks())
model = MaskablePPO("MlpPolicy", env, verbose=1)
model.learn(total_timesteps=2_000_000)
model.save("lab/training/wahulo_ppo.zip")
```
- Start **sparse** reward (+1/−1). Add shaping only if convergence stalls (audit for capture-chasing).
- Maintain a self-play **opponent pool** (snapshot every K updates; cap ~20; sample each episode).
- Evaluate vs the heuristic/expectimax panel every M updates; stop when win-rate vs heuristic ≳90% and stable.

### 10.3 (Alternative) live in-editor training via the bridge
To watch RL training live in Godot instead of training purely headless: build the env as a Godot scene driven by the plugin's **Sync** node, then:
```bash
$ python lab/training/sb3_godot_train.py --viz          # --viz shows the running game
```
Use this only if you want live training visuals; the headless-sim + replay path is lower-risk for a turn-based game.

### 10.4 Export to ONNX & run in-engine (watch / ship the learned agent)
```bash
$ python lab/training/sb3_godot_train.py --timesteps=2_000_000 \
      --onnx_export_path=game/ai/wahulo_model.onnx --save_model_path=wahulo_ppo.zip
```
▸ In the **.NET/mono** Godot editor, open `train.tscn` (or your inference scene) → select the **`Sync`** node → in the Inspector set **Control Mode → "Onnx Inference"** → set **Onnx Model Path** to `wahulo_model.onnx`.
▸ Press **▶** — the agent now runs entirely in-engine, no Python. Ship `wahulo_model.onnx` as a game asset for the Master tier and watch it play natively.

---

## Quick reference — phase gates

| Phase | Done when… |
|---|---|
| 0 | Fork cloned; venv with pinned deps; Godot 4.6.3 (+ .NET build if RL) confirmed |
| 1 | Rules unit tests pass |
| 2 | Python↔GDScript parity green |
| 3 | 10k random games clean; tournament harness gives seat-rotated win-rates + CIs |
| 4 | Greedy beats random (CI-clear) |
| 5 | Tuned weights beat previous best ≥55% (seat-rotated, ≥1000 games) |
| 6 | Any lab game watchable in the Godot ReplayViewer |
| 7 | Expectimax ≥ tuned heuristic within time budget |
| 8 | MCTS ≥ expectimax under equal budget (or dropped) |
| 9 | GDScript port matches Python reference; wired to difficulty UI |
| 10 | (Optional) MaskablePPO beats heuristic ≳90%; ONNX runs in-engine |

---

## Commands cheat-sheet

```bash
# Tests
pytest tests/ -q
pytest lab/parity/test_parity.py -q

# Tournament (seat-rotated, seeded, with CIs)
python -m lab.benchmarks.run_tournament --agents A,B,C,D --games 4000 --rotate-seats --seed 7

# Save a watchable replay
python -m lab.benchmarks.run_tournament --agents expert,expert,hard,hard --games 1 --save-replay lab/replays/match.json

# Tune heuristic weights
python -m lab.training.tune_weights --trials 200 --games-per-trial 2000 --optimizer optuna

# (RL) train + export ONNX
python lab/training/sb3_godot_train.py --timesteps=2_000_000 --onnx_export_path=game/ai/wahulo_model.onnx

# Godot 4.6.3 headless parity dump
godot --headless --path . --script res://tools/parity_dump.gd -- --seed 12345 --out parity/gd_12345.json
```

---

*Sources for current tooling/UI: Godot 4.6.3 release (godotengine.org); Godot RL Agents README & ONNX/Sync-node docs (github.com/edbeeching/godot_rl_agents); sb3-contrib MaskablePPO docs. See `Wahulo_AI_Development_Plan.md` Appendix B.*
