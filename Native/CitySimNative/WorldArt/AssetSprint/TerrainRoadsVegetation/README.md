# Cedar Market Terrain, Roads, and Vegetation

This bounded production family is original CitySim artwork built against
`AssetSprintReferenceFamily.canonical`. Every runtime asset uses the same
88x44, 2:1 southeast-facing orthographic projection, elevation step 22,
ground pivot `(0.5, 0.18)`, northwest key light, and restrained southeast
shadow. Runtime rotation, skew, and per-asset scale correction are forbidden.

## Built-in image generation

Tool mode: Codex built-in `image_gen` (default mode), followed by local
project packaging. The final ground-system image and pocket-park image are
project-bound originals. The supplied catalog image was a quality and catalog
benchmark only; the Cedar Market frame was the projection and scale reference.

Ground-system prompt:

> Create one entirely original dense mixed-use neighborhood ground system
> centered on continuous streets, joined lots, sidewalks, a small public park,
> industrial service yard, plaza paving, lawns, and restrained vegetation and
> street dressing. Use a fixed orthographic 3/4 isometric view in exact 2:1
> projection, warm northwest light, restrained southeast shadows, detailed
> asphalt, concrete, brick, gravel, grass, trees, lamps, benches, bollards,
> planters and fountain. Buildings are simple massing context only. No copied
> assets, text, UI, sprite sheet, mixed angles, or transform tricks.

Pocket-park prompt:

> Create one entirely original compact neighborhood pocket park on a 2x2
> joined-lot diamond base with a low stone fountain, brick herringbone paths,
> four benches, layered shrub beds, small deciduous trees, and warm metal lamps.
> Match the fixed 2:1 Cedar Market projection and northwest light. Isolate the
> asset on a solid magenta removal background. No copied arrangement, people,
> text, UI, mixed angles, or transform tricks.

The preferred Pillow matte helper was unavailable in the active environment,
so the selected opaque park source was matted locally with FFmpeg chroma-key
filtering. The packaged asset retains transparent corners and is regression
tested for opaque magenta fringe.

## Source and packaged outputs

- `cedar-market-ground-system-source.png`: selected built-in generation.
- `pocket-park-chroma-source.png`: selected built-in generation before matte.
- `pocket-park-alpha-source.png`: locally matted source.
- Runtime assets and representative renders live in
  `Resources/WorldAssets.atlas/AssetSprintTerrainRoadsVegetation/`.
