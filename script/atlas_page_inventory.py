#!/usr/bin/env python3
"""Print the exact production atlas page inventory declared by a manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path, PurePosixPath


def load_page_paths(manifest_path: Path) -> list[str]:
    with manifest_path.open(encoding="utf-8") as source:
        payload = json.load(source)

    if payload.get("production_selection") is not True:
        raise ValueError("manifest is not the production selection")

    pages = payload.get("pages")
    if not isinstance(pages, list) or not pages:
        raise ValueError("manifest pages must be a non-empty list")

    paths: list[str] = []
    seen: set[str] = set()
    for index, page in enumerate(pages):
        if not isinstance(page, dict):
            raise ValueError(f"manifest page {index} must be an object")
        value = page.get("file")
        if not isinstance(value, str) or not value:
            raise ValueError(f"manifest page {index} is missing file")

        relative_path = PurePosixPath(value)
        if (
            relative_path.is_absolute()
            or value != relative_path.as_posix()
            or len(relative_path.parts) < 3
            or relative_path.parts[0] != "pages"
            or any(part in {".", ".."} for part in relative_path.parts)
            or relative_path.suffix.lower() != ".png"
        ):
            raise ValueError(f"manifest page {index} has unsafe file path: {value}")
        if value in seen:
            raise ValueError(f"manifest page file is duplicated: {value}")

        seen.add(value)
        paths.append(value)

    return paths


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {Path(argv[0]).name} MANIFEST", file=sys.stderr)
        return 2

    try:
        page_paths = load_page_paths(Path(argv[1]))
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(*page_paths, sep="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
