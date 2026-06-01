"""Tests for custom AI profile creator and manager utilities."""

import pytest

from wahoo.profile_creator import (
    add_managed_profile,
    build_profile_weights,
    effective_profile_index,
    parse_trait_overrides,
    remove_managed_profile,
    rename_managed_profile,
    restore_managed_profile,
    slider_to_weight,
    update_managed_profile,
    validate_selected_traits,
    weight_to_slider,
)


def _empty_config() -> dict:
    return {
        "disabled_profiles": [],
        "aliases": {},
        "custom_profiles": {},
    }


def test_validate_selected_traits_allows_combined_traits():
    validate_selected_traits(["RUN", "SPR"])


def test_parse_trait_overrides_parses_valid_input():
    overrides = parse_trait_overrides(["run=85", "cap=70"])

    assert overrides == {"RUN": 85, "CAP": 70}


def test_parse_trait_overrides_rejects_invalid_slider():
    with pytest.raises(ValueError, match="between 0 and 100"):
        parse_trait_overrides(["RUN=101"])


def test_slider_to_weight_uses_feature_max_scale():
    assert slider_to_weight("RUN", 80) == pytest.approx(0.8)
    assert slider_to_weight("SAFE", 40) == pytest.approx(1.0)


def test_weight_to_slider_uses_feature_max_scale():
    assert weight_to_slider("RUN", 0.8) == 80
    assert weight_to_slider("SAFE", 1.0) == 40


def test_weight_to_slider_rejects_out_of_range_value():
    with pytest.raises(ValueError, match="must be between"):
        weight_to_slider("RUN", 1.1)


def test_build_profile_weights_applies_selected_trait_sliders():
    weights = build_profile_weights("balanced", {"RUN": 80, "CAP": 50})

    assert weights["RUN"] == pytest.approx(0.8)
    assert weights["CAP"] == pytest.approx(0.5)
    assert weights["HOME"] == pytest.approx(0.7)


def test_build_profile_weights_rejects_unknown_base_profile():
    with pytest.raises(ValueError, match="Unknown base profile"):
        build_profile_weights("not_real", {"RUN": 80})


def test_add_managed_profile_adds_effective_profile():
    config = _empty_config()

    add_managed_profile(
        config,
        name="my_style",
        base_profile="balanced",
        trait_sliders={"RUN": 75},
    )
    profiles = effective_profile_index(config)

    assert "my_style" in profiles
    assert profiles["my_style"]["source"] == "managed"


def test_rename_builtin_profile_creates_alias_and_disables_old_name():
    config = _empty_config()

    rename_managed_profile(config, old_name="sprinter", new_name="blitz")
    profiles = effective_profile_index(config)

    assert "blitz" in profiles
    assert "sprinter" not in profiles


def test_update_builtin_profile_overrides_traits():
    config = _empty_config()

    update_managed_profile(
        config,
        name="balanced",
        trait_updates={"CAP": 90},
    )
    profiles = effective_profile_index(config)

    assert profiles["balanced"]["source"] == "managed"
    assert profiles["balanced"]["weights"]["CAP"] == pytest.approx(0.9)


def test_remove_and_restore_profile_name():
    config = _empty_config()

    remove_managed_profile(config, name="swarm")
    assert "swarm" not in effective_profile_index(config)

    restore_managed_profile(config, name="swarm")
    assert "swarm" in effective_profile_index(config)
