# Industrial L4 North v12 static-A module-bootstrap recovery v02

**Owner:** Integration

**Baseline:** `ccb3d67eb2cd7095589249ac316ac48f105e76dd`

**Direction / claim:** North / `PLAY-027`

**Disposition:** one replacement zero-pixel child start authorized

The v01 recovery was complete and correctly bounded, but Blender did not put
the frozen importer directory on `sys.path`. The unchanged importer therefore
failed before argument parsing, lowering, `bpy` mutation, static output, or
rendering:

- v01 recovery content commit:
  `56e4f484ac07ca3fcf11e72f69a7fb56170d9792`;
- integrated v01 failure commit:
  `ccb3d67eb2cd7095589249ac316ac48f105e76dd`;
- v01 `FAILURE.json` SHA-256:
  `d68b922bb93ea57449e69fd5ee5d177e697d0b19cc02860c95db11d56ab2f5a6`;
- complete child stream SHA-256:
  `a11ae931a33a201fa3ac3b079dd4771abb73fc13ccf62765b2448243b3fab8c7`.

## Exact grant

Create only:

```text
Native/CitySimNative/WorldArt/Blender/PLAY-027/
  industrial-l04-north-art-v12/blender-lowering-v01/
    static-a-recovery-v02/
      RECOVERY-CONTRACT.json
      launch_static_a_module_bootstrap.py
      test_static_a_module_bootstrap.py

docs/production/evidence/PLAY-027/industrial-l04/l04/
  blender-north-art-v12/blender-lowering-v01/
    static-a-recovery-v02/
      PRELAUNCH-VALIDATION.json
      static-a/
```

The launcher may change only the Blender child bootstrap. Immediately before
the unchanged importer, it may execute one deterministic `--python-expr` that:

1. resolves the canonical `blender-lowering-v01` directory;
2. proves `lower_v12_scene.py` has SHA-256
   `7dc01ddc56bfff3ee9efca417ad0f70265d92daf99281dd53f7231c691e53a42`;
3. rejects any unexpected existing occurrence of that directory;
4. inserts that exact directory at `sys.path[0]`; and
5. verifies `importlib.util.find_spec("lower_v12_scene").origin` resolves to
   that exact file.

The next child argument must execute the frozen `import_v12_scene.py`, SHA-256
`ec726d584ce4b22253fca486e82bc6a198616debed94358d76f6dac7a1f62988`.
No `PYTHONPATH`, environment injection, importer/lowerer edit, alternate module
loader, or additional search directory is permitted.

## Frozen boundaries

- Original lowering contract:
  `21480cd8c1dbb66f33b3ccd4987fea169198f2640b793a220d8d22c9c8505aa8`.
- Original launcher remains byte-identical and inactive:
  `990ec8d724441cd59a6bfeaa30d4e370142ff64d73b3ea085da3dad70ff664c5`.
- Lowering validator:
  `a72247a1c8b5410096298608dce4b5ce10b971ed028143c242f6c056cf112d99`.
- Lowering tests:
  `04eccfc1688fcb85f9a805ec257599f75372e2e6ce8dacb08f482a7a9bac2484`.
- Both prior failure roots remain byte-identical.
- Maximum Blender child starts: `1`.
- Allowed process ID: `static-a`.
- Maximum simultaneous DCC processes: `1`.
- Success returns exactly the six static JSON files plus process provenance,
  commits them, and stops.
- Failure retains one complete immutable receipt with argv, elapsed time, peak
  process-group RSS, bounded full-stream evidence, and every partial file,
  commits it, and stops.

No `static-b`, Process A/B/C, rendered pixel, `.blend`, normalization,
appearance lock, sibling source release, source admission, Renderer
quarantine, production selection, shipping, push, or self-acceptance is
authorized. A child start consumes this authority regardless of outcome.
