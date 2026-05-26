# Stat Tracking Plan

How per-game statistics are captured, stored, and analyzed. The goal is to surface trends between AI playstyles across many games — which profiles win more, which strategies correlate with winning, and whether the dice or the decisions are doing the explaining.

This document drives the code in `wahoo/stats.py` and the extended game recording format.

---

## 1. Design Goals

- **Separate luck from skill.** Every metric that measures a decision must be expressed as a rate over *opportunities*, not a raw count. A player who rolled more 6s naturally makes more base exits — that's luck. What matters is whether they *chose* to exit when given the chance.
- **Record alternatives, not just choices.** For any turn with more than one legal move, log what was available, not just what was picked. Without this, you cannot infer preference.
- **Opportunity-conditioned style metrics.** The primary output is a per-player style vector — the 10 strategy dimension rates computed from discretionary turns only — which can be compared against the AI profile weight table.
- **Stay practical.** The tracking must not require manual annotation. Everything is computed automatically from the game state, legal moves, and chosen move.

---

## 2. What the Existing Recording Already Has

The JSON game files (`game1.json`, `game2.json`, etc.) capture:

```json
{
  "version": 1,
  "seed": null,
  "entries": [
    {
      "index": 0,
      "event": { "type": "start", "starting_player": 2, "top_roll": 5 },
      "state": { ... }
    },
    {
      "index": 1,
      "event": {
        "type": "turn",
        "player": 2,
        "roll": 6,
        "outcome": "auto-selected Move A3 + 6 positions",
        "reroll": true,
        "won": false
      },
      "state": { ... }
    }
  ]
}
```

This captures full board snapshots and turn outcomes but loses the information needed for strategy analysis: what other moves were available, and what were their feature values.

---

## 3. Extended Recording Format

### 3.1 New `event.type` — `"turn_detail"`

When a move is made, a `turn_detail` event is appended alongside the existing `turn` event. The `turn` event stays unchanged for replay compatibility; `turn_detail` is optional and only written when `settings["track_stats"] = True`.

```json
{
  "type": "turn_detail",
  "player": 0,
  "player_type": "assassin",
  "roll": 6,
  "roll_index": 1,
  "forced_move": false,
  "pre_state_snapshot": {
    "own_marble_locations": [["TRACK", 7], ["BASE"], ["BASE"], ["TRACK", 22]],
    "center_occupant": null,
    "marbles_in_home": [0, 1, 0, 2],
    "marbles_in_base": [2, 3, 4, 2]
  },
  "candidate_moves": [
    {
      "kind": "exit_base",
      "marble": 1,
      "dest": ["TRACK", 0],
      "captures": null,
      "features": { "DEP": 1.0, "RUN": 0.0, "SPR": 0.8, "CAP": 0.0,
                    "SAFE": 0.6, "CTR": 0.0, "DEN": 0.0, "FLOW": 0.3,
                    "HOME": 0.0, "FIN": 0.5 }
    },
    {
      "kind": "advance",
      "marble": 0,
      "dest": ["TRACK", 13],
      "captures": [1, 2],
      "features": { "DEP": 0.0, "RUN": 0.4, "SPR": 0.1, "CAP": 0.85,
                    "SAFE": 0.3, "CTR": 0.0, "DEN": 0.0, "FLOW": 0.1,
                    "HOME": 0.0, "FIN": 0.0 }
    }
  ],
  "chosen_move_index": 1,
  "decision_type": "capture_vs_deploy"
}
```

Fields:
- `player_type` — the profile name assigned to this slot (`"human"` for human players)
- `roll_index` — 1 for the primary roll, 2+ for re-rolls after a 6
- `forced_move` — `true` when `len(candidate_moves) == 1`
- `pre_state_snapshot` — lightweight summary of the board at decision time (not the full state blob)
- `candidate_moves` — one record per legal move, including the feature vector from `compute_features()`
- `chosen_move_index` — index into `candidate_moves` of the chosen move
- `decision_type` — a coarse label for the type of decision (see §4)
- `opportunity_flags` — boolean map of which tactical opportunities were present (see §4.1)

### 3.2 Game metadata extension

Add a `players` field to the recording header:

