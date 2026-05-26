# AI Player Build Plan

Concrete implementation spec for computer opponents in the Wahoo Python prototype. This document drives the code in `wahoo/ai.py`, `wahoo/selfplay.py`, and `tests/test_ai.py`. It is grounded in the design framework in `AI_Stragegy_Spec.md` (filename currently misspelled) and the rules in `RULES.md`.

---

## 1. Overview

The AI lives entirely in `wahoo/ai.py`. It exposes a small set of player classes with a common interface and a `PROFILES` dict that maps name strings to pre-configured instances. `play.py` calls one method on whichever player is assigned to each slot; it does not need to know which tier or profile it is talking to.

```
wahoo/ai.py          — player classes, feature computation, profiles
wahoo/selfplay.py    — headless N-game runner for win-rate analysis
tests/test_ai.py     — scenario probe suite
```

The existing `choose_computer_move()` in `play.py` is still active today; per-slot AI dispatch remains planned work.

---

## 2. Player Interface

Every player class implements one method:

```python
def choose_move(self, state: GameState, player: int, roll: int, moves: list) -> dict:
    ...
```

- `state` — current game state (do not mutate; clone if simulation is needed)
- `player` — the seat index (0–3) making the move
- `roll` — the die value that generated this move list
- `moves` — the list returned by `legal_moves(state, player, roll)`; guaranteed non-empty

Returns one move dict from `moves`.

---

## 3. Tier 1 — `RandomPlayer`

```python
class RandomPlayer:
    def choose_move(self, state, player, roll, moves):
        return random.choice(moves)
```

No state read beyond the move list. Used as a baseline opponent and for sanity-testing the game loop. A well-tuned `GreedyPlayer` should win against four `RandomPlayer` opponents at a clearly above-chance rate in self-play.

---

## 4. Tier 2 — `GreedyPlayer`

### 4.1 Constructor

```python
class GreedyPlayer:
    def __init__(self, weights: dict, phase_weights: dict | None = None):
        self.weights = weights          # 10-key float dict, see §6
        self.phase_weights = phase_weights or DEFAULT_PHASE_WEIGHTS
```

### 4.2 `choose_move` logic

```python
def choose_move(self, state, player, roll, moves):
    # Hard guardrail: immediate win always overrides style
    for move in moves:
        s2 = state.clone()
        apply_move(s2, move)
        if s2.player_won(player):
            return move

    phase = _game_phase(state, player)
    scores = [self._score(state, player, roll, m, moves, phase) for m in moves]
    return moves[scores.index(max(scores))]
```

Ties in `max()` resolve to the first tied move in the list (list order is deterministic from `legal_moves()`). This is fine — it keeps the player deterministic given fixed state and roll.

### 4.3 `_score`

```python
def _score(self, state, player, roll, move, all_moves, phase):
    features = compute_features(state, player, roll, move, all_moves)
    base = sum(self.weights[k] * features[k] for k in self.weights)
    modifier = sum(self.phase_weights[phase].get(k, 0.0) * features[k] for k in features)
    return base + modifier
```

### 4.4 `_game_phase`

```python
def _game_phase(state, player) -> str:
    home_count = sum(1 for m in range(4) if state.marbles[player][m][0] == "HOME")
    if home_count == 0:
        return "early"
    if home_count == 1:
        return "mid"
    return "late"
```

---

## 5. Tier 3 — `ExpectimaxPlayer` (stretch)

After `GreedyPlayer` is validated, one-ply expectimax can be layered on top.

For each legal move `a`:
1. Clone state and apply `a`.
2. For each of the 6 die outcomes `r ∈ {1…6}`:
   a. Get the next player's legal moves.
   b. Assume the next player plays their greedy-best move (using their own profile).
   c. Apply that move to a cloned state.
   d. Evaluate the resulting state with a `_evaluate(state, player)` heuristic (sum of own marble progress scores minus sum of all opponent progress scores).
3. The value of move `a` is the average of the 6 resulting evaluations.
4. Re-rolls on 6 extend the same player's turn — the lookahead must thread these correctly (see `RULES.md` §8.6).

