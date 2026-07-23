# PLAY-052 Round 1E independent renderer-only disposition

## Disposition

**APPROVED AS THE EXACT PLAY-034 COMPATIBLE ADAPTER CHECKPOINT — 17/20.**

This renderer-only score applies solely to product
`45dd181221701f7cb73be39b558b7440d86e13b5`. It clears the frozen renderer
threshold of at least 17/20, no category below 3, and no renderer automatic
reject. It is not final integrated acceptance. The separate active-target
contradiction remains a binding UI/input blocker in
`COMBINED_CANDIDATE_BLOCKER.md`.

The prior quality rejection remains immutable at
`ace9d826964a76b05b011174728b9ff45cc04f60` (15/20).

## Exact candidate identity

- World branch: `codex/citysim-world-rendering`
- Merge/base:
  `b5f5d58695c8a0640ad792b1d884b93fc50bfc28`
- Product:
  `45dd181221701f7cb73be39b558b7440d86e13b5`
- Evidence checkpoint:
  `013bdd37c706f2c7326bda870259feb7379570e4`
- Candidate ID: `world-rendering-w5f893ad1da1b`
- Bundle:
  `/Users/James/.codex/worktrees/cac1/city-sim/dist/CitySim-world-rendering-w5f893ad1da1b.app`
- Executable:
  `Contents/MacOS/CitySimNative-w5f893ad1da1b`
