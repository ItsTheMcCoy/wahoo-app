"""Interactive and scripted tool for creating and managing AI profiles.

Capabilities:
  - Create a trait-slider profile payload (legacy single-file output mode)
    - Manage in-game profiles (list/add/update/rename/disable/restore)

Examples:
    python -m wahoo.profile_creator --ui
  python -m wahoo.profile_creator
  python -m wahoo.profile_creator --base balanced --trait RUN=85 --trait CAP=70
  python -m wahoo.profile_creator list
  python -m wahoo.profile_creator add --name my_style --base balanced --trait CAP=75
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

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
        _load_custom_profile_weights,
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
        _load_custom_profile_weights,
        _load_human_like_weights,
    )

FEATURE_KEYS = ("DEP", "RUN", "SPR", "CAP", "SAFE", "CTR", "DEN", "FLOW", "HOME", "FIN")
NON_TRAIT_BUILTIN_PROFILES = ("random", "expectimax")
MANAGER_CONFIG_PATH = os.path.join(os.path.dirname(__file__), "profiles_manager.json")

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

TRAIT_LONG_DESCRIPTIONS = {
    "DEP": (
        "Deployment / exit pressure. Higher DEP increases preference for moves "
        "that exit marbles from BASE onto TRACK (kind=exit_base), improving early rollout."
    ),
    "RUN": (
        "Single-runner focus. Higher RUN favors advancing your furthest-progress marble, "
        "concentrating progress on one lead piece."
    ),
    "SPR": (
        "Spread focus. Higher SPR favors advancing less-progressed marbles to diversify "
        "board presence."
    ),
    "CAP": (
        "Capture aggression. Higher CAP values prioritize capturing opponents, with larger "
        "reward for capturing marbles that had higher progress."
    ),
    "SAFE": (
        "Safety-first bias. SAFE scores net reduction in exposure to being captured. "
        "Existing profiles use up to 2.5 SAFE (for example Tortoise and Gatekeeper), "
        "so this slider range supports that stronger defensive style."
    ),
    "CTR": (
        "Shortcut eagerness. Higher CTR prefers entering center when available, "
        "trading immediate board position for shortcut opportunities."
    ),
    "DEN": (
        "Center denial. Higher DEN rewards center-entry moves that also bump an opponent "
        "from center, preventing their shortcut use."
    ),
    "FLOW": (
        "Flow control. Higher FLOW favors moves that reduce self-blocking and improve "
        "future mobility among your own marbles."
    ),
    "HOME": (
        "Home-lane engineering. Higher HOME emphasizes moves deeper into HOME slots, "
        "helping convert track progress into near-finish positioning."
    ),
    "FIN": (
        "Finish-over-fight bias. In states where both HOME and capture options exist, "
        "higher FIN leans toward taking HOME progress instead of fighting."
    ),
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
    "custom": dict(_load_custom_profile_weights()),
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
    """Validate feature names."""
    unknown = [trait for trait in selected_traits if trait not in FEATURE_KEYS]
    if unknown:
        raise ValueError(f"Unknown trait(s): {', '.join(sorted(set(unknown)))}")


def slider_to_weight(feature: str, slider_value: int) -> float:
    """Map slider value (0-100) to a practical weight for the target feature."""
    if feature not in FEATURE_KEYS:
        raise ValueError(f"Unknown feature: {feature}")
    if slider_value < 0 or slider_value > 100:
        raise ValueError(f"Slider for {feature} must be between 0 and 100")

    max_weight = FEATURE_MAX_WEIGHTS[feature]
    return round((slider_value / 100.0) * max_weight, 4)


def weight_to_slider(feature: str, weight_value: float) -> int:
    """Map a direct feature weight value back to slider units (0-100)."""
    if feature not in FEATURE_KEYS:
        raise ValueError(f"Unknown feature: {feature}")

    max_weight = FEATURE_MAX_WEIGHTS[feature]
    if max_weight <= 0.0:
        return 0

    if weight_value < 0 or weight_value > max_weight:
        raise ValueError(
            f"Weight for {feature} must be between 0 and {max_weight:.4f}"
        )

    return int(round((float(weight_value) / max_weight) * 100.0))


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


def _normalize_profile_name(name: str) -> str:
    cleaned = name.strip().lower()
    if not cleaned:
        raise ValueError("Profile name cannot be blank")
    return cleaned


def _default_manager_config() -> dict:
    return {
        "disabled_profiles": [],
        "aliases": {},
        "custom_profiles": {},
    }


def load_manager_config(path: str = MANAGER_CONFIG_PATH) -> dict:
    """Load profile management config with schema normalization."""
    default = _default_manager_config()
    if not os.path.exists(path):
        return default

    try:
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return default

    if not isinstance(payload, dict):
        return default

    disabled = payload.get("disabled_profiles", [])
    aliases = payload.get("aliases", {})
    custom_profiles = payload.get("custom_profiles", {})

    normalized_disabled = []
    if isinstance(disabled, list):
        for value in disabled:
            if isinstance(value, str):
                name = value.strip().lower()
                if name and name not in normalized_disabled:
                    normalized_disabled.append(name)

    normalized_aliases: dict[str, str] = {}
    if isinstance(aliases, dict):
        for alias, target in aliases.items():
            if not isinstance(alias, str) or not isinstance(target, str):
                continue
            alias_name = alias.strip().lower()
            target_name = target.strip().lower()
            if alias_name and target_name:
                normalized_aliases[alias_name] = target_name

    normalized_custom: dict[str, dict] = {}
    if isinstance(custom_profiles, dict):
        for name, profile_payload in custom_profiles.items():
            if not isinstance(name, str) or not isinstance(profile_payload, dict):
                continue
            profile_name = name.strip().lower()
            if not profile_name:
                continue
            weights = profile_payload.get("weights", {})
            if not isinstance(weights, dict):
                continue

            normalized_weights = dict(BALANCED_WEIGHTS)
            for key in FEATURE_KEYS:
                value = weights.get(key)
                if isinstance(value, (int, float)):
                    normalized_weights[key] = max(0.0, float(value))

            trait_sliders = profile_payload.get("trait_sliders", {})
            normalized_sliders: dict[str, int] = {}
            if isinstance(trait_sliders, dict):
                for feature, slider in trait_sliders.items():
                    if feature in FEATURE_KEYS and isinstance(slider, int) and 0 <= slider <= 100:
                        normalized_sliders[feature] = slider

            entry = {
                "base_profile": str(profile_payload.get("base_profile", "balanced")).strip().lower(),
                "weights": normalized_weights,
                "trait_sliders": normalized_sliders,
                "description": str(profile_payload.get("description", "")).strip(),
                "updated_at": str(profile_payload.get("updated_at", "")).strip(),
            }
            normalized_custom[profile_name] = entry

    return {
        "disabled_profiles": normalized_disabled,
        "aliases": normalized_aliases,
        "custom_profiles": normalized_custom,
    }


def save_manager_config(config: dict, path: str = MANAGER_CONFIG_PATH) -> None:
    """Persist profile management config to disk."""
    output_dir = os.path.dirname(path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(config, handle, indent=2)


def _builtin_profile_index() -> dict[str, dict]:
    """Return builtin profiles and metadata for management views."""
    builtins = {}
    for name, weights in PRESET_WEIGHTS.items():
        builtins[name] = {
            "name": name,
            "kind": "builtin-greedy",
            "source": "builtin",
            "weights": dict(weights),
        }
    for name in NON_TRAIT_BUILTIN_PROFILES:
        builtins[name] = {
            "name": name,
            "kind": "builtin-special",
            "source": "builtin",
            "weights": None,
        }
    return builtins


def effective_profile_index(config: dict | None = None) -> dict[str, dict]:
    """Return profiles visible in-game after applying manager config."""
    config = config or load_manager_config()
    resolved = _builtin_profile_index()

    aliases = config.get("aliases", {})
    if isinstance(aliases, dict):
        for alias, target in aliases.items():
            target_profile = resolved.get(target)
            if target_profile is None:
                continue
            aliased = dict(target_profile)
            aliased["name"] = alias
            aliased["source"] = f"alias:{target}"
            resolved[alias] = aliased

    custom_profiles = config.get("custom_profiles", {})
    if isinstance(custom_profiles, dict):
        for name, profile_payload in custom_profiles.items():
            if not isinstance(profile_payload, dict):
                continue
            weights = profile_payload.get("weights")
            if not isinstance(weights, dict):
                continue
            resolved[name] = {
                "name": name,
                "kind": "managed-greedy",
                "source": "managed",
                "weights": dict(weights),
                "base_profile": profile_payload.get("base_profile", "balanced"),
                "trait_sliders": dict(profile_payload.get("trait_sliders", {})),
                "description": profile_payload.get("description", ""),
            }

    disabled = set(config.get("disabled_profiles", []))
    for name in list(resolved.keys()):
        if name in disabled:
            resolved.pop(name, None)

    return resolved


def add_managed_profile(
    config: dict,
    *,
    name: str,
    base_profile: str,
    trait_sliders: dict[str, int],
    description: str = "",
    overwrite: bool = False,
) -> dict:
    """Add a managed profile or overwrite an existing one."""
    profile_name = _normalize_profile_name(name)
    base_name = _normalize_profile_name(base_profile)
    if base_name not in PRESET_WEIGHTS:
        valid = ", ".join(sorted(PRESET_WEIGHTS))
        raise ValueError(f"Unknown base profile '{base_name}'. Valid profiles: {valid}")

    existing = effective_profile_index(config)
    if profile_name in existing and not overwrite:
        raise ValueError(f"Profile '{profile_name}' already exists. Use --overwrite to replace it.")

    validate_selected_traits(list(trait_sliders.keys()))
    weights = build_profile_weights(base_name, trait_sliders)
    custom = config.setdefault("custom_profiles", {})
    if not isinstance(custom, dict):
        custom = {}
        config["custom_profiles"] = custom

    custom[profile_name] = {
        "base_profile": base_name,
        "weights": weights,
        "trait_sliders": dict(trait_sliders),
        "description": description.strip(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    disabled = config.setdefault("disabled_profiles", [])
    if isinstance(disabled, list):
        config["disabled_profiles"] = [n for n in disabled if n != profile_name]

    aliases = config.setdefault("aliases", {})
    if isinstance(aliases, dict):
        aliases.pop(profile_name, None)

    return custom[profile_name]


def update_managed_profile(
    config: dict,
    *,
    name: str,
    base_profile: str | None = None,
    trait_updates: dict[str, int] | None = None,
    description: str | None = None,
    reset_traits: bool = False,
) -> dict:
    """Update managed profile by name, creating an override when needed."""
    profile_name = _normalize_profile_name(name)
    trait_updates = trait_updates or {}
    validate_selected_traits(list(trait_updates.keys()))

    custom = config.setdefault("custom_profiles", {})
    if not isinstance(custom, dict):
        custom = {}
        config["custom_profiles"] = custom

    existing_payload = custom.get(profile_name, {}) if isinstance(custom.get(profile_name), dict) else {}

    if existing_payload:
        current_base = existing_payload.get("base_profile", "balanced")
        current_traits = {} if reset_traits else dict(existing_payload.get("trait_sliders", {}))
        current_description = existing_payload.get("description", "")
    else:
        current_base = profile_name if profile_name in PRESET_WEIGHTS else "balanced"
        current_traits = {}
        current_description = ""

    if profile_name in NON_TRAIT_BUILTIN_PROFILES and base_profile is None and not existing_payload:
        raise ValueError(
            f"Profile '{profile_name}' is a non-trait builtin. Provide --base to convert it to a trait-driven override."
        )

    next_base = _normalize_profile_name(base_profile) if base_profile is not None else current_base
    if next_base not in PRESET_WEIGHTS:
        valid = ", ".join(sorted(PRESET_WEIGHTS))
        raise ValueError(f"Unknown base profile '{next_base}'. Valid profiles: {valid}")

    current_traits.update(trait_updates)
    validate_selected_traits(list(current_traits.keys()))
    weights = build_profile_weights(next_base, current_traits)

    payload = {
        "base_profile": next_base,
        "weights": weights,
        "trait_sliders": dict(current_traits),
        "description": current_description if description is None else description.strip(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    custom[profile_name] = payload

    disabled = config.setdefault("disabled_profiles", [])
    if isinstance(disabled, list):
        config["disabled_profiles"] = [n for n in disabled if n != profile_name]

    aliases = config.setdefault("aliases", {})
    if isinstance(aliases, dict):
        aliases.pop(profile_name, None)

    return payload


def rename_managed_profile(
    config: dict,
    *,
    old_name: str,
    new_name: str,
    overwrite: bool = False,
) -> None:
    """Rename a profile; builtin names become alias-based renames."""
    old_profile = _normalize_profile_name(old_name)
    new_profile = _normalize_profile_name(new_name)
    if old_profile == new_profile:
        return

    existing = effective_profile_index(config)
    if old_profile not in existing:
        raise ValueError(f"Unknown profile '{old_profile}'")
    if new_profile in existing and not overwrite:
        raise ValueError(f"Profile '{new_profile}' already exists. Use --overwrite to replace it.")

    custom = config.setdefault("custom_profiles", {})
    aliases = config.setdefault("aliases", {})
    disabled = config.setdefault("disabled_profiles", [])
    if isinstance(custom, dict):
        custom.pop(new_profile, None)
    if isinstance(aliases, dict):
        aliases.pop(new_profile, None)

    if isinstance(custom, dict) and old_profile in custom:
        payload = custom.pop(old_profile)
        custom[new_profile] = payload
        if old_profile in PRESET_WEIGHTS or old_profile in NON_TRAIT_BUILTIN_PROFILES:
            if old_profile not in disabled:
                disabled.append(old_profile)
        return

    if isinstance(aliases, dict) and old_profile in aliases:
        target = aliases.pop(old_profile)
        aliases[new_profile] = target
        return

    # Builtin rename via alias + disable old name.
    if isinstance(aliases, dict):
        aliases[new_profile] = old_profile
    if isinstance(disabled, list) and old_profile not in disabled:
        disabled.append(old_profile)


def disable_managed_profile(config: dict, *, name: str) -> None:
    """Disable a profile so it no longer appears in game profile lists."""
    profile_name = _normalize_profile_name(name)
    custom = config.setdefault("custom_profiles", {})
    aliases = config.setdefault("aliases", {})
    disabled = config.setdefault("disabled_profiles", [])

    if isinstance(custom, dict):
        custom.pop(profile_name, None)
    if isinstance(aliases, dict):
        aliases.pop(profile_name, None)
    if isinstance(disabled, list) and profile_name not in disabled:
        disabled.append(profile_name)


def remove_managed_profile(config: dict, *, name: str) -> None:
    """Compatibility alias for disable_managed_profile()."""
    disable_managed_profile(config, name=name)


def restore_managed_profile(config: dict, *, name: str) -> None:
    """Restore visibility for a previously disabled profile name."""
    profile_name = _normalize_profile_name(name)
    disabled = config.setdefault("disabled_profiles", [])
    if isinstance(disabled, list):
        config["disabled_profiles"] = [n for n in disabled if n != profile_name]


def _print_trait_catalog() -> None:
    print("Available traits (use each as FEATURE in --trait FEATURE=SLIDER):")
    for feature in FEATURE_KEYS:
        print(f"  {feature}: {TRAIT_DESCRIPTIONS[feature]}")


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


def _launch_profile_creator_ui(default_output: str) -> int:
    """Launch a desktop UI for creating, editing, and disabling profiles."""
    try:
        import tkinter as tk
        from tkinter import filedialog, messagebox, scrolledtext
    except ImportError:
        print("Error: Tkinter is not available in this Python environment.")
        return 2

    root = tk.Tk()
    root.title("Wahoo Profile Creator")
    root.geometry("1200x780")
    root.minsize(1100, 700)

    header = tk.Label(
        root,
        text="Profile Manager (Create / Edit / Disable)",
        font=("Segoe UI", 16, "bold"),
        anchor="w",
    )
    header.pack(fill="x", padx=12, pady=(12, 6))

    body = tk.Frame(root)
    body.pack(fill="both", expand=True, padx=12, pady=(0, 8))

    list_panel = tk.LabelFrame(body, text="Profiles")
    list_panel.pack(side="left", fill="y", padx=(0, 10))

    editor_panel = tk.Frame(body)
    editor_panel.pack(side="left", fill="both", expand=True)

    profile_listbox = tk.Listbox(list_panel, width=34, height=26, exportselection=False)
    profile_listbox.pack(side="left", fill="y", padx=(8, 0), pady=8)

    list_scrollbar = tk.Scrollbar(list_panel, orient="vertical", command=profile_listbox.yview)
    list_scrollbar.pack(side="left", fill="y", padx=(4, 8), pady=8)
    profile_listbox.config(yscrollcommand=list_scrollbar.set)

    list_actions = tk.Frame(list_panel)
    list_actions.pack(fill="x", padx=8, pady=(0, 8))

    profile_name_var = tk.StringVar(value="new_profile")
    base_options = sorted(PRESET_WEIGHTS.keys())
    base_profile_var = tk.StringVar(value="balanced")
    description_var = tk.StringVar(value="")
    output_var = tk.StringVar(value=default_output)
    overwrite_var = tk.BooleanVar(value=False)
    status_var = tk.StringVar(value="Select a profile or click Create New.")

    form = tk.Frame(editor_panel)
    form.pack(fill="x", pady=(0, 8))

    tk.Label(form, text="Profile name:").grid(row=0, column=0, sticky="w", padx=(0, 8), pady=4)
    tk.Entry(form, textvariable=profile_name_var, width=28).grid(
        row=0, column=1, sticky="w", padx=(0, 14), pady=4
    )

    tk.Label(form, text="Base profile:").grid(row=0, column=2, sticky="w", padx=(0, 8), pady=4)
    tk.OptionMenu(form, base_profile_var, *base_options).grid(
        row=0, column=3, sticky="w", padx=(0, 14), pady=4
    )

    tk.Label(form, text="Description:").grid(row=1, column=0, sticky="w", padx=(0, 8), pady=4)
    tk.Entry(form, textvariable=description_var, width=54).grid(
        row=1, column=1, columnspan=3, sticky="we", padx=(0, 14), pady=4
    )

    tk.Label(form, text="Export path:").grid(row=2, column=0, sticky="w", padx=(0, 8), pady=4)
    tk.Entry(form, textvariable=output_var, width=54).grid(
        row=2, column=1, columnspan=2, sticky="we", padx=(0, 8), pady=4
    )

    def _choose_output_path() -> None:
        selected = filedialog.asksaveasfilename(
            title="Export Profile JSON",
            defaultextension=".json",
            initialfile=Path(output_var.get()).name,
            filetypes=[("JSON files", "*.json"), ("All files", "*.*")],
        )
        if selected:
            output_var.set(selected)

    tk.Button(form, text="Browse...", command=_choose_output_path).grid(
        row=2, column=3, sticky="w", padx=(0, 14), pady=4
    )
    tk.Checkbutton(form, text="Overwrite existing managed profile", variable=overwrite_var).grid(
        row=3, column=0, columnspan=3, sticky="w", pady=(4, 2)
    )

    sliders_container = tk.LabelFrame(editor_panel, text="Trait Overrides (weight range per feature)")
    sliders_container.pack(fill="x", pady=(0, 8))

    slider_vars: dict[str, tk.DoubleVar] = {}
    override_vars: dict[str, tk.BooleanVar] = {}
    slider_value_labels: dict[str, tk.Label] = {}

    for idx, feature in enumerate(FEATURE_KEYS):
        row = idx // 2
        col_base = (idx % 2) * 5
        max_weight = FEATURE_MAX_WEIGHTS[feature]

        override_vars[feature] = tk.BooleanVar(value=False)
        slider_vars[feature] = tk.DoubleVar(value=float(PRESET_WEIGHTS["balanced"][feature]))

        tk.Checkbutton(
            sliders_container,
            text="Override",
            variable=override_vars[feature],
            anchor="w",
        ).grid(row=row, column=col_base, sticky="w", padx=(8, 6), pady=6)

        tk.Label(
            sliders_container,
            text="%s (%0.2f max): %s" % (feature, max_weight, TRAIT_DESCRIPTIONS[feature]),
            anchor="w",
        ).grid(row=row, column=col_base + 1, sticky="w", padx=(0, 6), pady=6)

        scale = tk.Scale(
            sliders_container,
            from_=0,
            to=max_weight,
            orient="horizontal",
            variable=slider_vars[feature],
            showvalue=False,
            length=180,
            resolution=0.01,
        )
        scale.grid(row=row, column=col_base + 2, sticky="we", padx=(0, 6), pady=6)

        value_label = tk.Label(sliders_container, text="0.00", width=6)
        value_label.grid(row=row, column=col_base + 3, sticky="w", padx=(0, 10), pady=6)
        slider_value_labels[feature] = value_label

        def _open_trait_details(feat: str = feature) -> None:
            details = TRAIT_LONG_DESCRIPTIONS.get(feat, TRAIT_DESCRIPTIONS.get(feat, ""))
            messagebox.showinfo("%s Trait Details" % feat, details)

        tk.Button(
            sliders_container,
            text="Details",
            width=8,
            command=_open_trait_details,
        ).grid(row=row, column=col_base + 4, sticky="w", padx=(0, 8), pady=6)

    preview_frame = tk.LabelFrame(editor_panel, text="Generated Payload Preview")
    preview_frame.pack(fill="both", expand=True, pady=(0, 8))
    preview_text = scrolledtext.ScrolledText(preview_frame, wrap="none", font=("Consolas", 10))
    preview_text.pack(fill="both", expand=True, padx=8, pady=8)
    preview_text.configure(state="disabled")

    footer = tk.Frame(root)
    footer.pack(fill="x", padx=12, pady=(0, 12))
    tk.Label(footer, textvariable=status_var, anchor="w", fg="#184b18").pack(
        side="left", fill="x", expand=True
    )

    profile_rows: list[tuple[str, str]] = []

    def _set_form_from_base(base_profile: str) -> None:
        base_weights = PRESET_WEIGHTS[base_profile]
        for feature in FEATURE_KEYS:
            if not override_vars[feature].get():
                slider_vars[feature].set(float(base_weights[feature]))

    def _refresh_profile_list(select_name: str | None = None) -> None:
        nonlocal profile_rows
        config = load_manager_config()
        profiles = effective_profile_index(config)
        profile_rows = []
        profile_listbox.delete(0, "end")

        for name in sorted(profiles):
            source = str(profiles[name].get("source", "unknown"))
            profile_rows.append((name, source))
            profile_listbox.insert("end", f"{name:<18} [{source}]")

        if not profile_rows:
            return

        if select_name:
            for idx, (name, _source) in enumerate(profile_rows):
                if name == select_name:
                    profile_listbox.selection_clear(0, "end")
                    profile_listbox.selection_set(idx)
                    profile_listbox.see(idx)
                    return

        profile_listbox.selection_clear(0, "end")
        profile_listbox.selection_set(0)

    def _selected_trait_sliders() -> dict[str, int]:
        selected: dict[str, int] = {}
        for feature in FEATURE_KEYS:
            if not override_vars[feature].get():
                continue
            weight_value = float(slider_vars[feature].get())
            selected[feature] = weight_to_slider(feature, weight_value)
        validate_selected_traits(list(selected.keys()))
        return selected

    def _current_selection_name() -> str | None:
        picked = profile_listbox.curselection()
        if not picked:
            return None
        idx = int(picked[0])
        if idx < 0 or idx >= len(profile_rows):
            return None
        return profile_rows[idx][0]

    def _create_new_profile() -> None:
        profile_name_var.set("new_profile")
        base_profile_var.set("balanced")
        description_var.set("")
        overwrite_var.set(False)
        for feature in FEATURE_KEYS:
            override_vars[feature].set(False)
        _set_form_from_base("balanced")
        _refresh_preview()
        status_var.set("Create New: set name, base, overrides, then Save Managed Profile.")

    def _load_profile_into_editor(name: str) -> None:
        config = load_manager_config()
        profiles = effective_profile_index(config)
        selected = profiles.get(name)
        if selected is None:
            status_var.set(f"Profile '{name}' no longer exists.")
            return

        profile_name_var.set(name)
        overwrite_var.set(True)

        custom = config.get("custom_profiles", {})
        custom_payload = custom.get(name, {}) if isinstance(custom, dict) else {}

        base_profile = "balanced"
        trait_sliders: dict[str, int] = {}
        description = ""

        if isinstance(custom_payload, dict) and custom_payload:
            base_candidate = str(custom_payload.get("base_profile", "balanced")).strip().lower()
            if base_candidate in PRESET_WEIGHTS:
                base_profile = base_candidate
            sliders_raw = custom_payload.get("trait_sliders", {})
            if isinstance(sliders_raw, dict):
                for feature in FEATURE_KEYS:
                    value = sliders_raw.get(feature)
                    if isinstance(value, int) and 0 <= value <= 100:
                        trait_sliders[feature] = value
            description = str(custom_payload.get("description", "")).strip()
        elif name in PRESET_WEIGHTS:
            base_profile = name
        elif str(selected.get("source", "")).startswith("alias:"):
            target = str(selected.get("source", "")).split(":", 1)[1]
            if target in PRESET_WEIGHTS:
                base_profile = target
        elif name in NON_TRAIT_BUILTIN_PROFILES:
            base_profile = "balanced"

        base_profile_var.set(base_profile)
        description_var.set(description)

        for feature in FEATURE_KEYS:
            override_vars[feature].set(False)

        _set_form_from_base(base_profile)

        for feature, slider in trait_sliders.items():
            override_vars[feature].set(True)
            slider_vars[feature].set(slider_to_weight(feature, slider))

        # Fallback: infer overrides from effective weights when trait sliders are not available.
        if not trait_sliders and isinstance(selected.get("weights"), dict):
            base_weights = PRESET_WEIGHTS[base_profile]
            weights = selected["weights"]
            for feature in FEATURE_KEYS:
                candidate = weights.get(feature)
                if not isinstance(candidate, (int, float)):
                    continue
                candidate_weight = max(0.0, min(float(candidate), FEATURE_MAX_WEIGHTS[feature]))
                if abs(candidate_weight - float(base_weights[feature])) > 0.0001:
                    override_vars[feature].set(True)
                    slider_vars[feature].set(candidate_weight)

        _refresh_preview()
        if name in NON_TRAIT_BUILTIN_PROFILES:
            status_var.set(
                "Loaded '%s'. Saving will convert it to a trait-driven managed profile." % name
            )
        else:
            status_var.set("Loaded '%s' into editor." % name)

    def _build_payload_for_ui() -> tuple[dict, dict[str, int], dict[str, float]]:
        profile_name = profile_name_var.get().strip()
        if not profile_name:
            raise ValueError("Profile name cannot be blank")

        base_profile = base_profile_var.get().strip().lower()
        if base_profile not in PRESET_WEIGHTS:
            valid = ", ".join(sorted(PRESET_WEIGHTS))
            raise ValueError(f"Unknown base profile '{base_profile}'. Valid profiles: {valid}")

        sliders = _selected_trait_sliders()
        weights = build_profile_weights(base_profile, sliders)
        payload = {
            "profile_name": profile_name,
            "base_profile": base_profile,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "selected_traits": [
                {
                    "feature": feature,
                    "description": TRAIT_DESCRIPTIONS[feature],
                    "slider": slider,
                    "weight": weights[feature],
                }
                for feature, slider in sorted(sliders.items())
            ],
            "weights": weights,
            "description": description_var.get().strip(),
        }
        return payload, sliders, weights

    def _set_preview(payload: dict) -> None:
        preview_text.configure(state="normal")
        preview_text.delete("1.0", "end")
        preview_text.insert("1.0", json.dumps(payload, indent=2))
        preview_text.configure(state="disabled")

    def _refresh_preview(*_args) -> None:
        for feature in FEATURE_KEYS:
            slider_value_labels[feature].configure(text=f"{float(slider_vars[feature].get()):0.2f}")

        try:
            payload, sliders, _weights = _build_payload_for_ui()
            _set_preview(payload)
            status_var.set("Ready: %d trait override(s) selected." % len(sliders))
        except ValueError as exc:
            status_var.set(f"Validation error: {exc}")

    def _save_managed_profile() -> None:
        try:
            _payload, sliders, _weights = _build_payload_for_ui()
            profile_name = profile_name_var.get().strip()
            base_profile = base_profile_var.get().strip().lower()
            config = load_manager_config()
            add_managed_profile(
                config,
                name=profile_name,
                base_profile=base_profile,
                trait_sliders=sliders,
                description=description_var.get().strip(),
                overwrite=bool(overwrite_var.get()),
            )
            save_manager_config(config)
            _refresh_profile_list(select_name=profile_name.strip().lower())
            status_var.set("Saved managed profile '%s'." % profile_name.strip().lower())
            messagebox.showinfo("Profile Saved", "Managed profile saved to profiles_manager.json")
        except ValueError as exc:
            status_var.set(f"Save failed: {exc}")
            messagebox.showerror("Save Failed", str(exc))

    def _export_json() -> None:
        try:
            payload, _sliders, _weights = _build_payload_for_ui()
            output_path = output_var.get().strip()
            if not output_path:
                raise ValueError("Export path cannot be blank")

            output_dir = os.path.dirname(output_path)
            if output_dir:
                os.makedirs(output_dir, exist_ok=True)

            with open(output_path, "w", encoding="utf-8") as handle:
                json.dump(payload, handle, indent=2)

            status_var.set(f"Exported profile JSON to {output_path}")
            messagebox.showinfo("Export Complete", f"Wrote custom AI profile to:\n{output_path}")
        except (OSError, ValueError) as exc:
            status_var.set(f"Export failed: {exc}")
            messagebox.showerror("Export Failed", str(exc))

    def _reset_sliders() -> None:
        base_profile = base_profile_var.get().strip().lower()
        if base_profile not in PRESET_WEIGHTS:
            base_profile = "balanced"
        for feature in FEATURE_KEYS:
            override_vars[feature].set(False)
        _set_form_from_base(base_profile)
        _refresh_preview()

    def _disable_selected_profile() -> None:
        selected_name = _current_selection_name()
        if not selected_name:
            messagebox.showwarning("Disable Profile", "Select a profile to disable.")
            return

        confirmed = messagebox.askyesno(
            "Disable Profile",
            "Disable '%s' so it no longer appears in-game?" % selected_name,
        )
        if not confirmed:
            return

        config = load_manager_config()
        disable_managed_profile(config, name=selected_name)
        save_manager_config(config)
        _refresh_profile_list()
        status_var.set("Disabled '%s' (hidden from in-game profile lists)." % selected_name)

    def _edit_selected_profile() -> None:
        selected_name = _current_selection_name()
        if not selected_name:
            messagebox.showwarning("Edit Profile", "Select a profile to edit.")
            return
        _load_profile_into_editor(selected_name)

    def _on_base_changed(*_args) -> None:
        base_profile = base_profile_var.get().strip().lower()
        if base_profile not in PRESET_WEIGHTS:
            return
        _set_form_from_base(base_profile)
        _refresh_preview()

    def _on_profile_click(_event) -> None:
        selected_name = _current_selection_name()
        if selected_name:
            _load_profile_into_editor(selected_name)

    tk.Button(list_actions, text="Create New", command=_create_new_profile).pack(fill="x", pady=(0, 6))
    tk.Button(list_actions, text="Edit Selected", command=_edit_selected_profile).pack(fill="x", pady=(0, 6))
    tk.Button(list_actions, text="Disable Selected", command=_disable_selected_profile).pack(
        fill="x", pady=(0, 6)
    )
    tk.Button(list_actions, text="Refresh", command=_refresh_profile_list).pack(fill="x")

    action_bar = tk.Frame(root)
    action_bar.pack(fill="x", padx=12, pady=(0, 12))
    tk.Button(action_bar, text="Reset Sliders", command=_reset_sliders).pack(side="left", padx=(0, 8))
    tk.Button(action_bar, text="Save Managed Profile", command=_save_managed_profile).pack(
        side="left", padx=(0, 8)
    )
    tk.Button(action_bar, text="Export JSON", command=_export_json).pack(side="left", padx=(0, 8))
    tk.Button(action_bar, text="Close", command=root.destroy).pack(side="right")

    profile_listbox.bind("<<ListboxSelect>>", _on_profile_click)

    base_profile_var.trace_add("write", _on_base_changed)
    profile_name_var.trace_add("write", _refresh_preview)
    description_var.trace_add("write", _refresh_preview)
    for feature in FEATURE_KEYS:
        slider_vars[feature].trace_add("write", _refresh_preview)
        override_vars[feature].trace_add("write", _refresh_preview)

    _refresh_profile_list()
    _refresh_preview()
    root.mainloop()
    return 0


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Create and manage AI profiles with granular trait sliders "
            "for all strategy features."
        )
    )
    parser.add_argument(
        "--ui",
        action="store_true",
        help="launch desktop UI for profile creation",
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

    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("list", help="list effective in-game profiles")

    add_parser = subparsers.add_parser("add", help="add a managed profile")
    add_parser.add_argument("--name", required=True, help="profile name")
    add_parser.add_argument("--base", default="balanced", help="base profile")
    add_parser.add_argument(
        "--trait",
        action="append",
        default=[],
        help="trait slider in FEATURE=SLIDER format",
    )
    add_parser.add_argument("--description", default="", help="optional profile description")
    add_parser.add_argument("--overwrite", action="store_true", help="replace if name already exists")

    update_parser = subparsers.add_parser("update", help="update or override a profile")
    update_parser.add_argument("--name", required=True, help="profile name")
    update_parser.add_argument("--base", help="optional new base profile")
    update_parser.add_argument(
        "--trait",
        action="append",
        default=[],
        help="trait slider update in FEATURE=SLIDER format",
    )
    update_parser.add_argument(
        "--reset-traits",
        action="store_true",
        help="clear previous managed trait sliders before applying --trait updates",
    )
    update_parser.add_argument("--description", help="optional new description")

    rename_parser = subparsers.add_parser("rename", help="rename a profile")
    rename_parser.add_argument("--name", required=True, help="existing profile name")
    rename_parser.add_argument("--new-name", required=True, help="new profile name")
    rename_parser.add_argument("--overwrite", action="store_true", help="replace existing target name")

    disable_parser = subparsers.add_parser(
        "disable",
        help="disable profile so it no longer appears in-game",
    )
    disable_parser.add_argument("--name", required=True, help="profile name")

    remove_parser = subparsers.add_parser(
        "remove",
        help="deprecated alias for disable",
    )
    remove_parser.add_argument("--name", required=True, help="profile name")

    restore_parser = subparsers.add_parser("restore", help="restore a removed/disabled profile name")
    restore_parser.add_argument("--name", required=True, help="profile name")

    return parser


def _handle_management_command(args: argparse.Namespace) -> int:
    config = load_manager_config()

    try:
        if args.command == "list":
            profiles = effective_profile_index(config)
            print("In-game profiles:")
            for name in sorted(profiles):
                meta = profiles[name]
                print(f"  {name:<14} source={meta.get('source', 'unknown')}")

            disabled = config.get("disabled_profiles", [])
            if disabled:
                print("Disabled profile names:")
                for name in sorted(disabled):
                    print(f"  {name}")
            return 0

        if args.command == "add":
            sliders = parse_trait_overrides(args.trait)
            payload = add_managed_profile(
                config,
                name=args.name,
                base_profile=args.base,
                trait_sliders=sliders,
                description=args.description,
                overwrite=args.overwrite,
            )
            save_manager_config(config)
            print(f"Added profile '{args.name.strip().lower()}'.")
            print(f"Base: {payload['base_profile']}")
            return 0

        if args.command == "update":
            sliders = parse_trait_overrides(args.trait)
            payload = update_managed_profile(
                config,
                name=args.name,
                base_profile=args.base,
                trait_updates=sliders,
                description=args.description,
                reset_traits=args.reset_traits,
            )
            save_manager_config(config)
            print(f"Updated profile '{args.name.strip().lower()}'.")
            print(f"Base: {payload['base_profile']}")
            return 0

        if args.command == "rename":
            rename_managed_profile(
                config,
                old_name=args.name,
                new_name=args.new_name,
                overwrite=args.overwrite,
            )
            save_manager_config(config)
            print(
                f"Renamed profile '{args.name.strip().lower()}' -> "
                f"'{args.new_name.strip().lower()}'."
            )
            return 0

        if args.command == "disable" or args.command == "remove":
            disable_managed_profile(config, name=args.name)
            save_manager_config(config)
            print(f"Disabled profile '{args.name.strip().lower()}' from in-game availability.")
            return 0

        if args.command == "restore":
            restore_managed_profile(config, name=args.name)
            save_manager_config(config)
            print(f"Restored profile name '{args.name.strip().lower()}'.")
            return 0
    except ValueError as exc:
        print(f"Error: {exc}")
        return 2

    return 0


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.command:
        return _handle_management_command(args)

    if args.ui:
        return _launch_profile_creator_ui(args.output)

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
