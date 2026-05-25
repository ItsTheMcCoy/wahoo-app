"""Compatibility re-export for game_state module."""

import os
import sys

ROOT = os.path.dirname(__file__)
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)

from wahoo.game_state import *  # noqa: F401,F403