```json
{
  "version": 2,
  "seed": null,
  "players": ["human", "assassin", "tortoise", "balanced"],
  "entries": [ ... ]
}
```

---

## 4. Decision Type Labels

Automatically assigned based on what move types are in the legal-move list. Used for slicing analysis by situation.

| Label | Condition |
|---|---|
| `forced` | Only one legal move |
| `exit_only` | Multiple exit_base moves, no other types |
| `capture_vs_advance` | Capture available; no home or center moves |
| `capture_vs_deploy` | Capture available; exit_base also available |
| `center_opportunity` | enter_center available (any other moves also present) |
| `center_denial` | enter_center would bump an opponent from center |
| `finish_vs_fight` | Home move and capture/denial move both available |
| `home_vs_advance` | Home move available; no capture or center options |
| `mixed` | Multiple types present, none of the above patterns match |

### 4.1 Opportunity Flags (including human-tendency flags)

These flags are recorded per turn so the HT-01..HT-11 tendencies in `AI_Strategy_Spec.md` can be analyzed as rates over opportunities.

| Flag | Meaning |
|---|---|
| `has_capture` | At least one legal capture exists |
| `has_center` | At least one legal `enter_center` exists |
| `has_home` | At least one legal home move exists (`enter_home` or `advance_home`) |
| `has_exit_base` | At least one legal `exit_base` exists |
| `opp_center_exit_threat` | At least one opponent can plausibly exit center before your next turn |
| `back_threat_within_6` | At least one of your marbles is within six squares of a dangerous trailing opponent |
| `intercept_hold_available` | A legal move preserves or creates an interception square against a likely opponent pass-through line |
| `guard_exit_hold_available` | A legal move keeps a guard on your base-exit traffic square while alternatives advance elsewhere |
| `opening_run_split_available` | You can advance a lead opening-run marble while preserving a near-exit support marble |
| `sandwich_trap_present` | An opponent marble is between two of your marbles with meaningful capture pressure |
| `multi_capture_choice` | Two or more distinct capture targets are legal |
| `bait_line_available` | A legal move creates an exposure that can force opponent capture-vs-progress tradeoff |

Implementation guidance:
- Keep flag logic conservative and deterministic; ambiguous states should default to `false`.
- Use these as analysis dimensions first (rates and win correlation), then as potential AI tuning inputs.

---

## 5. `wahoo/stats.py` Module

### 5.1 `TurnRecord` dataclass

```python
@dataclass
class TurnRecord:
    game_id: str
    turn_index: int
    player: int
    player_type: str
    roll: int
    roll_index: int             # 1 = primary roll, 2+ = re-roll after 6
    forced_move: bool
    decision_type: str
    num_legal_moves: int
    chosen_kind: str            # move["kind"] of chosen move
    chosen_features: dict       # 10-key float dict
    capture_made: bool
    capture_victim_progress: float   # 0.0 if no capture
    center_entered: bool
    center_denied: bool         # entered center AND bumped opponent
    home_move_made: bool
    home_slot_reached: int | None    # 0–3, or None
    exit_base_made: bool
    opportunity_flags: dict     # which opportunity types were available this turn
    # opportunity_flags includes base flags + tendency flags from §4.1
    tendency_flags: dict | None  # optional alias/subset for HT-01..HT-11 analytics
```

### 5.2 `PlayerGameStats` dataclass

Aggregated per-player per-game stats. All *rate* fields are `float | None` (None when denominator is 0).

