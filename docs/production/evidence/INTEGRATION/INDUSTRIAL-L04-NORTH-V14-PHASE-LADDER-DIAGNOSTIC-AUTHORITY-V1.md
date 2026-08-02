# Industrial L4 North v14 Phase-Ladder Diagnostic Authority v1

**Owner:** Integration frontier authority

**Task:** PLAY-027
**Purpose:** localize the repeated North v14 native Blender SIGSEGV without
another blind production render or any mutation of frozen scene/output bytes.

## Frozen diagnosis

North R5 at exact candidate
`c792001a7f387b6ddb65092dc426531e98719553` consumed one authorized arm64
Blender child, returned `-11` (`SIGSEGV`), wrote no pixels, and retained only
its failure packet. The cached factory-startup receipt exercised `--version`,
not the deeper `--python` scene path. The next legal action is an isolated
phase diagnostic, not a retry of Process A.

## Stage A: zero-DCC implementation

`LUNA_IMPLEMENTATION / gpt-5.6-luna / high` may add only:

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v14/process-a-phase-ladder-v01/`
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v14/process-a-phase-ladder-r1/STATIC-RECEIPT.json`

The implementation wraps, imports, and calls the frozen child helpers. It must
not copy or edit the v14 scene implementation. Its durable JSONL phase order is:

1. `python_entered`
2. `frozen_inputs_verified`
3. `source_module_loaded`
4. `bpy_imported`
5. `scene_configured`
6. `all_96_meshes_created`
7. `pre_micro_render`
8. `post_micro_render`
9. `complete`

The launcher is inert without a later Integration-issued Stage-B schedule,
grant, and session. Static tests must prove exact immutable hashes, actual
branch/HEAD binding, one child-start site, exclusive-root containment, ordered
flushed markers, output-leaf allowlisting, and zero DCC/process/pixel effects.

## Stage B: separately gated one-child diagnosis

Stage B does not exist until a frontier reviewer accepts the exact Stage-A
candidate and Integration publishes a new route plus external schedule, grant,
session, and static-approval receipt. That future packet may authorize exactly
one arm64 Blender child and one 8x8 non-shipping CPU/Cycles micro-render in a
new absent `phase-output` root. It must preserve complete argv, executable
identity, PID/times/return/signal, full stdout/stderr, every phase marker, last
phase, exact output inventory, and any newly created macOS crash-report hash.

No normal 1536x1024 render, semantic pass, `.blend`, normalization, source
selection, Process B/C, sibling work, Renderer/shipping mutation, retry, or
second child is legal.

## Interpretation

- no `python_entered`: native launcher/startup boundary;
- stop before `bpy_imported`: Python/source-module boundary;
- stop before `all_96_meshes_created`: scene construction boundary;
- stop after `pre_micro_render`: renderer/compositor/write boundary;
- `complete`: full-resolution/output path requires a separate diagnosis.

Every mismatch or unexpected output fails closed and preserves existing R4/R5
evidence byte-for-byte.
