#!/usr/bin/env python3
"""Compatibility entry point for the production generated-v4 pack builder.

PLAY-022 used this name while individual PNG payloads still shipped. PLAY-023
keeps the command valid but delegates to the sole page-pack authority so an old
workflow cannot recreate unpacked shipping resources or a partial manifest.
"""

from build_world_asset_pack import CANONICAL_ATLAS, build


if __name__ == "__main__":
    build(CANONICAL_ATLAS)
