# Wahulo AI Development Plan

**A combined concepts-and-handoff document for building a strong AI opponent for Wahulo (a virtual Wahoo-style race game built in Godot 4.6.3).**

| | |
|---|---|
| **Owner** | McCoy |
| **Engine** | Godot 4.6.3 (latest stable, released 21 May 2026) |
| **AI lab stack** | Python 3.10+, headless simulator, offline training/benchmarking |
| **Document version** | 1.0 — June 2026 |
| **Source synthesis** | Merged from two independent AI responses (ChatGPT + Cowork/Claude) to the same brief, reconciled, corrected, and extended with current tooling. See Appendix C. |

---

## 0. How to read this document

This document serves **two audiences at once**:

- **For McCoy (owner):** §1–§6 explain, in plain language, every concept involved in building a game AI — what the options are, why one is recommended, and what each will and won't buy you. You do not need to read the code blocks to follow the decisions.
- **For implementing AI agents / developers:** §5–§15 plus the appendices are a complete technical hand-off. Every rule, formula, API contract, algorithm, and constraint needed to build the system is reproduced here, so no other document is strictly required. Where game behavior is ambiguous, **`RULES.md` is the source of truth.**

A companion file, **`Wahulo_AI_Implementation_Steps.md`**, gives the literal step-by-step build sequence (commands, Godot editor navigation, file-by-file order). This plan is the *what and why*; the steps file is the *how*.

---

## 1. Executive summary & recommended path

Wahulo is a **turn-based, stochastic, perfect-information, 4-player race game**. Each player has 4 marbles, movement comes from a single d6, and the AI's only decision is *which legal move to make after the die is rolled*. That shape has a decisive consequence:

> **You do not need machine learning to get a strong opponent.** The fastest path to an AI that beats experienced human players is a reliable simulator plus a tuned hand-built evaluation and shallow search. Reinforcement learning is a worthwhile *later* experiment, not the starting point.

**The recommended ladder** — each rung is independently shippable and is reused by the next:

```
Phase 0 ── Headless Python simulator + rules-parity tests   (the lab)
Phase 1 ── Random agent            (rules stress-test, Easy tier baseline)
Phase 2 ── Greedy heuristic        (Easy/Medium tiers)
Phase 3 ── Tuned heuristic         (Medium/Hard tiers; weights tuned by simulation)
Phase 4 ── One-ply Expectimax      (Hard tier; reasons about the die + opponents)
Phase 5 ── MCTS                    (Expert tier; strong ceiling without ML)
Phase 6 ── RL self-play (optional) (only if Phases 2–5 plateau too weak)
```

**Recommended near-term target: tuned heuristic + one-ply expectimax.** This is very likely enough to match or beat experienced casual players, runs in well under a frame's time budget, and is trivial to reimplement in GDScript to ship inside the game. Treat MCTS as the "Expert" difficulty and RL as a research track.

**Architecture in one sentence:** build and train everything in a fast **headless Python "lab"**, then ship the finished AI into the Godot game two ways — classical tiers reimplemented in **GDScript**, and (if you pursue RL) the trained network exported to **ONNX** and run in-engine — while a **deterministic replay system** lets you watch any lab game play out on the real Godot board (§5.5).

---

## 2. The game model the AI must understand

This is the condensed, implementation-relevant model. It is **not** a replacement for `RULES.md`; if anything here conflicts with `RULES.md`, the latter wins.

| Concept | Implementation meaning |
|---|---|
| Players | 4, indexed `0..3`. Turn order is strictly `0 → 1 → 2 → 3 → 0 …` |
| Marbles | 4 per player (16 total) |
| Track | Closed loop of **56** squares, indices `0..55` |
| Player segment | Each player owns a **14**-square segment of the loop |
| Die | One fair d6. A roll of **6 grants another roll to the same player** |
| Must-move | If at least one legal move exists, the player **must** make one (no voluntary pass) |
| Win | A player wins **immediately** when all 4 of their marbles are in their home row |

### 2.1 Marble locations

| Location | Meaning |
|---|---|
| `BASE` | Not yet on the track |
| `TRACK(i)` | On loop square `i`, `i ∈ 0..55` |
| `HOME(j)` | In own home row, slot `j`, `j ∈ 0..3` (`0` = entry, `3` = deepest) |
| `CENTER` | In the central shortcut hole (holds only one marble at a time) |

### 2.2 Board formulas (verified consistent across both source documents)

```python
base_exit(p)        = p * 14                      # where player p enters the loop
home_entry(p)       = (p * 14 - 2) % 56           # square that triggers diversion into home
center_exit_dest(p) = ((p - 1) % 4) * 14 + 5      # where p lands after exiting center on a 1
center_entry_roll(k)= 6 - k                        # marble at offset k (0..5) from base_exit enters center on this roll
```

Resolved values (sanity table — both sources agree):

| Player `p` | `base_exit` | `home_entry` | `center_exit_dest` |
|---|---|---|---|
| 0 | 0 | 54 | 47 |
| 1 | 14 | 12 | 5 |
| 2 | 28 | 26 | 19 |
| 3 | 42 | 40 | 33 |

### 2.3 Move kinds

| Kind | When used |
|---|---|
| `exit_base` | Marble leaves `BASE` for `base_exit` (only on a roll of **1 or 6**) |
| `advance` | Marble moves forward along the loop |
| `enter_center` | Marble takes the optional center shortcut |
| `exit_center` | Marble leaves center (only on a roll of **1**) to `center_exit_dest` |
| `enter_home` | Marble crosses `home_entry` and diverts into `HOME(0)` or deeper |
| `advance_home` | Marble already in home moves to a deeper slot |

### 2.4 Rules that most affect AI quality

- A marble leaves base only on a **1 or 6**.
- A player **cannot land on or pass over their own marble** (self-blocking).
- Landing on an opponent **captures** it (sends it to base). **Passing over** does not capture.
- Home movement needs **exact** rolls and **cannot overshoot** `HOME(3)`.
- Home marbles are **safe** and immovable.
- The center shortcut is **optional**, holds **one** marble, can capture an opponent already there on entry, and a center marble exits **only on a 1**.
- A roll of **6 grants another roll even if no legal move was available**.
- A **winning move ends the game immediately**, overriding any pending re-roll.

