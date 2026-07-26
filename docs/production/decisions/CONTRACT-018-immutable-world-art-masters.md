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

## Additional authority — Industrial L3 North

Integration independently reviewed the retained Industrial L3 North v02 and
v03 raw attempts after exact cross-process evidence localized the remaining
drift to 2–61 opaque RGB pixels with stable alpha, occupancy, pivot, socket,
frontage, contact, shadow, and registered volume. The v03 pre-Lanczos repair
did not establish repeat identity and visibly flattened the v02 corrugated
facade, rooftop, tank, and material detail. It is rejected as the visual
authority.

The exception is therefore granted only to the richer PLAY-027 Industrial L3
variant-zero North v02 run-A master retained at clean checkpoint
`81ef296de589b99b5617feeab9d92dffc98806f6`:

- source file:
  `docs/production/evidence/PLAY-027/industrial-l03/l03/raw-gate-v02/diagnostics/raw-repeat/north/run-a/raw.png`
- file SHA-256:
  `05d97a621d466b8943d3fcd30ee934e91b9733cc7715d832534771eaeb2b6888`
- decoded RGBA SHA-256:
  `5d1858ff3676156b7b2084f492e3a227a70b65177d1f4bf436885d8e4237eb9f`
- frozen scene descriptor SHA-256:
  `78803712a2b4118abef6ff90119444b1c4093f5cb442348f3cdb9b3e4bf1fe51`
- frozen material library SHA-256:
  `3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e`

Industrial L3 East, South, and West retain the normal CONTRACT-011
repeat-render gate. World Art may normalize North twice only from the exact
master above and may continue the frozen v02 E/S/W raw gate. This authority
does not accept the four-direction family, authorize Industrial L4, select
production art, or permit shipping ingestion.

After North normalization reproduced exactly, East completed three fresh v02
processes at clean checkpoint
`ebb0f49d81cc103203382626aef82aa6a70d9f34`. All retained complete volume,
alpha, occupancy, registration, and four-bay road-facing frontage. Runs A and
C differed by five opaque RGB pixels; the larger B variation remained confined
to the registered campus edge and did not change geometry or visibility.
Integration independently reviewed the full retained attempts and names East
run A as the immutable master:

- source file:
  `docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02/diagnostics/raw-repeat/east/run-a/raw.png`
- file SHA-256:
  `5dd2999ad2916a8ccddcf91954e54d1dfcf1139f78977d05d738c3dbfff4b9af`
- decoded RGBA SHA-256:
  `29b0f59bad27c4c8e9918e5544ab712d4e35d5acb056a31be2f2e0d71081f4d6`
- frozen scene descriptor SHA-256:
  `dbe0dd260d28d848864d4194826f5147ec91314cf75b95bff9349bbfe466342c`
- frozen material library SHA-256:
  `3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e`

Industrial L3 South and West retain the normal CONTRACT-011 repeat-render
gate. World Art may normalize East twice only from the exact master above and
continue the frozen v02 South/West raw gate. The North and East exceptions do
not accept the four-direction family or broaden any other authority.

After East normalization reproduced exactly, South completed three fresh v02
processes at clean checkpoint
`e3bfb7d306f9479c6d037ba1f4287a6c4b29d845`. Runs A and B were byte- and
pixel-identical. Run C differed by eleven opaque RGB pixels while alpha,
occupancy, bounds, registration, complete volume, and road-facing frontage
remained identical. Integration independently reviewed the retained South
candidate and names the already twice-reproduced run A as its immutable
master:

- source file:
  `docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02/diagnostics/raw-repeat/south/run-a/raw.png`
- file SHA-256:
  `171bcba90f5a06353778bc6d420723b714ad0a6313dd4d858128ae0efad5775c`
- decoded RGBA SHA-256:
  `4a5d3f5473528015ce604ade12e18fb6bbc53df4d3607f277b67d86d40386e06`
- frozen scene descriptor SHA-256:
  `1e548d4694bea47b36e9aca1a97e901917ea92742fd6366f53a4e92bfcba1b2b`
- frozen material library SHA-256:
  `3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e`

Industrial L3 West retains the normal CONTRACT-011 repeat-render gate. World
Art may normalize South twice only from the exact master above and continue
the frozen v02 West raw gate. The three exceptions do not accept the
four-direction family or broaden any other authority.

After South normalization reproduced exactly, West completed three fresh v02
processes at clean checkpoint
`e594259c1705320973ecb0067f7398ddbb2d6886`. Runs A and B were byte- and
pixel-identical. Run C differed by two opaque RGB pixels while every alpha,
occupancy, bounds, registration, complete-volume, and far-edge frontage check
remained identical. Integration independently reviewed the retained West
candidate and names the already twice-reproduced run A as its immutable
master:

- source file:
  `docs/production/evidence/PLAY-027/industrial-l03/l03/source-completion-v02/diagnostics/raw-repeat/west/run-a/raw.png`
- file SHA-256:
  `6d99f9436c11294f97359b3ed35203658ea178caa092f0ffea7d63982baa2151`
- decoded RGBA SHA-256:
  `b47b211174e77d53ffad023af06734c1467403cd612af46c4e49dcef0e2921df`
- frozen scene descriptor SHA-256:
  `bc0812eb16008bb0a544873fb3d24c4b01c470c405b4f6051a36a400c68856ce`
- frozen material library SHA-256:
  `3a9b0d97e74c3aba1772fa0dac66151955db98b34d25212eee7e15472ce2715e`

World Art may now normalize West twice only from the exact master above and
assemble the complete Industrial L3 four-direction source candidate. All four
directional masters remain non-shipping until the family passes cross-direction
and cross-family review and receives a separate integration disposition.

## Stop conditions

Stop on any raw-master hash drift, missing provenance, changed visual
candidate, failed normalization repeat, source-pack mismatch, alias or
transform evidence, registration loss, fallback, mixed-family substitution,
resource regression, candidate substitution, or failed staged independent QA.
