# AI Sprinter-Beating Training Plan

Goal: train and promote a new profile that beats sprinter consistently while remaining strong across mixed opponent fields.

## Core Strategy

Use automated weight search on the existing GreedyPlayer feature architecture, then promote candidates only if they pass the existing Stage 2 through Stage 5 validation gates in AI_TESTING_PLAN.md.

## Training Pipeline

1. Define objective and acceptance metrics.
- Primary: win rate against sprinter and gambler in seat-rotated mini-benchmarks.
- Penalties: unfinished game rate and severe seat bias.
- Keep this objective fixed for the entire cycle.

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
