#!/usr/bin/env python3
"""Claim-path entrypoint for the West v14 compatibility proof."""
from pathlib import Path
import runpy


if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).resolve().parent / "v14-compatibility-v01" / "test_v14_compatibility.py"), run_name="__main__")
