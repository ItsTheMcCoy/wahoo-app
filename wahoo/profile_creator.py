"""Interactive and scripted tool for building custom AI profiles.

This tool starts from an existing profile and lets you tune granular, single-trait
weights using slider values (0-100). It prevents contradictory trait selections.

Examples:
  python -m wahoo.profile_creator
  python -m wahoo.profile_creator --base balanced --trait RUN=85 --trait CAP=70
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone

try:
    from .ai import (
        ASSASSIN_WEIGHTS,
        BALANCED_WEIGHTS,
        ENGINEER_WEIGHTS,
        GAMBLER_WEIGHTS,
        GATEKEEPER_WEIGHTS,
        SPRINTER_WEIGHTS,
        SWARM_WEIGHTS,
        TORTOISE_WEIGHTS,
        _load_human_like_weights,
    )
except ImportError:
    from ai import (
        ASSASSIN_WEIGHTS,
        BALANCED_WEIGHTS,
        ENGINEER_WEIGHTS,
        GAMBLER_WEIGHTS,
        GATEKEEPER_WEIGHTS,
        SPRINTER_WEIGHTS,
        SWARM_WEIGHTS,
        TORTOISE_WEIGHTS,
        _load_human_like_weights,
    )

FEATURE_KEYS = ("DEP", "RUN", "SPR", "CAP", "SAFE", "CTR", "DEN", "FLOW", "HOME", "FIN")

TRAIT_DESCRIPTIONS = {
    "DEP": "Deployment pressure (prefer exiting base)",
    "RUN": "Single-runner focus",
    "SPR": "Spread focus",
    "CAP": "Capture aggression",
    "SAFE": "Safety first",
    "CTR": "Shortcut eagerness (center entry)",
    "DEN": "Center denial",
    "FLOW": "Flow control (reduce self-blocking)",
    "HOME": "Home-lane engineering",
    "FIN": "Finish-over-fight preference",
}

# Mutually exclusive feature choices. Selecting both indicates a contradictory style.
CONTRADICTIONS = {
    "RUN": {"SPR"},
    "SPR": {"RUN"},
}

PRESET_WEIGHTS = {
    "balanced": dict(BALANCED_WEIGHTS),
    "sprinter": dict(SPRINTER_WEIGHTS),
    "swarm": dict(SWARM_WEIGHTS),
    "assassin": dict(ASSASSIN_WEIGHTS),
    "gambler": dict(GAMBLER_WEIGHTS),
    "tortoise": dict(TORTOISE_WEIGHTS),
    "gatekeeper": dict(GATEKEEPER_WEIGHTS),
    "engineer": dict(ENGINEER_WEIGHTS),
    "human_like": dict(_load_human_like_weights()),
}


def _feature_max_weights() -> dict[str, float]:
    """Compute per-feature max from existing profiles for slider scaling."""
    max_by_feature = {key: 0.0 for key in FEATURE_KEYS}
    for profile in PRESET_WEIGHTS.values():
        for key in FEATURE_KEYS:
            max_by_feature[key] = max(max_by_feature[key], float(profile.get(key, 0.0)))
    return max_by_feature


FEATURE_MAX_WEIGHTS = _feature_max_weights()


def validate_selected_traits(selected_traits: list[str]) -> None:
    """Validate feature names and enforce contradiction constraints."""
    unknown = [trait for trait in selected_traits if trait not in FEATURE_KEYS]
    if unknown:
        raise ValueError(f"Unknown trait(s): {', '.join(sorted(set(unknown)))}")

    selected = set(selected_traits)
    for trait in selected_traits:
        conflicts = CONTRADICTIONS.get(trait, set())
        overlap = conflicts & selected
        if overlap:
            conflict = sorted(overlap)[0]
            raise ValueError(
                f"Contradictory traits selected: {trait} conflicts with {conflict}. "
                "Choose only one."
            )


def slider_to_weight(feature: str, slider_value: int) -> float:
    """Map slider value (0-100) to a practical weight for the target feature."""
    if feature not in FEATURE_KEYS:
        raise ValueError(f"Unknown feature: {feature}")
    if slider_value < 0 or slider_value > 100:
        raise ValueError(f"Slider for {feature} must be between 0 and 100")

    max_weight = FEATURE_MAX_WEIGHTS[feature]
    return round((slider_value / 100.0) * max_weight, 4)


def build_profile_weights(
    base_profile: str,
    trait_sliders: dict[str, int],
) -> dict[str, float]:
    """Build a weight vector from base profile + selected trait sliders."""
    if base_profile not in PRESET_WEIGHTS:
        valid = ", ".join(sorted(PRESET_WEIGHTS))
        raise ValueError(f"Unknown base profile '{base_profile}'. Valid profiles: {valid}")

    selected_traits = list(trait_sliders.keys())
    validate_selected_traits(selected_traits)

    weights = dict(PRESET_WEIGHTS[base_profile])
    for feature, slider in trait_sliders.items():
        weights[feature] = slider_to_weight(feature, slider)

    return weights


def parse_trait_overrides(raw_traits: list[str]) -> dict[str, int]:
    """Parse repeated --trait flags in FEATURE=SLIDER format."""
    overrides: dict[str, int] = {}
    for raw in raw_traits:
        if "=" not in raw:
            raise ValueError(f"Invalid trait override '{raw}'. Use FEATURE=SLIDER")

        feature, slider_raw = raw.split("=", 1)
        feature = feature.strip().upper()
        slider_raw = slider_raw.strip()

        if feature not in FEATURE_KEYS:
            raise ValueError(f"Unknown trait '{feature}'")

        try:
            slider = int(slider_raw)
        except ValueError as exc:
            raise ValueError(f"Invalid slider '{slider_raw}' for trait {feature}") from exc

        if slider < 0 or slider > 100:
            raise ValueError(f"Slider for {feature} must be between 0 and 100")

        overrides[feature] = slider

    validate_selected_traits(list(overrides.keys()))
    return overrides


def _print_trait_catalog() -> None:
    print("Available traits (use each as FEATURE in --trait FEATURE=SLIDER):")
    for feature in FEATURE_KEYS:
        conflicts = sorted(CONTRADICTIONS.get(feature, set()))
        conflict_text = f"; conflicts: {', '.join(conflicts)}" if conflicts else ""
        print(f"  {feature}: {TRAIT_DESCRIPTIONS[feature]}{conflict_text}")


def _print_base_profiles() -> None:
    print("Base profiles:")
    for name in sorted(PRESET_WEIGHTS):
        print(f"  {name}")


def _interactive_collect(base_profile: str) -> dict[str, int]:
    """Simple terminal wizard for selecting traits and slider values."""
    print("Interactive AI profile creator")
    print(f"Base profile: {base_profile}")
    _print_trait_catalog()
    print("")

    selected: dict[str, int] = {}

    while True:
        raw = input("Select trait (FEATURE), or type 'done': ").strip().upper()
        if raw == "DONE":
            break
        if raw == "":
            continue
        if raw not in FEATURE_KEYS:
            print("Unknown trait. Try again.")
            continue

        if raw in selected:
            print(f"Trait {raw} is already selected.")
            continue

        conflicts = CONTRADICTIONS.get(raw, set())
        active_conflicts = sorted(conflicts & set(selected.keys()))
        if active_conflicts:
            print(
                f"Cannot add {raw}: conflicts with already selected trait(s) "
                f"{', '.join(active_conflicts)}."
            )
            continue

        slider_input = input(f"Slider for {raw} (0-100): ").strip()
        try:
            slider = int(slider_input)
            if slider < 0 or slider > 100:
                raise ValueError
        except ValueError:
            print("Slider must be an integer from 0 to 100.")
            continue

        selected[raw] = slider
        print(f"Added {raw} at {slider}.")

    return selected


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Create a custom AI profile from existing profile traits with "
            "per-trait sliders and contradiction checks."
        )
    )
    parser.add_argument(
        "--base",
        default="balanced",
        help="base profile to start from (default: balanced)",
    )
    parser.add_argument(
        "--name",
        default="custom",
        help="profile name to write into the output payload (default: custom)",
    )
    parser.add_argument(
        "--trait",
        action="append",
        default=[],
        help="trait slider override in FEATURE=SLIDER format; repeatable",
    )
    parser.add_argument(
        "--output",
        default="wahoo/custom_profile.json",
        help="output path for generated profile JSON (default: wahoo/custom_profile.json)",
    )
    parser.add_argument(
        "--interactive",
        action="store_true",
        help="open interactive trait selection wizard",
    )
    parser.add_argument(
        "--list-traits",
        action="store_true",
        help="print available traits and exit",
    )
    parser.add_argument(
        "--list-bases",
        action="store_true",
        help="print available base profiles and exit",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.list_traits:
        _print_trait_catalog()
        return 0

    if args.list_bases:
        _print_base_profiles()
        return 0

    base_profile = args.base.strip().lower()
    if base_profile not in PRESET_WEIGHTS:
        valid = ", ".join(sorted(PRESET_WEIGHTS))
        print(f"Error: Unknown base profile '{base_profile}'. Valid profiles: {valid}")
        return 2

    try:
        scripted_traits = parse_trait_overrides(args.trait)
        trait_sliders = dict(scripted_traits)
        if args.interactive or not trait_sliders:
            trait_sliders = _interactive_collect(base_profile)

        weights = build_profile_weights(base_profile, trait_sliders)
    except ValueError as exc:
        print(f"Error: {exc}")
        return 2

    output_dir = os.path.dirname(args.output)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    payload = {
        "profile_name": args.name,
        "base_profile": base_profile,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "selected_traits": [
            {
                "feature": feature,
                "description": TRAIT_DESCRIPTIONS[feature],
                "slider": slider,
                "weight": weights[feature],
            }
            for feature, slider in sorted(trait_sliders.items())
        ],
        "weights": weights,
    }

    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)

    print(f"Wrote custom AI profile to {args.output}")
    print(f"Base profile: {base_profile}")
    if trait_sliders:
        print("Selected traits:")
        for feature in sorted(trait_sliders):
            print(f"  {feature}: slider={trait_sliders[feature]} -> weight={weights[feature]:.4f}")
    else:
        print("Selected traits: none (profile mirrors base)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
