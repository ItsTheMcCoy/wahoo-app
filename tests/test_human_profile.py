import json

import pytest

from wahoo.ai import PROFILES
from wahoo.human_profile import FEATURE_KEYS, fit_human_like_profile, main


def _make_recording_with_reasoned_turn(sample_count: int = 1) -> dict:
    entries = []
    # One dummy turn event per sample.
    for idx in range(sample_count):
        entries.append(
            {
                "index": len(entries),
                "event": {
                    "type": "turn",
                    "player": 0,
                    "roll": 1,
                    "human_reasoning": "Prefer safer pressure line.",
                },
                "state": {},
            }
        )
        entries.append(
            {
                "index": len(entries),
                "event": {
                    "type": "turn_detail",
                    "turn_index": idx + 1,
                    "decision_type": "mixed",
                    "chosen_move_index": 0,
                    "candidate_moves": [
                        {
                            "features": {
                                "DEP": 1.0,
                                "RUN": 0.8,
                                "SPR": 0.2,
                                "CAP": 0.5,
                                "SAFE": 0.7,
                                "CTR": 0.0,
                                "DEN": 0.0,
                                "FLOW": 0.6,
                                "HOME": 0.0,
                                "FIN": 0.5,
                            }
                        },
                        {
                            "features": {
                                "DEP": 0.0,
                                "RUN": 0.2,
                                "SPR": 0.8,
                                "CAP": 0.1,
                                "SAFE": 0.2,
                                "CTR": 0.0,
                                "DEN": 0.0,
                                "FLOW": 0.3,
                                "HOME": 0.0,
                                "FIN": 0.5,
                            }
                        },
                    ],
                },
                "state": {},
            }
        )
    return {"entries": entries}


def test_fit_human_like_profile_uses_reasoned_discretionary_samples():
    recording = _make_recording_with_reasoned_turn(sample_count=2)

    fit = fit_human_like_profile([recording], scale=1.0)

    assert fit["sample_count"] == 2
    assert set(fit["weights"]) == set(FEATURE_KEYS)
    assert fit["weights"]["DEP"] > 0.6
    assert fit["weights"]["SPR"] < 0.6


def test_fit_human_like_profile_raises_when_no_samples():
    recording = {"entries": [{"event": {"type": "turn", "human_reasoning": None}}]}

    with pytest.raises(ValueError):
        fit_human_like_profile([recording])


def test_cli_writes_profile_file(tmp_path):
    source_path = tmp_path / "game_test.json"
    output_path = tmp_path / "human_like_profile.json"
    with source_path.open("w", encoding="utf-8") as handle:
        json.dump(_make_recording_with_reasoned_turn(sample_count=1), handle)

    exit_code = main(["--input", str(source_path), "--output", str(output_path)])

    assert exit_code == 0
    payload = json.loads(output_path.read_text(encoding="utf-8"))
    assert payload["profile_name"] == "human_like"
    assert payload["sample_count"] == 1
    assert set(payload["weights"]) == set(FEATURE_KEYS)


def test_human_like_profile_is_registered():
    assert "human_like" in PROFILES
