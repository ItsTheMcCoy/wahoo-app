# Wahoo — Game Specification

This document is the authoritative reference for the rules, board, and data model of the Wahoo app. It is intended as input to AI coding assistants (Cowork, Claude Code, etc.) building game logic and computer opponents. If this document and the code disagree, **this document wins** — fix the code.

---

## 1. Game Overview

Wahoo is a turn-based race game for **4 players**. Each player controls **4 marbles** that begin in the player's *base* (start pen) and must travel around a shared track and into the player's own *home* row. The first player to get all 4 marbles into home wins.

Movement is driven by **one six-sided die**, with frequent opportunities to capture opponents and one risky high-value shortcut through the center of the board.

---

## 2. Board

### 2.1 Physical Layout

The play area forms a **plus sign** (cross shape). Each of the four arms of the plus belongs to one player. Players sit at the tips of the four arms.

For each player's arm, walking from the tip toward the center:

- The **base** (a 2×2 cluster of 4 holes) sits outside the play track, beside the arm's tip.
- The arm itself is part of the shared **track**.
- A **home row** of 4 slots runs parallel to the arm's inward spoke, leading from the track inward toward the center.

The **center hole** sits at the geometric middle of the plus, where the four arms meet. It is off the loop.

### 2.2 Track Structure

The track is a **closed loop of 56 squares**. It traces the outline of the plus sign.

Each player owns a 14-square segment of the loop. Walking forward from a player's base-exit square:

| Offset | Description |
|--------|-------------|
| 0 | Base-exit square (adjacent to base) |
| 1–5 | Continuing the inward spoke toward center (5 more squares) |
| 6 | First square of the armpit (after 90° turn) |
| 7–10 | Across the armpit between arms (4 more squares) |
| 11 | First square of the outward spoke toward next player's base (after 90° turn) |
| 12–13 | Outward spoke continuing toward next player's base (2 more squares) |
| (14) | = Offset 0 of the next player's segment |

So: 6 squares of inward spoke + 5 squares of armpit + 3 squares of outward spoke = 14 squares per segment × 4 players = **56 squares total**.

### 2.3 Direction of Travel

Movement around the loop is in one fixed direction (incrementing loop index modulo 56). All players move in the same direction.

### 2.4 Key Absolute Positions

For player `p` (in `0..3`):

| Constant | Formula | Meaning |
|----------|---------|---------|
| `base_exit(p)` | `p * 14` | Where marbles enter the loop from base |
| `home_entry(p)` | `(p * 14 − 1) mod 56` | Square immediately before own base-exit; forced home turn happens *after* this square |
| `center_exit_dest(p)` | `((p − 1) mod 4) * 14 + 5` | Where a marble lands when exiting center on a roll of 1 |

Concrete values:

| Player | base_exit | home_entry | center_exit_dest |
|--------|-----------|------------|------------------|
| 0 | 0 | 55 | 47 |
| 1 | 14 | 13 | 5 |
| 2 | 28 | 27 | 19 |
| 3 | 42 | 41 | 33 |

### 2.5 Marble States

A marble is in exactly one of four locations:

| Location | Meaning |
|----------|---------|
| `BASE` | In the player's start pen, awaiting exit |
| `TRACK(i)` | On the loop at absolute index `i` in `0..55` |
| `HOME(j)` | In own home row at slot `j` in `0..3` (0 = entry, 3 = deepest) |
| `CENTER` | In the center hole |

The home row is owned by exactly one player; only that player's marbles may occupy its slots.

---

## 3. Setup

- 4 players, 4 marbles each. All marbles start in `BASE`.
- The center hole starts empty.
- A starting player is chosen by any agreed method (high die roll, etc.). After that, turns proceed in fixed clockwise order: 0 → 1 → 2 → 3 → 0.

---

## 4. Turn Structure

1. The current player **rolls one d6**.
2. The player examines all of their legal moves for that roll.
3. **If at least one legal move exists, the player must take one** (must-move rule). The player chooses which legal move if multiple are available.
4. **If no legal moves exist, the turn passes** with no marble moved.
5. **If the roll was a 6, the player rolls again** (regardless of whether they had any legal move). There is no cap on consecutive 6s.
6. Otherwise, play passes to the next player.

The die is never split across multiple marbles. A single roll moves a single marble (or, if no legal move, nothing).

---

## 5. Movement Rules

### 5.1 Exiting Base

