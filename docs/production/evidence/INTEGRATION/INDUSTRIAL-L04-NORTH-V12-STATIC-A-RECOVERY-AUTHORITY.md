# Industrial L4 North v12 — Static-A Recovery Authority

- **Integration baseline:** `472ffa85cd35639a675c1c2e4ede748c94446a7f`
- **Branch:** `codex/citysim-world-art`
- **Claim:** `PLAY-027`
- **Claim SHA-256:** `d08b57fd47ea3270597e5e36f1b29e9faf820110467a1622bf35fc2bfccedaf3`
- **Retained Phase 1 candidate:** `c609d1cd44c8a188f702894002a0fdd7d79a1d47`
- **Retained failed static-a checkpoint:** `12bcb1a2c740d30cebdc975c2f0882f63de6b6cf`
- **Direction:** North only
- **Stage:** additive launcher repair and exactly one replacement zero-pixel
  `static-a` import
- **DCC compute cap:** one process total and one process at a time
- **Static-b authority:** false
- **Source authority:** false
- **Candidate ready for source review:** false
- **Production selection:** false
- **External dispatch binding:** required; the worker must receive and verify
  the exact published commit containing this authority plus this authority
  file's SHA-256. Neither value may be inferred from this document.

## Disposition and purpose

The original `static-a` failure is valid rejected evidence and remains
immutable. Independent review returned the retained Phase 1 chain because the
original launcher omitted the required caller `--output-root`, scanned an
incomplete dependency set, did not enforce exact branch/authority ancestry and
post-child repository status, and produced an incomplete failure receipt.

This authority permits one additive recovery implementation and exactly one
replacement `static-a` process. It does not rewrite the rejected root, change
the retained lowerer/importer or their pure outputs, authorize `static-b`, or
claim Blender, appearance, source, renderer, or shipping readiness.

## Frozen bindings

The recovery must bind and verify these exact bytes before mutation or
execution:

| Binding | SHA-256 |
|---|---|
| Claim after this recovery authorization | `d08b57fd47ea3270597e5e36f1b29e9faf820110467a1622bf35fc2bfccedaf3` |
| Original lowering authority | `e90f676ca76d65ec7a351ff7e09eeb278c58173a92a8f5036fb9ac18647d66c9` |
| Scene | `dad20722f4770c82992040861074188c604b46cd226e5f739291ac22683594e2` |
| Materials | `e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09` |
| Coordinate bridge | `5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7` |
| Lowering contract | `21480cd8c1dbb66f33b3ccd4987fea169198f2640b793a220d8d22c9c8505aa8` |
| Lowerer | `7dc01ddc56bfff3ee9efca417ad0f70265d92daf99281dd53f7231c691e53a42` |
| Importer | `ec726d584ce4b22253fca486e82bc6a198616debed94358d76f6dac7a1f62988` |
| Rejected launcher | `990ec8d724441cd59a6bfeaa30d4e370142ff64d73b3ea085da3dad70ff664c5` |
| Lowering validator | `a72247a1c8b5410096298608dce4b5ce10b971ed028143c242f6c056cf112d99` |
| Lowering tests | `04eccfc1688fcb85f9a805ec257599f75372e2e6ce8dacb08f482a7a9bac2484` |
| Blender executable | `8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4` |
| Frozen failure receipt | `aa9e71684dffcd501cbdb6f664787de6e7cb6d33602f46aa928f09a062d4ebd3` |
| Frozen failed child stream | `a11ae931a33a201fa3ac3b079dd4771abb73fc13ccf62765b2448243b3fab8c7` |

The six pure-A and pure-B outputs and their exact hashes must remain
byte-identical. The recovery contract may differ from the original lowering
contract only where required to bind this recovery authority, claim,
replacement evidence root, launcher, bounded-output capture, and resource
measurements. Geometry, materials, object mapping, projection, topology,
coordinate basis, importer, and lowerer identities remain unchanged.

## Exclusive additive paths

Add only:

```text
Native/CitySimNative/WorldArt/Blender/PLAY-027/
  industrial-l04-north-art-v12/static-a-recovery-v01/
    RECOVERY-CONTRACT.json
    launch_static_a_recovery.py
    validate_static_a_recovery.py
    test_static_a_recovery.py
```

Retain replacement evidence only under:

```text
docs/production/evidence/PLAY-027/industrial-l04/l04/
  blender-north-art-v12/static-a-recovery-v01/static-a/
```

The original `blender-lowering-v01/static-a/` root is read-only historical
evidence. Do not add, delete, rename, repair, replace, or overwrite any byte
inside it. Do not edit any retained Phase 1 source or pure output.

## Required pre-DCC contract

Before a Blender process may start:

1. commit the additive recovery implementation and its pure test evidence;
2. verify the exact branch, published authority commit, claim hash, authority
   hash, retained candidate ancestry, and frozen bindings;
3. require a clean worktree except for an absent exclusive replacement output
   root that will be created by the launcher;