The subtle interactions of these (forced home diversion, center blocking, capture-on-entry) are exactly why the AI must **never** generate moves itself — see §4.1 and §13.

---

## 3. Core AI concepts — plain language (for the owner)

Skip to §4 if these are already familiar.

- **Game state** — a complete snapshot: where all 16 marbles are, whose turn it is, who occupies the center. The AI decides based on the current state.
- **Policy** — the AI's decision rule: a function from state to chosen move. "Random policy" picks any legal move; a "perfect policy" always picks the best one.
- **Heuristic / evaluation function** — a hand-built scorer that estimates how good a position is *without* simulating to the end of the game. Fast, intuitive, imperfect. Better evaluation → stronger AI.
- **Search tree** — thinking ahead: "if I do X, the die could land on 1–6, and then an opponent could do Y or Z…". Branching possibilities form a tree. Searching deeper plays stronger but costs more time.
- **Expectimax** — a search method for games with dice. At *decision* nodes it takes the best move; at *chance* nodes (the die) it **averages** the six outcomes weighted by probability. ("Expected value" + "maximize".)
- **MCTS (Monte Carlo Tree Search)** — instead of evaluating every line, it plays thousands of fast simulated games ("rollouts") from the current position and steers toward moves that won most often. The method behind AlphaGo.
- **Reinforcement learning (RL)** — an agent learns by trial and error: it plays, gets rewards (win good, loss bad), and adjusts. With **self-play**, it plays copies of itself and bootstraps upward. How AlphaZero works.
- **Self-play & overfitting** — self-play needs no human game records, but if the agent only ever plays its newest self it can **overfit** (learn to beat one specific style and nothing else). Fixed by training against a *pool* of past versions.
- **Action masking** — forcing a learned model to only choose among legal moves by zeroing out illegal ones. Essential here because Wahulo has hard legality rules.

---

## 4. Problem definition & objective

The AI receives the current state, the acting player, the die roll, and the **list of legal moves** (produced by the rules engine). It returns one of those moves. The universal contract:

```python
def choose_move(state: GameState, player: int, roll: int, moves: list[Move]) -> Move:
    """
    Preconditions:  `moves` is non-empty (the caller only calls choose_move when a move exists).
    Postcondition:  the returned move is an element of `moves`.
    Budget:         must return within the per-move time budget (see §9.5).
    """
```

Every difficulty tier is just a different implementation of this one function.

### 4.1 The real objective

The objective is **not** maximum immediate progress or captures. It is **maximizing the probability of eventually winning**. Progress, captures, safety, center usage, and home timing matter *only insofar as they raise win probability*.

> **Common failure mode:** a weak AI overvalues captures and the center shortcut because they "feel" strong. A strong AI sometimes declines a capture, avoids center risk, or moves a *less* advanced marble to avoid self-blocking later. The benchmark harness (§9), not intuition, decides what is actually good.

### 4.2 Why Wahulo is tractable

- **Perfect information** — no hidden state; the AI can plan with full knowledge.
- **Small action space** — usually ~2–4 legal moves (vs ~30 in chess, ~250 in Go). Tree search is cheap.
- **Bounded randomness** — exactly one d6, six equally-likely outcomes; trivially modeled.
- **Moderate state space** — each marble in ~63 locations; large but approximable.
- **Unlimited self-play data** — a simulator generates as many games as you want.

### 4.3 What makes it harder than a toy

- **4 players, not 2.** Classic minimax assumes two opposed players. With four, "the opponent" is three independent agents; eliminating one can help another. This needs a deliberate modeling choice (§7.2).
- **Variable turn length.** A 6 re-rolls, so one "turn" can be several sequential decisions by the same player. Search and simulation must handle this without advancing the turn (§13.1).
- **Luck sensitivity.** A player one move from winning can stall on unlucky rolls. The AI should be robust, not just expected-value-optimal.

---

## 5. System architecture for a Godot 4.6.3 game

This is the section that adapts the generic advice in both source documents to **your** situation: a shipping game written in Godot 4.6.3, a desire to **watch AI games inside that game**, and a plan to **fork into a separate project**.

### 5.1 The two-world design

Keep two clearly separated worlds:

1. **The Godot product world (GDScript).** The actual game. Owns the canonical rules, the board rendering, the UI, and — eventually — the *shipped* AI that players face.
2. **The Python lab world.** A headless, fast, dependency-heavy environment for *developing* and *training* the AI: simulator, strategies, tournaments, weight tuning, and (optionally) RL. None of this ships to players.

Why split them: GDScript is fine for running a finished, cheap AI at runtime, but it is the wrong place to run **millions** of simulated games or a multi-hour PyTorch training job. Python has the ecosystem (NumPy, PyTorch, Stable-Baselines3, Optuna) and runs headless simulations orders of magnitude faster than driving the full Godot engine. **Train in Python; ship in Godot.**

### 5.2 The headless Python simulator and rules parity

The lab's foundation is a **headless reimplementation of the Wahulo rules in pure Python** — no rendering, no Godot. This is what makes "Python engine + offline training" viable.

The danger of two rule implementations (GDScript and Python) is **drift**: if they disagree, your AI is trained against a game that isn't the real game. Mitigate with a **rules-parity harness**:

- Define a small, canonical **trace format**: an initial state + RNG seed + the resulting sequence of (roll, chosen move) pairs.
- Generate N random traces in Python; replay the same seeds/states through the GDScript engine (via a headless Godot run or an exported test scene) and assert that legal-move sets and resulting states match exactly.
- Run parity tests in CI for both projects. If they ever diverge, fix before any further AI work — a wrong simulator makes every downstream metric meaningless.

`RULES.md` is the contract both implementations conform to.

### 5.3 Repo / fork strategy (your "separate project" instinct is correct)

