# Wahoo Strategy Metric Tracking Plan — Agent Build Specification

## Purpose

Create a metric tracking plan for evaluating which Wahoo gameplay strategies improve the chance of winning.

This document is intended to be provided to an LLM agent. The agent should use it to design a practical, repeatable system for collecting, analyzing, and comparing Wahoo gameplay data across multiple games.

The goal is not just to track who wins. The goal is to identify which decisions, board states, and strategy patterns are associated with winning more often.

---

## Game Context

Use the attached Wahoo rules as the source of truth for gameplay mechanics. The strategy tracking plan must account for the following rules and mechanics:

- Each player has 4 marbles.
- The goal is to be the first player to get all 4 marbles into the home row.
- A player must make a legal move if one exists.
- Rolling a 6 grants another roll.
- A 1 or 6 can move a marble from base to the player’s starting square.
- On the main track, a marble must move exactly the number rolled.
- A player cannot land on or pass over their own marbles.
- Landing on an opponent’s marble sends that opponent marble back to base.
- Opponent marbles may be passed without capture.
- Marbles entering or moving within home require legal exact movement and cannot overshoot.
- Marbles in home are safe from capture.
- The center shortcut is optional.
- A marble can enter the center only from the first 6 squares after leaving base and only with the exact roll that lands it on the 6th square.
- A marble exits the center only by rolling a 1.
- The center can hold only one marble; another player entering the center bumps the current center marble back to base.
- Each marble gets only one opportunity window to use the center shortcut per trip around the board.

---

## Primary Evaluation Questions

The tracking plan should allow analysis of these strategy questions:

1. Does bringing a marble out of base on a roll of 6 improve win rate compared to advancing an existing marble?
2. Does using the center shortcut improve win rate?
3. When the center shortcut is available, is it usually better to take it or decline it?
4. Does an aggressive capture strategy improve win rate?
5. Does racing one marble toward home outperform keeping multiple marbles active?
6. Does having more active marbles increase flexibility enough to offset capture risk?
7. How much do extra rolls from 6s explain wins?
8. How much do captures suffered explain losses?
9. Do own-marble blocking situations reduce win probability?
10. Does prioritizing home entry improve win rate compared to offensive or positioning moves?
11. Are some board states strongly associated with winning or losing?
12. Which decisions create short-term gains but long-term disadvantages?

---

## Tracking Philosophy

The plan should distinguish between four types of data:

1. **Luck metrics** — what the dice gave the player.
2. **Opportunity metrics** — what legal or strategic choices were available.
3. **Decision metrics** — what the player chose.
4. **Outcome metrics** — what happened immediately, later in the game, and by the end of the game.

The analysis should avoid treating raw outcomes as strategy evidence unless they are tied to the opportunities and decisions that created them.

For example:

- “Player got 3 marbles home” is useful but incomplete.
- “Player chose to exit base on 6 in 5 of 6 opportunities and got 3 marbles home” is more useful.
- “Player declined the center shortcut 4 times and won” is useful only if compared against similar opportunities where the shortcut was taken.

Recommended model:

```text
Decision → Board Effect → Marble Progress → Game Outcome
```

---

## Required Output From the LLM Agent

The agent should produce a complete metric tracking plan that includes:

1. A game-level tracking sheet.
2. A player-level tracking sheet.
3. A turn-level or decision-level tracking sheet.
4. A center-shortcut-specific tracking section.
5. A capture tracking section.
6. A marble-progress tracking section.
7. A strategy classification system.
8. Derived metrics and formulas.
9. Recommended dashboards or summary views.
10. Recommended minimum viable tracking version.
11. Recommended advanced tracking version.
12. Guidance for analyzing results after multiple games.
13. A list of strategy hypotheses to test.
14. A recommended data format, preferably table-based and usable in Excel, Google Sheets, Airtable, Notion, or a lightweight database.

---

## Data Collection Levels

The plan should define metrics at these levels:

### 1. Game-Level Metrics

These describe the whole game.

Recommended fields:

| Field | Description |
|---|---|
| Game ID | Unique identifier for each game. |
| Date played | Date of the game. |
| Number of players | Usually 4, but track explicitly. |
| Player order | Seat/order of play for each player. |
| Winner | Winning player. |
| Winning seat position | Whether the winner went 1st, 2nd, 3rd, or 4th. |
| Total rounds | Number of full rounds completed. |
| Total turns | Total turns taken by all players. |
| Total rolls | Total rolls, including extra rolls from 6s. |
| Game duration | Optional real-world time duration. |
| Notes | Unusual rule clarifications, disputes, or anomalies. |

### 2. Player-Level Metrics

These summarize each player’s game.

Recommended fields:

| Field | Description |
|---|---|
| Game ID | Links player record to game. |
| Player ID/name | Player identifier. |
| Seat position | Turn order. |
| Win/loss | Whether this player won. |
| Final marbles in home | Number of marbles in home at game end. |
| Final marbles on track | Number of marbles on main track at game end. |
| Final marbles in base | Number of marbles in base at game end. |
| Total turns | Number of turns taken. |
| Total rolls | Total rolls including extra rolls. |
| Number of 1s rolled | Relevant to base exit and center exit. |
| Number of 6s rolled | Relevant to base exit and extra turns. |
| Extra rolls earned | Usually equal to number of 6s rolled. |
| No-legal-move turns | Turns where no move could be made. |
| Forced-move turns | Turns where only one legal move existed. |
| Multi-option turns | Turns where more than one legal move existed. |
| Captures made | Opponent marbles sent to base. |
| Captures suffered | Player’s marbles sent to base. |
| Net captures | Captures made minus captures suffered. |
| Center attempts | Number of times player entered center. |
| Center successful exits | Number of center marbles that exited. |
| Center bumps suffered | Number of times player was bumped from center. |
| Center-to-home successes | Shortcut marbles that eventually reached home. |
| Base exits on 1 | Number of base exits using 1. |
| Base exits on 6 | Number of base exits using 6. |
| Base exits declined on 6 | Times base exit was available on 6 but not chosen. |
| Own-blocking events | Times player could not move because of own marble blockage. |

### 3. Turn-Level Metrics

Turn-level data is more detailed but gives better strategy analysis.

Recommended fields:

| Field | Description |
|---|---|
| Game ID | Links turn to game. |
| Round number | Round in which turn occurred. |
| Turn number | Sequential turn number. |
| Player ID/name | Player taking the turn. |
| Roll number within turn | 1 for normal roll, 2+ after rolling 6. |
| Die roll | Number rolled. |
| Extra roll earned | Whether roll was a 6. |
| Legal move available | Yes/no. |
| Number of legal moves | Count of legal marble moves. |
| Forced move | Yes/no. |
| Chosen marble ID | Which marble moved. |
| Starting location type | Base, track, center, home. |
| Ending location type | Base, track, center, home. |
| Move type | Base exit, advance, capture, enter center, exit center, enter home, advance in home, forced pass. |
| Capture made | Yes/no. |
| Captured player | If capture occurred. |
| Captured marble distance/progress | Approximate progress lost by captured marble. |
| Capture suffered | Yes/no, if current move caused center bump against this player in a broader event model. |
| Shortcut opportunity available | Yes/no. |
| Shortcut chosen | Yes/no. |
| Shortcut declined | Yes/no. |
| Base exit available | Yes/no. |
| Base exit chosen | Yes/no. |
| Base exit declined | Yes/no. |
| Home move available | Yes/no. |
| Home move chosen | Yes/no. |
| Own marble blocked move | Yes/no. |
| Result note | Short description of meaningful effect. |

---

## Marble Progress Metrics

Marble progress metrics are useful, but they should be treated as outcome metrics that must be tied back to decisions and opportunities.

### Required Marble-Level Fields

Each marble should have a stable identifier, such as Blue-1, Blue-2, Blue-3, Blue-4.

Recommended fields:

| Field | Description |
|---|---|
| Game ID | Links marble to game. |
| Player ID/name | Owner. |
| Marble ID | Stable marble identifier. |
| First exit round | Round when marble first left base. |
| First exit roll | Whether it exited on 1 or 6. |
| Used center shortcut | Yes/no. |
| Center entry round | If used. |
| Center exit round | If exited successfully. |
| Bumped from center | Yes/no. |
| Captures made by this marble | Count. |
| Times captured | Count. |
| Reached home | Yes/no. |
| Round reached home | Round when it first entered home. |
| Final state | Base, track, center, home. |

### Useful Marble Progress Metrics

| Metric | Use |
|---|---|
| First marble out round | Measures early tempo. |
| First marble home round | Measures successful advancement speed. |
| Second/third/fourth marble home round | Measures consistency of progress. |
| Active marbles by round | Helps compare “spread out” vs “race one marble” strategies. |
| Average active marbles per round | Measures board presence. |
| Marbles stranded near home | Measures difficulty finishing due to exact-roll requirements. |
| Marbles captured after high progress | Measures high-value losses. |
| Marbles safely converted to home | Measures successful risk management. |

---

## Center Shortcut Metrics

The center shortcut should be tracked as a strategy subsystem, not just as a move type.

### Required Center Shortcut Fields

For every shortcut opportunity:

| Field | Description |
|---|---|
| Game ID | Links to game. |
| Round number | Round when opportunity occurred. |
| Player ID/name | Player with the opportunity. |
| Marble ID | Marble with opportunity. |
| Marble position in shortcut window | Square 1 through 6 after leaving base. |
| Required roll to enter center | Exact number needed. |
| Actual roll | Die roll. |
| Opportunity valid | Yes/no. |
| Shortcut chosen | Yes/no. |
| Shortcut declined | Yes/no. |
| Reason declined | Optional subjective note. |
| Center occupied before move | Yes/no. |
| Player occupying center | If occupied. |
| Opponent bumped from center | Yes/no. |
| Later exited center | Yes/no. |
| Turns spent in center | Count. |
| Bumped from center later | Yes/no. |
| Eventually reached home | Yes/no. |
| Captures made after shortcut | Count after exiting center. |
| Captures suffered after shortcut | Count after exiting center. |
| Final shortcut outcome | Reached home, bumped to base, still on track, still in center, captured later. |

### Derived Center Shortcut Metrics

| Metric | Formula |
|---|---|
| Shortcut take rate | Shortcut attempts / shortcut opportunities. |
| Shortcut decline rate | Shortcut declines / shortcut opportunities. |
| Center exit success rate | Successful center exits / shortcut attempts. |
| Center bump rate | Center bumps suffered / shortcut attempts. |
| Shortcut-to-home rate | Shortcut marbles that reached home / shortcut attempts. |
| Average turns stuck in center | Total center turns / shortcut attempts. |
| Win rate when shortcut used | Wins in games with shortcut use / games with shortcut use. |
| Win rate when shortcut declined | Wins in games with shortcut opportunities declined / games with shortcut opportunities declined. |
| Net shortcut value | Estimated spaces saved - estimated progress lost from bumps/captures - delay penalty. |

### Required Center Shortcut Analysis

The agent should compare:

- Taking the shortcut vs declining the shortcut.
- Taking the shortcut early vs later.
- Taking the shortcut when center is empty vs occupied.
- Taking the shortcut when the player has few active marbles vs many active marbles.
- Taking the shortcut when opponents are near their own shortcut windows.
- Whether center shortcut use correlates with winning after controlling for number of 6s and captures suffered.

---

## Capture Metrics

Captures should be tracked by value, not just count.

### Required Capture Fields

| Field | Description |
|---|---|
| Game ID | Links to game. |
| Round number | Round of capture. |
| Capturing player | Player who made capture. |
| Capturing marble ID | Marble that captured. |
| Captured player | Player whose marble was captured. |
| Captured marble ID | Marble sent to base. |
| Captured marble location | Main track, center, near home, etc. |
| Captured marble progress estimate | Approximate number of spaces from base/start or qualitative progress level. |
| Capture value | Low, medium, high, very high. |
| Capture move also advanced strategy? | Yes/no. |
| Capture delayed home entry? | Yes/no/unknown. |