- A marble may exit `BASE` only on a roll of **1 or 6**.
- It lands on the player's `base_exit` square (offset 0). The roll value is "spent" on the exit itself; the marble does *not* advance further on a 6.
- If an opponent's marble is on the base-exit square, it is **captured** (sent to its own `BASE`).
- If the player's own marble is on the base-exit square, the exit is **illegal** (blocked).

### 5.2 Advancing on the Track

- A marble moves forward exactly `roll` squares along the loop (in the fixed direction, modulo 56).
- A marble **cannot land on or pass over a marble of the same color**. If the player's own marble sits on any of the squares it would cross or land on, the move is illegal.
- A marble **may land on an opponent's marble**, which **captures** the opponent (sent to opponent's `BASE`).
- A marble **may pass over** an opponent's marble without effect. Capture only happens on landing.

### 5.3 The Home-Entry Square

The home-entry square is a **normal track square** with one extra rule that applies *only* to its owner's marbles:

- For non-owners: home-entry is just another loop square. Landing on it captures; passing over it does nothing special.
- For the owner:
  - **Landing exactly on home_entry** is a normal track landing (captures opponent if present; marble stays on the track at that square).
  - **Passing over home_entry** (i.e., taking another step beyond it in the same move) forces the marble to **divert into home slot 0** instead of continuing along the loop. The remaining steps of the roll are spent climbing the home column.
  - If the forced home turn cannot be completed (because the marble would overshoot home slot 3, or because an own marble blocks the path within the home column), **the entire move is illegal**. Owner marbles cannot loop past their own home entry.

This combined rule means an owner can land on home-entry and stop, but cannot continue past it on the loop.

### 5.4 Home Row

- Home slots are indexed 0 (entry, adjacent to the loop) through 3 (deepest, the win position).
- A marble in `HOME(j)` may advance to `HOME(j + roll)` if and only if:
  - `j + roll ≤ 3` (no overshooting), and
  - No own marble occupies any slot in the range `j+1 .. j+roll` (no landing on or passing own marbles).
- **Exact roll is required to land in any home slot.** A marble cannot bounce back; if there's no legal advance, the marble must stay put (and another marble may be moved instead if it has a legal move).
- Marbles in home cannot be captured. Home slots are safe.

### 5.5 The Center Hole

The center hole holds **at most one marble** at a time.

**Entering center:**

- A marble may enter center only from one of the **first 6 squares of its own segment** (offsets 0 through 5).
- The required roll is `6 − offset`:

| Marble offset | Required roll |
|---------------|---------------|
| 0 | 6 |
| 1 | 5 |
| 2 | 4 |
| 3 | 3 |
| 4 | 2 |
| 5 | 1 |

- Entering center is **always optional**. When the trigger condition is met, the player may choose to enter center *or* advance along the track normally. (Both options are added to the legal-move list.)
- If the center is occupied by an opponent's marble, entering center **captures** that opponent.
- A player cannot enter center if their own marble is already there.

**Exiting center:**

- A marble in center may exit only on a roll of **1**.
- It lands on the `center_exit_dest` square for its player (see §2.4): the **5th offset square of the previous player's segment**. Geometrically this is the last square of the previous player's inward spoke, adjacent to center.
- If an opponent's marble occupies the destination, that opponent is **captured**.
- If the player's own marble occupies the destination, the exit is **illegal** (blocked).

**Strategic implications (not rules, just consequences):**

- The center entry window for each marble is a **one-shot opportunity** per lifetime. Once a marble passes its own offset 5, it cannot return to the entry zone until it has either reached home or been captured.
- A marble taking the shortcut saves approximately 38–43 squares of travel compared to going the long way around. The shortcut is valuable but risky: while in center, a marble can be captured by the next opponent to roll the matching value from one of their entry squares.

### 5.6 Capture

When a marble is captured, it is moved immediately to its owner's `BASE`. The capturing marble takes the captured marble's position.

Capture can occur in any of these situations:

- Exiting base onto an opponent on the base-exit square.
- Advancing on the loop and landing on an opponent.
- Landing on home-entry as the owner with an opponent already there.
- Passing home-entry as the owner with an opponent there (capture happens on the way through, then the forced home turn applies to the moving marble).
- Entering center with an opponent already in center.
- Exiting center onto an opponent on the destination square.

Marbles in `HOME` cannot be captured. Marbles in `BASE` cannot be captured (they are already in base).

---

## 6. Winning

