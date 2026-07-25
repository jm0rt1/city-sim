# PLAY-073 candidate evidence checkpoint

## Disposition

This packet preserves the exact renderer candidate for independent review. It
does **not** claim Wave 009 visual acceptance or PLAY-073 completion.

Integration inspected the production app on exact staged master
`fbbff0c7a633be81ae7779709a76ff3202d928fb` and rejected the visual outcome:

- the developed city occupies approximately `0.369` of the regular safe width;
- the compact occupied-width measure is approximately `0.510`, but persistent
  HUD chrome materially reduces the useful aperture;
- the empty green board remains the dominant visual mass;
- the authoritative road system still reads as isolated strips;
- building, park, utility, material, outline, and ground-contact fidelity remain
  visibly mixed.

The preserved renderer work remains a valid technical checkpoint. The
connected-authoritative-road camera fit, exact empty-land truth, selection,
overlays, hit testing, and incremental renderer behavior all pass their
technical gates. A new focused claim/authority is required before another
product iteration.

## Exact identity

- Product commit: `1c590e446e718024f4848d22b33b05db4c73555a`
- Assertion/cleanup commit: `00228da9ca362b98a1f96d6156acc7a99ba48991`
- Evidence is bound to staged commit:
  `00228da9ca362b98a1f96d6156acc7a99ba48991`
- Branch: `codex/citysim-world-rendering`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle identifier:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Executable:
  `dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/MacOS/CitySimNative-w5f893ad1da1b`
- Executable SHA-256:
  `ce4ed88362157db7fae859da2eebc5836f5458615952429da4dfcf95c7990b5d`
- Staging manifest SHA-256:
  `b3f68d423d250bb1259fda3ee5738b1348a0c156117d32e509b221880b256013`
- Packaged generated-v4 manifest SHA-256:
  `4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`
- Frozen live fixture:
  `visible-city-industrial-pressured-district-v2.json`
- Fixture SHA-256:
  `0a39d5537b7cf1bd477d47a9b1a50753ad45ac919dbe7e31933e6e56792ba923`

## Supporting deterministic harness

`harness/repeat-a/` and `harness/repeat-b/` contain the same twelve-route
matrix:

- regular and compact;
- selected and unselected;
- City, Neighborhood, and Block semantic LOD.

Every corresponding repeat A/B PNG is byte-identical. These frames use the
renderer proof harness and explicit real-viewport insets. They support
determinism and camera/selection geometry, but they do not substitute for the
shipping SwiftUI HUD.

## Exact staged app

`live/` contains uncropped decorated-window captures from the exact staged
executable:

- regular: `1278 x 768`;
- compact: `900 x 652`, proving exact `900 x 600` content plus 52 points of
  window chrome;
- selected and unselected at City, Neighborhood, and Block proof scales;
- regular routes use normal motion;
- compact routes use `CITYSIM_REDUCE_MOTION_PROOF=1`;
- each route used the same frozen fixture, loaded with Command-O and observed
  paused at Day 244 after the load toast cleared;
- keyboard Right selected City Hall at block `12,12`;
- the retained full AX trees prove selected/unselected map state and the
  typed utility, pollution, and vitality descriptions.

Proof camera scales:

| Window | City | Neighborhood | Block |
|---|---:|---:|---:|
| regular | `0.85` | `0.65` | `0.50` |
| compact | `0.576345682144165` | `0.52` | `0.45` |

The compact matrix visibly retains the selected coordinate inside the real HUD
aperture. The regular matrix remains evidence of the rejected sparse-board
composition rather than a visual acceptance claim.

## Camera and truth measurements

- Regular starting camera scale: `0.6335128545761108`
- Regular occupied width: `0.3689999848900444`
- Regular connected-priority occupancy:
  `0.7841249678913442 x 0.9011585451885599`
- Compact starting camera scale: `0.6549999713897705`
- Compact occupied width: `0.5100866307358453`
- Compact connected-priority occupancy:
  `1.0839340903136712 x 2.0671486412619124`
- Authoritative roads: `32`
- Road-enclosed coordinates retained as authoritative empty land: `15`
- The natural ground adds no road, building, label, action, plaza, path, or
  bench semantic.
- A real road-accessible enclosed coordinate remains buildable, hittable,
  selectable, and visually overridden by placement preview.

## Deferred input

An asset-rich commons or landscape treatment is not appropriate as additional
procedural SpriteKit ornament. Any future authored landscape/public-realm
material should arrive through a governed world-art input contract and the
existing deterministic asset pipeline.
