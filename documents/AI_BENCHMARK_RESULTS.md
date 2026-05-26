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

## Run Log

### Stage 0 - Environment Validation (2026-05-26)

**Step 0.1 - Tests:**
`python -m pytest tests/test_selfplay.py tests/test_ai.py` — 20/20 passed. No failures.

**Step 0.2 - Profiles listed:**
`python -m wahoo.selfplay --list-profiles`
Output: assassin, balanced, engineer, expectimax, gambler, gatekeeper, human_like, random, sprinter, swarm, tortoise
All 10 expected profiles present. `expectimax` and `human_like` confirmed. Stage 0 passed.

---

### Stage 1.1 - Quick Baseline Screening (2026-05-26)

```text
Run name: screening-v1
Date: 2026-05-26
Candidates: balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax
Opponents: balanced,balanced,balanced
Games per seat: 25
Total games per profile: 100
Seed: 20260526
Max turns: 20000
Notes: Quick screening pass per AI_TESTING_PLAN.md Stage 1.1
```

**Raw leaderboard:**

| Rank | Profile    | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B)       |
|------|------------|------|-------|-----------|-----------|-----------|--------------|----------------------|
| 1    | sprinter   | 88   | 88.0% | 100/100   | 560.4     | 674.9     | 101.3        | 22 / 23 / 22 / 21    |
| 2    | gambler    | 85   | 85.0% | 100/100   | 587.0     | 707.1     | 110.0        | 21 / 23 / 20 / 21    |
| 3    | expectimax | 85   | 85.0% | 100/100   | 684.2     | 820.2     | 122.3        | 21 / 21 / 22 / 21    |
| 4    | human_like | 65   | 65.0% | 100/100   | 981.8     | 1177.3    | 197.9        | 20 / 18 / 12 / 15    |
| 5    | gatekeeper | 50   | 50.0% | 100/100   | 1173.8    | 1409.0    | 238.4        | 13 / 12 / 13 / 12    |
| 6    | assassin   | 37   | 37.0% | 100/100   | 1137.8    | 1366.5    | 232.0        | 7 / 9 / 12 / 9       |
| 7    | engineer   | 23   | 23.0% | 100/100   | 1151.9    | 1385.7    | 234.5        | 9 / 4 / 7 / 3        |
| 8    | balanced   | 22   | 22.0% | 100/100   | 1348.3    | 1616.7    | 280.1        | 4 / 8 / 6 / 4        |
| 9    | tortoise   | 13   | 13.0% | 100/100   | 1123.4    | 1351.4    | 227.5        | 3 / 3 / 4 / 3        |
| 10   | swarm      | 7    | 7.0%  | 100/100   | 1282.9    | 1541.5    | 261.7        | 0 / 2 / 4 / 1        |

**Interpretation:**
- No unfinished games across any profile. All 100/100 completed.
- Clear top tier: sprinter (88%), gambler (85%), expectimax (85%) dominate the field.
- human_like (65%) is competitive but well below the top 3. Seat Yellow (12/25) shows some seat bias.
- gatekeeper (50%) is near the expected neutral level for a 4-player game (25%), slightly above.
- assassin (37%), engineer (23%), balanced (22%), tortoise (13%), swarm (7%) all underperform vs the expected 25% baseline.
- No profile is broken or pathological. All games completed cleanly.
- Provisional low-priority candidates: tortoise, swarm (both well below 25% win floor).

**Action before Stage 2:**
- All profiles retained for Stage 2 (no profile removed permanently based on this stage alone).
- tortoise and swarm flagged as provisional low-priority — watch for confirmation in Stage 2.
- No rerun needed: zero unfinished games across the field.

---

### Stage 2.1 - Serious Baseline Ranking, Seed 20260526 (2026-05-26)

```text
Run name: baseline-v1-seed-20260526
Date: 2026-05-26
Candidates: balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax
Opponents: balanced,balanced,balanced
Games per seat: 100
Total games per profile: 400
Seed: 20260526
Max turns: 20000
Notes: AI_TESTING_PLAN.md Stage 2.1, first baseline seed run
```

**Raw leaderboard:**

| Rank | Profile    | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B)       |
|------|------------|------|-------|-----------|-----------|-----------|--------------|----------------------|
| 1    | sprinter   | 366  | 91.5% | 400/400   | 572.8     | 688.0     | 104.4        | 87 / 97 / 88 / 94    |
| 2    | gambler    | 358  | 89.5% | 400/400   | 596.9     | 716.3     | 111.8        | 86 / 93 / 88 / 91    |
| 3    | expectimax | 319  | 79.8% | 400/400   | 720.5     | 864.8     | 130.9        | 80 / 75 / 81 / 83    |
| 4    | human_like | 243  | 60.8% | 400/400   | 973.3     | 1168.2    | 197.3        | 58 / 55 / 61 / 69    |
| 5    | gatekeeper | 152  | 38.0% | 400/400   | 1192.4    | 1429.5    | 241.7        | 39 / 37 / 39 / 37    |
| 6    | assassin   | 140  | 35.0% | 400/400   | 1205.0    | 1446.1    | 249.6        | 37 / 38 / 31 / 34    |
| 7    | engineer   | 87   | 21.8% | 400/400   | 1225.1    | 1468.7    | 249.8        | 18 / 28 / 18 / 23    |
| 8    | balanced   | 86   | 21.5% | 400/400   | 1298.9    | 1559.3    | 268.2        | 16 / 21 / 20 / 29    |
| 9    | tortoise   | 66   | 16.5% | 400/400   | 1195.8    | 1435.9    | 242.1        | 12 / 14 / 21 / 19    |
| 10   | swarm      | 37   | 9.2%  | 400/400   | 1257.8    | 1509.5    | 256.0        | 7 / 10 / 10 / 10     |

