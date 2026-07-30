# Industrial L4 North v12 — Static-A Recovery v01 Authority

- **Integration baseline:** `472ffa85cd35639a675c1c2e4ede748c94446a7f`
- **Branch:** `codex/citysim-world-art`
- **Claim:** `PLAY-027`
- **Claim path:** `docs/production/claims/PLAY-027.world-art.md`
- **Claim SHA-256:** `83fa2894bd822c5b7b25d8da37903dec5f039b30fc334f7b59ca3d8eba82bf0d`
- **Required worker ancestors:**
  `c609d1cd44c8a188f702894002a0fdd7d79a1d47` and
  `12bcb1a2c740d30cebdc975c2f0882f63de6b6cf`
- **Direction:** North only
- **Attempt ID:** `industrial-l04-north-v12-static-a-recovery-v01`
- **Allowed process ID:** `static-a`
- **Maximum Blender child starts:** `1`
- **Maximum simultaneous DCC processes:** `1`
- **Static-b authority:** false
- **Source authority:** false
- **Candidate ready for source review:** false
- **Production selection:** false
- **External dispatch binding:** required; the worker must receive and verify
  the exact published commit containing this authority plus this authority
  file's measured SHA-256. Neither value may be inferred from this document.

## Operative grant

This additive authority reopens exactly one North-only, zero-pixel Blender
child start identified as
`industrial-l04-north-v12-static-a-recovery-v01/static-a`. It supplements but
does not rewrite the original lowering authority. The rejected
`blender-lowering-v01/static-a` root at commit
`12bcb1a2c740d30cebdc975c2f0882f63de6b6cf` remains immutable. A Blender child
start consumes this authority whether it succeeds, exits nonzero, times out,
or exceeds RSS.

No second recovery start, `static-b`, Process A/B/C, rendered pixel, `.blend`,
normalization, appearance lock, sibling release, admission, shipping, push, or
self-acceptance is authorized.

## Frozen authority and implementation

| Binding | SHA-256 |
|---|---|
| Original lowering authority | `e90f676ca76d65ec7a351ff7e09eeb278c58173a92a8f5036fb9ac18647d66c9` |
| Scene | `dad20722f4770c82992040861074188c604b46cd226e5f739291ac22683594e2` |
| Materials | `e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09` |
| Coordinate bridge | `5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7` |
| Original lowering contract | `21480cd8c1dbb66f33b3ccd4987fea169198f2640b793a220d8d22c9c8505aa8` |
| Lowerer | `7dc01ddc56bfff3ee9efca417ad0f70265d92daf99281dd53f7231c691e53a42` |
| Importer | `ec726d584ce4b22253fca486e82bc6a198616debed94358d76f6dac7a1f62988` |
| Rejected launcher, retained but never executed | `990ec8d724441cd59a6bfeaa30d4e370142ff64d73b3ea085da3dad70ff664c5` |
| Lowering validator | `a72247a1c8b5410096298608dce4b5ce10b971ed028143c242f6c056cf112d99` |
| Lowering tests | `04eccfc1688fcb85f9a805ec257599f75372e2e6ce8dacb08f482a7a9bac2484` |
| Blender executable | `8485107307b16bd0899f3c259261494b0c80e383db239c04e2c9fcd14d305fb4` |
| Consumed failure receipt | `aa9e71684dffcd501cbdb6f664787de6e7cb6d33602f46aa928f09a062d4ebd3` |
| Consumed child-output stream | `a11ae931a33a201fa3ac3b079dd4771abb73fc13ccf62765b2448243b3fab8c7` |

The consumed failure receipt is:

```text
docs/production/evidence/PLAY-027/industrial-l04/l04/
  blender-north-art-v12/blender-lowering-v01/static-a/FAILURE.json
```

The original rejected root is immutable. The worker must prove its path, hash,
inventory, and containing commit again before and after recovery.

## Exclusive additive paths

Add only:

```text
Native/CitySimNative/WorldArt/Blender/PLAY-027/
  industrial-l04-north-art-v12/blender-lowering-v01/
    static-a-recovery-v01/
      RECOVERY-CONTRACT.json
      launch_static_a_recovery.py
      test_static_a_recovery.py
```

