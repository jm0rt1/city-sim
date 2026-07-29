# Industrial L4 North v12 — Blender Lowering Authority

- **Integration baseline:** `94ae73a99abe64f59bb052582fcaba1d9725319d`
- **Integrated v12 implementation:** `066c5240baf5f7dab62894a71670cb54adf2eead`
- **Integrated analytic identity:** `a9beb5826b1f05d9509b2ac57be5f1bb8b767e1d`
- **Integrated compound audit:** `73d4836c541c1e91647863ae36b8cdbc84035da0`
- **Integrated internal-face proof:** `aef61b2c27ec295a3f088f41031f35e20bc13bc9`
- **Branch:** `codex/citysim-world-art`
- **Claim:** `PLAY-027`
- **Claim SHA-256:** `83fa2894bd822c5b7b25d8da37903dec5f039b30fc334f7b59ca3d8eba82bf0d`
- **Direction:** North only
- **Stage:** task-local deterministic Blender lowering and two zero-pixel
  static-import proofs
- **DCC compute cap:** one process at a time
- **Source authority:** false
- **Candidate ready for source review:** false
- **Production selection:** false
- **External dispatch binding:** required; the worker must receive and verify
  the exact published commit containing this authority plus this authority
  file's SHA-256. Neither value may be inferred from the document itself.

## Independent disposition

North v12 is accepted only as a zero-pixel geometric input for this lowering
slice. Its scene, materials, analytic replays, and mechanical compound-face
proof are integrated. This does not accept its appearance, authorize Process
A, publish an appearance lock, or release any sibling source process.

The v12 scene contains 50 physical components: 44 boxes, five octagonal
prisms, and one exact triangular prism. Earlier Blender helpers do not support
that complete input. This authority therefore permits one task-local v12
lowerer and a thin static importer without changing a shared toolchain.

## Frozen inputs

The worker must verify all of these exact bytes before editing or executing:

| Input | SHA-256 |
|---|---|
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/SCENE.json` | `dad20722f4770c82992040861074188c604b46cd226e5f739291ac22683594e2` |
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/MATERIALS.json` | `e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09` |
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-direction-bridge-v06/MAPPING-CONTRACT.json` | `5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7` |
| `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/audit_compound_mesh.py` | `eba59bae87676c80d7271897cd3ff478e8ca771bc1f8a9ad322d264985d534c8` |
| `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/REPLAY-IDENTITY.json` | `791cdaef240baed03a7a8a380b8fddb50f4039f375a1022ce7eaa7003a28c99e` |
| `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/boundary-proof-repair-v01/COMPOUND-MESH-AUDIT.json` | `03f6e9f1460c87251e525b977d9684a2e92b4e80eb8145563be0a5fb4f39266e` |
| `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/boundary-proof-repair-v01/ADVERSARIAL-RESULTS.json` | `9315b8e778d130ad1a31d3fe30727e6eafce6ba4dffbe66154853f64ef9f5d6c` |
| `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/boundary-proof-repair-v01/DISPOSITION.json` | `8725454f888b3d0c299c4d6bb0bb8fbb46d1bd313b27e2e3cb1826ecb1828c88` |
| `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/boundary-proof-repair-v01/REPLAY-PRESERVATION.json` | `e9818cd8b4e3349c83f6438448582faf1adcdec59318c75202bd5945dd7cc1dd` |

The accepted coordinate basis is exactly
`B(CitySim[x,y,z]) = Blender[z,x,y]`. It has determinant `+1`; face order
must not be reversed, mirrored, rotated, inferred, or sorted.

Earlier `v07/render_process_a.py` and `v07/prove_actual_camera.py` may be
inspected as non-authoritative reference only. They must not be copied,
modified, imported, or executed. They do not support v12's full geometry and
the runner contains a rendering call.

## Exclusive owned paths

Add or edit only these source files:

```text
Native/CitySimNative/WorldArt/Blender/PLAY-027/
  industrial-l04-north-art-v12/blender-lowering-v01/
    LOWERING-CONTRACT.json
    lower_v12_scene.py
    import_v12_scene.py
    launch_static_import.py
    validate_v12_lowering.py
    test_v12_lowering.py
```

Retain evidence only under this exact inventory:

```text
docs/production/evidence/PLAY-027/industrial-l04/l04/
  blender-north-art-v12/blender-lowering-v01/
    pure-a/
      CANONICAL-MESH-IR.json
      OBJECT-MAPPING.json
      PROJECTION.json
      TOPOLOGY.json
      INPUT-BINDINGS.json
      VALIDATION.json
    pure-b/
      <same six run-neutral files>
    static-a/
      BLENDER-OBJECT-MANIFEST.json
      MATERIAL-MANIFEST.json
      PROJECTION.json
      TOPOLOGY.json
      INPUT-BINDINGS.json
      VALIDATION.json
      PROCESS-PROVENANCE.json
    static-b/
      <same seven files>
    REPLAY-IDENTITY.json
    ADVERSARIAL-RESULTS.json
    DISPOSITION.json
