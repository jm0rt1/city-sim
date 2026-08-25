#!/usr/bin/env python3
"""Regression tests for manifest-driven release atlas verification."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "script"))

from atlas_page_inventory import load_page_paths


ATLAS = (
    ROOT
    / "Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas"
)
PRODUCTION_MANIFEST = ATLAS / "generated-v4-manifest.json"


class AtlasPageInventoryTests(unittest.TestCase):
    def test_production_manifest_matches_every_packaged_page(self) -> None:
        declared = load_page_paths(PRODUCTION_MANIFEST)
        packaged = sorted(
            path.relative_to(ATLAS).as_posix()
            for path in (ATLAS / "pages").glob("*/*.png")
        )

        self.assertEqual(sorted(declared), packaged)
        self.assertIn("pages/block/page-03.png", declared)

    def test_duplicate_page_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "duplicated"):
            self._load_fixture(
                [
                    {"file": "pages/block/page-00.png"},
                    {"file": "pages/block/page-00.png"},
                ]
            )

    def test_path_escape_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self._load_fixture([{"file": "pages/../outside.png"}])

    def _load_fixture(self, pages: list[dict[str, str]]) -> list[str]:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "manifest.json"
            path.write_text(
                json.dumps({"production_selection": True, "pages": pages}),
                encoding="utf-8",
            )
            return load_page_paths(path)


if __name__ == "__main__":
    unittest.main()
