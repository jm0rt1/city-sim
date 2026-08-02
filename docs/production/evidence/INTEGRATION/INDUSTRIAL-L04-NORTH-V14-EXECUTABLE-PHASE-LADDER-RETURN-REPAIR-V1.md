# Industrial L4 North v14 Executable Phase-Ladder Return Repair v1

**Owner:** Integration frontier authority

**Task:** PLAY-027 North

## Disposition

Candidate `0c2b3a0fca3e3b5637d2dd8c4b296235ef957202` is preserved and returned.
It correctly preserved frozen v14 and R4/R5 bytes and produced zero DCC/output,
but its Stage-B functions always raise, its phase list is metadata rather than
flushed runtime evidence, and it does not implement live checkout or external
schedule/grant/session closure. It cannot support a one-child diagnosis.

## Required repair

Within the existing `process-a-phase-ladder-v01/` and matching task-owned
static-evidence root only, implement the complete future diagnostic path while
keeping it unreachable without a separately published Integration Stage-B
packet.

The repaired launcher must:

1. resolve and require the exact live branch and `git rev-parse HEAD`;
2. parse and hash-bind external schedule, grant, session and static-approval
   documents, the exact model route, native Blender identity, one-child cap,
   absent exclusive output root, allowed output leaves and timeout;
3. contain exactly one child-start site, with no caller-selected authority;
4. capture complete stdout/stderr, PID, argv, timing, return/signal, every
   parsed phase, last phase, output inventory and any newly created macOS crash
   report;
5. preserve `FAILURE.json` after `communicate()` on every nonzero, signal,
   timeout or incomplete-phase result; and
6. reject replay, direct child invocation and all identity/hash/root drift.

The child must import the immutable v14 helper module, emit real line-delimited
JSON using `print(..., flush=True)` at these exact phases:

`python_entered`, `frozen_inputs_verified`, `source_module_loaded`,
`bpy_imported`, `scene_configured`, `all_96_meshes_created`,
`pre_micro_render`, `post_micro_render`, `complete`.

It must construct the actual governed scene through the frozen helpers and
perform only one 8x8 non-shipping CPU/Cycles micro-render. It must not render a
semantic pass, write `.blend`, generate normal source pixels, normalize, or
reference sibling/renderer/shipping paths.

## Proof boundary

This is ambiguous cross-system crash diagnosis and therefore uses
`FRONTIER_AUTHORITY / gpt-5.6-sol / high`. The repair turn remains zero-DCC:
tests exercise document parsing, subprocess seams, marker parsing, capture and
failure preservation with a fake child, plus adversaries for every identity,
hash, ordering, root, leaf, timeout and replay edge. They must prove no Blender
process, output root or pixel is created.

Independent Integration review is required before any Stage-B schedule,
grant, session or child attempt. The later runtime attempt remains exactly one
child with no retry and confers diagnostic evidence only.
