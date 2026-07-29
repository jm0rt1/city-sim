# PLAY-027 Industrial L2 quality-reset pre-pixel design

Status: **independent review candidate; non-authority pixels only**

Source revision label: `quality-reset-prepixel-v01`

Production selected: `false`

## Fixed registration and presentation contract

- source canvas: 1536 x 1024;
- source footprint diamond: `[(768,640), (1024,768), (768,896), (512,768)]`;
- ground pivot: `(768,896)`;
- world contact polygon: `[(-28,-28), (28,-28), (28,28), (-28,28)]`;
- tile basis: 72 x 36 points;
- projection: orthographic 2:1, yaw 45 degrees, elevation 30 degrees;
- camera position: `(180,146.9693845669907,180)`;
- northwest key origin: `(-120,180,-120)`;
- authored contact shadow: southeast, vector `(2,1)`, opacity `0.34`;
- orientation transform: none;
- sibling mirror or rotation: forbidden and absent.

The exact road-facing sockets remain:

| View | World edge | Source socket |
|---|---|---|
| North | `z=-28` | `(896,704)` |
| East | `x=28` | `(896,832)` |
| South | `z=28` | `(640,832)` |
| West | `x=-28` | `(640,704)` |

## Facility program

The design represents one medium logistics/manufacturing operation rather than
a larger copy of Industrial L1. A cast-concrete plinth supports a clear-span
production hall, two-storey administration, a stepped process volume, roof
monitors, grouped HVAC and exhaust, drainage, service tanks, visible pipe
runs, and a three-position dock. Each frontage includes a deep recess, dock
seals, canopy, structural posts, scored apron, bollards, and a staff entrance.
The parts are grouped at native-readable scale.

The two accepted ImageGen swatches are material references only:
blue-gray painted steel and dark roof membrane. The concrete and galvanized
corrugated attempts missed the declared wrap boundary, remain preserved as
rejected direct tiles, and inform only procedural color/pattern semantics.

## Independently authored North

- descriptor SHA-256:
  `83c4bb6b8437f44b9c25b168395725c788b6f7326d6595d7404882090e1a3596`;
- geometry SHA-256:
  `7bae82334de9b3dfad0a10217dd4109e536385354275ef0566c86de7c155c313`;
- geometry ID: `industrial-l02-quality-reset-north-geometry-v01`;
- 45 explicit components.

Twin production bays form a central service throat. The process mass moves to
the northeast so it cannot block that throat. The far-edge North dock is
represented honestly by a grounded roof-clearing portal, deep canopy, three
dock positions, and an apron connected to the North socket. An east-side
administration return, warm staff entrance, paired roof monitors, service tank,
pipe bridge, and asymmetric exhaust group make this scene unique.

## Independently authored East

- descriptor SHA-256:
  `46896f6c9aae7e37e682d6137cfaec7d35c706f4222bedece9be7127ff9d0265`;
- geometry SHA-256:
  `03fa84eb21231bb191887bccd45e5c22ed9d4739b8325b4bb89411bd56bb57b9`;
- geometry ID: `industrial-l02-quality-reset-east-geometry-v01`;
- 43 explicit components.

A broad production hall steps up to a northwest process tower and down to a
southern fabrication wing. The visible East face carries the three recessed
docks and deep canopy. A southeast administration corner and glazed stair
tower establish human scale, while offset tanks, dual roof monitors, vertical
pipe run, and two HVAC groups create an East-specific skyline and service
logic.

## Independently authored South

- descriptor SHA-256:
  `b6e5df380e17cd10c08394e844066fe2e4e25f4e181484b178172ea0663f0185`;
- geometry SHA-256:
  `01e74e25fcb06002e369973c4ccbb831e36cf03a6c34cc03752927225fcf2277`;
- geometry ID: `industrial-l02-quality-reset-south-geometry-v01`;
- 41 explicit components.

The South scene has a wide rear production hall, a tall southeast process bay,
a low western fabrication wing, and a separate southwest administration bar.
Three South docks share a canopy and scored apron, while a visitor entrance
and warm glazing remain visually separate from logistics traffic. Offset roof
monitors, a west service tank, and a tall east exhaust pair produce a distinct
silhouette.

## Independently authored West

- descriptor SHA-256:
  `57a150395f4c073b77fc4eeecc4d246e9b3c00e81ec87661383e8c120faabbc3`;
- geometry SHA-256:
  `72728a3e3fec588a27a4d3dfa8cc212c5d388ede8ae67759dbe7aab1701a9d2c`;
- geometry ID: `industrial-l02-quality-reset-west-geometry-v01`;
- 46 explicit components.

North and South production bays leave a West service throat. The tall process
block moves to the northeast, clear of the loading sightline. A grounded
roof-clearing West portal, canopy, three dock positions, and apron bind the
far-edge socket without pretending the hidden door plane faces the camera.
The southwest administration return, two eastern tanks, cross-building pipe
bridge, and offset roof monitors distinguish West from every sibling.

## Native-scale intent

Standalone parts are at least 2.0 world units. Thinner seams, drains, rails,
and pipes appear only as named multi-part clusters spanning at least 6.0 world
units. The native-2x mockups use the exact 144 x 72 footprint and deliberately
show that:

- the L2 stepped skyline survives reduction;
- the process and administrative layers separate in grayscale;
- East and South show literal dock depth;
- North and West retain a grounded, roof-clearing loading portal at the
  physically occluded far edge;
- safety yellow remains subordinate to the building rather than becoming a
  toy-like sign.

The clay, wireframe, material-look, color, and grayscale panels are design
diagnostics only. They are not SceneKit source-authority renders and cannot be
normalized, selected, or ingested.
