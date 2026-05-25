"""Compatibility entrypoint for running the Wahoo game from repository root."""

import os
import sys

ROOT = os.path.dirname(__file__)
SRC = os.path.join(ROOT, "src")
if SRC not in sys.path:
    sys.path.insert(0, SRC)

from wahoo.play import main


if __name__ == "__main__":
    main()
