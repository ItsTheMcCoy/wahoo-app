# AI Testing Plan

Detailed step-by-step protocol for evaluating Wahoo AI profiles with the existing self-play and benchmark tooling.

This plan is designed to answer the practical question:

Which AI profiles actually win the most games across repeated runs, across seats, and across different opponent fields?

It is intentionally stricter than a single benchmark leaderboard. A profile should not be treated as stronger until it survives all stages below.

## Scope

This plan covers:
- benchmark-mode screening with seat rotation
- repeated-seed confirmation
- mixed-opponent robustness checks
- pairwise confirmation between top candidates
- interpretation rules after each stage
- what action to take before proceeding to the next stage

This plan uses two existing entry points:
- `python -m wahoo.selfplay --benchmark-*` for seat-rotated gauntlet benchmarking
- `python -m wahoo.selfplay --games ... --players ...` for direct matchup confirmation

## Profiles Under Test

Current profile set:
- `balanced`
- `sprinter`
- `swarm`
- `assassin`
- `gambler`
- `tortoise`
- `gatekeeper`
- `engineer`
- `human_like`
- `expectimax`

`human_like` should be evaluated using this same protocol, not a separate standard.

## Global Test Rules

These rules apply to the entire testing cycle.

1. Do not change weights mid-cycle.
If any profile weights change, the entire cycle must restart from Stage 0.

2. Keep max-turns constant within a cycle.
Use the same `--max-turns` value for all runs in a given evaluation cycle.
Recommended value: `20000`.

3. Use repeated seeds.
A single seeded run is never enough to conclude that one profile is better.

4. Record results immediately.
Use `documents/AI_BENCHMARK_RESULTS.md` as the canonical results log.

5. Do not advance on ambiguous results.
If the decision rule for a stage is not satisfied, run the prescribed follow-up action before moving on.

## Standard Seed Set

Use this seed set for serious comparisons:
- `20260526`
- `20260527`
- `20260528`
- `20260529`
- `20260530`

Use these only for screening or tie-break follow-ups unless otherwise noted.

## Stage 0 - Environment Validation

Purpose:
Confirm that the codebase and CLI are in a valid state before collecting any benchmark data.

### Step 0.1 - Run targeted tests

Command:

```powershell
python -m pytest tests/test_selfplay.py tests/test_ai.py
```

Interpretation:
- If all tests pass, continue.
- If any test fails, all benchmark work is blocked.

Action before next stage:
- Fix failures first.
- Do not run any benchmark until these tests pass.

### Step 0.2 - List available profiles

Command:

```powershell
python -m wahoo.selfplay --list-profiles
```

Interpretation:
- Verify that all expected profiles appear.
- Confirm that `expectimax` is listed.
- Confirm that `human_like` is listed.

Action before next stage:
- If any expected profile is missing, fix profile registration before continuing.

## Stage 1 - Quick Baseline Screening

Purpose:
Identify obviously weak profiles before spending time on large benchmark runs.

### Step 1.1 - Run quick seat-rotated baseline gauntlet

Command:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 25 --max-turns 20000 --seed 20260526
```

Interpretation:
- This is not the final ranking.
- Use this run only to spot profiles that are clearly underperforming or clearly unstable.
- Focus on:
  - total win rate
  - per-seat win breakdown
  - unfinished games

Decision rule:
- Profiles that lag the field badly and show no competitive seat pattern may be marked as provisional low-priority candidates.
- No profile should be removed permanently based on this stage alone.

Action before next stage:
- Record the results in `documents/AI_BENCHMARK_RESULTS.md`.
- Keep all profiles for Stage 2 unless a profile is clearly broken or pathological.
- If a profile has excessive unfinished games, rerun the same command once with a different seed to check whether that behavior repeats.

## Stage 2 - Serious Baseline Ranking

Purpose:
Measure how strong each profile is against a neutral baseline field.

### Step 2.1 - Run baseline benchmark across all standard seeds

Run the following command once per seed.

Seed `20260526`:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260526
```

Seed `20260527`:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260527
```

Seed `20260528`:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260528
```

