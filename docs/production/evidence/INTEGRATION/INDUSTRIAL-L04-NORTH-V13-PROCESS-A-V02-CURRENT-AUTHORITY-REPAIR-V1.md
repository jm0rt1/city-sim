# Industrial L4 North v13 Process-A v02 current-authority repair

**Owner:** Integration

**Status:** active frontier authority

**Execution boundary:** `LUNA_IMPLEMENTATION / gpt-5.6-luna / high`

## Disposition

North retirement candidate
`c95029d4a6efa1ceb6a93860a96c87ecc5a6f7b9` passes the exact hostile-import
and attempted-call gate with zero files, directories, processes, DCC starts,
renders, normalizations, or pixels. Its `process-a-prelaunch-v01/` bytes are
accepted as inert on the source branch. They are not cherry-picked to master
because master already omits that obsolete branch-only surface; reintroducing
retired files would be a semantic regression.

The unchanged prospective `process-a-v02/` implementation cannot yet launch.
Independent review found that its executable constants, execution contract,
handoff, and readiness records still bind:

- authority/base `23f1836892f19d9579609f523397aea068202859`;
- revision-8 claim SHA-256
  `7d42ba7c38a55d7681171499aad50e15c2d3eba0878cabf508d0e42ee97cdc83`;
- execution base `3485ff76543ef9be595f9640deab925f17ac8eb5`; and
- the superseded Integration-direct route/carrier.

A schedule against the current claim and worker tree must fail those stale
bindings. Integration therefore issues no schedule, receipt, attempt marker,
compute slot, or process start until the exact repair below passes.

## Exact mutable paths

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-v02/EXECUTION-CONTRACT.json`
- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-v02/RUNNER-CONTRACT.json`
- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-v02/launch_north_v13_process_a_v02.py`
- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-v02/render_north_v13_process_a_child.py`
- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-v02/test_process_a_v02.py`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-v02/HANDOFF.json`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-v02/ORCHESTRATOR-READINESS.json`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-v02/CURRENT-AUTHORITY-REBIND.json`

Every other path is immutable, including all `process-a-prelaunch-v01/`
retirement bytes, frozen design/lowering inputs, sibling directions,
Renderer/shipping resources, shared authority, claims, and the user's
untracked schedule draft.

## Required repair

1. Bind the exact published revision-10 claim hash, authority/base commit,
   selected model route, synchronized clean worker HEAD, and all existing
   frozen input hashes in both parent and child validation.
2. Preserve the fixed Blender executable/arguments, one subprocess and one
   Process-A ceiling, outside-output-root attempt marker, absent output-root
   precondition, atomic marker consumption, committed schedule path/blob
   equality, process-receipt identity, child-side repository checks, direct
   child rejection, and `communicate()` capture.
3. Add exact stale-authority, stale-claim, stale-route, stale-worker,
   changed-input, schedule-forgery, replay, wrong-root, direct-child, and
   more-than-one-child adversaries.
4. Run the focused suite twice from the same committed inputs and produce a
   byte-identical current-authority receipt with zero DCC, child, render,
   normalization, and pixel activity.

## Stop boundary

Stop after one clean candidate-ready-for-independent-review commit or on any
mandatory model-route escalation trigger. This authority grants no live
schedule, lease, secret, attempt marker, Blender/DCC child, Process A/B/C,
render, pixel, normalization, appearance lock, source admission, production
selection, Renderer activation, shipping mutation, push, integration, or
self-acceptance. Integration alone may independently accept the repaired
boundary and publish a later one-attempt schedule.
