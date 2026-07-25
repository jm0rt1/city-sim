# PLAY-027 Industrial L1 audit and source-v01 design freeze

## Authority and retained inputs

Published authority `91f885925fd601786fa95dbb969b71fefef5ddcd`
accepts and freezes the complete Residential and Commercial source catalog and
authorizes Industrial expansion one level at a time. Accepted Commercial
candidate `bf3e24b2b465870f131ac0a01a2327ac4969d5d5` remains an ancestor.

Industrial L1 begins with no governed PLAY-027 N/E/S/W source. Its retained
calibration image is an appearance-only family anchor:

- file:
  `Native/CitySimNative/WorldArt/GeneratedV4/ImageGen/raw/calibration/industrial_l01/source-v01.png`;
- SHA-256:
  `22dbf75f35d66f86b108c8e5ab9d7b3f753df74489d0b9e9877fc81ba86a2515`;
- use: industrial material, loading-door scale, roof rhythm, and family
  recognition only;
- prohibited use: geometry, registration, sibling derivation, or directional
  source substitution.

Whole-building ImageGen remains closed by the retained capability limit. No
ImageGen call or material swatch was needed for this authored numeric palette.

## Frozen Industrial L1 identity

`industrial_l01/variant-0/source-v01` is a low, broad loading works:

- high-bay corrugated-steel assembly hall over a concrete datum;
- offset warm-umber brick service wing;
- three narrow repeated roof volumes that read as an industrial shed rhythm,
  not a domestic or office roof;
- oversized roll-up loading door, concrete jamb/header, dock apron, steel
  canopy, and safety bollards on the declared road frontage;
- roof HVAC, tall exhaust stack, and ground-level service tank;
- sparse clerestory glazing rather than residential windows or commercial
  storefronts;
- sage steel, warm industrial concrete, charcoal metal, oxidized service
  equipment, and restrained hazard-yellow accents.

This silhouette and facade grammar do not reuse Residential porches, domestic
roofs, Commercial storefronts, office lobbies, or tower massing.

## Directional authorship

North, east, south, and west are four explicit schema-2 descriptors. Each
declares its own facade rhythm IDs and coordinates, loading-bay facade,
frontage exclusion, service equipment positions, hinge side, canopy offset,
and scene geometry ID. All declare:

- `authoredIndependently: true`;
- `siblingSource: null`;
- `mirror: false`;
- `rotationDegrees: 0`;
- `transform: none`;
- `orientationTransform: none`;
- `productionSelected: false`.

The four descriptors share only the immutable physical building envelope,
material library, camera, light, footprint, contact polygon, and schema-2 v3
sampling contract. Shared structural modules do not transform or derive a
sibling scene.

North and west use grounded loading-canopy returns so their road-facing
loading identity remains legible from the fixed camera without moving the
frontage socket or substituting a near-edge entrance.

## Frozen registration and sampling

- canvas: `1536 x 1024`;
- footprint: one `72 x 72` world-unit tile;
- ground pivot: `[768, 896]`;
- directional sockets and door bases: exact CONTRACT-010 values;
- projection: fixed orthographic 2:1;
- light: northwest key;
- shadow: southeast `[2, 1]`;
- schema: 2;
- sampling:
  `play027-deterministic-4x-no-msaa-lanczos-v3`;
- SceneKit antialiasing: none;
- linear oversampling: 4;
- software Lanczos: scale `0.25`, aspect `1`;
- frozen quantizer/canonicalizer: approved schema-2 v3;
- production selection: false.

## Pre-pixel validation

- scene validation: pass;
- four unique descriptor hashes;
- four unique scene geometry IDs;
- 12 sparse clerestory windows per direction;
- each direction contains HVAC, exhaust, and service-tank treatment;
- exact pivot/socket/door/light/camera/contact agreement;
- zero coincident authored structural boundaries in all four scenes;
- task-owned renderer and validators compile outside `Package.swift`;
- no accepted Residential or Commercial source is modified.

No raw pixel is accepted by this checkpoint. Three fresh processes per
direction and exact RGBA visibility must pass before normalization.
