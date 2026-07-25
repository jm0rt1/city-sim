# PLAY-027 Industrial L2 retained-pixel diagnostic

Status: pixel quantification passes; equivalence to the Commercial L4 MSAA
failure does not.

The existing native comparator decoded the exact retained PNG bytes through
ImageIO into 8-bit RGBA. Each report contains every differing source
coordinate, A/B/C RGBA value, differing channel, pairwise pixel/channel count,
alpha count, and difference bounds. Its nearest-neighbor locality sheet shows
the exact A crop, comparison crop, and difference mask.

All four reports and sheets were generated twice from the same retained inputs.
The second generation reproduced every artifact hash exactly.

## North

Primary versus B and primary versus C each differ at 1,157 pixels and 1,458
RGB channel samples within source bounds `[771,701,801,807]`. B and C are
identical. There are no alpha changes; every differing pixel remains fully
opaque. Channel changes comprise 1 red, 640 green, and 817 blue samples, all
one frozen quantization quantum (`32`) apart.

The literal zoom shows broad contiguous interior surface-value regions on the
facade/loading structure, rather than a narrow silhouette edge or isolated
five-pixel seam.

## East

- A versus B: 604 pixels / 737 RGB channels within
  `[682,687,779,781]`;
- A versus C: one red-channel pixel at exact source coordinate `(778,728)`;
- B versus C: 603 pixels / 736 green-or-blue channels within
  `[682,687,712,781]`.

Every alpha remains 255 and all channel deltas are exactly 32. The literal
zooms again show broad interior facade/shadow regions plus the separately
retained one-pixel A/C split.

## Provenance comparison

North and East A/B/C bind the same:

- renderer source commit `5fa1e4fd71e772bcd765c62c8eda4313fee57b4f`;
- descriptor and material hashes;
- `Apple M5 Pro` device and registry identity `4294968844`;
- schema-2 v3 contract
  `play027-deterministic-4x-no-msaa-lanczos-v3`;
- SceneKit antialiasing `none`, effective antialiasing `none`;
- 4x linear oversampling, software Core Image Lanczos scale 0.25;
- step-32 quantizer and canonicalizer v3;
- current SceneKit shadows.

Commercial L4’s accepted diagnosis was a five-pixel upper-shaft seam under
retained SceneKit 4x MSAA, and exact identity returned when only MSAA was
disabled. Industrial L2 already has MSAA disabled and differs across hundreds
of broad interior pixels. The same MSAA cause is therefore not supported.

The condition for a no-MSAA/current-shadows isolation was not met. Running the
same setting again would not change one independent variable, so no additional
Metal processes were launched.

## Proposed next diagnostic and production-path decision

This is a proposal only; it is not implemented.

The next smallest causal experiment is three fresh diagnostics-only processes
for North and East with the existing schema-2 v3 no-MSAA sampling fixed and
only SceneKit scene shadows disabled. If that restores identity, integration
can evaluate a governed offline path that:

1. retains 4x/no-MSAA/software-Lanczos and all frozen geometry/registration;
2. removes nondeterministic SceneKit shadow-map contribution from source
   authority;
3. preserves the existing deterministic registered footprint shadow;
4. adds any required deterministic authored/self-shadow treatment in
   task-owned Core Graphics/Core Image composition;
5. reruns complete accepted-art appearance, lighting, grayscale, registration,
   raw, normalization, and uniqueness regressions before a new source revision
   is authorized.

If shadows-disabled processes still split, the next proposal is a
diagnostics-only per-root/group isolation around the exact affected
facade/loading subgraphs. Neither experiment is authorized by this packet.

Industrial L2 remains frozen at source-v03. Descriptors, materials, South,
West, accepted art, and product/shipping surfaces are unchanged. No
normalization or production selection occurred.
