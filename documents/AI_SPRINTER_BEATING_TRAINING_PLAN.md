# AI Sprinter-Beating Training Plan

Goal: train and promote a new profile that beats sprinter consistently while remaining strong across mixed opponent fields.

## Core Strategy

Use automated weight search on the existing GreedyPlayer feature architecture, then promote candidates only if they pass the existing Stage 2 through Stage 5 validation gates in AI_TESTING_PLAN.md.

## Training Pipeline

1. Define objective and acceptance metrics.
- Primary: win rate against sprinter and gambler in seat-rotated mini-benchmarks.
- Penalties: unfinished game rate and severe seat bias.
- Keep this objective fixed for the entire cycle.

## Objective Function (Search Phase)

Use a single scalar objective for candidate ranking during overnight tuning:

score =
	0.50 * wr_vs_sprinter
	+ 0.20 * wr_vs_gambler
	+ 0.15 * wr_vs_balanced
	+ 0.10 * min_seed_wr_vs_sprinter
	- 0.30 * unfinished_rate
	- 0.10 * seat_spread

Definitions:
- wr_vs_sprinter: aggregate win rate vs sprinter over search seeds.
- wr_vs_gambler: aggregate win rate vs gambler over search seeds.
- wr_vs_balanced: aggregate win rate vs balanced over search seeds.
- min_seed_wr_vs_sprinter: worst single-seed win rate vs sprinter.
- unfinished_rate: unfinished games / total games in search runs.
- seat_spread: max seat win rate minus min seat win rate in search runs.

Notes:
- Treat all rates as decimals in [0, 1].
- Keep this formula fixed during the full tuning cycle.
- Use this objective only for candidate selection, not final promotion.

## Acceptance Metrics (Promotion Gates)

A candidate can be promoted only if all gates pass.

1. Head-to-head strength vs sprinter.
- Aggregate win rate vs sprinter >= 0.52.
- Pairwise confirmation margin vs sprinter >= 0.02 (2 percentage points).

2. Worst-seed robustness.
- Worst seed win rate vs sprinter >= 0.49.

3. Confidence gate.
- 95% confidence interval lower bound for win rate vs sprinter > 0.50.

4. Mixed-field robustness.
- Competitive in at least 2 of 3 Stage 3 gauntlets.
- No Stage 3 gauntlet more than 0.03 below sprinter.

5. Seat fairness.
- Seat spread <= 0.10.
- No seat win rate < 0.20 over large aggregated samples.

6. Completion and stability quality.
- Unfinished rate <= 0.02.
- Unfinished rate not materially worse than sprinter (target difference <= 0.01).

7. Holdout consistency.
- Holdout-seed win rate within 0.02 of search-seed win rate.

8. Regression safety.
- Existing AI and selfplay tests pass.
- Determinism and win-guardrail behavior remain intact.

## Seed Split Policy

Use separate seed sets for selection and confirmation.

- Search seeds (used in objective optimization):
	- 20260601
	- 20260602
	- 20260603

- Holdout and promotion seeds (not used during search scoring):
	- 20260526
	- 20260527
	- 20260528
	- 20260529
	- 20260530

If any search hyperparameter or objective term changes, restart the cycle.

2. Build a tuning harness script.
- Add a script in scripts/ that evaluates candidate weights by calling Python APIs directly in wahoo.selfplay (especially benchmark_profiles).
- Persist checkpoints to JSON so overnight runs can resume safely.

3. Seed candidate population from strong priors.
- Start from sprinter, gambler, balanced, and one blended profile.
- Generate perturbations over all 10 feature weights: DEP, RUN, SPR, CAP, SAFE, CTR, DEN, FLOW, HOME, FIN.
- Also perturb phase modifiers (early, mid, late) in small ranges.

4. Run overnight search.
- Use random-plus-mutation rounds first (optionally evolutionary selection later).
- Use reduced games-per-seat and fixed mini-seeds for throughput.
- Keep a holdout seed set that is not used in candidate selection.

5. Promote top candidates to full validation.
- Advance top 3 to 5 candidates from search.
- Run full Stage 2 baseline across standard seeds.

6. Enforce robustness and confirmation gates.
- Stage 3 mixed-opponent gauntlets: candidate must stay competitive in at least 2 of 3 gauntlets.
- Stage 4 pairwise confirmation: require a visible aggregate margin over sprinter (target >= 2 percentage points).
- Stage 5 winner-vs-field spot checks: verify no blind-spot profile defeats the winner clearly.

7. Regression safety and promotion.
- Run targeted AI/selfplay tests (including win guardrail and deterministic behavior).
- Register the winning profile in wahoo/ai.py only after all gates pass.
- Freeze weights for the cycle and log results in AI_BENCHMARK_RESULTS.md.

## Invariants To Preserve

- GreedyPlayer must remain deterministic.
- Immediate win guardrail must always override feature scoring.
- Never mutate input GameState directly; clone before simulation.
- Keep feature outputs in roughly 0.0 to 1.0 scale so weights remain meaningful.
- Do not change profile weights mid-cycle.

## Suggested Overnight Run Structure

1. Search phase (overnight): large candidate batch with mini-evaluations.
2. Selection phase (morning): shortlist top 3 to 5 candidates by objective score.
3. Validation phase (same day): Stage 2 to Stage 5 confirmation pipeline.

### Tuner Command (Automated Search)

```powershell
python scripts/tune_profile_against_sprinter.py --generations 8 --population-size 20 --elite-count 4 --games-per-seat 15 --max-turns 20000 --search-seeds 20260601,20260602,20260603 --holdout-seeds 20260526,20260527,20260528,20260529,20260530 --checkpoint-json documents/sprinter_tuning_checkpoint.json --output-json documents/sprinter_tuning_results.json --output-md documents/sprinter_tuning_results.md
```

Outputs:
- `documents/sprinter_tuning_checkpoint.json`
- `documents/sprinter_tuning_results.json`
- `documents/sprinter_tuning_results.md`

## Required Evidence Before Declaring New Champion

- Stage 2 complete across all standard seeds.
- Stage 3 robustness complete.
- Stage 4 pairwise confirmation complete.
- Stage 5 winner-vs-field checks complete.
- Results logged in AI_BENCHMARK_RESULTS.md with seeds and caveats.

## Practical Notes

- Prefer API-driven evaluation in scripts over parsing long terminal output.
- Keep benchmark blocks fixed per cycle for fair comparisons.
- If weights or profile definitions change, restart from Stage 0 of AI_TESTING_PLAN.md.
