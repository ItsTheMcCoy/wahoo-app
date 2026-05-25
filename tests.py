"""Compatibility test runner for repository-root execution."""

import os
import sys

ROOT = os.path.dirname(__file__)
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)

from tests.test_wahoo import main


if __name__ == "__main__":
    main()
