# AI Benchmark Results

Protocol and results log for evaluating Wahoo AI profile strength with the benchmark mode in `wahoo/selfplay.py`.

## Goal

Measure which AI profiles are actually stronger under controlled conditions, not just which profile wins a single seeded run.

Use this document to:
- keep benchmark settings consistent across runs
- compare profiles against the same opponent gauntlets
- track repeated runs across multiple seeds
- record conclusions before changing weights or adding new profiles

## Core Rules

1. Keep one benchmark block fixed.
Use the same candidate set, opponents, `--benchmark-games-per-seat`, `--max-turns`, and interpretation rules within one comparison cycle.

2. Use multiple seeds.
A single seeded run is not enough evidence to call one profile stronger than another.

3. Compare against a baseline first.
The first gauntlet should usually be `balanced,balanced,balanced`.

4. Rotate through all seats.
Use benchmark mode rather than manual self-play when ranking profiles, because benchmark mode controls for seat bias.

5. Do not tune weights mid-cycle.
Finish the full measurement block, then adjust weights, then rerun the same block.

## Benchmark Commands

### Baseline Gauntlet

Use this first to compare all current profiles against three balanced opponents:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 100 --seed 20260526
```

### Mixed-Opponent Gauntlet

Use this after the baseline to test robustness against more varied playstyles:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax --benchmark-opponents assassin,tortoise,balanced --benchmark-games-per-seat 100 --seed 20260526
```

### Quick Screening Run

Use this only for fast iteration while tuning:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,expectimax,assassin,tortoise --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 25 --seed 20260526
```

## Recommended Evaluation Sequence

### Phase 1: Broad Screening

1. Run all profiles against `balanced,balanced,balanced`.
2. Use `25` games per seat for a quick pass.
3. Remove obviously weak profiles from the next round.

### Phase 2: Serious Baseline Ranking

1. Run serious comparison against `balanced,balanced,balanced`.
2. Use `100` games per seat.
3. Repeat across at least 5 seeds.
4. Aggregate results into one table.

Suggested seeds:
- `20260526`
- `20260527`
- `20260528`
- `20260529`
- `20260530`

### Phase 3: Robustness Testing

Take the top 3 profiles from the baseline and rerun them against:
- `assassin,tortoise,balanced`
- `gambler,gatekeeper,engineer`
- `random,balanced,balanced`

### Phase 4: Follow-Up Comparison

If two profiles are close, run additional direct matchup experiments with `--players` to confirm the result.

Example:

```powershell
python -m wahoo.selfplay --games 500 --players expectimax,balanced,expectimax,balanced --seed 20260531
python -m wahoo.selfplay --games 500 --players balanced,expectimax,balanced,expectimax --seed 20260532
```

## Success Criteria

A profile should only be considered meaningfully stronger if it meets all of the following:

1. It beats `balanced` by a visible margin over aggregated runs.
Suggested threshold: at least 2 to 3 percentage points in aggregate win rate.

2. It is not heavily seat-dependent.
Large seat skew suggests the result may be positional rather than algorithmic.

3. It does not produce many unfinished games.
A profile that stalls or drags into the max-turn cap too often is not a clean winner.

4. It remains competitive in at least one mixed-opponent gauntlet.
A profile that only dominates one narrow field may be overfit.

## Metrics to Record

Primary metric:
- aggregate win rate

Secondary metrics:
- per-seat win rate
- completed vs unfinished games
- average turns
- average rolls
- average captures

Interpretation notes:
- Higher win rate is the main ranking signal.
- Lower unfinished count is a quality signal.
- Seat imbalance should be treated as a warning flag.
- Very high average turns may indicate a safe but overly passive profile.

## Run Log Template

Copy this block for each benchmark run.

```text
Run name:
Date:
Candidates:
Opponents:
Games per seat:
Total games per profile:
Seed:
Max turns:
Notes:
```

## Aggregate Results Table

Use one row per profile after combining repeated runs for the same benchmark block.

| Benchmark block | Profile | Opponents | Seeds | Games/seat | Total games | Wins | Win rate | Completed | Unfinished | Avg turns | Avg rolls | Avg captures | Seat notes | Conclusion |
|-----------------|---------|-----------|-------|------------|-------------|------|----------|-----------|------------|-----------|-----------|--------------|------------|------------|
| baseline-v1 | balanced | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | sprinter | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | swarm | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | assassin | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | gambler | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | tortoise | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | gatekeeper | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | engineer | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | human_like | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |
| baseline-v1 | expectimax | balanced,balanced,balanced | 5 | 100 | 2000 | | | | | | | | | |

## Per-Seat Notes Template

Use this section when a profile shows visible seat bias.

### Example format

```text
Profile: expectimax
Benchmark block: baseline-v1
Red:  
Green:
Yellow:
Blue:
Interpretation:
```

## Promotion / Demotion Guidelines

Promote a profile to top-tier candidate status if:
- it consistently beats `balanced`
- it has low seat skew
- it does not accumulate many unfinished games
- it survives at least one mixed-opponent gauntlet

Mark a profile as unstable if:
- its results swing hard between seeds
- it is strong only from one or two seats
- it performs well only in one opponent set

Mark a profile as weak if:
- it repeatedly underperforms `balanced`
- it loses badly to both baseline and mixed-opponent gauntlets

## Future Use

`human_like` should stay in the same benchmark blocks as all other profiles rather than using a separate evaluation standard.

After a tuning script exists, record the candidate generation rule and benchmark block used for each tuning pass so results remain comparable.
