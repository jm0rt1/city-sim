# Industrial L4 Integration-direct launch authority v2

**Owner:** Integration

**Status:** active replacement authority

**Batch:** `industrial_l04_directional_family`

**Execution mode:** `integration_direct`

## Decision

Return exact North v13 candidate
`aaea9fda4249e88a82791d9a418408575e5f32ff`. Its new `process-a-v02`
boundary remains the prospective Integration-direct implementation, but the
candidate tree also retains the rejected `process-a-prelaunch-v01` module.
Independent review proved that module still exports a caller-keyed authority
builder and a consumer that can create attempt state. A rejected historical
module may not retain a live authority surface in the tree used for execution.

Revision 9 therefore authorizes one bounded deactivation repair. The original
revision-8 bytes remain recoverable in Git history, while the current-tree
launcher, child, contracts, and focused test become explicit retirement
stubs. The repair must add a machine-readable retirement receipt and must not
modify any `process-a-v02`, design, lowering, pixel, sibling, Renderer, or
shipping byte.

## Honest trust boundary

`integration_direct` is an operational ownership boundary, not in-repository
cryptographic authentication between processes running as the same macOS
user. No repository-local secret, caller-selected key, token builder, or
worker-authored receipt can prove actor identity. Only the Integration task is
authorized to publish the schedule and invoke the exact accepted command.
The resulting Integration-owned process receipt is audit evidence of that
event; it is not a worker-mintable grant.

The technical closure must still fail closed on exact schedule bytes, claim,
branch, HEAD, input hashes, direction, process, slot, roots, replay, direct
child invocation, and more than one child. Those checks protect identity and
determinism. They must not be described as authenticating a same-user caller.

## Bounded Luna implementation

Exact mutable paths:

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-prelaunch-v01/EXECUTION-CONTRACT.json`
- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-prelaunch-v01/RUNNER-CONTRACT.json`
- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-prelaunch-v01/launch_north_v13_prelaunch.py`
- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-prelaunch-v01/render_north_v13_process_a_child.py`
- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-prelaunch-v01/test_process_a_prelaunch.py`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-prelaunch-v01/RETIREMENT.json`

Required outcome:

1. Both executable modules are import-safe and unconditionally refuse every
   attempted launch or child entry.
2. No public builder, signer, validator, fixture-authority consumer, schedule
   consumer, attempt consumer, or child-start helper remains callable.
3. Both contracts are closed retired records with no executable command,
   secret, token, authority, schedule, receipt, attempt, or source-ready state.
4. Fresh-root adversaries prove imports and attempted calls create zero files,
   directories, processes, DCC starts, renders, normalizations, or pixels.
5. The test also proves the historical `/private/tmp/citysim-play027-north-v13-test-attempt-`
   prefix is unchanged before and after the run.
6. The retirement receipt binds the exact parent candidate, claim revision,
   five source paths and hashes, focused result, zero-side-effect accounting,
   and `productionSelected:false` / `sourceAuthority:false`.

## Acceptance and later launch

Independent frontier review evaluates the complete repaired candidate tree,
including absence of the retired escape and the unchanged `process-a-v02`
boundary. Acceptance authorizes neither pixels nor launch. Integration must
then publish a separate exact schedule, exclusive one-attempt lease, compute
slot, command, and process-receipt root before invoking North Process A once.

This authority grants no B/C process, sibling pixels, appearance lock, source
admission, production selection, Renderer activation, integration, or push.