Forking the game into a dedicated AI-development project is the right call, for three reasons: it keeps heavy ML dependencies out of the shipping game, lets the AI iterate on its own cadence, and gives you a place to add a **replay viewer scene** without touching production code.

Recommended structure:

- **`wahulo`** — the existing production game repo (Godot 4.6.3). Untouched except to *receive* finished AI at the end (a GDScript strategy file and/or an ONNX model).
- **`wahulo-ai`** — a **fork** of `wahulo`. This is where AI development happens. Because it starts as a fork, it already contains the real board scene and rules — so the replay viewer (§5.5) literally *is* the game, satisfying "watch the AI within the current game." Add to it:
  - a `/lab` Python package (simulator, strategies, training, benchmarks),
  - a Godot **`ReplayViewer`** scene that loads lab-produced replay files and animates them on the real board,
  - (optional) the Godot RL Agents plugin for live RL training/visualization.

Keep `wahulo-ai` periodically rebased on `wahulo` so the board/rules stay current. Port finished AI back to `wahulo` via a small, reviewed PR (GDScript strategy + optional ONNX asset) — *not* by merging the whole fork.

> If you would rather not fork, the alternative is a sibling repo plus a git submodule that pulls in the game's board scene. Forking is simpler and is recommended.

### 5.4 Project layout (`wahulo-ai`)

```
wahulo-ai/
├─ game/                        # inherited from the fork: real Godot game
│  ├─ ...                       # existing scenes, rules (GDScript), UI
│  └─ ai/                       # SHIPPED ai (GDScript) — final port target
│     ├─ strategy.gd            #   base interface
│     ├─ heuristic_strategy.gd
│     ├─ expectimax_strategy.gd
│     └─ onnx_policy.gd         #   loads exported RL model (optional)
├─ viewer/
│  └─ replay_viewer.tscn/.gd    # loads a replay file, plays it on the board
├─ lab/                         # Python lab (NOT shipped)
│  ├─ sim/
│  │  ├─ game_state.py          # GameState dataclass + clone()
│  │  ├─ rules.py               # legal_moves(), apply_move(), player_won()
│  │  └─ turn_loop.py           # full-turn simulation incl. re-roll chains
│  ├─ ai/
│  │  ├─ base_strategy.py
│  │  ├─ random_strategy.py
│  │  ├─ features.py
│  │  ├─ evaluation.py
│  │  ├─ heuristic_strategy.py
│  │  ├─ expectimax_strategy.py
│  │  └─ mcts_strategy.py
│  ├─ training/
│  │  ├─ tune_weights.py        # Optuna / CMA-ES weight search
│  │  ├─ env.py                 # Gymnasium env (RL, optional)
│  │  └─ rl_train.py            # MaskablePPO self-play (RL, optional)
│  ├─ benchmarks/
│  │  ├─ run_tournament.py
│  │  └─ analyze_results.py
│  ├─ replays/                  # JSON replay files consumed by viewer/
│  └─ parity/
│     └─ test_parity.py         # GDScript-vs-Python rules parity
└─ tests/                       # pytest: rules, features, each strategy
```

### 5.5 Watching AI games inside Godot — two mechanisms

You asked specifically to watch AI training/lab games play out inside the actual game. There are two complementary mechanisms; **use the replay system as the primary one.**

**(A) Deterministic replay (recommended primary).**
Because Wahulo is fully determined by an RNG seed plus the sequence of chosen moves, every lab game — a self-play game, a benchmark game, a specific matchup — can be serialized as a compact **replay file** (JSON: seed, agent lineup, and the ordered list of `(player, roll, move)` events). The Godot `ReplayViewer` scene loads a replay and animates it on the real board at an adjustable speed (step, 1×, 10×, fast-forward), with an overlay showing which agent/tier controls each seat and, optionally, the evaluation score behind each decision. Benefits: zero coupling between the trainer and the engine, perfectly reproducible, works for *every* approach (heuristic through RL), and trivial to share ("here's the game where Expert beat me"). This is the cleanest way to satisfy "watch the AI inside the game."