A player wins immediately when **all 4 of their marbles are in `HOME`** (in any of the 4 home slots). The home slots do not need to be filled in any particular order, and the player does not need to fill all 4 slots — they only need every marble to be somewhere in their home row.

The game ends as soon as one player wins. Other players' final positions are not ranked.

---

## 7. Data Model (Reference Implementation)

The Python reference implementation lives in `game_state.py` and `rules.py`. The model is the same one any AI implementation should target.

### 7.1 `GameState`

```python
@dataclass
class GameState:
    marbles: list           # marbles[player][marble_id] = Location tuple
    current_player: int     # 0..3
    center_occupant: Optional[tuple]  # (player, marble_id) or None
```

Locations are tagged tuples: `("BASE",)`, `("TRACK", i)`, `("HOME", j)`, `("CENTER",)`.

### 7.2 `legal_moves(state, player, roll) -> list[Move]`

Returns all legal moves for `player` with the given `roll`. Empty list means no legal move (turn passes).

A `Move` is a dict:

```python
{
  "marble": int,            # marble id 0..3
  "dest": tuple,            # destination Location
  "kind": str,              # see kinds below
  "captures": tuple | None, # (player, marble_id) sent to base, if any
}
```

Move `kind` values:

| Kind | When |
|------|------|
| `exit_base` | Marble leaves base for the base-exit square |
| `advance` | Marble moves along the loop and lands on a track square |
| `enter_center` | Marble takes the center shortcut |
| `exit_center` | Marble leaves center to a track square |
| `enter_home` | Marble crosses home-entry and lands in home slot 0 |
| `advance_home` | Marble moves to a deeper home slot (entering past slot 0, or moving within home) |

### 7.3 `apply_move(state, move) -> GameState`

Mutates `state` in place to reflect the move. Resolves capture (sending the captured marble to its base), moves the marble to its destination, and updates `center_occupant`. **Does not** handle turn advancement or re-rolls — that lives in the game loop.

### 7.4 Turn Loop (Pseudocode)

```
while no player has won:
    player = state.current_player
    while True:
        roll = d6()
        moves = legal_moves(state, player, roll)
        if moves:
            chosen = pick_move(moves)   # human input or AI
            apply_move(state, chosen)
            if state.player_won(player):
                return player
        if roll != 6:
            break
    state.current_player = (player + 1) % 4
```

---

## 8. AI Design Notes

This section is for AI authors building computer opponents. It establishes vocabulary and identifies the design space, without prescribing a specific algorithm.

### 8.1 Action Space

An AI plays by implementing a `choose_move(state, moves) -> Move` function. The action space is small and discrete: typically 0–4 moves to choose from per turn, occasionally more when multiple marbles have legal moves. There is no continuous control.

### 8.2 Randomness Model

The die roll is the sole source of stochasticity. From a given state, the distribution of next states under a given player's turn is:

- With probability 1/6 each, one of rolls 1–6 occurs.
- A roll of 6 grants an additional roll, making the *effective* turn length variable (geometric distribution capped only by no-legal-move scenarios).

For tree search algorithms (expectimax, MCTS): chance nodes have 6 outcomes weighted equally. Re-rolls extend the same player's turn rather than passing to the opponent.

### 8.3 State Features Worth Computing

These are features an evaluation function or heuristic might use. They're not rules — they're handles for AI reasoning:

- **Progress per marble**: distance traveled toward home, measured in squares. A marble in `BASE` has 0 progress; a marble in `HOME(3)` has maximum progress.
- **Total player progress**: sum of progress across all 4 marbles. Crude but informative.
- **Marbles in home**: count of own marbles in `HOME` (the win condition is 4).
- **Marbles in base**: count of own marbles still in `BASE` (need at least one 1-or-6 roll to free each).
- **Shortcut availability**: which own marbles are still within their first 6 track squares (eligible for center entry).
- **Center status**: empty, own marble, or opponent in center.
- **Capture exposure**: for each own marble on the loop, the set of opponent (loop position, roll) pairs that could capture it on the opponent's next turn.
- **Capture opportunity**: for each opponent marble on the loop, the (own marble, roll) pairs that could capture it.

### 8.4 Strategic Trade-offs

The game has several genuine tactical tensions that an AI must navigate:

- **Spreading vs. consolidating**: getting more marbles onto the track reduces risk of being stuck on a roll that doesn't free a base marble, but each marble on the track is exposed to capture.
- **Center risk/reward**: the center shortcut saves enormous travel time but the marble in center is vulnerable to capture on every opponent's turn until it exits.
- **Capture vs. progress**: when both options are available, capturing sets back an opponent but the capturing marble is often left in a vulnerable forward position. Sometimes the right play is to advance a safer marble.
- **Home-entry positioning**: parking an opponent on your own home-entry square is uncomfortable for them (you'll capture them on most rolls) but they may be forced to stay there if no other moves exist.
- **Blocking**: own marbles act as blockades against the player's own other marbles too. Stringing marbles too close together can prevent advancement.

### 8.5 Difficulty Tiers

Suggested progression of AI strength:

1. **Random**: pick any legal move uniformly at random. Baseline opponent; surprisingly playable for casual humans and useful as a sanity check during development.
2. **Greedy heuristic**: score each move by a hand-crafted utility (e.g., `+10 for capture, +5 for entering center, +1 per square of progress, -8 for landing on a high-capture-exposure square`) and pick the highest. Decent club-level opponent with very little code.
3. **One-ply expectimax**: for each legal move, simulate the opponent's next turn over all 6 rolls and assume they play their best heuristic move. Pick the move maximizing expected own score. Noticeably stronger; still cheap.
4. **Multi-ply expectimax / MCTS**: search deeper. Branching is manageable because the action space is small, but re-roll chains can extend turns significantly. Pruning likely needed.
5. **Trained policy (RL)**: self-play with a learned evaluator. Likely overkill for a hobby project but the game is small enough to make it feasible.

### 8.6 Practical Notes for Implementation

- The reference `rules.py` is the canonical source for what is and isn't legal. AI authors should call `legal_moves()` rather than re-implementing move generation.
- `GameState.clone()` exists specifically to support simulation. It's a shallow clone of the marbles list-of-lists; locations are immutable tuples so sharing is safe.
- The current implementation does not separate "current player turn" from "roll outcome." For expectimax, an AI author may need to extend the API to support "given state, what's the distribution of (resulting_state, next_player) across the 6 dice outcomes?" — including correctly threading re-rolls.
- There is no hidden information. Wahoo is a perfect-information game (modulo the upcoming die roll). All evaluation and search can operate on fully visible state.

---

## 9. Edge Cases and Clarifications

Documented here to remove ambiguity. These are consequences of the rules above, called out explicitly because they have come up during design.

- **No legal move + roll of 6**: the player still rolls again. The 6 grants re-roll regardless of whether the previous roll resulted in a move.
- **Multiple legal moves to the same destination**: not possible. Each (marble, destination, kind) tuple is unique within a turn's move list.
- **Choosing not to take the center shortcut**: legal. Both the center-entry move and the normal-advance move appear in the move list when the trigger condition is met; the player picks either.
- **Opponent parked on your home-entry square**: the opponent is fully exposed. On your turn, any roll that lands you on home-entry captures them (normal track land), and any roll that passes over home-entry also captures them (the way-through capture), with the forced home turn applying to your moving marble after the capture.
- **Center exit blocked by own marble**: the exit move is illegal. The marble must wait in center for another roll of 1 *and* a clear destination square. (This is rare but possible if a player's own marble lands on `center_exit_dest` and stays there.)
- **Marble in home cannot be moved if any advance overshoots**: if a marble is in `HOME(2)` and the player rolls a 3, that marble has no legal move. The player must move a different marble or pass the turn.
- **Win triggers immediately**: the moment a move puts a player's last out-of-home marble into a home slot, that player wins. The current turn does not continue (no further re-rolls processed).

---

## 10. Glossary

- **Base** — A player's start pen, holding marbles that have not yet entered the track.
- **Base-exit square** — The track square immediately adjacent to a player's base; offset 0 of their segment.
- **Home / home row** — A player's 4-slot column where marbles end the race. Owned by one player.
- **Home-entry square** — The track square immediately before a player's own base-exit; the square from which the forced home turn occurs.
- **Center / center hole** — The single off-loop position at the middle of the board. Holds one marble.
- **Capture** — Sending an opponent's marble back to its base by landing on or passing it under the rules above.
- **Segment** — The 14-square portion of the loop owned by one player.
- **Offset** — Distance along a player's own segment, 0–13. Differs from absolute loop index by an additive constant per player.
- **Re-roll** — The additional die roll granted to a player after rolling a 6. Unlimited consecutive re-rolls are permitted.
- **Must-move rule** — When at least one legal move exists, the player must take one of them.