```

Do not change existing v12 inputs, sealed analytic replays, repair evidence,
shared Blender helpers, sibling roots, Renderer, shipping resources,
manifests, packages, or build scripts.

## Phase 1 — deterministic lowering

Author a task-local contract, pure-data lowerer, static importer, and tests.
The canonical intermediate representation must:

1. bind the exact claim, authority, scene, materials, bridge, and compound
   proof identities;
2. preserve all 50 physical component IDs and per-face physical provenance
   before aggregation into exactly 47 semantic-owner objects. Name every
   semantic object by its exact `semanticOwnerID`, falling back to the physical
   component ID only when that field is absent. Order objects
   lexicographically, order polygons by the lowerer's canonical face key, and
   emit `OBJECT-MAPPING.json` with a sidecar entry for every
   `objectName/polygonIndex -> physicalComponentID/sourceFaceIndex`;
3. support only the frozen `box`, `octagonal-prism`, and
   `triangular-prism` shapes and reject unknown or extra fields;
4. transform every vertex, camera point, pivot, socket, light, shadow, and
   dimension through the v06 basis exactly once;
5. preserve the triangular prism's exact CitySim vertices and face order:

   ```text
   vertices:
   [3.5,1,-12.8] [3.5,1,-6.8] [9.5,1,-12.8]
   [3.5,19,-12.8] [3.5,19,-6.8] [9.5,19,-12.8]

   faces:
   [0,2,1] [3,4,5] [0,1,4,3] [1,2,5,4] [2,0,3,5]
   ```

6. derive and remove the six same-owner internal face fragments totaling
   exactly `1023.0` world-area units, leaving zero internal interface area and
   compound boundary area `35103.094623`;
7. preserve the different-owner pier/header contact with area `18.0`;
8. reject degeneracy, non-finite coordinates, non-outward winding, duplicate
   IDs, unresolved materials, gaps, owner splits, positive-volume overlap,
   unintended coplanar planes, non-manifold output, and registration error
   above `0.001` source pixel;
9. emit mesh and authored-shadow geometry in world space with identity object
   transforms only. Camera and light objects must instead use the exact
   governed basis-transformed location and orientation. No object may use a
   runtime direction transform, mirroring, fallback, or sibling substitution;
   and
10. produce byte-identical canonical IR and manifests across two pure-data
    runs without timestamps, absolute paths, or nondeterministic ordering.

### Bevel policy

This slice carries each component's frozen bevel value as provenance only.
The lowering and static importer must set `applyBevel: false`, create zero
bevel modifiers, and prove `bevelModifierCount: 0`. It may not guess which
compound seams a future bevel operation should exclude. Actual bevel treatment
must be frozen by a later separately authorized DCC preflight before Process A.

## Phase 2 — two sequential zero-pixel static imports

Phase 2 may begin only after every Phase 1 test passes and the implementation
checkpoint is committed cleanly.

Run exactly two sequential fresh Blender processes, `static-a` then
`static-b`, using:

- executable: `/Applications/Blender.app/Contents/MacOS/Blender`;
- version: `4.5.12 LTS`;
- build hash: `84afd5f785f7`;
- executable SHA-256:
  `8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4`;
- `--background --factory-startup --disable-autoexec --threads 1
  --python-exit-code 1`;
- exactly one DCC process at a time.

The only caller-facing command templates are:

```text
python3 Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/launch_static_import.py \
  --repository-root <canonical-absolute-repository-root> \
  --contract Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/LOWERING-CONTRACT.json \
  --output-root <canonical-absolute-static-a-root> \
  --process-id static-a

python3 Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/launch_static_import.py \
  --repository-root <canonical-absolute-repository-root> \
  --contract Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/LOWERING-CONTRACT.json \
  --output-root <canonical-absolute-static-b-root> \
  --process-id static-b
