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
- Enter `S` to start a new game or `E` to exit.
- Each player rolls once to determine who goes first.
- Highest roll starts. Play order then continues clockwise.

## Replay a Saved Game

Each new game writes its own history file automatically using a unique name like:

```text
wahoo_history_20260524_153012_123456.json
```

To replay a saved game:

```powershell
python play.py replay wahoo_history_20260524_153012_123456.json
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