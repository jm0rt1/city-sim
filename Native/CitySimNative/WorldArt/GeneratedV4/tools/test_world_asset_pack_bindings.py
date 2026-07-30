#!/usr/bin/env python3
"""Focused negative tests for accepted explicit directional source bindings."""

from __future__ import annotations

import copy
import json
import unittest

from build_world_asset_pack import (
    PLAY073_INDUSTRIAL_L3_SELECTION,
    repository_path,
    validate_explicit_source_binding,
)


class ExplicitSourceBindingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        catalog = json.loads(
            PLAY073_INDUSTRIAL_L3_SELECTION.read_text(encoding="utf-8")
        )
        cls.selections = {
            selection["direction"]: selection
            for selection in catalog["selections"]
        }

    def binding_inputs(
        self,
        direction: str,
    ) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
        selection = copy.deepcopy(self.selections[direction])
        provenance = json.loads(
            repository_path(selection["provenance_file"]).read_text(encoding="utf-8")
        )
        scene = json.loads(
            repository_path(selection["scene_descriptor_file"]).read_text(
                encoding="utf-8"
            )
        )
        return selection, provenance, scene

    def test_repaired_family_bindings_pass(self) -> None:
        for direction in ("north", "east", "south", "west"):
            with self.subTest(direction=direction):
                selection, provenance, scene = self.binding_inputs(direction)
                validate_explicit_source_binding(
                    selection,
                    provenance,
                    scene,
                    f"industrial_l03_v0_{direction}",
                )

    def test_wrong_descriptor_revision_is_rejected(self) -> None:
        selection, provenance, scene = self.binding_inputs("east")
        scene["sourceRevision"] = "source-v06"
        with self.assertRaisesRegex(SystemExit, "descriptor source revision mismatch"):
            validate_explicit_source_binding(
                selection,
                provenance,
                scene,
                "industrial_l03_v0_east",
            )

    def test_swapped_north_west_library_is_rejected(self) -> None:
        selection, provenance, scene = self.binding_inputs("north")
        west = self.selections["west"]
        selection["material_library_file"] = west["material_library_file"]
        selection["material_library_sha256"] = west["material_library_sha256"]
        with self.assertRaisesRegex(SystemExit, "descriptor material binding mismatch"):
            validate_explicit_source_binding(
                selection,
                provenance,
                scene,
                "industrial_l03_v0_north",
            )

    def test_wrong_provenance_library_hash_is_rejected(self) -> None:
        selection, provenance, scene = self.binding_inputs("south")
        provenance["materialLibrarySHA256"] = "0" * 64
        with self.assertRaisesRegex(SystemExit, "provenance material binding mismatch"):
            validate_explicit_source_binding(
                selection,
                provenance,
                scene,
                "industrial_l03_v0_south",
            )


if __name__ == "__main__":
    unittest.main()