**(B) Live in-engine inference via Godot RL Agents (for the RL track).**
The Godot RL Agents framework (`pip install godot-rl`; plugin via the editor **AssetLib**, search "rl") bridges a running Godot game to a Python RL trainer over TCP, and supports **in-editor interactive training** so you can watch an agent act live while it trains. After training, it can **export the policy to ONNX** and run it **in-engine** with no Python at all: in the **.NET / mono** Godot editor, select the **`Sync` node**, set **control mode → "Onnx Inference"**, and point **Onnx Model Path** at your `model.onnx`. This is the path for (a) watching live RL training and (b) shipping a learned agent that runs natively in Godot. Caveats: it targets Godot 4.x — **verify against 4.6.3 on a throwaway branch first** (the plugin's `.csproj`/`.sln` must match your project), in-engine ONNX inference requires the **.NET/mono** build of the editor, and the framework is designed for real-time agents, so a turn-based board game needs discrete actions + action masking rather than its default continuous-control assumptions.

**Decision rule:** use **(A) replay** for all classical tiers and for routine "watch a game" needs; add **(B)** only when/if you pursue RL and want either live training visuals or a native ONNX opponent in the shipped game.

### 5.6 Shipping the finished AI back into the game

- **Classical tiers (heuristic, expectimax, MCTS):** reimplement the *final, tuned* strategy in **GDScript** inside `game/ai/`. These are cheap (microseconds to a few ms) and have no runtime dependency. The Python versions remain the reference and the tuning ground; keep a parity test so the GDScript port matches.
- **RL tier (if pursued):** do **not** port a neural net to GDScript by hand. Export to **ONNX** and run it in-engine (Godot RL Agents Sync node on .NET/mono, or a standalone ONNX-runtime addon). Ship the `.onnx` as a game asset.
- **Difficulty selection:** the game wires a chosen strategy to each AI seat (§8).

---

## 6. The four viable approaches (the ladder)

Each approach is a component of the next, so build them in order. Do **not** skip Phase 1 (Random): a random agent that plays thousands of legal games without error is your proof the rules engine is correct.

| # | Approach | Idea | Effort | Strength | Tier |
|---|---|---|---|---|---|
| 1 | **Greedy heuristic** | Score each legal move with a hand-built formula; pick the best. No lookahead. | Low | Beats casual players | Easy/Medium |
| 2 | **One-ply expectimax** | For each move, average the heuristic over the next die roll(s)/opponent reply. | Medium | Noticeably stronger; weighs exposure | Hard |
| 3 | **MCTS** | Thousands of simulated games steer toward winning moves. | Med-high | Strongest without ML | Expert |
| 4 | **RL self-play** | Train a network to predict winning moves via self-play. | High | Unknown ceiling; can find non-obvious play | "Master" (optional) |

When each is "good enough": the heuristic backs the Easy/Medium tiers *and* serves as MCTS rollout policy and the RL baseline; expectimax covers Hard; MCTS is a strong shipped ceiling; RL is justified only if 1–3 plateau below the strength you want, or you specifically want emergent strategy.

---

## 7. Approach specifications (full, corrected code)

The code below is the merged, corrected reference. Two corrections were applied relative to the source documents, flagged inline: **bounded re-roll recursion** and a **corrected capture-exposure estimate**. Treat all weights/constants as tunable starting points.

### 7.0 Shared state, move, and progress primitives

```python
from dataclasses import dataclass, field
from typing import Optional, Tuple

# Location is a tagged tuple: ("BASE",) | ("TRACK", i) | ("HOME", j) | ("CENTER",)
Location = Tuple

NUM_PLAYERS = 4
NUM_MARBLES = 4
TRACK_LENGTH = 56
SEGMENT_LENGTH = 14

@dataclass
class GameState:
    marbles: list[list[Location]]                 # marbles[player][marble_id]
    current_player: int                            # 0..3
    center_occupant: Optional[Tuple[int, int]]     # (player, marble_id) or None

    def clone(self) -> "GameState":
        return GameState(
            marbles=[list(p) for p in self.marbles],
            current_player=self.current_player,
            center_occupant=self.center_occupant,
        )

    def player_won(self, player: int) -> bool:
        return all(loc[0] == "HOME" for loc in self.marbles[player])

# Move = {"marble": int, "dest": Location, "kind": str, "captures": (player, marble_id) | None}
Move = dict

def base_exit(p: int) -> int:        return p * 14
def home_entry(p: int) -> int:       return (p * 14 - 2) % TRACK_LENGTH
def center_exit_dest(p: int) -> int: return ((p - 1) % 4) * 14 + 5
def center_entry_roll(offset: int) -> int: return 6 - offset   # offset 0..5

def marble_progress(loc: Location, player: int) -> float:
    """Normalized 0.0 (BASE) .. 1.0 (HOME(3)). Approximate; tune the constants."""
    if loc[0] == "BASE":   return 0.0
    if loc[0] == "CENTER": return 50 / 60.0           # shortcut ~ deep progress, but risky
    if loc[0] == "HOME":   return (56 + loc[1] + 1) / 60.0
    if loc[0] == "TRACK":
        dist = (loc[1] - base_exit(player)) % TRACK_LENGTH
        return dist / 60.0
    return 0.0
```

**Required from the rules engine — never reimplemented in the AI layer:**

```python
def legal_moves(state: GameState, player: int, roll: int) -> list[Move]: ...   # [] = no legal move
def apply_move(state: GameState, move: Move) -> GameState: ...                  # mutates & returns state
```

### 7.1 Approach 1 — Greedy heuristic

```python
def score_move(state: GameState, player: int, move: Move, w: dict) -> float:
    nxt = apply_move(state.clone(), move)
    if nxt.player_won(player):
        return float("inf")                          # always take a win

    score = 0.0
    if move["captures"] is not None:
        score += w["capture"]
    if move["kind"] in ("enter_home", "advance_home"):
        score += w["enter_home"]
        if move["dest"][0] == "HOME":
            score += move["dest"][1] * w["home_depth"]
    if move["kind"] == "exit_base":
        score += w["exit_base"]
    if move["kind"] == "enter_center":
        score += w["center_entry"]
    if move["kind"] == "exit_center":
        score += w["exit_center"]

    score += marble_progress(move["dest"], player) * w["progress"]
    score -= capture_exposure(nxt, player, move["marble"]) * w["exposure"]
    return score

def choose_move_greedy(state, player, roll, moves, w):
    return max(moves, key=lambda m: score_move(state, player, m, w))
```

**Corrected capture-exposure.** The source versions summed "capturing rolls" across all opponents and all rolls, which double-counts (each opponent rolls **once** next turn, and you face one roll per opponent, not 72 independent chances). This estimates, per opponent, the fraction of their six rolls that yield *any* capturing move against us, then combines:

```python
def capture_exposure(state: GameState, player: int, marble_id: int) -> float:
    """P(this marble is captured on the immediate next go-round), approx in [0,1].
    Uses the rules engine so blocking/home-diversion/center cases are correct."""
    our_loc = state.marbles[player][marble_id]
    if our_loc[0] != "TRACK":
        return 0.0                                   # BASE/HOME safe; CENTER handled separately

    survive = 1.0
    for opp in range(NUM_PLAYERS):
        if opp == player:
            continue
        capturing_rolls = 0
        for roll in range(1, 7):
            for m in legal_moves(state, opp, roll):
                if m["captures"] == (player, marble_id):
                    capturing_rolls += 1
                    break                            # this roll already captures us
        p_capture_this_opp = capturing_rolls / 6.0   # independent opponents (approx)
        survive *= (1.0 - p_capture_this_opp)
    return 1.0 - survive
```

**Weight-tuning guide** (defaults in Appendix A):

| Weight | Tune up if… | Tune down if… |
|---|---|---|
| `capture` | AI ignores easy setbacks | AI chases captures recklessly |
| `enter_home` | AI dawdles near home | AI rushes one marble home, neglects the rest |
| `exit_base` | AI hoards marbles in base | AI floods the board and self-blocks |
| `center_entry` | AI never takes the shortcut | AI takes it into obvious danger |
| `progress` | AI is too passive | AI races forward into exposure |
| `exposure` | AI is reckless | AI is paralyzed / too timid |

### 7.2 Approach 2 — One-ply expectimax (with the 4-player and re-roll fixes)

**4-player model — recommend Paranoid.** Treat the three opponents as one adversary minimizing your score. It is pessimistic but robust and hard for humans to exploit. The alternative, **MaxN** (each player maximizes their own score), is more game-theoretically correct but heavier and exploitable. Start Paranoid; revisit if play feels overly defensive.

**Evaluation function** (subtract the *strongest* opponent, not the average — one near-winning opponent is the real threat):

```python
def player_score(state, player, w):
    return sum(marble_progress(loc, player) for loc in state.marbles[player])

def evaluate_state(state, ai_player, w):
    if state.player_won(ai_player):
        return float("inf")
    ours = player_score(state, ai_player, w)
    worst_threat = max(player_score(state, p, w) for p in range(NUM_PLAYERS) if p != ai_player)
    return ours - w["opponent_pressure"] * worst_threat
```

**Re-roll handling — bounded.** The source documents either left the re-roll loop unbounded (risking runaway expansion on consecutive 6s) or capped it ad hoc. Use an explicit `MAX_REROLL_DEPTH` and only advance the turn on a non-6:

```python
MAX_REROLL_DEPTH = 3        # cap re-roll chains in simulation; tune

def simulate_turn_ev(state, player, ai_player, w, depth=0):
    """Expected eval (from ai_player's view) over this player's full turn, incl. re-rolls."""
    if depth >= MAX_REROLL_DEPTH:
        return evaluate_state(state, ai_player, w)
    total = 0.0
    for roll in range(1, 7):
        moves = legal_moves(state, player, roll)
        if moves:
            if player == ai_player:                                  # our decision: maximize
                best = max(moves, key=lambda m: evaluate_state(apply_move(state.clone(), m), ai_player, w))
            else:                                                    # Paranoid: opponent minimizes us
                best = min(moves, key=lambda m: evaluate_state(apply_move(state.clone(), m), ai_player, w))
            nxt = apply_move(state.clone(), best)
        else:
            nxt = state.clone()
        if nxt.player_won(player):
            total += (1/6) * evaluate_state(nxt, ai_player, w)
        elif roll == 6:
            total += (1/6) * simulate_turn_ev(nxt, player, ai_player, w, depth + 1)   # same player
        else:
            total += (1/6) * evaluate_state(nxt, ai_player, w)
    return total

def choose_move_expectimax(state, player, roll, moves, w):
    best_move, best_val = None, float("-inf")
    for m in moves:
        nxt = apply_move(state.clone(), m)
        if nxt.player_won(player):
            return m
        nxt_player = player if roll == 6 else (player + 1) % NUM_PLAYERS
        val = simulate_turn_ev(nxt, nxt_player, ai_player=player, w=w, depth=0)
        if val > best_val:
            best_val, best_move = val, m
    return best_move
```

### 7.3 Approach 3 — MCTS

Standard four-phase loop (selection → expansion → rollout → backprop) with **UCB1** selection and **heuristic-guided rollouts** (the Phase-2 heuristic) for faster convergence than pure-random rollouts.

```python
import math, random

EXPLORATION_C = math.sqrt(2)
MCTS_ITERS = 1000                      # more = stronger + slower; budget-bound it (§9.5)
ROLLOUT_CAP = 500                      # safety cap against non-terminating rollouts

@dataclass
class Node:
    state: GameState
    player: int                        # player to move at this node
    move: Optional[Move]
    parent: "Optional[Node]"
    children: list = field(default_factory=list)
    untried: list = field(default_factory=list)
    visits: int = 0
    wins: float = 0.0

def ucb1(node):
    lp = math.log(node.parent.visits)
    return max(node.parent.children,
               key=lambda c: (c.wins / c.visits) + EXPLORATION_C * math.sqrt(lp / c.visits)) if False else None
```

The full implementation (selection walk, expansion with a sampled next roll, heuristic rollout to a terminal or `ROLLOUT_CAP`, win/loss backprop from the perspective of each node's player, and "pick the most-visited child") follows the structure in the source documents and is reproduced in the implementation-steps file. **Tuning knobs:** `MCTS_ITERS` (strength vs time), `EXPLORATION_C` (raise to escape local optima), and rollout policy (random = fast, heuristic = stronger, learned net = strongest).

> **Re-roll subtlety in MCTS:** when expanding a child after a 6, the *same* player keeps acting — set the child's `player` to the current player, not the next one. Getting this wrong silently corrupts the tree (§13.1).

### 7.4 Approach 4 — Reinforcement learning (optional, current tooling)

Pursue only if MCTS at your time budget still loses to strong humans, or you want emergent strategy. Train entirely in the **headless Python sim** (no Godot in the training loop); visualize/ship via ONNX (§5.5–§5.6).

**Environment — Gymnasium, single learning agent vs an opponent pool.** The learner is player 0; the other seats are driven by a fixed/older policy sampled from a pool. Opponent turns auto-play until it's player 0's turn again.

```python
import gymnasium as gym
import numpy as np

class WahuloEnv(gym.Env):
    def reset(self, *, seed=None, options=None):
        self.state = initial_game_state(seed)
        return self._observe(), {}
    def step(self, action: int):
        # action indexes into the CURRENT legal_moves list; apply it, then auto-play opponents
        ...
        return self._observe(), reward, terminated, truncated, {}
    def _observe(self) -> np.ndarray:
        return encode_state(self.state, player=0)
    def action_masks(self) -> np.ndarray:        # consumed by MaskablePPO / ActionMasker
        return current_legal_action_mask(self.state, player=0)
```

**Action masking is mandatory.** Use **`MaskablePPO` from `sb3-contrib`** with the `ActionMasker` wrapper: it gives illegal actions ~0 probability so the network only ever picks legal moves — the concrete answer to "the model must only choose legal moves" that both source documents left generic.

```python
from sb3_contrib import MaskablePPO
from sb3_contrib.common.wrappers import ActionMasker

env = ActionMasker(WahuloEnv(), lambda e: e.action_masks())
model = MaskablePPO("MlpPolicy", env, verbose=1)     # SB3 ≥ 2.x, Python 3.10+, Gymnasium API
model.learn(total_timesteps=2_000_000)
```

**Observation encoding** — flat one-hot per marble over 63 positions (BASE, 56 track, CENTER, 4 home) plus center-occupant and current-player one-hots (~1001 floats). A shallow MLP actor-critic (e.g. 256→256→128) is ample given the small state space.

**Reward** — start **sparse** (+1 win / −1 loss) because it exactly matches the objective. Add shaping (small +progress, modest +home-entry, small −captured) only if convergence is too slow, and audit for the predictable failure mode (capture-chasing, premature rushing).

**Self-play opponent pool** — periodically snapshot the current policy into a pool (cap ~20, drop oldest); sample opponents from the pool each episode to prevent overfitting to one style.

**Export & watch** — train with `--onnx_export_path=model.onnx` (or SB3's ONNX export), then run it in-engine via the Godot RL Agents **Sync node** in the **.NET/mono** editor (§5.5B), or replay logged self-play games in the `ReplayViewer` (§5.5A).

> **Advanced option (not required):** for *true* 4-player self-play (all seats learning simultaneously) use a **PettingZoo** multi-agent wrapper instead of the single-agent-vs-pool setup. It is more correct but materially more complex; single-agent-vs-pool is the recommended starting point and matches both source documents.

---

## 8. Difficulty tiers & blending

| Tier | Implementation | Rough expected win-rate vs an experienced human* |
|---|---|---|
| Easy | Random (or deliberately weak heuristic) | ~15% |
| Medium | Greedy heuristic | ~35–50% |
| Hard | One-ply expectimax | ~60–70% |
| Expert | MCTS (1000+ iters) | ~75–85% |
| Master | RL self-play | Unknown ceiling |

\* These are **rough design expectations, not measured results.** They will only be real after you benchmark on the actual rules engine. Treat them as targets to validate, not promises.

**Smooth difficulty within a tier** — rather than hard-switching implementations, blend toward random:

```python
def choose_move_blended(state, player, roll, moves, base_chooser, skill: float):
    # skill 0.0 = pure random, 1.0 = full strength
    if random.random() > skill:
        return random.choice(moves)
    return base_chooser(state, player, roll, moves)
```

For MCTS, scale `MCTS_ITERS` with `skill` instead.

---

## 9. Testing, evaluation & metrics

### 9.1 Rules-engine correctness comes first

AI quality is meaningless on a buggy rules engine. Before any tuning, assert (in both Python and, via parity, GDScript):

- base exit only on 1 or 6; own marble blocks landing **and** passing; capture only on landing (plus center-entry capture); forced home diversion when passing `home_entry`; no home overshoot; center entry optional; center exit only on 1; a 6 with no legal move still re-rolls; win triggers immediately on the 4th marble home.

A random agent completing **10,000+** games with zero illegal moves or exceptions is the practical proof.

### 9.2 AI unit tests

Behavioral invariants independent of strength: always take an available winning move; take a forced capture when it is the only legal move; never attempt to enter center when self-occupied; never select a move outside `legal_moves`.

### 9.3 Tournaments — with seat rotation and statistical significance

Round-robin AI-vs-AI tournaments are the arbiter of strength. **Two things both source documents under-emphasized:**

1. **Rotate seat positions.** First-mover and seating effects are real in a 4-player race. Rotate each agent through all seats and average, or you will measure position, not skill.
2. **Report significance, not just raw win-rate.** 4-player outcomes are noisy. With 4 equal players the null win-rate is 25%. To call a difference real, compute a **95% confidence interval** (Wilson interval on the win proportion) or a two-proportion test, and size the run accordingly. As a rule of thumb, distinguishing a 30% from a 25% win-rate at 95% confidence needs **on the order of a few thousand games per agent** — run 2,000–10,000, not 200.

```python
# Wilson 95% CI half-width is ~1/sqrt(n) scale; for a quick gate:
# a 1000-game regression test resolves differences of ~3-4 percentage points.
```

### 9.4 Regression gate

Before any new AI version ships, it must win **≥ 55%** head-to-head against the previous version over a seat-rotated, seeded ≥1,000-game match. This prevents silent regressions from "improvements."

### 9.5 Time budgets

| Context | Max think time / move |
|---|---|
| Desktop | ~500 ms |
| Mobile | ~200 ms |
| Server (async) | ~2000 ms |

Cap MCTS iterations / expectimax depth to fit the *target hardware* budget; profile on-device. Add `max_depth`, `max_reroll_chain`, `time_budget_ms`, `node_budget`, and a transposition cache as the search limits.

### 9.6 Reproducibility

Seed all RNG in benchmarks. Store, alongside every result: the seed, agent versions/weights, the code commit, and the `RULES.md` version. Without this, tuning conclusions are not trustworthy.

### 9.7 Strength & behavior metrics to track

Win-rate (primary), average game length, capture rate / captured rate (aggression vs recklessness), center usage & success rate, home-completion efficiency, and illegal-move attempts (must be 0).

---

## 10. Weight tuning (turning "Medium" into "Hard")

The tuned heuristic is the highest strength-per-effort rung. Tune its weights by simulation, not intuition:

- **Quick & dirty:** manual / grid / random search over the weights, scored by win-rate vs the current best.
- **Recommended:** **Optuna** (Bayesian/TPE optimization) or **CMA-ES** — define the objective as "win-rate vs a fixed reference panel over N seeded, seat-rotated games," and let the optimizer search the weight vector. CMA-ES is well suited to ~10 continuous weights; Optuna gives nice dashboards and pruning.
- Always evaluate a candidate against a **fixed panel** (random + previous-best + expectimax), never only against itself, to avoid chasing a moving target.

---

## 11. Roadmap (phased, with Godot integration milestones)

| Phase | Deliverable | Exit criteria |
|---|---|---|
| 0 | Headless Python sim + **rules parity** vs GDScript | Parity tests pass; 10k random games, zero illegal moves |
| 1 | Random agent + seeded tournament harness | Reproducible AI-vs-AI runs producing win-rates with CIs |
| 2 | Greedy heuristic + feature/eval modules | Beats random by a statistically clear margin |
| 3 | Tuned heuristic (Optuna/CMA-ES) | Distinct, measurably stronger weight sets; Medium/Hard tiers |
| 3.5 | **Godot `ReplayViewer`** + replay format | Any lab game watchable on the real board at variable speed |
| 4 | One-ply expectimax (Paranoid, bounded re-roll) | Beats tuned heuristic enough to justify its cost |
| 5 | MCTS | Matches/beats expectimax under the same time budget, or is dropped |
| 5.5 | **GDScript port** of the chosen shipped tiers | GDScript AI matches Python reference (parity test); wired to difficulty UI |
| 6 | RL self-play (optional): Gymnasium + MaskablePPO + pool | Beats heuristic ≥ ~90% and is stable; ONNX runs in-engine |

Each phase is independently shippable; ship the strongest tier you have whenever you need to.

---

## 12. Hand-off for AI coding agents

### 12.1 Non-negotiable constraints

- **Never reimplement legal-move generation in the AI.** Always call `legal_moves()`.
- **Never mutate real game state during evaluation.** Operate on `state.clone()`.
- **Never let the AI choose a move outside `legal_moves`.**
- **Never advance the turn on a 6** during simulation — the same player continues.
- **Never continue a turn after a winning move** — the game ends immediately.
- **Keep the Python sim and GDScript rules in parity** (§5.2); a divergence invalidates all downstream work.
- **`RULES.md` is authoritative** wherever behavior is ambiguous.

### 12.2 Build order

1. Read `RULES.md` and the existing GDScript rules.
2. Implement/verify `GameState.clone()`, `legal_moves()`, `apply_move()`, `player_won()` in Python; add unit tests.
3. Stand up the **rules-parity harness** (§5.2) and get it green.
4. `Strategy` base class → `RandomStrategy`.
5. Seeded simulation runner + tournament harness with seat rotation and Wilson CIs.
6. `features.py` and `evaluate_state()`.
7. `GreedyHeuristicStrategy`; benchmark vs random.
8. Weight tuning (Optuna/CMA-ES) → tuned heuristic.
9. Build the Godot `ReplayViewer` + replay (de)serialization.
10. `ExpectimaxStrategy` (Paranoid, bounded re-roll); benchmark.
11. `MCTSStrategy`; benchmark under the time budget.
12. Port the chosen shipped tiers to GDScript; parity-test the port.
13. *Only then*, if warranted: RL (Gymnasium env, MaskablePPO, opponent pool, ONNX export + in-engine inference).

### 12.3 Ready-to-paste prompt for an implementing agent

> You are implementing AI players for **Wahulo**, a 4-player Wahoo-style race game in **Godot 4.6.3**. `RULES.md` is authoritative. All training/benchmarking happens in a **headless Python simulator** that must stay in **parity** with the GDScript rules (a parity harness compares legal-move sets and resulting states on shared seeds). **Do not** reimplement move generation in the AI — call `legal_moves(state, player, roll)`, `apply_move(state, move)`, `state.clone()`, `player_won()`.
>
> Build incrementally: (1) `Strategy` base + `choose_move(state, player, roll, moves)`; (2) `RandomStrategy`; (3) seeded tournament harness with **seat rotation** and **Wilson 95% CIs**; (4) `features.py` (progress, home count, base count, center status, capture availability, **corrected** capture-exposure per §7.1, self-blocking); (5) `GreedyHeuristicStrategy` using `evaluate_state()`; (6) weight tuning via Optuna or CMA-ES against a fixed panel; (7) `ExpectimaxStrategy` — **Paranoid**, d6 chance nodes, **bounded** re-roll recursion (`MAX_REROLL_DEPTH`), same player continues on a 6; (8) `MCTSStrategy` with UCB1 + heuristic rollouts; (9) optional RL with **`MaskablePPO` (sb3-contrib)** + `ActionMasker`, sparse reward first, self-play opponent pool, ONNX export.
>
> No strategy may mutate real state or return an illegal move. Add tests for every strategy and the harness. Produce deterministic, seeded, reproducible benchmarks, and a JSON **replay** for any game so it can be viewed in the Godot `ReplayViewer`.

### 12.4 Acceptance criteria

- Random agent completes 10,000 games, zero exceptions, zero illegal moves.
- Greedy heuristic beats random by a statistically clear (CI-backed) margin.
- Tuned heuristic variants show measurable, distinct play styles.
- Expectimax matches or beats the tuned heuristic within the time budget.
- Every strategy chooses only legal moves; re-roll and win-mid-turn handled correctly.
- All benchmarks reproducible from stored seed + version metadata.
- Python sim and GDScript rules pass parity.
- Any lab game is reproducible in the Godot `ReplayViewer`.

---

## 13. Known complexity traps

1. **Re-roll chains.** A 6 keeps the *same* player active across sub-rolls. Advancing `current_player` after every roll is the most common and most corrupting bug. Only advance on `roll != 6`.
2. **Forced home diversion.** Passing *over* `home_entry` forces diversion into home; if that would overshoot `HOME(3)` or hit an own marble, the **entire move is illegal** — not just the home portion. Always defer to `legal_moves()`.
3. **Landing on vs passing `home_entry`.** Landing *exactly* on `home_entry` is a normal track landing (can capture, no diversion); moving *past* it diverts. Different cases.
4. **Center self-block.** A marble already in center can't re-enter; the `enter_center` move is illegal then.
5. **Center exit blocked.** If an own marble sits on `center_exit_dest`, the center marble can't exit and must wait — a rare long stall the AI should understand.
6. **Win mid-turn.** The 4th marble entering home ends the game *now*, even mid re-roll. Check `player_won()` after every `apply_move` before processing re-rolls.
7. **4-player turn order.** Strictly `0→1→2→3→0`; re-rolls keep the same player. Simulation must model all four seats, not "me vs one opponent."

---

## 14. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Python/GDScript rules drift | Parity harness in CI for both repos (§5.2) |
| Tuning on noisy 4-player results | Seat rotation + Wilson CIs + thousands of games (§9.3) |
| Heuristic overfits to one opponent | Evaluate vs a fixed multi-agent panel, not self only (§10) |
| Godot RL Agents vs 4.6.3 / turn-based fit | Validate on a throwaway branch; prefer replay (§5.5A); use discrete actions + masking |
| RL reward hacking (capture-chasing) | Start sparse reward; add shaping only with metric audits (§7.4) |
| AI too slow for the frame budget | Budget-bound search; cache; profile on target hardware (§9.5) |
| Fork diverges from production game | Periodic rebase; port AI back via small reviewed PRs (§5.3) |

---

## 15. Glossary

| Term | Meaning |
|---|---|
| Action space | All moves available on a turn (Wahulo: ~2–4) |
| Action mask | Filter forcing a model to pick only legal moves |
| Backpropagation (MCTS) | Updating win/visit stats up the tree after a rollout |
| Branching factor | Average choices per decision (low here) |
| Capture | Landing on an opponent, sending it to base |
| Chance node | Search node representing the die roll |
| Decision node | Search node where a player chooses |
| Evaluation/value function | Scores how good a state is for a player |
| Expectimax | Search that averages chance nodes, maximizes decision nodes |
| GAE | Generalized Advantage Estimation (RL training signal) |
| Heuristic | Hand-built position scorer |
| MaskablePPO | PPO variant (sb3-contrib) with invalid-action masking |
| MaxN | 4-player search where each maximizes its own score |
| MCTS | Monte Carlo Tree Search |
| ONNX | Portable model format; runs in-engine in Godot (.NET) |
| Paranoid search | 4-player search treating all opponents as one adversary |
| Policy | State → move (or distribution over moves) |
| PPO | Proximal Policy Optimization (standard RL algorithm) |
| Progress | Normalized marble advancement toward home |
| Re-roll | Extra roll granted after a 6 |
| Rollout | A simulated game to completion (MCTS) |
| Self-play | Training against copies/past versions of the agent |
| Sync node | Godot RL Agents node that drives agents (incl. ONNX inference) |
| UCB1 | Upper Confidence Bound; MCTS selection rule |

---

## Appendix A — initial heuristic weight template

```python
DEFAULT_WEIGHTS = {
    "progress":          4.0,
    "enter_home":        8.0,
    "home_depth":        2.0,
    "exit_base":         5.0,
    "center_entry":     10.0,
    "exit_center":       6.0,
    "capture":          12.0,
    "exposure":          3.0,
    "opponent_pressure": 0.75,
}
```

These are **starting points, not truths.** Tune by simulation (§10).

---

## Appendix B — current tooling & versions (June 2026)

| Tool | Version / status (June 2026) | Role |
|---|---|---|
| **Godot Engine** | **4.6.3** stable (released 21 May 2026) | The game + replay viewer + in-engine inference. ONNX inference needs the **.NET/mono** build |
| **Python** | 3.10+ | The lab (sim, strategies, training) |
| **Godot RL Agents** (`godot-rl`) | actively maintained; `pip install godot-rl`; plugin via editor **AssetLib** ("rl") or from source; wraps SB3 / Sample Factory / RLlib / CleanRL | Live in-editor RL training + **ONNX in-engine inference** via the **Sync node** (control mode → "Onnx Inference") |
| **Stable-Baselines3** | 2.x (2.6 stable line; 2.9.x alpha), Gymnasium API | Baseline RL |
| **sb3-contrib `MaskablePPO`** | 2.x, with `ActionMasker` wrapper | **Required** for legal-action masking |
| **Gymnasium** | current | RL environment API |
| **Optuna / CMA-ES** | current | Heuristic weight tuning |
| **PettingZoo** | current | *Optional* true multi-agent self-play |

> Compatibility caveat to verify during implementation: Godot RL Agents targets Godot 4.x broadly; confirm the plugin builds against **4.6.3** on a throwaway branch before committing to it (match the plugin's `.csproj`/`.sln`), and remember it was designed for real-time agents — a turn-based board game uses its discrete-action + masking path, and the **replay** mechanism (§5.5A) is the lower-risk way to watch games regardless.

---

## Appendix C — source synthesis & evaluation note

This plan merges two independent AI responses to the same brief.

**Document A (ChatGPT-style):** strongest on *architecture and hand-off discipline* — the modular engine/strategy/benchmark split, the "never reimplement legal moves" rule, the explicit `choose_move` contract, the staged ladder, reproducibility, the AI-agent prompt, and acceptance criteria. Lighter on runnable code and on plain-language teaching.

**Document B (Cowork/Claude-style):** strongest on *teaching and completeness of code* — a plain-language concept primer for the owner, full working specs for all four approaches (including a PyTorch actor-critic and PPO outline), explicit board constants, a "known complexity traps" section, difficulty-tier expectations, and a thorough glossary.

**What this merge added or corrected beyond both:**

- Adapted everything to a **Godot 4.6.3** game with a **headless Python lab + rules-parity** design, a **fork-as-separate-project** strategy, and an **in-game replay viewer** plus **ONNX in-engine inference** so you can *watch* AI games inside the actual game.
- Named concrete, current tooling the sources left generic: **`MaskablePPO`/`ActionMasker`** for action masking, **Optuna/CMA-ES** for weight tuning, **ONNX + Godot RL Agents Sync node** for shipping/watching a learned agent.
- **Corrected** the capture-exposure estimate (the sources double-counted threat probability) and **bounded** the re-roll recursion that one source left open-ended.
- Added **statistical-significance** discipline to tournaments (seat rotation + Wilson CIs + adequate sample sizes), which both sources under-specified.

Where the two sources stated game facts, they agreed (board formulas, location model, move kinds), which raises confidence those values match `RULES.md` — but `RULES.md` remains the final authority.