- Bundle ID:
  `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- Executable SHA-256:
  `9d2f81ec4bf831f7420bf42a49fdfdebdb4c7952808be0bb43bee3f05d596eb5`
- Candidate manifest SHA-256:
  `4e4ad0e151c2bab3187260cabc96b64c59d4c126569a8af5267f851a42ec9d5d`
- Packaged and source generated-v4 manifest SHA-256:
  `eab12ce0838be9dca6ae00927accac60b15eb41617b39c0e33dd1e727e759692`
- Default live PID: `85453`, sole exact executable, terminated with SIGTERM.
- Explicit compact / Reduce Motion PID: `91740`, sole exact executable,
  launched with `CITYSIM_COMPACT_WINDOW=1` and
  `CITYSIM_REDUCE_MOTION_PROOF=1`, terminated with SIGTERM.
- Compact settled observation: `124,480 KiB` RSS after the live route.
- Final process check: no exact candidate process remained.

The world worktree was clean at the evidence checkpoint. Product ancestry from
the named merge/base and into the evidence checkpoint passed. Quality verified
all 12 renderer-owned evidence hashes, plus the exact executable, candidate
manifest, and packaged/source generated-v4 manifest hashes.

The quality branch was clean at
`ace9d826964a76b05b011174728b9ff45cc04f60`, then merged local master
`6d7df1efa73b4fbcb3e6acf992a80adbaac148ec` normally into merge commit
`0648de6fc5131f0399686551921ebedce0cc9e78`, preserving the immutable prior
rejection without rewriting.

## Independent live route

Quality operated the exact staged application with real pointer and keyboard
input:

1. Launched the sole exact default process, confirmed Day 1, semantic City map
   focus, and no selected block.
2. Paused, used the declared developed-bounds framing command, and captured the
   uncropped 1278 x 768 world.
3. Traversed city, neighborhood, and block LOD stops by keyboard.
4. Selected a commercial block by pointer and a road by keyboard; semantic AX
   identity and primary actions agreed with each committed selection.
5. Cleared selection while leaving the pointer over the commercial frontage.
   AX reported no selected block and the renderer showed only a small,
   non-obscuring cyan frontage cue.
6. Enabled Land Value, checked invalid and valid Residential previews, then
   committed the keyboard-valid block. Live captures retain the 0%, 75%, and
   completed construction states with truthful AX progress and consequence
   text. Undo restored the isolated candidate.
7. Relaunched the same exact executable at 900 x 600 content size with Reduce
   Motion proof enabled. Verified compact composition, keyboard selection,
   semantic AX identity, Objectives plus Command Center arbitration, and
   topmost-first Escape.

The same-bundle preference domain retained a prior quality camera scale on the
first process launch. Quality retained that frame for provenance, then used
the product's `0` developed-bounds framing command before visual scoring. The
renderer-owned same-seed default frame independently hash-verified under the
exact checkpoint shows the same declared developed framing. No product or
defaults were repaired.

## Frozen 20-point score

| Category | Score | Lost points |
|---|---:|---|
| Composition / map occupancy | **3/4** | The developed default and compact world bands are occupied by connected roads, structures, turning heads, pedestrians, and bounded vegetation rather than the predecessor's toy-island emptiness. The point is lost because the city remains one modest crossroads district rather than a richer city-scale network. |
| Projection / material / light / road coherence | **3/4** | Asphalt, curbs, sidewalks, junction contact, shadows, and generated buildings form one coherent physical language. Remote roads no longer dissolve into translucent green previews, and internal ends are readable turning heads. Their saturated green center inserts remain visually prominent enough to cost one point, but they are physically explained termini rather than automatic-reject stubs. |
| Useful city / neighborhood / block LOD and depth | **3/4** | All three stops are stable, keyboard reachable, and useful: city exposes road extent and context, neighborhood preserves frontage and people, and block exposes material/construction detail. City and neighborhood remain close enough in information density to prevent a 4. |
| Believable life / state / interaction restraint | **4/4** | The prior oversized hover ring is gone. Independent no-selection hover showed a small frontage cue; committed selection remained a distinct grounded boundary. Pedestrian/vegetation vignettes, overlay, valid/invalid preview, 0/75/completed construction, and AX consequence states were visible and restrained. CONTRACT-008 target arbitration is scored separately because it is a shared UI/input contradiction, not a renderer-owned presentation regression. |
| Systemic shipping credibility / performance | **4/4** | Exact executable, manifest, resource identity, sole PIDs, and cleanup passed. Current renderer disclosure records staged verification, 36/36 focused renderer tests, 1,138/406 default and 1,129/397 compact nodes/drawables, two bounded ambient actions normally and zero with Reduce Motion, 28 resident textures / 13,521,048 decoded bytes, zero fallback, and a 4,286-pulse stable soak. Quality observed compact at 124,480 KiB RSS. The renderer-owned series is disclosed, not self-credited as a quality rerun. |
| **Total** | **17/20** | Renderer-only threshold met. |

## Renderer automatic-reject checklist

- **Visible unintended physical overlap:** not reproduced. Exact retained
  renderer evidence reports zero governed collision regression.
- **Mixed art language:** not triggered. Roads, curbs, sidewalks, buildings,
  vegetation, and contact shadows now read as one material/projection system.
- **Mostly empty city frame:** not triggered after declared developed framing.
  The starting district remains modest and costs a composition point, but roads
  and inhabited context occupy the governed world band.
- **Unexplained road end:** not triggered. Internal ends are deterministic
  landscaped turning heads; other roads continue beyond the visible frame.
- **Obscuring hover, selection, or overlay:** not triggered by the renderer.
  The isolated no-selection hover cue remains below the facade and does not
  obscure it.
- **Duplicated rejection copy:** not observed.
- **Silent fallback:** not observed; exact resource hashes matched and the
  retained current diagnostics report zero fallback.
- **Over-budget memory / continuing high-water growth:** not observed in the
  live compact process or retained current soak. The final governed cold/memory
  series stopped after the shared live blocker and remains required before
  final integration, but no renderer regression was identified at this
  compatible checkpoint.
- **Harness-only proof:** not triggered. Default, compact, three LODs, pointer,
  keyboard, AX, hover, selection, overlay, construction, and Reduce Motion were
  operated live.

## Comparison with immutable 15/20 predecessor

Round 1E gains two points over product `8433621`:

- life / interaction restraint rises from 2 to 4 because the target-obscuring
  cyan ring/arrow is replaced by a small frontage cue and ambient context is
  visibly richer;
- road continuity no longer triggers an automatic reject: remote roads remain
  physically rendered and internal ends have deterministic turning heads;
- composition stays at 3 because the district is still modest;
- coherence and LOD stay at 3 because the turning-head inserts remain visually
  prominent and city/neighborhood information remains similar;
- the exact resource/performance properties remain credible at 4.

## Renderer-only limitations

- Quality did not rerun the renderer-owned governed cold series or full native
  suite. The retained Round 1E full run has one inherited compact semantic-map
  assertion failure reproduced unchanged on the clean pre-product merge/base;
  it is covered in the combined-candidate disposition.
- The author stopped final governed cold/memory completion after the shared
  live blocker. This renderer score authorizes only the exact compatible
  adapter checkpoint, not final integration.
- Spoken VoiceOver narration and system Full Keyboard Access were not
  separately exercised; semantic AX identity/action parity was inspected live.

These limitations do not waive the separate UI/input blocker or authorize
PLAY-023, push, merge, or final integrated acceptance.