### Suggested Capture Value Classification

| Capture Value | Description |
|---|---|
| Low | Captured marble had recently exited base. |
| Medium | Captured marble had made moderate track progress. |
| High | Captured marble was near home. |
| Very high | Captured marble was close to entering home or had used shortcut progress. |

### Derived Capture Metrics

| Metric | Formula |
|---|---|
| Captures made per game | Total captures by player. |
| Captures suffered per game | Total captures against player. |
| Net captures | Captures made - captures suffered. |
| High-value captures made | Count of high or very high captures. |
| High-value captures suffered | Count of high or very high captures suffered. |
| Capture efficiency | Captures made / capture opportunities. |
| Capture choice rate | Capture moves chosen / capture opportunities. |
| Win rate by capture strategy | Win rate grouped by aggressive, balanced, conservative capture behavior. |

---

## Decision Quality Metrics

Decision metrics should focus on actual choice points, not forced moves.

### Required Decision Points to Track

| Decision Point | Track? | Reason |
|---|---:|---|
| Base exit on 6 when available | Yes | Key strategy question. |
| Base exit on 1 when available | Optional | Often less strategically complex but still useful. |
| Shortcut chosen when available | Yes | Major risk/reward decision. |
| Shortcut declined when available | Yes | Needed for comparison. |
| Capture chosen when available | Yes | Tests aggressive strategy. |
| Home move chosen when available | Yes | Tests safety/progress strategy. |
| Move that creates own-blocking risk | Yes | Tests positional discipline. |
| Moving a leading marble vs trailing marble | Yes | Tests racing vs spreading strategy. |
| Advancing in home vs moving track marble | Optional | Tests finishing priority. |

### Base Exit on 6 Tracking

This is a priority metric.

Track every time a player rolls a 6 while at least one marble remains in base.

Fields:

| Field | Description |
|---|---|
| Game ID | Links to game. |
| Round number | Round of decision. |
| Player ID/name | Player rolling. |
| Roll | Should be 6. |
| Marble in base available | Yes/no. |
| Base exit legal | Yes/no. |
| Base exit chosen | Yes/no. |
| Alternative chosen | Advance, capture, enter center, enter home, advance in home. |
| Number of active marbles before choice | Count. |
| Number of marbles in base before choice | Count. |
| Number of marbles in home before choice | Count. |
| Immediate result | New marble out, capture, home progress, etc. |
| Result before player’s next turn | Captured, safe, enabled capture, caused block, no effect. |
| Result after one full round | Captured, safe, enabled capture, caused block, reached shortcut window, etc. |
| Final game outcome | Win/loss. |

Derived metrics:

| Metric | Formula |
|---|---|
| Base-exit-on-6 rate | Base exits on 6 / base-exit-on-6 opportunities. |
| Win rate when exiting on 6 | Wins after choosing base exit on 6 / games with base exit on 6. |
| Win rate when declining base exit on 6 | Wins after declining base exit on 6 / games with declines. |
| Capture risk after base exit | New base-exit marbles captured within one round / base exits on 6. |
| Flexibility gain after base exit | Change in average legal moves after base exit. |
| Blocking cost after base exit | Own-blocking events within next X turns after base exit. |

---

## Strategy Classification System

The agent should define strategy labels based on observed decisions. Avoid relying only on subjective labels.

Suggested strategy categories:

### 1. Base Expansion Strategy

Measures how often a player brings new marbles out when possible.

| Label | Possible Definition |
|---|---|
| Conservative expansion | Rarely exits base if another useful move exists. |
| Balanced expansion | Sometimes exits base, depending on board state. |
| Aggressive expansion | Usually exits base on 1 or 6 when available. |

### 2. Center Shortcut Strategy

| Label | Possible Definition |
|---|---|
| Shortcut avoider | Rarely takes center opportunities. |
| Selective shortcut user | Takes center only in favorable states. |
| Aggressive shortcut user | Usually takes center when available. |

### 3. Capture Strategy