4. scan the complete task-owned recovery dependency closure and retained
   importer/lowerer closure for forbidden render, image, save, network,
   add-on, dynamic-code, shell, or subprocess paths; only the recovery launcher
   may use `subprocess`;
5. reject symlinks, path traversal, absolute repository-relative inputs,
   preexisting output roots, wrong process ID, `static-b`, argument additions
   or reordering, and any mutation of the original failed root; and
6. run all recovery adversaries without Blender.

The fixed child argv is:

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
<canonical-repository-root>/Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/import_v12_scene.py
--
--repository-root
<canonical-repository-root>
--contract
<canonical-repository-root>/Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/static-a-recovery-v01/RECOVERY-CONTRACT.json
--output-root
<canonical-repository-root>/docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/static-a-recovery-v01/static-a
--process-id
static-a
```

The caller-facing command is exactly:

```text
python3 Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/static-a-recovery-v01/launch_static_a_recovery.py \
  --repository-root <canonical-absolute-repository-root> \
  --contract Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/static-a-recovery-v01/RECOVERY-CONTRACT.json \
  --output-root <canonical-absolute-replacement-static-a-root> \
  --process-id static-a
```

No direct Blender invocation is authorized.

## Process and evidence requirements

The launcher must:

- acquire the existing exclusive task lock with no-follow and regular-file
  checks;
- create the replacement root exclusively and refuse any preexisting or
  symlinked path;
- launch Blender in a new process group without a shell;
- enforce a 120-second timeout and 1024 MiB process-group RSS cap;
- sample process-group RSS at least every 50 milliseconds;
- continuously drain the merged child output, hash every byte, and retain only
  a bounded 65,536-byte tail;
- revalidate all frozen inputs immediately before launch and after exit;
- inventory and hash every partial or successful output;
- verify no tracked or untracked repository mutation occurred outside the
  exact replacement root; and
- terminate the complete process group on timeout, RSS breach, or operator
  interruption.

On success, the replacement root contains exactly the original six
run-neutral importer outputs plus `PROCESS-PROVENANCE.json`. On failure, it
contains the immutable partial subset plus exactly one launcher-created
`FAILURE.json` and no `PROCESS-PROVENANCE.json`.

Both success provenance and failure receipts must contain:

- process ID, return code, and termination disposition;
- `elapsedMonotonicSeconds`;
- `peakProcessGroupRSSKiB`;
- `rssSampleCount`;
- `rssMaximumIntervalSeconds`, no greater than `0.05`;
- exact child argv;
- complete pre/post frozen-input hashes;
- complete output path/hash/size inventory;
- `combinedOutputSHA256`;
- `combinedOutputByteCount`;
- `combinedOutputTailEncoding: base64`;
- `combinedOutputTailBase64`;
- `combinedOutputTailByteCount`;
- `combinedOutputTailMaximumBytes: 65536`; and
- `combinedOutputTailTruncated`.

The launcher must never block on child output and must not store an unbounded
child transcript.

## Mandatory adversaries

The preflight tests must reject:

- claim, authority, contract, importer, lowerer, executable, bridge, failure,
  scene, or materials hash drift;
- wrong branch, wrong authority commit, missing ancestry, or dirty status;
- wrong process ID or any `static-b` request;
- changed, reordered, appended, or caller-controlled child arguments;
- relative, traversing, arbitrary, preexisting, symlinked, or dangling output
  roots;
- reuse or mutation of the original failed root;
- busy, symlinked, non-regular, or replaced lock files;
- timeout and RSS-limit simulations;
- missing, extra, overwritten, image, `.blend`, or out-of-root outputs;
- repository mutation before, during, or after the child;
- stale input metadata after byte mutation;
- empty or oversized tail metadata and any failure to preserve arbitrary
  invalid-UTF-8 child bytes through the bounded base64 tail;
- partial-output mutation before `FAILURE.json`;
- `subprocess` use outside the recovery launcher; and
- any render, save, image, network, dynamic-code, or add-on path in the full
  dependency closure.

## Durability and stop conditions

Commit the recovery implementation and all pre-DCC proof before the one
replacement process. Then run exactly one replacement `static-a` process.
Commit its success or failure root unchanged as an immutable checkpoint and
stop.

Success does not authorize `static-b`. Integration must independently inspect
the replacement evidence and publish a separate authority before any repeat
process. Failure consumes this recovery authority; preserve the failed root
and return without repair or retry.

Explicitly forbidden:

- any `static-b` process;
- any render, source pixel, normalization, or contact sheet;
- North Process A, B, or C;
- East, South, or West DCC or pixel work;
- appearance-lock or source-production-profile publication;
- source packet, admission, Renderer quarantine, activation, or shipping;
- shared toolchain, atlas, manifest, runtime, package, or build-script change;
- push, integration, or self-acceptance.

Return the exact implementation, test-evidence, and immutable replacement
process commits; the authority, claim, contract, launcher, importer, lowerer,
executable, and output hashes; measured runtime/RSS/output-tail fields; the
complete output inventory; and a disposition that keeps `staticBAllowed`,
`sourceAuthority`, `candidateReadyForIndependentReview`, and
`productionSelected` false.
