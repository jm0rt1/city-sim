# Gate A golden-district source

This folder retains the non-shipping authoring source and deterministic cleanup
step for PLAY-022 Gate A. SwiftPM ships only the three transparent PNG exports
under `Sources/CitySimNative/Resources/WorldAssets.atlas`.

## Provenance and art direction

- Tool: OpenAI built-in ImageGen, July 20, 2026.
- Visual reference: `docs/production/evidence/PLAY-021/art-direction-reference.png`.
  It supplied the target quality, 2:1 isometric projection, material richness,
  and northwest-key/southeast-shadow direction; it was not used as a shipping
  pixel source.
- Retained master: `golden_district_imagegen_source-v2.png`, 1536 x 1024,
  SHA-256 `b227286bfe5ffe8cfc920d3faf8abe081f5cca8a498c215bfb8a840a448e7425`.
- The first generated composition was rejected before integration because it
  invented perimeter streets. It is intentionally not retained in the repo.

The final edit prompt was:

> Edit the supplied isometric district artwork. Preserve its architecture,
> material depth, 2:1 projection, northwest key light, southeast shadows, civic
> focal building, residences northwest, commercial northeast/east, industrial
> southeast, park southwest, and water tower. Authoritative road correction:
> show exactly two continuous roads, upper-left to lower-right and lower-left to
> upper-right, crossing once at the center. Remove every perimeter, parallel,
> and secondary road and replace those areas with landscaped parcels, private
> walks, and short driveways. Keep a flat #ff00ff field outside the district.
> No UI, icons, rings, bolts, cyan marks, text, or watermark.

## Isolation, scale, and anchors

`prepare_golden_district.py` removes only saturated low-green magenta pixels,
zeros transparent RGB, and produces deterministic Lanczos LOD exports. Run it
after `generate_world_assets.py` when rebuilding the complete atlas.

- Block: 1536 x 1024, SHA-256
  `37791fd91ca17d0bb09782ae4556d51874c88fcfb6dd3886d146ff16709fa614`.
- Neighborhood: 1024 x 683, SHA-256
  `d256c1271a6b71bce8df0b0e6a7c955714b2082e3aac49717eff7b2cb806a696`.
- City: 512 x 341, SHA-256
  `4b0646d507e10015c67c9b07a7cfd1781eebcbc7cc324fa76eb0ebe7836d60bc`.

The plate occupies 368 x 245.33 world points, centered on simulation coordinate
(12, 12) with a +9-point vertical registration. Its central crossing aligns to
the accepted starting roads; all interaction and truth-bearing tile nodes stay
live above or beneath it, and the plate withdraws when its verified starting
state, normal overlay, or inspect-mode contract no longer holds.
