# CONTRACT-006: Generated world-asset pack

**Status:** Approved for staged implementation

**Date:** July 21, 2026

## Decision

CitySim will replace the legacy Pillow world art with one versioned,
manifest-driven pack named `generated-v4`. OpenAI built-in ImageGen is approved
as the source-art producer. Generated pixels never become geometry, simulation,
or state authority and never ship directly from a tool response.

The independently accepted PLAY-022 Gate A source will become the global style
anchor. The current source on the rendering branch is provisional until its
exact staged candidate passes both reviewers. Once frozen, it defines
projection, materials, value hierarchy, palette, detail scale, and northwest
light with southeast shadows. It does not define roads, parcels, coordinates,
building placement, state, or interaction.

## Semantic boundary

ImageGen may author:

- building, vegetation, prop, parked-vehicle, pedestrian, and particle masters;
- terrain and material swatches;
- construction and condition reference treatments.

Deterministic repository code owns:

- the exact 2:1 grid, road connections, frontage orientation, parcel masks,
  pivots, anchors, scale, LOD export, and atlas placement;
- construction-stage and condition composition;
- selection, hover, placement, overlays, consequence intensity, animation
  paths, Reduce Motion, and all mapping from authoritative simulation truth.

No generated road, building, label, effect, or scenery may imply a simulation
fact that is absent from the accepted snapshot.

## Manifest v4

`generated-v4` has one Codable manifest authority containing:

- pack ID, schema, generator version, projection, 72 x 36 world-point tile,
  color space, light direction, page limits, and production selection;
- complete source, normalized, packed-page, prompt, and reference SHA-256
  values;
- logical ID, family, variant, level/state, LOD, page, texture rectangle, trim
  rectangle, anchor, ground pivot, footprint, world size, padding, filtering,
  mipmap, decoded-byte estimate, and provenance record;
- the complete file inventory so missing, corrupt, or orphan resources fail
  validation.

Every source record includes the complete prompt, tool and date, exposed model
or `built-in/model-not-exposed`, reference roles and hashes, chroma key,
cleanup command, intended gameplay meaning, reviewer, and disposition.

## Normalization and packing

- Retain accepted stochastic masters; rebuilding never calls ImageGen.
- Normalize to canonical 8-bit sRGB RGBA and strip nondeterministic metadata.
- Remove only border-connected matte, retain soft alpha and controlled shadows,
  despill edges, zero hidden RGB, remove background islands, and reject clipped
  bounds, halos, chroma spill, or inadequate padding.
- Store exact pivots before trimming and round-trip anchors within 0.5 world
  point across every LOD.
- Produce explicit city, neighborhood, and block assets. Mipmaps handle only
  continuous scaling inside one LOD.
- Pack each LOD into deterministic, power-of-two pages no larger than 2048 x
  2048, stable sorted, unrotated, with at least four pixels of gutter and two
  pixels of edge extrusion.

The loader validates the manifest, creates subtextures from pages, preloads the
next camera LOD, evicts unused pages, and reports pack ID, manifest digest,
pages, cache hits/misses, fallback count, decoded bytes, and load time. Missing
art produces one explicit logged fallback during development; production proof
fails on any fallback.

## Budgets

- At most four active 2048 x 2048 pages.
- Approximately 96 MiB target active texture memory and 128 MiB hard high-water
  after repeated LOD cycling.
- Compressed shipping pack initially capped at 128 MiB.
- Staged RSS no more than the accepted baseline plus 128 MiB.
- Existing 2.1 ms unchanged-pulse ceiling remains; no renderer metric may
  regress more than 20 percent without integration approval.
- LOD transition p95 stays below 16.7 ms with no transition frame above 33.3
  ms; nodes, drawables, actions, pages, and resident bytes do not accumulate.

## Staging and rollback

CONTRACT-005 packages the unrenamed SwiftPM resource bundle. Staging will also
record `world_asset_pack_id` and `world_asset_manifest_sha256`, validate every
manifest-declared page, and compare built and staged digests.

The current art remains a reproducible non-shipping `legacy-v2` source pack.
Candidate builds may expose a debug-only `CITYSIM_WORLD_ASSET_PACK=legacy-v2`
A/B switch. Production selects exactly one pack. Integration can roll back the
pack-selection commit without changing saves, simulation state, or logical
visual identities.

## Image-generation mode

Use built-in ImageGen one distinct call per asset or variant. Project-bound
accepted outputs, prompts, and provenance move into the repository immediately.
Use a flat `#ff00ff` field and the approved chroma-key cleanup workflow.

This approval does not authorize silent CLI/API fallback. If foliage, glass,
smoke, reflections, or soft shadows cannot pass chroma extraction, stop and ask
before any true-native-transparency CLI path.