| Label | Possible Definition |
|---|---|
| Conservative | Rarely chooses capture if another progress move exists. |
| Balanced | Captures when value is medium or high. |
| Aggressive | Usually captures whenever available. |

### 4. Marble Distribution Strategy

| Label | Possible Definition |
|---|---|
| Racer | Focuses on advancing one marble far. |
| Spreader | Keeps multiple marbles active. |
| Finisher | Prioritizes moving marbles into or within home. |

### 5. Blocking Avoidance Strategy

| Label | Possible Definition |
|---|---|
| Low blockage | Rarely creates own-blocking situations. |
| Moderate blockage | Some own-blocking events. |
| High blockage | Frequent own-blocking events. |

---

## Derived Metrics and Formulas

The tracking plan should include formulas such as:

| Metric | Formula |
|---|---|
| Win rate | Wins / games played. |
| Seat win rate | Wins from seat position / games from that seat. |
| Extra-roll advantage | 6s rolled by player - average 6s rolled by opponents. |
| Base-exit-on-6 rate | Base exits on 6 / opportunities to exit on 6. |
| Shortcut take rate | Shortcut attempts / shortcut opportunities. |
| Shortcut success rate | Successful center exits / shortcut attempts. |
| Shortcut-to-home rate | Shortcut marbles reaching home / shortcut attempts. |
| Capture efficiency | Captures made / capture opportunities. |
| Net capture score | Captures made - captures suffered. |
| High-value net capture score | High-value captures made - high-value captures suffered. |
| Flexibility score | Average number of legal moves per non-pass turn. |
| Forced-move rate | Forced moves / turns with legal moves. |
| No-move rate | No-legal-move turns / total turns. |
| Own-blocking rate | Own-blocking events / total turns. |
| Home conversion rate | Marbles entering home / marbles reaching near-home zone. |
| Progress efficiency | Marbles home / total rolls. |
| Roll luck index | Weighted score based on useful 1s and 6s. |

---

## Recommended Minimum Viable Tracking Plan

If full turn-level tracking is too much, start with a simplified per-player scorecard.

### Minimum Game-Level Fields

- Game ID
- Date
- Player order
- Winner
- Total rounds

### Minimum Player-Level Fields

- Player
- Seat position
- Win/loss
- Final marbles in home
- Total rolls
- Number of 1s rolled
- Number of 6s rolled
- Captures made
- Captures suffered
- Net captures
- Shortcut opportunities
- Shortcut attempts
- Shortcut successful exits
- Shortcut bumps suffered
- Shortcut marbles that reached home
- Base-exit-on-6 opportunities
- Base exits chosen on 6
- Base exits declined on 6
- No-legal-move turns
- Own-blocking events
- First marble home round

This minimum set should still support useful analysis of:

- First-player advantage.
- Impact of 6s.
- Value of center shortcut use.
- Aggressive vs conservative base exit strategy.
- Capture impact.
- Own-blocking impact.

---

## Recommended Advanced Tracking Plan

For better strategy analysis, track each turn and each meaningful decision point.

The advanced version should include:

1. Game table.
2. Player-game table.
3. Turn table.
4. Marble-state table.
5. Shortcut-opportunity table.
6. Capture-event table.
7. Decision-event table.

The advanced version should allow analysis of short-term and long-term effects.

Examples:

- What happened immediately after choosing to exit base on 6?
- Was that marble captured before the player’s next turn?
- Did having that marble out increase future legal move options?
- Did it create own-blocking?
- Did it eventually reach home?
- Did the player win?

---

## Suggested Data Tables

### Table 1: Games

| Column | Type |
|---|---|
| GameID | Text/number |
| Date | Date |
| PlayerCount | Number |
| WinnerPlayerID | Text |
| WinningSeat | Number |
| TotalRounds | Number |
| TotalTurns | Number |
| TotalRolls | Number |
| Notes | Text |

### Table 2: PlayerGameStats