```python
@dataclass
class PlayerGameStats:
    game_id: str
    player: int
    player_type: str
    won: bool
    final_marbles_in_home: int
    final_marbles_on_track: int
    final_marbles_in_base: int
    total_turns: int
    total_rolls: int
    ones_rolled: int
    sixes_rolled: int
    no_move_turns: int              # turns where no legal move existed
    forced_move_turns: int          # turns where exactly one legal move existed
    discretionary_turns: int        # turns with 2+ legal moves

    captures_made: int
    captures_suffered: int

    center_entries: int
    center_exits: int
    center_bumps_suffered: int

    base_exits_on_1: int
    base_exits_on_6: int
    base_exit_on_6_opportunities: int   # times roll=6 with marble in base
    base_exit_on_6_chosen: int

    home_moves_made: int
    first_marble_home_turn: int | None  # turn index, or None

    # Opportunity-conditioned rates (None when no opportunities occurred)
    capture_conversion_rate: float | None   # captures chosen / capture opps
    center_entry_rate: float | None         # center entries / center opps
    base_exit_on_6_rate: float | None       # exits on 6 / opportunities
    home_move_rate: float | None            # home moves chosen / home opps

    # Tendency-conditioned rates (derived from §4.1 flags)
    intercept_hold_rate: float | None
    guard_exit_hold_rate: float | None
    sandwich_trap_preserve_rate: float | None
    bait_line_success_rate: float | None

    # Style vector: average feature value of chosen moves on discretionary turns
    style_vector: dict   # 10-key float dict, keys: DEP RUN SPR CAP SAFE CTR DEN FLOW HOME FIN
```

### 5.3 `GameSummary` dataclass

```python
@dataclass
class GameSummary:
    game_id: str
    player_types: list[str]          # [slot0, slot1, slot2, slot3]
    winner: int
    winner_type: str
    total_turns: int
    total_rolls: int
    player_stats: list[PlayerGameStats]  # one per player
```

### 5.4 Key functions

```python
def compute_turn_record(
    game_id: str,
    turn_index: int,
    state_before: GameState,
    player: int,
    player_type: str,
    roll: int,
    roll_index: int,
    all_moves: list,
    chosen_move: dict,
) -> TurnRecord:
    """Compute all turn-level metrics for one move decision."""
```

```python
def compile_game_stats(recording: dict) -> GameSummary:
    """Read a recording dict (loaded from JSON) and compute full GameSummary.
    Requires version 2 recording with turn_detail events."""
```

```python
def print_game_report(summary: GameSummary) -> None:
    """Print a human-readable post-game stat report to stdout."""
```

```python
def append_stats_csv(summary: GameSummary, path: str) -> None:
    """Append one row per player to a CSV file for cross-game analysis.
    Creates the file with headers if it does not exist."""
```

### 5.5 CSV schema

One row per player per game. This file accumulates across games and is the primary input for trend analysis.

| Column | Type | Description |
|---|---|---|
| game_id | str | e.g., `game7` |
| player | int | Slot index 0–3 |
| player_type | str | Profile name or `human` |
| won | bool | |
| final_home | int | Marbles in home at end |
| total_turns | int | |
| total_rolls | int | |
| ones_rolled | int | |
| sixes_rolled | int | |
| captures_made | int | |
| captures_suffered | int | |
| net_captures | int | made − suffered |
| center_entries | int | |
| center_exits | int | |
| center_bumps_suffered | int | |
| base_exit_on_6_rate | float | exits on 6 / opportunities |
| capture_conversion_rate | float | |
| center_entry_rate | float | |
| home_move_rate | float | |
| discretionary_turns | int | |
| forced_turns | int | |
| no_move_turns | int | |
| first_marble_home_turn | int | |
| style_DEP | float | Avg DEP feature on discretionary turns |
| style_RUN | float | |
| style_SPR | float | |
| style_CAP | float | |
| style_SAFE | float | |
| style_CTR | float | |
| style_DEN | float | |
| style_FLOW | float | |
| style_HOME | float | |
| style_FIN | float | |

---

## 6. Style Vector

The most analytically useful per-player output. For each discretionary turn (2+ legal moves), take the feature vector of the chosen move. Average these vectors across all discretionary turns in the game.

```
style_vector[k] = mean(chosen_move_features[k]) over all discretionary turns
```

This produces a 10-dimensional fingerprint of how each player *actually played*, regardless of their assigned profile. For AI players it should closely match their profile weight vector (modulo phase modifiers and opportunity availability). For human players it reveals their implicit strategy.

**What to do with it:**

- Compare a human player's style vector to the 8 profile vectors using cosine similarity or Euclidean distance to find their "nearest AI match"
- Check that AI profiles have distinguishable style vectors (profile distinguishability — the spec targets macro-F1 ≥ 0.80 for a classifier predicting profile from style vector)
- Track style drift across a player's games over time

---

## 7. Derived Analysis Metrics

Computed from the CSV after accumulating multiple games. These are not stored per-game — they're calculated in whatever spreadsheet or analysis tool you prefer.