Implementation note: `GameState.clone()` already exists for this purpose. The main risk is performance when all 4 slots are `ExpectimaxPlayer`; profile with `cProfile` before enabling it in self-play.

---

## 6. Feature Computation

### 6.1 Entry point

```python
def compute_features(state: GameState, player: int, roll: int, move: dict, all_moves: list) -> dict:
    """Return a 10-key float dict for one candidate move."""
```

All values are in the 0.0–1.0 range (approximate; strict normalization is not required, but consistent relative scaling within each feature is).

### 6.2 Helper — marble progress score

```python
def _marble_progress(state, player, marble_id) -> float:
```

Returns a 0.0–1.0 value representing how far along the race path a marble is.

- `BASE` → 0.0
- `TRACK(i)` → `segment_offset(player, i) / (LOOP_SIZE - 1)`
  (normalizes the marble's distance from its own base-exit across the full loop)
- `CENTER` → 0.65 (heuristic: center exit lands at ~offset 47 of own journey; treat as mid-late)
- `HOME(j)` → `0.85 + (j / (HOME_SLOTS - 1)) * 0.15` (0.85–1.0 range)

### 6.3 Helper — capture exposure

```python
def compute_exposure(state: GameState, player: int, loop_idx: int) -> float:
```

Returns the fraction of (opponent × roll) pairs that can land exactly on `loop_idx` on the opponent's next turn. Computed as:

```
count of (opp_player, roll) pairs where:
    opp_player ≠ player
    opp_player has a marble at TRACK(loop_idx - roll mod LOOP_SIZE)
    that marble's _walk_forward would land on loop_idx (not diverted to home)
divided by
    (NUM_PLAYERS - 1) * 6   # maximum possible threat pairs
```

This remains an approximation (for example, it does not model opponent self-blocking), but it does account for home-entry diversion checks so opponents are not counted as threats when their path would be forced into home instead of landing on `loop_idx`.

### 6.4 The 10 features

#### DEP — Deployment (exit pressure)
Exit base move indicator.

```python
DEP = 1.0 if move["kind"] == "exit_base" else 0.0
```

#### RUN — Single-runner bias
Does this move advance the currently furthest-progress marble?

```python
progress = [_marble_progress(state, player, m) for m in range(4)]
moved_marble = move["marble"]
# Progress after the move (approximate — use dest location directly)
dest_progress = _loc_progress(player, move["dest"])
rank = sorted(set(progress), reverse=True)
# 1.0 if the moved marble is the furthest; scales down by rank
RUN = 1.0 - (rank.index(progress[moved_marble]) / 3.0)
```

#### SPR — Spread portfolio
Preference for activating base marbles or advancing lagging marbles.

```python
SPR = 1.0 - RUN
```

(RUN and SPR are complements. Profiles separate them because some profiles weight one high and the other moderate, rather than simply inverting.)

#### CAP — Capture aggression
Reward for capturing, scaled by victim progress.

```python
if move["captures"] is None:
    CAP = 0.0
else:
    cap_p, cap_m = move["captures"]
    CAP = _marble_progress(state, cap_p, cap_m)   # 0.0–1.0 by victim's progress
```

A marble that has barely left base scores ~0.05; a marble near home scores ~0.9. This naturally biases the Assassin toward targeting the leader.

#### SAFE — Safety first
Net reduction in capture exposure from the move.

```python
if move["dest"][0] != "TRACK":
    # HOME and CENTER have their own safety logic; treat as moderate safety
    SAFE = 0.5
else:
    before = compute_exposure(state, player, state.marbles[player][move["marble"]][1])
    after  = compute_exposure(state, player, move["dest"][1])
    SAFE = max(0.0, min(1.0, (before - after) + 0.5))
    # Centered at 0.5: >0.5 means safer, <0.5 means more exposed
```

#### CTR — Shortcut eagerness
Center entry move indicator.

```python
CTR = 1.0 if move["kind"] == "enter_center" else 0.0
```

#### DEN — Center denial
Center entry that specifically bumps an opponent from center.

```python
DEN = 1.0 if move["kind"] == "enter_center" and move["captures"] is not None else 0.0
```

Note: a DEN move always also has `CTR = 1.0`. Profiles like Gatekeeper and Assassin weight DEN heavily, so they prefer center entry specifically when it displaces an opponent.

#### FLOW — Flow control
Reduction in self-blocking after the move. A marble is "trapped" if another own marble is between 1 and 5 steps ahead of it on the loop (the maximum single-die range).

```python
def _self_block_count(state, player):
    track_offsets = sorted(
        segment_offset(player, state.marbles[player][m][1])
        for m in range(4) if state.marbles[player][m][0] == "TRACK"
    )
    blocked = 0
    for i, off in enumerate(track_offsets):
        for j in range(i + 1, len(track_offsets)):
            gap = track_offsets[j] - off
            if 1 <= gap <= 5:
                blocked += 1
    return blocked

before = _self_block_count(state, player)
s2 = state.clone(); apply_move(s2, move)
after = _self_block_count(s2, player)
FLOW = max(0.0, min(1.0, (before - after) / 3.0 + 0.5))
# >0.5 = reduced blocking; <0.5 = increased blocking
```

#### HOME — Home-lane engineering
Depth of home placement, rewarding deeper slots and preferring to clear congestion.

```python
if move["dest"][0] != "HOME":
    HOME = 0.0
else:
    slot = move["dest"][1]
    HOME = (slot + 1) / HOME_SLOTS   # 0.25 for slot 0, 1.0 for slot 3
```

#### FIN — Finish-over-fight
High when this is a home-progress move in a finish-vs-fight decision state. A finish-vs-fight state is one where at least one home move AND at least one capture/denial move are both legal this turn.

```python
home_moves    = [m for m in all_moves if m["dest"][0] == "HOME"]
capture_moves = [m for m in all_moves if m["captures"] is not None]
finish_vs_fight = bool(home_moves and capture_moves)

if not finish_vs_fight:
    FIN = 0.5   # neutral; not a meaningful decision point
elif move["dest"][0] == "HOME":
    FIN = 1.0
else:
    FIN = 0.0
```

(Pass `all_moves` as a parameter into `compute_features()` for this check.)

---

## 7. Phase Modifiers

Additive adjustments layered on top of profile weights. Applied after the base dot product.

```python
DEFAULT_PHASE_WEIGHTS = {
    "early": {"DEP": 0.30, "SPR": 0.20},
    "mid":   {"CAP": 0.10, "CTR": 0.10},
    "late":  {"HOME": 0.40, "FIN": 0.50, "SAFE": 0.20},
}
```

Phase is determined per-turn before scoring. Late-game boosting HOME and FIN ensures all profiles converge on finishing behavior once two marbles are home, regardless of their base combat style.

---

## 8. Profile Weight Table

Taken directly from `AI_Stragegy_Spec.md` (filename currently misspelled). Stored as module-level constants in `ai.py`.

| Profile            | DEP | RUN | SPR | CAP | SAFE | CTR | DEN | FLOW | HOME | FIN |
|--------------------|-----|-----|-----|-----|------|-----|-----|------|------|-----|
| Sprinter           | 0.4 | 1.0 | 0.2 | 0.4 | 0.2  | 0.9 | 0.3 | 0.4  | 0.5  | 0.9 |
| Swarm              | 1.0 | 0.2 | 1.0 | 0.5 | 0.4  | 0.4 | 0.4 | 0.8  | 0.5  | 0.6 |
| Assassin           | 0.5 | 0.4 | 0.4 | 1.0 | 0.2  | 0.5 | 0.9 | 0.5  | 0.3  | 0.4 |
| Shortcut Gambler   | 0.7 | 0.8 | 0.3 | 0.6 | 0.1  | 1.0 | 0.6 | 0.2  | 0.4  | 0.5 |
| Tortoise           | 0.4 | 0.3 | 0.6 | 0.2 | 1.0  | 0.1 | 0.5 | 0.9  | 0.9  | 0.8 |
| Gatekeeper         | 0.5 | 0.3 | 0.5 | 0.7 | 0.7  | 0.4 | 1.0 | 0.8  | 0.5  | 0.6 |
| Endgame Engineer   | 0.4 | 0.4 | 0.5 | 0.2 | 0.8  | 0.2 | 0.3 | 1.0  | 1.0  | 1.0 |
| Balanced Pragmatist| 0.6 | 0.5 | 0.6 | 0.6 | 0.6  | 0.5 | 0.6 | 0.7  | 0.7  | 0.7 |

The `PROFILES` dict in `ai.py`:

```python
PROFILES = {
    "random":    RandomPlayer(),
    "sprinter":  GreedyPlayer(SPRINTER_WEIGHTS),
    "swarm":     GreedyPlayer(SWARM_WEIGHTS),
    "assassin":  GreedyPlayer(ASSASSIN_WEIGHTS),
    "gambler":   GreedyPlayer(GAMBLER_WEIGHTS),
    "tortoise":  GreedyPlayer(TORTOISE_WEIGHTS),
    "gatekeeper":GreedyPlayer(GATEKEEPER_WEIGHTS),
    "engineer":  GreedyPlayer(ENGINEER_WEIGHTS),
    "balanced":  GreedyPlayer(BALANCED_WEIGHTS),
}
```

---

## 9. Integration with `play.py`

### 9.1 Settings change

Replace the boolean `computer_self_play` flag with a per-slot player list:

```python
# Before
settings = {"auto_roll": False, "computer_self_play": False}

# After
settings = {
    "auto_roll": False,
    "players": ["human", "human", "human", "human"],  # one entry per slot
}
```

Valid slot values: `"human"` or any key from `PROFILES`.

### 9.2 `take_turn` dispatch

```python
player_type = settings["players"][player]
if player_type == "human":
    auto_move = maybe_auto_choose_move(state, player, roll, moves)
    if auto_move is not None:
        chosen = auto_move
    else:
        print(f"{player_label(player)} rolled a {roll}.")
        prompt_moves = build_prompt_moves(state, player, roll, moves)
        chosen = choose_move(prompt_moves, player, roll, settings)
else:
    from wahoo.ai import PROFILES
    chosen = PROFILES[player_type].choose_move(state, player, roll, moves)
    outcome = f"[{player_type}] {format_move(chosen, player, roll)}"
```

Auto-roll is forced on for slots with an AI player type. Human slots continue to use the existing roll-prompt and move-prompt flow.

### 9.3 Startup configuration

Add a `configure_players()` function called during game setup that presents each slot and asks: human or which AI profile? The `[C] Computer self-play` option from the current menu maps to all-Balanced for backwards compatibility.

---

## 10. `wahoo/selfplay.py`

Headless runner for win-rate analysis. No console UI; prints results only.

### Usage

```
python -m wahoo.selfplay --games 500 --players balanced assassin tortoise random
python -m wahoo.selfplay --games 200 --players assassin assassin assassin assassin
```

`--players` accepts exactly 4 profile names (use `random` for random baseline).

### Output

```
Self-play: 500 games, players: [balanced, assassin, tortoise, random]

Slot  Profile      Wins   Win%   Avg turns to win
  0   balanced      141   28.2%  87.3
  1   assassin      163   32.6%  81.1
  2   tortoise      112   22.4%  94.6
  3   random         84   16.8%  102.7
```

Optionally `--output results.csv` to append each game's result to a CSV file for further analysis (see `STAT_TRACKING_PLAN.md`).

### Implementation notes

- Reuse the game loop logic from `play.py`'s `take_turn()` but stripped of all print/input calls
- Use `random.Random()` with an optional `--seed` for reproducibility
- Do not record game history to JSON by default (performance); add `--record` flag to enable

---

## 11. Test Plan — `tests/test_ai.py`

### 11.1 Framework

Use `pytest`. Board states are built by directly constructing `GameState` and assigning marble locations as location tuples. There is no need to simulate a game to reach a probe state — just set the marbles list directly.

```python
from wahoo.game_state import GameState, loc_base, loc_track, loc_home, loc_center
from wahoo.rules import legal_moves
from wahoo.ai import PROFILES, RandomPlayer

def make_state(marbles_by_player, center_occupant=None):
    state = GameState()
    state.marbles = marbles_by_player
    state.center_occupant = center_occupant
    state.current_player = 0
    return state
```

### 11.2 Required probes

All probes are deterministic (GreedyPlayer is deterministic given fixed state + roll).

---

**Probe 1 — Win guardrail (all profiles)**

State: Player 0 has marbles at `HOME(0)`, `HOME(1)`, `HOME(2)`, `BASE`. Roll: `3`.
`HOME(2) + 3 = HOME(5)` would overshoot. Set `HOME(0)`, `HOME(1)`, `HOME(3)`, `TRACK(55)`. Roll: `1`.
The `TRACK(55)` marble at home_entry for player 0 will enter HOME(0) on roll 1 — but HOME(0) is occupied.
Better setup: marbles at `HOME(0)`, `HOME(1)`, `HOME(2)`, `TRACK(home_entry(0))`. Roll: `2`. The TRACK marble enters HOME and advances to `HOME(1)` — but that's occupied. Use roll `3` to reach `HOME(3)` (deepest) — that's the win.

```python
def test_win_guardrail():
    for profile_name, player in PROFILES.items():
        # state where exactly one move wins
        state = ...  # set up 3 marbles in HOME(0,1,2), one at TRACK position
                     # with roll that puts it in HOME(3)
        moves = legal_moves(state, 0, roll)
        winning = [m for m in moves if m["dest"] == loc_home(3)]
        assert len(winning) == 1
        chosen = player.choose_move(state, 0, roll, moves)
        assert chosen == winning[0], f"{profile_name} failed win guardrail"
```

---

**Probe 2 — Center temptation (Sprinter and Shortcut Gambler prefer center)**

State: Player 0 at `[BASE, BASE, TRACK(offset 6 = loop_idx 6), TRACK(18)]`, center empty. Roll: `1` (required to enter center from offset 5; offset 5 from player 0's base_exit(0)=0 is loop_idx 5; with roll 1 from offset 5, enter center).

Actually: `base_exit(0) = 0`, offset 5 = `TRACK(5)`. Roll needed = `6 - 5 = 1`. So set marble at `TRACK(5)`.

```python
def test_center_temptation():
    state = make_state([[loc_base(), loc_base(), loc_track(5), loc_track(18)], ...])
    moves = legal_moves(state, 0, 1)
    center_move = next(m for m in moves if m["kind"] == "enter_center")
    for profile_name in ["sprinter", "gambler"]:
        chosen = PROFILES[profile_name].choose_move(state, 0, 1, moves)
        assert chosen == center_move, f"{profile_name} should prefer center"
    # Swarm should often prefer deployment; Tortoise should avoid center
    swarm_choice = PROFILES["swarm"].choose_move(state, 0, 1, moves)
    tortoise_choice = PROFILES["tortoise"].choose_move(state, 0, 1, moves)
    assert swarm_choice["kind"] != "enter_center"   # prefers exit_base
    assert tortoise_choice["kind"] != "enter_center"
```

---

**Probe 3 — Capture vs deploy (Assassin prefers capture)**

State: Player 0 at `[BASE, BASE, TRACK(7), TRACK(22)]`. Opponent (player 1) marble at `TRACK(13)` (exactly 6 ahead of player 0's marble at TRACK(7)). Roll: `6`. Two legal moves: `exit_base` (marble from BASE to TRACK(0)) and `advance` (TRACK(7) → TRACK(13), capturing player 1's marble).

```python
def test_capture_vs_deploy():
    # Player 1 marble exactly 6 ahead of player 0's marble at track(7)
    state = make_state(...)
    moves = legal_moves(state, 0, 6)
    capture_move = next(m for m in moves if m["captures"] is not None)
    for profile_name in ["assassin", "gatekeeper"]:
        chosen = PROFILES[profile_name].choose_move(state, 0, 6, moves)
        assert chosen == capture_move, f"{profile_name} should capture"
    # Swarm should prefer deploying new marble
    swarm_choice = PROFILES["swarm"].choose_move(state, 0, 6, moves)
    assert swarm_choice["kind"] == "exit_base"
```

---

**Probe 4 — Finish or fight (Endgame Engineer prefers home)**

State: Player 0 at `[HOME(0), HOME(1), TRACK(home_entry(0)), TRACK(10)]`. Opponent leader at `TRACK(home_entry(0) - 4)` (4 behind player 0's marble at TRACK(10), which they can capture). Roll: `4`. Two meaningful moves: advance `TRACK(home_entry(0))` marble into `HOME(3)` (win-adjacent) and capture the opponent's marble on `TRACK(10)`.

Wait — with marbles at HOME(0), HOME(1), the player needs 2 more in home to win. The move that enters HOME(3) is not a win. Let me just set up: two moves legal, one is a home move, one is a capture.

```python
def test_finish_over_fight():
    state = make_state(...)
    moves = legal_moves(state, 0, roll)
    home_move    = next(m for m in moves if m["dest"][0] == "HOME")
    capture_move = next(m for m in moves if m["captures"] is not None)
    for profile_name in ["engineer", "tortoise"]:
        chosen = PROFILES[profile_name].choose_move(state, 0, roll, moves)
        assert chosen == home_move, f"{profile_name} should prefer home over fight"
    for profile_name in ["assassin"]:
        chosen = PROFILES[profile_name].choose_move(state, 0, roll, moves)
        assert chosen == capture_move, f"{profile_name} should prefer capture"
```

---

**Probe 5 — Center denial (Gatekeeper bumps opponent from center)**

State: Player 0 at `[BASE, BASE, TRACK(5), TRACK(18)]`, opponent marble occupying center. Roll: `1`. Two moves: `enter_center` (capturing opponent) and `advance` (TRACK(5) → TRACK(6)).

```python
def test_center_denial():
    occ = (1, 0)   # opponent player 1, marble 0 in center
    state = make_state(..., center_occupant=occ)
    moves = legal_moves(state, 0, 1)
    denial_move = next(m for m in moves if m["kind"] == "enter_center")
    for profile_name in ["gatekeeper", "assassin"]:
        chosen = PROFILES[profile_name].choose_move(state, 0, 1, moves)
        assert chosen == denial_move
```

---

**Probe 6 — Threat escape (Tortoise moves away from danger)**

State: Player 0 marble at `TRACK(24)`. Opponent marble at `TRACK(20)` (4 behind; will capture on roll 4). Player 0 also has a marble at `TRACK(30)`. Roll: `4`. Two moves: advance `TRACK(24)` to `TRACK(28)` (safer) or advance `TRACK(30)` to `TRACK(34)`.

```python
def test_threat_escape():
    state = make_state(...)
    moves = legal_moves(state, 0, 4)
    escape_move = next(m for m in moves if m["marble"] == marble_at_24)
    for profile_name in ["tortoise", "gatekeeper"]:
        chosen = PROFILES[profile_name].choose_move(state, 0, 4, moves)
        assert chosen == escape_move, f"{profile_name} should escape threat"
```

---

### 11.3 Randomness / determinism

`GreedyPlayer` is fully deterministic given fixed state and roll — no sampling needed. `RandomPlayer` tests should use `random.seed()` or run over many trials and check statistical properties (e.g., each move chosen with roughly equal frequency over 1000 calls).

---

## 12. Build Order

1. `compute_exposure()` and `_marble_progress()` helpers — no other dependencies
2. `compute_features()` using those helpers — all 10 features
3. `RandomPlayer` and `GreedyPlayer` with `Balanced Pragmatist` weights only
4. Probe 1 (win guardrail) — validates the hard-rule path
5. Probe 2–6 with Balanced weights initially; tune to confirm balanced play
6. Add remaining 7 profiles; run probes per profile
7. Refactor `play.py` for per-slot dispatch
8. `selfplay.py` + win-rate table to confirm rough Elo parity across profiles
9. `ExpectimaxPlayer` (optional, after profiles are stable)

---

## 13. Files Modified or Created

| File | Change |
|------|--------|
| `wahoo/ai.py` | New — player classes, features, profiles |
| `wahoo/selfplay.py` | New — headless N-game runner |
| `tests/test_ai.py` | New — scenario probe suite |
| `wahoo/play.py` | Modify `take_turn()`, settings, startup menu |
| `documents/AI_PLAYER_BUILD_PLAN.md` | This document |
