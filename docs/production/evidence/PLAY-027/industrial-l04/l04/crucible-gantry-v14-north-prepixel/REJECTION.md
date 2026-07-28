# PLAY-027 Industrial L4 North v14 pre-pixel rejection

**Disposition:** `REJECTED_AFTER_THREE_VISUAL_REFINEMENTS`

**Authorized base:** `8f330e061f88d29be620f77d7bcdc223bc3bc800`

The concept-led reset produced one new board-derived functional massing and
three documented visual refinements. It did not clone v13 geometry, ingest
board pixels, use ImageGen, run SceneKit/Metal, normalize pixels, or touch
product/shipping surfaces.

## What improved

Refinement 03 establishes a materially stronger source/native-scale direction:

- one warm masonry hall with roof seams, masonry coursing, cornice,
  buttresses, windows, and repeated clerestory rhythm;
- a true double-girder crane with buttressed piers, flanges, transverse ties,
  trolley, and lift rail;
- a separate seven-tier octagonal furnace with base, taper, shoulder, upper
  vessel, neck, rim, and hot mouth;
- an open concrete service court connected to the exact North socket;
- a subordinate control annex, boiler/stack, pipes, rails, and restrained heat
  accents;
- distinct masonry, dark steel, oxidized copper, concrete, glazing, and heat
  value groups.

## Binding failure

Independent humans own premium identity, and literal pixels remain binding.
At source and native scale the hero assembly is improved, but at untouched
exact 192 color and grayscale:

1. the three road-edge freight beats compress behind the eastern crane tower
   instead of reading as one deliberate three-position logistics group;
2. the staff return does not remain independently readable;
3. the complete frontage story therefore depends on the semantic panel.

This violates the explicit rule that semantic masks may support but never
rescue weak literal pixels. The third refinement is rejected even though its
descriptor structure and role inventory are complete.

## Final retained identity

- revision: `source-v14-prepixel`;
- geometry ID:
  `industrial-l04-crucible-gantry-v14-north-board-led`;
- descriptor SHA-256:
  `537c2ed86b53ded38aa00413066a7a8edc0ca3ebc241e5baa13b8e47eb48d4db`;
- material SHA-256:
  `147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202`;
- geometry SHA-256:
  `0ac9404a905d6d91c5b3cb6f1d01f9785d419a46452c5d3097d5241fde8477a5`;
- components: `72`;
- double girders: `2`;
- furnace tiers: `7`;
- authored freight beats: `3`;
- pivot/socket: `[768,896]` / `[896,704]`;
- raw/SceneKit/Metal/normalizer process counts: `0/0/0/0`;
- source authority / production selected: `false/false`.
- builder source SHA-256:
  `4a85fd0913bca95a156b00b02c9fb5a3b4153436cc660be0e4be80fbbb14f9c7`;
- compiled binary SHA-256:
  `8ad2a8a2f14995ce3a22c0459c8593d80c1f76433e85926c35e0c878eb61f975`.

Warnings-as-errors compile:

```text
xcrun swiftc -module-cache-path /tmp/play027-v14-module-cache -parse-as-library -warnings-as-errors Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Sources/SceneDescriptor.swift Native/CitySimNative/WorldArt/OfflineScene/PLAY-027/Tools/BuildIndustrialL4CrucibleGantryV14NorthPrepixel.swift -o /tmp/build-industrial-l4-v14-north-prepixel
```

## Exact literal panel hashes

- source color:
  `e6ed3b303667b6e63da67a1e722b16a7cdc1f1ac5aa0ab253b9ccd64361381ec`;
- source grayscale:
  `58868f8fe54d33693eaeba89b38619d38a92da1ba124edb162519b4e0663dc18`;
- native-2x color:
  `68504605c238f97c5acf71ca2718e5a311ab7710389967ab697060b8079a2a1b`;
- native-2x grayscale:
  `dd5f29388b8828568365383217a80322890a9a82169c5c7b3875096956f61020`;
- exact-192 color:
  `d6434650e69bd89b69b3991d46ce728e1bc00b92bec43091e92423499c2c18fe`;
- exact-192 grayscale:
  `f81210be3c81e097524115e5816e66a63b0a7dcfaec5514504b87065242acc49`.

## Exact tool limitation proposal

The current compact analytic vocabulary represents freight depth as additive
boxes on the camera-far North edge. It cannot express a true wall cutout or
negative loading throat, so the frames remain surface objects that lose
ownership behind the crane tower at compact scale. A future authority should
add one task-owned recessed-opening primitive (outer structural frame plus
subtracted void and inset back plane) to the analytic and offline-scene source
tooling before another layout. That capability would preserve the fixed
camera/socket while modeling actual depth instead of moving, raising, or
mask-labeling the far-edge frontage.

Because no final candidate exists, the candidate-only two-replay gate was not
consumed.

`sourceAuthority=false`

`productionSelected=false`