Retain evidence only under:

```text
docs/production/evidence/PLAY-027/industrial-l04/l04/
  blender-north-art-v12/blender-lowering-v01/
    static-a-recovery-v01/
      PRELAUNCH-VALIDATION.json
      static-a/
```

Do not edit the retained Phase 1 source, pure outputs, rejected launcher, or
original failed evidence.

## Recovery contract

`RECOVERY-CONTRACT.json` is the original lowering contract with exactly two
top-level changes:

1. `evidenceRoot` points to
   `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/blender-lowering-v01/static-a-recovery-v01`.
2. A `recovery` object binds the exact published authority commit, measured
   authority-file SHA-256, Integration baseline, both required worker
   ancestors, consumed failure path/hash/commit, `allowedProcessID:
   "static-a"`, and `maximumChildStarts: 1`.

All geometry, materials, claim, original authority, coordinate bridge,
expected values, compound interfaces, Blender fingerprint, and stage remain
byte- or structurally identical.

## Fixed child invocation

The recovery launcher must accept the caller arguments
`--repository-root`, `--contract`, `--output-root`, and `--process-id`. It must
require the exact absent recovery root and process ID `static-a`.

Its child argv is fixed:

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
<repository-root>/Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/import_v12_scene.py
--
--repository-root
<repository-root>
--contract
<repository-root>/Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/static-a-recovery-v01/RECOVERY-CONTRACT.json
--output-root
<repository-root>/docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/blender-lowering-v01/static-a-recovery-v01/static-a
--process-id
static-a
```

No direct Blender invocation or shell is authorized. Only the new recovery
launcher may execute the child. The rejected launcher remains inactive.

## Mandatory prelaunch validation

Commit the recovery implementation and
`PRELAUNCH-VALIDATION.json` cleanly before Blender. Prove:

- exact North branch and clean status;
- the published authority commit, dispatch commit, and both required worker
  commits are ancestors;
- every frozen hash passes;
- the original failed root remains byte-identical;
- the recovery contract differs from the original only in `evidenceRoot` and
  `recovery`;
- the complete task-owned dependency scan passes;
- `subprocess` occurs only in the frozen inactive launcher and the new
  recovery launcher, and only the new launcher may execute;
- the new launcher accepts `--output-root` and requires the exact absent
  recovery root;
- child output uses a temporary file rather than an unread pipe;
- the source and evidence roots are regular, canonical, confined, absent where
  required, and symlink-free; and
- no source pixel, `.blend`, `static-b`, Process A/B/C, sibling DCC, admission,
  or shipping output exists.

Negative tests must cover wrong branch, authority, claim, commit ancestry,
contract, importer, lowerer, executable, bridge, failure, scene, or materials
identity; symlinks; traversal; arbitrary or preexisting roots; lock
contention; changed child arguments; timeout; RSS; repository mutation;
missing/extra/overwritten files; images; `.blend`; and a second attempted
start.

## Runtime and immutable result

The launcher must use the existing no-follow task lock, launch Blender in a
new process group without a shell, enforce a 120-second timeout and 1024 MiB
process-group RSS cap, sample RSS at least every 50 milliseconds, hash the
complete temporary child-output file, and retain only a bounded 65,536-byte
UTF-8-safe tail in the receipt. It must revalidate frozen inputs and repository
status before launch and after exit.

Success retains exactly the six importer files plus
`PROCESS-PROVENANCE.json`. Failure retains the immutable partial subset plus
exactly one launcher-created `FAILURE.json`.

The provenance or failure receipt must include:

- process ID, return code, termination disposition, and exact child argv;
- measured elapsed monotonic seconds and peak process-group RSS;
- RSS sample count and maximum interval;
- complete combined-output SHA-256 and byte count;
- bounded output tail, tail byte count, maximum bytes, and truncation state;
  and
- `{path, sha256, byteCount}` for every partial or successful output.

After the one child starts, commit its success or failure root unchanged,
verify the original failure hash again, prove `static-b` and every pixel or
`.blend` file absent, and stop. Failure consumes the authority; no repair or
retry is allowed. Success does not authorize `static-b`.
