# PLAY-022 Round 1D Candidate Submission

- **Lane:** World rendering
- **Branch:** `codex/citysim-world-rendering`
- **Status:** candidate submitted for independent PLAY-052 scoring; claim remains active and this record is not self-acceptance
- **Rejected predecessor:** product `2cf18b0f0d9a0aee9f3708e72593eb6e7cd99ae0` / evidence `f35d6ef2d17376f02fdcee6410cf7ef11f29735a`
- **Exact product:** `8433621760ba169995aa1a5dc81cac27c380d746`
- **Exact evidence:** `326def7dcf63f70b8dc6d54dab9a1f7e6bbbff7a`
- **Candidate identity:** `world-rendering-w5f893ad1da1b`
- **Product tree:** `c02c6811f8a4e257f0297a189514ff9875a004a1`

## Ordered commits

1. `7ccf0c15b31fb2b6f4fff2aea3e32612d05a9360` — acquire accepted Round 1C rejection `4bbe72b`
2. `5982c4bfaca18e55a690be22dd6c1d822054fbd6` — acquire Round 1D authority `ab722bd`
3. `dd8076efbc94d3ef6bd61487d6231dc6429dcb35` — reframe a connected authored district
4. `d740a6099d13df677eaaf9f9890585d6dde8ef32` — keep the compact district in frame
5. `8433621760ba169995aa1a5dc81cac27c380d746` — make developed mass dominate default framing
6. `326def7dcf63f70b8dc6d54dab9a1f7e6bbbff7a` — retain exact Round 1D evidence

This record follows those commits and does not alter the frozen product or
evidence trees.

## Player-visible outcome

The shipping start now presents one connected developed district instead of a
sparse four-stub crossroads. Authoritative developed lots plus their immediate
public realm occupy 74.73% of the default world width and 56.00% at exact
compact. Remote opportunity roads do not count toward or expand the framing
gate.

All 16 deterministic road masks use the retained generated-v4 material at city,
neighborhood, and block LOD. Curbs, sidewalks, crossings, lane marks, frontage
joins, shoulders, terrain, and intentional terminals read as one physical
system. The three live LOD stops are materially distinct: city emphasizes
network and mass, neighborhood exposes blocks and frontage, and block reveals
materials, props, and construction detail.

The correction changes only renderer-owned sources, resources, tests, and
evidence. It does not change SwiftUI views, player intent/store contracts,
gameplay, simulation, saves, Package.swift, build scripts, legacy Python,
Round 2, PLAY-023, or CONTRACT-008.

## Validation and governed budgets

- Focused `WorldRenderingTests`: 36/36 passed in 9.779 seconds.
- Full native suite: 136/136 passed in 45.725 seconds.
- `bash -n script/build_and_run.sh`: passed.
- Exact staged `./script/build_and_run.sh --verify`: passed; the packaged and
  source generated-v4 manifests match.
- Candidate isolation: passed in two disposable clones with distinct bundle,
  executable, preferences, and data identities.
- Geometry: 324 ground, 36 building-road setback, and 256 entrance/prop
  neighbor checks; zero collisions, missing entries, or orphan inventory.
- Fresh-process cold totals: 3.913, 3.766, 3.658, 3.800, and 3.743 ms; median
  3.766 ms, maximum 3.913 ms, 5/5 at or below 6.03 ms.
- Default: 1,111 nodes / 389 drawables. Compact: 1,102 / 380. Ten pulses reused
  5,759 tiles, updated one, and averaged 0.826 ms.
- Decoded residency high water after repeated LOD cycling: 13,521,048 bytes,
  with zero fallback.
- After three staged LOD cycles plus 60 seconds, regular settled at 218 MB
  footprint / 252,944 KiB RSS / 325 MB peak; compact at 179 MB /
  242,752 KiB / 311 MB peak. Both stay below the 333.8 MiB ceiling.

## Real-app proof

The exact candidate retains uncropped default and exact 900 x 600 content,
regular and compact city/neighborhood/block LODs, pointer and keyboard
selection, valid and invalid placement, road commit and undo, sparse utility
overlay, construction stages, accessibility trees, color-vision and grayscale
sheets, Reduce Motion, and continuous pan/zoom proof.

Pointer selection announced City Hall 12,12 with its authoritative state.
Keyboard selection announced Road 14,13. The occupied coordinate displayed and
announced the same demolition reason; Road 21,13 displayed and announced the
same available price, Return committed it, and Command-Z restored open land.
Reduce Motion A/B frames taken five seconds apart are byte-identical, while
static meaning remains present.

The immutable evidence packet, hashes, commands, logs, collision/seam outputs,
resource identity, live results, and before/after comparison are under
`docs/production/evidence/PLAY-022/round-1d/candidate-8433621/`.

## Truthful limitations and disposition

Independent quality has not scored this exact pair. The author evidence cannot
close PLAY-022 or authorize integration; the claim remains active pending the
required PLAY-052 score of at least 17/20, with no category below 3 and no
automatic rejection.

Five-stage construction, decline/recovery, and spatial-consequence sequences
use the shipping renderer harness because forcing those states in the staged
app would require gameplay mutation outside this lane. Native screen recording
was unavailable, so the retained 7 fps pan/zoom movie contains 25 direct exact
staged-app frames and no synthesized frames. At 900 x 600, peripheral
roofs/shadows may sit below translucent chrome, but active selection and
placement coordinates remain visible and accessibility-addressable.

No shared-contract proposal is required. Nothing was pushed or integrated.