**Interpretation (Stage 2.1, single-seed interim):**
- No unfinished games: 400/400 completed for every profile.
- Top three are currently well-separated from the field: sprinter, gambler, expectimax.
- balanced baseline for this seed is 21.5%; sprinter (+70.0 pp), gambler (+68.0 pp), and expectimax (+58.3 pp) are far above the baseline threshold on this run.
- human_like is above balanced (+39.3 pp) but remains materially behind the top 3.
- Seat behavior is mostly stable for top profiles; balanced shows moderate Blue-seat lift (29 vs 16 Red), worth watching across additional seeds.
- This is still one seed only; no Stage 2 contender decisions should be finalized until all five standard seeds are aggregated.

**Action before next Stage 2.1 run:**
- Repeat the same command for seeds 20260527, 20260528, 20260529, and 20260530.
- After all five runs, aggregate totals before selecting Stage 3 candidates.

---

### Stage 2.1 - Serious Baseline Ranking, Seed 20260527 (2026-05-26)

```text
Run name: baseline-v1-seed-20260527
Date: 2026-05-26
Candidates: balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax
Opponents: balanced,balanced,balanced
Games per seat: 100
Total games per profile: 400
Seed: 20260527
Max turns: 20000
Notes: AI_TESTING_PLAN.md Stage 2.1, second baseline seed run
```

**Raw leaderboard:**

| Rank | Profile    | Wins | Win % | Completed | Avg Turns | Avg Rolls | Avg Captures | Seat (R/G/Y/B)       |
|------|------------|------|-------|-----------|-----------|-----------|--------------|----------------------|
| 1    | sprinter   | 367  | 91.8% | 400/400   | 549.7     | 658.6     | 98.9         | 88 / 94 / 91 / 94    |
| 2    | gambler    | 352  | 88.0% | 400/400   | 619.6     | 743.3     | 115.7        | 90 / 85 / 84 / 93    |
| 3    | expectimax | 336  | 84.0% | 400/400   | 711.2     | 853.9     | 129.9        | 88 / 83 / 88 / 77    |
| 4    | human_like | 251  | 62.7% | 400/400   | 998.5     | 1198.9    | 202.6        | 66 / 62 / 68 / 55    |
| 5    | gatekeeper | 184  | 46.0% | 400/400   | 1186.6    | 1424.9    | 240.7        | 40 / 51 / 49 / 44    |
| 6    | assassin   | 140  | 35.0% | 400/400   | 1242.1    | 1490.0    | 257.9        | 33 / 33 / 42 / 32    |
| 7    | engineer   | 100  | 25.0% | 400/400   | 1174.3    | 1409.8    | 238.5        | 16 / 22 / 27 / 35    |
| 8    | balanced   | 99   | 24.8% | 400/400   | 1279.5    | 1534.9    | 263.9        | 28 / 27 / 21 / 23    |
| 9    | tortoise   | 95   | 23.8% | 400/400   | 1214.5    | 1458.4    | 248.0        | 20 / 23 / 19 / 33    |
| 10   | swarm      | 22   | 5.5%  | 400/400   | 1274.8    | 1529.6    | 260.5        | 5 / 5 / 4 / 8        |

**Interpretation (Stage 2.1, single-seed interim):**
- No unfinished games: 400/400 completed for every profile.
- Top three again are sprinter, gambler, expectimax, consistent with seed 20260526 ordering.
- balanced baseline for this seed is 24.8%; sprinter (+67.0 pp), gambler (+63.2 pp), and expectimax (+59.2 pp) remain far above baseline.
- human_like remains clearly above balanced (+37.9 pp) but below the top 3.
- gatekeeper rose materially vs seed 20260526 (38.0% -> 46.0%), while assassin stayed flat at 35.0%.

**Two-seed interim aggregate (seeds 20260526 + 20260527, 800 games/profile):**

| Rank | Profile    | Wins | Win % | Completed | Unfinished | Seat Wins (R/G/Y/B) |
|------|------------|------|-------|-----------|------------|---------------------|
| 1    | sprinter   | 733  | 91.6% | 800/800   | 0          | 175 / 191 / 179 / 188 |
| 2    | gambler    | 710  | 88.8% | 800/800   | 0          | 176 / 178 / 172 / 184 |
| 3    | expectimax | 655  | 81.9% | 800/800   | 0          | 168 / 158 / 169 / 160 |
| 4    | human_like | 494  | 61.8% | 800/800   | 0          | 124 / 117 / 129 / 124 |
| 5    | gatekeeper | 336  | 42.0% | 800/800   | 0          | 79 / 88 / 88 / 81 |
| 6    | assassin   | 280  | 35.0% | 800/800   | 0          | 70 / 71 / 73 / 66 |
| 7    | engineer   | 187  | 23.4% | 800/800   | 0          | 34 / 50 / 45 / 58 |
| 8    | balanced   | 185  | 23.1% | 800/800   | 0          | 44 / 48 / 41 / 52 |
| 9    | tortoise   | 161  | 20.1% | 800/800   | 0          | 32 / 37 / 40 / 52 |
| 10   | swarm      | 59   | 7.4%  | 800/800   | 0          | 12 / 15 / 14 / 18 |

**Action before next Stage 2.1 run:**
- Continue with seeds 20260528, 20260529, and 20260530 using the same command and max-turns.
- Reassess seat-skew warnings after seed 3; treat current seat deltas as provisional.

---

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