| Column | Type |
|---|---|
| GameID | Text/number |
| PlayerID | Text |
| SeatPosition | Number |
| Won | Boolean |
| FinalHomeCount | Number |
| FinalTrackCount | Number |
| FinalBaseCount | Number |
| TotalTurns | Number |
| TotalRolls | Number |
| OnesRolled | Number |
| SixesRolled | Number |
| CapturesMade | Number |
| CapturesSuffered | Number |
| NoMoveTurns | Number |
| ForcedMoveTurns | Number |
| OwnBlockingEvents | Number |
| ShortcutOpportunities | Number |
| ShortcutAttempts | Number |
| ShortcutSuccesses | Number |
| ShortcutBumpsSuffered | Number |
| ShortcutToHomeCount | Number |
| BaseExitOn6Opportunities | Number |
| BaseExitOn6Chosen | Number |
| BaseExitOn6Declined | Number |
| FirstMarbleHomeRound | Number |
| FourthMarbleHomeRound | Number |

### Table 3: DecisionEvents

| Column | Type |
|---|---|
| GameID | Text/number |
| DecisionID | Text/number |
| Round | Number |
| TurnNumber | Number |
| PlayerID | Text |
| Roll | Number |
| DecisionType | Text |
| OptionsAvailable | Text/list |
| ChosenAction | Text |
| AlternativeAction | Text |
| ActiveMarblesBefore | Number |
| BaseMarblesBefore | Number |
| HomeMarblesBefore | Number |
| CaptureAvailable | Boolean |
| ShortcutAvailable | Boolean |
| BaseExitAvailable | Boolean |
| HomeMoveAvailable | Boolean |
| ImmediateOutcome | Text |
| OutcomeByNextTurn | Text |
| OutcomeAfterOneRound | Text |
| FinalGameOutcome | Win/loss |

### Table 4: ShortcutEvents

| Column | Type |
|---|---|
| GameID | Text/number |
| ShortcutEventID | Text/number |
| PlayerID | Text |
| MarbleID | Text |
| Round | Number |
| PositionInEntryWindow | Number |
| RequiredRoll | Number |
| ActualRoll | Number |
| Opportunity | Boolean |
| Taken | Boolean |
| Declined | Boolean |
| CenterOccupiedBefore | Boolean |
| OccupyingPlayerID | Text |
| BumpedOpponent | Boolean |
| ExitedCenter | Boolean |
| TurnsInCenter | Number |
| BumpedFromCenter | Boolean |
| EventuallyReachedHome | Boolean |
| FinalShortcutOutcome | Text |

### Table 5: CaptureEvents

| Column | Type |
|---|---|
| GameID | Text/number |
| CaptureEventID | Text/number |
| Round | Number |
| TurnNumber | Number |
| CapturingPlayerID | Text |
| CapturingMarbleID | Text |
| CapturedPlayerID | Text |
| CapturedMarbleID | Text |
| CapturedLocationType | Text |
| CapturedProgressEstimate | Number/text |
| CaptureValue | Low/medium/high/very high |
| CaptureChosenWhenOptional | Boolean |
| CapturingPlayerWon | Boolean |

### Table 6: MarbleProgress

| Column | Type |
|---|---|
| GameID | Text/number |
| PlayerID | Text |
| MarbleID | Text |
| FirstExitRound | Number |
| FirstExitRoll | Number |
| UsedShortcut | Boolean |
| CenterEntryRound | Number |
| CenterExitRound | Number |
| BumpedFromCenter | Boolean |
| CapturesMade | Number |
| TimesCaptured | Number |
| ReachedHome | Boolean |
| RoundReachedHome | Number |
| FinalState | Base/track/center/home |

---

## Analysis Guidance

The agent should recommend analyzing data in stages.

### Stage 1: Basic Win Correlations

Compare win rate by:

- Seat position.
- Number of 6s rolled.
- Number of 1s rolled.
- Captures made.
- Captures suffered.
- Net captures.
- Shortcut attempts.
- Shortcut successes.
- Base exits on 6.
- Own-blocking events.
- No-legal-move turns.

### Stage 2: Strategy Comparisons

Compare outcomes for players or games grouped by:

- Aggressive vs conservative base exit behavior.
- Shortcut users vs shortcut avoiders.
- High-capture players vs low-capture players.
- Players with many active marbles vs few active marbles.
- Players with low own-blocking vs high own-blocking.

### Stage 3: Decision Outcome Analysis

For each decision type, compare:

- Immediate outcome.
- Outcome by player’s next turn.
- Outcome after one full round.
- Whether the involved marble eventually reached home.
- Whether the player won.

### Stage 4: Adjust for Luck

The agent should avoid claiming a strategy is better if the evidence is mostly explained by dice rolls.

At minimum, compare strategy outcomes while also considering:

- Number of 6s rolled.
- Number of 1s rolled.
- Total rolls.
- Extra rolls.
- Forced moves.
- No-legal-move turns.

Example:

A player who exits base on 6 more often may win more often simply because they rolled more 6s. The useful comparison is what they did when they had the opportunity, not just how many times the event occurred.

---

## Recommended Dashboards / Summary Views

The agent should recommend dashboard views such as:

### Game Summary Dashboard

- Winner by seat position.
- Average rounds per game.
- Average rolls per player.
- Win distribution by player.

### Strategy Dashboard

- Win rate by base-exit-on-6 rate.
- Win rate by shortcut take rate.
- Win rate by capture aggressiveness.
- Win rate by average active marbles.
- Win rate by own-blocking rate.

### Center Shortcut Dashboard

- Shortcut opportunities.
- Shortcut attempts.
- Shortcut success rate.
- Shortcut bump rate.
- Shortcut-to-home rate.
- Win rate with shortcut use vs no shortcut use.

### Capture Dashboard

- Captures made.
- Captures suffered.
- Net captures.
- High-value captures made/suffered.
- Capture efficiency.

### Decision Dashboard

- Base exit on 6: chosen vs declined.
- Shortcut: chosen vs declined.
- Capture: chosen vs declined.
- Home move: chosen vs declined.
- Outcome by decision type.

---

## Warnings and Limitations

The final tracking plan should clearly explain these limitations:

1. Small sample sizes will be misleading.
2. Dice luck can overpower strategy in individual games.
3. Win/loss alone is too crude for evaluating decisions.
4. Metrics must separate opportunities from choices.
5. Forced moves should not be treated as strategic decisions.
6. Tracking too much detail may make players stop using the system.
7. Marble progress is useful, but only when tied to decisions and board state.
8. Strategy labels should be calculated from behavior, not manually guessed.

---

## Recommended Final Deliverable Format

The LLM agent should produce a final plan with these sections:

1. Executive summary.
2. Strategy questions being tested.
3. Minimum viable tracking plan.
4. Advanced tracking plan.
5. Data tables and fields.
6. Definitions for each metric.
7. Derived metric formulas.
8. Strategy classification rules.
9. Recommended dashboards.
10. Example filled-in turn records.
11. Analysis workflow after 10, 25, 50, and 100 games.
12. Recommendations for keeping tracking practical during live gameplay.

---

## Practical Live-Tracking Recommendation

The agent should consider a two-layer tracking approach:

### During the Game

Track only quick, easy fields:

- Rolls.
- 1s and 6s.
- Captures.
- Shortcut opportunities and choices.
- Base exit on 6 opportunities and choices.
- No-move turns.
- Own-blocking events.
- Marbles entering home.

### After the Game

Review and enrich the data:

- Assign strategy labels.
- Classify capture value.
- Summarize shortcut outcomes.
- Calculate derived metrics.
- Add notes about major turning points.

This avoids making live gameplay too slow while still preserving useful strategy data.

---

## Success Criteria

The metric tracking plan is successful if it can help answer:

- Which strategies are associated with higher win rates?
- Which choices increase marble progress?
- Which choices increase capture risk?
- Whether the center shortcut is worth using.
- Whether exiting base on 6 is usually beneficial.
- Whether aggressive capture play helps or hurts.
- Whether keeping more marbles active improves flexibility.
- Whether own-blocking is a major cause of lost tempo.
- Which metrics are mostly luck and which are more likely strategic.

