# PLAY-061 Exact Candidate Evidence

This packet records independent evidence for exact integration candidate
`1799fbc2810f14d85511b74a8808bbee1928eef7` under frozen preregistration
`bd0a06ea676f492e5dc7a354f423f51e6ed4a741`. It contains no product changes
and does not reuse the renderer lane's score.

## Independent validation

- The sandboxed focused run failed first because the restricted module cache
  was not writable; a redirected-cache sandbox attempt then failed at
  `sandbox-exec`. Both failures are retained. The same exact candidate was run
  outside that restriction with a private `/private/tmp` module cache.
- `WorldRenderingTests`: 52/52, zero failures, 27.987 seconds.
- Complete native suite: 223/223, zero failures, 105.980 seconds.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed and launched only staged PID
  `18870` from the exact quality executable.
- Independent pack validator: passed; four pages, 180 payload checks, 180
  extrusion checks, 4,411 packed-overlap checks, 16 Commercial raw identities,
  48 Commercial normalized identities, source/staged parity, zero failures.
- Independent production geometry: passed; 6,724 reciprocal-ground checks,
  164 building/road checks, 628 entrance/prop checks, zero collisions,
  missing references, or orphan entries.
- Two clean pack builds reproduced identical manifest and page bytes.

## Runtime identity and skyline matrix

The independent 2800 x 2200 runtime export replaces the baseline's one
south-facing L1 alias in every cell with sixteen unique Commercial identities.
In color and derived grayscale:

- L1 reads as a low storefront;
- L2 adds a materially larger market/arcade mass;
- L3 becomes a stepped office/department block; and
- L4 is an unmistakable premium tower.

N/E/S/W entrances and mass returns move with the declared road socket. No row
reads as Residential or Industrial, and no level is a scaled clone. The matrix
is a renderer runtime export from the exact candidate, not an author contact
sheet. The focused all-LOD persistence test independently exercised every
identity through pulse, save/load, undo, camera, and LOD transitions.

## Real staged-app routes

Regular and compact sessions loaded the byte-identical Day 33 fixture paused.
The exact live L1 Commercial at player block `14,12` remained visually distinct
from neighboring Residential and Industrial buildings. Compared with frozen
baseline `64dd475`, the new L1 is correctly low-rise and storefront-led rather
than the old generic medium-rise `commercial_l01`; its entrance direction,
commercial awning/color accents, and density role are clearer in both regular
and compact frames.

The regular route covered pointer and keyboard selection, Details, all five
overlays, Focus City exit/re-entry, occupied rejection, valid preview,
single construction, undo, save, terminate, relaunch, and paused load. Undo
restored treasury to `$30,848`, removed the construction, and the saved primary
and backup both matched the original fixture SHA-256 exactly.

The exact compact route preserved a world-first aperture with all critical
metrics, urgency, speed, notices, selected target, Details, and actions
visible or scroll-reachable. Command search, stable focus traversal, FKA Space
activation, and an AX custom build action were exercised. The AX action built
the single announced coordinate once. Escape restored the selected map target.
Reduce Motion preserved Commercial identity and state meaning.

Original binding captures are uncropped decorated windows. `city-900x600.jpg`
and `valid-commercial-preview.jpg` retain setup transients for chronology;
`city-900x600-clean.jpg` and `valid-commercial-preview-clean.jpg` are the
transient-free binding frames.

## LOD and story-fixture limitation

The supplied production story fixtures contain only L1 Commercial lots. That
does not remove or waive the frozen 4 x 4 requirement. Evidence is split by
proof class:

1. the real staged app proves the actual L1 gameplay journey, state, HUD,
   selection, construction, persistence, input, AX, compact, and Reduce Motion;
2. the independently exported exact-runtime 4 x 4 matrix proves all sixteen
   source identities, frontages, color/grayscale progression, and renderer
   lookup; and
3. exact candidate tests prove all sixteen identities across every LOD,
   unchanged pulse, save/load, undo, camera, selection, overlay, construction,
   condition, and Reduce Motion.

This is sufficient because the frozen rubric requires systemic runtime
coverage rather than fabrication of un-authored gameplay states. A static
author sheet or L1-only live route alone would not be sufficient.

## Evidence index

- `identity/IDENTITY.md`
- `identity/staged-candidate.manifest`
- `ledgers/commercial-direction-level-matrix.csv`
- `ledgers/interaction-accessibility.csv`
- `ledgers/performance-and-residency.csv`
- `matrix/`
- `live/regular/`
- `live/compact/`
- `live/reduce-motion/`
- `validation/`