Seed `20260529`:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260529
```

Seed `20260530`:

```powershell
python -m wahoo.selfplay --benchmark-profiles balanced,sprinter,swarm,assassin,gambler,tortoise,gatekeeper,engineer,human_like,expectimax --benchmark-opponents balanced,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260530
```

Each profile will accumulate:
- `4 * 100 = 400` games per seed
- `5 * 400 = 2000` total baseline games per profile

### Step 2.2 - Aggregate baseline results

Required metrics to aggregate per profile:
- total wins
- total games
- aggregate win rate
- total completed games
- total unfinished games
- average turns
- average rolls
- average captures
- per-seat wins and per-seat win rates

Interpretation:
- Aggregate win rate is the primary signal.
- Unfinished games are a quality/stability signal.
- Seat-level skew is a robustness warning.

Decision rule:
- A profile is a baseline contender if it meets all of the following:
  - aggregate win rate is at or above `balanced`
  - unfinished games are not materially worse than the field
  - no severe seat collapse is visible

Suggested threshold for clearly beating `balanced`:
- at least 2 to 3 percentage points above `balanced` over the full aggregated baseline run

Action before next stage:
- Rank all profiles by aggregate win rate.
- Select the top 3 profiles for Stage 3.
- If positions 3 and 4 are very close, include both and test top 4 instead.
- If no profile clearly beats `balanced`, still carry forward the top 3 and note that the field is clustered.
- If unfinished-game counts are high across many profiles, do not continue until you determine whether `--max-turns` is too low or a profile is pathological.

## Stage 3 - Mixed-Opponent Robustness Testing

Purpose:
Verify that a profile is not only strong against `balanced,balanced,balanced`, but also against varied behaviors.

Use the top 3 profiles from Stage 2 as the candidate set in this stage.

### Step 3.1 - Run mixed-opponent gauntlet A

Command template:

```powershell
python -m wahoo.selfplay --benchmark-profiles TOP1,TOP2,TOP3 --benchmark-opponents assassin,tortoise,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260526
```

Repeat across all standard seeds.

### Step 3.2 - Run mixed-opponent gauntlet B

Command template:

```powershell
python -m wahoo.selfplay --benchmark-profiles TOP1,TOP2,TOP3 --benchmark-opponents gambler,gatekeeper,engineer --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260526
```

Repeat across all standard seeds.

### Step 3.3 - Run mixed-opponent gauntlet C

Command template:

```powershell
python -m wahoo.selfplay --benchmark-profiles TOP1,TOP2,TOP3 --benchmark-opponents random,balanced,balanced --benchmark-games-per-seat 100 --max-turns 20000 --seed 20260526
```

Repeat across all standard seeds.

Interpretation:
- A strong general-purpose profile should remain competitive across all three gauntlets.
- A profile that only wins in the baseline gauntlet may be overfit to the balanced field.

Decision rule:
- A profile passes robustness if it remains competitive in at least 2 of the 3 mixed-opponent gauntlets.
- If one profile collapses in all three mixed-opponent sets, it should not be declared the overall winner, even if it topped the baseline gauntlet.

Action before next stage:
- Carry forward the top 2 robust profiles.
- If only one profile remains clearly robust, still run Stage 4 to confirm against the nearest competitor.
- If all three remain close, carry all three into Stage 4 pairwise confirmation.

**Stage 3 summary:**
- Gauntlet A: sprinter 87.1%, gambler 86.0%, expectimax 77.5%.
- Gauntlet B: sprinter 50.5%, gambler 49.2%, expectimax 35.8%.
- Gauntlet C: sprinter 76.1%, gambler 75.0%, expectimax 66.5%.
- Outcome: sprinter and gambler remain the strongest mixed-field profiles; expectimax is still viable but trails the top two on every mixed-opponent field.
- Follow-up: advance sprinter and gambler as the clearest robust finalists, with expectimax kept as the third comparison profile for Stage 4 unless a narrower finalist set is needed.

## Stage 4 - Pairwise Confirmation Matrix

Purpose:
Confirm head-to-head strength between top candidates so the final ranking is not based only on fixed-opponent gauntlets.

This stage is required to answer the question of which profiles win most often against the other profiles.

Use direct self-play runs with mixed seat layouts.

### Step 4.1 - Build the pair list

For the top candidate set, create every unique pair.

Examples if top 3 are:
- `balanced`
- `assassin`
- `expectimax`

Required pairs:
- `balanced` vs `assassin`
- `balanced` vs `expectimax`
- `assassin` vs `expectimax`

### Step 4.2 - Run four-seat direct matchup patterns for each pair

For each pair `A` and `B`, run at least these two layouts per seed:

Layout 1:

```powershell
python -m wahoo.selfplay --games 500 --players A,B,A,B --max-turns 20000 --seed 20260531
```

Layout 2:

```powershell
python -m wahoo.selfplay --games 500 --players B,A,B,A --max-turns 20000 --seed 20260532
```

Recommended extension for stronger confirmation:

Layout 3:

```powershell
python -m wahoo.selfplay --games 500 --players A,A,B,B --max-turns 20000 --seed 20260533
```

Layout 4:

```powershell
python -m wahoo.selfplay --games 500 --players B,B,A,A --max-turns 20000 --seed 20260534
```

For a local automation script that runs the full Stage 4 confirmation block and writes markdown plus JSON summaries, use [scripts/run_stage4_pairwise_confirmation.py](../scripts/run_stage4_pairwise_confirmation.py).

Interpretation:
- These runs are not a replacement for benchmark mode.
- They are a pairwise confirmation step.
- Track total wins by profile across all layouts and seeds.

Decision rule:
- A profile wins the pair if it beats the other profile by a visible aggregate margin across all pairwise runs.
- Suggested threshold: at least 2 percentage points over the total head-to-head dataset.

Action before next stage:
- Build a pairwise win matrix for the finalist profiles.
- If a pair remains too close to call, run one more round with new seeds before final ranking.

## Stage 5 - Full Round-Robin Confirmation

Purpose:
Ensure the final conclusion is not distorted by only testing a small set of final candidates.

This stage tests whether the leading profile still looks best when every profile is considered in direct comparison work.

### Step 5.1 - Pairwise spot-check the final winner against every profile

Let `WINNER` be the current top profile from Stages 2 through 4.

For each remaining profile `X`, run:

```powershell
python -m wahoo.selfplay --games 500 --players WINNER,X,WINNER,X --max-turns 20000 --seed 20260541
python -m wahoo.selfplay --games 500 --players X,WINNER,X,WINNER --max-turns 20000 --seed 20260542
```

Interpretation:
- This is the final sanity check that the provisional winner does not have a blind spot against a profile that was weaker in the benchmark gauntlets.

Decision rule:
- If the winner loses clearly to any non-finalist profile, the full conclusion must be revisited.
- If the winner remains positive or neutral across the rest of the field, the result is stable enough to declare.

Action before next stage:
- If no serious blind spot appears, proceed to final ranking.
- If a blind spot appears, rerun Stage 3 with an updated mixed-opponent block that includes the spoiler profile.

## Stage 6 - Final Ranking and Classification

Purpose:
Convert the evidence into a practical ranking.

### Step 6.1 - Create the final ranking

Rank profiles using all previous evidence in this order:
1. baseline aggregate performance
2. robustness across mixed-opponent gauntlets
3. pairwise confirmation results
4. unfinished-game rate
5. seat-bias severity

### Step 6.2 - Assign profile status

Use these buckets:

- `S-tier`: clearly strongest across benchmark, robustness, and pairwise confirmation
- `A-tier`: consistently strong, but not clearly dominant
- `B-tier`: viable but matchup-sensitive or seat-sensitive
- `C-tier`: consistently underperforms or fails robustness checks

### Step 6.3 - Document the final decision

Record in `documents/AI_BENCHMARK_RESULTS.md`:
- final ranking
- total evidence used
- seeds used
- any caveats
- whether any ties remain too close to call

Interpretation:
- The winner should be the profile with the strongest total evidence, not just the best single metric.

Action after final ranking:
- Freeze current weights if no tuning is planned.
- If tuning is planned, use the final ranking as the baseline to beat in the next cycle.

## Stop Conditions

Stop the cycle and fix issues before continuing if any of the following occur:
- selfplay/AI tests fail
- a benchmark run shows implausibly high unfinished rates across the field
- profile registration changes mid-cycle
- weights change mid-cycle
- a profile appears broken from one or more seats

If a stop condition occurs, restart from Stage 0 after the issue is fixed.

## Minimum Evidence Standard

Do not declare an overall winner unless all of the following are true:
- Stage 2 baseline ranking completed across 5 seeds
- Stage 3 robustness testing completed
- Stage 4 pairwise confirmation completed for finalists
- Stage 5 winner-vs-field spot checks completed
- results logged in `documents/AI_BENCHMARK_RESULTS.md`

## Recommended Next Actions After This Plan

If the current goal is profile quality only:
- keep the top profile as the default benchmark champion

If the current goal is human-like play:
- create the human-like profile after collecting reasoning data
- insert it into every stage of this same plan

If the current goal is tuning:
- create a tuning script only after a stable baseline winner is known
- use the Stage 2 baseline block as the default tuning target
