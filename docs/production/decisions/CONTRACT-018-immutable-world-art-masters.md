# CONTRACT-018 — Immutable world-art master authority

**Status:** Approved
**Owner:** Integration
**Initial scope:** PLAY-027 Industrial L2 variant-zero East

## Problem

The offline SceneKit authoring pipeline can produce two host-Metal raster
identities from one unchanged scene even when camera, geometry, materials,
alpha, occupancy, pivot, socket, frontage, contact, and registered shadow are
identical. Requiring the authoring renderer to reproduce an already approved
raw master byte-for-byte can therefore block a release without improving the
bytes that the product actually normalizes, packs, loads, or displays.

Authoring-process reproducibility and shipping reproducibility are different
properties. The latter remains a release requirement.

## Decision

Integration may grant a direction-specific immutable-master exception to the
repeat-render clause in CONTRACT-011. The exact independently reviewed raw PNG
becomes source authority; the product pipeline must consume that frozen file
and may not rerender or substitute it.

The exception is valid only when all of the following are true:

1. Integration names the exact source file, file SHA-256, decoded-pixel
   SHA-256, direction, family, variant, and independent visual candidate.
2. The raw master passes alpha/chroma, occupied-volume, pivot, socket,
   frontage, contact, shadow, scale, and padding checks.
3. Its scene, material, renderer, toolchain, and provenance records are
   retained, including every repeat-render rejection. The exception does not
   rewrite or conceal nondeterminism.
4. Cross-direction and cross-family audits prove no alias, mirror, rotation,
   recolor substitution, or fallback.
5. Every governed LOD is normalized twice from the frozen raw master with
   byte-identical output.
6. Renderer ingestion proves exact source-to-pack identity, deterministic
   lookup, stable registration, bounded resources, and no fallback.
7. The exact staged candidate passes the focused independent visual,
   interaction, accessibility, and LOD gate.

The exception changes no runtime renderer, package, build script, save data,
gameplay, simulation, UI, or production-selection ownership. World Art owns
the immutable source record; World Rendering remains the only writer of
shipping manifests, packed resources, runtime lookup, and production
selection.

## Initial authority

The exception is authorized only for the independently reviewed PLAY-027
Industrial L2 East anchor in candidate
`9d641edbb6a88d675c4822c02c1594318186c5ac`:

- source file:
  `docs/production/evidence/PLAY-027/industrial-l02/l02/east-calibration-v05/raw-calibration/diagnostics/east-primary/raw.png`
- file SHA-256:
  `a32725fd0ea0436c1f8a13d319c3c66408a7cdf44ff8f2cdb72665839dd685a8`
- decoded RGBA SHA-256:
  `555f35d466326783a038ff842f76e8cdeff8284a4b26bb901d6d20428ad88bcc`

North, South, and West retain the normal CONTRACT-011 repeat-render gate.
This authority does not itself accept the four-direction family, authorize
normalization, select production art, or permit shipping ingestion.

## Stop conditions

Stop on any raw-master hash drift, missing provenance, changed visual
candidate, failed normalization repeat, source-pack mismatch, alias or
transform evidence, registration loss, fallback, mixed-family substitution,
resource regression, candidate substitution, or failed staged independent QA.
