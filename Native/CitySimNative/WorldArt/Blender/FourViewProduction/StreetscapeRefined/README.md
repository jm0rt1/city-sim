# CitySim Foundry Streets — Refined Four-View Streetscape

This source-only successor family contains one original Blender road asset for every `RoadConnectionMask` raw value from `0...15`. It preserves the accepted CitySim registration contract while improving how repeated road tiles read as one district: a broader warm medium-charcoal carriageway, quiet warm-gray aggregate walks, narrow low-contrast curbs, and exact material overlap across every connected socket.

The family uses the canonical 88×44 projected tile, orthographic 45-degree azimuth and 30-degree elevation, four fixed cameras, 384×384 transparent canvas, `[192, 300]` pivot, identity roots, exact `2 x 2` world cells, and the sole canonical `CitySimKey` light. Gameplay north/east/south/west map to Blender `-X/-Y/+X/+Y` for every asset. No view or mask uses rotation, skew, scale, crop, offset, or post-render compensation.

Road and walk planes bleed `0.10` world unit past the logical `+/-1.0` socket boundary, so adjacent sprites overlap with the same material instead of exposing transparent filtering seams. There is no raised square tile plate or independent border. Straight and corner masks intentionally omit repeated lane markings; endpoints, tees, the crossing, and isolated turnaround use only sparse topology-aware details.

Run:

```sh
Native/CitySimNative/WorldArt/Blender/FourViewProduction/StreetscapeRefined/run_pipeline.sh
python3 Native/CitySimNative/WorldArt/Blender/FourViewProduction/StreetscapeRefined/admit_live_catalog.py
```

The pipeline writes 16 `.blend` sources, 64 canonical PNGs, 16 contact sheets and manifests, a family manifest, deterministic validation evidence, and connected-district previews at 1280×800 and 900×600. This directory is a source-only candidate and does not alter the live catalog.