```

Direct operator invocation of Blender is forbidden. `launch_static_import.py`
is the sole caller and the sole task-owned file permitted to import or use
`subprocess`. It must construct this exact child argv without a shell or
caller-controlled additions:

```text
/Applications/Blender.app/Contents/MacOS/Blender
--background
--factory-startup
--disable-autoexec
--threads
1
--python-exit-code
1
--python
<canonical-absolute-repository-root>/Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/import_v12_scene.py
--
--repository-root
<canonical-absolute-repository-root>
--contract
<canonical-absolute-repository-root>/Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/LOWERING-CONTRACT.json
--output-root
<canonical-absolute-static-a-or-static-b-root>
--process-id
<static-a-or-static-b>
```

The importer and the lowerer's complete dependency closure must not import,
invoke, or dynamically reach `subprocess`.

`launch_static_import.py` must acquire an exclusive nonblocking `flock` on
`/private/tmp/citysim-play027-industrial-l04-north-v12-static.lock` after
opening it with no-follow semantics and verifying that it is a regular file.
It must launch Blender in a new process group, enforce `120` seconds per
process and `240` seconds combined measured child runtime, defined as the sum
of static-a and static-b child runtimes, using a parent-owned monotonic clock.
It must sample total process-group RSS at least every `50` milliseconds and
terminate the group if RSS exceeds `1024 MiB`. Caller-supplied wall/RSS values
are forbidden. The launcher alone records the measured wall, peak
process-group RSS, and exact child argv in `PROCESS-PROVENANCE.json` after the
child exits. Because static-a is committed before static-b begins, continuous
wall time spanning both processes is neither required nor reported.

The importer may create mesh objects, materials, the governed camera, light,
and shadow objects. The importer exclusively emits these six run-neutral
files, using exclusive creation:

- `BLENDER-OBJECT-MANIFEST.json`;
- `MATERIAL-MANIFEST.json`;
- `PROJECTION.json`;
- `TOPOLOGY.json`;
- `INPUT-BINDINGS.json`; and
- `VALIDATION.json`.

The importer must not:

- configure Cycles or another render engine;
- call any render API;
- save a `.blend`;
- write PNG, JPEG, TIFF, EXR, or any other image;
- normalize or create contact sheets; or
- write outside the exact absent, symlink-free `static-a` or `static-b`
  evidence roots.

Require `renderInvocationCount: 0`, `pixelFiles: []`,
`bevelModifierCount: 0`, exact object/mesh/material/projection/topology
identity, and byte-identical run-neutral manifests between both processes.
The run-neutral comparison set is exactly:

- `BLENDER-OBJECT-MANIFEST.json`;
- `MATERIAL-MANIFEST.json`;
- `PROJECTION.json`;
- `TOPOLOGY.json`;
- `INPUT-BINDINGS.json`; and
- `VALIDATION.json`.

`PROCESS-PROVENANCE.json` must truthfully retain its distinct process ID,
child argv, output root, measured child runtime, and peak process-group RSS
and is excluded from byte equality. Only the parent launcher may create it,
after the Blender child exits and the six run-neutral files pass their exact
inventory check.
`REPLAY-IDENTITY.json` must list both comparison sets and every file hash.

Before either Blender launch, mechanically scan the complete task-owned source
tree and fail on direct or dynamic access to render/image/save execution,
including `bpy.ops.render`, render-engine or render-filepath configuration,
image save/write APIs, `.blend` save APIs, `eval`, `exec`, dynamic `getattr`,
network access, subprocess creation from inside Blender, or add-on loading.
The scan may allow `subprocess` only in `launch_static_import.py` and only for
the exact fixed child argv above; it must reject `subprocess` from every other
file in the dependency closure. After each process, scan the
exact output inventory and the repository status; any image, `.blend`, extra
file, or tracked-file mutation fails the stage. Self-reported invocation
counts are evidence only, never the enforcement mechanism.

## Fail-closed and durability requirements

Reject absolute or traversing paths, symlink components, non-regular inputs,
preexisting output roots, overwritten files, wrong repository or branch,
authority/claim/commit/hash drift, and any output outside the two exclusive
roots. Use no-follow parent capture, immediate pre-write revalidation, and
exclusive file creation.

Commit the Phase 1 implementation and two pure-data repeat outputs before
either Blender process. Run, validate, and commit `static-a` as an immutable
checkpoint before `static-b` starts. On an A failure, commit the rejected A
root and stop. On a B failure, preserve and commit B without changing any A
byte, then stop. Commit the final repeat receipt and disposition separately.
Stop at every clean checkpoint if a gate fails; preserve failed output roots
without repair or overwrite.

For a failed or terminated child, preserve the original partial `static-a` or
`static-b` root unchanged. After the child exits or is terminated, the parent
launcher may add exactly one file, `FAILURE.json`, using exclusive creation.
It must contain only the process ID, exit/timeout/RSS disposition, the
launcher-measured child runtime and peak process-group RSS, exact child argv,
and the path/hash inventory of files already present. It must not delete,
rename, repair, replace, or overwrite any partial output. A successful static
root has exactly the seven-file inventory above and no `FAILURE.json`; a
failed root has its immutable partial subset plus exactly `FAILURE.json` and
no later additions.

## Explicitly not authorized

- any rendered or source pixel;
- North Process A, B, or C;
- East, South, or West DCC or pixel work;
- a claim of rendered, Cycles, appearance, or source compatibility/readiness;
- normalization or contact-sheet production;
- appearance-lock or source-production-profile publication;
- source packet, admission, Renderer quarantine or activation;
- shared toolchain, atlas, manifest, runtime, package, or shipping mutation;
- push, integration, or self-acceptance.

Return the exact implementation and evidence commits, IR/manifests and hashes,
static process provenance, negative-case results, repeat identity, invocation
counts, and a disposition that keeps `sourceAuthority`,
`candidateReadyForIndependentReview`, and `productionSelected` false.
