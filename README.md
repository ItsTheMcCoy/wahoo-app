# Wahoo Text Game

Console-based Wahoo implementation for 4 players.

## Requirements

- Python 3.10+

## Run the Game

From the project folder:

```powershell
python play.py
```

Startup flow:

- ASCII-art intro is shown first.
- Choose one of the intro menu options shown on separate lines:
	- `S` to start a new game
	- `C` to run computer self-play (all players are computer-controlled)
	- `R` to replay a saved game
	- `E` to exit
- Type `/auto` at any prompt to toggle auto-roll on or off.
- Each player rolls once to determine who goes first.
- Highest roll starts. Play order then continues clockwise.

Auto-roll behavior:

- When auto-roll is ON, the game rolls automatically for turns.
- If a roll produces more than one legal move, you still choose the move manually.

Computer self-play behavior:

- Computer move priority is: capture, then exit base, then get home.
- Center entry is only chosen when the current player has at least one other marble already in play.

## Replay a Saved Game

Each new game writes its own history file automatically using a simple sequential name like:

```text
game1.json
game2.json
game3.json
```

To replay a saved game:

```powershell
python play.py replay game3.json
```

Replay behavior:

- Each recorded board state is displayed in order.
- The recorded event summary for that state is shown below the board.
- Press Enter to step to the next recorded state.

## Continue a Replayed Game

At the end of replay, the game prompts you to either continue or exit replay.

- Enter `C` to continue the replayed game from its last saved state.
- Enter `E` to exit replay.

If you continue:

- The loaded game state becomes the active live game.
- New moves are appended to the same history JSON file.

## Tests

Run the test suite with:

```powershell
python tests.py
```

## Notes

- Game history is recorded after each resolved roll/move.
- Replay is useful for reproducing specific board states and verifying rule behavior.