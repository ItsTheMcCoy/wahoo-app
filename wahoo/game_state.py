"""
Wahoo game state.

Board model:
- 4 players (0..3), each owns a 14-square segment of the loop.
- Loop is 56 squares total, indexed 0..55. Player p's base-exit is at p*14.
- Each player segment runs base_exit (offset 0) through offset 13, then
  the next square is the next player's base_exit (offset 0 of segment p+1).
- Each player has a home stretch of 4 slots (indices 0..3), entered from
  the loop at the square immediately before their own base-exit
  (i.e., (p*14 - 1) mod 56 = previous player's offset 13).
- Center hole: a single off-loop position holding at most one marble.

A marble's location is one of:
  ("BASE",)            in the start pen
  ("TRACK", i)         on the loop at absolute index i (0..55)
  ("HOME", j)          in own home stretch at slot j (0..3)
  ("CENTER",)          in the center hole
"""

from dataclasses import dataclass, field
from typing import Optional

LOOP_SIZE = 56
SEGMENT_LEN = 14
HOME_SLOTS = 4
MARBLES_PER_PLAYER = 4
NUM_PLAYERS = 4


def base_exit(player: int) -> int:
    """Absolute loop index where this player's marbles enter the track."""
    return player * SEGMENT_LEN


def home_entry(player: int) -> int:
    """Loop square immediately before this player's base-exit; marble turns
    into home from here rather than continuing onto base-exit."""
    return (player * SEGMENT_LEN - 1) % LOOP_SIZE


def center_exit_dest(player: int) -> int:
    """Where a marble lands when it exits center on a roll of 1.
    Rule: offset 5 of the previous player's segment."""
    prev_player = (player - 1) % NUM_PLAYERS
    return prev_player * SEGMENT_LEN + 5


def segment_offset(player: int, loop_idx: int) -> int:
    """How far loop_idx is along the given player's own segment, 0..13.
    Negative/wraparound returns are normalized into 0..55 first."""
    return (loop_idx - base_exit(player)) % LOOP_SIZE


# A Location is a tuple. Helpers to construct/inspect:

def loc_base() -> tuple:
    return ("BASE",)

def loc_track(i: int) -> tuple:
    return ("TRACK", i)

def loc_home(j: int) -> tuple:
    return ("HOME", j)

def loc_center() -> tuple:
    return ("CENTER",)


@dataclass
class GameState:
    # marbles[player][marble_id] = Location tuple
    marbles: list = field(default_factory=lambda: [
        [loc_base() for _ in range(MARBLES_PER_PLAYER)]
        for _ in range(NUM_PLAYERS)
    ])
    current_player: int = 0
    pending_roll: Optional[int] = None
    # center_occupant: (player, marble_id) or None. Redundant with marbles
    # but makes capture checks O(1).
    center_occupant: Optional[tuple] = None
    # For auto-exit behavior: which marble id to prefer next when multiple
    # base-exit moves are auto-selected.
    next_base_exit_marble: list = field(default_factory=lambda: [0] * NUM_PLAYERS)

    def marble_at_track(self, loop_idx: int) -> Optional[tuple]:
        """Return (player, marble_id) of marble at this loop square, or None."""
        for p in range(NUM_PLAYERS):
            for m in range(MARBLES_PER_PLAYER):
                loc = self.marbles[p][m]
                if loc[0] == "TRACK" and loc[1] == loop_idx:
                    return (p, m)
        return None

    def marble_at_home(self, player: int, slot: int) -> Optional[int]:
        """Return marble_id at given home slot for given player, or None.
        (Home slots can only be occupied by their owner.)"""
        for m in range(MARBLES_PER_PLAYER):
            loc = self.marbles[player][m]
            if loc[0] == "HOME" and loc[1] == slot:
                return m
        return None

    def player_won(self, player: int) -> bool:
        """Player wins when all 4 marbles are in home stretch (any slots)."""
        return all(
            self.marbles[player][m][0] == "HOME"
            for m in range(MARBLES_PER_PLAYER)
        )

    def clone(self) -> "GameState":
        """Deep copy for AI simulation later."""
        new = GameState()
        new.marbles = [list(row) for row in self.marbles]  # tuples are immutable
        new.current_player = self.current_player
        new.pending_roll = self.pending_roll
        new.center_occupant = self.center_occupant
        new.next_base_exit_marble = list(self.next_base_exit_marble)
        return new


def format_location(loc: tuple) -> str:
    """Human-readable location string."""
    if loc[0] == "BASE":
        return "base"
    if loc[0] == "TRACK":
        return f"track:{loc[1]}"
    if loc[0] == "HOME":
        return f"home:{loc[1]}"
    if loc[0] == "CENTER":
        return "center"
    return f"?{loc}"
