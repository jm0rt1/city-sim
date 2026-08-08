#!/usr/bin/env python3
"""Build deterministic color or grayscale literal-scale evidence sheets."""

from __future__ import annotations

import argparse
from pathlib import Path

from single_angle_harness import build_literal_scale_sheet, repo_root


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--grayscale", action="store_true")
    args = parser.parse_args()
    names = ("block", "neighborhood", "city")
    inputs = [(name, args.input_root / f"generated_v4_residential_l01_{name}.png") for name in names]
    result = build_literal_scale_sheet(inputs, args.output, grayscale=args.grayscale)
    print(result)


if __name__ == "__main__":
    main()