| Metric | Formula | What it tests |
|---|---|---|
| Win rate by profile | wins / games for each player_type | Which profiles win more |
| Extra-roll advantage | sixes_rolled − avg(opponents sixes_rolled) | Whether 6s explain wins |
| Capture efficiency | captures_made / (turns where has_capture = true) | True aggression rate |
| Shortcut value | center_exit rate among profiles that enter often vs. those that avoid | Whether shortcut is worth it |
| Seat advantage | win rate by slot index | First-player edge |
| Style-to-win correlation | Pearson correlation of each style_* column with won | Which dimension associates with winning |
| Lucky vs. strategic wins | wins where sixes_rolled > 75th percentile vs. wins where style matched profile and normal dice | Dice vs. decisions |

### Critical distinction: rate vs. count

Always prefer rates over counts for cross-game comparison:

- **Don't use**: "Player captured 3 times and won" (could be 3 opportunities and 3 choices, or 10 opportunities and 3 choices)
- **Do use**: `capture_conversion_rate = 3/3 = 1.0` vs. `3/10 = 0.3` — dramatically different profiles

---

## 8. Integration with the Game Loop

### 8.1 Where stats are computed

In `play.py`'s `take_turn()`, after the chosen move is determined but before `apply_move()`:

```python
if settings.get("track_stats") and chosen is not None:
    from wahoo.stats import compute_turn_record
    tr = compute_turn_record(
        game_id=settings["game_id"],
        turn_index=len(recording["entries"]),
        state_before=state,         # before apply_move
        player=player,
        player_type=settings["players"][player],
        roll=roll,
        roll_index=roll_index,
        all_moves=moves,
        chosen_move=chosen,
    )
    # Embed in the recording as a turn_detail event
    append_recording_entry(recording, state, {
        "type": "turn_detail",
        **asdict(tr),   # or manually serialize
    })
```

### 8.2 Post-game report

At the end of `main()` when a winner is declared:

```python
if settings.get("track_stats"):
    from wahoo.stats import compile_game_stats, print_game_report, append_stats_csv
    summary = compile_game_stats(recording)
    print_game_report(summary)
    append_stats_csv(summary, settings.get("stats_csv", "wahoo_stats.csv"))
```

### 8.3 Settings flags

```python
settings = {
    "auto_roll": False,
    "players": ["human", "human", "human", "human"],
    "track_stats": True,        # default True; disable with --no-stats flag
    "stats_csv": "wahoo_stats.csv",
    "game_id": "game7",         # from make_recording_path()
}
```

---

## 9. `selfplay.py` Integration

`selfplay.py` should always track stats and append to the CSV. Over 500+ games it builds the primary dataset for trend analysis.

```
python -m wahoo.selfplay --games 500 --players balanced assassin tortoise random \
  --stats wahoo_stats.csv
```

With 500 games, each profile plays ~125 games. That's enough to compute stable win rates and style vectors, and to start detecting which strategy dimensions correlate with winning under random dice.

---

## 10. Minimum Viable Version

If full per-candidate feature recording feels heavy, start with this minimal subset:

**Per-turn:** `player`, `player_type`, `roll`, `forced_move`, `chosen_kind`, `capture_made`, `center_entered`, `home_move_made`, `exit_base_made`, opportunity flags.

**Per-player per-game:** `won`, `captures_made`, `captures_suffered`, `center_entries`, `base_exit_on_6_rate`, `capture_conversion_rate`.

This supports the most important analysis questions without requiring `compute_features()` to be called on every candidate move. Add the style vector later once `ai.py` is in place and `compute_features()` is already running.

---

## 11. Files Created or Modified

| File | Change |
|---|---|
| `wahoo/stats.py` | New — `TurnRecord`, `PlayerGameStats`, `GameSummary`, compute/report/export functions |
| `wahoo/play.py` | Add stats hook in `take_turn()`, post-game report call, `settings["track_stats"]` |
| `wahoo/selfplay.py` | Pass `--stats` flag through to CSV writer |
| `wahoo_stats.csv` | Generated — accumulates one row per player per game |
| `documents/STAT_TRACKING_PLAN.md` | This document |
