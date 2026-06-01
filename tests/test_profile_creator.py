"""Tests for custom AI profile creation utilities."""

import pytest

from wahoo.profile_creator import (
    build_profile_weights,
    parse_trait_overrides,
    slider_to_weight,
    validate_selected_traits,
)


def test_validate_selected_traits_rejects_contradiction():
    with pytest.raises(ValueError, match="Contradictory traits selected"):
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


def test_build_profile_weights_applies_selected_trait_sliders():
    weights = build_profile_weights("balanced", {"RUN": 80, "CAP": 50})

    assert weights["RUN"] == pytest.approx(0.8)
    assert weights["CAP"] == pytest.approx(0.5)
    assert weights["HOME"] == pytest.approx(0.7)


def test_build_profile_weights_rejects_unknown_base_profile():
    with pytest.raises(ValueError, match="Unknown base profile"):
        build_profile_weights("not_real", {"RUN": 80})
