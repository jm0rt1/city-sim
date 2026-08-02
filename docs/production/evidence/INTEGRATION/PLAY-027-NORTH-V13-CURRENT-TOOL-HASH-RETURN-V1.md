# PLAY-027 North v13 current-tool-hash return

**Disposition:** one bounded evidence-integrity return

**Functionally accepted candidate:** `74e5b7b5cbd79439ed2e0f40c360a58daedbccdc`

**Synchronized clean worker HEAD:** `23fe321326cb1d2fc390cf390e7f03ca0befe70e`

Independent review confirmed the exact eight-path scope, real-Git
`launchReady=1` positive fixture, 41 fail-closed adversaries, exact generated
HANDOFF/READINESS bytes, and zero DCC, child, Process-A, output-root, render, or
pixel activity.

The candidate is returned only because
`CURRENT-AUTHORITY-REBIND.json.toolHashes` retains four pre-repair hashes for
the execution contract, runner contract, runner, and child. The receipt now
claims the repaired boundary, so those values must bind the current committed
bytes rather than remain historical.

The worker may change only:

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-v02/test_process_a_v02.py`; and
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-v02/CURRENT-AUTHORITY-REBIND.json`.

Update the four stale SHA-256 values from the exact committed candidate bytes.
Extend the focused test so every receipt `toolHashes` entry resolves to its
named governed file and equals the current byte hash. Run the focused suite
twice plus JSON and diff checks, then return one clean evidence-integrity
commit.

Do not change contracts, runner behavior, launch logic, HANDOFF/READINESS,
authority, schedule, attempt markers, DCC state, source/pixels, renderer,
shipping resources, gameplay, UI, simulation, package topology, or scripts.
Do not launch, self-accept, integrate, push, or pin.
